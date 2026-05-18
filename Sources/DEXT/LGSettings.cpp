#include "LGSettings.hpp"
#include "LGCommon.hpp"

namespace LGSettings {

size_t setRotationRangePacket(uint16_t degrees, uint16_t maxDegrees,
                              uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    if (degrees < 40) degrees = 40;
    if (degrees > maxDegrees) degrees = maxDegrees;
    out[0] = LGCommon::kCmdExtendedPrefix;
    out[1] = LGCommon::kExtSetRange;
    out[2] = (uint8_t)(degrees & 0xFF);
    out[3] = (uint8_t)((degrees >> 8) & 0xFF);
    out[4] = 0;
    out[5] = 0;
    out[6] = 0;
    return 7;
}

bool setAutocenterPackets(uint8_t percent, EffectPackets *out) {
    out->count = 0;
    if (percent > 100) percent = 100;

    if (percent == 0) {
        out->bytes[0] = LGCommon::kCmdAutocenterDisable;
        for (int i = 1; i < 7; ++i) out->bytes[i] = 0;
        out->lengths[0] = 7;
        out->count = 1;
        return true;
    }

    uint32_t magnitude = (uint32_t)percent * 0xFFFF / 100;
    uint32_t expandA, expandB;
    if (magnitude <= 0xAAAA) {
        expandA = 0x0C * magnitude;
        expandB = 0x80 * magnitude;
    } else {
        expandA = (0x0C * 0xAAAA) + 0x06 * (magnitude - 0xAAAA);
        expandB = (0x80 * 0xAAAA) + 0xFF * (magnitude - 0xAAAA);
    }
    expandA >>= 1;

    out->bytes[0] = LGCommon::kCmdAutocenterStrength;
    out->bytes[1] = 0x0D;
    out->bytes[2] = (uint8_t)(expandA / 0xAAAA);
    out->bytes[3] = (uint8_t)(expandA / 0xAAAA);
    out->bytes[4] = (uint8_t)(expandB / 0xAAAA);
    out->bytes[5] = 0;
    out->bytes[6] = 0;

    out->bytes[7] = LGCommon::kCmdAutocenterActivate;
    for (int i = 8; i < 14; ++i) out->bytes[i] = 0;

    out->lengths[0] = 7;
    out->lengths[1] = 7;
    out->count = 2;
    return true;
}

} // namespace LGSettings
