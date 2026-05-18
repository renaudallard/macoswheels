#include "WheelProtocol.hpp"
#include "TMSettings.hpp"

// Standalone shifters (no FFB, no rotation/autocenter/gain). The driver
// publishes their HID descriptor unchanged and forwards interrupt-IN bytes
// through, same as for any wheel that lacks a translateInputReport.
// MacoswheelsDriver skips opening the OUT pipe when interruptOutEndpoint
// is 0 and skips the PID block splice when encodeEffect is nullptr.

// T128 lands here too: the wheel's FFB protocol isn't publicly documented
// and hid-tmff2 has no working T128 driver. We expose it as an input-only
// joystick (steering / pedals / buttons via the dynamic-descriptor path)
// and leave FFB/settings unimplemented until a usbmon capture lands. The
// T-series boot shim already knows how to switch the wheel into firmware
// mode (added in TMBootSwitch's model table).
const WheelProtocol kT128Protocol = {
    .displayName            = "Thrustmaster T128",
    .vendorID               = 0x044F,
    .productID              = 0xB68F,
    .minRangeDegrees        = 270,
    .maxRangeDegrees        = 900,
    .interruptInEndpoint    = TMSettings::kInterruptInEndpoint,
    .interruptOutEndpoint   = TMSettings::kInterruptOutEndpoint,
    .hardwareSlotCount      = 0,
};

const WheelProtocol kTH8AProtocol = {
    .displayName            = "Thrustmaster TH8A shifter",
    .vendorID               = 0x044F,
    .productID              = 0xB687,
    .minRangeDegrees        = 0,
    .maxRangeDegrees        = 0,
    .interruptInEndpoint    = 0x81,
    .interruptOutEndpoint   = 0,
    .hardwareSlotCount      = 0,
};

const WheelProtocol kGShifterProtocol = {
    .displayName            = "Logitech Driving Force Shifter",
    .vendorID               = 0x046D,
    .productID              = 0xC29C,
    .minRangeDegrees        = 0,
    .maxRangeDegrees        = 0,
    .interruptInEndpoint    = 0x81,
    .interruptOutEndpoint   = 0,
    .hardwareSlotCount      = 0,
};
