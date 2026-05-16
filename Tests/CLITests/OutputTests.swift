import XCTest
@testable import ConfigPlane

final class OutputTests: XCTestCase {

    func testWheelInfoRoundtripsThroughJSON() throws {
        let info = WheelInfo(registryID: 0xDEADBEEF, vendorID: 0x044F, productID: 0xB65D,
                             model: "Thrustmaster T150", firmwareVersion: "0.1",
                             currentRangeDegrees: 900, currentAutocenter: 50, currentGain: 80)
        let data = try JSONEncoder().encode(info)
        let back = try JSONDecoder().decode(WheelInfo.self, from: data)
        XCTAssertEqual(back, info)
    }

    func testSetRangeRequestRoundtrip() throws {
        let req = SetRangeRequest(registryID: 1, degrees: 540)
        let data = try JSONEncoder().encode(req)
        let back = try JSONDecoder().decode(SetRangeRequest.self, from: data)
        XCTAssertEqual(back, req)
    }
}
