# Adding a wheel, shifter, pedal set or handbrake

Two halves: the Swift reference library (Linux-testable, where you nail down
the byte layout) and the IIG / C++ DEXT (what actually ships to macOS). Add
the device in that order so the Swift side acts as a fixture for the C++
encoder you write next.

## 1. Capture the protocol

Plug the device into a Linux machine with the right kernel driver loaded
(`hid-tmff2`, `new-lg4ff`, `scarburato/t150_driver`, or whatever the device
uses). Make sure FFB works in a known game first — if it doesn't, your
capture won't be useful.

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

## 2. Register the (VID, PID) in the Swift registry

In [`Sources/WheelRegistry/DeviceMatch.swift`](../Sources/WheelRegistry/DeviceMatch.swift),
add one entry per identifier the device may enumerate as:

- Boot identity (if the device requires a boot↔firmware switch): set
  `bootIdentity` on the firmware entries to point at it.
- Firmware identity: with `bootIdentity` set if applicable.

The Swift registry is consumed by the CLI (`macoswheels list`) and the
golden-byte tests; the DEXT has its own C++ registry, wired up in step 6
below.

## 3. Add IOKitPersonalities

In [`Sources/DEXT/Info.plist`](../Sources/DEXT/Info.plist), add a
personality for each (VID, PID) tuple:

- `IOProviderClass = IOUSBHostInterface`
- `IOClass = IOUserService`
- `IOUserClass = MacoswheelsDriver`
- `idVendor`, `idProduct` as integers — **decimal, not hex**
- `IOProbeScore = 10000` so we beat Apple's generic gamepad driver
- `IOMatchCategory` set to something unique per personality
- `WheelMode` = `"boot"` or `"firmware"` — the driver reads this to decide
  whether to run the boot shim or the full lifecycle

## 4. Write a Swift Quirks struct + typealias

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
    public static let bootIdentity: WheelIdentity? = nil

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
}

public typealias NewWheelDriver = GenericWheelDriver<NewWheelQuirks>
```

If the wheel shares a protocol family with an existing wheel — most
Thrustmaster T300-class wheels do (`T300Settings`, `T300FFBEncoder`), most
Logitech G-class wheels do (`LGSettings`, `LGFFBEncoder`) — the new packet
builders should just delegate:

```swift
public static func setRotationRangePackets(degrees: UInt16) throws -> [USBPacket] {
    try T300Quirks.setRotationRangePackets(degrees: degrees)
}
```

## 5. Write the matching XCTests

Copy [`Tests/WheelProtocolTests/T150DriverTests.swift`](../Tests/WheelProtocolTests/T150DriverTests.swift)
to `Tests/WheelProtocolTests/<NewWheel>DriverTests.swift` and adjust the
type name. Verify:

- Capabilities are what you expect.
- Range bounds reject out-of-bounds values.
- Each effect kind encodes to the **exact** bytes from your pcap capture
  (this is the contract the C++ port has to match in step 6).

```swift
func testConstantForceAt50PercentEncoding() throws {
    let pkts = try NewWheelQuirks.encode(
        .constant(slot: 0, magnitude: 0x4000, duration: 1000,
                  direction: 0, envelope: nil))
    guard case .interruptOut(_, let bytes) = pkts[0] else { return XCTFail() }
    XCTAssertEqual(bytes, [/* exact bytes from the capture */])
}
```

`swift test` on Linux should now go green for the new wheel.

## 6. Port the encoder + settings into the C++ DEXT

This is the step that makes the wheel actually work on macOS.

### 6a. Endpoints and shared modules

If the wheel reuses an existing family, you can stop here: the Logitech
family all share `LGSettings` + `LGFFBEncoder`; the T300 family all share
`T300Settings` + `T300FFBEncoder`. T150 has its own `TMSettings` +
`TMFFBEncoder`. Skip to 6b.

If the wheel is in a new family, port its settings and FFB byte-builders
from Swift to C++ under `Sources/DEXT/`. Mirror the Swift API shape
function-by-function so the golden-byte tests are easy to mentally
diff-check. Each function takes raw `uint8_t *out` and returns the byte
count written — no `OSData`, no STL.

### 6b. Add a `WheelProtocol` vtable instance

In a `*Protocols.cpp` file under `Sources/DEXT/`, write a vtable for the
new wheel using the existing per-family macros:

```cpp
const WheelProtocol kNewWheelProtocol = {
    .displayName            = "Vendor Model",
    .vendorID               = 0xVVVV,
    .productID              = 0xPPPP,
    .minRangeDegrees        = 40,
    .maxRangeDegrees        = 900,
    .interruptInEndpoint    = 0x81,
    .interruptOutEndpoint   = 0x02,         // 0 for shifters
    .hardwareSlotCount      = 16,
    .setRotationRange       = &FamilySettings::setRotationRangePacket,
    .setAutocenterEnable    = &FamilySettings::setAutocenterEnabledPacket,
    .setAutocenterStrength  = &FamilySettings::setAutocenterStrengthPacket,
    .setGain                = &FamilySettings::setGainPacket,
    .encodeEffect           = &encodeFamilyEffect,
    // optional fields default to nullptr via designated init zero-fill:
    // prepareInputStream, translateInputReport, setAutocenter
};
```

For shifters and other no-FFB devices: leave `interruptOutEndpoint = 0`,
`encodeEffect = nullptr`, and all settings function pointers `nullptr`.
The driver gates pipe acquisition and the PID-block splice on those nulls.

### 6c. Register the vtable

Add an `extern const WheelProtocol kNewWheelProtocol;` line to
[`Sources/DEXT/WheelProtocol.hpp`](../Sources/DEXT/WheelProtocol.hpp) and
push the pointer onto the `kRegistry` array in
[`Sources/DEXT/WheelProtocol.cpp`](../Sources/DEXT/WheelProtocol.cpp). The
driver's `findWheelProtocol(vid, pid)` returns this vtable when the
firmware-mode personality matches.

### 6d. Boot-shim entries, if applicable

- **Thrustmaster T-series**: add a row to `kModels` in
  [`Sources/DEXT/TMBootSwitch.cpp`](../Sources/DEXT/TMBootSwitch.cpp) with
  the wheel's (model, attachment) tuple and switch value, from upstream
  `hid-tminit`.
- **Logitech**: add a `bcdDevice` mask check to
  `LGBootSwitch::lookupNativeMode` in
  [`Sources/DEXT/LGBootSwitch.cpp`](../Sources/DEXT/LGBootSwitch.cpp),
  matching the wheel's bcdDevice prefix and returning the
  `LGCommon::Native*` mode code.

If the device enumerates directly at its native PID (G920, G923, T150 in
firmware mode), no boot-shim entry is needed — just the firmware
personality + vtable.

## 7. Entitlements

If the device introduces a new vendor (not Thrustmaster `0x044F`, not
Logitech `0x046D`), add it to
[`Sources/DEXT/Macoswheels.entitlements`](../Sources/DEXT/Macoswheels.entitlements):

```xml
<dict>
    <key>idVendor</key>
    <integer>NEW_VENDOR_DECIMAL</integer>
</dict>
```

The signing team's DriverKit grant has to cover that VID, otherwise the
DEXT won't load. For dev-mode-only installs the user's system-extensions
developer toggle takes precedence.

## 8. README and man pages

Add the device to the supported-devices tables in
[`README.md`](../README.md), to
[`man/macoswheels.7`](../man/macoswheels.7), and (if relevant) to
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md).

## 9. Verify

```sh
swift build
swift test                         # Linux side
.build/debug/macoswheels list      # the new wheel should appear
xcodegen generate                  # on macOS only
xcodebuild -project Macoswheels.xcodeproj \
           -scheme MacoswheelsContainer \
           -configuration Release build
```

CI runs both jobs on push. Once green, the DEXT artifact from
`build.yml`'s macos-latest job will contain the new wheel.

## Tips

- **Numbers in `Info.plist` are decimal**, not hex. `0xB677 = 46711`.
- **PID output report IDs in the C++ descriptor (0x21..0x2A) must not
  collide with vendor report IDs the wheel itself declares.** Check your
  pcap or `lsusb -v` output before relying on raw passthrough; if there's
  a collision, you can either renumber the PID block or write a
  `translateInputReport` for the wheel.
- **Boot vs firmware ordering matters.** Keep both personalities at
  `IOProbeScore = 10000` and let `IOMatchCategory` segregate them; if the
  boot personality wins on score, the wheel never reveals its real PID.
- **`supportsGain = false` on Logitech wheels** is real — they have no
  software gain knob like Thrustmasters do. Don't lie or `setGain` will
  silently no-op.
- **`rangeMaxDegrees` clamps from the firmware side too.** Be honest about
  what the hardware can actually do.
