# Dev-mode setup

`macoswheels`' DriverKit DEXT requests USB Transport, HID Device and HID
EventService entitlements that Apple gates per Developer team. Without
Apple's grant on the signing team, macOS refuses to load the DEXT at three
separate gates:

1. **SIP** (System Integrity Protection) — blanket macOS hardening, blocks
   loading drivers that aren't from Apple's allowlist.
2. **AMFI** (Apple Mobile File Integrity) — validates that the binary's
   embedded entitlements match what its signing team is actually allowed to
   claim. Free Personal Team Apple IDs cannot claim any DriverKit
   entitlements at all; AMFI rejects them outright.
3. **System Extension developer mode** — separate kernel toggle that lets
   `sysextd` load DEXTs from teams other than Apple's preinstalled set.

How many of those you have to relax depends on whether your build has the
DriverKit entitlement grant from Apple (see the [README's
"Loading the DEXT"](../README.md#loading-the-dext) section). Each path
below is one-time setup; you don't repeat it per build.

## Path 1 — Signed DEXT with Apple's DriverKit grant

Only SIP needs a small relaxation; AMFI is happy because Apple's grant
makes the entitlements legitimate.

Boot into Recovery (hold Power on Apple Silicon until the boot options
appear; Intel: Cmd+R during boot). Open Terminal from the Utilities menu:

```sh
csrutil enable --without kext --without dtrace
```

Reboot. Verify in normal macOS:

```sh
csrutil status
```

Should report SIP enabled but with `Kernel Extension Signing` and
`Filesystem Protections` (or equivalent) disabled.

Then enable system-extension developer mode (see the bottom of this file).

## Path 2 — Unsigned DEXT, free Personal Team build, or DEXT without the grant

You need SIP fully off **and** AMFI bypassed. The DEXT then loads regardless
of who signed it (or whether it's signed at all).

In Recovery (same boot trick as above), open Terminal:

```sh
csrutil disable
```

Reboot. In normal macOS:

```sh
sudo nvram boot-args="amfi_get_out_of_my_way=0x1"
```

Reboot again so the kernel picks up the new boot-arg. Then enable
system-extension developer mode (next section).

**To roll back** to a normal-security Mac:

```sh
sudo nvram -d boot-args        # clear AMFI bypass
```

Then reboot into Recovery and run `csrutil enable`, then reboot.

## System extension developer mode (both paths)

In a regular macOS Terminal:

```sh
sudo systemextensionsctl developer on
```

Verify:

```sh
systemextensionsctl developer
```

Should print `Developer mode is on`. This setting persists across reboots
on macOS 26+; if a future macOS resets it, just rerun the command.

## Why the DEXT is IIG / C++, not Swift

The GitHub Actions `macos-latest` runner ships Xcode 26.3 with the
DriverKit 25.2 SDK, but Apple has not shipped a Swift standard library
for DriverKit on any installed Xcode. Every `swift-frontend` invocation
against an `arm64-apple-driverkit*` target fails with:

```
error: Unable to find module dependency: 'Swift'
error: Unable to find module dependency: 'Foundation'
error: Unable to find module dependency: 'DriverKit'
error: Unable to find module dependency: 'os'
```

Swift DriverKit support has been "preview-quality" since Xcode 13 (2021)
and the stdlib for newer DriverKit deployment targets has never caught up.
Most production DEXTs in the wild (Karabiner-DriverKit, SoftRAID, etc.)
are written in IIG / Objective-C++ for the same reason.

The project's response: the DEXT under `Sources/DEXT/` is now IIG
(`.iig`) plus plain C++ (`.cpp` / `.hpp`) and compiles cleanly in CI on
every push. The original Swift sources are kept under
`Sources/DEXT-swift-attic/` for reference. The Swift protocol library
(`Sources/WheelProtocol`, `Sources/Drivers/*`, `Sources/FFBNormalizer`,
...) is unchanged and stays the Linux-unit-tested source of truth for
byte-level encoder behaviour; each wheel is ported from Swift into a C++
`WheelProtocol` vtable as it lands in the DEXT.

## Signing reality check

The default `release.yml` builds **unsigned**. Apple's tooling refuses
ad-hoc (`codesign --sign -`) signing for DriverKit SDK, and the project
has no Apple Developer Program subscription, so CI cannot produce a
signed artifact. The release zip loads on Macs configured per Path 2;
to get it loading on Macs configured only per Path 1 you'd need to sign
locally with an Apple Developer Program cert whose team has the DriverKit
entitlement grant — both Apple-side items the README's Option B walks
through.
