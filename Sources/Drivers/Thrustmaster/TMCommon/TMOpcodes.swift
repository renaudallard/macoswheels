#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum TMOpcode {

    public static let genericBootProductID: UInt16 = 0xB65D

    public static let modelQueryRequestType: UInt8 = 0xC1
    public static let modelQueryRequest:     UInt8 = 73
    public static let modelQueryLength:      UInt16 = 0x0010

    public static let modeSwitchRequestType: UInt8 = 0x41
    public static let modeSwitchRequest:     UInt8 = 83

    public static let interruptOutEndpoint:  UInt8 = 0x02
    public static let interruptInEndpoint:   UInt8 = 0x81

    public static let setGainOpcode:         UInt8 = 0x43

    public static let settingsOpcode:        UInt8 = 0x40
    public enum Settings: UInt8 {
        case autocenterStrength = 0x03
        case autocenterEnable   = 0x04
        case rotationRange      = 0x11
    }

    public enum EffectClass: UInt8 {
        case constant  = 0x03
        case periodic  = 0x04
        case condition = 0x05
    }

    public enum FirstCode: UInt8 {
        case constantPeriodic = 0x02
        case condition        = 0x05
    }

    public enum CommitCode: UInt16 {
        case constant = 0x4000
        case sine     = 0x4022
        case sawUp    = 0x4023
        case sawDown  = 0x4024
        case square   = 0x4025
        case triangle = 0x4026
        case spring   = 0x4040
        case damper   = 0x4041
    }

    public enum EffectControl: UInt8 {
        case stop    = 0x00
        case play    = 0x01
        case loop    = 0x41
    }
}

public struct TMModelSwitch: Sendable, Hashable {
    public let model: UInt8
    public let attachment: UInt8
    public let switchValue: UInt16
    public let name: String
}

public enum TMModelTable {
    public static let entries: [TMModelSwitch] = [
        TMModelSwitch(model: 0x00, attachment: 0x02, switchValue: 0x0002, name: "T500RS"),
        TMModelSwitch(model: 0x02, attachment: 0x00, switchValue: 0x0005, name: "T300RS (no attachment)"),
        TMModelSwitch(model: 0x02, attachment: 0x03, switchValue: 0x0005, name: "T300RS F1"),
        TMModelSwitch(model: 0x02, attachment: 0x04, switchValue: 0x0005, name: "T300 Ferrari Alcantara"),
        TMModelSwitch(model: 0x02, attachment: 0x06, switchValue: 0x0005, name: "T300RS"),
        TMModelSwitch(model: 0x02, attachment: 0x09, switchValue: 0x0005, name: "T300RS Open Wheel"),
        TMModelSwitch(model: 0x03, attachment: 0x06, switchValue: 0x0006, name: "T150RS"),
    ]

    public static func lookup(model: UInt8, attachment: UInt8) -> TMModelSwitch? {
        entries.first(where: { $0.model == model && $0.attachment == attachment })
    }
}
