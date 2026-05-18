#ifndef LGFFBEncoder_hpp
#define LGFFBEncoder_hpp

#include <stdint.h>
#include <stddef.h>

// Logitech G-series FFB encoder. Every packet is exactly 7 bytes on
// interrupt-OUT. First byte is `(0x10 << hardwareSlot) | op`. Hardware
// slot is 0..3 (only 4 effect slots, unlike T-series 16); PID slots are
// folded mod 4. Supported effects today: Constant, Spring, Damper,
// Friction. Periodics/Ramp need a continuous-update loop that's still
// TODO (Logitech's hardware lacks dedicated periodic effects).
namespace LGFFBEncoder {

static const uint8_t kOpDownload     = 0x01;
static const uint8_t kOpStop         = 0x03;
static const uint8_t kOpUpdate       = 0x0C;

static const uint8_t kEffectConstant = 0x00;
static const uint8_t kEffectSpring   = 0x0B;
static const uint8_t kEffectDamper   = 0x0C;
static const uint8_t kEffectFriction = 0x0E;

static inline uint8_t pidSlotToHardware(uint8_t pidSlot) {
    return pidSlot & 0x03;
}

size_t constantPacket(uint8_t hardwareSlot, int16_t force,
                      uint8_t *out, size_t outCap);

size_t springPacket(uint8_t hardwareSlot,
                    int16_t  posCoeff, int16_t negCoeff,
                    int16_t  posSat,
                    uint16_t deadBand, int16_t centerOffset,
                    uint8_t *out, size_t outCap);

size_t damperPacket(uint8_t hardwareSlot,
                    int16_t posCoeff, int16_t negCoeff,
                    int16_t posSat,
                    uint8_t *out, size_t outCap);

size_t frictionPacket(uint8_t hardwareSlot,
                      int16_t posCoeff, int16_t negCoeff,
                      int16_t posSat,
                      uint8_t *out, size_t outCap);

size_t stopPacket(uint8_t hardwareSlot, uint8_t *out, size_t outCap);

} // namespace LGFFBEncoder

#endif /* LGFFBEncoder_hpp */
