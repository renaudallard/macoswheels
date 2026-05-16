import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TH8AShifterTests: XCTestCase {

    func testRoleIsShifter() {
        XCTAssertEqual(TH8AShifterDriver.capabilities.role, .shifter)
    }

    func testNoFFBOrSettings() {
        let caps = TH8AShifterDriver.capabilities
        XCTAssertEqual(caps.supportedEffects, [])
        XCTAssertFalse(caps.supportsAutocenter)
        XCTAssertFalse(caps.supportsGain)
    }

    func testWheelOnlyMethodsThrowUnsupportedForRole() {
        let d = TH8AShifterDriver(transport: MockUSBTransport(), delegate: NoopDelegate())
        XCTAssertThrowsError(try d.setRotationRange(degrees: 540)) { err in
            guard case DriverError.unsupportedForRole(.shifter) = err else { return XCTFail() }
        }
        XCTAssertThrowsError(try d.setAutocenter(strength: 50))
        XCTAssertThrowsError(try d.setGain(75))
    }

    func testEncodeFailsForShifter() {
        let d = TH8AShifterDriver(transport: MockUSBTransport(), delegate: NoopDelegate())
        XCTAssertThrowsError(try d.encode(
            .constant(slot: 0, magnitude: 0, duration: 0, direction: 0, envelope: nil)))
    }
}
