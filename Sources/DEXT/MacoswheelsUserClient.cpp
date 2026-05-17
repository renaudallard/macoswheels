#include <os/log.h>
#include <stdint.h>
#include <string.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/IOService.h>
#include <DriverKit/IOUserClient.h>
#include <DriverKit/OSNumber.h>

#include "MacoswheelsUserClient.h"
#include "MacoswheelsDriver.h"

#define Log(fmt, ...) \
    os_log(OS_LOG_DEFAULT, "MacoswheelsUserClient: " fmt, ##__VA_ARGS__)

enum {
    kSelectorGetDeviceList    = 0,
    kSelectorGetInfo          = 1,
    kSelectorGetCapabilities  = 2,
    kSelectorSetRotationRange = 3,
    kSelectorSetAutocenter    = 4,
    kSelectorSetGain          = 5,
    kSelectorReset            = 6,
    kSelectorVendorCommand    = 7,
};

struct MacoswheelsUserClient_IVars {
    MacoswheelsDriver *driver;
};

bool MacoswheelsUserClient::init() {
    bool ok = super::init();
    if (!ok) return false;
    ivars = IONewZero(MacoswheelsUserClient_IVars, 1);
    return ivars != NULL;
}

void MacoswheelsUserClient::free() {
    IOSafeDeleteNULL(ivars, MacoswheelsUserClient_IVars, 1);
    super::free();
}

kern_return_t IMPL(MacoswheelsUserClient, Start) {
    kern_return_t ret = Start(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) return ret;
    ivars->driver = OSDynamicCast(MacoswheelsDriver, provider);
    if (ivars->driver == NULL) {
        Log("provider is not MacoswheelsDriver");
        Stop(provider, SUPERDISPATCH);
        return kIOReturnUnsupported;
    }
    return kIOReturnSuccess;
}

kern_return_t IMPL(MacoswheelsUserClient, Stop) {
    ivars->driver = NULL;
    return Stop(provider, SUPERDISPATCH);
}

kern_return_t MacoswheelsUserClient::ExternalMethod(
    uint64_t selector,
    IOUserClientMethodArguments *arguments,
    const IOUserClientMethodDispatch *dispatch,
    OSObject *target,
    void *reference)
{
    MacoswheelsDriver *driver = ivars->driver;
    if (driver == NULL) return kIOReturnNotReady;

    switch (selector) {
    case kSelectorSetRotationRange: {
        if (arguments->scalarInputCount < 1) return kIOReturnBadArgument;
        uint16_t degrees = (uint16_t) arguments->scalarInput[0];
        return driver->SetRotationRange(degrees);
    }
    case kSelectorSetAutocenter: {
        if (arguments->scalarInputCount < 1) return kIOReturnBadArgument;
        uint8_t pct = (uint8_t) arguments->scalarInput[0];
        return driver->SetAutocenter(pct);
    }
    case kSelectorSetGain: {
        if (arguments->scalarInputCount < 1) return kIOReturnBadArgument;
        uint8_t pct = (uint8_t) arguments->scalarInput[0];
        return driver->SetGain(pct);
    }
    case kSelectorReset:
        return driver->ResetWheel();

    case kSelectorGetDeviceList:
    case kSelectorGetInfo:
    case kSelectorGetCapabilities:
    case kSelectorVendorCommand:
        return kIOReturnUnsupported;

    default:
        Log("unknown selector %llu", selector);
        return kIOReturnBadArgument;
    }
}
