---
title: "Build phone kernels with clang 23, not the MBP Docker clang 19"
author: claude
date: 2026-11-18
branch: inumineq/slim-result
id: l-e03ff7fe
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/kernel.config
  - docs/runbooks
---

## Watch out
- [V] Kernels built in the MacBook Pro Docker image `k3build:audio-base` (Debian clang 19.1.7) freeze before the panel handover: the fastboot splash stays up with a coloured glitch at the top, no USB, no journal, empty pstore. Seen 2026-11-17/18 with the camera kernel, the slim kernel and a control build of the known-good daily `.config` (Image 44.85 MB, under `0x2b60000`). The control build rules out the config.
- [V] The same slim tree and `.config` built on omabook with clang/LLD 23.1.3 boots: USB in 6 s, `running`, panel, msm GL, Wi-Fi, hci0, gauge.
- [I] The cause inside the clang 19 output is not traced; `olddefconfig` also flips toolchain-dependent options (`ARM64_BTI_KERNEL`, `LSUI`).
- Build phone kernels with clang 23 (omabook, or an Arch container on the MBP with current clang). Treat a freeze on the fastboot splash as a toolchain suspect before blaming a driver.

## Tried and ruled out
- Size alone does not explain the P2 charger freeze: P2 Image is 44,657,152 bytes, under `0x2b60000` (45,481,984), built with clang 23.1.3 [V: build dirs]. The charger driver stays the suspect for P2.
