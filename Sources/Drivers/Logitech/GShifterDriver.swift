import Foundation
import WheelProtocol

public enum GShifterQuirks: ShifterQuirks {
    public static let displayName = "Logitech Driving Force Shifter"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: LGOpcode.logitechVID, productID: LGPID.drivingForceShifter,
                      model: displayName, role: .shifter),
    ]

    public static let bootIdentity: WheelIdentity? = nil

    public static let capabilities = WheelCapabilities(
        role: .shifter,
        buttonCount: 8,
        pedalCount: 0,
        hasHat: false,
        rangeMinDegrees: 0,
        rangeMaxDegrees: 0,
        supportedEffects: [],
        supportsAutocenter: false,
        supportsGain: false
    )
}

public typealias GShifterDriver = GenericShifterDriver<GShifterQuirks>
