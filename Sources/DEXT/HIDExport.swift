#if canImport(HIDDriverKit)

import DriverKit
import HIDDriverKit
import HIDDescriptors
import WheelProtocol
import os.log

final class HIDExport: IOUserHIDDevice {

    weak var session: WheelSession?
    private let descriptorBytes: [UInt8]
    private let log = OSLog(subsystem: "it.allard.macoswheels.dext", category: "HIDExport")

    init(capabilities: WheelCapabilities, session: WheelSession) {
        self.descriptorBytes = DescriptorBuilder.build(for: capabilities)
        self.session = session
        super.init()
    }

    override func newReportDescriptor() -> Data {
        Data(descriptorBytes)
    }

    override func setReport(_ report: IOMemoryDescriptor,
                            type: IOHIDReportType,
                            options: UInt32,
                            completionTimeout: UInt64) -> IOReturn
    {
        guard let bytes = report.bytes else { return kIOReturnBadArgument }
        guard !bytes.isEmpty else { return kIOReturnBadArgument }
        let reportID = bytes[0]
        let payload = Array(bytes.dropFirst())
        session?.ingest(reportID: reportID, payload: payload)
        return kIOReturnSuccess
    }

    func handleInputReport(_ bytes: [UInt8]) {
        let descriptor = IOBufferMemoryDescriptor.withBytes(bytes)
        _ = handleReport(timestamp: 0, report: descriptor, reportType: .input, options: 0)
    }
}

#endif
