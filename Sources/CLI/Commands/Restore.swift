enum Restore {
    static func run(args: [String]) {
        let _ = args
        let prefs = PreferencesStore.load()
        do {
            let client = try WheelClient()
            if let d = prefs.rotationRangeDegrees {
                try client.setRotationRange(degrees: d, registryID: 0)
            }
            if let a = prefs.autocenterPercent {
                try client.setAutocenter(percent: a, registryID: 0)
            }
            if let g = prefs.gainPercent {
                try client.setGain(percent: g, registryID: 0)
            }
            print("restored")
        } catch WheelClientError.notImplementedOnPlatform {
            print("restore: not on macOS, skipped")
        } catch {
            Output.die("restore: \(error)")
        }
    }
}
