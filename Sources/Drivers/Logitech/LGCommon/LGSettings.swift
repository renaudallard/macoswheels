#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum LGSettings {

    public static func setRotationRangePacket(degrees: UInt16) -> USBPacket {
        let r = max(40, min(900, degrees))
        let bytes: [UInt8] = [
            LGOpcode.cmdExtendedPrefix,
            LGOpcode.cmdSetRange,
            UInt8(r & 0x00FF),
            UInt8((r & 0xFF00) >> 8),
            0x00, 0x00, 0x00,
        ]
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func autocenterDisablePacket() -> USBPacket {
        .interruptOut(endpoint: LGOpcode.interruptOutEndpoint,
                      bytes: [LGOpcode.cmdAutocenterDisable, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    public static func setAutocenterPackets(percent: UInt8) -> [USBPacket] {
        let pct = min(percent, 100)
        if pct == 0 { return [autocenterDisablePacket()] }

        let magnitude = UInt32(pct) * 0xFFFF / 100
        var expandA: UInt32
        var expandB: UInt32
        if magnitude <= 0xAAAA {
            expandA = 0x0C * magnitude
            expandB = 0x80 * magnitude
        } else {
            expandA = (0x0C * 0xAAAA) + 0x06 * (magnitude - 0xAAAA)
            expandB = (0x80 * 0xAAAA) + 0xFF * (magnitude - 0xAAAA)
        }
        expandA >>= 1

        let setBytes: [UInt8] = [
            LGOpcode.cmdAutocenterStrength,
            0x0D,
            UInt8(expandA / 0xAAAA),
            UInt8(expandA / 0xAAAA),
            UInt8(expandB / 0xAAAA),
            0x00, 0x00,
        ]
        let activateBytes: [UInt8] = [
            LGOpcode.cmdAutocenterActivate, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ]
        return [
            .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: setBytes),
            .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: activateBytes),
        ]
    }
}
