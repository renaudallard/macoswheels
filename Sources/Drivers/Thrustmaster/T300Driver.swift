import Foundation
import WheelProtocol

public enum T300Quirks: WheelQuirks {
    public static let displayName = "Thrustmaster T300 RS"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB66E,
                      model: "Thrustmaster T300 RS (PS3 normal)", role: .wheelBase),
        WheelIdentity(vendorID: 0x044F, productID: 0xB66F,
                      model: "Thrustmaster T300 RS (PS3 advanced)", role: .wheelBase),
        WheelIdentity(vendorID: 0x044F, productID: 0xB66D,
                      model: "Thrustmaster T300 RS (PS4 normal)", role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: 0x044F, productID: TMOpcode.genericBootProductID,
                      model: "Thrustmaster FFB Wheel (T-series boot)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 14,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 1080,
        supportedEffects: [
            .constant, .ramp,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper, .friction, .inertia,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    public static let defaultRangeDegrees: UInt16 = 900

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
        [T300Settings.setRotationRangePacket(degrees: degrees)]
    }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        let pct = min(percent, 100)
        return [
            T300Settings.setAutocenterEnabledPacket(pct > 0),
            T300Settings.setAutocenterStrengthPacket(percent: pct),
        ]
    }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        [T300Settings.setGainPacket(percent: percent)]
    }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try T300FFBEncoder.encode(effect)
    }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        T300FFBEncoder.stopPacket(slot: slot)
    }
}

public typealias T300Driver = GenericWheelDriver<T300Quirks>
