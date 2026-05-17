import Foundation
#if canImport(HIDDescriptors)
import HIDDescriptors
#endif
#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum PIDParseError: Error, Sendable, Hashable {
    case unknownReportID(UInt8)
    case truncatedReport(reportID: UInt8, length: Int)
    case unknownEffectType(UInt8)
    case slotUnregistered(UInt8)
}

public final class PIDParser: @unchecked Sendable {

    private var slotKind: [UInt8: EffectKind] = [:]

    public init() {}

    public func parse(reportID: UInt8, payload: [UInt8]) throws -> NormalizedEffect? {
        guard let id = PIDReportID(rawValue: reportID) else {
            throw PIDParseError.unknownReportID(reportID)
        }

        switch id {
        case .setEffect:
            try registerSlot(from: payload)
            return nil

        case .setConstant:
            return try decodeConstant(payload)

        case .setPeriodic:
            return try decodePeriodic(payload)

        case .setCondition:
            return try decodeCondition(payload)

        default:
            return nil
        }
    }

    public func kind(forSlot slot: UInt8) -> EffectKind? {
        slotKind[slot]
    }

    public func clear() {
        slotKind.removeAll()
    }

    private func registerSlot(from payload: [UInt8]) throws {
        guard payload.count >= 2 else {
            throw PIDParseError.truncatedReport(reportID: PIDReportID.setEffect.rawValue,
                                                length: payload.count)
        }
        let slot = payload[0]
        let typeByte = payload[1]
        guard let kind = EffectKind(rawValue: typeByte) else {
            throw PIDParseError.unknownEffectType(typeByte)
        }
        slotKind[slot] = kind
    }

    private func decodeConstant(_ payload: [UInt8]) throws -> NormalizedEffect {
        guard payload.count >= 2 else {
            throw PIDParseError.truncatedReport(reportID: PIDReportID.setConstant.rawValue,
                                                length: payload.count)
        }
        let slot = payload[0]
        let magnitude = Int16(Int8(bitPattern: payload[1])) * 256
        return .constant(slot: slot, magnitude: magnitude,
                         duration: 0, direction: 0, envelope: nil)
    }

    private func decodePeriodic(_ payload: [UInt8]) throws -> NormalizedEffect {
        guard payload.count >= 5 else {
            throw PIDParseError.truncatedReport(reportID: PIDReportID.setPeriodic.rawValue,
                                                length: payload.count)
        }
        let slot = payload[0]
        let mag = Int16(Int8(bitPattern: payload[1])) * 256
        let off = Int16(Int8(bitPattern: payload[2])) * 256
        let phase = UInt16(payload[3]) * 256
        let period = UInt32(payload[4]) * 10
        guard let kind = slotKind[slot] else {
            throw PIDParseError.slotUnregistered(slot)
        }
        return .periodic(slot: slot, kind: kind,
                         params: PeriodicParams(magnitude: mag, offset: off, phase: phase, period: period),
                         duration: 0, envelope: nil)
    }

    private func decodeCondition(_ payload: [UInt8]) throws -> NormalizedEffect {
        guard payload.count >= 6 else {
            throw PIDParseError.truncatedReport(reportID: PIDReportID.setCondition.rawValue,
                                                length: payload.count)
        }
        let slot = payload[0]
        let posCoeff = Int16(Int8(bitPattern: payload[1])) * 256
        let negCoeff = Int16(Int8(bitPattern: payload[2])) * 256
        let posSat   = Int16(Int8(bitPattern: payload[3])) * 256
        let negSat   = Int16(Int8(bitPattern: payload[4])) * 256
        let deadBand = UInt16(payload[5]) * 256
        let params = ConditionParams(positiveCoefficient: posCoeff,
                                     negativeCoefficient: negCoeff,
                                     positiveSaturation:  posSat,
                                     negativeSaturation:  negSat,
                                     deadBand:            deadBand,
                                     centerOffset:        0)
        let kind = slotKind[slot] ?? .spring
        switch kind {
        case .spring:   return .spring(slot: slot, params: params)
        case .damper:   return .damper(slot: slot, params: params)
        case .friction: return .friction(slot: slot, params: params)
        case .inertia:  return .inertia(slot: slot, params: params)
        default:        return .spring(slot: slot, params: params)
        }
    }
}
