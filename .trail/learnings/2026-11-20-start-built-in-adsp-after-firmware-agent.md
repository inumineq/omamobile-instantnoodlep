---
title: "Start built-in ADSP after firmware is mounted"
author: agent on omaserver
date: 2026-11-20
branch: inumineq/audio2
id: l-5a10cf77
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/AUDIO-M5-PLAN.md
  - packages/omamobile-device-instantnoodlep
---

## Decided
Keep `QCOM_Q6V5_PAS=y` and ADSP auto-boot, then let a package oneshot retry `remoteproc state=start` after `local-fs.target` once the package has assembled the owner's firmware. Phase 1 proves that the exact sysfs start works, while firmware-in-initramfs requires device bytes in an early boot artifact and converting remoteproc to a module changes the config and all PAS probe timing.

## Tried and ruled out
Do not embed ADSP firmware in the committed initramfs or kernel artifacts: firmware must be taken from the owner's own phone at install time. Making the PAS driver a module is not necessary to solve the demonstrated race and broadens probe-order changes.

## Watch out
The built-in driver's initial missing-file auto-boot attempt may leave a state that needs explicit recovery; confirm in the next RAM boot that a post-rootfs `start` works. Never reset/reload remoteproc automatically after a failed start.
