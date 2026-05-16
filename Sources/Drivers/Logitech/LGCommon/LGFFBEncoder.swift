import WheelProtocol

public enum LGFFBEncoder {

    public enum CommandOp: UInt8 {
        case download = 1
        case stop     = 3
        case update   = 0xC
    }

    public enum EffectByte: UInt8 {
        case constant = 0x00
        case spring   = 0x0B
        case damper   = 0x0C
        case friction = 0x0E
    }

    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        switch effect {
        case .constant(let slot, let magnitude, _, _, _):
            return [constant(hardwareSlot: pidSlotToHardware(slot), force: magnitude)]
        case .spring(let slot, let p):
            return [spring(hardwareSlot: pidSlotToHardware(slot), params: p)]
        case .damper(let slot, let p):
            return [damper(hardwareSlot: pidSlotToHardware(slot), params: p)]
        case .friction(let slot, let p):
            return [friction(hardwareSlot: pidSlotToHardware(slot), params: p)]
        case .periodic, .ramp, .inertia, .customForceData:
            throw DriverError.notImplemented
        }
    }

    public static func stopPacket(hardwareSlot: UInt8) -> USBPacket {
        let bytes: [UInt8] = [
            (0x10 << hardwareSlot) | CommandOp.stop.rawValue, 0, 0, 0, 0, 0, 0,
        ]
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func pidSlotToHardware(_ pidSlot: UInt8) -> UInt8 {
        pidSlot & 0x03
    }

    public static func constant(hardwareSlot slot: UInt8, force: Int16) -> USBPacket {
        var bytes: [UInt8] = [
            (0x10 << slot) | CommandOp.download.rawValue,
            EffectByte.constant.rawValue,
            0, 0, 0, 0, 0,
        ]
        bytes[2 + Int(slot)] = translateForce(force)
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func spring(hardwareSlot slot: UInt8, params p: ConditionParams) -> USBPacket {
        let d1raw = (UInt32(bitPattern: Int32(p.deadBand)) &+ 0x8000) & 0xFFFF
        let d2raw = (UInt32(bitPattern: Int32(p.centerOffset)) &+ 0x8000) & 0xFFFF
        var d1 = scaleValueU16(UInt16(d1raw & 0xFFFF), bits: 11)
        var d2 = scaleValueU16(UInt16(d2raw & 0xFFFF), bits: 11)
        let s1: UInt8 = (p.negativeCoefficient < 0) ? 1 : 0
        let s2: UInt8 = (p.positiveCoefficient < 0) ? 1 : 0
        var k1 = Int(abs(Int(p.negativeCoefficient)))
        var k2 = Int(abs(Int(p.positiveCoefficient)))
        if k1 < 2048 { d1 = 0 }       else { k1 -= 2048 }
        if k2 < 2048 { d2 = 2047 }    else { k2 -= 2048 }
        let bytes: [UInt8] = [
            (0x10 << slot) | CommandOp.download.rawValue,
            EffectByte.spring.rawValue,
            UInt8(d1 >> 3),
            UInt8(d2 >> 3),
            UInt8((scaleCoeff(k2, bits: 4) << 4) | scaleCoeff(k1, bits: 4)),
            UInt8(((d2 & 7) << 5) | ((d1 & 7) << 1) | (UInt16(s2) << 4) | UInt16(s1)),
            scaleValueU16(UInt16(min(Int(p.positiveSaturation) + 0x8000, 0xFFFF)), bits: 8).toU8(),
        ]
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func damper(hardwareSlot slot: UInt8, params p: ConditionParams) -> USBPacket {
        let s1: UInt8 = (p.negativeCoefficient < 0) ? 1 : 0
        let s2: UInt8 = (p.positiveCoefficient < 0) ? 1 : 0
        let bytes: [UInt8] = [
            (0x10 << slot) | CommandOp.download.rawValue,
            EffectByte.damper.rawValue,
            UInt8(scaleCoeff(Int(abs(Int(p.negativeCoefficient))), bits: 4)),
            s1,
            UInt8(scaleCoeff(Int(abs(Int(p.positiveCoefficient))), bits: 4)),
            s2,
            scaleValueU16(UInt16(min(Int(p.positiveSaturation) + 0x8000, 0xFFFF)), bits: 8).toU8(),
        ]
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func friction(hardwareSlot slot: UInt8, params p: ConditionParams) -> USBPacket {
        let s1: UInt8 = (p.negativeCoefficient < 0) ? 1 : 0
        let s2: UInt8 = (p.positiveCoefficient < 0) ? 1 : 0
        let bytes: [UInt8] = [
            (0x10 << slot) | CommandOp.download.rawValue,
            EffectByte.friction.rawValue,
            UInt8(scaleCoeff(Int(abs(Int(p.negativeCoefficient))), bits: 8)),
            UInt8(scaleCoeff(Int(abs(Int(p.positiveCoefficient))), bits: 8)),
            scaleValueU16(UInt16(min(Int(p.positiveSaturation) + 0x8000, 0xFFFF)), bits: 8).toU8(),
            (s2 << 4) | s1,
            0,
        ]
        return .interruptOut(endpoint: LGOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func translateForce(_ x: Int16) -> UInt8 {
        let clamped = max(Int(Int16.min), min(Int(Int16.max), Int(x)))
        return UInt8(((clamped + 0x8000) >> 8) & 0xFF)
    }

    private static func scaleValueU16(_ x: UInt16, bits: Int) -> UInt16 {
        x >> (16 - bits)
    }

    private static func scaleCoeff(_ x: Int, bits: Int) -> UInt16 {
        let doubled = min(0xFFFF, x * 2)
        return UInt16(doubled) >> (16 - bits)
    }
}

private extension UInt16 {
    func toU8() -> UInt8 { UInt8(self & 0xFF) }
}
