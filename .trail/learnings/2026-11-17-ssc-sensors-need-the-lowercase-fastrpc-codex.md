---
title: "SSC sensors need the lowercase FastRPC node and explicit proxy backend properties"
author: codex on omabook
date: 2026-11-17
branch: inumineq/sensors
id: l-cf9a7203
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/SENSORS-M5-PLAN.md
  - device/instantnoodlep/SENSORS-PACKAGING.md
  - device/instantnoodlep/kernel.config
---

## Watch out
- [V] The combo kernel creates `fastrpc-sdsp`, not `fastrpc-SDSP`: `drivers/misc/fastrpc.c:2468-2469` formats the DT's literal lowercase label (`sm8250.dtsi:3132`).
- [V] Current proxy source ca0d5b08bd647afc5f8ead3ce00a44018fbc633f needs `libssc >=0.2.1`; the agx fork pinned during planning is 0.1.7 and provides a different pkg-config name. Use the DylanVanAssche source identified by upstream proxy CI; immutable pins are in SENSORS-PACKAGING.md.
- [V] Proxy upstream udev rules advertise only `ssc-light ssc-compass` for SDSP, while its accelerator/proximity backends require `ssc-accel`/`ssc-proximity`; the device package must opt in explicitly (source paths in SENSORS-PACKAGING.md).
- [V] Generic `build-instantnoodlep-probe` disables every remoteproc; a sensors candidate must re-enable SLPI in the final packed DTB and validate the unpacked image, not only modify its sidecar DTB.
- [I] Sensor libraries/config need an owner-OTA names-only allowlist before provisioning; no persist calibration may be imported by this phase. Kernel/DTB build success does not prove SLPI or sensor data on the phone.
