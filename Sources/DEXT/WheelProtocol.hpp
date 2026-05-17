#ifndef WheelProtocol_hpp
#define WheelProtocol_hpp

#include <stdint.h>
#include <stddef.h>

// One vtable per wheel model. Adding a new wheel = define one of these
// structs and register it in WheelProtocol.cpp's kRegistry table.
//
// All packet-builder function pointers follow the same convention: write the
// bytes into the caller's out[outCap] buffer, return the number of bytes
// written (0 on insufficient capacity or unsupported operation). No
// allocations.
struct WheelProtocol {
    const char *displayName;
    uint16_t    vendorID;
    uint16_t    productID;

    uint16_t    minRangeDegrees;
    uint16_t    maxRangeDegrees;
    uint8_t     interruptInEndpoint;
    uint8_t     interruptOutEndpoint;
    uint8_t     hardwareSlotCount;

    // Settings packet builders. NULL means the wheel doesn't expose this knob
    // (e.g. Logitech wheels have no software gain so setGain is NULL there).
    size_t (*setRotationRange)(uint16_t degrees, uint16_t maxDeg,
                               uint8_t *out, size_t outCap);
    size_t (*setAutocenterEnable)(bool on, uint8_t *out, size_t outCap);
    size_t (*setAutocenterStrength)(uint8_t percent, uint8_t *out, size_t outCap);
    size_t (*setGain)(uint8_t percent, uint8_t *out, size_t outCap);

    // Wheel input-bytes -> re-exposed HID input report.
    // NULL means parser is not yet implemented; driver will not call back.
    size_t (*translateInputReport)(const uint8_t *raw, size_t rawLen,
                                   uint8_t *out, size_t outCap);
};

// Find a registered wheel by USB VID/PID. Returns NULL if unsupported.
const WheelProtocol *findWheelProtocol(uint16_t vendorID, uint16_t productID);

// Concrete protocol instances. New wheels add an extern here and register
// themselves in WheelProtocol.cpp.
extern const WheelProtocol kT150Protocol;

#endif /* WheelProtocol_hpp */
