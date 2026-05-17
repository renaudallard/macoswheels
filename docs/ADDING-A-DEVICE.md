# Adding a wheel, shifter, pedal set or handbrake

The DRY refactor (`GenericWheelDriver<Q: WheelQuirks>`) made adding a wheel
mostly a per-`Quirks`-struct change. This is the end-to-end checklist.

## 1. Capture the protocol

Plug the device into a Linux machine with the right kernel driver loaded
(`hid-tmff2`, `new-lg4ff`, `t150_driver`, or whatever the device uses). Make
sure FFB works in a known game first — if it doesn't, your capture won't be
useful.

Capture USB traffic with `usbmon`:

```sh
sudo modprobe usbmon
sudo tshark -i usbmonN -w device.pcapng
# in another terminal:
#   - run a game that calls every FFB effect type
#   - run `oversteer` (Logitech) or `tmff-utils` to exercise settings
```

Save the resulting `.pcapng` under `docs/PROTOCOL-NOTES/<device>/` and write
a short `<device>.md` summarising the boot sequence, settings packets, and
each effect's wire format. Use [`T300.md`](PROTOCOL-NOTES/T300.md) and
[`Logitech.md`](PROTOCOL-NOTES/Logitech.md) as the template.

## 2. Register the (VID, PID) tuples

In [`Sources/WheelRegistry/DeviceMatch.swift`](../Sources/WheelRegistry/DeviceMatch.swift),
add one entry per identifier the device may enumerate as:

- Boot identity (if the device requires a boot↔firmware switch): mode `.boot`,
  point the firmware entries' `bootIdentity` at it.
- Firmware identity: mode `.firmware`, with `bootIdentity` set if applicable.

Pick a short `driverName` (e.g. `"T128"`, `"G29"`). It's the key the DEXT
uses in `MacoswheelsDriver.makeDriver(for:transport:)` to instantiate the
right concrete driver.

## 3. Add IOKitPersonalities

In [`Sources/DEXT/Info.plist`](../Sources/DEXT/Info.plist), add a
personality for each (VID, PID) tuple:

- `IOProviderClass = IOUSBHostInterface`
- `IOClass = IOUserService`
- `IOUserClass = MacoswheelsDriver`
- `idVendor`, `idProduct` as integers (decimal!)
- `IOProbeScore = 10000` so we beat Apple's generic gamepad driver
- `IOMatchCategory` set to something unique per personality
- `WheelMode` = `"boot"` or `"firmware"`

## 4. Write a Quirks struct + typealias

In `Sources/Drivers/<Vendor>/<Model>Driver.swift`, write:

```swift
import Foundation
#if canImport(WheelProtocol)
import WheelProtocol
#endif

public enum NewWheelQuirks: WheelQuirks {
    public static let displayName = "Vendor Model"
    public static let supportedIDs: [WheelIdentity] = [
        WheelIdentity(vendorID: 0xVVVV, productID: 0xPPPP,
                      model: displayName, role: .wheelBase),
    ]
    public static let bootIdentity: WheelIdentity? = nil  // or a boot WheelIdentity

    public static let capabilities = WheelCapabilities(
        role: .wheelBase,
        buttonCount: N,
        pedalCount: N,
        hasHat: true,
        hasClutch: true,
        rangeMinDegrees: 40,
        rangeMaxDegrees: 900,
        supportedEffects: [ .constant, .spring, .damper, /* ... */ ],
        supportsAutocenter: true,
        supportsGain: false
    )
    public static let defaultRangeDegrees: UInt16 = 900

    public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] { /* ... */ }
    public static func setAutocenterPackets(percent: UInt8) throws -> [USBPacket] { /* ... */ }
    public static func setGainPackets(percent: UInt8) throws -> [USBPacket] { /* ... */ }
    public static func encode(_ effect: NormalizedEffect) throws -> [USBPacket] { /* ... */ }
    public static func stopEffectPacket(slot: UInt8) throws -> USBPacket { /* ... */ }

    // Optional input report parsing override:
    public static func parseInputReport(raw: [UInt8]) -> [UInt8]? { /* ... */ }
}

public typealias NewWheelDriver = GenericWheelDriver<NewWheelQuirks>
```

For shifters or pedal sets, use `ShifterQuirks` + `GenericShifterDriver` instead.
There's much less to fill in.

## 5. Wire it into `MacoswheelsDriver.makeDriver`

In [`Sources/DEXT/MacoswheelsDriver.swift`](../Sources/DEXT/MacoswheelsDriver.swift),
add a case to the `switch entry.driverName` block in `makeDriver(for:transport:)`:

```swift
case "NewWheel": return NewWheelDriver(transport: transport, delegate: dummy)
```

## 6. Reuse family-shared code

If the wheel shares a protocol family with an existing wheel — most Thrustmaster
T300-class wheels do (`T300Settings`, `T300FFBEncoder`), most Logitech G-class
wheels do (`LGSettings`, `LGFFBEncoder`) — your packet builders can usually
just delegate:

```swift
public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
    try T300Quirks.setRotationRangePackets(degrees: degrees)
}
```

## 7. Tests

Copy [`Tests/WheelProtocolTests/T150DriverTests.swift`](../Tests/WheelProtocolTests/T150DriverTests.swift)
to `Tests/WheelProtocolTests/<NewWheel>DriverTests.swift` and adjust the
type name. Verify:

- Capabilities are what you expect.
- Range bounds reject out-of-bounds values.
- `initialize()` sends the right packets in the right order.

Add golden-byte tests derived from your pcap:

```swift
func testConstantForceAt50PercentEncoding() throws {
    let pkts = try NewWheelQuirks.encode(
        .constant(slot: 0, magnitude: 0x4000, duration: 1000, direction: 0, envelope: nil))
    guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
    XCTAssertEqual(bytes, [/* exact bytes from the capture */])
}
```

## 8. Entitlements

If the device introduces a new vendor (not Thrustmaster 0x044F, not Logitech
0x046D), add it to
[`Sources/DEXT/Macoswheels.entitlements`](../Sources/DEXT/Macoswheels.entitlements):

```xml
<dict>
    <key>idVendor</key>
    <integer>NEW_VENDOR_DECIMAL</integer>
</dict>
```

## 9. README and man pages

Add the device to the supported-devices tables in
[`README.md`](../README.md) and to
[`man/macoswheels.7`](../man/macoswheels.7).

## 10. Verify

```sh
swift build
swift test
.build/debug/macoswheels list   # the new wheel should appear
.build/debug/macoswheels dump-effect constant --slot 0 --magnitude 16384   # see exact bytes
```

CI will run the same checks on push. Once green, the device is available
to anyone who builds a release zip — though FFB will only work on a real
Mac after the DEXT compile issue (see [`DEV-MODE-SETUP.md`](DEV-MODE-SETUP.md#4-why-ci-doesnt-compile-the-dext))
is resolved or the DEXT is rewritten in IIG.

## Tips

- **Numbers in `Info.plist` are decimal**, not hex. `0xB677 = 46711`.
- **Boot vs firmware ordering matters.** If the boot personality has a higher
  `IOProbeScore` than the firmware one, the kernel will keep matching the boot
  shim and the wheel will never reveal its real PID. Keep them at the same
  score and let `IOMatchCategory` segregate them.
- **`supportsGain = false` on Logitech wheels** is real — they don't have a
  software gain knob like Thrustmasters do. Don't lie or `setGain` will appear
  to work but do nothing.
- **`rangeMaxDegrees` clamps from the firmware side too.** Be honest about what
  the hardware can do.
