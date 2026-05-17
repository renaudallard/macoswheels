import Foundation
import WheelProtocol

public enum G29Quirks: WheelQuirks {
    public static let displayName = "Logitech G29"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.g29,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? =
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.drivingForceGeneric,
                      model: "Logitech Driving Force (boot/compat mode)", role: .wheelBase)

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 26,
        pedalCount: 3,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 900,
        supportedEffects: [
            .constant, .ramp,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper,
        ],
        supportsAutocenter: true,
        supportsGain: false
    )

    public static let defaultRangeDegrees: UInt16 = 900
    public static let hardwareSlotCount: UInt8 = 4

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
        [LGSettings.setRotationRangePacket(degrees: degrees)]
    }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        LGSettings.setAutocenterPackets(percent: percent)
    }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        throw DriverError.effectNotSupported(.constant)
    }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try LGFFBEncoder.encode(effect)
    }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        LGFFBEncoder.stopPacket(hardwareSlot: LGFFBEncoder.pidSlotToHardware(slot))
    }
}

public typealias G29Driver = GenericWheelDriver<G29Quirks>
