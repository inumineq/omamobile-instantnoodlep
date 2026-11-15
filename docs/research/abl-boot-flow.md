<!-- SPDX-License-Identifier: MIT -->
# Research: Qualcomm ABL boot flow on instantnoodlep

Research date: 2026-11-15. No device was available, so every conclusion about
the stock ABL's runtime choices is marked `[I]` and remains gated on
`docs/STAGE-0.md`.

## Executive result

The public device tree and Android build configuration describe the normal
flow as: Qualcomm ABL selects the active A/B slot, reads a legacy Android boot
image containing the kernel, ramdisk and DTB, applies a separately stored
DTBO, and passes the resulting DT plus a command line to Linux. The strongest
correction to the draft descriptor is that this is boot-image header **v2**,
not v3: the OnePlus 8 Pro launched with Android 10 and Lineage's common
configuration explicitly sets `BOARD_BOOT_HEADER_VERSION := 2`.

## 1. DTBO and `ro.boot.dtbo_idx`

- `[V]` Lineage's SM8250 common BoardConfig declares `BOARD_KERNEL_SEPARATED_DTBO := true`, a 24 MiB DTBO partition, and `dtbo` as an A/B OTA partition. Source: [BoardConfigCommon.mk](https://raw.githubusercontent.com/LineageOS/android_device_oneplus_sm8250-common/lineage-23.2/BoardConfigCommon.mk).
- `[V]` Lineage's instantnoodlep installation guide requires flashing both
  `dtbo.img` and `vbmeta.img` in addition to the normal images. Source:
  [Lineage install guide](https://wiki.lineageos.org/devices/instantnoodlep/install/).
- `[V]` Android's DTO documentation says a DTBO partition is selected by the
  bootloader, applied to the base DT, and reported with
  `androidboot.dtbo_idx`; init exposes that as `ro.boot.dtbo_idx`. Source:
  [AOSP DTO verification](https://source.android.com/docs/core/architecture/dto/compile).
- `[I]` Stock OnePlus ABL applies a board DTBO from `dtbo[_a|_b]` and emits
  `androidboot.dtbo_idx` (therefore `ro.boot.dtbo_idx`). This is highly likely,
  but only the stage-0 property capture plus the live `/proc/device-tree` can
  prove the selected index and resulting overlay.

**Descriptor impact:** leave `DTBO_SOURCE` unset until stage 0 identifies the
stock overlay. The current draft's question at `device.conf:39-44` is correct;
the comment should not be read as proof that a trivial overlay is required.

## 2. Kernel command line versus `/chosen/bootargs`

- `[V]` AOSP documents the effective Linux command line as a concatenation of
  bootloader parameters, `/chosen/bootargs`, `CONFIG_CMDLINE`, and boot-image
  command-line fields. Source: [AOSP bootloader overview](https://source.android.com/docs/core/architecture/bootloader).
- `[V]` The public OnePlus BoardConfig puts the board's required arguments in
  `BOARD_KERNEL_CMDLINE` and passes them to `mkbootimg`; it also includes the
  DTB in the boot image (`BOARD_INCLUDE_DTB_IN_BOOTIMG := true`). Source:
  [BoardConfigCommon.mk](https://raw.githubusercontent.com/LineageOS/android_device_oneplus_sm8250-common/lineage-23.2/BoardConfigCommon.mk).
- `[I]` Qualcomm ABL on this phone is not shown by public sources to ignore
  boot-image cmdline. Unlike the Pixel-specific premise in the upstream
  project, the safe working assumption is that ABL supplies the boot-image
  cmdline and may also preserve/merge `/chosen/bootargs`; do not assume that
  `/chosen/bootargs` replaces the image cmdline.
- `[I]` Stage 0 must compare `/proc/cmdline` with the captured DTB's
  `/chosen/bootargs` and with the stock image header. Until then, put only
  deliberately required arguments in the descriptor and avoid relying on
  duplicate/conflicting values.

**Descriptor impact:** `VENDOR_CMDLINE` at `device.conf:46-49` is a misleading
name for this legacy flow. It is an inference, not evidence that Qualcomm
uses a vendor_boot command-line section. The existing `console=tty0` and
power-management arguments still need comparison with the live stock command
line.

## 3. A/B slot flags: GPT or `devinfo`

- `[V]` Qualcomm's public `qbootctl` defines A/B priority, active, successful,
  unbootable and retry state in GPT attribute bits 48 onward, and explicitly
  excludes XBL because XBL selection is the UFS boot-LUN attribute. Source:
  [linux-msm/qbootctl gpt-utils.h](https://github.com/linux-msm/qbootctl/blob/main/gpt-utils.h).
- `[V]` The Qualcomm boot-control implementation reads and writes GPT
  attributes for the `_a`/`_b` boot partitions. Source: [AOSP Qualcomm
  bootctrl](https://android.googlesource.com/platform/hardware/qcom/bootctrl/+/8d5e2b337916fd8df3175f39e7b56e146a1f8ba3/boot_control.cpp).
- `[V]` The OnePlus/Lineage device configuration is standard Qualcomm A/B and
  lists `boot`, `dtbo`, `vbmeta` and other suffixed partitions, but does not
  document a OnePlus-specific devinfo A/B backend. Source: [BoardConfigCommon.mk](https://raw.githubusercontent.com/LineageOS/android_device_oneplus_sm8250-common/lineage-23.2/BoardConfigCommon.mk).
- `[I]` GPT attributes are the best current model for instantnoodlep slot
  flags; `devinfo` should be treated as unlock/bootloader metadata until the
  phone proves otherwise. Stage 0 must inspect GPT attributes and the
  `devinfo` contents without writing either.

**Descriptor impact:** this contradicts the stronger statement at
`device.conf:71-75` that “devinfo holds the slot flags.” Change that statement
when the descriptor is next edited to “GPT attributes expected; devinfo role
unverified,” and do not put `devinfo` in a write allowlist.

## 4. Header version and image layout

- `[V]` AOSP's boot-image specification says Android 10 devices must use boot
  image header version 2; version 3 is the Android 11 format and moves the DTB
  into `vendor_boot`. Source: [AOSP boot image header](https://source.android.com/docs/core/architecture/bootloader/boot-image-header).
- `[V]` The OnePlus SM8250 BoardConfig sets
  `BOARD_BOOT_HEADER_VERSION := 2`, `BOARD_KERNEL_PAGESIZE := 4096`, includes
  the DTB in `boot.img`, and uses a separated DTBO image. Source:
  [BoardConfigCommon.mk](https://raw.githubusercontent.com/LineageOS/android_device_oneplus_sm8250-common/lineage-23.2/BoardConfigCommon.mk).
- `[V]` The Lineage device metadata identifies the device as released in April
  2020 and shipping Android 10-era hardware; current firmware may be Android
  13 or later, but that does not change the original boot layout. Source:
  [Lineage device metadata](https://github.com/LineageOS/lineage_wiki/blob/main/_data/devices/instantnoodlep.yml).
- `[I]` The stock OnePlus 8 Pro flow therefore uses `boot` (header v2 with
  kernel, ramdisk and DTB), separate `dtbo`, and AVB metadata (`vbmeta`, with
  `vbmeta_system` possible in later software). It does not use
  `init_boot`, `vendor_boot`, or `vendor_kernel_boot` in the legacy layout.
  Stage 0 `fastboot getvar all` and OTA extraction must confirm the exact
  installed release.

**Descriptor impact:** the expectation at `device.conf:50-55` is wrong only in
  its “v3” wording. Set the expected header to v2 after stage 0 confirms the
  stock image; retain the no-`vendor_boot` expectation as `[I]` until then.

## 5. earlycon UART

- `[V]` The SM8250 upstream DTS defines the debug GENI UART `uart12` at
  `0x00a90000`, compatible `qcom,geni-debug-uart`; the node is disabled by
  default in the SoC DTS. Source: [upstream sm8250.dtsi](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sm8250.dtsi).
- `[V]` The OnePlus SM8250 common DTS used by current upstream work aliases
  `serial0` to `uart12` and sets `stdout-path = "serial0:115200n8"`. Source:
  [upstream OnePlus common DTS patch](https://lkml.iu.edu/2610.2/06441.html).
- `[I]` `0x00a90000` is the candidate earlycon base for instantnoodlep,
  probably with the GENI earlycon and 115200n8. It is not safe to make this a
  descriptor fact: OnePlus's stock live DT and board pin routing must be
  checked first.

Stage 0 must read the live DT `stdout-path`, resolve its UART node's
`reg`, and compare `/proc/cmdline` before any UART argument is shipped.

## 6. Unlocking and AVB

- `[V]` AOSP describes bootloader verification of boot and related partitions
  as part of the boot flow. Source: [AOSP bootloader overview](https://source.android.com/docs/core/architecture/bootloader).
- `[V]` Lineage still builds AVB metadata for this device and explicitly adds
  `--set_hashtree_disabled_flag` and `--set_verification_disabled_flag` to
  its generated vbmeta image. Source: [BoardConfigCommon.mk](https://raw.githubusercontent.com/LineageOS/android_device_oneplus_sm8250-common/lineage-23.2/BoardConfigCommon.mk).
- `[V]` The official Lineage install procedure for instantnoodlep requires
  flashing `vbmeta.img` as an additional partition after unlocking. Source:
  [Lineage install guide](https://wiki.lineageos.org/devices/instantnoodlep/install/).
- `[I]` `fastboot oem unlock` changes the device state so custom images can be
  accepted, but it does **not** establish that AVB verification is skipped
  entirely. ABL may still verify vbmeta and chained descriptors, and unlocked
  booting does not make an arbitrary vbmeta write unnecessary. Ship/flash
  vbmeta only according to the tested image chain, never on the assumption
  that unlock alone disables AVB.

## Stage-0 gates still open

The following remain device facts, not source-derived facts: selected DTBO
index and merged nodes; effective cmdline and `/chosen/bootargs`; GPT versus
any devinfo A/B record; exact installed partition set; exact live UART
`stdout-path` and `reg`; and the unlocked ABL's actual AVB error/acceptance
behaviour. The commands and stop conditions are already specified in
`docs/STAGE-0.md`.
