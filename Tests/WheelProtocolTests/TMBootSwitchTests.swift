import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TMBootSwitchTests: XCTestCase {

    func testModelQueryShape() {
        guard case .control(let setup, let payload) = TMBootSwitch.modelQueryPacket() else {
            return XCTFail("expected control")
        }
        XCTAssertEqual(setup.bmRequestType, 0xC1)
        XCTAssertEqual(setup.bRequest, 73)
        XCTAssertEqual(setup.wValue, 0)
        XCTAssertEqual(setup.wIndex, 0)
        XCTAssertTrue(payload.isEmpty)
    }

    func testModeSwitchEncodesValue() {
        guard case .control(let setup, _) = TMBootSwitch.modeSwitchPacket(value: 0x0006) else {
            return XCTFail()
        }
        XCTAssertEqual(setup.bmRequestType, 0x41)
        XCTAssertEqual(setup.bRequest, 83)
        XCTAssertEqual(setup.wValue, 0x0006)
    }

    func testModelTableHasT150() {
        let m = TMModelTable.lookup(model: 0x03, attachment: 0x06)
        XCTAssertEqual(m?.switchValue, 0x0006)
        XCTAssertEqual(m?.name, "T150RS")
    }

    func testModelTableHasT300VariantsAll005() {
        for att: UInt8 in [0x00, 0x03, 0x04, 0x06, 0x09] {
            XCTAssertEqual(TMModelTable.lookup(model: 0x02, attachment: att)?.switchValue, 0x0005)
        }
    }

    func testParseModelQueryExtractsModelAttachment() {
        let bytes: [UInt8] = [0x49, 0x00, 0, 0, 0, 0, 0x06, 0x03]
        let r = TMBootSwitch.parseModelQuery(bytes)
        XCTAssertEqual(r?.model, 0x03)
        XCTAssertEqual(r?.attachment, 0x06)
    }
}
