#include <os/log.h>
#include <stdint.h>

#include <DriverKit/IOLib.h>
#include <DriverKit/OSData.h>
#include <DriverKit/OSDictionary.h>
#include <DriverKit/OSNumber.h>
#include <DriverKit/OSString.h>
#include <HIDDriverKit/IOUserHIDDevice.h>

#include "HIDExport.h"

#define Log(fmt, ...) os_log(OS_LOG_DEFAULT, "HIDExport: " fmt, ##__VA_ARGS__)

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
    return super::init();
}

void HIDExport::free() {
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
