#include "WheelProtocol.hpp"
#include "TMSettings.hpp"

// T150 input-report translation is not yet implemented; the wheel's
// interrupt-IN packet layout needs a usbmon capture from real hardware to
// land. NULL pointer in the protocol vtable means "no parser; don't bother
// dispatching".
//
// Placeholder declaration -- when the parser lands, replace NULL in the
// kT150Protocol struct below with translateT150InputReport.
//
// static size_t translateT150InputReport(const uint8_t *raw, size_t rawLen,
//                                        uint8_t *out, size_t outCap);

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
};
