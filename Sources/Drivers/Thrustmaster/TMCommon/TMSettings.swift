import WheelProtocol

public enum TMSettings {

    public static func setGainPacket(percent: UInt8) -> USBPacket {
        let raw = UInt8(min(255, Int(percent) * 255 / 100))
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [TMOpcode.setGainOpcode, raw])
    }

    public static func setRotationRangePacket(degrees: UInt16, maxDegrees: UInt16) -> USBPacket {
        let clamped = min(degrees, maxDegrees)
        let scaled = UInt16(UInt32(clamped) * 0xFFFF / UInt32(maxDegrees))
        return settings40(.rotationRange, argument: scaled)
    }

    public static func setAutocenterStrengthPacket(percent: UInt8) -> USBPacket {
        let p = min(percent, 100)
        return settings40(.autocenterStrength, argument: UInt16(p))
    }

    public static func setAutocenterEnabledPacket(_ enabled: Bool) -> USBPacket {
        settings40(.autocenterEnable, argument: enabled ? 1 : 0)
    }

    public static func settings40(_ op: TMOpcode.Settings, argument: UInt16) -> USBPacket {
        let lo = UInt8(argument & 0xFF)
        let hi = UInt8((argument >> 8) & 0xFF)
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [TMOpcode.settingsOpcode, op.rawValue, lo, hi])
    }
}
