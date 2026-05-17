<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/wordmark-dark.svg">
    <img src="docs/assets/wordmark-light.svg" alt="macoswheels" width="640">
  </picture>
</p>

<p align="center">
  <b>Native macOS driver for Thrustmaster &amp; Logitech racing wheels.</b><br>
  Force feedback, rotation range and autocenter spring, on macOS 26+ — for native and CrossOver/Wine games.
</p>

<p align="center">
  <a href="https://github.com/renaudallard/macoswheels/actions/workflows/build.yml"><img alt="build" src="https://github.com/renaudallard/macoswheels/actions/workflows/build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-BSD--2--Clause-blue"></a>
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey">
  <img alt="swift" src="https://img.shields.io/badge/swift-6.0-orange">
  <img alt="devices" src="https://img.shields.io/badge/devices-21%20wheels%20%26%20shifters-success">
</p>

---

## What is this?

Thrustmaster ships no macOS driver. Apple removed kext-based force feedback years ago and never replaced the public API, so racing wheels show up as half-broken HID devices on a Mac and CrossOver titles see no force feedback at all.

`macoswheels` is a dev-signed DriverKit System Extension plus a small CLI that:

- claims the wheel over USB,
- runs the proprietary initialization (Thrustmaster boot↔firmware mode switch, Logitech native-mode register write),
- re-exposes the wheel as a clean HID joystick with a USB PID 1.0 force-feedback descriptor,
- accepts rotation range, autocenter, and gain commands from the CLI or the bundled SwiftUI config app.

Games that use `IOHIDManager` — that's CrossOver/Wine plus any well-behaved native title — see a standard force-feedback joystick with zero per-app glue.

> [!IMPORTANT]
> **Status:** the Swift protocol library is complete for 21 wheels and shifters and is tested on Linux on every push (125 unit tests covering encoders, settings packets and the PID parser). The DriverKit DEXT is being rewritten in IIG / C++ because Apple still ships no Swift standard library for DriverKit on any installed Xcode. **T150 is currently the only model wired into the IIG DEXT**; the rest of T-series and the Logitech family are being ported module by module. The device tables below describe the Swift library's encoder coverage, not what the IIG DEXT exposes to macOS today. See [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md) for the rationale and setup.

---

## Supported devices

### Thrustmaster T-series

All T-series wheels share boot PID `044F:B65D` ("Thrustmaster FFB Wheel") and are switched into their model-specific firmware PID by a vendor control transfer.

| Model           | Firmware PID  | FFB encoder | Notes                                     |
|-----------------|---------------|-------------|-------------------------------------------|
| **T150**        | `B677`        | **full**    | reference implementation                  |
| T300 RS (PS3 normal / advanced / PS4) | `B66E` / `B66F` / `B66D` | full | three USB modes, one driver |
| TX              | `B669`        | full        |                                           |
| TS-XW           | `B692`        | full        |                                           |
| TS-PC Racer     | `B689`        | full        |                                           |
| T248            | `B696`        | full        | no hardware inertia                       |
| T-GT            | `B68E`        | full        |                                           |
| T128            | `B68F`        | stub        | distinct protocol; needs hardware capture |
| TH8A shifter    | `B687`        | n/a         | buttons only                              |

### Logitech G-series

DFP / G25 / DFGT / G27 / G29 reach this driver via the shared "Driving Force" compat PID `046D:C294`. G920 and G923 enumerate directly.

| Model                  | PID                       | FFB encoder | Notes                                |
|------------------------|---------------------------|-------------|--------------------------------------|
| Driving Force Pro      | `C298`                    | constant + condition |                              |
| G25                    | `C299`                    | constant + condition | hardware friction support    |
| Driving Force GT       | `C29A`                    | settings only        |                              |
| G27                    | `C29B`                    | constant + condition | hardware friction support    |
| **G29**                | `C24F`                    | constant + condition |                              |
| **G920**               | `C262`                    | constant + condition |                              |
| **G923** (PC/PS/Xbox)  | `C266` / `C267` / `C26E`  | constant + condition |                              |
| Driving Force shifter  | `C29C`                    | n/a                  | buttons only                 |

`full` = constant, ramp, every periodic waveform, spring, damper, friction, inertia. `constant + condition` = constant, spring, damper, friction (Logitech periodic + ramp need a continuous-update loop that's still TODO). `settings only` = rotation range + autocenter + gain, no FFB encoder yet. `stub` = wheel is recognised, settings throw `notImplemented` pending a USB capture.

---

## Quickstart

> [!NOTE]
> **macoswheels is dev-signed only.** It's not, and will not be, notarized. SIP must be relaxed (`csrutil enable --without kext --without dtrace`) and developer mode enabled (`sudo systemextensionsctl developer on`). If that's not your thing, this project isn't for you. See [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md).

1. Grab the latest build from the [Releases page](https://github.com/renaudallard/macoswheels/releases) (cut by `release.yml` on every `v*` tag, built on `macos-latest`) or the development [build workflow](https://github.com/renaudallard/macoswheels/actions/workflows/build.yml).
2. Unzip and run `Tools/dev-load.sh`. It checks your dev-mode posture and opens the container app.
3. Approve the system extension in **System Settings → Privacy & Security**.
4. Plug the wheel in and configure:

```sh
macoswheels list
macoswheels info
macoswheels range 900
macoswheels autocenter 50
macoswheels gain 80
```

Settings persist to `~/Library/Preferences/it.allard.macoswheels.plist` and are reapplied on login by the `it.allard.macoswheels.restore` LaunchAgent the container app installs.

---

## How it works

```
+----------------------- Game / CrossOver / Wine ----------------------+
                              |
                              | IOHIDManager + PID 1.0 output reports
                              v
+--------------- macoswheels DEXT (IIG / C++, DriverKit) --------------+
|                                                                     |
|  (d) ConfigPlane      MacoswheelsUserClient : IOUserClient          |
|  (c) HID re-export    HIDExport             : IOUserHIDDevice       |
|  (b) Device driver    any DeviceDriver       (one per wheel)        |
|  (a) USB transport    USBTransport over IOUSBHostInterface          |
|                                                                     |
+---------------------------------------------------------------------+
                              |   USB control + interrupt
                              v
                       [ Thrustmaster / Logitech wheel ]
```

Strict downward dependency between the four layers. The Swift reference implementation of the device-driver layer (under `Sources/Drivers/`) has no IOKit dependency and is unit-tested on Linux in ~0.2 s; the IIG DEXT ports each wheel from there into its own C++ `WheelProtocol` vtable. Full architectural detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Building from source

**Linux (Debian arm64, primary dev loop):**

```sh
swift build
swift test
.build/debug/macoswheels list
```

Covers `WheelProtocol`, `WheelRegistry`, `Drivers`, `HIDDescriptors`, `FFBNormalizer`, `ConfigPlane`, and the `macoswheels` CLI. 125 tests.

**macOS (DEXT + container app, only on macOS hosts):**

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Macoswheels.xcodeproj \
           -scheme MacoswheelsContainer \
           -configuration Release \
           build
```

The DEXT target requires either an Apple-issued DriverKit entitlement (not pursued) or a free Personal Team certificate that Xcode auto-generates for you. See [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md) for the loading flow.

GitHub Actions (`.github/workflows/build.yml`) runs the Linux job on every push and the macOS job on `macos-latest` — falling back to a compile-only build when signing secrets aren't configured. `release.yml` is identical but triggered by `v*` tags and attaches the signed zip to a GitHub Release.

---

## Repository layout

```
Sources/
  WheelProtocol/        pure-Swift plugin protocol, USB transport, FFB types
  WheelRegistry/        (VID, PID) table — single source of truth
  Drivers/              per-wheel modules (Thrustmaster/, Logitech/)
  HIDDescriptors/       PID 1.0 output-report block + descriptor builder
  FFBNormalizer/        PID Set-Effect parser + Synthesizer (effect downgrade)
  ConfigPlane/          IOUserClient selectors + struct ABI
  DEXT/                 DriverKit System Extension (IIG / C++)
  DEXT-swift-attic/     superseded Swift DEXT, kept for reference
  Container/            SwiftUI container app (DEXT activator + sliders GUI)
  CLI/                  `macoswheels` binary
Tests/                  Linux-runnable XCTest suites (125 tests)
man/                    mdoc man pages
docs/                   ARCHITECTURE.md, ADDING-A-DEVICE.md, DEV-MODE-SETUP.md
ci/                     GitHub Actions helper scripts
Tools/                  end-user install helpers
```

---

## License

BSD-2-Clause. See [`LICENSE`](LICENSE).
