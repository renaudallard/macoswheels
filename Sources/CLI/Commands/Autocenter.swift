enum Autocenter {
    static func run(args: [String]) {
        guard let raw = args.first, let pct = UInt8(raw) else {
            Output.die("autocenter: expected <0..100>", code: 2)
        }
        guard pct <= 100 else {
            Output.die("autocenter: \(pct) out of bounds (0..100)", code: 2)
        }
        print("macoswheels: would set autocenter spring to \(pct)% (Phase 0 stub)")
    }
}
