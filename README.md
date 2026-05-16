# macoswheels

macOS 26+ driver for Thrustmaster T-series and Logitech G-series racing wheels.
Brings force feedback, rotation-range control and autocenter spring to native
macOS games and to CrossOver / Wine titles.

> **Status:** Phases 0-7 of the implementation roadmap have landed. Every
> supported wheel and shifter has a `DeviceDriver` conformance with verified
> protocol bytes for settings (rotation range, autocenter, gain). The
> `T150Driver` is the first complete FFB encoder; other wheels currently throw
> `notImplemented` for effect uploads and will fill in as USB captures from
> real hardware confirm their wire formats. 84 unit tests pass on Debian arm64.

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

Wheel bases (firmware-mode PIDs; all Thrustmasters share boot PID `044F:B65D`,
many Logitechs share compat PID `046D:C294`):

| Vendor       | Model                          | USB ID    | FFB encoder       |
|--------------|--------------------------------|-----------|-------------------|
| Thrustmaster | T150                           | 044F:B677 | full (constant, periodic, spring, damper) |
| Thrustmaster | T300 RS (PS3 normal / adv / PS4)| 044F:B66E / B66F / B66D | full FFB    |
| Thrustmaster | TX                             | 044F:B669 | full FFB          |
| Thrustmaster | TS-XW                          | 044F:B692 | full FFB          |
| Thrustmaster | TS-PC Racer                    | 044F:B689 | full FFB          |
| Thrustmaster | T248                           | 044F:B696 | full FFB          |
| Thrustmaster | T128                           | 044F:B68F | stub              |
| Thrustmaster | T-GT                           | 044F:B68E | full FFB          |
| Logitech     | Driving Force Pro              | 046D:C298 | settings + condition FFB |
| Logitech     | G25                            | 046D:C299 | settings + condition FFB |
| Logitech     | Driving Force GT               | 046D:C29A | settings only     |
| Logitech     | G27                            | 046D:C29B | settings + condition FFB |
| Logitech     | G29                            | 046D:C24F | settings + condition FFB |
| Logitech     | G920                           | 046D:C262 | settings + condition FFB |
| Logitech     | G923 (PC / PlayStation / Xbox) | 046D:C266 / C267 / C26E | settings + condition FFB |

Peripherals:

| Vendor       | Model                            | USB ID    |
|--------------|----------------------------------|-----------|
| Thrustmaster | TH8A shifter                     | 044F:B687 |
| Logitech     | Driving Force shifter (G29/G920) | 046D:C29C |

"Settings only" means rotation range, autocenter strength, and (where the wheel
supports it) global gain are encoded with verified bytes; FFB effect upload
still throws `notImplemented`.

"Full FFB" means every effect supported by the wheel's hardware (constant,
ramp, all five periodic waveforms, spring, damper, friction, inertia) is
encoded with bytes verified against `hid-tmff2`'s `t300rs_upload_*`.

"Condition FFB" on the Logitechs means constant, spring, damper, and
friction effects are byte-correct per `new-lg4ff`'s `lg4ff_update_slot`.
Periodic and ramp on Logitech still need the continuous-update timer
loop and are pending.

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
