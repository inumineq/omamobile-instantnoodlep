---
title: "Audio speakers are TFA9874, not TFA989x or WSA881x"
author: agent on omabook
date: 2026-11-17
branch: instantnoodlep-k3-audio
id: l-b9f9c4ea
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/AUDIO-M5-PLAN.md
  - device/instantnoodlep/kernel.config
  - tools/build-instantnoodlep-probe
---

## Decided
- [V] Public D patch 0005 at 4e04b523eefa identifies WCD9385 reset GPIO32, TX mapping <2 2 3 4>, and two TFA9874 amplifiers on mainline i2c15, 0x34/GPIO91 and 0x35/GPIO99. Source link and phase corrections are in AUDIO-M5-PLAN's implementation correction.
- [V] Combo aa996bae0 has no TFA987x driver. TFA989x supports only 9890/95/97; it must not bind TFA9874. Phase 1 describes the amplifiers disabled and excludes their DAI link, so an unavailable amplifier cannot defer the whole sound card.
- [V] The probe builder disables all DSPs by default. Audio needs an explicit ADSP-only opt-in with a firmware.map name assertion; CDSP/SLPI stay disabled. Stock DTBO remains installed and combo's temporary Kona/PDM match is required (l-48e0c482).
- [I] Published board wiring and an offline build do not establish functioning sound on this unit. All mixer routing and playback remain owner/coordinator gates.
