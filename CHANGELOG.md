# Changelog

All notable changes to this project will be documented in this file. Format
loosely follows [Keep a Changelog](https://keepachangelog.com/). The project
uses semantic versioning, but until 1.0.0 every release may include breaking
changes to the wire protocol encoders, the IOUserClient ABI, or the
configuration plist layout.

## Unreleased

### Added
- WheelQuirks / ShifterQuirks protocols plus `GenericWheelDriver<Q>` and
  `GenericShifterDriver<Q>`. Adding a new wheel is now a single Quirks struct
  plus a typealias.
- `docs/PROTOCOL-NOTES/{T150,T300,Logitech}.md` with the full wire-protocol
  references derived from `scarburato/t150_driver`, `Kimplul/hid-tmff2`,
  `scarburato/hid-tminit`, and `berarma/new-lg4ff`.
- `parseInputReport(raw:) -> [UInt8]?` requirement on `WheelQuirks` (default
  returns nil) so per-wheel input-bytes-to-HID-report translators can land
  alongside hardware captures.
- `dev-load.sh` is a proper installer: drops the CLI into `/usr/local/bin/`,
  man pages into `/usr/local/share/man/`, prints SIP status, ensures
  systemextensions developer mode is on, opens the container app.
- `uninstall.sh` undoes everything dev-load did.
- `swift-format` lint config + a continue-on-error CI job.
- Code coverage summary in the Linux CI job.
- Release zips ship a `.sha256` alongside; the GitHub Release page includes
  the `shasum -a 256 -c` verify command.
- `CONTRIBUTING.md`, `SECURITY.md`, issue + PR templates.
- `MacoswheelsUserClient` handlers actually call into the driver instead of
  returning empty `kIOReturnSuccess` from every selector.
- `locateInterruptPipes` uses `IOUSBHostInterface.copyPipe(forAddress:)` with
  vendor-aware endpoint addresses.
- Driver dispatch in `MacoswheelsDriver.makeDriver(for:transport:)` covers
  every wheel and shifter in the registry.

### Changed
- 14 per-wheel driver files now define a Quirks enum + typealias instead of a
  full DeviceDriver class — net −465 lines.
- macOS CI job runs on `macos-latest` (was pinned to `macos-15`) and selects
  the newest installed Xcode dynamically.
- `DRIVERKIT_DEPLOYMENT_TARGET` bumped to 25.0 to match Xcode 26.3's
  DriverKit 25.2 SDK.
- README leads with the custom wordmark + AppIcon family from the iconpack
  (white-on-transparent dark variant, navy-on-transparent light variant via
  `<picture>` element).

### Known issues
- The DEXT does not currently compile in CI. Xcode 26.3 ships the DriverKit
  25.2 SDK but no Swift standard library for DriverKit, so every
  `swift-frontend` invocation against `arm64-apple-driverkit*` fails with
  "Unable to find module dependency: 'Swift'". Documented in
  `docs/DEV-MODE-SETUP.md` §4. The protocol encoders and CLI compile and
  test cleanly; the DEXT stays in the repo for whichever Xcode does ship a
  stdlib in the future.
- `T128` is a stub. No public protocol reference exists; needs a `usbmon`
  capture from real hardware.
- Logitech periodic and ramp effects throw `notImplemented`. They need a
  DEXT-side 2 ms timer loop (lg4ff's design), which depends on the DEXT
  actually compiling first.
- Input report parsing is stubbed (default `parseInputReport` returns nil).
  Per-wheel implementations land alongside `usbmon` captures.
