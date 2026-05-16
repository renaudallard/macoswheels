import XCTest
@testable import Drivers
@testable import WheelProtocol
@testable import WheelRegistry

final class LogitechPhase6Tests: XCTestCase {

    func testG25BootIdentity() {
        XCTAssertEqual(G25Driver.bootIdentity?.productID, 0xC294)
    }

    func testG27HasFriction() {
        XCTAssertTrue(G27Driver.capabilities.supportedEffects.contains(.friction))
    }

    func testG923HasThreeVariants() {
        let ids = G923Driver.supportedIDs.map(\.productID)
        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(ids.contains(0xC266))
        XCTAssertTrue(ids.contains(0xC267))
        XCTAssertTrue(ids.contains(0xC26E))
    }

    func testGShifterIsShifterRole() {
        XCTAssertEqual(GShifterDriver.capabilities.role, .shifter)
    }

    func testDeviceMatchHasAllG923Variants() {
        XCTAssertNotNil(DeviceMatch.entry(forVID: 0x046D, pid: 0xC266))
        XCTAssertNotNil(DeviceMatch.entry(forVID: 0x046D, pid: 0xC267))
        XCTAssertNotNil(DeviceMatch.entry(forVID: 0x046D, pid: 0xC26E))
    }

    func testDeviceMatchHasDFPandDFGT() {
        XCTAssertEqual(DeviceMatch.entry(forVID: 0x046D, pid: 0xC298)?.identity.model.contains("Driving Force Pro"), true)
        XCTAssertEqual(DeviceMatch.entry(forVID: 0x046D, pid: 0xC29A)?.identity.model.contains("Driving Force GT"), true)
    }

    func testG25InitializeSendsRangePacket() throws {
        let t = MockUSBTransport()
        let d = G25Driver(transport: t, delegate: NoopDelegate())
        try d.initialize()
        guard case .interruptOut(_, let bytes) = t.sentPackets()[0] else { return XCTFail() }
        XCTAssertEqual(bytes[0], 0xF8)
        XCTAssertEqual(bytes[1], 0x81)
    }
}
