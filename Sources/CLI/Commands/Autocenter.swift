enum Autocenter {
    static func run(args: [String]) {
        guard let raw = args.first, let pct = UInt8(raw) else {
            Output.die("autocenter: expected <0..100>", code: 2)
        }
        guard pct <= 100 else {
            Output.die("autocenter: \(pct) out of bounds (0..100)", code: 2)
        }
        do {
            let client = try WheelClient()
            try client.setAutocenter(percent: pct, registryID: 0)
            try PreferencesStore.mutate { $0.autocenterPercent = pct }
            print("autocenter = \(pct)%")
        } catch WheelClientError.notImplementedOnPlatform {
            try? PreferencesStore.mutate { $0.autocenterPercent = pct }
            print("autocenter = \(pct)% (not on macOS, plist updated only)")
        } catch {
            Output.die("autocenter: \(error)")
        }
    }
}
