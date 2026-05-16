# macoswheels

macOS 26+ driver for Thrustmaster T-series and Logitech G-series racing wheels.
Brings force feedback, rotation-range control and autocenter spring to native
macOS games and to CrossOver / Wine titles.

> **Status:** Phase 0 scaffolding. The Linux-buildable Swift libraries, CLI,
> tests, and CI workflow are in place. The DriverKit System Extension is a
> bundle skeleton; no real USB traffic is emitted yet.

## What it does

Thrustmaster ships no macOS driver. Apple removed kext-based force feedback
years ago and never replaced the public API, so wheels appear as half-broken
HID devices and CrossOver titles see no force feedback. `macoswheels` is a
dev-signed DriverKit System Extension (DEXT) plus a CLI that:

- claims the wheel over USB,
- runs the proprietary initialization (boot-to-firmware mode switch on
  Thrustmaster T-series; native-mode register write on Logitech G29/G920/G923),
- re-exposes the wheel as a HID joystick with a USB PID 1.0 force-feedback
  descriptor so games using `IOHIDManager` (CrossOver/Wine plus well-behaved
  native titles) see a standard force-feedback joystick,
- accepts rotation range and autocenter commands from the CLI.

## Supported devices

Wheel bases:

| Vendor       | Model         | USB ID         |
|--------------|---------------|----------------|
| Thrustmaster | T150          | 044F:B65D      |
| Thrustmaster | T300 RS       | 044F:B66E      |
| Thrustmaster | TX            | 044F:B664      |
| Thrustmaster | TS-XW         | 044F:B66F      |
| Thrustmaster | T248          | 044F:B696      |
| Thrustmaster | T128          | 044F:B68F      |
| Thrustmaster | T-GT          | 044F:B66D      |
| Logitech     | G25           | 046D:C299      |
| Logitech     | G27           | 046D:C29B      |
| Logitech     | G29           | 046D:C24F      |
| Logitech     | G920          | 046D:C262      |
| Logitech     | G923          | 046D:C266      |

Peripherals:

| Vendor       | Model                       | USB ID    |
|--------------|-----------------------------|-----------|
| Thrustmaster | TH8A shifter                | 044F:B687 |
| Logitech     | G-series shifter            | 046D:C29C |

The T150 is the first wheel to ship with full FFB. Other wheels are stubs
gated behind their own personality entries and will be filled in per the
roadmap in `docs/ARCHITECTURE.md`.

## Distribution model

`macoswheels` is **dev-signed only**. It is not, and will not be, notarized
for the Mac App Store or Developer ID distribution. To run it you must:

- enable system-extension developer mode:
  `sudo systemextensionsctl developer on`
- relax SIP per `docs/DEV-MODE-SETUP.md`.

If you are not comfortable with that, this project is not for you.

## Install (end-user)

1. Grab the latest signed artifact from the GitHub Actions
   [build workflow](https://github.com/renaudallard/macoswheels/actions/workflows/build.yml).
2. Unzip the artifact.
3. Run `Tools/dev-load.sh` from the unzip directory.
4. Approve the system extension in System Settings > Privacy & Security.

After activation, plug in the wheel and use `macoswheels list` to confirm it
is recognized. Configure rotation range and autocenter:

```sh
macoswheels list
macoswheels info
macoswheels range 900
macoswheels autocenter 50
```

These settings persist in `~/Library/Preferences/it.allard.macoswheels.plist`
and are reapplied at login by the `macoswheels-restore` LaunchAgent installed
by the container app.

## Build (developer)

Linux dev host (Debian arm64):

```sh
swift build
swift test
.build/debug/macoswheels list
```

macOS build host (only needed for the DEXT and container app):

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Macoswheels.xcodeproj \
           -scheme MacoswheelsContainer \
           -configuration Release \
           build
```

The GitHub Actions workflow `.github/workflows/build.yml` runs both steps on
every push.

## Layout

```
Sources/
  WheelProtocol/     pure-Swift plugin protocol, transport, FFB types
  WheelRegistry/     static (VID,PID) table; single source of truth
  Drivers/           per-wheel modules (Thrustmaster/, Logitech/)
  HIDDescriptors/    PID 1.0 output-report block + descriptor builder
  FFBNormalizer/     PID Set-Effect parser; effect synthesis/downgrade
  ConfigPlane/       IOUserClient selector numbers + struct ABI
  DEXT/              DriverKit System Extension (Swift)
  Container/         tiny SwiftUI app that activates the DEXT
  CLI/               `macoswheels` binary
Tests/               Linux-runnable XCTest suites
man/                 mdoc man pages
docs/                architecture and dev-mode setup
ci/                  GitHub Actions helper scripts
Tools/               end-user install helpers
```

`Sources/WheelProtocol`, `WheelRegistry`, `Drivers`, `HIDDescriptors`,
`FFBNormalizer`, `ConfigPlane`, and `CLI` are pure-Swift SwiftPM targets that
build on Linux. `DEXT` and `Container` are Xcode-only DriverKit targets,
generated from `project.yml` by XcodeGen.

## License

BSD-2-Clause. See `LICENSE`.
