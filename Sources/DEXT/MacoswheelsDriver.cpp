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
#include "HIDExport.h"
#include "TMSettings.hpp"
#include "TMBootSwitch.hpp"
#include "WheelProtocol.hpp"

#define Log(fmt, ...) \
    os_log(OS_LOG_DEFAULT, "MacoswheelsDriver: " fmt, ##__VA_ARGS__)

struct MacoswheelsDriver_IVars {
    IOUSBHostInterface  *interface;
    IOUSBHostPipe       *outPipe;
    HIDExport           *hidExport;
    const WheelProtocol *protocol;
    uint16_t             vendorID;
    uint16_t             productID;
    uint16_t             currentRange;
    uint8_t              currentAutocenter;
    uint8_t              currentGain;
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

static bool readBootMode(IOService *self) {
    OSDictionary *props = NULL;
    self->CopyProperties(&props);
    if (!props) return false;
    OSObject *modeObj = props->getObject("WheelMode");
    OSString *mode = OSDynamicCast(OSString, modeObj);
    bool isBoot = mode && mode->isEqualTo("boot");
    OSSafeReleaseNULL(props);
    return isBoot;
}

static kern_return_t runBootShim(IOUSBHostInterface *iface) {
    // Step 1: model query. Wrap a 16-byte buffer in an
    // IOBufferMemoryDescriptor for the IN data stage.
    IOBufferMemoryDescriptor *queryBuf = NULL;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(
        kIOMemoryDirectionIn, 16, 0, &queryBuf);
    if (ret != kIOReturnSuccess || !queryBuf) return ret;

    uint16_t bytesTransferred = 0;
    ret = iface->DeviceRequest(/*bmRequestType*/ 0xC1,
                               /*bRequest*/      73,
                               /*wValue*/        0,
                               /*wIndex*/        0,
                               /*wLength*/       16,
                               queryBuf,
                               &bytesTransferred,
                               /*completionTimeoutMs*/ 1000);
    if (ret != kIOReturnSuccess || bytesTransferred < 8) {
        os_log(OS_LOG_DEFAULT,
               "MacoswheelsDriver: boot model query failed 0x%x (%u bytes)",
               ret, bytesTransferred);
        OSSafeReleaseNULL(queryBuf);
        return ret != kIOReturnSuccess ? ret : kIOReturnError;
    }

    uint8_t queryBytes[16] = {0};
    uint64_t addr = 0;
    uint64_t length = 0;
    queryBuf->Map(0, 0, 0, 0, &addr, &length);
    if (addr) {
        size_t copyLen = bytesTransferred < sizeof(queryBytes)
            ? bytesTransferred : sizeof(queryBytes);
        memcpy(queryBytes, (const void *)(uintptr_t)addr, copyLen);
    }
    OSSafeReleaseNULL(queryBuf);

    uint8_t model = 0, attachment = 0;
    if (!TMBootSwitch::parseModelQuery(queryBytes, bytesTransferred,
                                       &model, &attachment)) {
        return kIOReturnUnsupported;
    }
    uint16_t switchValue = TMBootSwitch::lookupSwitchValue(model, attachment);
    if (switchValue == 0) {
        os_log(OS_LOG_DEFAULT,
               "MacoswheelsDriver: no switch for model %u attachment %u",
               model, attachment);
        return kIOReturnUnsupported;
    }
    os_log(OS_LOG_DEFAULT,
           "MacoswheelsDriver: detected %s, mode-switch 0x%04x",
           TMBootSwitch::lookupName(model, attachment), switchValue);

    // Step 2: mode switch. No data stage.
    uint16_t outBytes = 0;
    ret = iface->DeviceRequest(/*bmRequestType*/ 0x41,
                               /*bRequest*/      83,
                               /*wValue*/        switchValue,
                               /*wIndex*/        0,
                               /*wLength*/       0,
                               /*dataDescriptor*/ NULL,
                               &outBytes,
                               /*completionTimeoutMs*/ 1000);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT,
               "MacoswheelsDriver: mode switch failed 0x%x", ret);
    }
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

    if (readBootMode(this)) {
        Log("matched boot personality; running model-query + mode-switch");
        ret = runBootShim(iface);
        if (ret != kIOReturnSuccess) {
            Log("boot shim failed 0x%x", ret);
        }
        iface->Close(this, 0);
        ivars->interface = NULL;
        Stop(provider, SUPERDISPATCH);
        return ret;
    }

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

    ivars->protocol = findWheelProtocol(ivars->vendorID, ivars->productID);
    if (!ivars->protocol) {
        Log("no WheelProtocol registered for %04x:%04x",
            ivars->vendorID, ivars->productID);
        iface->Close(this, 0);
        ivars->interface = NULL;
        Stop(provider, SUPERDISPATCH);
        return kIOReturnUnsupported;
    }
    Log("dispatching as '%s'", ivars->protocol->displayName);
    if (ivars->currentRange < ivars->protocol->minRangeDegrees) {
        ivars->currentRange = ivars->protocol->minRangeDegrees;
    }
    if (ivars->currentRange > ivars->protocol->maxRangeDegrees) {
        ivars->currentRange = ivars->protocol->maxRangeDegrees;
    }

    IOUSBHostPipe *outPipe = NULL;
    iface->CopyPipe(ivars->protocol->interruptOutEndpoint, &outPipe);
    if (outPipe) {
        ivars->outPipe = outPipe;
        Log("interrupt-OUT pipe at 0x%02x acquired",
            ivars->protocol->interruptOutEndpoint);
    } else {
        Log("failed to acquire interrupt-OUT pipe at 0x%02x",
            ivars->protocol->interruptOutEndpoint);
    }

    IOService *hidService = NULL;
    ret = Create(this, "HIDExportProperties", &hidService);
    if (ret == kIOReturnSuccess && hidService) {
        ivars->hidExport = OSDynamicCast(HIDExport, hidService);
        if (ivars->hidExport) {
            Log("HIDExport instantiated");
        }
    } else {
        Log("Create HIDExport failed 0x%x", ret);
    }

    RegisterService();
    return kIOReturnSuccess;
}

kern_return_t IMPL(MacoswheelsDriver, Stop) {
    Log("Stop");
    if (ivars) {
        OSSafeReleaseNULL(ivars->hidExport);
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
    if (!ivars->protocol || !ivars->protocol->setRotationRange) {
        return kIOReturnUnsupported;
    }
    uint16_t maxDeg = ivars->protocol->maxRangeDegrees;
    uint16_t minDeg = ivars->protocol->minRangeDegrees;
    if (degrees > maxDeg) degrees = maxDeg;
    if (degrees < minDeg) degrees = minDeg;
    Log("SetRotationRange %u", degrees);
    uint8_t pkt[16];
    size_t n = ivars->protocol->setRotationRange(degrees, maxDeg, pkt, sizeof(pkt));
    if (n == 0) return kIOReturnBadArgument;
    kern_return_t ret = sendBytes(ivars->outPipe, pkt, n);
    if (ret == kIOReturnSuccess) ivars->currentRange = degrees;
    return ret;
}

kern_return_t MacoswheelsDriver::SetAutocenter(uint8_t percent) {
    if (!ivars->protocol) return kIOReturnUnsupported;
    if (percent > 100) percent = 100;
    Log("SetAutocenter %u%%", percent);
    uint8_t enablePkt[16], strengthPkt[16];
    kern_return_t ret = kIOReturnSuccess;
    if (ivars->protocol->setAutocenterEnable) {
        size_t en = ivars->protocol->setAutocenterEnable(
            percent > 0, enablePkt, sizeof(enablePkt));
        if (en > 0) {
            ret = sendBytes(ivars->outPipe, enablePkt, en);
            if (ret != kIOReturnSuccess) return ret;
        }
    }
    if (ivars->protocol->setAutocenterStrength) {
        size_t sn = ivars->protocol->setAutocenterStrength(
            percent, strengthPkt, sizeof(strengthPkt));
        if (sn > 0) {
            ret = sendBytes(ivars->outPipe, strengthPkt, sn);
        }
    }
    if (ret == kIOReturnSuccess) ivars->currentAutocenter = percent;
    return ret;
}

kern_return_t MacoswheelsDriver::SetGain(uint8_t percent) {
    if (!ivars->protocol || !ivars->protocol->setGain) return kIOReturnUnsupported;
    if (percent > 100) percent = 100;
    Log("SetGain %u%%", percent);
    uint8_t pkt[16];
    size_t n = ivars->protocol->setGain(percent, pkt, sizeof(pkt));
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
