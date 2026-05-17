#include "TMBootSwitch.hpp"

namespace TMBootSwitch {

static const ModelEntry kModels[] = {
    {0x00, 0x02, 0x0002, "T500RS"},
    {0x02, 0x00, 0x0005, "T300RS (no attachment)"},
    {0x02, 0x03, 0x0005, "T300RS F1"},
    {0x02, 0x04, 0x0005, "T300 Ferrari Alcantara"},
    {0x02, 0x06, 0x0005, "T300RS"},
    {0x02, 0x09, 0x0005, "T300RS Open Wheel"},
    {0x03, 0x06, 0x0006, "T150RS"},
};

uint16_t lookupSwitchValue(uint8_t model, uint8_t attachment) {
    for (const auto &e : kModels) {
        if (e.model == model && e.attachment == attachment) {
            return e.switchValue;
        }
    }
    return 0;
}

const char *lookupName(uint8_t model, uint8_t attachment) {
    for (const auto &e : kModels) {
        if (e.model == model && e.attachment == attachment) {
            return e.name;
        }
    }
    return "(unknown)";
}

bool parseModelQuery(const uint8_t *buffer, uint32_t length,
                     uint8_t *outModel, uint8_t *outAttachment)
{
    if (length < 8) return false;
    uint16_t type = (uint16_t)buffer[0] | ((uint16_t)buffer[1] << 8);
    if (type != 0x0049 && type != 0x0047) return false;
    if (outAttachment) *outAttachment = buffer[6];
    if (outModel) *outModel = buffer[7];
    return true;
}

} // namespace TMBootSwitch
