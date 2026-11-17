---
title: "The M-CAM1 camera path is built in; check the graph by entity name"
author: claude on macbookpro
date: 2026-11-17
branch: instantnoodlep-k3-camera
id: l-51f65d4c
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/CAMERA-PLAN.md
  - device/instantnoodlep/kernel.config
  - device/instantnoodlep/patches/camera
---

## Watch out

- [V] `VIDEO_IMX471`, `VIDEO_QCOM_CAMSS`, `I2C_QCOM_CCI`, `V4L2_CCI`,
  `V4L2_CCI_I2C` and `SM_CAMCC_8250` are all `=y` in the camera fragment, so
  the modules tarball for release `7.3.0-rc6-instantnoodlep-k3-camera-g70d0761d1`
  contains no camera module. Do not look for `imx471.ko`; a missing module
  file is not a missing driver.
- [V] `dtc -I dtb -O dts` on the board DTB prints pre-existing base-DTS
  warnings (geniqup i2c/spi duplicate unit-address, dsi `#address-cells`).
  They are not from the camera series and do not appear in the build or
  schema logs; do not chase them.
- [V] The graph names the coordinator must match are `msm_csiphy3`,
  `msm_csid0`, `msm_vfe0_rdi0` and the video entity `msm_vfe0_video0`
  (`camss-csiphy.c:794`, `camss-csid.c:1370`, `camss-vfe.c:2077-2080`,
  `camss-vfe.c:2122`). RDI bytes-per-line alignment is 16 on CAMSS_8250, so
  1928x1088 RAW10 is 2416 bytes/line and 2628608 bytes/frame.

## Decided

- [V] The series stays three commits (binding, driver, board) on top of combo
  `aa996bae0`; the Kona match stays in the base and is never part of the
  series. Artefacts and hashes are in CAMERA-PLAN section 9.4.
- [I] Rail ordering, chip ID and 200 MHz streaming remain coordinator gates;
  a chip-ID failure in C2 stops the experiment rather than inviting a mode or
  graph change.
