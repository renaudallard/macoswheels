import Foundation

enum Output {
    static let version = "0.1.0-dev"

    static func usage() {
        let txt = """
        usage: macoswheels <command> [args]

        commands:
          list                          list connected wheels
          info        [<wheel>]         show wheel state
          range       <degrees> [<wheel>]
          autocenter  <0..100> [<wheel>]
          gain        <0..100> [<wheel>]
          reset       [<wheel>]
          restore                       reapply saved range/autocenter/gain

        flags:
          -h, --help     show this help
          -V, --version  show version
        """
        print(txt)
    }

    static func die(_ message: String, code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("macoswheels: \(message)\n".utf8))
        exit(code)
    }
}
