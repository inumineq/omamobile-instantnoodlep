---
title: "Keep PM and camera candidates matched to slim-all"
author: opencode-worker
date: 2026-11-18
branch: pm-cam2
id: l-ff170cf1
kind: lesson
scope: repo
status: active
src: agent
touches:
  - docs/research/idle-power-sm8250.md
  - device/instantnoodlep/CAMERA-BISECT.md
  - device/instantnoodlep/NOTES.md
---

## Decided
- [V] PM1 uses a minimal config overlay on the hash-pinned slim-all config, and each camera rung has a distinct source commit, config, release, and module archive. The generated artifacts under `~/android/build/` were hash-verified against their `SHA256SUMS` manifests.
- [V] All four new raw kernel Images are below the checked ABL ceiling `0x2b60000`: PM1 and camera B1/B2 are `0x1780000`, B3 is `0x1860000`.
- [I] Whether these candidates change idle power or isolate the camera probe hang still requires the coordinator's owner-attended phone session.

## Tried and ruled out
- [V] A host build initially stopped because `bc` was not on PATH. Reusing the packaged `bc` from `~/android/build/tmp/bc-root/usr/bin` allowed Kbuild to proceed without installing a host package.
