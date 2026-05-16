enum Info {
    static func run(args: [String]) {
        let _ = args
        let prefs = PreferencesStore.load()
        let range = prefs.rotationRangeDegrees.map { "\($0)\u{00B0}" } ?? "(default)"
        let ac    = prefs.autocenterPercent.map    { "\($0)%" } ?? "(default)"
        let gain  = prefs.gainPercent.map          { "\($0)%" } ?? "(default)"
        print("rotation range : \(range)")
        print("autocenter     : \(ac)")
        print("gain           : \(gain)")
    }
}
