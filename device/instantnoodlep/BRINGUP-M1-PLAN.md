<!-- SPDX-License-Identifier: MIT -->
# BRINGUP-M1: first light on instantnoodlep

Plan for the first boot of our kernel on slot B, with stock untouched on
slot A. Modelled on cheetah's BRINGUP-M1.md (upstream). Write and gate
before any code runs on the phone.

## 1. Status

- Date: 2026-11-15
- Branch/worktree: none yet (to be created in linux-omarchy-mobile, based on `omamobile`)
- Built: nothing. Ran on the phone: stock only.
- Stage-0 facts: pending (docs/STAGE-0.md); this plan's [I] items resolve there.

## 2. Goal

Kernel boots from slot B; USB gadget networking up; SSH reachable
(`ssh root@172.16.42.1`); watchdogs handled; `panic=10`; stock still boots
on slot A afterwards.

## 3. Path abbreviations

- `G/` = OnePlus GPL kernel (android_kernel_oneplus_sm8250) as register/clock reference
- `R/` = our stock captures (private, `captures/<date>/`)
- `L/` = linux-omarchy-mobile branch `omamobile`
- `P/` = the SM8250 community fork (postmarketOS/Nura)

## 4. Facts (each [V] with source or file:line, or [I] to check)

- [V] Upstream Linux carries SM8250 OnePlus bindings, common DTS, panel and
  Synaptics TCM touch drivers (LWN 979482).
- [V] `P/` carries `sm8250-oneplus-instantnoodlep.dts` and a Wi-Fi/BT DTS
  fix from around v6.11.
- [V] Nura image (kernel 7.2) shows display 1440x3168@120, GPU, audio,
  Wi-Fi, BT, modem/SMS/data, GPS, NFC, sensors, 5 cameras on this hardware.
- [I] Qualcomm ABL picks no DTB by /soc_id (unlike Pixel); boot images on
  this device are `boot`, `dtbo`, `vbmeta` (no `init_boot`/`vendor_boot`).
- [I] Kernel cmdline reaches the kernel via the boot image; upstream prefers
  /chosen/bootargs in the DTB. Decide after stage 0.
- [I] earlycon UART base from the live stock DT (R/devicetree).
- [I] Slot flags live in GPT attributes or `devinfo` (stage 0 Q2).

## 5. Design and options

- Base DTS: port `P/`'s instantnoodlep DTS into `L/` in upstream style
  (bindings, then driver, then DTS; one commit per logical change), rather
  than regenerating from scratch.
- Initramfs: reuse upstream's shared `initramfs/init` via device.conf;
  `SIMPLEFB_TRIG_CON` stays unset until this phone's panel registers are
  proven (upstream rule: never another phone's address).
- Storage guard: `UFS_RW` limited to slot B images + `userdata` from day one.

## 6. What was built

| Where | Change |
| --- | --- |
| (none yet) | |

## 7. Risks

- Wrong reserved-memory nodes let firmware corrupt RAM silently; check every
  stock reserved-memory node against R/iomem before first boot.
- A wrong UFS allowlist is the worst possible failure mode; the build refuses
  anything not slot B + userdata, keep it that way.
- Panel variants: our EU unit has AMS678UW01 (as the Nura image was tested
  with); other units may need separate DT work.

## 8. Gated runbook

| # | Step | Risk | Stop condition | Rollback |
| --- | --- | --- | --- | --- |
| 0 | Stage-0 complete, answers in #808, maintainer ack | 0 | any open [I] in section 4 | n/a |
| 1 | Build kernel + images with DEVICE=instantnoodlep | 0 | build errors | n/a |
| 2 | `tools/install-phone --dry-run` | 0 | any partition outside allowlist | fix device.conf |
| 3 | First flash: slot B images only | medium | fastboot rejects, phone stays in fastboot | `fastboot set_active a`, stock boots |
| 4 | Boot, observe over USB | medium | no USB network in 5 min | reboot to slot A |
| 5 | Verify slot A still boots | low | anything unexpected | n/a |

## 9. Results

(none yet; append with dates and the kernel release that produced them)

Open questions: the [I] items above, tracked in docs/STAGE-0.md section 5.
