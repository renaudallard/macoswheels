import Foundation

public enum UserClientSelector: UInt32 {
    case getDeviceList    = 0
    case getInfo          = 1
    case getCapabilities  = 2
    case setRotationRange = 3
    case setAutocenter    = 4
    case setGain          = 5
    case reset            = 6
    case vendorCommand    = 7
}

public struct WheelInfo: Sendable, Hashable, Codable {
    public let registryID: UInt64
    public let vendorID: UInt16
    public let productID: UInt16
    public let model: String
    public let firmwareVersion: String
    public let currentRangeDegrees: UInt16
    public let currentAutocenter: UInt8
    public let currentGain: UInt8
    public init(registryID: UInt64,
                vendorID: UInt16,
                productID: UInt16,
                model: String,
                firmwareVersion: String,
                currentRangeDegrees: UInt16,
                currentAutocenter: UInt8,
                currentGain: UInt8)
    {
        self.registryID = registryID
        self.vendorID = vendorID
        self.productID = productID
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.currentRangeDegrees = currentRangeDegrees
        self.currentAutocenter = currentAutocenter
        self.currentGain = currentGain
    }
}

public struct DeviceListEntry: Sendable, Hashable, Codable {
    public let registryID: UInt64
    public let role: String
    public let model: String
    public let vendorID: UInt16
    public let productID: UInt16
    public init(registryID: UInt64, role: String, model: String,
                vendorID: UInt16, productID: UInt16)
    {
        self.registryID = registryID
        self.role = role
        self.model = model
        self.vendorID = vendorID
        self.productID = productID
    }
}

public struct SetRangeRequest: Sendable, Hashable, Codable {
    public let registryID: UInt64
    public let degrees: UInt16
    public init(registryID: UInt64, degrees: UInt16) {
        self.registryID = registryID
        self.degrees = degrees
    }
}

public struct SetByteRequest: Sendable, Hashable, Codable {
    public let registryID: UInt64
    public let value: UInt8
    public init(registryID: UInt64, value: UInt8) {
        self.registryID = registryID
        self.value = value
    }
}

public let bundleIdentifier = "it.allard.macoswheels"
public let driverServiceClassName = "MacoswheelsDriver"
