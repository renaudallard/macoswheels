#if canImport(DriverKit)

import DriverKit
#if canImport(WheelProtocol)
import WheelProtocol
#endif
#if canImport(HIDDescriptors)
import HIDDescriptors
#endif
#if canImport(FFBNormalizer)
import FFBNormalizer
#endif
#if canImport(Drivers)
import Drivers
#endif
import os.log

final class WheelSession: DeviceDriverDelegate, @unchecked Sendable {

    let driver: any DeviceDriver
    let transport: any USBTransport
    let parser = PIDParser()
    var hidExport: HIDExport?
    private let log = OSLog(subsystem: "it.allard.macoswheels.dext", category: "WheelSession")

    init(driver: any DeviceDriver, transport: any USBTransport) {
        self.driver = driver
        self.transport = transport
    }

    func start() throws {
        try driver.probe()
        try driver.claim()
        try driver.initialize()
        try driver.startReadLoop()
    }

    func ingest(reportID: UInt8, payload: [UInt8]) {
        do {
            guard let normalized = try parser.parse(reportID: reportID, payload: payload) else {
                return
            }
            let caps = type(of: driver).capabilities
            guard let final = Synthesizer.downgrade(normalized, supported: caps.supportedEffects) else {
                os_log("effect dropped (not supported)", log: log, type: .info)
                return
            }
            let packets = try driver.encode(final)
            for p in packets { try transport.send(p) }
        } catch {
            os_log("ingest error: %{public}@", log: log, type: .error, String(describing: error))
        }
    }

    func driver(_ driver: any DeviceDriver, didEmitHIDReport bytes: [UInt8]) {
        hidExport?.handleInputReport(bytes)
    }

    func driver(_ driver: any DeviceDriver, didFailWith error: Error) {
        os_log("driver failed: %{public}@", log: log, type: .error, String(describing: error))
    }

    func driverDidRequestRematch(_ driver: any DeviceDriver) {
        os_log("driver requested rematch", log: log, type: .info)
    }
}

#endif
