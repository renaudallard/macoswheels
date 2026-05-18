#ifndef LGBootSwitch_hpp
#define LGBootSwitch_hpp

#include <stdint.h>
#include <stddef.h>

// Logitech compat → native mode-switch helpers. When a multimode wheel
// (G25/G27/G29/G923/DFP/DFGT) enumerates at the shared "Driving Force"
// compat PID 0xC294, its bcdDevice picks out the actual model. We then
// send a HID++ extended command on the interrupt-OUT pipe; the wheel
// disconnects and reappears at its native PID, which the firmware-mode
// personality matches. Mirrors Linux new-lg4ff §lg4ff_main_checklist.
namespace LGBootSwitch {

// Returns one of LGCommon::NativeMode values; 0xFF if bcdDevice doesn't
// match any known multimode wheel (caller should leave the wheel alone).
uint8_t lookupNativeMode(uint16_t bcdDevice);

// HID++ 0xF8 / 0x0A "revert on reset" prefix packet (7 bytes). Sent
// before the switch so the wheel returns to compat mode on next plug,
// matching the Linux driver's behaviour.
size_t revertOnResetPacket(uint8_t *out, size_t outCap);

// HID++ 0xF8 / 0x09 switch-mode packet (7 bytes). `mode` is a
// LGCommon::NativeMode value.
size_t switchPacket(uint8_t mode, uint8_t *out, size_t outCap);

} // namespace LGBootSwitch

#endif /* LGBootSwitch_hpp */
