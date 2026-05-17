#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum LGModeSwitch {

    public static func switchToNativePackets(_ mode: LGOpcode.NativeMode) -> [USBPacket] {
        let revert: [UInt8] = [
            LGOpcode.cmdExtendedPrefix, LGOpcode.extRevertOnReset,
            0x00, 0x00, 0x00, 0x00, 0x00,
        ]
        let detach: UInt8 = (mode == .g29 || mode == .g923) ? 0x01 : 0x01
        let switchBytes: [UInt8] = [
            LGOpcode.cmdExtendedPrefix, LGOpcode.extSwitchMode,
            mode.rawValue, detach,
            (mode == .g29 || mode == .g923) ? 0x01 : 0x00,
            0x00, 0x00,
        ]
        return [
            .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: revert),
            .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: switchBytes),
        ]
    }
}
