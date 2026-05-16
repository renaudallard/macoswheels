public enum TMOpcode {
    public static let bootSwitchRequestType: UInt8 = 0x41
    public static let bootSwitchRequest:     UInt8 = 0x53
    public static let bootSwitchWValue:      UInt16 = 0x0001
    public static let bootSwitchWIndex:      UInt16 = 0x0000

    public static let interruptOutEndpoint:  UInt8 = 0x02
    public static let interruptInEndpoint:   UInt8 = 0x81

    public enum Effect: UInt8 {
        case constant     = 0x60
        case squarePeriodic   = 0x61
        case sinePeriodic     = 0x62
        case trianglePeriodic = 0x63
        case sawtoothPeriodic = 0x64
        case spring   = 0x40
        case damper   = 0x41
        case friction = 0x42
    }

    public enum Control: UInt8 {
        case startEffect = 0x89
        case stopEffect  = 0x8A
        case globalGain  = 0x81
    }
}
