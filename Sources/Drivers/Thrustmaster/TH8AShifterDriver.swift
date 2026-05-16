import Foundation
import WheelProtocol

public final class TH8AShifterDriver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Thrustmaster TH8A shifter"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB687,
                      model: TH8AShifterDriver.displayName, role: .shifter),
    ]

    public static let bootIdentity: WheelIdentity? = nil

    public static let capabilities = WheelCapabilities(
        role: .shifter,
        buttonCount: 8,
        pedalCount: 0,
        hasHat: false,
        rangeMinDegrees: 0,
        rangeMaxDegrees: 0,
        supportedEffects: [],
        supportsAutocenter: false,
        supportsGain: false
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

    public func setRotationRange(degrees: UInt16) throws { throw DriverError.unsupportedForRole(.shifter) }
    public func setAutocenter(strength: UInt8) throws    { throw DriverError.unsupportedForRole(.shifter) }
    public func setGain(_ gain: UInt8) throws            { throw DriverError.unsupportedForRole(.shifter) }
    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func stopEffect(slot: UInt8) throws { throw DriverError.unsupportedForRole(.shifter) }
    public func stopAllEffects() throws         { throw DriverError.unsupportedForRole(.shifter) }
}
