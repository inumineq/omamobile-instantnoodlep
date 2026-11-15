<!-- SPDX-License-Identifier: MIT -->
# Draft: proposed `device/instantnoodlep/device.conf` (ticket #8)

Status: **DRAFT. This file edits nothing.** It is the proposal that the
ticket "Lock device.conf values once stage-0 answers exist" (#8) decides
on. `device/instantnoodlep/device.conf` itself is untouched.

Inputs: `device/instantnoodlep/BRINGUP-M1-PLAN.md` §5.9 and §5.7, the
upstream flame/dipper/enchilada `device.conf` at `6c11752ae4c3`, and
`docs/research/*` — notably `vbmeta-avb.md` (PR #27) for every vbmeta
line. Evidence marks as usual: [V] checked (source given),
[I] inference to check on the device. Every `{{...}}` names the stage-0
step (`docs/STAGE-0.md` §5) whose answer fills it.

## The proposed file

```
# SPDX-License-Identifier: MIT
# Device descriptor: OnePlus 8 Pro (instantnoodlep), EU model IN2023.
#
# FORMAT: KEY=value or KEY="value" lines, comments and blank lines only.
# No shell: no $, backticks or command substitution. Mirrors the upstream
# cheetah descriptor (derekross/omarchy-mobile device/cheetah/device.conf),
# keys documented in upstream docs/RELEASES.md.
#
# M1a is RAM-only: BOOT_METHOD=ram-only with empty BOOT_IMAGES and UFS_RW,
# the shape of upstream's flame and dipper ram-only descriptors. The
# generic image, flash, push and installer paths refuse this descriptor.
# The probe image is built offline by tools/build-instantnoodlep-probe
# (header version, geometry and cmdline are baked in there, not here) and
# booted with `fastboot boot`; nothing is written to the phone.
# {{...}} marks a value stage 0 still has to fill (docs/STAGE-0.md §5).
# Parked M1b values are commented out, not deleted (BRINGUP-M1-PLAN §5.9).

# --- Identity ---
CODENAME=instantnoodlep
NAME="OnePlus 8 Pro"
SOC=sm8250
COMPATIBLE="oneplus,instantnoodlep"
# I: the upstream project's package naming convention.
PACKAGE=omamobile-device-instantnoodlep
# I: none of cheetah's board packages apply; fill as subsystems come up
# (audio, sensors, modem, camera).
ROOTFS_PACKAGES=""

# --- Kernel and device tree ---
# Path once the DTS is ported into linux-omarchy-mobile's tree.
DTB=qcom/sm8250-oneplus-instantnoodlep.dtb
# Empty until bring-up overlays exist; proven nodes move into the DTS
# itself and leave this list (upstream CONTRIBUTING 6.1).
DTB_OVERLAYS=""
# N/A: /soc_id DTB selection is a Pixel ABL rule; Qualcomm's ABL selects
# DTBs by qcom,msm-id/qcom,board-id. Keep unset unless stage 0 disagrees.
#SOC_IDS=

# --- Boot (M1a) ---
BOOT_METHOD=ram-only
BOOT_IMAGES=""
UFS_RW=""
# Boot image header v2 (not v3): the DTB rides inside boot.img, dtbo is a
# separate partition, and there is no init_boot/vendor_boot on this phone
# [V: docs/research/abl-boot-flow.md §4; PM/deviceinfo header_version=2].
# Stage-0 Q1 confirms on the unit, Q7 confirms the header fields offline.
# No upstream image method packs v2 yet; that tooling PR comes later and
# is coordinated with the coral port (BRINGUP-M1-PLAN §5.7).

# --- Parked for M1b and later (BRINGUP-M1-PLAN §5.9) ---
# Inactive until the GPT-attribute exception has its upstream entry and
# the ticket "vbmeta/AVB handling on an unlocked Qualcomm ABL" is
# resolved. No vbmeta anywhere: it is on upstream's never-flash list
# (docs/research/vbmeta-avb.md §0, PR #27).
# No devinfo anywhere: slot flags are GPT attributes on this phone
# (docs/research/abl-boot-flow.md), so devinfo is in no list of ours.
#BOOT_IMAGES="boot dtbo"
#UFS_RW="boot_b dtbo_b userdata"
#UFS_RW_LUNS={{Q10: disk name of the LUN holding boot_b (STAGE-0-RUNBOOK D4 by-name-root.txt); set only if not sda — upstream #530}}
#OMAMOBILE_SLOT=b
#DTBO_SOURCE=instantnoodlep-overlay.dts
#DTBO_BOARD_ID={{Q9: RESTORE-ASSETS R4 mkdtboimg dump, matched to msm-id/board-id}}
#DTBO_BOARD_REV={{Q9: same}}
#VENDOR_CMDLINE="console=tty0 panic=10 omamobile.initramfs clk_ignore_unused pd_ignore_unused printk.devkmsg=on"
# plus {{Q6: earlycon=<uart>,<base> from the live DT (STAGE-0-RUNBOOK D5),
# only if a debug UART exists; serial0 is the Bluetooth UART}}
#OS_VERSION={{Q7: RESTORE-ASSETS R4 unpack_bootimg, the stock boot header}}
#OS_PATCH_LEVEL={{Q7: same}}
# AVB_FOOTERS and friends stay unset unless the vbmeta ticket's evidence
# says stock's vbmeta chains the images (laptop-build-setup.md item 4).

# --- Radio backup ---
# Qualcomm NV/calibration equivalents of cheetah's radio partitions.
NV_PARTS={{candidates "persist modemst1 modemst2 fsc fsg"; each name verified against STAGE-0-RUNBOOK D4 by-name-root.txt}}
# NV_BACKUP_EXTRA is deliberately absent: the old draft listed devinfo as
# "holds the slot flags". Slot flags are GPT attributes here; devinfo is
# backed up read-only by the bring-up plan instead (BRINGUP-M1-PLAN R6).

# --- Guided install ---
# {{Button finding: the old draft says Volume Down + Power; Lineage
# device data and the Nura README say Volume Up + Volume Down + Power
# (BRINGUP-M1-PLAN §8 note). Settled when the owner first reaches
# fastboot by the buttons (stage-0 phase B at the latest).}}
INSTALL_KEYS_FASTBOOT={{the proven button combo, one line}}
INSTALL_KEYS_RESTART="hold Power for about 30 seconds, then press it again"
# I: rough estimate; count kernel tree, factory OTA, images and rootfs.
INSTALL_FREE_GB=25

# --- Initramfs ---
# Shared upstream script.
INITRAMFS_INIT=/initramfs/init
# WARNING (upstream rule): never put another phone's display register
# address in this key. Leave unset until this phone's panel is driven.
#SIMPLEFB_TRIG_CON=
# Leave unset until the panel driver probe facts are collected.
#BRINGUP_PROBE=
# Panel size in pixels, portrait [V: the Nura image drives this unit's
# panel at 1440x3168@120].
PANEL_SIZE=1440x3168
```

## Line by line

Line numbers refer to the code block above.

| line | value | evidence | filled by |
| --- | --- | --- | --- |
| 19 | `CODENAME=instantnoodlep` | [V] #808 body; current `device.conf:14` | fixed |
| 20 | `NAME="OnePlus 8 Pro"` | [V] current `device.conf:15` | fixed |
| 21 | `SOC=sm8250` | [V] #808 body (SM8250); current `device.conf:18` | fixed |
| 22 | `COMPATIBLE="oneplus,instantnoodlep"` | [V] the community DTS's root compatible (`BRINGUP-M1-PLAN.md:165-167`; `docs/research/sm8250-dts-gap.md:13`, review item 1) | fixed (corrects the draft) |
| 24 | `PACKAGE=omamobile-device-instantnoodlep` | [I] upstream package naming convention (current `device.conf:23-24`) | ticket #8 |
| 27 | `ROOTFS_PACKAGES=""` | [I] none of cheetah's board packages apply (current `device.conf:25-27`) | later subsystem work |
| 31 | `DTB=qcom/sm8250-oneplus-instantnoodlep.dtb` | [I] path once the DTS is ported (current `device.conf:30-31`; `BRINGUP-M1-PLAN.md` §5.8) | the K2 DTS port |
| 34 | `DTB_OVERLAYS=""` | [V] current `device.conf:32-34` (upstream CONTRIBUTING 6.1) | fixed |
| 37 | `#SOC_IDS=` (unset) | [V] Qualcomm ABL selects DTBs by `qcom,msm-id`/`qcom,board-id`, not `/soc_id` (`BRINGUP-M1-PLAN.md:117-118`) | stays unset unless stage 0 disagrees |
| 40 | `BOOT_METHOD=ram-only` | [V] upstream ram-only descriptors at `6c11752ae4c3` (`device/flame/device.conf:1-12`, `device/dipper/device.conf:1-11`); `BRINGUP-M1-PLAN.md` §5.7, §5.9 | fixed for M1a |
| 41 | `BOOT_IMAGES=""` | [V] same ram-only precedents; every generic tool refuses them (`BRINGUP-M1-PLAN.md:293-296`) | fixed for M1a |
| 42 | `UFS_RW=""` | [V] same; M1a has no writable exception at all (`BRINGUP-M1-PLAN.md:252-256`) | fixed for M1a |
| 43-48 | header-v2 comment | [V] header v2, DTB inside `boot.img`, separate `dtbo`, no `init_boot`/`vendor_boot` (`BRINGUP-M1-PLAN.md:112-115`; `docs/research/abl-boot-flow.md` §4) | confirmed by stage-0 Q1 (STAGE-0-RUNBOOK B2) and Q7 (RESTORE-ASSETS R4) |
| 56 | `#BOOT_IMAGES="boot dtbo"` (parked) | [V] parked slot-B values without `vbmeta` (`BRINGUP-M1-PLAN.md:357-362`; `docs/research/vbmeta-avb.md` decision input 1: remove `vbmeta` from `BOOT_IMAGES`; never-flash list `UP/CONTRIBUTING.md#L55-L63`; cf. `docs/research/gpt-exception-prep.md:371-374`) | M1b, after ticket #10 |
| 57 | `#UFS_RW="boot_b dtbo_b userdata"` (parked) | [V] same, with `vbmeta_b` removed (`docs/research/vbmeta-avb.md` decision input 1); `userdata` is M2 and must be on the list (ticket #8's hard rule) | M1b/M2 |
| 58 | `#UFS_RW_LUNS={{...}}` (parked placeholder) | [V] upstream #530 merged 2026-11-09 (`docs/research/gpt-exception-prep.md:249-252`); enchilada's `boot_b` sits on `sde`, not `sda` (`NOTES.md:52-54`) | stage-0 Q10 (STAGE-0-RUNBOOK D4 `by-name-root.txt`); set only if not `sda` |
| 59 | `#OMAMOBILE_SLOT=b` (parked) | [V] upstream `device/enchilada/device.conf` at `6c11752ae4c3` | M1b |
| 60-62 | `#DTBO_SOURCE`, `#DTBO_BOARD_ID`, `#DTBO_BOARD_REV` (parked placeholders) | [I] whether M1b ships a dtbo at all (`BRINGUP-M1-PLAN.md` §5.3); Q4 already answered yes, `dtbo_idx=16` (ticket #3, A3) | stage-0 Q9 (RESTORE-ASSETS R4 `mkdtboimg dump`) |
| 63-65 | `#VENDOR_CMDLINE=...` (parked) + earlycon placeholder | [V] cmdline from `BRINGUP-M1-PLAN.md:182-187`, baked into the M1a probe builder (`tools/build-instantnoodlep-probe:53-54`), so unused while ram-only; `serial0` is the Bluetooth UART (`BRINGUP-M1-PLAN.md:186-187`) | M1b; `earlycon=` only from stage-0 Q6 (STAGE-0-RUNBOOK D5) |
| 66-67 | `#OS_VERSION`, `#OS_PATCH_LEVEL` (parked placeholders) | [I] the stock boot header's values; unused while ram-only (the probe builder sets no os_version) | stage-0 Q7 (RESTORE-ASSETS R4 `unpack_bootimg`) |
| 68-69 | AVB keys stay unset (comment) | [V] drop `vbmeta`/`AVB_*` unless the vbmeta ticket's evidence demands footers (`BRINGUP-M1-PLAN.md:360-361`; `docs/research/vbmeta-avb.md` §4: footers only for a chain descriptor, and only on `boot_b`, never a vbmeta write; `docs/research/gpt-exception-prep.md:371-374`) | ticket #10 |
| 73 | `NV_PARTS={{...}}` | [I] candidate Qualcomm NV/calibration names (current `device.conf:72-75`) | stage-0: each name verified against STAGE-0-RUNBOOK D4 `by-name-root.txt` |
| 74-76 | `NV_BACKUP_EXTRA` absent | [V] slot flags are GPT attributes here, and `devinfo` stays out of every list (`docs/research/gpt-exception-prep.md:612-616`) | fixed (dropped) |
| 83 | `INSTALL_KEYS_FASTBOOT={{...}}` | [I] disputed combo: Volume Down + Power vs Volume Up + Volume Down + Power (`BRINGUP-M1-PLAN.md:413-419`) | the owner's first button entry to fastboot (stage-0 phase B at the latest) |
| 84 | `INSTALL_KEYS_RESTART=...` | [I] current `device.conf:82`, unverified | stage 0 / M1a observation |
| 86 | `INSTALL_FREE_GB=25` | [I] rough estimate (current `device.conf:83-84`) | ticket #8 |
| 90 | `INITRAMFS_INIT=/initramfs/init` | [V] current `device.conf:88`; upstream `device/enchilada/device.conf` at `6c11752ae4c3` | fixed |
| 93, 95 | `#SIMPLEFB_TRIG_CON=`, `#BRINGUP_PROBE=` (unset) | [V] upstream rule: never another phone's register address; both stay unset in M1a (`BRINGUP-M1-PLAN.md:329-330`) | much later (panel work) |
| 98 | `PANEL_SIZE=1440x3168` | [V] the Nura image drives this unit's panel at 1440x3168@120 (`NOTES.md:78-82`); §5.9's proposed value (`BRINGUP-M1-PLAN.md:352`) | fixed |

## Changes against the current draft

1. **`COMPATIBLE` corrected.** Was `qcom,sm8250-oneplus-instantnoodlep`;
   the DTS root compatible is `"oneplus,instantnoodlep", "qcom,sm8250"`
   (`BRINGUP-M1-PLAN.md:165-167`).
2. **`devinfo` dropped.** The "devinfo holds the slot flags" comment and
   `NV_BACKUP_EXTRA="devinfo"` are gone: slot flags are GPT attributes,
   and `devinfo` is in no list of ours
   (`docs/research/gpt-exception-prep.md:612-616`).
3. **No `vbmeta` anywhere.** The parked M1b values are
   `BOOT_IMAGES="boot dtbo"` and `UFS_RW="boot_b dtbo_b userdata"`;
   `vbmeta`/`vbmeta_b` wait on ticket #10 (`vbmeta` is on upstream's
   never-flash list; decision input 1 of `docs/research/vbmeta-avb.md`,
   PR #27, says remove them now; `docs/research/gpt-exception-prep.md:371-374`).
4. **`BOOT_METHOD=ram-only` with empty `BOOT_IMAGES` and `UFS_RW`** for
   M1a, as upstream's flame and dipper ram-only descriptors do
   (`BRINGUP-M1-PLAN.md` §5.9).
5. **`UFS_RW_LUNS` added as a parked placeholder** (upstream #530); the
   disk name comes from stage-0 Q10.
6. **Header comment corrected to boot image header v2** (the old draft
   said "expected v3", current `device.conf:52-54`). The v2 geometry and
   cmdline are baked into `tools/build-instantnoodlep-probe`
   (`tools/build-instantnoodlep-probe:45-55`), not the descriptor.
7. **`USB_PRODUCT` dropped.** The draft's value had a typo ("Omamobile
   Mobile"), and upstream defaults the USB product string to `NAME`.
8. **`VENDOR_PAGESIZE` dropped.** Page size is header-v2 geometry, which
   lives in the probe builder, not the descriptor.
