import XCTest
@testable import Drivers
@testable import WheelProtocol

final class LGFFBEncoderTests: XCTestCase {

    func testConstantSlot0EncodesAs0x11WithForceInByte2() throws {
        let p = try LGFFBEncoder.encode(
            .constant(slot: 0, magnitude: 0x4000, duration: 0, direction: 0, envelope: nil))
        guard case .interruptOut(let ep, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(ep, 0x01)
        XCTAssertEqual(bytes[0], 0x11)
        XCTAssertEqual(bytes[1], 0x00)
        XCTAssertEqual(bytes[2], 0xC0)
    }

    func testConstantSlot1WritesByte3NotByte2() throws {
        let p = try LGFFBEncoder.encode(
            .constant(slot: 1, magnitude: 0x4000, duration: 0, direction: 0, envelope: nil))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x21)
        XCTAssertEqual(bytes[2], 0x00)
        XCTAssertEqual(bytes[3], 0xC0)
    }

    func testSpringEncodesEffectByte0x0B() throws {
        let p = try LGFFBEncoder.encode(.spring(slot: 0,
            params: ConditionParams(positiveCoefficient: 0x4000,
                                    negativeCoefficient: 0x4000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x11)
        XCTAssertEqual(bytes[1], 0x0B)
    }

    func testDamperEncodesEffectByte0x0C() throws {
        let p = try LGFFBEncoder.encode(.damper(slot: 2,
            params: ConditionParams(positiveCoefficient: 0x2000,
                                    negativeCoefficient: 0x2000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x41)
        XCTAssertEqual(bytes[1], 0x0C)
    }

    func testFrictionEncodesEffectByte0x0E() throws {
        let p = try LGFFBEncoder.encode(.friction(slot: 3,
            params: ConditionParams(positiveCoefficient: 0x2000,
                                    negativeCoefficient: 0x2000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x81)
        XCTAssertEqual(bytes[1], 0x0E)
    }

    func testStopPacketHasCmdOp3() {
        guard case .interruptOut(_, let bytes) = LGFFBEncoder.stopPacket(hardwareSlot: 1) else {
            return XCTFail()
        }
        XCTAssertEqual(bytes[0], 0x23)
        XCTAssertEqual(bytes[1...6], [0, 0, 0, 0, 0, 0])
    }

    func testPidSlotMapsToFourHardwareSlots() {
        XCTAssertEqual(LGFFBEncoder.pidSlotToHardware(0), 0)
        XCTAssertEqual(LGFFBEncoder.pidSlotToHardware(3), 3)
        XCTAssertEqual(LGFFBEncoder.pidSlotToHardware(4), 0)
        XCTAssertEqual(LGFFBEncoder.pidSlotToHardware(7), 3)
    }

    func testPeriodicThrowsNotImplemented() {
        let p = PeriodicParams(magnitude: 0x4000, offset: 0, phase: 0, period: 1000)
        XCTAssertThrowsError(try LGFFBEncoder.encode(
            .periodic(slot: 0, kind: .sinePeriodic, params: p, duration: 1000, envelope: nil)))
    }
}
