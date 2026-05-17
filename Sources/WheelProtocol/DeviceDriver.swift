import Foundation

public struct ProbeResult: Sendable, Hashable {
    public let identity: WheelIdentity
    public let firmwareVersion: String?
    public init(identity: WheelIdentity, firmwareVersion: String?) {
        self.identity = identity
        self.firmwareVersion = firmwareVersion
    }
}

public enum DriverError: Error, Sendable, Hashable {
    case notInitialized
    case unsupportedForRole(DeviceRole)
    case effectNotSupported(EffectKind)
    case effectSlotInvalid(UInt8)
    case rangeOutOfBounds(requested: UInt16, min: UInt16, max: UInt16)
    case bootSwitchPending
    case usb(USBError)
    case notImplemented
}

extension DriverError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notInitialized:
            return "driver not initialized"
        case .unsupportedForRole(let role):
            return "not supported for \(role.rawValue)"
        case .effectNotSupported(let kind):
            return "effect not supported by this wheel: \(kind)"
        case .effectSlotInvalid(let slot):
            return "invalid effect slot \(slot)"
        case .rangeOutOfBounds(let requested, let min, let max):
            return "rotation range \(requested) out of bounds (\(min)..\(max))"
        case .bootSwitchPending:
            return "boot-to-firmware mode switch in progress"
        case .usb(let underlying):
            return "USB transport error: \(underlying)"
        case .notImplemented:
            return "not implemented for this wheel yet"
        }
    }
}

public protocol DeviceDriverDelegate: AnyObject, Sendable {
    func driver(_ driver: any DeviceDriver, didEmitHIDReport bytes: [UInt8])
    func driver(_ driver: any DeviceDriver, didFailWith error: Error)
    func driverDidRequestRematch(_ driver: any DeviceDriver)
}

public protocol DeviceDriver: AnyObject {
    static var supportedIDs: [WheelIdentity] { get }
    static var bootIdentity: WheelIdentity? { get }
    static var capabilities: WheelCapabilities { get }
    static var displayName: String { get }

    init(transport: any USBTransport, delegate: any DeviceDriverDelegate)

    func probe() throws -> ProbeResult
    func claim() throws
    func initialize() throws
    func startReadLoop() throws
    func teardown()

    func setRotationRange(degrees: UInt16) throws
    func setAutocenter(strength: UInt8) throws
    func setGain(_ gain: UInt8) throws

    func encode(_ effect: NormalizedEffect) throws -> [USBPacket]
    func stopEffect(slot: UInt8) throws
    func stopAllEffects() throws
}
