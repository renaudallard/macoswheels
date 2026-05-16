enum Reset {
    static func run(args: [String]) {
        let _ = args
        do {
            let client = try WheelClient()
            try client.reset(registryID: 0)
            print("reset")
        } catch WheelClientError.notImplementedOnPlatform {
            print("reset: not on macOS")
        } catch {
            Output.die("reset: \(error)")
        }
    }
}
