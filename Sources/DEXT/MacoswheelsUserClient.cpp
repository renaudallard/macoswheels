#include <os/log.h>
#include <stdint.h>
#include <string.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/IOService.h>
#include <DriverKit/IOMemoryDescriptor.h>
#include <DriverKit/IOUserClient.h>
#include <DriverKit/OSData.h>
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

// Layouts match Sources/ConfigPlane/UserClientAPI.swift exactly. Swift packs
// these structs without trailing padding, so __attribute__((packed)) on the
// C side reads the same bytes.
struct __attribute__((packed)) SetRangeReq {
    uint64_t registryID;
    uint16_t degrees;
};

struct __attribute__((packed)) SetByteReq {
    uint64_t registryID;
    uint8_t  value;
};

static const uint8_t *mapStructureInput(IOUserClientMethodArguments *args,
                                        size_t expected, uint8_t *scratch)
{
    if (!args) return NULL;
    if (args->structureInput == NULL) {
        // Newer DriverKit places small struct payloads in structureInput as
        // an OSData; older paths use structureInputDescriptor. Try both.
        if (args->structureInputDescriptor == NULL) return NULL;
        uint64_t addr = 0, len = 0;
        args->structureInputDescriptor->Map(0, 0, 0, 0, &addr, &len);
        if (!addr || len < expected) return NULL;
        memcpy(scratch, (const void *)(uintptr_t)addr, expected);
        return scratch;
    }
    if (args->structureInput->getLength() < expected) return NULL;
    return (const uint8_t *)args->structureInput->getBytesNoCopy();
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

    uint8_t scratch[16] = {0};

    switch (selector) {
    case kSelectorSetRotationRange: {
        const uint8_t *bytes = mapStructureInput(
            arguments, sizeof(SetRangeReq), scratch);
        if (!bytes) return kIOReturnBadArgument;
        const SetRangeReq *req = (const SetRangeReq *)bytes;
        return driver->SetRotationRange(req->degrees);
    }
    case kSelectorSetAutocenter: {
        const uint8_t *bytes = mapStructureInput(
            arguments, sizeof(SetByteReq), scratch);
        if (!bytes) return kIOReturnBadArgument;
        const SetByteReq *req = (const SetByteReq *)bytes;
        return driver->SetAutocenter(req->value);
    }
    case kSelectorSetGain: {
        const uint8_t *bytes = mapStructureInput(
            arguments, sizeof(SetByteReq), scratch);
        if (!bytes) return kIOReturnBadArgument;
        const SetByteReq *req = (const SetByteReq *)bytes;
        return driver->SetGain(req->value);
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
