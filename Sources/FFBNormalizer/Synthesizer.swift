import WheelProtocol

public enum Synthesizer {

    public static func downgrade(_ effect: NormalizedEffect,
                                 supported: Set<EffectKind>) -> NormalizedEffect?
    {
        switch effect {
        case .constant:
            return supported.contains(.constant) ? effect : nil

        case .ramp:
            return supported.contains(.ramp) ? effect : nil

        case .periodic(_, let kind, _, _, _):
            return supported.contains(kind) ? effect : nil

        case .spring:
            return supported.contains(.spring) ? effect : nil

        case .damper:
            return supported.contains(.damper) ? effect : nil

        case .friction:
            return supported.contains(.friction) ? effect : nil

        case .inertia(let slot, let params):
            if supported.contains(.inertia) { return effect }
            if supported.contains(.damper) { return .damper(slot: slot, params: params) }
            return nil

        case .customForceData:
            return supported.contains(.customForceData) ? effect : nil
        }
    }
}
