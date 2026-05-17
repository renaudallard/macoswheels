# Contributing to macoswheels

Thanks for poking at this. This is a personal-scope, dev-signed project so the
contribution flow is light, but here's what's useful to know.

## What's the project

A macOS DriverKit System Extension plus CLI for Thrustmaster T-series and
Logitech G-series racing wheels. It's dev-signed only — see [`README.md`](README.md)
for the distribution model and [`docs/DEV-MODE-SETUP.md`](docs/DEV-MODE-SETUP.md)
for what running it requires.

## What's most welcome

In rough order:

1. **`usbmon` captures from real wheels** for the wheels currently marked
   `stub` or `settings only` in the README. T128 is the biggest hole. Drop
   pcaps under `docs/PROTOCOL-NOTES/<device>/` and reference them from the
   device's encoder PR.
2. **Bug reports with `log stream` output.** Filter on `sender ==
   "MacoswheelsDEXT"` and include 30 seconds of context. Wheel make/model,
   macOS version, the game (if relevant).
3. **DEXT-side fixes.** Anything that touches `Sources/DEXT/*.swift`,
   `IOUserHIDDevice` overrides, USB pipe wiring, or the user-client selector
   handlers. The Linux dev loop covers the protocol-encoder side; the DEXT
   side really needs eyes on a Mac.
4. **Documentation.** Architecture/protocol notes are easy to bring up to date
   and high-impact for the next person.

## How to build & test

**Linux side** (the fast dev loop):

```sh
swift build
swift test
.build/debug/macoswheels list
```

108 tests run in well under a second.

**macOS side** (the DEXT + container app):

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Macoswheels.xcodeproj \
           -scheme MacoswheelsContainer \
           -configuration Release \
           DRIVERKIT_DEPLOYMENT_TARGET=24.0 \
           build
```

This requires either an Apple-issued DriverKit entitlement (not pursued by
this project) or a free Personal Team certificate that Xcode auto-generates.

## Code style

`.swift-format` at repo root is the source of truth. The CI lint job is
informational (continue-on-error) — fix what you can but don't worry about
existing drift.

Per [`CLAUDE.md`](https://docs.anthropic.com/) house style note: avoid `--`
and `—` in comments, avoid unnecessary `!`, follow KISS / UNIX / OpenBSD-quality
sensibilities.

## Adding a wheel

See [`docs/ADDING-A-DEVICE.md`](docs/ADDING-A-DEVICE.md). Short version: add a
`*Quirks` enum conforming to `WheelQuirks` (or `ShifterQuirks`), plus the
`typealias *Driver = GenericWheelDriver<*Quirks>`, register the (VID, PID)
in `Sources/WheelRegistry/DeviceMatch.swift`, drop golden-byte tests under
`Tests/WheelProtocolTests/`. Ideally also a `docs/PROTOCOL-NOTES/<device>.md`
describing what you reverse-engineered.

## Pull requests

- One logical change per PR.
- Commit messages: human-readable summary on the first line, prose body
  describing what changed and why. No "produced by LLM assistance" footer
  unless the PR is genuinely that.
- Run `swift test` before pushing.
- CI runs Linux tests on every push and PR; macOS build needs the signing
  secrets to validate the DEXT compile.
