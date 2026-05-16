import XCTest
@testable import Drivers
@testable import WheelProtocol

final class TMSettingsTests: XCTestCase {

    func testGainPacketScales0to100() {
        guard case .interruptOut(let ep, let bytes) = TMSettings.setGainPacket(percent: 0) else {
            return XCTFail("expected interruptOut")
        }
        XCTAssertEqual(ep, 0x02)
        XCTAssertEqual(bytes, [0x43, 0x00])

        guard case .interruptOut(_, let mid) = TMSettings.setGainPacket(percent: 50) else { return }
        XCTAssertEqual(mid, [0x43, 0x7F])

        guard case .interruptOut(_, let max) = TMSettings.setGainPacket(percent: 100) else { return }
        XCTAssertEqual(max, [0x43, 0xFF])
    }

    func testRangePacketEncodes1080AsFFFF() {
        guard case .interruptOut(let ep, let bytes)
                = TMSettings.setRotationRangePacket(degrees: 1080, maxDegrees: 1080) else {
            return XCTFail("expected interruptOut")
        }
        XCTAssertEqual(ep, 0x02)
        XCTAssertEqual(bytes, [0x40, 0x11, 0xFF, 0xFF])
    }

    func testRangePacketEncodes540AsHalf() {
        guard case .interruptOut(_, let bytes)
                = TMSettings.setRotationRangePacket(degrees: 540, maxDegrees: 1080) else { return }
        XCTAssertEqual(bytes[0], 0x40)
        XCTAssertEqual(bytes[1], 0x11)
        let arg = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        XCTAssertEqual(arg, 0x7FFF)
    }

    func testAutocenterStrengthEncodesPercent() {
        guard case .interruptOut(_, let bytes)
                = TMSettings.setAutocenterStrengthPacket(percent: 50) else { return }
        XCTAssertEqual(bytes, [0x40, 0x03, 50, 0])
    }

    func testAutocenterEnabledEncodesBoolean() {
        guard case .interruptOut(_, let on) = TMSettings.setAutocenterEnabledPacket(true) else { return }
        guard case .interruptOut(_, let off) = TMSettings.setAutocenterEnabledPacket(false) else { return }
        XCTAssertEqual(on,  [0x40, 0x04, 1, 0])
        XCTAssertEqual(off, [0x40, 0x04, 0, 0])
    }
}
