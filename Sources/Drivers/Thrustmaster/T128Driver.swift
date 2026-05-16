import Foundation
import WheelProtocol

public final class T128Driver: DeviceDriver, @unchecked Sendable {

    public static let displayName = "Thrustmaster T128"

    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0x044F, productID: 0xB68F,
                      model: T128Driver.displayName, role: .wheelBase),
    ]

    public static let bootIdentity: WheelIdentity? = nil

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: 12,
        pedalCount: 2,
        hasHat: true,
        rangeMinDegrees: 270,
        rangeMaxDegrees: 900,
        supportedEffects: [
            .constant,
            .squarePeriodic, .sinePeriodic, .trianglePeriodic,
            .sawtoothUpPeriodic, .sawtoothDownPeriodic,
            .spring, .damper,
        ],
        supportsAutocenter: true,
        supportsGain: true
    )

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?
    private let lock = NSLock()
    private var currentRangeDegrees: UInt16 = 900
    private var currentAutocenter: UInt8 = 0
    private var currentGain: UInt8 = 75

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Self.supportedIDs[0], firmwareVersion: nil)
    }
    public func claim() throws {}
    public func initialize() throws {}
    public func startReadLoop() throws {}
    public func teardown() {}

    public func setRotationRange(degrees: UInt16) throws {
        let caps = Self.capabilities
        guard (caps.rangeMinDegrees...caps.rangeMaxDegrees).contains(degrees) else {
            throw DriverError.rangeOutOfBounds(requested: degrees,
                                               min: caps.rangeMinDegrees,
                                               max: caps.rangeMaxDegrees)
        }
        lock.lock(); currentRangeDegrees = degrees; lock.unlock()
        throw DriverError.notImplemented
    }

    public func setAutocenter(strength: UInt8) throws {
        lock.lock(); currentAutocenter = min(strength, 100); lock.unlock()
        throw DriverError.notImplemented
    }

    public func setGain(_ gain: UInt8) throws {
        lock.lock(); currentGain = min(gain, 100); lock.unlock()
        throw DriverError.notImplemented
    }

    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        throw DriverError.notImplemented
    }
    public func stopEffect(slot: UInt8) throws { throw DriverError.notImplemented }
    public func stopAllEffects() throws         { throw DriverError.notImplemented }
}
