---
title: "Probe the alert-slider Hall pair with four i2cget reads, never i2cdetect"
author: claude on omabook
date: 2026-11-17
branch: inumineq/misc-hw
id: l-8f847777
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/MISC-HW-PLAN.md
---

## Watch out
- The public GPL board source describes alternative Hall pairs on `qupv3_se1_i2c`: IST8801 at `0x18/0x19` and MXM1120 at `0x0c/0x0d` [V: OnePlusOSS `kona-oem.dtsi:49-95` at `cad09e061ef6`]. It does not say which pair this unit has.
- `i2cdetect -y -r 1 0x0c 0x19` probes ten addresses nobody approved. Read only the four approved ones with `i2cget -y 1 <addr> 0x09`, which writes nothing but the register pointer [V: MISC-HW-PLAN §8.1].
- Both public GPL headers use register `0x09` as the device ID: `0x9c` for MXM1120, `0x81` for IST8801 [V: `hall_mxm1120.h:151`, `hall_ist8801.h:133`]. A NACK proves nothing about absence: the L10A supply may be off, and no rail is enabled in this phase.
- Never retry with `i2cget -f` or force a client node: an unknown ID or a bus timeout is a stop condition, not a puzzle to solve on the phone.
