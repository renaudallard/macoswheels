import Foundation
import WheelProtocol

public enum T128Quirks: WheelQuirks {
    public static let displayName = "Thrustmaster T128"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB68F,
                      model: displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? = nil

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 12,
        pedalCount: 2,
        hasHat: true,
        rangeMinDegrees: 270,
        rangeMaxDegrees: 900,
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
        throw DriverError.notImplemented
    }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] {
        throw DriverError.notImplemented
    }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] {
        throw DriverError.notImplemented
    }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        throw DriverError.notImplemented
    }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket {
        throw DriverError.notImplemented
    }
}

public typealias T128Driver = GenericWheelDriver<T128Quirks>
