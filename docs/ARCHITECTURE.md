# Architecture

```
+----------------------- Game / CrossOver / Wine ----------------------+
                              |
                              | IOHIDManager + PID 1.0 output reports
                              v
+--------------- macoswheels DEXT (IIG / C++, DriverKit) --------------+
|                                                                     |
|  (d) ConfigPlane      MacoswheelsUserClient : IOUserClient          |
|  (c) HID re-export    HIDExport             : IOUserHIDDevice       |
|  (b) Device driver    any DeviceDriver       (plugin per device)    |
|  (a) USB transport    USBTransport over IOUSBHostInterface          |
|                                                                     |
+---------------------------------------------------------------------+
                              |   USB control + interrupt
                              v
                +-------------+-------------+
                |    Thrustmaster T150,     |
                |  TH8A shifter, Logitech   |
                |  G29 base + G29 shifter…  |
                +---------------------------+

+ macoswheels (CLI)            : IOServiceOpen + selector calls
+ MacoswheelsContainer.app     : OSSystemExtensionRequest activation
+ macoswheels-restore (Launch  : reapplies rotation/autocenter at login
  Agent invocation of CLI)
```

The DEXT has strict downward dependencies between four layers:

- **(a) USB transport.** Wraps `IOUSBHostInterface` and its pipes behind the
  `USBTransport` protocol. A `MockUSBTransport` implementation under `Tests/`
  records sent packets and replays canned interrupt-IN payloads, so the entire
  driver layer is testable on Linux.
- **(b) Device driver.** One conformance of `DeviceDriver` per wheel model.
  Knows nothing about IOKit. Owns the wire protocol: init sequence, FFB byte
  encoding, rotation-range and autocenter commands, slot bookkeeping.
- **(c) HID re-export.** `HIDExport: IOUserHIDDevice` publishes the wheel
  with a HID descriptor synthesized from the matched driver's
  `WheelCapabilities`. Input reports come from the device driver via a
  delegate callback; output reports (PID Set-Effect) are forwarded into the
  `FFBNormalizer`.
- **(d) Config plane.** `MacoswheelsUserClient: IOUserClient` exposes a fixed
  selector table to the `macoswheels` CLI. Method numbers and struct shapes
  live in `Sources/ConfigPlane/UserClientAPI.swift`, shared verbatim with the
  CLI side.

## Plugin contract

```swift
public protocol DeviceDriver: AnyObject {
    static var supportedIDs:   [WheelIdentity] { get }
    static var bootIdentity:   WheelIdentity?  { get }
    static var capabilities:   WheelCapabilities { get }

    init(transport: any USBTransport, delegate: any DeviceDriverDelegate)

    func probe()        throws -> ProbeResult
    func claim()        throws
    func initialize()   throws
    func startReadLoop() throws
    func teardown()

    func setRotationRange(degrees: UInt16) throws
    func setAutocenter(strength: UInt8)    throws
    func setGain(_ gain: UInt8)            throws

    func encode(_ effect: NormalizedEffect) throws -> [USBPacket]
    func stopEffect(slot: UInt8) throws
    func stopAllEffects() throws
}
```

Shifters and stand-alone pedals also implement `DeviceDriver`. Methods that
don't apply to their role throw `DriverError.unsupportedForRole`.

## Boot-to-firmware PID swap

Many T-series wheels enumerate at a "boot" PID and need a vendor control
transfer to flip into "firmware" mode, after which they re-enumerate at a
different PID with the full HID interface. macoswheels handles this with two
`IOKitPersonalities` entries per affected wheel:

- The boot personality instantiates a small shim driver whose `Start` issues
  the control transfer and returns. The device disconnects and reconnects.
- The firmware personality matches the new PID and runs the real
  `MacoswheelsDriver` lifecycle.

The personality list is the source of truth for the device-match table in
`Sources/WheelRegistry/DeviceMatch.swift`. A future `PersonalitiesGen.swift`
build plugin will derive the `Info.plist` fragments from that table so the
two never drift.

## FFB pipeline

```
game writes PID Set Effect Report
  -> HIDExport.setReport(reportID:type:bytes:)
  -> PIDParser.parse(reportID, payload)            // NormalizedEffect
  -> Synthesizer.downgrade(effect, supported)      // optional fallbacks
  -> DeviceDriver.encode(effect)                   // -> [USBPacket]
  -> USBTransport.send(packet, on: outPipe)
```

`NormalizedEffect` is an enum with associated values, so encoders pattern-match
against a flat representation rather than re-parsing PID bytes. Effect slot
state lives in `PIDParser`, not in each driver.

## Why pure-Swift libs

Everything except `DEXT/` and `Container/` is a SwiftPM target with no IOKit
dependency. That gives us a fast Linux-side unit test loop (relevant because
the dev host is Debian arm64 with no Mac in the loop, only GitHub Actions).
DEXT-specific files use `#if canImport(DriverKit)` guards so they live in the
same repo without breaking the Linux build.
