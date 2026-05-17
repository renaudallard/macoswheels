#if canImport(DriverKit)

import DriverKit
#if canImport(ConfigPlane)
import ConfigPlane
#endif
#if canImport(WheelProtocol)
import WheelProtocol
#endif
#if canImport(Drivers)
import Drivers
#endif
import os.log

final class MacoswheelsUserClient: IOUserClient {

    weak var driver: MacoswheelsDriver?
    private let log = OSLog(subsystem: "it.allard.macoswheels.dext", category: "UserClient")

    override func externalMethod(_ selector: UInt32,
                                 dispatch: IOUserClientMethodDispatch,
                                 target: AnyObject?,
                                 reference: UnsafeMutableRawPointer?) -> IOReturn
    {
        guard let sel = UserClientSelector(rawValue: selector) else {
            return kIOReturnBadArgument
        }
        guard let driver = driver, let session = driver.session else {
            return kIOReturnNotReady
        }
        switch sel {
        case .getDeviceList:    return handleGetDeviceList(session: session)
        case .getInfo:          return handleGetInfo(session: session)
        case .getCapabilities:  return handleGetCapabilities(session: session)
        case .setRotationRange: return handleSetRange(session: session)
        case .setAutocenter:    return handleSetAutocenter(session: session)
        case .setGain:          return handleSetGain(session: session)
        case .reset:            return handleReset(session: session)
        case .vendorCommand:    return kIOReturnUnsupported
        }
    }

    private func handleGetDeviceList(session: WheelSession) -> IOReturn {
        kIOReturnSuccess
    }

    private func handleGetInfo(session: WheelSession) -> IOReturn {
        kIOReturnSuccess
    }

    private func handleGetCapabilities(session: WheelSession) -> IOReturn {
        kIOReturnSuccess
    }

    private func handleSetRange(session: WheelSession) -> IOReturn {
        guard let req = readInput(SetRangeRequest.self) else { return kIOReturnBadArgument }
        do {
            try session.driver.setRotationRange(degrees: req.degrees)
            return kIOReturnSuccess
        } catch {
            os_log("setRotationRange failed: %{public}@", log: log, type: .error, String(describing: error))
            return kIOReturnError
        }
    }

    private func handleSetAutocenter(session: WheelSession) -> IOReturn {
        guard let req = readInput(SetByteRequest.self) else { return kIOReturnBadArgument }
        do {
            try session.driver.setAutocenter(strength: req.value)
            return kIOReturnSuccess
        } catch {
            os_log("setAutocenter failed: %{public}@", log: log, type: .error, String(describing: error))
            return kIOReturnError
        }
    }

    private func handleSetGain(session: WheelSession) -> IOReturn {
        guard let req = readInput(SetByteRequest.self) else { return kIOReturnBadArgument }
        do {
            try session.driver.setGain(req.value)
            return kIOReturnSuccess
        } catch {
            os_log("setGain failed: %{public}@", log: log, type: .error, String(describing: error))
            return kIOReturnError
        }
    }

    private func handleReset(session: WheelSession) -> IOReturn {
        do {
            try session.driver.stopAllEffects()
            try session.driver.initialize()
            return kIOReturnSuccess
        } catch {
            os_log("reset failed: %{public}@", log: log, type: .error, String(describing: error))
            return kIOReturnError
        }
    }

    private func readInput<T>(_ type: T.Type) -> T? {
        nil
    }
}

#endif
