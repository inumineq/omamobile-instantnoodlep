<!-- SPDX-License-Identifier: MIT -->
# NOTES: instantnoodlep (OnePlus 8 Pro, IN2023)

Newest first. Findings that matter beyond one subsystem go here; subsystem
detail lives in the *-PLAN.md files.

## 2026-11-15 (coordinator handover to Claude)

- Research tickets resolved; notes in `docs/research/` (each with a
  coordinator review block). Headline facts:
  - [V] Community DTS root compatible is `"oneplus,instantnoodlep",
    "qcom,sm8250"`, msm-id `0x164`, board-id `0x08`. The draft
    device.conf `COMPATIBLE` does not match yet (device.conf grilling
    ticket).
  - [V] `serial0 = &uart6` in the community DTS is the Bluetooth UART. The
    earlycon candidate is the SoC debug UART `uart12` @ `0xa90000` [I until
    the live DT confirms it].
  - [V] OnePlus SM8250 build config: boot header v2, DTB in boot.img,
    separate dtbo. Upstream `bin/omamobile` supports `android-v4`,
    `android-v0`, `qcom-abl` only, so a header-v2 method is a maintainer
    question.
  - [V] Wi-Fi/BT is QCA6390 (`pci17cb,1101`, `qcom,qca6390-bt`), not
    WCN6851. The modem is SDX55 over PCIe/MHI (`qcom/sdx55m/sbl1.mbn`).
- Upstream check: #808 still open, 0 comments, no labels. instantnoodlep is
  not on the Wanted list in upstream `docs/DEVICES.md` (status 2026-11-14,
  last commit 2026-11-15). New Qualcomm precedents there: Pixel 4 (flame,
  SM8150), Xiaomi Mi 8 (dipper) and OnePlus 6 (enchilada, `android-v0`)
  have merged **RAM-only** first-light probes. OnePlus 13 (dodge) uses the
  `qcom-abl` chain.
- Owner runbooks prepared: `docs/hitl/RESTORE-ASSETS.md` (run first) and
  `docs/hitl/STAGE-0.md`. `scripts/gpt-attrs.py` decodes the read-only GPT
  dumps from stage 0.

## 2026-11-15

- Support request posted upstream:
  [derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808).
  No maintainer reply yet.
- Workspace bootstrapped: device.conf draft (values marked TODO/I), stage-0
  checklist and collect script, restore runbook, BRINGUP-M1 plan skeleton.
- Mainline status of this hardware, demonstrated by the unofficial Nura
  image (kernel 7.2, Oct-Nov 2026 releases) on an IN2023 EU unit: display
  1440x3168@120 Hz, GPU, speakers/mics, Wi-Fi, Bluetooth, modem/SIM/data/SMS,
  GPS, NFC, sensors, all five cameras via libcamera. Voice calls (VoLTE) NOT
  verified. That image overwrites `super`; our model never does.
- Restore assets still to secure locally: full OTA (payload.bin) for IN2023,
  MSM Download Tool package for IN2023 (Windows, last resort, wipes+relocks).
