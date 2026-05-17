#ifndef TMBootSwitch_hpp
#define TMBootSwitch_hpp

#include <stdint.h>

namespace TMBootSwitch {

// Model lookup: (model, attachment) -> switch_value for the 0x41/83 control transfer.
// From scarburato/hid-tminit's tm_wheels_infos[] table.
struct ModelEntry {
    uint8_t  model;
    uint8_t  attachment;
    uint16_t switchValue;
    const char *name;
};

uint16_t lookupSwitchValue(uint8_t model, uint8_t attachment);
const char *lookupName(uint8_t model, uint8_t attachment);

// Parse the 16-byte response to model-query control transfer.
// type word 0x0049 or 0x0047 (network LE). Model/attachment in bytes 6 and 7.
bool parseModelQuery(const uint8_t *buffer, uint32_t length,
                     uint8_t *outModel, uint8_t *outAttachment);

} // namespace TMBootSwitch

#endif /* TMBootSwitch_hpp */
