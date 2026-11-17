---
title: "IMX471 needs DT support before front-camera board enablement"
author: codex on macbookpro
date: 2026-11-17
branch: instantnoodlep-k3-camera
id: l-dc980278
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/CAMERA-PLAN.md
  - device/instantnoodlep/kernel.config
  - device/instantnoodlep/patches/camera
---

## Watch out

- [V] Combo aa996bae0's upstream IMX471 driver has ACPI matching only, one `vana` supply and no DT binding; a board `sony,imx471` node alone cannot bind it (drivers/media/i2c/imx471.c).
- [V] That driver's only mode is 1928x1088 RAW10, four D-PHY lanes, 19.2 MHz xclk and 200 MHz link frequency. Nura patch 0012's 748.8/400 MHz values belong to its different driver, not this one.
- [V] This Mac's case-insensitive checkout reports unrelated case collisions. Build a git archive inside a case-sensitive Docker volume; never copy the damaged checkout file contents into the build.

## Decided

- [V] Coordinator authorized separate binding and driver patches before the front-only board integration. DT uses AVDD/DVDD/DOVDD bulk control; ACPI keeps `vana`. Keep the existing clock/mode/PLL values and reset recovery sequence.
- [I] Bulk control does not prove rail ordering or module-specific electrical timing. Binding, chip ID and one raw frame are explicit coordinator-only gates in CAMERA-PLAN section 9.1; no worker phone access.
- [V] Combo's Kona patch is authorized only for this RAM candidate. It is not part of the camera patch series and must not be sent upstream.
