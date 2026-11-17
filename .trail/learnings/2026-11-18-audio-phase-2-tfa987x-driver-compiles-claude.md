---
title: "Audio phase 2: TFA987x driver compiles clean offline; sound stays phone-gated"
author: claude
date: 2026-11-18
branch: inumineq/tfa987x
id: l-0eef74fe
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/AUDIO-M5-PLAN.md
  - device/instantnoodlep/patches/audio-tfa987x
---

## Watch out

- [V] The TFA987x codec driver (branch `instantnoodlep-k3-tfa987x` @ `bf29d8b47` on `instantnoodlep-k3-audio`) compile-checks clean with clang 23.1.3 as a single object (`make ARCH=arm64 LLVM=1 O=~/android/build/k3-tfa M=sound/soc/codecs tfa987x.o`, 0 warnings), passes `dt_binding_check` for `nxp,tfa987x.yaml` (dtschema 2026.9) and `checkpatch.pl --strict` 0/0/0. Patches in `device/instantnoodlep/patches/audio-tfa987x/`.
- [V] Writing every managed register as a full 16-bit value after the I2C soft reset removes the community driver's uninitialized-DCDC-value defect by construction: the binding exposes no boost properties, so no optional value is ever read unwritten.
- [I] Nothing about the real chips is proven yet: probe, revision match, control enumeration and first sound all wait for the PR #82 §9 runbook (RAM boot, one speaker, -60 dBFS, raw gain 0, boost off, separate owner go). Do not treat the clean compile as "audio works".
