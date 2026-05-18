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
};

const WheelProtocol *findWheelProtocol(uint16_t vendorID, uint16_t productID) {
    for (auto *w : kRegistry) {
        if (w && w->vendorID == vendorID && w->productID == productID) {
            return w;
        }
    }
    return nullptr;
}
