enum Range {
    static func run(args: [String]) {
        guard let raw = args.first, let degrees = UInt16(raw) else {
            Output.die("range: expected <degrees>", code: 2)
        }
        guard (90...1080).contains(degrees) else {
            Output.die("range: \(degrees) out of bounds (90..1080)", code: 2)
        }
        do {
            let client = try WheelClient()
            try client.setRotationRange(degrees: degrees, registryID: 0)
            try PreferencesStore.mutate { $0.rotationRangeDegrees = degrees }
            print("rotation range = \(degrees)\u{00B0}")
        } catch WheelClientError.notImplementedOnPlatform {
            try? PreferencesStore.mutate { $0.rotationRangeDegrees = degrees }
            print("rotation range = \(degrees)\u{00B0} (not on macOS, plist updated only)")
        } catch {
            Output.die("range: \(error)")
        }
    }
}
