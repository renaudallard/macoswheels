import Foundation
import WheelProtocol

public final class G25Driver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Logitech G25"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.g25,
                      model: G25Driver.displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.drivingForceGeneric,
                      model: "Logitech Driving Force (boot/compat mode)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 19,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 900,
        supportedEffects: [
            .constant, .ramp,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper, .friction,
        ],
        supportsAutocenter: true,
        supportsGain: false
    )

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?
    private let lock = NSLock()
    private var currentRangeDegrees: UInt16 = 900
    private var currentAutocenter: UInt8 = 0

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Self.supportedIDs[0], firmwareVersion: nil)
    }
    public func claim() throws {}

    public func initialize() throws {
        try transport.send(LGSettings.setRotationRangePacket(degrees: currentRangeDegrees))
        for p in LGSettings.setAutocenterPackets(percent: currentAutocenter) {
            try transport.send(p)
        }
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
        try transport.send(LGSettings.setRotationRangePacket(degrees: degrees))
        lock.lock(); currentRangeDegrees = degrees; lock.unlock()
    }

    public func setAutocenter(strength: UInt8) throws {
        let pct = min(strength, 100)
        for p in LGSettings.setAutocenterPackets(percent: pct) {
            try transport.send(p)
        }
        lock.lock(); currentAutocenter = pct; lock.unlock()
    }

    public func setGain(_ gain: UInt8) throws { throw DriverError.effectNotSupported(.constant) }
    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try LGFFBEncoder.encode(effect)
    }

    public func stopEffect(slot: UInt8) throws {
        try transport.send(LGFFBEncoder.stopPacket(hardwareSlot: LGFFBEncoder.pidSlotToHardware(slot)))
    }

    public func stopAllEffects() throws {
        for slot: UInt8 in 0..<4 {
            try? transport.send(LGFFBEncoder.stopPacket(hardwareSlot: slot))
        }
    }
}
