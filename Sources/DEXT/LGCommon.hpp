#ifndef LGCommon_hpp
#define LGCommon_hpp

#include <stdint.h>

// Shared constants for Logitech G-series wheels. Endpoints, command bytes
// and native-mode codes are identical across DFP/G25/G27/DFGT/G29/G920/G923.
namespace LGCommon {

static const uint16_t kVendorID = 0x046D;

// Boot/compat PID shared by older Logitech wheels (DFP, G25, G27, DFGT,
// G29). They enumerate here until switched into native mode via the HID++
// extended command 0xF8/0x09. G920 and G923 enumerate directly at their
// native PIDs.
static const uint16_t kCompatPID         = 0xC294;
static const uint16_t kDFPNativePID      = 0xC298;
static const uint16_t kG25NativePID      = 0xC299;
static const uint16_t kDFGTNativePID     = 0xC29A;
static const uint16_t kG27NativePID      = 0xC29B;
static const uint16_t kG29NativePID      = 0xC24F;
static const uint16_t kG920NativePID     = 0xC262;
static const uint16_t kG923PCNativePID   = 0xC266;
static const uint16_t kG923PSNativePID   = 0xC267;
static const uint16_t kG923XboxNativePID = 0xC26E;

static const uint8_t kInterruptOutEndpoint = 0x01;
static const uint8_t kInterruptInEndpoint  = 0x81;

// First byte of standalone command packets.
static const uint8_t kCmdAutocenterDisable  = 0xF5;
static const uint8_t kCmdAutocenterStrength = 0xFE;
static const uint8_t kCmdAutocenterActivate = 0x14;
static const uint8_t kCmdExtendedPrefix     = 0xF8;

// Subcommands following kCmdExtendedPrefix.
static const uint8_t kExtSetRange       = 0x81;
static const uint8_t kExtRevertOnReset  = 0x0A;
static const uint8_t kExtSwitchMode     = 0x09;

// Native-mode codes used by the 0xF8/0x09 switch command.
enum NativeMode : uint8_t {
    NativeDFex = 0x00,
    NativeDFP  = 0x01,
    NativeG25  = 0x02,
    NativeDFGT = 0x03,
    NativeG27  = 0x04,
    NativeG29  = 0x05,
    NativeG923 = 0x07,
};

} // namespace LGCommon

#endif /* LGCommon_hpp */
