import WheelProtocol

public final class T150Driver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Thrustmaster T150"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB65D,
                      model: T150Driver.displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: 0x044F, productID: 0xB677,
                      model: "Thrustmaster T150 (boot)", role: .wheelBase)

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
            .constant, .ramp, .squarePeriodic, .sinePeriodic,
            .trianglePeriodic, .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper, .friction,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Self.supportedIDs[0], firmwareVersion: nil)
    }

    public func claim() throws {}
    public func initialize() throws {}
    public func startReadLoop() throws {}
    public func teardown() {}

    public func setRotationRange(degrees: UInt16) throws {
        guard (Self.capabilities.rangeMinDegrees...Self.capabilities.rangeMaxDegrees).contains(degrees) else {
            throw DriverError.rangeOutOfBounds(requested: degrees,
                                               min: Self.capabilities.rangeMinDegrees,
                                               max: Self.capabilities.rangeMaxDegrees)
        }
    }

    public func setAutocenter(strength: UInt8) throws {}
    public func setGain(_ gain: UInt8) throws {}

    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        throw DriverError.notImplemented
    }

    public func stopEffect(slot: UInt8) throws {
        throw DriverError.notImplemented
    }

    public func stopAllEffects() throws {
        throw DriverError.notImplemented
    }
}
