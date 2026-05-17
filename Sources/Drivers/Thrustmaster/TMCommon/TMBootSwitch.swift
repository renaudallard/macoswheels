#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum TMBootSwitch {

    public static func modelQueryPacket() -> USBPacket {
        let setup = USBControlSetup(bmRequestType: TMOpcode.modelQueryRequestType,
                                    bRequest: TMOpcode.modelQueryRequest,
                                    wValue: 0,
                                    wIndex: 0)
        return .control(setup, payload: [])
    }

    public static func modeSwitchPacket(value: UInt16) -> USBPacket {
        let setup = USBControlSetup(bmRequestType: TMOpcode.modeSwitchRequestType,
                                    bRequest: TMOpcode.modeSwitchRequest,
                                    wValue: value,
                                    wIndex: 0)
        return .control(setup, payload: [])
    }

    public struct ModelQueryResponse: Sendable, Hashable {
        public let model: UInt8
        public let attachment: UInt8
    }

    public static func parseModelQuery(_ bytes: [UInt8]) -> ModelQueryResponse? {
        guard bytes.count >= 8 else { return nil }
        let type = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        switch type {
        case 0x0049 where bytes.count >= 8:
            return ModelQueryResponse(model: bytes[7], attachment: bytes[6])
        case 0x0047 where bytes.count >= 8:
            return ModelQueryResponse(model: bytes[7], attachment: bytes[6])
        default:
            return nil
        }
    }
}
