#include "WheelProtocol.hpp"
#include "T300Settings.hpp"
#include "T300FFBEncoder.hpp"
#include "TMSettings.hpp"

// Dispatches a NormalizedEffect into one T300FFBEncoder packet.
// T-series wheels in the T300 family (T300/TX/TS-XW/TS-PC/T248/T-GT) share
// this dispatcher; input parsing is per-wheel and not yet implemented.
static bool encodeT300Effect(const NormalizedEffect *e, EffectPackets *out) {
    out->count = 0;
    if (!e) return false;

    T300FFBEncoder::Envelope env = {
        e->attackLevel, e->attackTime,
        e->fadeLevel,   e->fadeTime,
    };
    const T300FFBEncoder::Envelope *envPtr = e->hasEnvelope ? &env : nullptr;

    uint8_t buf[64];
    size_t n = 0;

    switch (e->kind) {
    case NormalizedEffect::KindConstant:
        n = T300FFBEncoder::constantUploadPacket(
            e->slot, e->magnitude, e->durationMs, envPtr, buf, sizeof(buf));
        break;
    case NormalizedEffect::KindRamp:
        n = T300FFBEncoder::rampUploadPacket(
            e->slot, e->rampStart, e->rampEnd, e->durationMs, envPtr,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindSquarePeriodic:
    case NormalizedEffect::KindSinePeriodic:
    case NormalizedEffect::KindTrianglePeriodic:
    case NormalizedEffect::KindSawUpPeriodic:
    case NormalizedEffect::KindSawDownPeriodic: {
        T300FFBEncoder::WaveformCode wave;
        switch (e->kind) {
        case NormalizedEffect::KindSquarePeriodic:
            wave = T300FFBEncoder::WaveSquare; break;
        case NormalizedEffect::KindSinePeriodic:
            wave = T300FFBEncoder::WaveSine; break;
        case NormalizedEffect::KindTrianglePeriodic:
            wave = T300FFBEncoder::WaveTriangle; break;
        case NormalizedEffect::KindSawUpPeriodic:
            wave = T300FFBEncoder::WaveSawUp; break;
        case NormalizedEffect::KindSawDownPeriodic:
            wave = T300FFBEncoder::WaveSawDown; break;
        default: return false;
        }
        n = T300FFBEncoder::periodicUploadPacket(
            e->slot, wave, e->magnitude, e->offset, e->phase, e->period,
            e->durationMs, envPtr, buf, sizeof(buf));
        break;
    }
    case NormalizedEffect::KindSpring:
        n = T300FFBEncoder::conditionUploadPacket(
            e->slot, T300FFBEncoder::CondSpring,
            e->positiveCoeff, e->negativeCoeff,
            e->positiveSat,   e->negativeSat,
            e->deadBand,      e->centerOffset,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindDamper:
        n = T300FFBEncoder::conditionUploadPacket(
            e->slot, T300FFBEncoder::CondDamper,
            e->positiveCoeff, e->negativeCoeff,
            e->positiveSat,   e->negativeSat,
            e->deadBand,      e->centerOffset,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindFriction:
        n = T300FFBEncoder::conditionUploadPacket(
            e->slot, T300FFBEncoder::CondFriction,
            e->positiveCoeff, e->negativeCoeff,
            e->positiveSat,   e->negativeSat,
            e->deadBand,      e->centerOffset,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindInertia:
        n = T300FFBEncoder::conditionUploadPacket(
            e->slot, T300FFBEncoder::CondInertia,
            e->positiveCoeff, e->negativeCoeff,
            e->positiveSat,   e->negativeSat,
            e->deadBand,      e->centerOffset,
            buf, sizeof(buf));
        break;
    case NormalizedEffect::KindStartEffect:
        n = T300FFBEncoder::playPacket(
            e->slot, e->repeats, buf, sizeof(buf));
        break;
    case NormalizedEffect::KindStopEffect:
        n = T300FFBEncoder::stopPacket(e->slot, buf, sizeof(buf));
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

#define T300_PROTOCOL(NAME, NAMESTR, PID, MINDEG, MAXDEG)             \
const WheelProtocol NAME = {                                          \
    .displayName            = NAMESTR,                                \
    .vendorID               = 0x044F,                                 \
    .productID              = PID,                                    \
    .minRangeDegrees        = MINDEG,                                 \
    .maxRangeDegrees        = MAXDEG,                                 \
    .interruptInEndpoint    = TMSettings::kInterruptInEndpoint,       \
    .interruptOutEndpoint   = TMSettings::kInterruptOutEndpoint,      \
    .hardwareSlotCount      = 16,                                     \
    .setRotationRange       = &T300Settings::setRotationRangePacket,  \
    .setAutocenterEnable    = &T300Settings::setAutocenterEnabledPacket, \
    .setAutocenterStrength  = &T300Settings::setAutocenterStrengthPacket, \
    .setGain                = &T300Settings::setGainPacket,           \
    .translateInputReport   = nullptr,                                \
    .encodeEffect           = &encodeT300Effect,                      \
}

T300_PROTOCOL(kT300PS3NormalProtocol,
              "Thrustmaster T300 RS (PS3 normal)",   0xB66E, 40, 1080);
T300_PROTOCOL(kT300PS3AdvancedProtocol,
              "Thrustmaster T300 RS (PS3 advanced)", 0xB66F, 40, 1080);
T300_PROTOCOL(kT300PS4NormalProtocol,
              "Thrustmaster T300 RS (PS4 normal)",   0xB66D, 40, 1080);
T300_PROTOCOL(kTXProtocol,
              "Thrustmaster TX",                     0xB669, 40,  900);
T300_PROTOCOL(kTSXWProtocol,
              "Thrustmaster TS-XW",                  0xB692, 40, 1080);
T300_PROTOCOL(kTSPCProtocol,
              "Thrustmaster TS-PC Racer",            0xB689, 40, 1080);
T300_PROTOCOL(kT248Protocol,
              "Thrustmaster T248",                   0xB696, 270, 900);
T300_PROTOCOL(kTGTProtocol,
              "Thrustmaster T-GT",                   0xB68E, 40, 1080);

#undef T300_PROTOCOL
