import Foundation
import ConfigPlane
import WheelProtocol
import WheelRegistry

let argv = CommandLine.arguments
guard argv.count >= 2 else {
    Output.usage(); exit(2)
}
switch argv[1] {
case "list":         List.run(args: Array(argv.dropFirst(2)))
case "info":         Info.run(args: Array(argv.dropFirst(2)))
case "range":        Range.run(args: Array(argv.dropFirst(2)))
case "autocenter":   Autocenter.run(args: Array(argv.dropFirst(2)))
case "gain":         Gain.run(args: Array(argv.dropFirst(2)))
case "reset":        Reset.run(args: Array(argv.dropFirst(2)))
case "-h", "--help": Output.usage()
case "-V", "--version":
    print("macoswheels \(Output.version)")
default:
    FileHandle.standardError.write(Data("macoswheels: unknown subcommand '\(argv[1])'\n".utf8))
    exit(2)
}
