import XCTest
@testable import FFBNormalizer
@testable import WheelProtocol

final class SynthesizerTests: XCTestCase {

    private let cond = ConditionParams(positiveCoefficient: 100,
                                       negativeCoefficient: 100,
                                       positiveSaturation: 0x7F00,
                                       negativeSaturation: 0x7F00,
                                       deadBand: 0,
                                       centerOffset: 0)

    func testConstantPassesWhenSupported() {
        let e = NormalizedEffect.constant(slot: 1, magnitude: 0x4000,
                                          duration: 0, direction: 0, envelope: nil)
        XCTAssertNotNil(Synthesizer.downgrade(e, supported: [.constant]))
    }

    func testConstantDroppedWhenUnsupported() {
        let e = NormalizedEffect.constant(slot: 1, magnitude: 0x4000,
                                          duration: 0, direction: 0, envelope: nil)
        XCTAssertNil(Synthesizer.downgrade(e, supported: []))
    }

    func testInertiaDowngradesToDamperWhenAvailable() {
        let e = NormalizedEffect.inertia(slot: 2, params: cond)
        guard case .damper(let slot, let params)? = Synthesizer.downgrade(e, supported: [.damper]) else {
            return XCTFail("expected damper downgrade")
        }
        XCTAssertEqual(slot, 2)
        XCTAssertEqual(params.positiveCoefficient, cond.positiveCoefficient)
    }

    func testInertiaDroppedWhenNoFallback() {
        let e = NormalizedEffect.inertia(slot: 2, params: cond)
        XCTAssertNil(Synthesizer.downgrade(e, supported: [.constant]))
    }
}
