#ifndef WheelProtocol_hpp
#define WheelProtocol_hpp

#include <stdint.h>
#include <stddef.h>

// A wheel-agnostic representation of one FFB effect. The PID parser fills this
// from incoming HID output reports, the protocol's encodeEffect builds the
// wire packets, the driver pushes the packets out the interrupt-OUT pipe.
struct NormalizedEffect {
    enum Kind : uint8_t {
        KindUnknown = 0,
        KindConstant,
        KindRamp,
        KindSinePeriodic,
        KindSquarePeriodic,
        KindTrianglePeriodic,
        KindSawUpPeriodic,
        KindSawDownPeriodic,
        KindSpring,
        KindDamper,
        KindFriction,
        KindInertia,
        KindStartEffect,
        KindStopEffect,
    };

    Kind     kind;
    uint8_t  slot;
    uint32_t durationMs;
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
    int16_t  attackLevel;
    uint32_t attackTime;
    int16_t  fadeLevel;
    uint32_t fadeTime;
    bool     hasEnvelope;
    uint8_t  repeats;
};

// Output buffer for an encoded effect. Each Wheel's encodeEffect concatenates
// its packets back-to-back in `bytes` and records per-packet lengths in
// `lengths`. Driver iterates and sends each.
struct EffectPackets {
    uint8_t bytes[256];
    uint8_t lengths[8];
    uint8_t count;
};

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

    // Encode one NormalizedEffect into a concatenated packet sequence in
    // `out`. Sets out->count to the number of packets, out->lengths[i] to
    // each one's byte count, and writes the bytes back-to-back in
    // out->bytes. Returns true on success; false if the wheel doesn't
    // support this effect kind (driver should silently drop).
    bool (*encodeEffect)(const NormalizedEffect *effect, EffectPackets *out);

    // Optional one-shot interrupt-OUT packet that tells the wheel to start
    // streaming input reports. The driver sends it once after the AsyncIO
    // read loop is armed. Returns the byte count written, 0 if the wheel
    // doesn't need this kick. NULL means "no setup needed".
    size_t (*prepareInputStream)(uint8_t *out, size_t outCap);

    // Optional multi-packet autocenter, used by wheels that need separate
    // "set" and "activate" packets sent in a specific order (Logitech). The
    // driver tries this first; if NULL, falls back to setAutocenterEnable
    // followed by setAutocenterStrength. Same EffectPackets convention as
    // encodeEffect.
    bool (*setAutocenter)(uint8_t percent, EffectPackets *out);
};

// Find a registered wheel by USB VID/PID. Returns NULL if unsupported.
const WheelProtocol *findWheelProtocol(uint16_t vendorID, uint16_t productID);

// Concrete protocol instances. New wheels add an extern here and register
// themselves in WheelProtocol.cpp.
extern const WheelProtocol kT150Protocol;
extern const WheelProtocol kT300PS3NormalProtocol;
extern const WheelProtocol kT300PS3AdvancedProtocol;
extern const WheelProtocol kT300PS4NormalProtocol;
extern const WheelProtocol kTXProtocol;
extern const WheelProtocol kTSXWProtocol;
extern const WheelProtocol kTSPCProtocol;
extern const WheelProtocol kT248Protocol;
extern const WheelProtocol kTGTProtocol;

#endif /* WheelProtocol_hpp */
