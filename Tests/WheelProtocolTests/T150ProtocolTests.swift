import XCTest
@testable import Drivers
@testable import WheelProtocol

final class T150ProtocolTests: XCTestCase {

    private func make() -> (T150Driver, MockUSBTransport) {
        let t = MockUSBTransport()
        let d = T150Driver(transport: t, delegate: NoopDelegate())
        return (d, t)
    }

    func testInitializeSendsFourPackets() throws {
        let (d, t) = make()
        try d.initialize()
        let sent = t.sentPackets()
        XCTAssertEqual(sent.count, 4)
        if case .interruptOut(_, let firstBytes) = sent[0] {
            XCTAssertEqual(firstBytes[0], 0x43)
        } else { XCTFail("first packet should be gain") }
        if case .interruptOut(_, let lastBytes) = sent[3] {
            XCTAssertEqual(lastBytes[0], 0x40)
            XCTAssertEqual(lastBytes[1], 0x11)
        } else { XCTFail("last packet should be range") }
    }

    func testSetRotationRangeEmitsOnlyRangeWhenValid() throws {
        let (d, t) = make()
        try d.setRotationRange(degrees: 540)
        let sent = t.sentPackets()
        XCTAssertEqual(sent.count, 1)
        guard case .interruptOut(_, let bytes) = sent[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0x40)
        XCTAssertEqual(bytes[1], 0x11)
        let arg = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(arg, 0x7FFF)
    }

    func testSetAutocenterSendsEnableAndStrength() throws {
        let (d, t) = make()
        try d.setAutocenter(strength: 75)
        let sent = t.sentPackets()
        XCTAssertEqual(sent.count, 2)
        guard case .interruptOut(_, let enable)   = sent[0] else { return XCTFail() }
        guard case .interruptOut(_, let strength) = sent[1] else { return XCTFail() }
        XCTAssertEqual(enable,   [0x40, 0x04, 0x01, 0x00])
        XCTAssertEqual(strength, [0x40, 0x03, 75,   0x00])
    }

    func testSetAutocenterZeroDisablesIt() throws {
        let (d, t) = make()
        try d.setAutocenter(strength: 0)
        guard case .interruptOut(_, let enable) = t.sentPackets()[0] else { return XCTFail() }
        XCTAssertEqual(enable, [0x40, 0x04, 0x00, 0x00])
    }

    func testStopAllEffectsEmits16StopPackets() throws {
        let (d, t) = make()
        try d.stopAllEffects()
        XCTAssertEqual(t.sentPackets().count, 16)
    }
}
