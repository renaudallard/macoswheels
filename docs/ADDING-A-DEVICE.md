# Adding a device

Checklist for adding a new wheel, shifter, pedal set or handbrake.

1. **Capture the protocol on Linux.** Plug the device into a Linux box with
   `hid-tmff2` (Thrustmaster) or `new-lg4ff` (Logitech) loaded. Use
   `Tools/capture-usb.sh` (when it lands) or run `usbmon` + `tshark` manually
   to capture:
   - The init sequence the kernel driver emits at probe.
   - Output packets for each FFB effect type, at known parameters.
   - Output packets for setRotationRange and setAutocenter.
   Save the capture under `docs/PROTOCOL-NOTES/<device>/` and reference it
   from a short Markdown notes file in the same folder.
2. **Add the (VID, PID) tuples to `Sources/WheelRegistry/DeviceMatch.swift`.**
   Boot PIDs and firmware PIDs both. Pick a `driverName` that mirrors the
   model.
3. **Add the IOKitPersonalities entries to `Sources/DEXT/Info.plist`.** One
   per matching `(VID, PID)` tuple. Use `WheelMode=boot` for shim
   personalities and `WheelMode=firmware` for the real driver. Set
   `IOProbeScore` to 10000.
4. **Write the driver.** Create `Sources/Drivers/<Vendor>/<Model>Driver.swift`
   conforming to `DeviceDriver`. Reuse `<Vendor>Common/` helpers wherever
   possible. Encode each supported FFB effect; throw `effectNotSupported` for
   the rest.
5. **Declare `WheelCapabilities` accurately.** Effects mask, pedal/button
   count, role, range bounds. The `HIDExport` layer uses this to build the
   descriptor; lying here means games see wrong axes.
6. **Add tests.** Copy `Tests/WheelProtocolTests/T150DriverTests.swift` and
   adjust. Add golden-byte tests under `Tests/FFBNormalizerTests/` for each
   effect, derived from the Linux pcap.
7. **Add the entitlement.** If the device is a new vendor, add the `idVendor`
   to `Sources/DEXT/Macoswheels.entitlements`.
8. **Update `README.md` and `man/macoswheels.7`.** Both list the supported
   devices.
9. **Run `swift test` on Linux.** All tests must pass before opening a PR.
10. **Run the CI workflow.** Download the artifact, install on a dev-mode Mac
    with the device plugged in, and run through the verification checklist in
    `/home/r/.claude/plans/i-want-to-be-melodic-zebra.md` (the original plan).
