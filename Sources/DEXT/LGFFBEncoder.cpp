#include "LGFFBEncoder.hpp"

namespace LGFFBEncoder {

static uint8_t translateForce(int16_t x) {
    int32_t clamped = (int32_t)x;
    if (clamped < -32768) clamped = -32768;
    if (clamped >  32767) clamped =  32767;
    return (uint8_t)(((clamped + 0x8000) >> 8) & 0xFF);
}

static uint16_t scaleValueU16(uint16_t x, int bits) {
    return (uint16_t)(x >> (16 - bits));
}

static uint16_t scaleCoeff(int x, int bits) {
    int doubled = x * 2;
    if (doubled > 0xFFFF) doubled = 0xFFFF;
    if (doubled < 0)      doubled = 0;
    return (uint16_t)((uint16_t)doubled >> (16 - bits));
}

static int absI(int x) { return x < 0 ? -x : x; }

size_t constantPacket(uint8_t hardwareSlot, int16_t force,
                      uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    out[0] = (uint8_t)((0x10 << hardwareSlot) | kOpDownload);
    out[1] = kEffectConstant;
    out[2] = 0; out[3] = 0; out[4] = 0; out[5] = 0; out[6] = 0;
    out[2 + hardwareSlot] = translateForce(force);
    return 7;
}

size_t springPacket(uint8_t hardwareSlot,
                    int16_t  posCoeff, int16_t negCoeff,
                    int16_t  posSat,
                    uint16_t deadBand, int16_t centerOffset,
                    uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;

    uint32_t d1raw = ((uint32_t)deadBand + 0x8000) & 0xFFFF;
    uint32_t d2raw = (uint32_t)((int32_t)centerOffset + 0x8000) & 0xFFFF;
    uint16_t d1 = scaleValueU16((uint16_t)d1raw, 11);
    uint16_t d2 = scaleValueU16((uint16_t)d2raw, 11);
    uint8_t  s1 = (negCoeff < 0) ? 1 : 0;
    uint8_t  s2 = (posCoeff < 0) ? 1 : 0;
    int k1 = absI((int)negCoeff);
    int k2 = absI((int)posCoeff);
    if (k1 < 2048) { d1 = 0;    } else { k1 -= 2048; }
    if (k2 < 2048) { d2 = 2047; } else { k2 -= 2048; }

    uint8_t head = (uint8_t)((0x10 << hardwareSlot) | kOpDownload);
    uint8_t d1Hi = (uint8_t)(d1 >> 3);
    uint8_t d2Hi = (uint8_t)(d2 >> 3);

    uint16_t k1Scaled = scaleCoeff(k1, 4);
    uint16_t k2Scaled = scaleCoeff(k2, 4);
    uint8_t  coeffByte =
        (uint8_t)(((k2Scaled & 0x0F) << 4) | (k1Scaled & 0x0F));

    uint8_t d1Low = (uint8_t)(d1 & 7);
    uint8_t d2Low = (uint8_t)(d2 & 7);
    uint8_t bandByte =
        (uint8_t)((d2Low << 5) | (d1Low << 1) | (s2 << 4) | s1);

    int32_t satC = (int32_t)posSat + 0x8000;
    if (satC > 0xFFFF) satC = 0xFFFF;
    uint8_t satByte =
        (uint8_t)(scaleValueU16((uint16_t)satC, 8) & 0xFF);

    out[0] = head;
    out[1] = kEffectSpring;
    out[2] = d1Hi;
    out[3] = d2Hi;
    out[4] = coeffByte;
    out[5] = bandByte;
    out[6] = satByte;
    return 7;
}

size_t damperPacket(uint8_t hardwareSlot,
                    int16_t posCoeff, int16_t negCoeff,
                    int16_t posSat,
                    uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    uint8_t s1 = (negCoeff < 0) ? 1 : 0;
    uint8_t s2 = (posCoeff < 0) ? 1 : 0;
    uint8_t head = (uint8_t)((0x10 << hardwareSlot) | kOpDownload);
    uint8_t k1 = (uint8_t)(scaleCoeff(absI((int)negCoeff), 4) & 0xFF);
    uint8_t k2 = (uint8_t)(scaleCoeff(absI((int)posCoeff), 4) & 0xFF);
    int32_t satC = (int32_t)posSat + 0x8000;
    if (satC > 0xFFFF) satC = 0xFFFF;
    uint8_t satByte =
        (uint8_t)(scaleValueU16((uint16_t)satC, 8) & 0xFF);
    out[0] = head;
    out[1] = kEffectDamper;
    out[2] = k1; out[3] = s1; out[4] = k2; out[5] = s2; out[6] = satByte;
    return 7;
}

size_t frictionPacket(uint8_t hardwareSlot,
                      int16_t posCoeff, int16_t negCoeff,
                      int16_t posSat,
                      uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    uint8_t s1 = (negCoeff < 0) ? 1 : 0;
    uint8_t s2 = (posCoeff < 0) ? 1 : 0;
    uint8_t head = (uint8_t)((0x10 << hardwareSlot) | kOpDownload);
    uint8_t k1 = (uint8_t)(scaleCoeff(absI((int)negCoeff), 8) & 0xFF);
    uint8_t k2 = (uint8_t)(scaleCoeff(absI((int)posCoeff), 8) & 0xFF);
    int32_t satC = (int32_t)posSat + 0x8000;
    if (satC > 0xFFFF) satC = 0xFFFF;
    uint8_t satByte =
        (uint8_t)(scaleValueU16((uint16_t)satC, 8) & 0xFF);
    uint8_t signByte = (uint8_t)((s2 << 4) | s1);
    out[0] = head;
    out[1] = kEffectFriction;
    out[2] = k1; out[3] = k2; out[4] = satByte; out[5] = signByte; out[6] = 0;
    return 7;
}

size_t stopPacket(uint8_t hardwareSlot, uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    out[0] = (uint8_t)((0x10 << hardwareSlot) | kOpStop);
    out[1] = 0; out[2] = 0; out[3] = 0; out[4] = 0; out[5] = 0; out[6] = 0;
    return 7;
}

} // namespace LGFFBEncoder
