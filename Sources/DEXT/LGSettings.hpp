#ifndef LGSettings_hpp
#define LGSettings_hpp

#include <stdint.h>
#include <stddef.h>
#include "WheelProtocol.hpp"

// Logitech settings packets. Range is a single 7-byte packet; autocenter is
// either a 1-packet disable or a 2-packet set+activate sequence, hence the
// EffectPackets multi-packet return.
namespace LGSettings {

size_t setRotationRangePacket(uint16_t degrees, uint16_t maxDegrees,
                              uint8_t *out, size_t outCap);

bool setAutocenterPackets(uint8_t percent, EffectPackets *out);

} // namespace LGSettings

#endif /* LGSettings_hpp */
