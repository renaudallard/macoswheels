#ifndef T300Settings_hpp
#define T300Settings_hpp

#include <stdint.h>
#include <stddef.h>

// T300 family settings protocol. Distinct from T150's TMSettings: gain uses
// opcode 0x02, all rotation/autocenter packets are prefixed with 0x08 and
// scale arguments differently. Shared by T300/TX/TS-XW/TS-PC/T248/T-GT.
namespace T300Settings {

// [0x02, raw] -- gain byte scaled from percent 0..100 into 0..0xFF.
size_t setGainPacket(uint8_t percent, uint8_t *out, size_t outCap);

// [0x08, 0x11, lo, hi] -- rotation range as degrees * 60 (clamped to maxDeg).
size_t setRotationRangePacket(uint16_t degrees, uint16_t maxDegrees,
                              uint8_t *out, size_t outCap);

// [0x08, 0x04, lo, hi] -- autocenter strength as percent * 100.
size_t setAutocenterStrengthPacket(uint8_t percent,
                                   uint8_t *out, size_t outCap);

// [0x08, 0x04, lo, hi] -- autocenter enable (0 or 1).
size_t setAutocenterEnabledPacket(bool enabled,
                                  uint8_t *out, size_t outCap);

} // namespace T300Settings

#endif /* T300Settings_hpp */
