#ifndef T300FFBEncoder_hpp
#define T300FFBEncoder_hpp

#include <stdint.h>
#include <stddef.h>

// T300 family FFB encoder. Single-packet uploads per effect (unlike T150's
// first/update/commit triple). Shared across T300/TX/TS-XW/TS-PC/T248/T-GT.
//
// Each function writes bytes into out[outCap] and returns the byte count, or
// 0 on insufficient capacity. No allocations.
namespace T300FFBEncoder {

struct Envelope {
    int16_t  attackLevel;
    uint32_t attackTime;
    int16_t  fadeLevel;
    uint32_t fadeTime;
};

enum WaveformCode : uint8_t {
    WaveSquare   = 0x01,
    WaveTriangle = 0x02,
    WaveSine     = 0x03,
    WaveSawUp    = 0x04,
    WaveSawDown  = 0x05,
};

enum ConditionKind : uint8_t {
    CondSpring   = 0,
    CondDamper   = 1,
    CondFriction = 2,
    CondInertia  = 3,
};

size_t constantUploadPacket(
    uint8_t slot, int16_t magnitude, uint32_t durationMs,
    const Envelope *env,
    uint8_t *out, size_t outCap);

size_t periodicUploadPacket(
    uint8_t slot, WaveformCode wave,
    int16_t magnitude, int16_t offset,
    uint16_t phase, uint32_t period,
    uint32_t durationMs, const Envelope *env,
    uint8_t *out, size_t outCap);

size_t rampUploadPacket(
    uint8_t slot, int16_t start, int16_t end,
    uint32_t durationMs, const Envelope *env,
    uint8_t *out, size_t outCap);

size_t conditionUploadPacket(
    uint8_t slot, ConditionKind kind,
    int16_t posCoeff, int16_t negCoeff,
    int16_t posSat,   int16_t negSat,
    uint16_t deadBand, int16_t centerOffset,
    uint8_t *out, size_t outCap);

size_t playPacket(uint8_t slot, uint16_t repeats,
                  uint8_t *out, size_t outCap);

size_t stopPacket(uint8_t slot, uint8_t *out, size_t outCap);

} // namespace T300FFBEncoder

#endif /* T300FFBEncoder_hpp */
