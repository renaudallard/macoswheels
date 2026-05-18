#include "T300FFBEncoder.hpp"

namespace T300FFBEncoder {

static constexpr uint8_t kOpcodeConstant  = 0x6A;
static constexpr uint8_t kOpcodeCondition = 0x64;
static constexpr uint8_t kOpcodePeriodic  = 0x6B;
static constexpr uint8_t kOpcodeRamp      = 0x6B;
static constexpr uint8_t kOpcodePlay      = 0x89;
static constexpr uint8_t kCodePlay        = 0x41;

static const uint8_t kConditionHardcoded[8] = {
    0xFE, 0xFF, 0xFE, 0xFF, 0xFE, 0xFF, 0xFE, 0xFF,
};

static void writeLe16(uint8_t *dst, uint16_t v) {
    dst[0] = (uint8_t)(v & 0xFF);
    dst[1] = (uint8_t)(v >> 8);
}

static void writeEnvelope(uint8_t *dst, const Envelope *env) {
    if (!env) {
        for (int i = 0; i < 8; ++i) dst[i] = 0;
        return;
    }
    uint16_t attackLen =
        (env->attackTime > 0xFFFF) ? 0xFFFF : (uint16_t)env->attackTime;
    uint16_t fadeLen =
        (env->fadeTime   > 0xFFFF) ? 0xFFFF : (uint16_t)env->fadeTime;
    writeLe16(dst,     attackLen);
    writeLe16(dst + 2, (uint16_t)env->attackLevel);
    writeLe16(dst + 4, fadeLen);
    writeLe16(dst + 6, (uint16_t)env->fadeLevel);
}

static void writeTiming(uint8_t *dst, uint16_t durationMs, uint16_t offsetMs) {
    dst[0] = 0x4F;
    writeLe16(dst + 1, durationMs);
    dst[3] = 0x00;
    dst[4] = 0x00;
    writeLe16(dst + 5, offsetMs);
    dst[7] = 0x00;
    dst[8] = 0xFF;
    dst[9] = 0xFF;
}

static int32_t clamp32(int32_t v, int32_t lo, int32_t hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static uint16_t scaleSaturation(int16_t sat, uint16_t maxSat) {
    if (sat == 0) return maxSat;
    uint32_t s = (uint32_t)(uint16_t)sat;
    return (uint16_t)(s * (uint32_t)maxSat / 0xFFFF);
}

static uint16_t clampDuration(uint32_t durationMs) {
    if (durationMs == 0) return 0xFFFF;
    if (durationMs > 0xFFFE) return 0xFFFE;
    return (uint16_t)durationMs;
}

size_t constantUploadPacket(
    uint8_t slot, int16_t magnitude, uint32_t durationMs,
    const Envelope *env,
    uint8_t *out, size_t outCap)
{
    if (outCap < 24) return 0;
    int32_t level = clamp32((int32_t)magnitude / 2, -16385, 16381);
    uint16_t dur = clampDuration(durationMs);
    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodeConstant;
    writeLe16(out + 3, (uint16_t)(int16_t)level);
    writeEnvelope(out + 5, env);
    out[13] = 0x00;
    writeTiming(out + 14, dur, 0);
    return 24;
}

size_t periodicUploadPacket(
    uint8_t slot, WaveformCode wave,
    int16_t magnitude, int16_t offset,
    uint16_t phase, uint32_t period,
    uint32_t durationMs, const Envelope *env,
    uint8_t *out, size_t outCap)
{
    if (outCap < 32) return 0;
    uint16_t periodU16 = (period > 0xFFFF) ? 0xFFFF : (uint16_t)period;
    uint16_t dur = clampDuration(durationMs);
    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodePeriodic;
    writeLe16(out + 3,  (uint16_t)magnitude);
    writeLe16(out + 5,  (uint16_t)offset);
    writeLe16(out + 7,  phase);
    writeLe16(out + 9,  periodU16);
    writeLe16(out + 11, 0x8000);
    writeEnvelope(out + 13, env);
    out[21] = (uint8_t)wave;
    writeTiming(out + 22, dur, 0);
    return 32;
}

size_t rampUploadPacket(
    uint8_t slot, int16_t start, int16_t end,
    uint32_t durationMs, const Envelope *env,
    uint8_t *out, size_t outCap)
{
    if (outCap < 32) return 0;
    int32_t diff = (int32_t)start - (int32_t)end;
    if (diff < 0) diff = -diff;
    uint16_t slope = (uint16_t)(diff / 2);
    int16_t center = (int16_t)(((int32_t)start + (int32_t)end) / 2);
    uint8_t invert = (start < end) ? 0x04 : 0x05;
    uint16_t dur = clampDuration(durationMs);
    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodeRamp;
    writeLe16(out + 3,  slope);
    writeLe16(out + 5,  (uint16_t)center);
    out[7]  = 0x00;
    out[8]  = 0x00;
    writeLe16(out + 9,  dur);
    writeLe16(out + 11, 0x8000);
    writeEnvelope(out + 13, env);
    out[21] = invert;
    writeTiming(out + 22, dur, 0);
    return 32;
}

size_t conditionUploadPacket(
    uint8_t slot, ConditionKind kind,
    int16_t posCoeff, int16_t negCoeff,
    int16_t posSat,   int16_t negSat,
    uint16_t deadBand, int16_t centerOffset,
    uint8_t *out, size_t outCap)
{
    if (outCap < 38) return 0;
    uint16_t maxSat   = (kind == CondSpring) ? 0x6AA6 : 0x7FFC;
    uint8_t  typeByte = (kind == CondSpring) ? 0x06   : 0x07;

    int16_t rightCoeff = (int16_t)clamp32(posCoeff, -32767, 32767);
    int16_t leftCoeff  = (int16_t)clamp32(negCoeff, -32767, 32767);
    int32_t halfDead   = (int32_t)deadBand / 2;
    int16_t rightDead  = (int16_t)clamp32((int32_t)centerOffset + halfDead, -32767, 32767);
    int16_t leftDead   = (int16_t)clamp32((int32_t)centerOffset - halfDead, -32767, 32767);
    uint16_t rightSat  = scaleSaturation(posSat, maxSat);
    uint16_t leftSat   = scaleSaturation(negSat, maxSat);

    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodeCondition;
    writeLe16(out + 3,  (uint16_t)rightCoeff);
    writeLe16(out + 5,  (uint16_t)leftCoeff);
    writeLe16(out + 7,  (uint16_t)rightDead);
    writeLe16(out + 9,  (uint16_t)leftDead);
    writeLe16(out + 11, rightSat);
    writeLe16(out + 13, leftSat);
    for (int i = 0; i < 8; ++i) out[15 + i] = kConditionHardcoded[i];
    writeLe16(out + 23, maxSat);
    writeLe16(out + 25, maxSat);
    out[27] = typeByte;
    writeTiming(out + 28, 0xFFFF, 0);
    return 38;
}

size_t playPacket(uint8_t slot, uint16_t repeats,
                  uint8_t *out, size_t outCap)
{
    if (outCap < 6) return 0;
    uint16_t count = (repeats == 0 || repeats >= 0xFFFF) ? 0 : repeats;
    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodePlay;
    out[3] = kCodePlay;
    writeLe16(out + 4, count);
    return 6;
}

size_t stopPacket(uint8_t slot, uint8_t *out, size_t outCap) {
    if (outCap < 4) return 0;
    out[0] = 0x00;
    out[1] = (uint8_t)(slot + 1);
    out[2] = kOpcodePlay;
    out[3] = 0x00;
    return 4;
}

} // namespace T300FFBEncoder
