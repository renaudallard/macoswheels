import Foundation

public protocol WheelQuirks {
    static var displayName: String { get }
    static var supportedIDs: [WheelIdentity] { get }
    static var bootIdentity: WheelIdentity? { get }
    static var capabilities: WheelCapabilities { get }

    static var defaultRangeDegrees: UInt16 { get }
    static var defaultGainPercent: UInt8 { get }
    static var defaultAutocenterPercent: UInt8 { get }
    static var hardwareSlotCount: UInt8 { get }

    static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket]
    static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket]
    static func setGainPackets(percent: UInt8) throws -> [USBPacket]
    static func encode(_ effect: NormalizedEffect) throws -> [USBPacket]
    static func stopEffectPacket(slot: UInt8) throws -> USBPacket

    static func parseInputReport(raw: [UInt8]) -> [UInt8]?
}

extension WheelQuirks {
    public static var defaultAutocenterPercent: UInt8 { 0 }
    public static var defaultGainPercent: UInt8 { 75 }
    public static var hardwareSlotCount: UInt8 { 16 }

    public static func parseInputReport(raw: [UInt8]) -> [UInt8]? { nil }
}

public protocol ShifterQuirks {
    static var displayName: String { get }
    static var supportedIDs: [WheelIdentity] { get }
    static var bootIdentity: WheelIdentity? { get }
    static var capabilities: WheelCapabilities { get }
}
