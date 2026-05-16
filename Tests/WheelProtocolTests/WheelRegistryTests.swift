import XCTest
@testable import WheelRegistry
@testable import WheelProtocol

final class WheelRegistryTests: XCTestCase {

    func testT150BootAndFirmwarePresent() {
        let boot = DeviceMatch.entry(forVID: 0x044F, pid: 0xB677)
        let fw   = DeviceMatch.entry(forVID: 0x044F, pid: 0xB65D)
        XCTAssertNotNil(boot)
        XCTAssertNotNil(fw)
        XCTAssertEqual(boot?.mode, .boot)
        XCTAssertEqual(fw?.mode,   .firmware)
        XCTAssertEqual(fw?.bootIdentity?.productID, 0xB677)
    }

    func testLogitechG29Present() {
        let g29 = DeviceMatch.entry(forVID: 0x046D, pid: 0xC24F)
        XCTAssertEqual(g29?.identity.model, "Logitech G29")
    }

    func testNoDuplicateVIDPIDPairs() {
        let pairs = DeviceMatch.entries.map { "\($0.identity.vendorID)-\($0.identity.productID)" }
        XCTAssertEqual(pairs.count, Set(pairs).count, "duplicate VID:PID pair in registry")
    }
}
