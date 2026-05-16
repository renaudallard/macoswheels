import XCTest
@testable import Drivers
@testable import WheelProtocol

final class T150DriverTests: XCTestCase {

    private func makeDriver() -> (T150Driver, MockUSBTransport, NoopDelegate) {
        let transport = MockUSBTransport()
        let delegate = NoopDelegate()
        let driver = T150Driver(transport: transport, delegate: delegate)
        return (driver, transport, delegate)
    }

    func testCapabilities() {
        let caps = T150Driver.capabilities
        XCTAssertEqual(caps.role, .wheelBase)
        XCTAssertEqual(caps.pedalCount, 2)
        XCTAssertEqual(caps.rangeMinDegrees, 270)
        XCTAssertEqual(caps.rangeMaxDegrees, 1080)
        XCTAssertTrue(caps.supportedEffects.contains(.constant))
        XCTAssertTrue(caps.supportedEffects.contains(.spring))
        XCTAssertFalse(caps.supportedEffects.contains(.inertia))
        XCTAssertFalse(caps.supportedEffects.contains(.customForceData))
    }

    func testRangeAcceptsValidValues() throws {
        let (d, _, _) = makeDriver()
        XCTAssertNoThrow(try d.setRotationRange(degrees: 270))
        XCTAssertNoThrow(try d.setRotationRange(degrees: 540))
        XCTAssertNoThrow(try d.setRotationRange(degrees: 1080))
    }

    func testRangeRejectsOutOfBoundsValues() {
        let (d, _, _) = makeDriver()
        XCTAssertThrowsError(try d.setRotationRange(degrees: 90)) { err in
            guard case DriverError.rangeOutOfBounds(let req, let min, let max) = err else {
                return XCTFail("expected rangeOutOfBounds, got \(err)")
            }
            XCTAssertEqual(req, 90)
            XCTAssertEqual(min, 270)
            XCTAssertEqual(max, 1080)
        }
        XCTAssertThrowsError(try d.setRotationRange(degrees: 1200))
    }

    func testSupportedIDsHasT150Firmware() {
        let ids = T150Driver.supportedIDs.map { ($0.vendorID, $0.productID) }
        XCTAssertTrue(ids.contains(where: { $0 == (0x044F, 0xB677) }))
    }

    func testBootIdentityMatchesGenericTSeriesBoot() {
        XCTAssertEqual(T150Driver.bootIdentity?.productID, 0xB65D)
    }
}
