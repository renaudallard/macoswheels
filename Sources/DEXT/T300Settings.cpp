#include "T300Settings.hpp"

namespace T300Settings {

size_t setGainPacket(uint8_t percent, uint8_t *out, size_t outCap) {
    if (outCap < 2) return 0;
    if (percent > 100) percent = 100;
    uint32_t raw = (uint32_t)percent * 255 / 100;
    out[0] = 0x02;
    out[1] = (uint8_t)raw;
    return 2;
}

static size_t cmd08(uint8_t op, uint16_t argument,
                    uint8_t *out, size_t outCap) {
    if (outCap < 4) return 0;
    out[0] = 0x08;
    out[1] = op;
    out[2] = (uint8_t)(argument & 0xFF);
    out[3] = (uint8_t)((argument >> 8) & 0xFF);
    return 4;
}

size_t setRotationRangePacket(uint16_t degrees, uint16_t maxDegrees,
                              uint8_t *out, size_t outCap) {
    if (degrees < 40) degrees = 40;
    if (degrees > maxDegrees) degrees = maxDegrees;
    uint32_t scaled = (uint32_t)degrees * 0x3C;
    return cmd08(0x11, (uint16_t)scaled, out, outCap);
}

size_t setAutocenterStrengthPacket(uint8_t percent,
                                   uint8_t *out, size_t outCap) {
    if (percent > 100) percent = 100;
    uint16_t value = (uint16_t)percent * 100;
    return cmd08(0x04, value, out, outCap);
}

size_t setAutocenterEnabledPacket(bool enabled,
                                  uint8_t *out, size_t outCap) {
    return cmd08(0x04, enabled ? 1 : 0, out, outCap);
}

} // namespace T300Settings
