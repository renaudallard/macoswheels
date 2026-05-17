import Foundation
import WheelProtocol

public enum T150Quirks: WheelQuirks {
    public static let displayName = "Thrustmaster T150"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB677,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: 0x044F, productID: TMOpcode.genericBootProductID,
                      model: "Thrustmaster FFB Wheel (T-series boot)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 13,
        pedalCount: 2,
        hasHat: true,
        rangeMinDegrees: 270,
        rangeMaxDegrees: 1080,
        supportedEffects: [
            .constant,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    public static let defaultRangeDegrees: UInt16 = 900

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
        [TMSettings.setRotationRangePacket(degrees: degrees,
                                           maxDegrees: capabilities.rangeMaxDegrees)]
    }

    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        let pct = min(percent, 100)
        return [
            TMSettings.setAutocenterEnabledPacket(pct > 0),
            TMSettings.setAutocenterStrengthPacket(percent: pct),
        ]
    }

    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        [TMSettings.setGainPacket(percent: percent)]
    }

    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try TMFFBEncoder.encode(effect)
    }

    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        TMFFBEncoder.stopEffectPacket(slot: slot)
    }
}

public typealias T150Driver = GenericWheelDriver<T150Quirks>
