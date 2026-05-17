#include <os/log.h>
#include <stdio.h>
#include <string.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/IOService.h>
#include <DriverKit/OSData.h>
#include <DriverKit/OSDictionary.h>
#include <DriverKit/OSNumber.h>
#include <DriverKit/OSString.h>
#include <USBDriverKit/IOUSBHostInterface.h>
#include <USBDriverKit/IOUSBHostDevice.h>
#include <USBDriverKit/IOUSBHostPipe.h>

#include "MacoswheelsDriver.h"
#include "MacoswheelsUserClient.h"

#define Log(fmt, ...) \
    os_log(OS_LOG_DEFAULT, "MacoswheelsDriver: " fmt, ##__VA_ARGS__)

struct MacoswheelsDriver_IVars {
    IOUSBHostInterface *interface;
    IOUSBHostPipe      *inPipe;
    IOUSBHostPipe      *outPipe;
    uint16_t            vendorID;
    uint16_t            productID;
    uint16_t            currentRange;
    uint8_t             currentAutocenter;
    uint8_t             currentGain;
};

bool MacoswheelsDriver::init() {
    bool ok = super::init();
    if (!ok) return false;
    ivars = IONewZero(MacoswheelsDriver_IVars, 1);
    if (!ivars) return false;
    ivars->currentRange = 900;
    ivars->currentGain = 75;
    return true;
}

void MacoswheelsDriver::free() {
    IOSafeDeleteNULL(ivars, MacoswheelsDriver_IVars, 1);
    super::free();
}

kern_return_t IMPL(MacoswheelsDriver, Start) {
    kern_return_t ret = Start(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) return ret;

    Log("Start");

    IOUSBHostInterface *iface = OSDynamicCast(IOUSBHostInterface, provider);
    if (!iface) {
        Log("provider is not IOUSBHostInterface");
        Stop(provider, SUPERDISPATCH);
        return kIOReturnUnsupported;
    }

    ret = iface->Open(this, 0, NULL);
    if (ret != kIOReturnSuccess) {
        Log("interface Open failed 0x%x", ret);
        Stop(provider, SUPERDISPATCH);
        return ret;
    }
    ivars->interface = iface;

    IOUSBHostDevice *dev = NULL;
    iface->CopyDevice(&dev);
    if (dev) {
        const IOUSBDeviceDescriptor *desc = dev->CopyDeviceDescriptor();
        if (desc) {
            ivars->vendorID = USBToHost16(desc->idVendor);
            ivars->productID = USBToHost16(desc->idProduct);
            Log("matched VID:PID %04x:%04x", ivars->vendorID, ivars->productID);
            IOUSBHostFreeDescriptor(desc);
        }
        OSSafeReleaseNULL(dev);
    }

    RegisterService();
    return kIOReturnSuccess;
}

kern_return_t IMPL(MacoswheelsDriver, Stop) {
    Log("Stop");
    if (ivars && ivars->interface) {
        ivars->interface->Close(this, 0);
        ivars->interface = NULL;
    }
    return Stop(provider, SUPERDISPATCH);
}

kern_return_t IMPL(MacoswheelsDriver, NewUserClient) {
    Log("NewUserClient type=%u", type);
    IOService *uc = NULL;
    kern_return_t ret = Create(this, "MacoswheelsUserClientProperties", &uc);
    if (ret != kIOReturnSuccess) {
        Log("Create user client failed 0x%x", ret);
        return ret;
    }
    *userClient = OSDynamicCast(IOUserClient, uc);
    if (*userClient == NULL) {
        OSSafeReleaseNULL(uc);
        return kIOReturnError;
    }
    return kIOReturnSuccess;
}

kern_return_t MacoswheelsDriver::SetRotationRange_Impl(uint16_t degrees) {
    Log("SetRotationRange %u", degrees);
    ivars->currentRange = degrees;
    return kIOReturnSuccess;
}

kern_return_t MacoswheelsDriver::SetAutocenter_Impl(uint8_t percent) {
    Log("SetAutocenter %u%%", percent);
    ivars->currentAutocenter = percent;
    return kIOReturnSuccess;
}

kern_return_t MacoswheelsDriver::SetGain_Impl(uint8_t percent) {
    Log("SetGain %u%%", percent);
    ivars->currentGain = percent;
    return kIOReturnSuccess;
}

kern_return_t MacoswheelsDriver::ResetWheel_Impl() {
    Log("Reset");
    return kIOReturnSuccess;
}
