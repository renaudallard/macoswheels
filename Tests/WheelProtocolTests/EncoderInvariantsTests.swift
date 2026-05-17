import XCTest
@testable import Drivers
@testable import WheelProtocol

final class EncoderInvariantsTests: XCTestCase {

    private let bandedSweep: [Int16] = [
        Int16.min, -0x4000, -0x100, -1, 0, 1, 0x100, 0x4000, Int16.max,
    ]

    private func every(_ body: (NormalizedEffect) -> Void) {
        for slot: UInt8 in [0, 1, 4, 15] {
            for mag in bandedSweep {
                body(.constant(slot: slot, magnitude: mag,
                               duration: 0, direction: 0, envelope: nil))
                body(.ramp(slot: slot, start: 0, end: mag,
                           duration: 1000, envelope: nil))
                for kind: EffectKind in [.sinePeriodic, .squarePeriodic, .trianglePeriodic,
                                         .sawtoothUpPeriodic, .sawtoothDownPeriodic] {
                    body(.periodic(slot: slot, kind: kind,
                                   params: PeriodicParams(magnitude: mag, offset: 0,
                                                          phase: 0, period: 1000),
                                   duration: 1000, envelope: nil))
                }
                let cond = ConditionParams(positiveCoefficient: mag,
                                           negativeCoefficient: mag,
                                           positiveSaturation: 0x7F00,
                                           negativeSaturation: 0x7F00,
                                           deadBand: 0,
                                           centerOffset: 0)
                body(.spring(slot: slot, params: cond))
                body(.damper(slot: slot, params: cond))
                body(.friction(slot: slot, params: cond))
                body(.inertia(slot: slot, params: cond))
            }
        }
    }

    func testT150PacketsFitIn64Bytes() {
        every { effect in
            guard let pkts = try? T150Quirks.encode(effect) else { return }
            for p in pkts {
                if case .interruptOut(_, let bytes) = p {
                    XCTAssertLessThanOrEqual(bytes.count, 64,
                        "T150 encoder produced \(bytes.count)-byte packet for \(effect)")
                }
            }
        }
    }

    func testT300PacketsFitIn64Bytes() {
        every { effect in
            guard let pkts = try? T300Quirks.encode(effect) else { return }
            for p in pkts {
                if case .interruptOut(_, let bytes) = p {
                    XCTAssertLessThanOrEqual(bytes.count, 64,
                        "T300 encoder produced \(bytes.count)-byte packet for \(effect)")
                }
            }
        }
    }

    func testG29PacketsExactly7Bytes() {
        every { effect in
            guard let pkts = try? G29Quirks.encode(effect) else { return }
            for p in pkts {
                if case .interruptOut(_, let bytes) = p {
                    XCTAssertEqual(bytes.count, 7,
                        "Logitech encoder must produce 7-byte packets; got \(bytes.count) for \(effect)")
                }
            }
        }
    }

    func testT300ConstantIs24Bytes() throws {
        let pkts = try T300Quirks.encode(
            .constant(slot: 0, magnitude: 0x4000, duration: 1000, direction: 0, envelope: nil))
        guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
        XCTAssertEqual(bytes.count, 24, "T300 constant packet should be 24 bytes per docs/PROTOCOL-NOTES/T300.md")
    }

    func testT300ConditionIs38Bytes() throws {
        let pkts = try T300Quirks.encode(
            .spring(slot: 0, params: ConditionParams(positiveCoefficient: 0x4000,
                                                    negativeCoefficient: 0x4000,
                                                    positiveSaturation: 0x7F00,
                                                    negativeSaturation: 0x7F00,
                                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
        XCTAssertEqual(bytes.count, 38, "T300 condition packet should be 38 bytes per docs/PROTOCOL-NOTES/T300.md")
    }

    func testT300PeriodicIs32Bytes() throws {
        let pkts = try T300Quirks.encode(
            .periodic(slot: 0, kind: .sinePeriodic,
                      params: PeriodicParams(magnitude: 0x4000, offset: 0, phase: 0, period: 1000),
                      duration: 1000, envelope: nil))
        guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
        XCTAssertEqual(bytes.count, 32, "T300 periodic packet should be 32 bytes per docs/PROTOCOL-NOTES/T300.md")
    }

    func testT300PlayIs6Bytes() {
        guard case .interruptOut(_, let bytes) = T300FFBEncoder.playPacket(slot: 0) else { return XCTFail() }
        XCTAssertEqual(bytes.count, 6)
    }

    func testT300StopIs4Bytes() {
        guard case .interruptOut(_, let bytes) = T300FFBEncoder.stopPacket(slot: 0) else { return XCTFail() }
        XCTAssertEqual(bytes.count, 4)
    }
}
