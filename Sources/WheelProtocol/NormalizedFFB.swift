import Foundation

public struct Envelope: Sendable, Hashable {
    public let attackLevel: Int16
    public let attackTime: UInt32
    public let fadeLevel: Int16
    public let fadeTime: UInt32
    public init(attackLevel: Int16, attackTime: UInt32, fadeLevel: Int16, fadeTime: UInt32) {
        self.attackLevel = attackLevel
        self.attackTime = attackTime
        self.fadeLevel = fadeLevel
        self.fadeTime = fadeTime
    }
}

public struct ConditionParams: Sendable, Hashable {
    public let positiveCoefficient: Int16
    public let negativeCoefficient: Int16
    public let positiveSaturation: Int16
    public let negativeSaturation: Int16
    public let deadBand: UInt16
    public let centerOffset: Int16
    public init(positiveCoefficient: Int16, negativeCoefficient: Int16,
                positiveSaturation: Int16, negativeSaturation: Int16,
                deadBand: UInt16, centerOffset: Int16)
    {
        self.positiveCoefficient = positiveCoefficient
        self.negativeCoefficient = negativeCoefficient
        self.positiveSaturation = positiveSaturation
        self.negativeSaturation = negativeSaturation
        self.deadBand = deadBand
        self.centerOffset = centerOffset
    }
}

public struct PeriodicParams: Sendable, Hashable {
    public let magnitude: Int16
    public let offset: Int16
    public let phase: UInt16
    public let period: UInt32
    public init(magnitude: Int16, offset: Int16, phase: UInt16, period: UInt32) {
        self.magnitude = magnitude
        self.offset = offset
        self.phase = phase
        self.period = period
    }
}

public enum NormalizedEffect: Sendable, Hashable {
    case constant(slot: UInt8, magnitude: Int16, duration: UInt32, direction: UInt16, envelope: Envelope?)
    case ramp(slot: UInt8, start: Int16, end: Int16, duration: UInt32, envelope: Envelope?)
    case periodic(slot: UInt8, kind: EffectKind, params: PeriodicParams, duration: UInt32, envelope: Envelope?)
    case spring(slot: UInt8, params: ConditionParams)
    case damper(slot: UInt8, params: ConditionParams)
    case friction(slot: UInt8, params: ConditionParams)
    case inertia(slot: UInt8, params: ConditionParams)
    case customForceData(slot: UInt8, samplePeriod: UInt32, samples: [Int16])
}
