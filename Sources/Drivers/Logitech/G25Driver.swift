import Foundation
#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum G25Quirks: WheelQuirks {
    public static let displayName = "Logitech G25"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.g25,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? = G29Quirks.bootIdentity

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 19,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 900,
        supportedEffects: G29Quirks.capabilities.supportedEffects.union([.friction]),
        supportsAutocenter: true,
        supportsGain: false
    )

    public static let defaultRangeDegrees: UInt16 = 900
    public static let hardwareSlotCount: UInt8 = 4

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
        try G29Quirks.setRotationRangePackets(degrees: degrees)
    }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        try G29Quirks.setAutocenterPackets(percent: percent)
    }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        try G29Quirks.setGainPackets(percent: percent)
    }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try G29Quirks.encode(effect)
    }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        try G29Quirks.stopEffectPacket(slot: slot)
    }
}

public typealias G25Driver = GenericWheelDriver<G25Quirks>
