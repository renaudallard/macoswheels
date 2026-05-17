#include "WheelProtocol.hpp"

static const WheelProtocol *kRegistry[] = {
    &kT150Protocol,
};

const WheelProtocol *findWheelProtocol(uint16_t vendorID, uint16_t productID) {
    for (auto *w : kRegistry) {
        if (w && w->vendorID == vendorID && w->productID == productID) {
            return w;
        }
    }
    return nullptr;
}
