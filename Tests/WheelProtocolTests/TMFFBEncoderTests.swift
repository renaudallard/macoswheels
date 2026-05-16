import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TMFFBEncoderTests: XCTestCase {

    func testConstantEmitsThreePackets() throws {
        let pkts = try TMFFBEncoder.encode(
            .constant(slot: 1, magnitude: 0x4000, duration: 500, direction: 0, envelope: nil))
        XCTAssertEqual(pkts.count, 3)
        for p in pkts {
            guard case .interruptOut(let ep, _) = p else { return XCTFail("expected interruptOut") }
            XCTAssertEqual(ep, 0x02)
        }
    }

    func testConstantThirdPacketIsCommitWithType4000() throws {
        let pkts = try TMFFBEncoder.encode(
            .constant(slot: 0, magnitude: 0x7F00, duration: 1000, direction: 0, envelope: nil))
        guard case .interruptOut(_, let bytes) = pkts[2] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x00)
        XCTAssertEqual(bytes[3], 0x40)
    }

    func testSineCommitsAs4022() throws {
        let pkts = try TMFFBEncoder.encode(
            .periodic(slot: 2, kind: .sinePeriodic,
                      params: PeriodicParams(magnitude: 0x4000, offset: 0, phase: 0, period: 1000),
                      duration: 1000, envelope: nil))
        guard case .interruptOut(_, let bytes) = pkts[2] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x22)
        XCTAssertEqual(bytes[3], 0x40)
    }

    func testSpringCommitsAs4040() throws {
        let pkts = try TMFFBEncoder.encode(
            .spring(slot: 3, params: ConditionParams(positiveCoefficient: 0x7F00,
                                                    negativeCoefficient: 0x7F00,
                                                    positiveSaturation: 0x7F00,
                                                    negativeSaturation: 0x7F00,
                                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = pkts[2] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x40)
        XCTAssertEqual(bytes[3], 0x40)
    }

    func testFrictionThrowsNotSupported() {
        XCTAssertThrowsError(try TMFFBEncoder.encode(
            .friction(slot: 0, params: ConditionParams(positiveCoefficient: 0,
                                                      negativeCoefficient: 0,
                                                      positiveSaturation: 0,
                                                      negativeSaturation: 0,
                                                      deadBand: 0, centerOffset: 0))))
    }

    func testStartAndStopPacketsHaveOpcode0x60() {
        guard case .interruptOut(_, let start) = TMFFBEncoder.startEffectPacket(slot: 1) else { return }
        guard case .interruptOut(_, let stop)  = TMFFBEncoder.stopEffectPacket(slot: 1) else { return }
        XCTAssertEqual(start[0], 0x60)
        XCTAssertEqual(stop[0], 0x60)
        XCTAssertEqual(start[2], 0x01)
        XCTAssertEqual(stop[2], 0x00)
    }
}
