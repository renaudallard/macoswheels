---
name: Wheel support request
about: A wheel you'd like macoswheels to handle
title: 'Support: '
labels: enhancement, wheel-support
---

**Wheel make & model**

**USB VID / PID**
From `system_profiler SPUSBDataType | grep -i -E 'vendor|product id'` or Linux
`lsusb`.

**Existing Linux driver (if any)**
e.g. `hid-tmff2`, `new-lg4ff`, `t150_driver`, custom out-of-tree, none.

**Can you provide a `usbmon` capture?**
On Linux: `sudo modprobe usbmon && sudo tshark -i usbmonN -w wheel.pcapng`
while exercising the wheel in a game. Drop the capture under
`docs/PROTOCOL-NOTES/<device>/` in a PR if you can — it's the single most
useful artifact for adding a new wheel.

**Hardware features**
- Rotation range (min/max degrees):
- Number of buttons:
- Number of pedals + clutch present (y/n):
- Hardware FFB effects (spring/damper/friction/inertia):
- H-pattern shifter built in or detachable:
