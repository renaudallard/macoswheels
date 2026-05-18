#include "WheelProtocol.hpp"
#include "LGCommon.hpp"
#include "LGSettings.hpp"
#include "LGFFBEncoder.hpp"

// Dispatches NormalizedEffect kinds into the matching Logitech 7-byte
// upload. PID Start/Stop on Logitech: effects start playing as soon as
// they're downloaded, so we accept KindStartEffect silently; KindStopEffect
// maps to the explicit stop packet.
static bool encodeLGEffect(const NormalizedEffect *e, EffectPackets *out) {
    out->count = 0;
    if (!e) return false;

    uint8_t  hwSlot = LGFFBEncoder::pidSlotToHardware(e->slot);
    uint8_t  buf[8];
    size_t   n = 0;

    switch (e->kind) {
    case NormalizedEffect::KindConstant:
        n = LGFFBEncoder::constantPacket(
            hwSlot, e->magnitude, buf, sizeof(buf));
        break;
    case NormalizedEffect::KindSpring:
        n = LGFFBEncoder::springPacket(
            hwSlot,
            e->positiveCoeff, e->negativeCoeff,
            e->positiveSat,
            e->deadBand, e->centerOffset,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindDamper:
        n = LGFFBEncoder::damperPacket(
            hwSlot,
            e->positiveCoeff, e->negativeCoeff, e->positiveSat,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindFriction:
        n = LGFFBEncoder::frictionPacket(
            hwSlot,
            e->positiveCoeff, e->negativeCoeff, e->positiveSat,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindStartEffect:
        return true;
    case NormalizedEffect::KindStopEffect:
        n = LGFFBEncoder::stopPacket(hwSlot, buf, sizeof(buf));
        break;
    default:
        return false;
    }

    if (n == 0 || n > sizeof(out->bytes)) return false;
    for (size_t i = 0; i < n; ++i) out->bytes[i] = buf[i];
    out->lengths[0] = (uint8_t)n;
    out->count = 1;
    return true;
}

#define LG_PROTOCOL(NAME, NAMESTR, PID, MAXDEG)                          \
const WheelProtocol NAME = {                                             \
    .displayName            = NAMESTR,                                   \
    .vendorID               = LGCommon::kVendorID,                       \
    .productID              = PID,                                       \
    .minRangeDegrees        = 40,                                        \
    .maxRangeDegrees        = MAXDEG,                                    \
    .interruptInEndpoint    = LGCommon::kInterruptInEndpoint,            \
    .interruptOutEndpoint   = LGCommon::kInterruptOutEndpoint,           \
    .hardwareSlotCount      = 4,                                         \
    .setRotationRange       = &LGSettings::setRotationRangePacket,       \
    .setAutocenterEnable    = nullptr,                                   \
    .setAutocenterStrength  = nullptr,                                   \
    .setGain                = nullptr,                                   \
    .translateInputReport   = nullptr,                                   \
    .encodeEffect           = &encodeLGEffect,                           \
    .prepareInputStream     = nullptr,                                   \
    .setAutocenter          = &LGSettings::setAutocenterPackets,         \
}

LG_PROTOCOL(kDFPProtocol,
            "Logitech Driving Force Pro",  LGCommon::kDFPNativePID,      900);
LG_PROTOCOL(kDFGTProtocol,
            "Logitech Driving Force GT",   LGCommon::kDFGTNativePID,     900);
LG_PROTOCOL(kG25Protocol,
            "Logitech G25",                LGCommon::kG25NativePID,      900);
LG_PROTOCOL(kG27Protocol,
            "Logitech G27",                LGCommon::kG27NativePID,      900);
LG_PROTOCOL(kG29Protocol,
            "Logitech G29",                LGCommon::kG29NativePID,      900);
LG_PROTOCOL(kG920Protocol,
            "Logitech G920",               LGCommon::kG920NativePID,     900);
LG_PROTOCOL(kG923PCProtocol,
            "Logitech G923 (PC)",          LGCommon::kG923PCNativePID,   900);
LG_PROTOCOL(kG923PSProtocol,
            "Logitech G923 (PlayStation)", LGCommon::kG923PSNativePID,   900);
LG_PROTOCOL(kG923XboxProtocol,
            "Logitech G923 (Xbox)",        LGCommon::kG923XboxNativePID, 900);

#undef LG_PROTOCOL
