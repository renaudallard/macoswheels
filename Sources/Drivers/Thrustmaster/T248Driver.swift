import Foundation
import WheelProtocol

public enum T248Quirks: WheelQuirks {
    public static let displayName = "Thrustmaster T248"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB696,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? = T300Quirks.bootIdentity

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 19,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 270,
        rangeMaxDegrees: 900,
        supportedEffects: [
            .constant, .ramp,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper, .friction,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    public static let defaultRangeDegrees: UInt16 = 900

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

public typealias T248Driver = GenericWheelDriver<T248Quirks>
