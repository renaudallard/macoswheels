#include "LGBootSwitch.hpp"
#include "LGCommon.hpp"

namespace LGBootSwitch {

uint8_t lookupNativeMode(uint16_t bcdDevice) {
    // Order matters: most specific first, identical to Linux's
    // lg4ff_main_checklist iteration order.
    if ((bcdDevice & 0xFFF8) == 0x1350) return LGCommon::NativeG29;
    if ((bcdDevice & 0xFF00) == 0x8900) return LGCommon::NativeG29;
    if ((bcdDevice & 0xFF00) == 0x3800) return LGCommon::NativeG923;
    if ((bcdDevice & 0xFF00) == 0x1300) return LGCommon::NativeDFGT;
    if ((bcdDevice & 0xFFF0) == 0x1230) return LGCommon::NativeG27;
    if ((bcdDevice & 0xFF00) == 0x1200) return LGCommon::NativeG25;
    if ((bcdDevice & 0xF000) == 0x1000) return LGCommon::NativeDFP;
    return 0xFF;
}

size_t revertOnResetPacket(uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    out[0] = LGCommon::kCmdExtendedPrefix;
    out[1] = LGCommon::kExtRevertOnReset;
    out[2] = 0x00;
    out[3] = 0x00;
    out[4] = 0x00;
    out[5] = 0x00;
    out[6] = 0x00;
    return 7;
}

size_t switchPacket(uint8_t mode, uint8_t *out, size_t outCap) {
    if (outCap < 7) return 0;
    out[0] = LGCommon::kCmdExtendedPrefix;
    out[1] = LGCommon::kExtSwitchMode;
    out[2] = mode;
    out[3] = 0x01; // detach flag, always 1 per Linux table
    // The "HID++ extended" flag (byte 4) is set only for G29 and G923.
    out[4] = (mode == LGCommon::NativeG29 || mode == LGCommon::NativeG923)
             ? 0x01 : 0x00;
    out[5] = 0x00;
    out[6] = 0x00;
    return 7;
}

} // namespace LGBootSwitch
