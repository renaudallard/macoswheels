#include "WheelProtocol.hpp"

// Standalone shifters (no FFB, no rotation/autocenter/gain). The driver
// publishes their HID descriptor unchanged and forwards interrupt-IN bytes
// through, same as for any wheel that lacks a translateInputReport.
// MacoswheelsDriver skips opening the OUT pipe when interruptOutEndpoint
// is 0 and skips the PID block splice when encodeEffect is nullptr.

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
