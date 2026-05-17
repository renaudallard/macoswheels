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

#define kPIDSlotCount 16

// Per-slot PID effect state. Filled by Set Effect / Set Envelope / Set
// Constant / Set Periodic / Set Condition / Set Ramp reports; consumed when
// Effect Operation Start fires and the wheel needs to be programmed.
struct PIDSlot {
    bool                   defined;
    NormalizedEffect::Kind kind;
    uint32_t durationMs;
    bool     hasEnvelope;
    int16_t  attackLevel;
    uint32_t attackTime;
    int16_t  fadeLevel;
    uint32_t fadeTime;
    int16_t  magnitude;
    int16_t  rampStart;
    int16_t  rampEnd;
    int16_t  offset;
    uint16_t phase;
    uint32_t period;
    int16_t  positiveCoeff;
    int16_t  negativeCoeff;
    int16_t  positiveSat;
    int16_t  negativeSat;
    uint16_t deadBand;
    int16_t  centerOffset;
};

struct HIDExport_IVars {
    MacoswheelsDriver *driver;
    PIDSlot            slots[kPIDSlotCount];
};

// HID descriptor: joystick input + USB PID 1.0 output reports.
//
// Input (report ID 1): 16-bit signed X (steering), 16-bit Y (throttle),
// 16-bit Rz (brake), 16 buttons.
//
// Output reports are PID 1.0 (USB Physical Interface Device class). Each
// report's byte layout matches the parser in setReport below; field usages
// follow the PID spec so winebus/dinput can map DirectInput effects onto
// them. Effect block index is 8-bit so the host can address 0..255 slots
// (the driver caps at kPIDSlotCount = 16).
static const uint8_t kReportDescriptor[] = {
    // === Joystick input ===
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x04,        // Usage (Joystick)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        //   Report ID (1)
    0x09, 0x30,        //   Usage (X)
    0x16, 0x00, 0x80,
    0x26, 0xFF, 0x7F,
    0x75, 0x10, 0x95, 0x01,
    0x81, 0x02,
    0x09, 0x31,        //   Usage (Y)
    0x15, 0x00,
    0x26, 0xFF, 0x03,
    0x75, 0x10, 0x95, 0x01,
    0x81, 0x02,
    0x09, 0x35,        //   Usage (Rz)
    0x15, 0x00,
    0x26, 0xFF, 0x03,
    0x75, 0x10, 0x95, 0x01,
    0x81, 0x02,
    0x05, 0x09,        //   Usage Page (Button)
    0x19, 0x01, 0x29, 0x10,
    0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x10,
    0x81, 0x02,

    // === PID 1.0 output reports ===
    0x05, 0x0F,        //   Usage Page (Physical Interface Device)

    // Set Effect (0x02): [id, slot, type, dur_lo, dur_hi]
    0x09, 0x21,        //   Usage (Set Effect Report)
    0xA1, 0x02,        //   Collection (Logical)
    0x85, 0x02,        //     Report ID 2
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x25,        //     Effect Type
    0x91, 0x02,
    0x09, 0x50,        //     Duration
    0x27, 0xFF, 0xFF, 0x00, 0x00,
    0x75, 0x10,
    0x91, 0x02,
    0xC0,

    // Set Envelope (0x03): [id, slot, atk_lvl, atk_t, fade_lvl, fade_t]
    0x09, 0x5A,        //   Usage (Set Envelope Report)
    0xA1, 0x02,
    0x85, 0x03,        //     Report ID 3
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x5B,        //     Attack Level
    0x15, 0x80, 0x25, 0x7F,
    0x91, 0x02,
    0x09, 0x5C,        //     Attack Time
    0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00,
    0x75, 0x10,
    0x91, 0x02,
    0x09, 0x5D,        //     Fade Level
    0x15, 0x80, 0x25, 0x7F,
    0x75, 0x08,
    0x91, 0x02,
    0x09, 0x5E,        //     Fade Time
    0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00,
    0x75, 0x10,
    0x91, 0x02,
    0xC0,

    // Set Condition (0x04): [id, slot, pos_c, neg_c, pos_s, neg_s, db, ctr]
    0x09, 0x5F,        //   Usage (Set Condition Report)
    0xA1, 0x02,
    0x85, 0x04,        //     Report ID 4
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x61,        //     Positive Coefficient
    0x15, 0x80, 0x25, 0x7F,
    0x91, 0x02,
    0x09, 0x62,        //     Negative Coefficient
    0x91, 0x02,
    0x09, 0x63,        //     Positive Saturation
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x91, 0x02,
    0x09, 0x64,        //     Negative Saturation
    0x91, 0x02,
    0x09, 0x65,        //     Dead Band
    0x91, 0x02,
    0x09, 0x60,        //     CP Offset
    0x15, 0x80, 0x25, 0x7F,
    0x91, 0x02,
    0xC0,

    // Set Periodic (0x05): [id, slot, mag(2), off(2), phase(2), period(2)]
    0x09, 0x68,        //   Usage (Set Periodic Report)
    0xA1, 0x02,
    0x85, 0x05,        //     Report ID 5
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x70,        //     Magnitude
    0x16, 0x00, 0x80, 0x26, 0xFF, 0x7F,
    0x75, 0x10,
    0x91, 0x02,
    0x09, 0x71,        //     Offset
    0x91, 0x02,
    0x09, 0x72,        //     Phase
    0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00,
    0x91, 0x02,
    0x09, 0x73,        //     Period
    0x91, 0x02,
    0xC0,

    // Set Constant Force (0x06): [id, slot, mag(2)]
    0x09, 0x74,        //   Usage (Set Constant Force Report)
    0xA1, 0x02,
    0x85, 0x06,        //     Report ID 6
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x70,        //     Magnitude
    0x16, 0x00, 0x80, 0x26, 0xFF, 0x7F,
    0x75, 0x10,
    0x91, 0x02,
    0xC0,

    // Set Ramp Force (0x07): [id, slot, start, end]
    0x09, 0x76,        //   Usage (Set Ramp Force Report)
    0xA1, 0x02,
    0x85, 0x07,        //     Report ID 7
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x77,        //     Ramp Start
    0x15, 0x80, 0x25, 0x7F,
    0x91, 0x02,
    0x09, 0x78,        //     Ramp End
    0x91, 0x02,
    0xC0,

    // Effect Operation (0x0A): [id, slot, op, loops]
    0x09, 0x79,        //   Usage (Effect Operation Report)
    0xA1, 0x02,
    0x85, 0x0A,        //     Report ID 10
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0x09, 0x7A,        //     Op (Effect Operation)
    0x91, 0x02,
    0x09, 0x7E,        //     Loop Count
    0x91, 0x02,
    0xC0,

    // PID Block Free (0x0B): [id, slot]
    0x09, 0x90,        //   Usage (PID Block Free Report)
    0xA1, 0x02,
    0x85, 0x0B,        //     Report ID 11
    0x09, 0x22,        //     Effect Block Index
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0xC0,

    // PID Device Control (0x0C): [id, command]
    0x09, 0x95,        //   Usage (PID Device Control Report)
    0xA1, 0x02,
    0x85, 0x0C,        //     Report ID 12
    0x09, 0x96,        //     PID Device Control (raw command byte)
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0xC0,

    // PID Device Gain (0x0D): [id, gain]
    0x09, 0x7F,        //   Usage (PID Device Gain Report)
    0xA1, 0x02,
    0x85, 0x0D,        //     Report ID 13
    0x09, 0x52,        //     Gain
    0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x01,
    0x91, 0x02,
    0xC0,

    0xC0,              // End Collection (Joystick)
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

// PID Effect Type enum (USB PID 1.0 spec section 4.2).
static NormalizedEffect::Kind effectTypeToKind(uint8_t type) {
    switch (type) {
    case 1:  return NormalizedEffect::KindConstant;
    case 2:  return NormalizedEffect::KindRamp;
    case 3:  return NormalizedEffect::KindSquarePeriodic;
    case 4:  return NormalizedEffect::KindSinePeriodic;
    case 5:  return NormalizedEffect::KindTrianglePeriodic;
    case 6:  return NormalizedEffect::KindSawUpPeriodic;
    case 7:  return NormalizedEffect::KindSawDownPeriodic;
    case 8:  return NormalizedEffect::KindSpring;
    case 9:  return NormalizedEffect::KindDamper;
    case 10: return NormalizedEffect::KindInertia;
    case 11: return NormalizedEffect::KindFriction;
    default: return NormalizedEffect::KindUnknown;
    }
}

static void slotToEffect(const PIDSlot &s, uint8_t idx, NormalizedEffect &e) {
    e = {};
    e.kind          = s.kind;
    e.slot          = idx;
    e.durationMs    = s.durationMs;
    e.magnitude     = s.magnitude;
    e.rampStart     = s.rampStart;
    e.rampEnd       = s.rampEnd;
    e.offset        = s.offset;
    e.phase         = s.phase;
    e.period        = s.period;
    e.positiveCoeff = s.positiveCoeff;
    e.negativeCoeff = s.negativeCoeff;
    e.positiveSat   = s.positiveSat;
    e.negativeSat   = s.negativeSat;
    e.deadBand      = s.deadBand;
    e.centerOffset  = s.centerOffset;
    e.attackLevel   = s.attackLevel;
    e.attackTime    = s.attackTime;
    e.fadeLevel     = s.fadeLevel;
    e.fadeTime      = s.fadeTime;
    e.hasEnvelope   = s.hasEnvelope;
}

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

    switch (reportID) {
    case PIDDeviceGain: {
        if (length < 2) return kIOReturnBadArgument;
        uint8_t pct = (uint16_t)bytes[1] * 100 / 255;
        return ivars->driver->SetGain(pct);
    }
    case PIDSetEffect: {
        // [id, slot, effect_type, duration_lo, duration_hi]
        if (length < 5) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        NormalizedEffect::Kind k = effectTypeToKind(bytes[2]);
        if (k == NormalizedEffect::KindUnknown) return kIOReturnUnsupported;
        PIDSlot &s = ivars->slots[idx];
        s.kind       = k;
        s.durationMs = (uint32_t)(bytes[3] | (bytes[4] << 8));
        s.defined    = true;
        return kIOReturnSuccess;
    }
    case PIDSetEnvelope: {
        // [id, slot, attack_level, attack_time_lo, attack_time_hi,
        //            fade_level,   fade_time_lo,   fade_time_hi]
        if (length < 8) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        PIDSlot &s = ivars->slots[idx];
        s.attackLevel = (int16_t)((int8_t)bytes[2]) * 256;
        s.attackTime  = (uint32_t)(bytes[3] | (bytes[4] << 8));
        s.fadeLevel   = (int16_t)((int8_t)bytes[5]) * 256;
        s.fadeTime    = (uint32_t)(bytes[6] | (bytes[7] << 8));
        s.hasEnvelope = true;
        return kIOReturnSuccess;
    }
    case PIDSetConstant: {
        // [id, slot, magnitude_lo, magnitude_hi]
        if (length < 4) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        ivars->slots[idx].magnitude =
            (int16_t)(bytes[2] | (bytes[3] << 8));
        return kIOReturnSuccess;
    }
    case PIDSetPeriodic: {
        // [id, slot, mag_lo, mag_hi, off_lo, off_hi,
        //            phase_lo, phase_hi, period_lo, period_hi]
        if (length < 10) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        PIDSlot &s = ivars->slots[idx];
        s.magnitude = (int16_t)(bytes[2] | (bytes[3] << 8));
        s.offset    = (int16_t)(bytes[4] | (bytes[5] << 8));
        s.phase     = (uint16_t)(bytes[6] | (bytes[7] << 8));
        s.period    = (uint32_t)(bytes[8] | (bytes[9] << 8));
        return kIOReturnSuccess;
    }
    case PIDSetCondition: {
        // [id, slot, pos_coeff, neg_coeff, pos_sat, neg_sat,
        //            deadband,  center]
        if (length < 8) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        PIDSlot &s = ivars->slots[idx];
        s.positiveCoeff = (int16_t)((int8_t)bytes[2]) * 256;
        s.negativeCoeff = (int16_t)((int8_t)bytes[3]) * 256;
        s.positiveSat   = (int16_t)bytes[4] * 256;
        s.negativeSat   = (int16_t)bytes[5] * 256;
        s.deadBand      = (uint16_t)bytes[6] * 256;
        s.centerOffset  = (int16_t)((int8_t)bytes[7]) * 256;
        return kIOReturnSuccess;
    }
    case PIDSetRamp: {
        // [id, slot, start_level, end_level]
        if (length < 4) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        PIDSlot &s = ivars->slots[idx];
        s.rampStart = (int16_t)((int8_t)bytes[2]) * 256;
        s.rampEnd   = (int16_t)((int8_t)bytes[3]) * 256;
        return kIOReturnSuccess;
    }
    case PIDBlockFree: {
        if (length < 2) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx < kPIDSlotCount) {
            ivars->slots[idx] = {};
        }
        return kIOReturnSuccess;
    }
    case PIDEffectOperation: {
        // [id, slot, operation, repeats]
        // operation: 1=start, 2=start_solo, 3=stop
        if (length < 3) return kIOReturnBadArgument;
        uint8_t idx = bytes[1];
        if (idx >= kPIDSlotCount) return kIOReturnBadArgument;
        uint8_t op    = bytes[2];
        uint8_t loops = (length >= 4) ? bytes[3] : 1;
        NormalizedEffect eff = {};
        if (op == 3) {
            eff.kind = NormalizedEffect::KindStopEffect;
            eff.slot = idx;
            return ivars->driver->SubmitEffect(&eff);
        }
        PIDSlot &s = ivars->slots[idx];
        if (!s.defined) return kIOReturnNotReady;
        slotToEffect(s, idx, eff);
        kern_return_t r = ivars->driver->SubmitEffect(&eff);
        if (r != kIOReturnSuccess) return r;
        eff = {};
        eff.kind    = NormalizedEffect::KindStartEffect;
        eff.slot    = idx;
        eff.repeats = (loops == 0) ? 1 : loops;
        return ivars->driver->SubmitEffect(&eff);
    }
    case PIDDeviceControl: {
        // [id, command]
        // 1=enable, 2=disable, 3=stop_all, 4=device_reset,
        // 5=pause, 6=continue
        if (length < 2) return kIOReturnBadArgument;
        uint8_t cmd = bytes[1];
        if (cmd == 4) {
            for (int i = 0; i < kPIDSlotCount; ++i) ivars->slots[i] = {};
            return ivars->driver->ResetWheel();
        }
        if (cmd == 3) {
            for (int i = 0; i < kPIDSlotCount; ++i) {
                if (!ivars->slots[i].defined) continue;
                NormalizedEffect e = {};
                e.kind = NormalizedEffect::KindStopEffect;
                e.slot = (uint8_t)i;
                ivars->driver->SubmitEffect(&e);
            }
            return kIOReturnSuccess;
        }
        return kIOReturnSuccess;
    }
    case PIDSetCustom:
    case PIDCreateNewEffect:
        return kIOReturnSuccess;
    default:
        Log("setReport: unknown report ID 0x%02x", reportID);
        return kIOReturnUnsupported;
    }
}
