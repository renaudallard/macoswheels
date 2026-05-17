import Foundation
#if canImport(WheelRegistry)
import WheelRegistry
#endif

enum List {
    static func run(args: [String]) {
        let _ = args
        print("model                              vid:pid  role")
        for entry in DeviceMatch.entries where entry.mode == .firmware {
            let id = String(format: "%04X:%04X", entry.identity.vendorID, entry.identity.productID)
            let model = entry.identity.model.padding(toLength: 34, withPad: " ", startingAt: 0)
            print("\(model) \(id)  \(entry.identity.role.rawValue)")
        }
    }
}
