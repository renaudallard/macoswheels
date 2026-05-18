# Architecture

```
+----------------------- Game / CrossOver / Wine ----------------------+
                              |
                              | IOHIDManager + PID 1.0 output reports
                              v
+--------------- macoswheels DEXT (IIG / C++, DriverKit) --------------+
|                                                                     |
|  (d) Config plane     MacoswheelsUserClient : IOUserClient          |
|  (c) HID re-export    HIDExport             : IOUserHIDDevice       |
|  (b) Wheel protocol   WheelProtocol vtable   (one per wheel model)  |
|  (a) USB transport    IOUSBHostInterface + IOUSBHostPipe            |
|                                                                     |
+---------------------------------------------------------------------+
                              |   USB control + interrupt
                              v
            [ Thrustmaster / Logitech wheel or shifter ]

+ macoswheels (CLI)            : IOServiceOpen + IOConnectCallStructMethod
+ MacoswheelsContainer.app     : OSSystemExtensionRequest activation
+ macoswheels-restore (Launch  : reapplies rotation/autocenter at login
  Agent invocation of CLI)
```

The DEXT is one `MacoswheelsDriver` instance per matched USB interface, with a
strict top-to-bottom dependency between four conceptual layers:

- **(a) USB transport.** Direct calls into `IOUSBHostInterface` and
  `IOUSBHostPipe`. The driver opens one interrupt-IN pipe and, for FFB-capable
  devices, one interrupt-OUT pipe. `AsyncIO` arms the async read loop;
  `IOUSBHostPipe::IO` synchronously sends output bytes. There is no
  abstraction in front of these — the Swift `USBTransport` protocol below
  exists only for unit tests, never in the DEXT.
- **(b) Wheel protocol.** A `WheelProtocol` struct (declared in
  `Sources/DEXT/WheelProtocol.hpp`) is a vtable of function pointers per
  wheel model: `setRotationRange`, `setAutocenter*`, `setGain`,
  `encodeEffect`, `prepareInputStream`, and an optional
  `translateInputReport` for wheels whose native HID descriptor isn't
  acceptable as-is. The registry in `WheelProtocol.cpp` maps (VID, PID) to a
  vtable. Shifters and T128 leave most pointers null and only declare their
  USB endpoints; the driver gates pipe acquisition and PID-block splicing on
  those nulls.
- **(c) HID re-export.** `HIDExport : IOUserHIDDevice` publishes the wheel
  to the OS. At Start() the driver reads the wheel's own HID Report
  Descriptor over USB (`GET_DESCRIPTOR`, type 0x22), splices the PID 1.0
  output-report block from `HIDDescriptor.hpp` in just before the descriptor's
  outer Application Collection close, and attaches the merged bytes to itself
  as the `MergedHIDDescriptor` property; `HIDExport::newReportDescriptor`
  reads that back. Wheel input bytes forward verbatim into `handleReport`.
  Output reports (PID Set-Effect family, Device Gain, Device Control,
  Block Free) flow through `HIDExport::setReport`, whose switch on the
  report ID stashes parameters in `HIDExport_IVars::slots[idx]` until an
  Effect Operation Start arrives, at which point a `NormalizedEffect` is
  assembled and passed to `MacoswheelsDriver::SubmitEffect`.
- **(d) Config plane.** `MacoswheelsUserClient : IOUserClient` exposes a
  fixed selector table to the `macoswheels` CLI. Method numbers and packed
  structs live in `Sources/ConfigPlane/UserClientAPI.swift`, shared verbatim
  with the CLI; the C++ user-client decodes `structureInput` to receive them.

## Swift reference library

The Linux-side Swift code under `Sources/WheelProtocol/`, `Sources/Drivers/`
and `Sources/FFBNormalizer/` is the source of truth for byte-level encoder
behaviour. Each new wheel is reverse-engineered there first and tested with
golden-byte XCTests against a `MockUSBTransport`. Once the Swift driver
agrees with the wheel, the encoder is ported into a C++ `WheelProtocol`
vtable for the DEXT to ship. The CLI under `Sources/CLI/` is also Swift and
talks to the DEXT over `IOConnectCallStructMethod`.

The DEXT itself runs no Swift code — Apple still ships no Swift standard
library for DriverKit (see
[`DEV-MODE-SETUP.md`](DEV-MODE-SETUP.md) §4) — so the original Swift DEXT
sources sit under `Sources/DEXT-swift-attic/` for reference and are not
built.

## Boot-to-firmware PID swap

Two unrelated families need to be poked over USB before they expose their
proper HID interface.

**Thrustmaster T-series.** Wheels enumerate at the shared boot PID
`044F:B65D`. The `TSeries-Boot` personality in `Info.plist` matches that
PID; `runThrustmasterBoot` (in `MacoswheelsDriver.cpp`) sends the 0xC1/73
model query, looks the wheel up in `TMBootSwitch::kModels` by
(model, attachment), and issues the 0x41/83 mode-switch control transfer
with the per-model switch value. The wheel disconnects, reconnects at its
native firmware PID, and the model-specific firmware personality matches.

**Logitech "Driving Force compat."** DFP, DFGT, G25, G27 and G29 all
enumerate at the shared compat PID `046D:C294`. The `Logitech-Boot`
personality matches that PID; `runLogitechBoot` reads `bcdDevice` from the
USB device descriptor, looks up the native mode via
`LGBootSwitch::lookupNativeMode` (mask table cribbed from Linux
`new-lg4ff`), and sends the HID++ 0xF8/0x0A "revert on reset" and 0xF8/0x09
switch packets on the interrupt-OUT pipe. G920 and G923 enumerate directly
at their native PIDs.

Each model that may be reached after a swap has a matching firmware-mode
personality in `Info.plist` and a `WheelProtocol` entry in `kRegistry`.

## FFB pipeline

```
game writes a PID Set Effect / Set Constant / ... output report
  -> IOUserHIDDevice routes it to HIDExport::setReport
  -> the switch on report ID stashes params into HIDExport_IVars::slots[idx]
     (no wheel I/O yet)
  ...
game writes a PID Effect Operation report with op = Start
  -> setReport assembles a NormalizedEffect from the slot's stored fields
  -> MacoswheelsDriver::SubmitEffect(NormalizedEffect *)
  -> protocol->encodeEffect(effect, EffectPackets *)
  -> driver iterates EffectPackets and sends each one out the OUT pipe
```

`NormalizedEffect` (in `WheelProtocol.hpp`) is a flat struct with a `Kind`
discriminator covering constant, ramp, the five periodics, spring, damper,
friction, inertia, plus pseudo-kinds for Effect Operation Start and Stop.
`EffectPackets` holds up to eight back-to-back interrupt-OUT packets so a
single effect can require a setup / update / commit sequence (T150 uses
three packets per effect; the T300 family and Logitech use one).

PID output report IDs in `HIDDescriptor::kPIDBlock` are deliberately
`0x21..0x2A` so they never collide with vendor report IDs the wheels'
own descriptors declare (T150 ships 0x02 and 0x0A in its descriptor;
Logitech wheels declare several IDs in the 0x01..0x14 range).

## Why pure-Swift libs

Everything except `Sources/DEXT/` and `Sources/Container/` is a SwiftPM
target with no IOKit dependency. The Linux unit-test loop is the primary
dev cycle (the dev host is Debian arm64; macOS access is GitHub Actions
only). Anything DEXT-specific uses `#if canImport(DriverKit)` guards so
the same repo builds on Linux without breaking.
