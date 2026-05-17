#include <os/log.h>
#include <stdio.h>
#include <string.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/IOService.h>
#include <DriverKit/IOMemoryDescriptor.h>
#include <DriverKit/IOBufferMemoryDescriptor.h>
#include <DriverKit/OSData.h>
#include <DriverKit/OSDictionary.h>
#include <DriverKit/OSNumber.h>
#include <DriverKit/OSString.h>
#include <USBDriverKit/IOUSBHostInterface.h>
#include <USBDriverKit/IOUSBHostDevice.h>
#include <USBDriverKit/IOUSBHostPipe.h>

#include "MacoswheelsDriver.h"
#include "MacoswheelsUserClient.h"
#include "TMSettings.hpp"

#define Log(fmt, ...) \
    os_log(OS_LOG_DEFAULT, "MacoswheelsDriver: " fmt, ##__VA_ARGS__)

struct MacoswheelsDriver_IVars {
    IOUSBHostInterface *interface;
    IOUSBHostPipe      *outPipe;
    uint16_t            vendorID;
    uint16_t            productID;
    uint16_t            maxRangeDegrees;
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
    ivars->maxRangeDegrees = 1080;
    return true;
}

void MacoswheelsDriver::free() {
    IOSafeDeleteNULL(ivars, MacoswheelsDriver_IVars, 1);
    super::free();
}

static kern_return_t sendBytes(IOUSBHostPipe *pipe,
                               const uint8_t *bytes, size_t len) {
    if (!pipe || len == 0) return kIOReturnBadArgument;
    IOBufferMemoryDescriptor *buf = NULL;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(
        kIOMemoryDirectionOut, len, 0, &buf);
    if (ret != kIOReturnSuccess || !buf) return ret;

    uint64_t addr = 0;
    uint64_t length = 0;
    buf->Map(0, 0, 0, 0, &addr, &length);
    if (addr && length >= len) {
        memcpy((void *)(uintptr_t)addr, bytes, len);
    }
    buf->SetLength(len);

    uint32_t bytesTransferred = 0;
    ret = pipe->IO(buf, (uint32_t)len, &bytesTransferred, 1000);
    OSSafeReleaseNULL(buf);
    return ret;
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
        }
        OSSafeReleaseNULL(dev);
    }

    IOUSBHostPipe *outPipe = NULL;
    iface->CopyPipe(TMSettings::kInterruptOutEndpoint, &outPipe);
    if (outPipe) {
        ivars->outPipe = outPipe;
        Log("interrupt-OUT pipe at 0x%02x acquired",
            TMSettings::kInterruptOutEndpoint);
    } else {
        Log("failed to acquire interrupt-OUT pipe at 0x%02x",
            TMSettings::kInterruptOutEndpoint);
    }

    RegisterService();
    return kIOReturnSuccess;
}

kern_return_t IMPL(MacoswheelsDriver, Stop) {
    Log("Stop");
    if (ivars) {
        OSSafeReleaseNULL(ivars->outPipe);
        if (ivars->interface) {
            ivars->interface->Close(this, 0);
            ivars->interface = NULL;
        }
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

kern_return_t MacoswheelsDriver::SetRotationRange(uint16_t degrees) {
    if (degrees > ivars->maxRangeDegrees) degrees = ivars->maxRangeDegrees;
    Log("SetRotationRange %u", degrees);
    uint8_t pkt[4];
    size_t n = TMSettings::setRotationRangePacket(
        degrees, ivars->maxRangeDegrees, pkt, sizeof(pkt));
    if (n == 0) return kIOReturnBadArgument;
    kern_return_t ret = sendBytes(ivars->outPipe, pkt, n);
    if (ret == kIOReturnSuccess) ivars->currentRange = degrees;
    return ret;
}

kern_return_t MacoswheelsDriver::SetAutocenter(uint8_t percent) {
    if (percent > 100) percent = 100;
    Log("SetAutocenter %u%%", percent);
    uint8_t enablePkt[4], strengthPkt[4];
    size_t enableN = TMSettings::setAutocenterEnabledPacket(
        percent > 0, enablePkt, sizeof(enablePkt));
    size_t strengthN = TMSettings::setAutocenterStrengthPacket(
        percent, strengthPkt, sizeof(strengthPkt));
    kern_return_t ret = sendBytes(ivars->outPipe, enablePkt, enableN);
    if (ret != kIOReturnSuccess) return ret;
    ret = sendBytes(ivars->outPipe, strengthPkt, strengthN);
    if (ret == kIOReturnSuccess) ivars->currentAutocenter = percent;
    return ret;
}

kern_return_t MacoswheelsDriver::SetGain(uint8_t percent) {
    if (percent > 100) percent = 100;
    Log("SetGain %u%%", percent);
    uint8_t pkt[2];
    size_t n = TMSettings::setGainPacket(percent, pkt, sizeof(pkt));
    kern_return_t ret = sendBytes(ivars->outPipe, pkt, n);
    if (ret == kIOReturnSuccess) ivars->currentGain = percent;
    return ret;
}

kern_return_t MacoswheelsDriver::ResetWheel() {
    Log("Reset");
    SetGain(ivars->currentGain);
    SetAutocenter(ivars->currentAutocenter);
    SetRotationRange(ivars->currentRange);
    return kIOReturnSuccess;
}
