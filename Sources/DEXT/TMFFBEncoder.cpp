#include "TMFFBEncoder.hpp"

namespace TMFFBEncoder {

static inline uint8_t pkID0(uint8_t slot) {
    return (uint8_t)(((uint16_t)slot * 0x1C + 0x1C) & 0xFF);
}

static inline uint8_t pkID1(uint8_t slot) {
    return (uint8_t)(((uint16_t)slot * 0x1C + 0x0E) & 0xFF);
}

static inline int8_t clampToInt8(int v) {
    if (v < -127) return -127;
    if (v > 127) return 127;
    return (int8_t)v;
}

size_t firstPacket(uint8_t slot, uint8_t code, const Envelope *env,
                   uint8_t *out, size_t outCap)
{
    if (outCap < 11) return 0;

    uint16_t attackTime = 0;
    int8_t   attackLvl  = 0;
    uint16_t fadeTime   = 0;
    int8_t   fadeLvl    = 0;
    if (env) {
        attackTime = (env->attackTime > 0xFFFF) ? 0xFFFF : (uint16_t)env->attackTime;
        attackLvl  = clampToInt8((int)env->attackLevel / 256);
        fadeTime   = (env->fadeTime > 0xFFFF) ? 0xFFFF : (uint16_t)env->fadeTime;
        fadeLvl    = clampToInt8((int)env->fadeLevel / 256);
    }

    out[0]  = 0xF0;
    out[1]  = pkID0(slot);
    out[2]  = code;
    out[3]  = (uint8_t)(attackTime & 0xFF);
    out[4]  = (uint8_t)(attackTime >> 8);
    out[5]  = (uint8_t)attackLvl;
    out[6]  = (uint8_t)(fadeTime & 0xFF);
    out[7]  = (uint8_t)(fadeTime >> 8);
    out[8]  = (uint8_t)fadeLvl;
    out[9]  = 0x46;
    out[10] = 0x54;
    return 11;
}

size_t updateConstantPacket(uint8_t slot, int8_t level,
                            uint8_t *out, size_t outCap)
{
    if (outCap < 4) return 0;
    out[0] = ClassConstant;
    out[1] = pkID1(slot);
    out[2] = 0x4F;
    out[3] = (uint8_t)level;
    return 4;
}

size_t updatePeriodicPacket(uint8_t slot, const PeriodicParams *p,
                            uint8_t *out, size_t outCap)
{
    if (!p || outCap < 8) return 0;
    int8_t mag    = clampToInt8((int)p->magnitude / 256);
    int8_t offset = clampToInt8((int)p->offset / 256);
    uint8_t phase = (uint8_t)((unsigned)p->phase / 256);
    uint16_t period = (p->period > 0xFFFF) ? 0xFFFF : (uint16_t)p->period;

    out[0] = ClassPeriodic;
    out[1] = pkID1(slot);
    out[2] = 0x4F;
    out[3] = (uint8_t)mag;
    out[4] = (uint8_t)offset;
    out[5] = phase;
    out[6] = (uint8_t)(period & 0xFF);
    out[7] = (uint8_t)(period >> 8);
    return 8;
}

size_t updateConditionPacket(uint8_t slot, const ConditionParams *p,
                             CommitCode commit,
                             uint8_t *out, size_t outCap)
{
    if (!p || outCap < 11) return 0;
    int satMax = (commit == CommitSpring) ? 0x54 : 0x64;
    int8_t rightCoeff = clampToInt8((int)p->positiveCoefficient * 100 / 0x7F00);
    int8_t leftCoeff  = clampToInt8((int)p->negativeCoefficient * 100 / 0x7F00);
    int rightSatI = (int)p->positiveSaturation * satMax / 0x7F00;
    int leftSatI  = (int)p->negativeSaturation * satMax / 0x7F00;
    if (rightSatI > satMax) rightSatI = satMax;
    if (leftSatI  > satMax) leftSatI  = satMax;
    if (rightSatI < 0) rightSatI = 0;
    if (leftSatI < 0)  leftSatI  = 0;

    int centerSigned = (int)p->centerOffset * 500 / 0x7F00;
    if (centerSigned < -500) centerSigned = -500;
    if (centerSigned >  500) centerSigned =  500;
    uint16_t center = (uint16_t)((int16_t)centerSigned);

    int deadI = (int)p->deadBand * 1000 / 0xFFFF;
    if (deadI > 1000) deadI = 1000;
    if (deadI < 0)    deadI = 0;
    uint16_t dead = (uint16_t)deadI;

    out[0]  = ClassCondition;
    out[1]  = pkID1(slot);
    out[2]  = 0x4F;
    out[3]  = (uint8_t)rightCoeff;
    out[4]  = (uint8_t)leftCoeff;
    out[5]  = (uint8_t)(center & 0xFF);
    out[6]  = (uint8_t)(center >> 8);
    out[7]  = (uint8_t)(dead & 0xFF);
    out[8]  = (uint8_t)(dead >> 8);
    out[9]  = (uint8_t)rightSatI;
    out[10] = (uint8_t)leftSatI;
    return 11;
}

size_t commitPacket(uint8_t slot, CommitCode commit, uint16_t durationMs,
                    uint8_t *out, size_t outCap)
{
    if (outCap < 15) return 0;
    uint16_t etype = (uint16_t)commit;
    out[0]  = 0xF0;
    out[1]  = slot;
    out[2]  = (uint8_t)(etype & 0xFF);
    out[3]  = (uint8_t)(etype >> 8);
    out[4]  = (uint8_t)(durationMs & 0xFF);
    out[5]  = (uint8_t)(durationMs >> 8);
    out[6]  = 0x00;
    out[7]  = 0x00;
    out[8]  = 0x00;
    out[9]  = pkID1(slot);
    out[10] = 0x00;
    out[11] = pkID0(slot);
    out[12] = 0x00;
    out[13] = 0x00;
    out[14] = 0x00;
    return 15;
}

size_t startEffectPacket(uint8_t slot, uint8_t repeats,
                         uint8_t *out, size_t outCap)
{
    if (outCap < 4) return 0;
    out[0] = 0x60;
    out[1] = slot;
    out[2] = ControlPlay;
    out[3] = repeats;
    return 4;
}

size_t stopEffectPacket(uint8_t slot, uint8_t *out, size_t outCap)
{
    if (outCap < 4) return 0;
    out[0] = 0x60;
    out[1] = slot;
    out[2] = ControlStop;
    out[3] = 0x00;
    return 4;
}

} // namespace TMFFBEncoder
