import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TMBootSwitchTests: XCTestCase {

    func testBootSwitchPacketShape() {
        guard case .control(let setup, let payload) = TMBootSwitch.packet() else {
            XCTFail("expected .control packet"); return
        }
        XCTAssertEqual(setup.bmRequestType, 0x41)
        XCTAssertEqual(setup.bRequest, 0x53)
        XCTAssertEqual(setup.wValue, 0x0001)
        XCTAssertEqual(setup.wIndex, 0x0000)
        XCTAssertTrue(payload.isEmpty)
    }
}
