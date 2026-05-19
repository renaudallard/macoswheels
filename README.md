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

## Signing the DEXT

macOS won't load the driver until it's signed. The download from the Releases page is unsigned, so you sign it once on your own Mac. **This is free, takes about 5 minutes, and you don't need to pay Apple anything.**

### What you need

- A Mac running macOS 26 or later.
- **Xcode** (free from the Mac App Store).
- An **Apple ID** — the same one you use for iCloud / the App Store is fine. Create one at [appleid.apple.com](https://appleid.apple.com) if you don't have one.

### Step 1 — Get the source

Open the **Terminal** app and paste:

```sh
git clone https://github.com/renaudallard/macoswheels.git
cd macoswheels
git checkout v0.1.0
```

If you don't have Homebrew (the `brew` command), install it from [brew.sh](https://brew.sh) first. Then:

```sh
brew install xcodegen
xcodegen generate
open Macoswheels.xcodeproj
```

Xcode opens with the project loaded.

### Step 2 — Sign in to Xcode

In the menu bar: **Xcode → Settings → Accounts**. Click the **+** at the bottom left, pick **Apple ID**, type your Apple ID and password. You should see your name with **(Personal Team)** under it. Close the Settings window.

### Step 3 — Pick a name only you would use

You'll type this twice in the next steps. Make it lowercase, no spaces. A good pattern is your name plus the date, e.g. `johnsmith2026`. Just write it down somewhere.

### Step 4 — Set the team for the DEXT

In Xcode's left sidebar click the **blue project icon** at the very top (it says "Macoswheels"). A list of targets appears in the middle. Click **MacoswheelsDEXT** under TARGETS.

A row of tabs appears at the top of the middle panel. Click **Signing & Capabilities**.

- Tick the **Automatically manage signing** checkbox.
- In the **Team** dropdown, pick the entry with your name and **(Personal Team)**.
- In the **Bundle Identifier** field, replace `it.allard.macoswheels.dext` with `com.YOURNAME.macoswheels.dext` — using the name you wrote down in Step 3.

If Xcode shows a red error like "Failed to register bundle identifier", that name is taken. Add more letters until it's accepted.

### Step 5 — Set the team for the container app

Same panel, but in the TARGETS list click **MacoswheelsContainer** instead. **Signing & Capabilities** → tick **Automatically manage signing** → pick your team. Set the **Bundle Identifier** to `com.YOURNAME.macoswheels` (same as Step 4 but without the `.dext` at the end).

### Step 6 — Build & run

Press **⌘ R** (Cmd + R) or click the ▶ play button at the top-left of Xcode. Xcode signs everything and launches the container app.

### Step 7 — Approve the system extension

A small window opens with an **Activate DEXT** button. Click it. macOS pops a dialog telling you to open System Settings.

Open **System Settings → Privacy & Security**, scroll to the bottom. There will be a line saying "System software from macoswheels was blocked" with an **Allow** button. Click **Allow**, type your Mac password.

### Step 8 — Plug your wheel in

That's it. Plug the wheel into USB. It should now show up as a force-feedback joystick in any game and in CrossOver / Wine.

### Things that may go wrong

- **"No certificate found" in Step 4 or 5** — you skipped Step 2. Go back and sign in to Xcode.
- **System Settings doesn't show "Allow"** — you haven't enabled developer mode yet. In Terminal, run `sudo systemextensionsctl developer on` and try again. The full SIP / dev-mode setup is in [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md).
- **It worked, then a week later it doesn't** — free Personal Team certs expire after 7 days. Open the project in Xcode and press **⌘ R** again. The DEXT re-signs and reloads.
- **The DEXT loads but the wheel doesn't react** — start a debug log with `log stream --predicate 'sender == "MacoswheelsDEXT"'` in Terminal and watch what it says when you plug the wheel in.

---

### Optional: paying Apple to sign once for everyone

The free Personal Team route above ties the build to your Mac. If you want the same signed zip to install on multiple Macs (a friend's, a friend's friend's), you need an **Apple Developer Program** subscription — $99/year USD from [developer.apple.com/programs/enroll/](https://developer.apple.com/programs/enroll/). Individuals get approved in 24–48 h.

After enrolment:

1. **Find your Team ID** at [developer.apple.com/account](https://developer.apple.com/account) → **Membership** tab. It's a 10-character string like `A1B2C3D4E5`.
2. **Create a Developer ID Application certificate**:
   - Go to [Certificates list](https://developer.apple.com/account/resources/certificates/list) → click **+** → choose **Developer ID Application**.
   - Apple asks for a CSR (Certificate Signing Request) file. To make one: open **Keychain Access** on your Mac → menu bar **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…** Fill your email, name, choose **Saved to disk**, click **Continue**.
   - Upload that `.certSigningRequest` file to Apple's page. Download the resulting `.cer` and double-click it — it goes into your Keychain.
3. **Export the cert** so CI can use it. In **Keychain Access**, find "Developer ID Application: <Your Name>", right-click → **Export…**, save as `.p12`, pick a strong password (you'll need it in a second).
4. **Add three GitHub secrets** so the `release.yml` workflow can sign for you. You'll need the [GitHub CLI](https://cli.github.com/) (`brew install gh && gh auth login`). Then:
   ```sh
   gh secret set CERT_P12_BASE64 < <(base64 < your-cert.p12)
   gh secret set CERT_P12_PWD              # paste cert export password when prompted
   gh secret set DEVELOPMENT_TEAM          # paste your 10-character Team ID
   ```
   Check with `gh secret list` — the three names should show up (values are never displayed).
5. **Run the release workflow**:
   ```sh
   gh workflow run release.yml -f tag=v0.1.0
   ```
   The signed zip appears on the [Releases page](https://github.com/renaudallard/macoswheels/releases) when the workflow finishes (5–10 minutes).

Even with this paid path, end users still need `systemextensionsctl developer on` + relaxed SIP, because the DEXT also requests Apple-gated entitlements that need a separate (free) [DriverKit entitlement request](https://developer.apple.com/contact/request/driverkit) — Apple grants those case-by-case and may decline.

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
