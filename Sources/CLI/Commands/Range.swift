enum Range {
    static func run(args: [String]) {
        guard let raw = args.first, let degrees = UInt16(raw) else {
            Output.die("range: expected <degrees>", code: 2)
        }
        guard (90...1080).contains(degrees) else {
            Output.die("range: \(degrees) out of bounds (90..1080)", code: 2)
        }
        print("macoswheels: would set rotation range to \(degrees)\u{00B0} (Phase 0 stub)")
    }
}
