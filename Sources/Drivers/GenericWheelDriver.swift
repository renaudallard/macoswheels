import Foundation
#if canImport(WheelProtocol)
import WheelProtocol
#endif

public final class GenericWheelDriver<Q: WheelQuirks>: DeviceDriver, @unchecked Sendable {
    public static var displayName: String { Q.displayName }
    public static var supportedIDs: [WheelIdentity] { Q.supportedIDs }
    public static var bootIdentity: WheelIdentity? { Q.bootIdentity }
    public static var capabilities: WheelCapabilities { Q.capabilities }

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?
    private let lock = NSLock()
    private var currentRangeDegrees: UInt16
    private var currentAutocenter: UInt8
    private var currentGain: UInt8

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
        self.currentRangeDegrees = Q.defaultRangeDegrees
        self.currentAutocenter = Q.defaultAutocenterPercent
        self.currentGain = Q.defaultGainPercent
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Q.supportedIDs[0], firmwareVersion: nil)
    }

    public func claim() throws {}

    public func initialize() throws {
        if Q.capabilities.supportsGain {
            for p in try Q.setGainPackets(percent: currentGain) {
                try transport.send(p)
            }
        }
        for p in try Q.setAutocenterPackets(percent: currentAutocenter) {
            try transport.send(p)
        }
        for p in try Q.setRotationRangePackets(degrees: currentRangeDegrees) {
            try transport.send(p)
        }
    }

    public func startReadLoop() throws {}
    public func teardown() {}

    public func setRotationRange(degrees: UInt16) throws {
        let caps = Q.capabilities
        guard (caps.rangeMinDegrees...caps.rangeMaxDegrees).contains(degrees) else {
            throw DriverError.rangeOutOfBounds(requested: degrees,
                                               min: caps.rangeMinDegrees,
                                               max: caps.rangeMaxDegrees)
        }
        for p in try Q.setRotationRangePackets(degrees: degrees) {
            try transport.send(p)
        }
        lock.lock()
        currentRangeDegrees = degrees
        lock.unlock()
    }

    public func setAutocenter(strength: UInt8) throws {
        let pct = min(strength, 100)
        for p in try Q.setAutocenterPackets(percent: pct) {
            try transport.send(p)
        }
        lock.lock()
        currentAutocenter = pct
        lock.unlock()
    }

    public func setGain(_ gain: UInt8) throws {
        guard Q.capabilities.supportsGain else {
            throw DriverError.effectNotSupported(.constant)
        }
        let pct = min(gain, 100)
        for p in try Q.setGainPackets(percent: pct) {
            try transport.send(p)
        }
        lock.lock()
        currentGain = pct
        lock.unlock()
    }

    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        try Q.encode(effect)
    }

    public func stopEffect(slot: UInt8) throws {
        try transport.send(try Q.stopEffectPacket(slot: slot))
    }

    public func stopAllEffects() throws {
        for slot in 0..<Q.hardwareSlotCount {
            if let pkt = try? Q.stopEffectPacket(slot: slot) {
                try? transport.send(pkt)
            }
        }
    }

    public func snapshot() -> (range: UInt16, autocenter: UInt8, gain: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        return (currentRangeDegrees, currentAutocenter, currentGain)
    }
}

public final class GenericShifterDriver<Q: ShifterQuirks>: DeviceDriver, @unchecked Sendable {
    public static var displayName: String { Q.displayName }
    public static var supportedIDs: [WheelIdentity] { Q.supportedIDs }
    public static var bootIdentity: WheelIdentity? { Q.bootIdentity }
    public static var capabilities: WheelCapabilities { Q.capabilities }

    private let transport: any USBTransport
    private weak var delegate: (any DeviceDriverDelegate)?

    public init(transport: any USBTransport, delegate: any DeviceDriverDelegate) {
        self.transport = transport
        self.delegate = delegate
    }

    public func probe() throws -> ProbeResult {
        ProbeResult(identity: Q.supportedIDs[0], firmwareVersion: nil)
    }
    public func claim() throws {}
    public func initialize() throws {}
    public func startReadLoop() throws {}
    public func teardown() {}

    public func setRotationRange(degrees: UInt16) throws {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func setAutocenter(strength: UInt8) throws {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func setGain(_ gain: UInt8) throws {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func encode(_ effect: NormalizedEffect) throws -> [USBPacket] {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func stopEffect(slot: UInt8) throws {
        throw DriverError.unsupportedForRole(.shifter)
    }
    public func stopAllEffects() throws {
        throw DriverError.unsupportedForRole(.shifter)
    }
}
