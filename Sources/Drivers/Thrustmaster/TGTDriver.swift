import Foundation
import WheelProtocol

public final class TGTDriver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Thrustmaster T-GT"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB68E,
                      model: TGTDriver.displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: 0x044F, productID: TMOpcode.genericBootProductID,
                      model: "Thrustmaster FFB Wheel (T-series boot)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 19,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 1080,
        supportedEffects: [
            .constant, .ramp,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper, .friction, .inertia,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?
    private let lock = NSLock()
    private var currentRangeDegrees: UInt16 = 1080
    private var currentAutocenter: UInt8 = 0
    private var currentGain: UInt8 = 75

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Self.supportedIDs[0], firmwareVersion: nil)
    }
    public func claim() throws {}

    public func initialize() throws {
        try transport.send(T300Settings.setGainPacket(percent: currentGain))
        try transport.send(T300Settings.setAutocenterEnabledPacket(false))
        try transport.send(T300Settings.setAutocenterStrengthPacket(percent: currentAutocenter))
        try transport.send(T300Settings.setRotationRangePacket(degrees: currentRangeDegrees))
    }

    public func startReadLoop() throws {}
    public func teardown() {}

    public func setRotationRange(degrees: UInt16) throws {
        let caps = Self.capabilities
        guard (caps.rangeMinDegrees...caps.rangeMaxDegrees).contains(degrees) else {
            throw DriverError.rangeOutOfBounds(requested: degrees,
                                               min: caps.rangeMinDegrees,
                                               max: caps.rangeMaxDegrees)
        }
        try transport.send(T300Settings.setRotationRangePacket(degrees: degrees))
        lock.lock(); currentRangeDegrees = degrees; lock.unlock()
    }

    public func setAutocenter(strength: UInt8) throws {
        let pct = min(strength, 100)
        try transport.send(T300Settings.setAutocenterEnabledPacket(pct > 0))
        try transport.send(T300Settings.setAutocenterStrengthPacket(percent: pct))
        lock.lock(); currentAutocenter = pct; lock.unlock()
    }

    public func setGain(_ gain: UInt8) throws {
        let pct = min(gain, 100)
        try transport.send(T300Settings.setGainPacket(percent: pct))
        lock.lock(); currentGain = pct; lock.unlock()
    }

    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try T300FFBEncoder.encode(effect)
    }

    public func stopEffect(slot: UInt8) throws {
        try transport.send(T300FFBEncoder.stopPacket(slot: slot))
    }

    public func stopAllEffects() throws {
        for slot: UInt8 in 0..<16 {
            try? transport.send(T300FFBEncoder.stopPacket(slot: slot))
        }
    }
}
