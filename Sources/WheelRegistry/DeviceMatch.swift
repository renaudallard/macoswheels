import WheelProtocol

public struct DeviceMatchEntry: Sendable, Hashable {
    public let identity: WheelIdentity
    public let bootIdentity: WheelIdentity?
    public let mode: WheelMode
    public let driverName: String
    public init(identity: WheelIdentity,
                bootIdentity: WheelIdentity?,
                mode: WheelMode,
                driverName: String)
    {
        self.identity = identity
        self.bootIdentity = bootIdentity
        self.mode = mode
        self.driverName = driverName
    }
}

public enum DeviceMatch {

    public static let thrustmasterVID: UInt16 = 0x044F
    public static let logitechVID:    UInt16  = 0x046D

    public static let entries: [DeviceMatchEntry] = [

        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB677,
                                        model: "Thrustmaster T150 (boot)", role: .wheelBase),
            bootIdentity: nil,
            mode:         .boot,
            driverName:   "T150Boot"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB65D,
                                        model: "Thrustmaster T150", role: .wheelBase),
            bootIdentity: WheelIdentity(vendorID: thrustmasterVID, productID: 0xB677,
                                        model: "Thrustmaster T150 (boot)", role: .wheelBase),
            mode:         .firmware,
            driverName:   "T150"
        ),

        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB66E,
                                        model: "Thrustmaster T300 RS", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "T300"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB664,
                                        model: "Thrustmaster TX", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "TX"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB66F,
                                        model: "Thrustmaster TS-XW", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "TSXW"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB696,
                                        model: "Thrustmaster T248", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "T248"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB68F,
                                        model: "Thrustmaster T128", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "T128"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB66D,
                                        model: "Thrustmaster T-GT", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "TGT"
        ),

        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: thrustmasterVID, productID: 0xB687,
                                        model: "Thrustmaster TH8A shifter", role: .shifter),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "TH8A"
        ),

        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC294,
                                        model: "Logitech Driving Force / G25 / G27", role: .wheelBase),
            bootIdentity: nil,
            mode:         .boot,
            driverName:   "LG_DFGT_Boot"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC299,
                                        model: "Logitech G25 (native)", role: .wheelBase),
            bootIdentity: WheelIdentity(vendorID: logitechVID, productID: 0xC294,
                                        model: "Logitech G25 (boot)", role: .wheelBase),
            mode:         .firmware,
            driverName:   "G25"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC29B,
                                        model: "Logitech G27 (native)", role: .wheelBase),
            bootIdentity: WheelIdentity(vendorID: logitechVID, productID: 0xC294,
                                        model: "Logitech G27 (boot)", role: .wheelBase),
            mode:         .firmware,
            driverName:   "G27"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC24F,
                                        model: "Logitech G29", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "G29"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC262,
                                        model: "Logitech G920", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "G920"
        ),
        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC266,
                                        model: "Logitech G923", role: .wheelBase),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "G923"
        ),

        DeviceMatchEntry(
            identity:     WheelIdentity(vendorID: logitechVID, productID: 0xC29C,
                                        model: "Logitech G-series shifter", role: .shifter),
            bootIdentity: nil,
            mode:         .firmware,
            driverName:   "GShifter"
        ),
    ]

    public static func entry(forVID vid: UInt16, pid: UInt16) -> DeviceMatchEntry? {
        entries.first(where: { $0.identity.vendorID == vid && $0.identity.productID == pid })
    }
}
