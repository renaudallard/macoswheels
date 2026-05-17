#ifndef TMSettings_hpp
#define TMSettings_hpp

#include <stdint.h>
#include <stddef.h>

namespace TMSettings {

// Endpoint addresses (T150 firmware mode).
static const uint8_t kInterruptOutEndpoint = 0x02;
static const uint8_t kInterruptInEndpoint  = 0x81;

// Generic T-series boot product ID.
static const uint16_t kGenericBootProductID = 0xB65D;

// Build settings packets into the caller-provided buffer.
// Each function returns the number of bytes actually written; the buffer
// must be at least 4 bytes for the 0x40-family ops and 2 bytes for setGain.

// [0x43, gain_byte] -- gain scaled from percent 0..100 into byte 0..0xFF.
size_t setGainPacket(uint8_t percent, uint8_t *out, size_t outCap);

// [0x40, 0x11, range_lo, range_hi] -- rotation range scaled so 1080 deg = 0xFFFF.
size_t setRotationRangePacket(uint16_t degrees, uint16_t maxDegrees,
                              uint8_t *out, size_t outCap);

// [0x40, 0x03, percent, 0x00] -- autocenter strength as a 0..100 percent.
size_t setAutocenterStrengthPacket(uint8_t percent,
                                   uint8_t *out, size_t outCap);

// [0x40, 0x04, enabled, 0x00] -- autocenter enable.
size_t setAutocenterEnabledPacket(bool enabled,
                                  uint8_t *out, size_t outCap);

} // namespace TMSettings

#endif /* TMSettings_hpp */
