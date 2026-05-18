#include "WheelProtocol.hpp"
#include "TMSettings.hpp"
#include "TMFFBEncoder.hpp"

// T150's "open" packet, [0x42, 0x04] on interrupt-OUT, tells the wheel to
// start streaming input reports (Linux t150_driver/hid-t150.c §
// packet_input_open). The wheel's native descriptor (PID 0xB677, report ID
// 0x07, 15-byte state report) is read at Start() and re-published with our
// PID block spliced in, so input bytes pass through verbatim — no
// per-wheel translator needed here.

static size_t prepareT150InputStream(uint8_t *out, size_t outCap) {
    if (outCap < 2) return 0;
    out[0] = 0x42;
    out[1] = 0x04;
    return 2;
}

static int8_t clampLevel(int16_t v) {
    int x = (int)v / 256;
    if (x < -127) x = -127;
    if (x > 127) x = 127;
    return (int8_t)x;
}

static bool appendPacket(EffectPackets *out, const uint8_t *src, size_t n) {
    if (out->count >= 8) return false;
    size_t offset = 0;
    for (uint8_t i = 0; i < out->count; ++i) offset += out->lengths[i];
    if (offset + n > sizeof(out->bytes)) return false;
    for (size_t i = 0; i < n; ++i) out->bytes[offset + i] = src[i];
    out->lengths[out->count++] = (uint8_t)n;
    return true;
}

static bool encodeConstantEffect(const NormalizedEffect *e, EffectPackets *out) {
    uint8_t first[16], update[8], commit[16];
    TMFFBEncoder::Envelope env = {
        e->attackLevel, e->attackTime,
        e->fadeLevel,   e->fadeTime,
    };
    size_t n1 = TMFFBEncoder::firstPacket(
        e->slot, TMFFBEncoder::FirstConstantPeriodic,
        e->hasEnvelope ? &env : nullptr, first, sizeof(first));
    size_t n2 = TMFFBEncoder::updateConstantPacket(
        e->slot, clampLevel(e->magnitude), update, sizeof(update));
    uint16_t dur = e->durationMs > 0xFFFF ? 0xFFFF : (uint16_t)e->durationMs;
    size_t n3 = TMFFBEncoder::commitPacket(
        e->slot, TMFFBEncoder::CommitConstant, dur, commit, sizeof(commit));
    if (n1 == 0 || n2 == 0 || n3 == 0) return false;
    return appendPacket(out, first, n1)
        && appendPacket(out, update, n2)
        && appendPacket(out, commit, n3);
}

static bool encodePeriodicEffect(const NormalizedEffect *e, EffectPackets *out,
                                 TMFFBEncoder::CommitCode commit)
{
    uint8_t first[16], update[8], commitBuf[16];
    TMFFBEncoder::Envelope env = {
        e->attackLevel, e->attackTime, e->fadeLevel, e->fadeTime,
    };
    TMFFBEncoder::PeriodicParams pp = {
        e->magnitude, e->offset, e->phase, e->period,
    };
    size_t n1 = TMFFBEncoder::firstPacket(
        e->slot, TMFFBEncoder::FirstConstantPeriodic,
        e->hasEnvelope ? &env : nullptr, first, sizeof(first));
    size_t n2 = TMFFBEncoder::updatePeriodicPacket(
        e->slot, &pp, update, sizeof(update));
    uint16_t dur = e->durationMs > 0xFFFF ? 0xFFFF : (uint16_t)e->durationMs;
    size_t n3 = TMFFBEncoder::commitPacket(
        e->slot, commit, dur, commitBuf, sizeof(commitBuf));
    if (n1 == 0 || n2 == 0 || n3 == 0) return false;
    return appendPacket(out, first, n1)
        && appendPacket(out, update, n2)
        && appendPacket(out, commitBuf, n3);
}

static bool encodeConditionEffect(const NormalizedEffect *e, EffectPackets *out,
                                  TMFFBEncoder::CommitCode commit)
{
    uint8_t first[16], update[16], commitBuf[16];
    TMFFBEncoder::ConditionParams cp = {
        e->positiveCoeff, e->negativeCoeff,
        e->positiveSat,   e->negativeSat,
        e->deadBand,      e->centerOffset,
    };
    size_t n1 = TMFFBEncoder::firstPacket(
        e->slot, TMFFBEncoder::FirstCondition,
        nullptr, first, sizeof(first));
    size_t n2 = TMFFBEncoder::updateConditionPacket(
        e->slot, &cp, commit, update, sizeof(update));
    uint16_t dur = e->durationMs > 0xFFFF ? 0xFFFF : (uint16_t)e->durationMs;
    size_t n3 = TMFFBEncoder::commitPacket(
        e->slot, commit, dur, commitBuf, sizeof(commitBuf));
    if (n1 == 0 || n2 == 0 || n3 == 0) return false;
    return appendPacket(out, first, n1)
        && appendPacket(out, update, n2)
        && appendPacket(out, commitBuf, n3);
}

static bool encodeT150Effect(const NormalizedEffect *e, EffectPackets *out) {
    out->count = 0;
    if (!e) return false;
    switch (e->kind) {
    case NormalizedEffect::KindConstant:
        return encodeConstantEffect(e, out);
    case NormalizedEffect::KindSinePeriodic:
        return encodePeriodicEffect(e, out, TMFFBEncoder::CommitSine);
    case NormalizedEffect::KindSquarePeriodic:
        return encodePeriodicEffect(e, out, TMFFBEncoder::CommitSquare);
    case NormalizedEffect::KindTrianglePeriodic:
        return encodePeriodicEffect(e, out, TMFFBEncoder::CommitTriangle);
    case NormalizedEffect::KindSawUpPeriodic:
        return encodePeriodicEffect(e, out, TMFFBEncoder::CommitSawUp);
    case NormalizedEffect::KindSawDownPeriodic:
        return encodePeriodicEffect(e, out, TMFFBEncoder::CommitSawDown);
    case NormalizedEffect::KindSpring:
        return encodeConditionEffect(e, out, TMFFBEncoder::CommitSpring);
    case NormalizedEffect::KindDamper:
        return encodeConditionEffect(e, out, TMFFBEncoder::CommitDamper);
    case NormalizedEffect::KindStartEffect: {
        uint8_t pkt[4];
        size_t n = TMFFBEncoder::startEffectPacket(
            e->slot, e->repeats == 0 ? 1 : e->repeats, pkt, sizeof(pkt));
        return n > 0 && appendPacket(out, pkt, n);
    }
    case NormalizedEffect::KindStopEffect: {
        uint8_t pkt[4];
        size_t n = TMFFBEncoder::stopEffectPacket(e->slot, pkt, sizeof(pkt));
        return n > 0 && appendPacket(out, pkt, n);
    }
    default:
        return false;
    }
}

const WheelProtocol kT150Protocol = {
    .displayName            = "Thrustmaster T150",
    .vendorID               = 0x044F,
    .productID              = 0xB677,
    .minRangeDegrees        = 270,
    .maxRangeDegrees        = 1080,
    .interruptInEndpoint    = TMSettings::kInterruptInEndpoint,
    .interruptOutEndpoint   = TMSettings::kInterruptOutEndpoint,
    .hardwareSlotCount      = 16,

    .setRotationRange       = &TMSettings::setRotationRangePacket,
    .setAutocenterEnable    = &TMSettings::setAutocenterEnabledPacket,
    .setAutocenterStrength  = &TMSettings::setAutocenterStrengthPacket,
    .setGain                = &TMSettings::setGainPacket,

    .translateInputReport   = nullptr,
    .encodeEffect           = &encodeT150Effect,
    .prepareInputStream     = &prepareT150InputStream,
};
