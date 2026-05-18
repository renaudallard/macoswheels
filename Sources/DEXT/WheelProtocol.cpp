#include "WheelProtocol.hpp"

static const WheelProtocol *kRegistry[] = {
    &kT150Protocol,
    &kT300PS3NormalProtocol,
    &kT300PS3AdvancedProtocol,
    &kT300PS4NormalProtocol,
    &kTXProtocol,
    &kTSXWProtocol,
    &kTSPCProtocol,
    &kT248Protocol,
    &kTGTProtocol,
    &kG25Protocol,
    &kG27Protocol,
    &kG29Protocol,
    &kG920Protocol,
    &kG923PCProtocol,
    &kG923PSProtocol,
    &kG923XboxProtocol,
};

const WheelProtocol *findWheelProtocol(uint16_t vendorID, uint16_t productID) {
    for (auto *w : kRegistry) {
        if (w && w->vendorID == vendorID && w->productID == productID) {
            return w;
        }
    }
    return nullptr;
}
