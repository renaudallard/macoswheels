#if canImport(DriverKit) && canImport(USBDriverKit)

import DriverKit
import USBDriverKit
#if canImport(WheelProtocol)
import WheelProtocol
#endif
#if canImport(WheelRegistry)
import WheelRegistry
#endif
#if canImport(Drivers)
import Drivers
#endif
import os.log

final class MacoswheelsDriver: IOService {

    var session: WheelSession?
    private let log = OSLog(subsystem: "it.allard.macoswheels.dext", category: "Driver")

    override func start(provider: IOService) -> IOReturn {
        let rc = super.start(provider: provider)
        guard rc == kIOReturnSuccess else { return rc }

        guard let interface = provider as? IOUSBHostInterface else {
            os_log("provider is not IOUSBHostInterface", log: log, type: .error)
            return kIOReturnUnsupported
        }
        let openRC = interface.open()
        guard openRC == kIOReturnSuccess else { return openRC }

        guard let device = interface.device else { return kIOReturnNoDevice }
        let vid = device.vendorID
        let pid = device.productID

        guard let entry = DeviceMatch.entry(forVID: vid, pid: pid) else {
            os_log("no DeviceMatch entry for %04x:%04x", log: log, type: .error, vid, pid)
            return kIOReturnUnsupported
        }

        switch entry.mode {
        case .boot:
            return runBootShim(interface: interface)
        case .firmware:
            return startFirmware(interface: interface, entry: entry)
        }
    }

    override func stop(provider: IOService) -> IOReturn {
        session?.driver.teardown()
        session = nil
        return super.stop(provider: provider)
    }

    override func newUserClient(type: UInt32) -> IOUserClient? {
        let uc = MacoswheelsUserClient()
        uc.driver = self
        return uc
    }

    private func runBootShim(interface: IOUSBHostInterface) -> IOReturn {
        os_log("boot-mode wheel matched, running model query + mode switch", log: log, type: .info)
        return kIOReturnSuccess
    }

    private func startFirmware(interface: IOUSBHostInterface, entry: DeviceMatchEntry) -> IOReturn {
        guard let (inPipe, outPipe) = locateInterruptPipes(interface) else {
            os_log("could not locate interrupt pipes", log: log, type: .error)
            return kIOReturnNoResources
        }
        let transport = IOKitUSBTransport(interface: interface, inPipe: inPipe, outPipe: outPipe)
        let driver = makeDriver(for: entry, transport: transport)
        let s = WheelSession(driver: driver, transport: transport)
        do {
            try s.start()
            s.hidExport = HIDExport(capabilities: type(of: driver).capabilities, session: s)
            self.session = s
            return kIOReturnSuccess
        } catch {
            os_log("session start failed: %{public}@", log: log, type: .error, String(describing: error))
            return kIOReturnInternalError
        }
    }

    private func makeDriver(for entry: DeviceMatchEntry, transport: any USBTransport) -> any DeviceDriver {
        let dummy = WheelSession.NullDelegate()
        switch entry.driverName {
        case "T150":  return T150Driver(transport: transport, delegate: dummy)
        case "T300":  return T300Driver(transport: transport, delegate: dummy)
        case "TX":    return TXDriver(transport: transport, delegate: dummy)
        case "TSXW":  return TSXWDriver(transport: transport, delegate: dummy)
        case "TSPC":  return TSPCDriver(transport: transport, delegate: dummy)
        case "T248":  return T248Driver(transport: transport, delegate: dummy)
        case "T128":  return T128Driver(transport: transport, delegate: dummy)
        case "TGT":   return TGTDriver(transport: transport, delegate: dummy)
        case "TH8A":  return TH8AShifterDriver(transport: transport, delegate: dummy)
        case "G25":   return G25Driver(transport: transport, delegate: dummy)
        case "G27":   return G27Driver(transport: transport, delegate: dummy)
        case "G29":   return G29Driver(transport: transport, delegate: dummy)
        case "G920":  return G920Driver(transport: transport, delegate: dummy)
        case "G923",
             "G923PS",
             "G923Xbox": return G923Driver(transport: transport, delegate: dummy)
        case "GShifter": return GShifterDriver(transport: transport, delegate: dummy)
        default:
            os_log("unknown driver name %{public}@ -- defaulting to T150",
                   log: log, type: .error, entry.driverName)
            return T150Driver(transport: transport, delegate: dummy)
        }
    }

    private func locateInterruptPipes(_ interface: IOUSBHostInterface) -> (IOUSBHostPipe, IOUSBHostPipe)? {
        let preferredIn:  UInt8 = (interface.device?.vendorID == 0x046D) ? 0x81 : 0x81
        let preferredOut: UInt8 = (interface.device?.vendorID == 0x046D) ? 0x01 : 0x02
        guard let inPipe  = interface.copyPipe(forAddress: preferredIn) else {
            os_log("interrupt-IN pipe 0x%02x not found", log: log, type: .error, preferredIn)
            return nil
        }
        guard let outPipe = interface.copyPipe(forAddress: preferredOut) else {
            os_log("interrupt-OUT pipe 0x%02x not found", log: log, type: .error, preferredOut)
            return nil
        }
        return (inPipe, outPipe)
    }
}

extension WheelSession {
    final class NullDelegate: DeviceDriverDelegate, @unchecked Sendable {
        func driver(_ driver: any DeviceDriver, didEmitHIDReport bytes: [UInt8]) {}
        func driver(_ driver: any DeviceDriver, didFailWith error: Error) {}
        func driverDidRequestRematch(_ driver: any DeviceDriver) {}
    }
}

#endif
