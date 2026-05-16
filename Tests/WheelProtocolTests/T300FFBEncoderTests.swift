import XCTest
@testable import Drivers
@testable import WheelProtocol

final class T300FFBEncoderTests: XCTestCase {

    func testConstantHeaderIsZeroSlotPlus1Opcode6A() throws {
        let p = try T300FFBEncoder.encode(
            .constant(slot: 0, magnitude: 0x4000, duration: 500, direction: 0, envelope: nil))
        guard case .interruptOut(let ep, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(ep, 0x02)
        XCTAssertEqual(bytes[0], 0x00)
        XCTAssertEqual(bytes[1], 0x01)
        XCTAssertEqual(bytes[2], 0x6A)
    }

    func testConstantSlot7EncodesIDAs8() throws {
        let p = try T300FFBEncoder.encode(
            .constant(slot: 7, magnitude: 0, duration: 0, direction: 0, envelope: nil))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[1], 0x08)
    }

    func testConstantLevelIsHalved() throws {
        let p = try T300FFBEncoder.encode(
            .constant(slot: 0, magnitude: 0x4000, duration: 1000, direction: 0, envelope: nil))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        let level = Int16(bitPattern: UInt16(bytes[3]) | (UInt16(bytes[4]) << 8))
        XCTAssertEqual(level, 0x2000)
    }

    func testSpringHeaderOpcode0x64AndTypeByte0x06() throws {
        let p = try T300FFBEncoder.encode(.spring(slot: 0,
            params: ConditionParams(positiveCoefficient: 0x4000,
                                    negativeCoefficient: 0x4000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x64)
        let typeIdx = bytes.firstIndex(of: 0x06)
        XCTAssertNotNil(typeIdx)
    }

    func testDamperTypeByteIs0x07() throws {
        let p = try T300FFBEncoder.encode(.damper(slot: 0,
            params: ConditionParams(positiveCoefficient: 0x4000,
                                    negativeCoefficient: 0x4000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0)))
        guard case .interruptOut(_, let bytes) = p[0] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x64)
    }

    func testInertiaIsSupportedByT300() throws {
        XCTAssertNoThrow(try T300FFBEncoder.encode(.inertia(slot: 0,
            params: ConditionParams(positiveCoefficient: 0x2000,
                                    negativeCoefficient: 0x2000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 0, centerOffset: 0))))
    }

    func testRampStillThrowsNotImplemented() {
        XCTAssertThrowsError(try T300FFBEncoder.encode(
            .ramp(slot: 0, start: 0, end: 100, duration: 1000, envelope: nil)))
    }

    func testPlayPacketStructure() {
        guard case .interruptOut(_, let bytes) = T300FFBEncoder.playPacket(slot: 2, repeats: 5) else {
            return XCTFail()
        }
        XCTAssertEqual(bytes, [0x00, 0x03, 0x89, 0x41, 0x05, 0x00])
    }

    func testStopPacketStructure() {
        guard case .interruptOut(_, let bytes) = T300FFBEncoder.stopPacket(slot: 0) else { return XCTFail() }
        XCTAssertEqual(bytes, [0x00, 0x01, 0x89, 0x00])
    }
}

final class T300DriverFFBTests: XCTestCase {

    func testT300EncodeSpringSendsSinglePacket() throws {
        let t = MockUSBTransport()
        let d = T300Driver(transport: t, delegate: NoopDelegate())
        let pkts = try d.encode(.spring(slot: 0,
            params: ConditionParams(positiveCoefficient: 0x2000,
                                    negativeCoefficient: 0x2000,
                                    positiveSaturation: 0x7F00,
                                    negativeSaturation: 0x7F00,
                                    deadBand: 100, centerOffset: 0)))
        XCTAssertEqual(pkts.count, 1)
        guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
        XCTAssertEqual(bytes[2], 0x64)
    }

    func testT300StopAllEmits16Packets() throws {
        let t = MockUSBTransport()
        let d = T300Driver(transport: t, delegate: NoopDelegate())
        try d.stopAllEffects()
        XCTAssertEqual(t.sentPackets().count, 16)
    }
}
