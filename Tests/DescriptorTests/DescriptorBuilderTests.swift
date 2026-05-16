import XCTest
@testable import HIDDescriptors
@testable import WheelProtocol

final class DescriptorBuilderTests: XCTestCase {

    func testWheelBaseDescriptorWellFormed() {
        let caps = WheelCapabilities(role: .wheelBase, buttonCount: 13, pedalCount: 2,
                                     rangeMinDegrees: 270, rangeMaxDegrees: 1080)
        let bytes = DescriptorBuilder.build(for: caps)
        try? assertWellFormed(bytes)
        XCTAssertTrue(bytes.starts(with: [0x05, 0x01, 0x09, 0x04, 0xA1, 0x01]))
        XCTAssertEqual(bytes.last, 0xC0)
    }

    func testShifterDescriptorWellFormed() {
        let caps = WheelCapabilities(role: .shifter, buttonCount: 8, pedalCount: 0)
        let bytes = DescriptorBuilder.build(for: caps)
        try? assertWellFormed(bytes)
        XCTAssertEqual(bytes.last, 0xC0)
    }

    func testPedalsDescriptorWellFormed() {
        let caps = WheelCapabilities(role: .pedals, buttonCount: 0, pedalCount: 3)
        let bytes = DescriptorBuilder.build(for: caps)
        try? assertWellFormed(bytes)
        XCTAssertEqual(bytes.last, 0xC0)
    }

    func testButtonZeroOmitsButtonBlock() {
        let caps = WheelCapabilities(role: .wheelBase, buttonCount: 0, pedalCount: 0)
        let bytes = DescriptorBuilder.build(for: caps)
        var i = 0
        while i < bytes.count {
            let prefix = bytes[i]
            let size = Int(prefix & 0x03)
            let dataLen = (size == 3) ? 4 : size
            let tag  = (prefix >> 4) & 0x0F
            let type = (prefix >> 2) & 0x03
            if type == 0x01 && tag == 0x00 && dataLen >= 1 {
                XCTAssertNotEqual(bytes[i + 1], 0x09,
                                  "Button usage page found at item offset \(i)")
            }
            i += 1 + dataLen
        }
    }

    private func assertWellFormed(_ bytes: [UInt8]) throws {
        var i = 0
        var depth = 0
        while i < bytes.count {
            let prefix = bytes[i]
            let size = prefix & 0x03
            let tag  = (prefix >> 4) & 0x0F
            let type = (prefix >> 2) & 0x03
            let dataLen: Int = (size == 3) ? 4 : Int(size)
            i += 1 + dataLen
            if type == 0 && tag == 0xA { depth += 1 }
            if type == 0 && tag == 0xC { depth -= 1 }
            if depth < 0 { throw NSError(domain: "descriptor", code: 1) }
        }
        XCTAssertEqual(i, bytes.count, "descriptor length not parseable")
        XCTAssertEqual(depth, 0, "unbalanced collection")
    }
}
