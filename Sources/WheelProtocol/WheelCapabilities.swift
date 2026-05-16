public struct WheelCapabilities: Sendable, Hashable {
    public let role: DeviceRole
    public let buttonCount: UInt8
    public let pedalCount: UInt8
    public let hasHat: Bool
    public let hasClutch: Bool
    public let hasHandbrake: Bool
    public let rangeMinDegrees: UInt16
    public let rangeMaxDegrees: UInt16
    public let supportedEffects: Set<EffectKind>
    public let supportsAutocenter: Bool
    public let supportsGain: Bool

    public init(role: DeviceRole,
                buttonCount: UInt8,
                pedalCount: UInt8,
                hasHat: Bool = false,
                hasClutch: Bool = false,
                hasHandbrake: Bool = false,
                rangeMinDegrees: UInt16 = 0,
                rangeMaxDegrees: UInt16 = 0,
                supportedEffects: Set<EffectKind> = [],
                supportsAutocenter: Bool = false,
                supportsGain: Bool = false)
    {
        self.role = role
        self.buttonCount = buttonCount
        self.pedalCount = pedalCount
        self.hasHat = hasHat
        self.hasClutch = hasClutch
        self.hasHandbrake = hasHandbrake
        self.rangeMinDegrees = rangeMinDegrees
        self.rangeMaxDegrees = rangeMaxDegrees
        self.supportedEffects = supportedEffects
        self.supportsAutocenter = supportsAutocenter
        self.supportsGain = supportsGain
    }
}

public enum EffectKind: UInt8, Sendable, Hashable, CaseIterable {
    case constant = 1
    case ramp = 2
    case squarePeriodic = 3
    case sinePeriodic = 4
    case trianglePeriodic = 5
    case sawtoothUpPeriodic = 6
    case sawtoothDownPeriodic = 7
    case spring = 8
    case damper = 9
    case friction = 10
    case inertia = 11
    case customForceData = 12
}
