public struct WheelIdentity: Hashable, Sendable {
    public let vendorID: UInt16
    public let productID: UInt16
    public let bcdDevice: UInt16?
    public let model: String
    public let role: DeviceRole

    public init(vendorID: UInt16,
                productID: UInt16,
                bcdDevice: UInt16? = nil,
                model: String,
                role: DeviceRole)
    {
        self.vendorID = vendorID
        self.productID = productID
        self.bcdDevice = bcdDevice
        self.model = model
        self.role = role
    }
}

public enum DeviceRole: String, Sendable, Hashable {
    case wheelBase
    case shifter
    case pedals
    case handbrake
}

public enum WheelMode: String, Sendable, Hashable {
    case boot
    case firmware
}
