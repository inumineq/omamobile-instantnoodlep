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
- [V] Same slim tree (`78f38a2acc99`) and same `.config`, two toolchains: built in the MacBook Pro Docker image `k3build:audio-base` (Debian clang 19.1.7, header `image_size` 0x1750000) it freezes on the fastboot splash with a coloured glitch, no USB, no journal; built on omabook with clang/LLD 23.1.3 (`image_size` 0x1720000) it boots to `running` with panel, msm GL, Wi-Fi, hci0 and gauge (2026-11-18). Both are far under the ABL ceiling, so the toolchain is the difference.
- [I] The cause inside the clang 19 output is not traced; `olddefconfig` also flips toolchain-dependent options (`ARM64_BTI_KERNEL`, `LSUI`).
- Build phone kernels with clang 23 (omabook, or an MBP container with current clang) and still check `image_size <= 0x2b60000` (`od -An -tx8 -j16 -N8 Image`).

## Tried and ruled out
- A control build of the daily `.config` with clang 19 also froze, but its `image_size` was 0x2ba0000, over the ceiling, so it proves nothing about the toolchain. The front-camera kernel (clang 19, 0x2cd0000) is confounded the same way.
- P2 charger (clang 23) has `image_size` 0x2b70000, just over the ceiling, which explains its freeze; the charger driver is not shown to be at fault.
