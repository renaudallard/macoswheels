import Foundation
import ConfigPlane

enum WheelClientError: Error {
    case dextNotLoaded
    case kernelError(Int32)
    case notImplementedOnPlatform
}

#if os(macOS) && canImport(IOKit)

import IOKit

final class WheelClient {
    private var connection: io_connect_t = 0

    init() throws {
        guard let matching = IOServiceMatching(driverServiceClassName) else {
            throw WheelClientError.dextNotLoaded
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { throw WheelClientError.dextNotLoaded }
        defer { IOObjectRelease(service) }
        let rc = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard rc == kIOReturnSuccess else { throw WheelClientError.kernelError(rc) }
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    func setRotationRange(degrees: UInt16, registryID: UInt64) throws {
        var input = SetRangeRequest(registryID: registryID, degrees: degrees)
        try callStruct(selector: .setRotationRange, input: &input)
    }

    func setAutocenter(percent: UInt8, registryID: UInt64) throws {
        var input = SetByteRequest(registryID: registryID, value: percent)
        try callStruct(selector: .setAutocenter, input: &input)
    }

    func setGain(percent: UInt8, registryID: UInt64) throws {
        var input = SetByteRequest(registryID: registryID, value: percent)
        try callStruct(selector: .setGain, input: &input)
    }

    func reset(registryID: UInt64) throws {
        var input = registryID
        try callStruct(selector: .reset, input: &input)
    }

    private func callStruct<T>(selector: UserClientSelector, input: inout T) throws {
        let size = MemoryLayout<T>.size
        let rc = withUnsafePointer(to: &input) { ptr -> kern_return_t in
            IOConnectCallStructMethod(connection,
                                      selector.rawValue,
                                      ptr,
                                      size,
                                      nil,
                                      nil)
        }
        guard rc == kIOReturnSuccess else { throw WheelClientError.kernelError(rc) }
    }
}

#else

final class WheelClient {
    init() throws { throw WheelClientError.notImplementedOnPlatform }
    func setRotationRange(degrees: UInt16, registryID: UInt64) throws {
        throw WheelClientError.notImplementedOnPlatform
    }
    func setAutocenter(percent: UInt8, registryID: UInt64) throws {
        throw WheelClientError.notImplementedOnPlatform
    }
    func setGain(percent: UInt8, registryID: UInt64) throws {
        throw WheelClientError.notImplementedOnPlatform
    }
    func reset(registryID: UInt64) throws {
        throw WheelClientError.notImplementedOnPlatform
    }
}

#endif
