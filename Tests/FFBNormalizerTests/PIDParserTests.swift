import XCTest
@testable import FFBNormalizer
@testable import HIDDescriptors
@testable import WheelProtocol

final class PIDParserTests: XCTestCase {

    func testSetEffectRegistersSlotKind() throws {
        let p = PIDParser()
        let nilResult = try p.parse(reportID: PIDReportID.setEffect.rawValue,
                                    payload: [0x01, EffectKind.constant.rawValue])
        XCTAssertNil(nilResult)
        XCTAssertEqual(p.kind(forSlot: 0x01), .constant)
    }

    func testSetConstantProducesNormalizedConstant() throws {
        let p = PIDParser()
        _ = try p.parse(reportID: PIDReportID.setEffect.rawValue,
                        payload: [0x02, EffectKind.constant.rawValue])
        let effect = try p.parse(reportID: PIDReportID.setConstant.rawValue,
                                 payload: [0x02, 0x40])
        guard case .constant(let slot, let mag, _, _, _) = effect else {
            return XCTFail("expected .constant, got \(String(describing: effect))")
        }
        XCTAssertEqual(slot, 0x02)
        XCTAssertEqual(mag, Int16(Int8(bitPattern: 0x40)) * 256)
    }

    func testSetConditionDispatchesByRegisteredKind() throws {
        let p = PIDParser()
        _ = try p.parse(reportID: PIDReportID.setEffect.rawValue,
                        payload: [0x03, EffectKind.damper.rawValue])
        let damper = try p.parse(reportID: PIDReportID.setCondition.rawValue,
                                 payload: [0x03, 0x10, 0x10, 0x40, 0x40, 0x00])
        guard case .damper = damper else {
            return XCTFail("expected .damper, got \(String(describing: damper))")
        }
    }

    func testUnknownReportIDThrows() {
        let p = PIDParser()
        XCTAssertThrowsError(try p.parse(reportID: 0xFE, payload: []))
    }

    func testTruncatedReportThrows() {
        let p = PIDParser()
        XCTAssertThrowsError(try p.parse(reportID: PIDReportID.setEffect.rawValue, payload: [0x01]))
    }
}
