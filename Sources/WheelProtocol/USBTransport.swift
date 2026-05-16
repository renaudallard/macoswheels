import Foundation

public struct USBControlSetup: Sendable, Hashable {
    public let bmRequestType: UInt8
    public let bRequest: UInt8
    public let wValue: UInt16
    public let wIndex: UInt16
    public init(bmRequestType: UInt8, bRequest: UInt8, wValue: UInt16, wIndex: UInt16) {
        self.bmRequestType = bmRequestType
        self.bRequest = bRequest
        self.wValue = wValue
        self.wIndex = wIndex
    }
}

public enum USBPacket: Sendable, Hashable {
    case control(USBControlSetup, payload: [UInt8])
    case interruptOut(endpoint: UInt8, bytes: [UInt8])
}

public protocol USBTransport: AnyObject, Sendable {
    func send(_ packet: USBPacket) throws
    func readInterruptIn(endpoint: UInt8, length: Int, timeoutMs: UInt32) throws -> [UInt8]
    func close()
}

public enum USBError: Error, Sendable, Hashable {
    case notOpen
    case stall
    case timeout
    case shortTransfer(expected: Int, actual: Int)
    case unsupported
    case other(code: Int32)
}
