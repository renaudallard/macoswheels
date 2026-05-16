enum Gain {
    static func run(args: [String]) {
        guard let raw = args.first, let pct = UInt8(raw) else {
            Output.die("gain: expected <0..100>", code: 2)
        }
        guard pct <= 100 else {
            Output.die("gain: \(pct) out of bounds (0..100)", code: 2)
        }
        do {
            let client = try WheelClient()
            try client.setGain(percent: pct, registryID: 0)
            try PreferencesStore.mutate { $0.gainPercent = pct }
            print("gain = \(pct)%")
        } catch WheelClientError.notImplementedOnPlatform {
            try? PreferencesStore.mutate { $0.gainPercent = pct }
            print("gain = \(pct)% (not on macOS, plist updated only)")
        } catch {
            Output.die("gain: \(error)")
        }
    }
}
