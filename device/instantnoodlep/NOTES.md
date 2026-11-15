<!-- SPDX-License-Identifier: MIT -->
# NOTES: instantnoodlep (OnePlus 8 Pro, IN2023)

Newest first. Findings that matter beyond one subsystem go here; subsystem
detail lives in the *-PLAN.md files.

## 2026-11-15 (late): M1 split, RAM-only plan

- The owner chose to split M1 on the wayfinder map. **M1a** is a RAM-only
  first light (`fastboot boot`, nothing written, slot A stock and active);
  `BRINGUP-M1-PLAN.md` now plans it, with kernel K1 (SM8250 community
  kernel) before K2 (`omamobile` + ported DTS). **M1b** is the persistent
  slot-B install (`boot_b`/`dtbo_b`, `--set-active`), gated on the tickets
  "Slot-B bootable marking on Qualcomm: the named GPT-attribute exception"
  and "vbmeta/AVB handling on an unlocked Qualcomm ABL". **M2** stays
  "Arch root on userdata".
- [I] There is no public evidence yet that this phone RAM-boots a mainline
  image. Lineage and the community port document flashing only
  (`lineage_wiki` `install_method: fastboot_nexus`; Nura README "Flash"),
  and a TWRP-era guide flashes recovery rather than booting it.
  wiki.nura.eco and XDA could not be checked (bot protection / 403).
  Stage-0 Q11 decides at STAGE-0-RUNBOOK D3 whether this ABL RAM-boots at
  all (a Magisk-patched stock image); the first mainline image is M1a
  step R1.
- [I] Main risk: on a RAM boot the stock `dtbo_a` overlay is still read
  from flash and applied to our DTB. The Qualcomm reference ABL then
  either refuses the image or applies the overlay; a partial graft would
  leave the kernel on a contaminated DT. The plan has an offline overlay
  check (P3) and a live-DT diff (R3) for it.
- Disputed: the fastboot button combo. `device.conf` says Volume Down +
  Power; Lineage's device data and the Nura README say Volume Up + Volume
  Down + Power. Stage 0 settles it; until then, `adb reboot bootloader`.

## 2026-11-15 (evening): research landed, upstream precedents

- Research notes from the four research tickets are in `docs/research/`,
  each with a coordinator review of corrections: boot header v2 (not v3),
  root compatible `"oneplus,instantnoodlep", "qcom,sm8250"`, a 1080x2376
  bootloader framebuffer, `serial0` = the Bluetooth UART, Adreno 650 (not
  Mali) and SDX55 over MHI firmware rows.
- Watch: upstream #808 has not changed (open, 0 comments, 0 labels).
  instantnoodlep is not on the DEVICES.md Wanted list [V: GitHub API,
  2026-11-15 ~20:10 UTC].
- Precedents in upstream DEVICES.md (status 2026-11-14) [V]:
  - OnePlus 6 (enchilada, SDM845, upstream #432): first light was a
    **RAM-only `fastboot boot`**, with nothing written. It stays RAM-only
    "until the slot-B install and its CONTRIBUTING.md §3.1 entry are
    agreed". Pixel 4 (flame) and Xiaomi Mi 8 (dipper) also merged
    RAM-only first-light probes. [I] Our M1 first light could do the
    same; then the GPT-attribute exception would gate only the persistent
    slot-B install. This is an owner decision.
  - enchilada: `boot_b` sits on LUN `sde`, not on `sda` with `userdata`.
    The guard needs `UFS_RW_LUNS` (upstream #530). That is a device.conf
    key our draft lacks; stage-0 question 10 covers it.
  - enchilada: ABL appends `root=PARTUUID=<system_a> skip_initramfs ro
    init=/init` even on `fastboot boot`. The shared init copes.
  - enchilada erased `dtbo_b`, because downstream overlays do not apply to a
    mainline DTB. This matches our [I] on dtbo.
  - enchilada: `--set-active` writes the GPT slot flags, and upstream
    treats it as a slot-flag write.
  - Pixel 4 XL (coral, SM8150): "§3.1 entry still to land". No Qualcomm
    GPT-attribute exception exists upstream yet.
  - OnePlus 13 (dodge): the `qcom-abl` boot method (a header-v4
    chainloader) was merged in upstream #111. It is not our path, but it is
    the precedent for adding a Qualcomm `BOOT_METHOD`.
  - POCO F3 (alioth, SM8250): upstream #25 was closed 2026-11-11 and can
    be reopened. It is the closest SoC sibling.
- HITL runbooks written: `docs/runbooks/STAGE-0-RUNBOOK.md`,
  `docs/runbooks/RESTORE-ASSETS.md`.

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
