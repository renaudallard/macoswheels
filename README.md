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
> **Status:** the IIG / C++ DEXT covers every device in the tables below. T300, TX, TS-XW, TS-PC, T248 and T-GT have a full FFB encoder; T150 covers constant + periodics + spring + damper; the Logitech family (DFP, DFGT, G25, G27, G29, G920, G923 PC/PS/Xbox) covers constant + condition; the TH8A and Driving Force shifters work as input-only HID devices. T128 enumerates and forwards its axes / buttons / hat but FFB is unimplemented (wire protocol not publicly documented). Logitech wheels in "Driving Force compat" mode are auto-switched to native firmware mode at boot via the wheel's `bcdDevice` (table cribbed from Linux `new-lg4ff`). Input is dynamic: the driver reads each wheel's HID Report Descriptor over USB and re-publishes it with the PID 1.0 output-report block spliced in, so axes and buttons pass through unchanged. CI builds the DEXT on `macos-latest` and runs 125 Linux unit tests on every push. The DEXT is IIG / C++ rather than Swift because Apple still ships no Swift standard library for DriverKit on any installed Xcode; see [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md).

---

## Supported devices

### Thrustmaster T-series

All T-series wheels share boot PID `044F:B65D` ("Thrustmaster FFB Wheel") and are switched into their model-specific firmware PID by a vendor control transfer.

| Model           | Firmware PID  | FFB encoder         | Notes                                     |
|-----------------|---------------|---------------------|-------------------------------------------|
| **T150**        | `B677`        | constant + periodic + condition | reference implementation; no ramp / friction / inertia |
| T300 RS (PS3 normal / advanced / PS4) | `B66E` / `B66F` / `B66D` | full | three USB modes, one driver |
| TX              | `B669`        | full                |                                           |
| TS-XW           | `B692`        | full                |                                           |
| TS-PC Racer     | `B689`        | full                |                                           |
| T248            | `B696`        | full                | wheel hardware lacks inertia              |
| T-GT            | `B68E`        | full                |                                           |
| T128            | `B68F`        | none (input only)   | wire protocol not publicly documented     |
| TH8A shifter    | `B687`        | n/a                 | buttons only                              |

### Logitech G-series

DFP / G25 / DFGT / G27 / G29 reach this driver via the shared "Driving Force" compat PID `046D:C294`. G920 and G923 enumerate directly.

| Model                  | PID                       | FFB encoder          | Notes        |
|------------------------|---------------------------|----------------------|--------------|
| Driving Force Pro      | `C298`                    | constant + condition |              |
| G25                    | `C299`                    | constant + condition |              |
| Driving Force GT       | `C29A`                    | constant + condition |              |
| G27                    | `C29B`                    | constant + condition |              |
| **G29**                | `C24F`                    | constant + condition |              |
| **G920**               | `C262`                    | constant + condition |              |
| **G923** (PC/PS/Xbox)  | `C266` / `C267` / `C26E`  | constant + condition |              |
| Driving Force shifter  | `C29C`                    | n/a                  | buttons only |

`full` = constant, ramp, every periodic waveform, spring, damper, friction, inertia. `constant + periodic + condition` = constant, the five periodics, spring and damper (T150's encoder lacks ramp / friction / inertia). `constant + condition` = constant, spring, damper, friction (Logitech periodics and ramp would need a continuous-update loop that's still TODO). `none (input only)` = the wheel matches, its axes / buttons / hat are forwarded, but no FFB is sent. `n/a` = device has no FFB hardware.

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
|  (b) Device driver    WheelProtocol vtable   (one per wheel)        |
|  (a) USB transport    IOUSBHostInterface + IOUSBHostPipe            |
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

GitHub Actions (`.github/workflows/build.yml`) runs the Linux job on every push and the macOS job on `macos-latest` — falling back to a compile-only build when signing secrets aren't configured. `release.yml` is identical but triggered by `v*` tags and attaches the (un)signed zip to a GitHub Release.

---

## Loading the DEXT

Apple makes this harder than most macOS hobby projects. A DriverKit DEXT can only be signed by a **paid Apple Developer Program team that has been separately granted the DriverKit capability by Apple**. Free Personal Team Apple IDs **cannot** request DriverKit entitlements — Xcode rejects the build with "Personal development teams do not support the DriverKit USB Transport / HID Device / HID EventService / UserClient Access / DriverKit (development) capabilities". There is no clean free path that produces a DEXT that loads on a stock Mac.

You have two real options.

### Option A — Relax your Mac's security and run unsigned (free, your Mac only)

For personal use when you don't want to pay Apple anything. You're turning off SIP and AMFI, so don't do this on a Mac that holds anything sensitive.

1. **Boot into Recovery**. On Apple Silicon, shut down, hold the power button until "Loading startup options" appears, click **Options** → **Continue**. On Intel, restart while holding **⌘ R**.
2. **Open Terminal** from the Utilities menu in Recovery and run:
   ```sh
   csrutil disable
   ```
3. **Reboot to normal macOS**:
   ```sh
   reboot
   ```
4. **Disable AMFI's entitlement check**. In a regular macOS Terminal:
   ```sh
   sudo nvram boot-args="amfi_get_out_of_my_way=0x1"
   ```
5. **Reboot once more** so the boot-arg takes effect.
6. **Enable system extension developer mode** (still required even with AMFI off):
   ```sh
   sudo systemextensionsctl developer on
   ```
7. **Download** the latest zip from the [Releases page](https://github.com/renaudallard/macoswheels/releases), unzip, and run `Tools/dev-load.sh`. The DEXT loads regardless of who signed it.
8. **Approve** the system extension in **System Settings → Privacy & Security** when prompted, then plug in your wheel.

**To undo everything** and return to a normal-security Mac:
```sh
sudo nvram -d boot-args      # remove the amfi boot-arg
```
Then reboot into Recovery and run `csrutil enable`, then reboot.

### Option B — Pay Apple and request the DriverKit grant (proper distribution)

For anyone who wants the same artifact to load on other Macs in their stock security posture, or who'd rather not relax their own Mac.

1. **Enrol** in the Apple Developer Program at [developer.apple.com/programs/enroll/](https://developer.apple.com/programs/enroll/) — $99/year USD. Individuals are approved in 24–48 h; organisations need a D-U-N-S number and take longer.
2. **Find your Team ID** at [developer.apple.com/account](https://developer.apple.com/account) → **Membership** tab. It's a 10-character string like `A1B2C3D4E5`.
3. **Request the DriverKit entitlement grant** at [developer.apple.com/contact/request/driverkit](https://developer.apple.com/contact/request/driverkit). Tell Apple why you need DriverKit USB Transport + DriverKit Family HID Device + DriverKit Family HID EventService (e.g. "USB racing wheel driver, personal use"). Apple reviews case-by-case and **may decline**. Approval can take weeks; sometimes Apple doesn't reply.
4. **Create a Developer ID Application certificate**:
   - Go to the [Certificates list](https://developer.apple.com/account/resources/certificates/list) → **+** → **Developer ID Application**.
   - Apple wants a CSR. On your Mac open **Keychain Access** → menu bar **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…**, fill email + name, choose **Saved to disk**, click **Continue**. Upload the resulting `.certSigningRequest` to Apple's page.
   - Download the `.cer` Apple returns, double-click it to install in Keychain.
5. **Export the cert** for CI: in Keychain Access, right-click "Developer ID Application: <Your Name>" → **Export…**, choose `.p12`, set a strong password.
6. **Sign locally** if you only need it on your own Mac:
   ```sh
   git clone https://github.com/renaudallard/macoswheels.git
   cd macoswheels && brew install xcodegen && xcodegen generate
   xcodebuild -project Macoswheels.xcodeproj \
              -scheme MacoswheelsContainer \
              -configuration Release \
              CODE_SIGN_STYLE=Manual \
              CODE_SIGN_IDENTITY="Developer ID Application: <Your Name> (<TEAMID>)" \
              DEVELOPMENT_TEAM=<TEAMID> \
              archive
   ```
7. **Or wire CI to sign for you** — fork the repo, then:
   ```sh
   gh secret set CERT_P12_BASE64 < <(base64 < your-cert.p12)
   gh secret set CERT_P12_PWD            # paste cert password when prompted
   gh secret set DEVELOPMENT_TEAM        # paste your 10-character Team ID
   gh workflow run release.yml -f tag=v0.1.0
   ```
   You need the [GitHub CLI](https://cli.github.com/) (`brew install gh && gh auth login`). The signed zip appears on the Releases page when the workflow finishes (5–10 minutes).

Without the DriverKit entitlement grant (step 3) you still get the same outcome as Option A: the DEXT only loads on dev-mode + SIP/AMFI-relaxed Macs. The grant is the part that makes it loadable on stock Macs.

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
