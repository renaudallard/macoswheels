#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum LGOpcode {

    public static let logitechVID: UInt16 = 0x046D

    public static let interruptOutEndpoint: UInt8 = 0x01
    public static let interruptInEndpoint:  UInt8 = 0x81

    public static let cmdSetRange:          UInt8 = 0x81
    public static let cmdAutocenterDisable: UInt8 = 0xF5
    public static let cmdAutocenterStrength: UInt8 = 0xFE
    public static let cmdAutocenterActivate: UInt8 = 0x14
    public static let cmdExtendedPrefix:    UInt8 = 0xF8

    public static let extRevertOnReset:     UInt8 = 0x0A
    public static let extSwitchMode:        UInt8 = 0x09

    public enum NativeMode: UInt8 {
        case dfex = 0x00
        case dfp  = 0x01
        case g25  = 0x02
        case dfgt = 0x03
        case g27  = 0x04
        case g29  = 0x05
        case g923 = 0x07
    }
}

public enum LGPID {
    public static let drivingForceGeneric: UInt16 = 0xC294
    public static let dfp:  UInt16 = 0xC298
    public static let g25:  UInt16 = 0xC299
    public static let dfgt: UInt16 = 0xC29A
    public static let g27:  UInt16 = 0xC29B
    public static let g29:  UInt16 = 0xC24F
    public static let g920: UInt16 = 0xC262
    public static let g923PC:  UInt16 = 0xC266
    public static let g923PS:  UInt16 = 0xC267
    public static let g923Xbox: UInt16 = 0xC26E
    public static let drivingForceShifter: UInt16 = 0xC29C
}
