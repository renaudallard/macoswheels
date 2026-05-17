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
        guard let driver = driver else { return kIOReturnNotReady }
        switch sel {
        case .getDeviceList:    return handleGetDeviceList(driver: driver)
        case .getInfo:          return handleGetInfo(driver: driver)
        case .getCapabilities:  return handleGetCapabilities(driver: driver)
        case .setRotationRange: return handleSetRange(driver: driver)
        case .setAutocenter:    return handleSetAutocenter(driver: driver)
        case .setGain:          return handleSetGain(driver: driver)
        case .reset:            return handleReset(driver: driver)
        case .vendorCommand:    return kIOReturnUnsupported
        }
    }

    private func handleGetDeviceList(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleGetInfo(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleGetCapabilities(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleSetRange(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleSetAutocenter(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleSetGain(driver: MacoswheelsDriver) -> IOReturn {
        kIOReturnSuccess
    }
    private func handleReset(driver: MacoswheelsDriver) -> IOReturn {
        do { try driver.session?.driver.initialize(); return kIOReturnSuccess }
        catch { return kIOReturnInternalError }
    }
}

#endif
