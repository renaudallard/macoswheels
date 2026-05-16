import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TSeriesPhase3Tests: XCTestCase {

    func testTSXWCapabilities() {
        XCTAssertEqual(TSXWDriver.capabilities.rangeMaxDegrees, 1080)
        XCTAssertEqual(TSXWDriver.capabilities.pedalCount, 3)
        XCTAssertTrue(TSXWDriver.capabilities.supportedEffects.contains(.inertia))
    }

    func testTSPCCapabilities() {
        XCTAssertEqual(TSPCDriver.capabilities.rangeMaxDegrees, 1080)
        XCTAssertEqual(TSPCDriver.capabilities.buttonCount, 18)
    }

    func testT248ConsumerWheelMaxedAt900() {
        XCTAssertEqual(T248Driver.capabilities.rangeMaxDegrees, 900)
        XCTAssertFalse(T248Driver.capabilities.supportedEffects.contains(.inertia),
                       "T248 has no hardware inertia")
    }

    func testT128BootIdentityIsNilDirectPID() {
        XCTAssertNil(T128Driver.bootIdentity)
    }

    func testTGTRangeMatchesT300Range() {
        XCTAssertEqual(TGTDriver.capabilities.rangeMaxDegrees, 1080)
        XCTAssertEqual(TGTDriver.capabilities.rangeMinDegrees, 40)
    }

    func testT248InitializeUsesT300SettingsOpcode() throws {
        let t = MockUSBTransport()
        let d = T248Driver(transport: t, delegate: NoopDelegate())
        try d.initialize()
        let sent = t.sentPackets()
        guard case .interruptOut(_, let firstBytes) = sent[0] else { return XCTFail() }
        XCTAssertEqual(firstBytes[0], 0x02)
    }
}
