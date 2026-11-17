---
title: "The imported AW8697 waveform period was 235 Hz, not this actuator's 170 Hz"
author: claude on omabook
date: 2026-11-17
branch: inumineq/misc-hw
id: l-1c3e4cbe
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/MISC-HW-PLAN.md
---

## Watch out
- The public GPL-2.0-only `aw8695-haptics.c` (SM8250 tree, tag 7.2.0-dev) hard-codes a 102-sample sine period, i.e. about 235 Hz at the 24 kHz sample rate [V: source file, `aw8695_ram_init()`]. The instantnoodlep actuator's preset resonance is 170.0 Hz (`awinic,f0-preset = <1700>`, tenths of a hertz) [V: public board patch 0074 at `4e04b523eefa`].
- Playing a 235 Hz waveform into a 170 Hz LRA wastes energy and can sound harsh, so the imported driver generates one period from `fixp_sin32_rad()` at `240000 / f0_preset` samples instead [V: `drivers/input/misc/aw8695-haptics.c` in `instantnoodlep-k3-misc`].
- The driver still requests no firmware: the waveform is arithmetic, not a vendor `.bin` [V: same file, no `request_firmware()`].
