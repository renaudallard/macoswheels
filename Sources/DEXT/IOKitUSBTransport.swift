#if canImport(DriverKit) && canImport(USBDriverKit)

import DriverKit
import USBDriverKit
import WheelProtocol
import os.log

final class IOKitUSBTransport: USBTransport, @unchecked Sendable {

    private let interface: IOUSBHostInterface
    private let outPipe: IOUSBHostPipe
    private let inPipe: IOUSBHostPipe
    private let log = OSLog(subsystem: "it.allard.macoswheels.dext", category: "USBTransport")

    init(interface: IOUSBHostInterface, inPipe: IOUSBHostPipe, outPipe: IOUSBHostPipe) {
        self.interface = interface
        self.inPipe = inPipe
        self.outPipe = outPipe
    }

    func send(_ packet: USBPacket) throws {
        switch packet {
        case .control(let setup, let payload):
            var req = IOUSBDeviceRequest(
                bmRequestType: setup.bmRequestType,
                bRequest: setup.bRequest,
                wValue: setup.wValue,
                wIndex: setup.wIndex,
                wLength: UInt16(payload.count))
            let buf = payload
            let rc = interface.deviceRequest(&req, data: buf, completionTimeout: 1000)
            guard rc == kIOReturnSuccess else {
                os_log("control transfer failed rc=0x%x", log: log, type: .error, rc)
                throw USBError.other(code: rc)
            }
        case .interruptOut(_, let bytes):
            let rc = outPipe.io(data: bytes, completionTimeout: 1000)
            guard rc == kIOReturnSuccess else {
                os_log("interrupt-out failed rc=0x%x", log: log, type: .error, rc)
                throw USBError.other(code: rc)
            }
        }
    }

    func readInterruptIn(endpoint: UInt8, length: Int, timeoutMs: UInt32) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: length)
        let (rc, n) = inPipe.io(into: &buf, completionTimeout: timeoutMs)
        guard rc == kIOReturnSuccess else {
            if rc == kIOReturnTimeout { throw USBError.timeout }
            throw USBError.other(code: rc)
        }
        buf.removeLast(buf.count - n)
        return buf
    }

    func close() {
        interface.close()
    }
}

#endif
