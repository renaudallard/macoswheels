import XCTest
@testable import Drivers
@testable import WheelProtocol

final class T300SettingsTests: XCTestCase {

    func testGainPacketHasOpcode0x02() {
        guard case .interruptOut(_, let bytes) = T300Settings.setGainPacket(percent: 100) else {
            return XCTFail()
        }
        XCTAssertEqual(bytes, [0x02, 0xFF])
    }

    func testRangePacketScaledBy0x3C() {
        guard case .interruptOut(_, let bytes) = T300Settings.setRotationRangePacket(degrees: 1080) else {
            return XCTFail()
        }
        XCTAssertEqual(bytes[0], 0x08)
        XCTAssertEqual(bytes[1], 0x11)
        let arg = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(arg, UInt16(1080 * 0x3C))
    }

    func testRangePacketClampsLowValuesTo40() {
        guard case .interruptOut(_, let bytes) = T300Settings.setRotationRangePacket(degrees: 10) else {
            return XCTFail()
        }
        let arg = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(arg, UInt16(40 * 0x3C))
    }

    func testAutocenterStrengthEncoding() {
        guard case .interruptOut(_, let bytes) = T300Settings.setAutocenterStrengthPacket(percent: 50) else {
            return XCTFail()
        }
        XCTAssertEqual(bytes[0], 0x08)
        XCTAssertEqual(bytes[1], 0x04)
        let arg = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(arg, 5000)
    }
}

final class T300DriverTests: XCTestCase {

    func testCapabilitiesIncludeRichEffects() {
        let caps = T300Driver.capabilities
        XCTAssertEqual(caps.pedalCount, 3)
        XCTAssertTrue(caps.supportedEffects.contains(.inertia))
        XCTAssertTrue(caps.supportedEffects.contains(.friction))
        XCTAssertTrue(caps.supportedEffects.contains(.ramp))
    }

    func testInitializeEmitsFourPackets() throws {
        let t = MockUSBTransport()
        let d = T300Driver(transport: t, delegate: NoopDelegate())
        try d.initialize()
        XCTAssertEqual(t.sentPackets().count, 4)
    }

    func testRangeRejectsValueAbove1080() {
        let t = MockUSBTransport()
        let d = T300Driver(transport: t, delegate: NoopDelegate())
        XCTAssertThrowsError(try d.setRotationRange(degrees: 1200))
    }

    func testEncodeStillThrowsNotImplemented() {
        let t = MockUSBTransport()
        let d = T300Driver(transport: t, delegate: NoopDelegate())
        XCTAssertThrowsError(try d.encode(
            .constant(slot: 0, magnitude: 0, duration: 0, direction: 0, envelope: nil))) { err in
            guard case DriverError.notImplemented = err else { return XCTFail() }
        }
    }
}

final class TXDriverTests: XCTestCase {

    func testTXRangeCappedAt900() {
        XCTAssertEqual(TXDriver.capabilities.rangeMaxDegrees, 900)
    }

    func testTXSettingsReuseT300Packets() throws {
        let t = MockUSBTransport()
        let d = TXDriver(transport: t, delegate: NoopDelegate())
        try d.setRotationRange(degrees: 540)
        guard case .interruptOut(_, let bytes) = t.sentPackets()[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x08)
        XCTAssertEqual(bytes[1], 0x11)
    }
}
