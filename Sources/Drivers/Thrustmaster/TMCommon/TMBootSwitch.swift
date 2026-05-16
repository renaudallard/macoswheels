import WheelProtocol

public enum TMBootSwitch {

    public static func packet() -> USBPacket {
        let setup = USBControlSetup(bmRequestType: TMOpcode.bootSwitchRequestType,
                                    bRequest: TMOpcode.bootSwitchRequest,
                                    wValue: TMOpcode.bootSwitchWValue,
                                    wIndex: TMOpcode.bootSwitchWIndex)
        return .control(setup, payload: [])
    }
}
