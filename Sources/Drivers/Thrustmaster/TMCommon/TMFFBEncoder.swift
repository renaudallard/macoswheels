#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum TMFFBEncoder {

    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        switch effect {
        case .constant(let slot, let magnitude, let duration, _, let env):
            return constantUpload(slot: slot,
                                  magnitude: magnitude,
                                  duration: duration,
                                  envelope: env)
        case .periodic(let slot, let kind, let p, let duration, let env):
            return periodicUpload(slot: slot,
                                  kind: kind,
                                  params: p,
                                  duration: duration,
                                  envelope: env)
        case .spring(let slot, let c):
            return conditionUpload(slot: slot, commit: .spring, params: c)
        case .damper(let slot, let c):
            return conditionUpload(slot: slot, commit: .damper, params: c)
        case .friction:
            throw DriverError.effectNotSupported(.friction)
        case .inertia:
            throw DriverError.effectNotSupported(.inertia)
        case .ramp:
            throw DriverError.effectNotSupported(.ramp)
        case .customForceData:
            throw DriverError.effectNotSupported(.customForceData)
        }
    }

    public static func startEffectPacket(slot: UInt8, repeats: UInt8 = 1) -> USBPacket {
        .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                      bytes: [0x60, slot, TMOpcode.EffectControl.play.rawValue, repeats])
    }

    public static func stopEffectPacket(slot: UInt8) -> USBPacket {
        .interruptOut(endpoint: TMOpcode.interruptOutEndpoint,
                      bytes: [0x60, slot, TMOpcode.EffectControl.stop.rawValue, 0x00])
    }

    private static func constantUpload(slot: UInt8,
                                       magnitude: Int16,
                                       duration: UInt32,
                                       envelope: Envelope?) -> [USBPacket]
    {
        let level = Int8(truncatingIfNeeded: max(-127, min(127, Int(magnitude / 256))))
        let firstPkt = firstPacket(slot: slot,
                                   code: .constantPeriodic,
                                   envelope: envelope)
        let updatePkt = updateConstantPacket(slot: slot, level: level)
        let commitPkt = commitPacket(slot: slot,
                                     commit: .constant,
                                     durationMs: UInt16(min(duration, UInt32(UInt16.max))))
        return [firstPkt, updatePkt, commitPkt]
    }

    private static func periodicUpload(slot: UInt8,
                                       kind: EffectKind,
                                       params: PeriodicParams,
                                       duration: UInt32,
                                       envelope: Envelope?) -> [USBPacket]
    {
        let commit: TMOpcode.CommitCode
        switch kind {
        case .sinePeriodic:         commit = .sine
        case .squarePeriodic:       commit = .square
        case .trianglePeriodic:     commit = .triangle
        case .sawtoothUpPeriodic:   commit = .sawUp
        case .sawtoothDownPeriodic: commit = .sawDown
        default:                    commit = .sine
        }
        let firstPkt = firstPacket(slot: slot, code: .constantPeriodic, envelope: envelope)
        let updatePkt = updatePeriodicPacket(slot: slot, params: params)
        let commitPkt = commitPacket(slot: slot,
                                     commit: commit,
                                     durationMs: UInt16(min(duration, UInt32(UInt16.max))))
        return [firstPkt, updatePkt, commitPkt]
    }

    private static func conditionUpload(slot: UInt8,
                                        commit: TMOpcode.CommitCode,
                                        params: ConditionParams) -> [USBPacket]
    {
        let firstPkt = firstPacket(slot: slot, code: .condition, envelope: nil)
        let updatePkt = updateConditionPacket(slot: slot, params: params, commit: commit)
        let commitPkt = commitPacket(slot: slot, commit: commit, durationMs: 0)
        return [firstPkt, updatePkt, commitPkt]
    }

    private static func firstPacket(slot: UInt8,
                                    code: TMOpcode.FirstCode,
                                    envelope: Envelope?) -> USBPacket
    {
        let pkID0 = UInt8((UInt16(slot) &* 0x1C &+ 0x1C) & 0xFF)
        let attackTime  = UInt16(min(envelope?.attackTime ?? 0, UInt32(UInt16.max)))
        let attackLevel = UInt8(truncatingIfNeeded: Int(envelope?.attackLevel ?? 0) / 256)
        let fadeTime    = UInt16(min(envelope?.fadeTime ?? 0, UInt32(UInt16.max)))
        let fadeLevel   = UInt8(truncatingIfNeeded: Int(envelope?.fadeLevel ?? 0) / 256)
        let bytes: [UInt8] = [
            0xF0, pkID0, code.rawValue,
            UInt8(attackTime & 0xFF), UInt8(attackTime >> 8),
            attackLevel,
            UInt8(fadeTime & 0xFF), UInt8(fadeTime >> 8),
            fadeLevel,
            0x46, 0x54,
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func updateConstantPacket(slot: UInt8, level: Int8) -> USBPacket {
        let pkID1 = UInt8((UInt16(slot) &* 0x1C &+ 0x0E) & 0xFF)
        let bytes: [UInt8] = [
            TMOpcode.EffectClass.constant.rawValue,
            pkID1, 0x4F,
            UInt8(bitPattern: level),
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func updatePeriodicPacket(slot: UInt8, params: PeriodicParams) -> USBPacket {
        let pkID1 = UInt8((UInt16(slot) &* 0x1C &+ 0x0E) & 0xFF)
        let mag = Int8(truncatingIfNeeded: Int(params.magnitude) / 256)
        let off = Int8(truncatingIfNeeded: Int(params.offset) / 256)
        let phase = UInt8(truncatingIfNeeded: Int(params.phase) / 256)
        let period = UInt16(min(params.period, UInt32(UInt16.max)))
        let bytes: [UInt8] = [
            TMOpcode.EffectClass.periodic.rawValue,
            pkID1, 0x4F,
            UInt8(bitPattern: mag),
            UInt8(bitPattern: off),
            phase,
            UInt8(period & 0xFF), UInt8(period >> 8),
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func updateConditionPacket(slot: UInt8,
                                              params: ConditionParams,
                                              commit: TMOpcode.CommitCode) -> USBPacket
    {
        let pkID1 = UInt8((UInt16(slot) &* 0x1C &+ 0x0E) & 0xFF)
        let satMax: Int = (commit == .spring) ? 0x54 : 0x64
        let rightCoeff = Int8(truncatingIfNeeded: Int(params.positiveCoefficient) * 100 / 0x7F00)
        let leftCoeff  = Int8(truncatingIfNeeded: Int(params.negativeCoefficient) * 100 / 0x7F00)
        let rightSat = UInt8(min(Int(params.positiveSaturation) * satMax / 0x7F00, satMax))
        let leftSat  = UInt8(min(Int(params.negativeSaturation) * satMax / 0x7F00, satMax))
        let centerSigned = Int16(max(-500, min(500, Int(params.centerOffset) * 500 / 0x7F00)))
        let center = UInt16(bitPattern: centerSigned)
        let dead = UInt16(min(Int(params.deadBand) * 1000 / 0xFFFF, 1000))
        let bytes: [UInt8] = [
            TMOpcode.EffectClass.condition.rawValue,
            pkID1, 0x4F,
            UInt8(bitPattern: rightCoeff),
            UInt8(bitPattern: leftCoeff),
            UInt8(center & 0xFF), UInt8(center >> 8),
            UInt8(dead & 0xFF), UInt8(dead >> 8),
            rightSat, leftSat,
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }

    private static func commitPacket(slot: UInt8,
                                     commit: TMOpcode.CommitCode,
                                     durationMs: UInt16) -> USBPacket
    {
        let pkID0 = UInt8((UInt16(slot) &* 0x1C &+ 0x1C) & 0xFF)
        let pkID1 = UInt8((UInt16(slot) &* 0x1C &+ 0x0E) & 0xFF)
        let etype = commit.rawValue
        let bytes: [UInt8] = [
            0xF0, slot,
            UInt8(etype & 0xFF), UInt8(etype >> 8),
            UInt8(durationMs & 0xFF), UInt8(durationMs >> 8),
            0x00, 0x00, 0x00,
            pkID1, 0x00,
            pkID0, 0x00,
            0x00, 0x00,
        ]
        return .interruptOut(endpoint: TMOpcode.interruptOutEndpoint, bytes: bytes)
    }
}
