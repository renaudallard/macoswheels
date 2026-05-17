#ifndef TMFFBEncoder_hpp
#define TMFFBEncoder_hpp

#include <stdint.h>
#include <stddef.h>

namespace TMFFBEncoder {

// T150 effect-type opcodes (mirrors Swift TMFFBEncoder).
enum FirstCode : uint8_t {
    FirstConstantPeriodic = 0x02,
    FirstCondition        = 0x05,
};

enum EffectClass : uint8_t {
    ClassConstant  = 0x03,
    ClassPeriodic  = 0x04,
    ClassCondition = 0x05,
};

enum CommitCode : uint16_t {
    CommitConstant = 0x4000,
    CommitSine     = 0x4022,
    CommitSawUp    = 0x4023,
    CommitSawDown  = 0x4024,
    CommitSquare   = 0x4025,
    CommitTriangle = 0x4026,
    CommitSpring   = 0x4040,
    CommitDamper   = 0x4041,
};

enum EffectControl : uint8_t {
    ControlStop = 0x00,
    ControlPlay = 0x01,
    ControlLoop = 0x41,
};

struct Envelope {
    int16_t  attackLevel;
    uint32_t attackTime;
    int16_t  fadeLevel;
    uint32_t fadeTime;
};

struct PeriodicParams {
    int16_t  magnitude;
    int16_t  offset;
    uint16_t phase;
    uint32_t period;
};

struct ConditionParams {
    int16_t  positiveCoefficient;
    int16_t  negativeCoefficient;
    int16_t  positiveSaturation;
    int16_t  negativeSaturation;
    uint16_t deadBand;
    int16_t  centerOffset;
};

// Each builder writes a single packet into 'out', returning bytes written.
// Returns 0 if outCap is insufficient.
size_t firstPacket(uint8_t slot, uint8_t code, const Envelope *env,
                   uint8_t *out, size_t outCap);

size_t updateConstantPacket(uint8_t slot, int8_t level,
                            uint8_t *out, size_t outCap);

size_t updatePeriodicPacket(uint8_t slot, const PeriodicParams *p,
                            uint8_t *out, size_t outCap);

size_t updateConditionPacket(uint8_t slot, const ConditionParams *p,
                             CommitCode commit,
                             uint8_t *out, size_t outCap);

size_t commitPacket(uint8_t slot, CommitCode commit, uint16_t durationMs,
                    uint8_t *out, size_t outCap);

size_t startEffectPacket(uint8_t slot, uint8_t repeats,
                         uint8_t *out, size_t outCap);

size_t stopEffectPacket(uint8_t slot, uint8_t *out, size_t outCap);

} // namespace TMFFBEncoder

#endif /* TMFFBEncoder_hpp */
