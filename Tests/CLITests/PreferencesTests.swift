import XCTest
@testable import CLI

final class PreferencesTests: XCTestCase {

    func testEmptyDefaultsRoundtrip() throws {
        let p = Preferences()
        let data = try PropertyListEncoder().encode(p)
        let back = try PropertyListDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(p, back)
    }

    func testPopulatedRoundtrip() throws {
        let p = Preferences(rotationRangeDegrees: 900, autocenterPercent: 50, gainPercent: 80)
        let data = try PropertyListEncoder().encode(p)
        let back = try PropertyListDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(p, back)
    }
}
