import XCTest
@testable import Drivers
@testable import WheelProtocol

final class LGSettingsTests: XCTestCase {

    func testRangePacketShape() {
        guard case .interruptOut(let ep, let bytes) = LGSettings.setRotationRangePacket(degrees: 900) else {
            return XCTFail()
        }
        XCTAssertEqual(ep, 0x01)
        XCTAssertEqual(bytes[0], 0xF8)
        XCTAssertEqual(bytes[1], 0x81)
        let r = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(r, 900)
        XCTAssertEqual(bytes[4...], [0, 0, 0])
    }

    func testRangeClamps40to900() {
        guard case .interruptOut(_, let low) = LGSettings.setRotationRangePacket(degrees: 10) else {
            return XCTFail()
        }
        let r = UInt16(low[2]) | (UInt16(low[3]) << 8)
        XCTAssertEqual(r, 40)
    }

    func testAutocenterZeroProducesDisablePacket() {
        let pkts = LGSettings.setAutocenterPackets(percent: 0)
        XCTAssertEqual(pkts.count, 1)
        guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0xF5)
    }

    func testAutocenter50ProducesTwoPackets() {
        let pkts = LGSettings.setAutocenterPackets(percent: 50)
        XCTAssertEqual(pkts.count, 2)
        guard case .interruptOut(_, let setBytes) = pkts[0] else { return XCTFail() }
        guard case .interruptOut(_, let activate)  = pkts[1] else { return XCTFail() }
        XCTAssertEqual(setBytes[0], 0xFE)
        XCTAssertEqual(setBytes[1], 0x0D)
        XCTAssertEqual(activate[0], 0x14)
    }
}

final class LGModeSwitchTests: XCTestCase {

    func testG29SwitchEncodesMode0x05() {
        let pkts = LGModeSwitch.switchToNativePackets(.g29)
        XCTAssertEqual(pkts.count, 2)
        guard case .interruptOut(_, let revert)  = pkts[0] else { return XCTFail() }
        guard case .interruptOut(_, let switchB) = pkts[1] else { return XCTFail() }
        XCTAssertEqual(revert[0], 0xF8)
        XCTAssertEqual(revert[1], 0x0A)
        XCTAssertEqual(switchB[0], 0xF8)
        XCTAssertEqual(switchB[1], 0x09)
        XCTAssertEqual(switchB[2], 0x05)
    }

    func testG923SwitchEncodesMode0x07() {
        let pkts = LGModeSwitch.switchToNativePackets(.g923)
        guard case .interruptOut(_, let switchB) = pkts[1] else { return XCTFail() }
        XCTAssertEqual(switchB[2], 0x07)
    }
}

final class G29DriverTests: XCTestCase {

    func testCapabilitiesIncludeSpringDamperButNotInertia() {
        let caps = G29Driver.capabilities
        XCTAssertTrue(caps.supportedEffects.contains(.spring))
        XCTAssertTrue(caps.supportedEffects.contains(.damper))
        XCTAssertFalse(caps.supportedEffects.contains(.inertia))
        XCTAssertFalse(caps.supportsGain)
    }

    func testInitializeSendsRangeAndAutocenterDisable() throws {
        let t = MockUSBTransport()
        let d = G29Driver(transport: t, delegate: NoopDelegate())
        try d.initialize()
        let sent = t.sentPackets()
        XCTAssertGreaterThanOrEqual(sent.count, 2)
        let rangePacket = sent.first { p in
            if case .interruptOut(_, let bytes) = p { return bytes.count >= 2 && bytes[1] == 0x81 }
            return false
        }
        XCTAssertNotNil(rangePacket, "range packet not found in init sequence")
    }

    func testRangeBelowMinThrows() {
        let t = MockUSBTransport()
        let d = G29Driver(transport: t, delegate: NoopDelegate())
        XCTAssertThrowsError(try d.setRotationRange(degrees: 10))
    }
}

final class G920DriverTests: XCTestCase {

    func testG920SharesG29RangeLimits() {
        XCTAssertEqual(G920Driver.capabilities.rangeMaxDegrees, 900)
        XCTAssertEqual(G920Driver.capabilities.rangeMinDegrees, 40)
    }

    func testG920HasNoBootIdentityDirectMatch() {
        XCTAssertNil(G920Driver.bootIdentity)
    }
}
