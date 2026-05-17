#include <os/log.h>
#include <stdint.h>
#include <string.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/IOBufferMemoryDescriptor.h>
#include <DriverKit/IOMemoryDescriptor.h>
#include <DriverKit/OSData.h>
#include <DriverKit/OSDictionary.h>
#include <DriverKit/OSNumber.h>
#include <DriverKit/OSString.h>
#include <HIDDriverKit/IOUserHIDDevice.h>
#include <HIDDriverKit/IOHIDDevice.h>

#include "HIDExport.h"
#include "MacoswheelsDriver.h"
#include "WheelProtocol.hpp"

#define Log(fmt, ...) os_log(OS_LOG_DEFAULT, "HIDExport: " fmt, ##__VA_ARGS__)

struct HIDExport_IVars {
    MacoswheelsDriver *driver;
};

// Minimal HID joystick descriptor for the re-exposed wheel.
// 16-bit signed X axis (steering), 16-bit Y axis (throttle), 16-bit Rz (brake),
// 16 buttons. PID FFB collection is added incrementally in subsequent commits.
static const uint8_t kReportDescriptor[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x04,        // Usage (Joystick)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        //   Report ID (1)
    0x09, 0x30,        //   Usage (X)
    0x16, 0x00, 0x80,  //   Logical Minimum (-32768)
    0x26, 0xFF, 0x7F,  //   Logical Maximum (32767)
    0x75, 0x10,        //   Report Size (16)
    0x95, 0x01,        //   Report Count (1)
    0x81, 0x02,        //   Input (Data, Variable, Absolute)
    0x09, 0x31,        //   Usage (Y)
    0x15, 0x00,        //   Logical Minimum (0)
    0x26, 0xFF, 0x03,  //   Logical Maximum (1023)
    0x75, 0x10,        //   Report Size (16)
    0x95, 0x01,        //   Report Count (1)
    0x81, 0x02,        //   Input
    0x09, 0x35,        //   Usage (Rz)
    0x15, 0x00,
    0x26, 0xFF, 0x03,
    0x75, 0x10,
    0x95, 0x01,
    0x81, 0x02,
    0x05, 0x09,        //   Usage Page (Button)
    0x19, 0x01,        //   Usage Minimum (1)
    0x29, 0x10,        //   Usage Maximum (16)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x10,        //   Report Count (16)
    0x81, 0x02,        //   Input
    0xC0,              // End Collection
};

bool HIDExport::init() {
    bool ok = super::init();
    if (!ok) return false;
    ivars = IONewZero(HIDExport_IVars, 1);
    return ivars != NULL;
}

void HIDExport::free() {
    IOSafeDeleteNULL(ivars, HIDExport_IVars, 1);
    super::free();
}

kern_return_t IMPL(HIDExport, Start) {
    kern_return_t ret = Start(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) return ret;
    Log("Start");
    return kIOReturnSuccess;
}

kern_return_t IMPL(HIDExport, Stop) {
    return Stop(provider, SUPERDISPATCH);
}

OSDictionary *HIDExport::newDeviceDescription() {
    OSDictionaryPtr dict = OSDictionary::withCapacity(8);
    if (!dict) return NULL;
    OSStringPtr product = OSString::withCString("macoswheels wheel");
    if (product) {
        dict->setObject("Product", product);
        product->release();
    }
    OSNumberPtr vid = OSNumber::withNumber((uint16_t)0x16C0, 16);
    if (vid) {
        dict->setObject("VendorID", vid);
        vid->release();
    }
    OSNumberPtr pid = OSNumber::withNumber((uint16_t)0x27DA, 16);
    if (pid) {
        dict->setObject("ProductID", pid);
        pid->release();
    }
    return dict;
}

OSData *HIDExport::newReportDescriptor() {
    return OSData::withBytes(kReportDescriptor, sizeof(kReportDescriptor));
}

kern_return_t HIDExport::EmitInputReport(const uint8_t *bytes, size_t length) {
    if (!bytes || length == 0) return kIOReturnBadArgument;
    IOBufferMemoryDescriptor *desc = NULL;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(
        kIOMemoryDirectionIn, length, 0, &desc);
    if (ret != kIOReturnSuccess || !desc) return ret;

    uint64_t addr = 0;
    uint64_t mappedLen = 0;
    desc->Map(0, 0, 0, 0, &addr, &mappedLen);
    if (addr && mappedLen >= length) {
        memcpy((void *)(uintptr_t)addr, bytes, length);
    }
    desc->SetLength(length);

    ret = handleReport(0 /*timestamp; OS fills in*/, desc,
                       (uint32_t)length, kIOHIDReportTypeInput, 0);
    OSSafeReleaseNULL(desc);
    return ret;
}

void HIDExport::SetParentDriver(IOService *driver) {
    ivars->driver = OSDynamicCast(MacoswheelsDriver, driver);
}

// PID 1.0 output report IDs (Physical Interface Device class).
enum PIDReportID : uint8_t {
    PIDSetEffect       = 0x02,
    PIDSetEnvelope     = 0x03,
    PIDSetCondition    = 0x04,
    PIDSetPeriodic     = 0x05,
    PIDSetConstant     = 0x06,
    PIDSetRamp         = 0x07,
    PIDSetCustom       = 0x08,
    PIDEffectOperation = 0x0A,
    PIDBlockFree       = 0x0B,
    PIDDeviceControl   = 0x0C,
    PIDDeviceGain      = 0x0D,
    PIDCreateNewEffect = 0x11,
};

kern_return_t HIDExport::setReport(
    IOMemoryDescriptor *report,
    IOHIDReportType     reportType,
    IOOptionBits        options,
    uint32_t            completionTimeoutMs,
    OSAction           *action)
{
    if (!report) return kIOReturnBadArgument;

    uint64_t addr = 0, length = 0;
    report->Map(0, 0, 0, 0, &addr, &length);
    if (!addr || length < 1) return kIOReturnBadArgument;

    const uint8_t *bytes = (const uint8_t *)(uintptr_t)addr;
    uint8_t reportID = bytes[0];

    if (!ivars->driver) return kIOReturnNotReady;

    NormalizedEffect eff = {};
    switch (reportID) {
    case PIDDeviceGain: {
        if (length < 2) return kIOReturnBadArgument;
        uint8_t pct = (uint16_t)bytes[1] * 100 / 255;
        return ivars->driver->SetGain(pct);
    }
    case PIDSetConstant: {
        // payload: [report_id, slot, level_signed_byte]
        if (length < 3) return kIOReturnBadArgument;
        eff.kind = NormalizedEffect::KindConstant;
        eff.slot = bytes[1];
        eff.magnitude = (int16_t)((int8_t)bytes[2]) * 256;
        return ivars->driver->SubmitEffect(&eff);
    }
    case PIDSetPeriodic: {
        // [report_id, slot, magnitude_lo, magnitude_hi, period_lo, period_hi]
        // We don't know which kind of periodic without a prior Set Effect;
        // default to sine which is the common case.
        if (length < 6) return kIOReturnBadArgument;
        eff.kind     = NormalizedEffect::KindSinePeriodic;
        eff.slot     = bytes[1];
        eff.magnitude = (int16_t)(bytes[2] | (bytes[3] << 8));
        eff.period   = (uint32_t)(bytes[4] | (bytes[5] << 8));
        return ivars->driver->SubmitEffect(&eff);
    }
    case PIDSetCondition: {
        // [report_id, slot, pos_coeff, neg_coeff, pos_sat, neg_sat, deadband, center]
        if (length < 8) return kIOReturnBadArgument;
        eff.kind         = NormalizedEffect::KindSpring;
        eff.slot         = bytes[1];
        eff.positiveCoeff = (int16_t)((int8_t)bytes[2]) * 256;
        eff.negativeCoeff = (int16_t)((int8_t)bytes[3]) * 256;
        eff.positiveSat   = (int16_t)bytes[4] * 256;
        eff.negativeSat   = (int16_t)bytes[5] * 256;
        eff.deadBand      = (uint16_t)bytes[6] * 256;
        eff.centerOffset  = (int16_t)((int8_t)bytes[7]) * 256;
        return ivars->driver->SubmitEffect(&eff);
    }
    case PIDEffectOperation: {
        // [report_id, slot, operation]
        // operation: 1 = start, 2 = start solo, 3 = stop
        if (length < 3) return kIOReturnBadArgument;
        eff.kind = (bytes[2] == 3) ? NormalizedEffect::KindStopEffect
                                   : NormalizedEffect::KindStartEffect;
        eff.slot = bytes[1];
        eff.repeats = 1;
        return ivars->driver->SubmitEffect(&eff);
    }
    case PIDSetEffect:
    case PIDSetEnvelope:
    case PIDSetRamp:
    case PIDSetCustom:
    case PIDBlockFree:
    case PIDDeviceControl:
    case PIDCreateNewEffect:
        // Slot allocation / envelope state / ramp / custom: handled in a
        // follow-up commit when per-slot effect state lands. Accept silently
        // for now so games don't see errors mid-stream.
        return kIOReturnSuccess;
    default:
        Log("setReport: unknown report ID 0x%02x", reportID);
        return kIOReturnUnsupported;
    }
}
