import WheelProtocol

public enum T300Settings {

    public static func setGainPacket(percent: UInt8) -> USBPacket {
        let raw = UInt8(min(255, Int(percent) * 255 / 100))
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [0x02, raw])
    }

    public static func setRotationRangePacket(degrees: UInt16) -> USBPacket {
        let clamped = max(40, min(1080, degrees))
        let scaled = UInt16(UInt32(clamped) * 0x3C)
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [0x08, 0x11, UInt8(scaled & 0xFF), UInt8(scaled >> 8)])
    }

    public static func setAutocenterStrengthPacket(percent: UInt8) -> USBPacket {
        let p = min(percent, 100)
        let value = UInt16(p) * 100
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [0x08, 0x04, UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    public static func setAutocenterEnabledPacket(_ enabled: Bool) -> USBPacket {
        let v: UInt16 = enabled ? 1 : 0
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                             bytes: [0x08, 0x04, UInt8(v & 0xFF), UInt8(v >> 8)])
    }
}
