import Foundation
import WheelProtocol

public enum TH8AShifterQuirks: ShifterQuirks {
    public static let displayName = "Thrustmaster TH8A shifter"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB687,
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

public typealias TH8AShifterDriver = GenericShifterDriver<TH8AShifterQuirks>
