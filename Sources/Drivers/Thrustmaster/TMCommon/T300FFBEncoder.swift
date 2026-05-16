import WheelProtocol

public enum T300FFBEncoder {

    public static let opcodeConstant:  UInt8 = 0x6A
    public static let opcodeCondition: UInt8 = 0x64
    public static let opcodePeriodic:  UInt8 = 0x6B
    public static let opcodePlay:      UInt8 = 0x89
    public static let codePlay:        UInt8 = 0x41

    private static func waveformByte(_ kind: EffectKind) -> UInt8? {
        switch kind {
        case .squarePeriodic:       return 0x01
        case .trianglePeriodic:     return 0x02
        case .sinePeriodic:         return 0x03
        case .sawtoothUpPeriodic:   return 0x04
        case .sawtoothDownPeriodic: return 0x05
        default:                    return nil
        }
    }

    private static let conditionHardcoded: [UInt8] = [
        0xFE, 0xFF, 0xFE, 0xFF, 0xFE, 0xFF, 0xFE, 0xFF,
    ]

    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        switch effect {
        case .constant(let slot, let magnitude, let duration, _, let env):
            return [constantUpload(slot: slot,
                                   magnitude: magnitude,
                                   duration: duration,
                                   envelope: env)]
        case .spring(let slot, let p):
            return [conditionUpload(slot: slot, params: p, kind: .spring)]
        case .damper(let slot, let p):
            return [conditionUpload(slot: slot, params: p, kind: .damper)]
        case .friction(let slot, let p):
            return [conditionUpload(slot: slot, params: p, kind: .friction)]
        case .inertia(let slot, let p):
            return [conditionUpload(slot: slot, params: p, kind: .inertia)]
        case .periodic(let slot, let kind, let params, let duration, let env):
            guard let wave = Self.waveformByte(kind) else { throw DriverError.effectNotSupported(kind) }
            return [periodicUpload(slot: slot,
                                   waveform: wave,
                                   params: params,
                                   duration: duration,
                                   envelope: env)]
        case .ramp, .customForceData:
            throw DriverError.notImplemented
        }
    }

    public static func playPacket(slot: UInt8, repeats: UInt16 = 1) -> USBPacket {
        let count = (repeats == 0 || repeats >= 0xFFFF) ? UInt16(0) : repeats
        let bytes: [UInt8] = [
            0x00, slot &+ 1, opcodePlay,
            codePlay,
            UInt8(count & 0xFF), UInt8(count >> 8),
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    public static func stopPacket(slot: UInt8) -> USBPacket {
        let bytes: [UInt8] = [0x00, slot &+ 1, opcodePlay, 0x00]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private enum ConditionKind {
        case spring, damper, friction, inertia
        var typeByte: UInt8 { self == .spring ? 0x06 : 0x07 }
        var maxSaturation: UInt16 { self == .spring ? 0x6AA6 : 0x7FFC }
    }

    private static func constantUpload(slot: UInt8,
                                       magnitude: Int16,
                                       duration: UInt32,
                                       envelope: Envelope?) -> USBPacket
    {
        let level = Int16(max(-16385, min(16381, Int(magnitude) / 2)))
        let dur = duration == 0 ? UInt16(0xFFFF) : UInt16(min(duration, UInt32(UInt16.max - 1)))

        var bytes: [UInt8] = [0x00, slot &+ 1, opcodeConstant]
        bytes += le16(UInt16(bitPattern: level))
        bytes += envelopeBytes(envelope)
        bytes += [0x00]
        bytes += timingBytes(durationMs: dur, offsetMs: 0)
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func conditionUpload(slot: UInt8,
                                        params: ConditionParams,
                                        kind: ConditionKind) -> USBPacket
    {
        let rightCoeff = Int16(max(-32767, min(32767, Int(params.positiveCoefficient))))
        let leftCoeff  = Int16(max(-32767, min(32767, Int(params.negativeCoefficient))))
        let halfDead = Int(params.deadBand) / 2
        let rightDead = Int16(max(-0x7FFF, min(0x7FFF, Int(params.centerOffset) + halfDead)))
        let leftDead  = Int16(max(-0x7FFF, min(0x7FFF, Int(params.centerOffset) - halfDead)))
        let rightSat = scaleSaturation(params.positiveSaturation, max: kind.maxSaturation)
        let leftSat  = scaleSaturation(params.negativeSaturation, max: kind.maxSaturation)

        var bytes: [UInt8] = [0x00, slot &+ 1, opcodeCondition]
        bytes += le16(UInt16(bitPattern: rightCoeff))
        bytes += le16(UInt16(bitPattern: leftCoeff))
        bytes += le16(UInt16(bitPattern: rightDead))
        bytes += le16(UInt16(bitPattern: leftDead))
        bytes += le16(rightSat)
        bytes += le16(leftSat)
        bytes += conditionHardcoded
        bytes += le16(kind.maxSaturation)
        bytes += le16(kind.maxSaturation)
        bytes += [kind.typeByte]
        bytes += timingBytes(durationMs: 0xFFFF, offsetMs: 0)
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func periodicUpload(slot: UInt8,
                                       waveform: UInt8,
                                       params: PeriodicParams,
                                       duration: UInt32,
                                       envelope: Envelope?) -> USBPacket
    {
        let dur = duration == 0 ? UInt16(0xFFFF) : UInt16(min(duration, UInt32(UInt16.max - 1)))
        var bytes: [UInt8] = [0x00, slot &+ 1, opcodePeriodic]
        bytes += le16(UInt16(bitPattern: params.magnitude))
        bytes += le16(UInt16(bitPattern: params.offset))
        bytes += le16(params.phase)
        bytes += le16(UInt16(min(params.period, UInt32(UInt16.max))))
        bytes += le16(0x8000)
        bytes += envelopeBytes(envelope)
        bytes += [waveform]
        bytes += timingBytes(durationMs: dur, offsetMs: 0)
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func scaleSaturation(_ sat: Int16, max: UInt16) -> UInt16 {
        if sat == 0 { return max }
        return UInt16(UInt32(UInt16(bitPattern: sat)) * UInt32(max) / 0xFFFF)
    }

    private static func envelopeBytes(_ env: Envelope?) -> [UInt8] {
        guard let e = env else { return [0, 0, 0, 0, 0, 0, 0, 0] }
        let attackLen = UInt16(min(e.attackTime, UInt32(UInt16.max)))
        let attackLvl = UInt16(bitPattern: e.attackLevel)
        let fadeLen   = UInt16(min(e.fadeTime, UInt32(UInt16.max)))
        let fadeLvl   = UInt16(bitPattern: e.fadeLevel)
        return le16(attackLen) + le16(attackLvl) + le16(fadeLen) + le16(fadeLvl)
    }

    private static func timingBytes(durationMs: UInt16, offsetMs: UInt16) -> [UInt8] {
        var b: [UInt8] = []
        b += [0x4F]
        b += le16(durationMs)
        b += [0x00, 0x00]
        b += le16(offsetMs)
        b += [0x00]
        b += [0xFF, 0xFF]
        return b
    }

    private static func le16(_ v: UInt16) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8(v >> 8)]
    }
}
