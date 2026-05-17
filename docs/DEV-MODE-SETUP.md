# Dev-mode setup

`macoswheels` requires SIP to be relaxed and system-extension developer mode
enabled. This document covers the one-time setup on a fresh macOS 26 install.

## 1. Disable parts of SIP

Boot into Recovery (hold Power on Apple Silicon until the boot options
appear; Intel: Cmd+R during boot). Open Terminal from the Utilities menu.

```sh
csrutil enable --without kext --without dtrace
```

Reboot. Verify:

```sh
csrutil status
```

You should see SIP enabled but with `Kernel Extension Signing` and
`Filesystem Protections` (or equivalent) listed as disabled. The exact list
of options that needs relaxation has changed between macOS releases; if a
later macOS rejects the above, try:

```sh
csrutil disable
```

This fully disables SIP. Less surgical, but a known-working escape hatch.

## 2. Enable system-extension developer mode

Back in macOS, in a regular shell:

```sh
sudo systemextensionsctl developer on
```

This must be repeated after every reboot, because Apple is mean about it.

## 3. Verify

```sh
systemextensionsctl developer
```

Should print `Developer mode is on`.

## 4. Why the DEXT is IIG / C++, not Swift

The GitHub Actions `macos-latest` runner ships Xcode 26.3 with the DriverKit
25.2 SDK, but Apple has not shipped a Swift standard library for DriverKit on
any installed Xcode. Every `swift-frontend` invocation against an
`arm64-apple-driverkit*` target fails with:

```
error: Unable to find module dependency: 'Swift'
error: Unable to find module dependency: 'Foundation'
error: Unable to find module dependency: 'DriverKit'
error: Unable to find module dependency: 'os'
```

Swift DriverKit support has been "preview-quality" since Xcode 13 (2021) and
the stdlib for newer DriverKit deployment targets has never caught up. Most
production DEXTs in the wild (Karabiner-DriverKit, SoftRAID, etc.) are written
in IIG / Objective-C++ for the same reason.

The project's response: the DEXT under `Sources/DEXT/` is now IIG (`.iig`)
plus plain C++ (`.cpp` / `.hpp`) and compiles cleanly in CI on every push.
The original Swift sources are kept under `Sources/DEXT-swift-attic/` for
reference. The Swift protocol library (`Sources/WheelProtocol`,
`Sources/Drivers/*`, `Sources/FFBNormalizer`, ...) is unchanged and stays the
Linux-unit-tested source of truth for byte-level encoder behaviour; each
wheel is ported from Swift into a C++ `WheelProtocol` vtable as it lands in
the DEXT.

## 5. Notes on signing

The CI artifact is signed with the project's Developer ID certificate, but
the entitlements requested (`com.apple.developer.driverkit.*`) are gated by
Apple. Without an explicit grant from Apple to the signing team, the DEXT
cannot be loaded on a Mac in default SIP posture, which is why the dev-mode
setup above is required.

If you have your own DriverKit entitlement grant, replace the team in
`project.yml` (`DEVELOPMENT_TEAM`) and re-run the CI workflow; the resulting
artifact will load on any Mac with SIP in default posture.
