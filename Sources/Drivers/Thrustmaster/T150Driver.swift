import Foundation
import WheelProtocol

public final class T150Driver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Thrustmaster T150"
    public static let modelSwitchValue: UInt16 = 0x0006

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB677,
                      model: T150Driver.displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: 0x044F, productID: TMOpcode.genericBootProductID,
                      model: "Thrustmaster FFB Wheel (T-series boot)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 13,
        pedalCount: 2,
        hasHat: true,
        hasClutch: false,
        hasHandbrake: false,
        rangeMinDegrees: 270,
        rangeMaxDegrees: 1080,
        supportedEffects: [
            .constant, .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?
    private let lock = NSLock()
    private var currentRangeDegrees: UInt16 = 900
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
        try transport.send(TMSettings.setGainPacket(percent: currentGain))
        try transport.send(TMSettings.setAutocenterEnabledPacket(false))
        try transport.send(TMSettings.setAutocenterStrengthPacket(percent: currentAutocenter))
        try transport.send(TMSettings.setRotationRangePacket(degrees: currentRangeDegrees,
                                                             maxDegrees: Self.capabilities.rangeMaxDegrees))
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
        try transport.send(TMSettings.setRotationRangePacket(degrees: degrees,
                                                             maxDegrees: caps.rangeMaxDegrees))
        lock.lock(); currentRangeDegrees = degrees; lock.unlock()
    }

    public func setAutocenter(strength: UInt8) throws {
        let pct = min(strength, 100)
        try transport.send(TMSettings.setAutocenterEnabledPacket(pct > 0))
        try transport.send(TMSettings.setAutocenterStrengthPacket(percent: pct))
        lock.lock(); currentAutocenter = pct; lock.unlock()
    }

    public func setGain(_ gain: UInt8) throws {
        let pct = min(gain, 100)
        try transport.send(TMSettings.setGainPacket(percent: pct))
        lock.lock(); currentGain = pct; lock.unlock()
    }

    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try TMFFBEncoder.encode(effect)
    }

    public func stopEffect(slot: UInt8) throws {
        try transport.send(TMFFBEncoder.stopEffectPacket(slot: slot))
    }

    public func stopAllEffects() throws {
        for slot: UInt8 in 0..<16 {
            try? transport.send(TMFFBEncoder.stopEffectPacket(slot: slot))
        }
    }

    public func snapshot() -> (range: UInt16, autocenter: UInt8, gain: UInt8) {
        lock.lock(); defer { lock.unlock() }
        return (currentRangeDegrees, currentAutocenter, currentGain)
    }
}
