import Foundation
import WheelProtocol

final class MockUSBTransport: USBTransport, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockUSBTransport")
    private var sent: [USBPacket] = []
    private var inboundQueue: [(endpoint: UInt8, bytes: [UInt8])] = []
    private(set) var closed = false

    func send(_ packet: USBPacket) throws {
        queue.sync { sent.append(packet) }
    }

    func readInterruptIn(endpoint: UInt8, length: Int, timeoutMs: UInt32) throws -> [UInt8] {
        try queue.sync {
            guard let head = inboundQueue.first else { throw USBError.timeout }
            inboundQueue.removeFirst()
            if head.endpoint != endpoint {
                throw USBError.shortTransfer(expected: Int(endpoint), actual: Int(head.endpoint))
            }
            return Array(head.bytes.prefix(length))
        }
    }

    func close() {
        queue.sync { closed = true }
    }

    func sentPackets() -> [USBPacket] { queue.sync { sent } }
    func queueInbound(endpoint: UInt8, bytes: [UInt8]) {
        queue.sync { inboundQueue.append((endpoint, bytes)) }
    }
}

final class NoopDelegate: DeviceDriverDelegate, @unchecked Sendable {
    func driver(_ driver: any DeviceDriver, didEmitHIDReport bytes: [UInt8]) {}
    func driver(_ driver: any DeviceDriver, didFailWith error: Error) {}
    func driverDidRequestRematch(_ driver: any DeviceDriver) {}
}
