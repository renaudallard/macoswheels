#ifndef HIDDescriptor_hpp
#define HIDDescriptor_hpp

#include <stdint.h>
#include <stddef.h>

// HID descriptor utilities for the wheel re-export.
//
// macoswheels publishes a HID device that combines the wheel's own input
// report definitions (so steering, pedals, buttons, hat all flow through
// untouched) with a USB PID 1.0 output-report block so games can drive FFB.
// At Start() time the driver reads the wheel's native HID Report Descriptor
// over USB, splices in our PID block via spliceWithPID, and exposes the
// merged descriptor through HIDExport::newReportDescriptor.
namespace HIDDescriptor {

// Our PID 1.0 output-report block. Starts at the PID Usage Page declaration
// (0x05, 0x0F) and ends at the last inner 0xC0 closing the Device Gain
// Logical Collection. Does not include the outer Application Collection
// 0xC0 -- spliceWithPID inserts these bytes immediately before the wheel's
// existing outer 0xC0 so the PID block lives inside the wheel's joystick
// Application Collection.
//
// PID output report IDs are 0x21..0x2A, deliberately well above any vendor
// report IDs the wheels themselves use (T150 declares 0x02, 0x07, 0x0A,
// 0x14; Logitech wheels declare 0x01..0x14), so a merged descriptor never
// double-claims an ID.
extern const uint8_t kPIDBlock[];
extern const size_t  kPIDBlockLen;

// Output report ID values, exported for the PID parser in HIDExport.
enum PIDReportID : uint8_t {
    PIDSetEffect       = 0x21,
    PIDSetEnvelope     = 0x22,
    PIDSetCondition    = 0x23,
    PIDSetPeriodic     = 0x24,
    PIDSetConstant     = 0x25,
    PIDSetRamp         = 0x26,
    PIDEffectOperation = 0x27,
    PIDBlockFree       = 0x28,
    PIDDeviceControl   = 0x29,
    PIDDeviceGain      = 0x2A,
};

// Take a wheel's native HID Report Descriptor (must end with the 0xC0 that
// closes its outer Application Collection) and write a new descriptor
// containing the wheel's bytes with kPIDBlock spliced in immediately
// before that final 0xC0. Returns the byte count written; 0 on:
//   - wheelLen < 2 or last byte isn't 0xC0
//   - merged length exceeds outCap
size_t spliceWithPID(const uint8_t *wheel, size_t wheelLen,
                     uint8_t *out, size_t outCap);

} // namespace HIDDescriptor

#endif /* HIDDescriptor_hpp */
