# Logitech G-series protocol

Derived from [berarma/new-lg4ff](https://github.com/berarma/new-lg4ff). Covers
DFP, G25, DFGT, G27, G29, G920 and G923. The protocol is HID++-flavored —
short fixed-length commands tagged by an effect-byte and dispatched to one of
four hardware effect slots.

## USB identities

DFP / G25 / DFGT / G27 / G29 all start in a "Driving Force" compatibility mode
at `046D:C294`, then are switched into native mode and re-enumerate at a
model-specific PID.

| Wheel             | Native PID | Switch byte (`f8 09 <byte> 01 ...`) |
|-------------------|------------|-------------------------------------|
| DF-EX             | `C294`     | `0x00`                              |
| DFP               | `C298`     | `0x01`                              |
| G25               | `C299`     | `0x02`                              |
| DFGT              | `C29A`     | `0x03`                              |
| G27               | `C29B`     | `0x04`                              |
| **G29**           | `C24F`     | `0x05`                              |
| G920              | `C262`     | (already native; no switch needed)  |
| G923 (PC)         | `C266`     | `0x07`                              |
| G923 (PS)         | `C267`     | `0x07`                              |
| G923 (Xbox)       | `C26E`     | (no documented switch)              |
| Driving Force Shifter | `C29C` | n/a (button-only device)            |

## Native-mode switch

Two-command sequence on the boot PID `C294`:

```
[0xF8, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00]    # revert mode on USB reset
[0xF8, 0x09, mode_byte, 0x01, X, 0x00, 0x00]  # switch to native mode with detach
```

`X = 0x01` for G29/G923 (extra arg for newer wheels), `0x00` otherwise.

`Sources/Drivers/Logitech/LGCommon/LGModeSwitch.swift` mirrors this.

## Settings packets (HID output reports, endpoint 0x01)

Every settings command is a 7-byte HID output report.

| Setting              | Bytes                                                          |
|----------------------|----------------------------------------------------------------|
| Set rotation range   | `[0xF8, 0x81, range_lo, range_hi, 0, 0, 0]` (range 40..900)    |
| Disable autocenter   | `[0xF5, 0, 0, 0, 0, 0, 0]`                                     |
| Set autocenter (1)   | `[0xFE, 0x0D, expA/0xAAAA, expA/0xAAAA, expB/0xAAAA, 0, 0]`    |
| Activate autocenter  | `[0x14, 0, 0, 0, 0, 0, 0]`                                     |

`expA` and `expB` are the lg4ff curve from `lg4ff_set_autocenter_default`:

```
if magnitude <= 0xAAAA:
    expA = 0x0C * magnitude
    expB = 0x80 * magnitude
else:
    expA = 0x0C * 0xAAAA + 0x06 * (magnitude - 0xAAAA)
    expB = 0x80 * 0xAAAA + 0xFF * (magnitude - 0xAAAA)
# Non-MOMO wheels (every wheel we care about) right-shift expA by 1.
```

`magnitude` is a 16-bit value scaled from our 0..100 percent input as
`percent * 0xFFFF / 100`.

`Sources/Drivers/Logitech/LGCommon/LGSettings.swift` is the Swift mirror.

The G-series wheels do **not** have a software gain knob, unlike the
Thrustmasters' `0x43`. `supportsGain = false` in every Logitech `WheelQuirks`
struct and the generic driver throws when asked.

## FFB upload — slot/effect/op encoding

`Sources/Drivers/Logitech/LGCommon/LGFFBEncoder.swift`. Each upload is a single
7-byte HID output report:

```
cmd[0] = (0x10 << hardware_slot) | cmd_op
cmd[1] = effect type byte
cmd[2..6] = effect-specific parameters
```

`hardware_slot` is 0..3 (4 slots in hardware). PID effect-block-indices are
mapped via modulo: `hardware_slot = pid_slot & 0x03`.

`cmd_op`:

| Value | Meaning           |
|-------|-------------------|
| 0x01  | Download + play (initial upload) |
| 0x03  | Stop              |
| 0x0C  | Update (continue playing with new parameters) |

`effect type byte`:

| Value | Effect    |
|-------|-----------|
| 0x00  | Constant force |
| 0x0B  | Spring    |
| 0x0C  | Damper    |
| 0x0E  | Friction  |

### Constant force

`cmd[2 + hardware_slot] = TRANSLATE_FORCE(level)` where `TRANSLATE_FORCE(x)`
is `((clamped_int16(x) + 0x8000) >> 8) & 0xFF`. The other parameter bytes are
zero. The level byte position depends on the slot, which lets one HID report
update multiple slots' constant force simultaneously (lg4ff exploits this).

### Spring (effect byte 0x0B)

```
cmd[2] = d1 >> 3                              # high bits of low deadband
cmd[3] = d2 >> 3                              # high bits of high deadband
cmd[4] = (k2_scaled << 4) | k1_scaled         # 4-bit coefficients
cmd[5] = ((d2 & 7) << 5) | ((d1 & 7) << 1)
       | (s2 << 4) | s1                       # low bits + sign flags
cmd[6] = scaleU16(positive_saturation + 0x8000, 8)
```

where `d1, d2` are the deadband endpoints converted from PID's `deadBand` +
`centerOffset`, and `k1, k2` are the absolute coefficient magnitudes
right-shifted into 4-bit fields.

### Damper (effect byte 0x0C)

```
cmd[2] = scaleCoeff(|k1|, 4)
cmd[3] = s1                                   # 0 or 1
cmd[4] = scaleCoeff(|k2|, 4)
cmd[5] = s2
cmd[6] = scaleU16(sat + 0x8000, 8)
```

### Friction (effect byte 0x0E)

```
cmd[2] = scaleCoeff(|k1|, 8)
cmd[3] = scaleCoeff(|k2|, 8)
cmd[4] = scaleU16(sat + 0x8000, 8)
cmd[5] = (s2 << 4) | s1
cmd[6] = 0
```

`scaleCoeff(x, bits) = min(0xFFFF, x * 2) >> (16 - bits)`.

## Periodic and ramp — TODO

Logitech wheels render periodic and ramp **in software**, not in hardware. The
lg4ff driver samples the effect at a 2 ms timer tick, computes the
instantaneous force level, and issues a constant-force update via the same
0x10-slot-op encoding above.

That's a state machine: the DEXT `WheelSession` would need to maintain effect
metadata (start time, period, phase, magnitude, envelope) per active slot and
fire a timer to recompute and re-issue. The byte encoder for "constant" is
already correct, so the missing piece is the per-tick scheduler and effect
math (sine, square, triangle, sawtooth, ramp), not a new wire format.

Until that scheduler lands in the DEXT, `LGFFBEncoder.encode` throws
`notImplemented` for `.periodic` and `.ramp`. The protocol notes here are
recorded so re-deriving the math isn't necessary.
