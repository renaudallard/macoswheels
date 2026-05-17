import Foundation
#if canImport(WheelProtocol)
import WheelProtocol
#endif
#if canImport(Drivers)
import Drivers
#endif

enum DumpEffect {

    static func run(args: [String]) {
        guard let kind = args.first else {
            Output.die("dump-effect: expected effect kind (constant, sine, square, triangle, sawUp, sawDown, ramp, spring, damper, friction, inertia)", code: 2)
        }
        var wheel = "T150"
        var slot: UInt8 = 0
        var magnitude: Int16 = 0x4000
        var duration: UInt32 = 1000

        var i = 1
        while i < args.count {
            let a = args[i]
            switch a {
            case "--wheel":
                guard i + 1 < args.count else { Output.die("dump-effect: --wheel needs a value", code: 2) }
                wheel = args[i + 1]; i += 2
            case "--slot":
                guard i + 1 < args.count, let v = UInt8(args[i + 1]) else {
                    Output.die("dump-effect: --slot needs a 0..255", code: 2)
                }
                slot = v; i += 2
            case "--magnitude":
                guard i + 1 < args.count, let v = Int(args[i + 1]) else {
                    Output.die("dump-effect: --magnitude needs an int16", code: 2)
                }
                magnitude = Int16(max(Int(Int16.min), min(Int(Int16.max), v)))
                i += 2
            case "--duration":
                guard i + 1 < args.count, let v = UInt32(args[i + 1]) else {
                    Output.die("dump-effect: --duration needs a uint32 ms", code: 2)
                }
                duration = v; i += 2
            default:
                Output.die("dump-effect: unknown flag '\(a)'", code: 2)
            }
        }

        let effect = makeEffect(kind: kind, slot: slot, magnitude: magnitude, duration: duration)
        guard let effect = effect else {
            Output.die("dump-effect: unknown effect kind '\(kind)'", code: 2)
        }

        do {
            let packets = try encode(wheel: wheel, effect: effect)
            print("# wheel=\(wheel) effect=\(kind) slot=\(slot) magnitude=\(magnitude) duration=\(duration)")
            for (idx, p) in packets.enumerated() {
                switch p {
                case .control(let setup, let payload):
                    var bytes = [setup.bmRequestType, setup.bRequest,
                                 UInt8(setup.wValue & 0xFF), UInt8(setup.wValue >> 8),
                                 UInt8(setup.wIndex & 0xFF), UInt8(setup.wIndex >> 8)]
                    bytes.append(contentsOf: payload)
                    print("[\(idx)] control: " + hex(bytes))
                case .interruptOut(let endpoint, let bytes):
                    print(String(format: "[%d] EP 0x%02X (interrupt-OUT): %@",
                                 idx, endpoint, hex(bytes)))
                }
            }
        } catch {
            Output.die("dump-effect: \(error)")
        }
    }

    private static func makeEffect(kind: String, slot: UInt8, magnitude: Int16, duration: UInt32) -> NormalizedEffect? {
        let condition = ConditionParams(positiveCoefficient: magnitude,
                                        negativeCoefficient: magnitude,
                                        positiveSaturation: 0x7F00,
                                        negativeSaturation: 0x7F00,
                                        deadBand: 0,
                                        centerOffset: 0)
        let periodic = PeriodicParams(magnitude: magnitude,
                                      offset: 0,
                                      phase: 0,
                                      period: 1000)
        switch kind.lowercased() {
        case "constant":
            return .constant(slot: slot, magnitude: magnitude, duration: duration, direction: 0, envelope: nil)
        case "ramp":
            return .ramp(slot: slot, start: 0, end: magnitude, duration: duration, envelope: nil)
        case "sine":
            return .periodic(slot: slot, kind: .sinePeriodic, params: periodic, duration: duration, envelope: nil)
        case "square":
            return .periodic(slot: slot, kind: .squarePeriodic, params: periodic, duration: duration, envelope: nil)
        case "triangle":
            return .periodic(slot: slot, kind: .trianglePeriodic, params: periodic, duration: duration, envelope: nil)
        case "sawup":
            return .periodic(slot: slot, kind: .sawtoothUpPeriodic, params: periodic, duration: duration, envelope: nil)
        case "sawdown":
            return .periodic(slot: slot, kind: .sawtoothDownPeriodic, params: periodic, duration: duration, envelope: nil)
        case "spring":   return .spring(slot: slot, params: condition)
        case "damper":   return .damper(slot: slot, params: condition)
        case "friction": return .friction(slot: slot, params: condition)
        case "inertia":  return .inertia(slot: slot, params: condition)
        default: return nil
        }
    }

    private static func encode(wheel: String, effect: NormalizedEffect) throws -> [USBPacket] {
        switch wheel.lowercased() {
        case "t150": return try T150Quirks.encode(effect)
        case "t300", "tx", "tsxw", "tspc", "t248", "tgt": return try T300Quirks.encode(effect)
        case "t128": return try T128Quirks.encode(effect)
        case "g29", "g920", "g25", "g27", "g923": return try G29Quirks.encode(effect)
        default:
            throw DumpError.unknownWheel(wheel)
        }
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    enum DumpError: Error, CustomStringConvertible {
        case unknownWheel(String)
        var description: String {
            switch self {
            case .unknownWheel(let w): return "unknown wheel '\(w)' (try T150, T300, G29, ...)"
            }
        }
    }
}
