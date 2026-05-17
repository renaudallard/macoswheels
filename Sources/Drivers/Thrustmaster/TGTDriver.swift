import Foundation
#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum TGTQuirks: WheelQuirks {
    public static let displayName = "Thrustmaster T-GT"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB68E,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? = T300Quirks.bootIdentity

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 19,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 1080,
        supportedEffects: T300Quirks.capabilities.supportedEffects,
        supportsAutocenter: true,
        supportsGain: true
    )

    public static let defaultRangeDegrees: UInt16 = 1080

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
        try T300Quirks.setRotationRangePackets(degrees: degrees)
    }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        try T300Quirks.setAutocenterPackets(percent: percent)
    }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        try T300Quirks.setGainPackets(percent: percent)
    }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try T300Quirks.encode(effect)
    }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        try T300Quirks.stopEffectPacket(slot: slot)
    }
}

public typealias TGTDriver = GenericWheelDriver<TGTQuirks>
