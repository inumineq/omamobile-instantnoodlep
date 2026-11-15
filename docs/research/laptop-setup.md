<!-- SPDX-License-Identifier: MIT -->
# Laptop Build Setup: instantnoodlep

> **Coordinator review, 2026-11-15.** Worker notes for the research ticket
> "Laptop build setup for a Qualcomm boot-v3 device", landed as written apart
> from this block. Corrections:
>
> - [V] **Read "boot-v3" below as "legacy header, v2 expected".**
>   `abl-boot-flow.md` §4 shows the OnePlus SM8250 build config uses
>   `BOARD_BOOT_HEADER_VERSION := 2` with the DTB inside `boot.img` and a
>   separate `dtbo`. The `mkbootimg --header_version 3` row is wrong for this
>   phone. Header v2 takes `--dtb`, and stage 0's offline unpack of stock
>   `boot.img` confirms the version and page size.
> - [V] The worker's safety finding stands and is important: the draft
>   `device.conf` lists `vbmeta` in `BOOT_IMAGES` and `vbmeta_b` in `UFS_RW`.
>   That conflicts with the upstream safety model (never `vbmeta`). It is
>   carried to the vbmeta and device.conf grilling tickets. No tool reads the
>   draft yet (`device.conf:9-11`).
> - [V] `BOOT_METHOD` is missing from the draft. Upstream accepts `android-v4`,
>   `android-v0`, `qcom-abl` (`bin/omamobile:125-127`). [I] A header-v2
>   method is a maintainer conversation, not a local invention.

Research draft for `docs/LAPTOP-SETUP.md`, based on upstream
`derekross/omarchy-mobile` at the checkout used for this ticket and the local
instantnoodlep draft. This is a laptop-only checklist; no phone commands are
run here. Every row is marked `[V]` when the requirement is stated or checked
in a source, and `[I]` when it is a Qualcomm/OnePlus proposal that must be
confirmed by Stage 0.

## Checklist

| Requirement | Command | Expect / Pass | Qualcomm delta for boot-v3 + separate dtbo | Evidence |
| --- | --- | --- | --- | --- |
| [V] Linux host and container | `docker info`; `docker build --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" -t omamobile-build:24.04 docker` | Docker responds; image builds from Ubuntu 24.04. | None. The Qualcomm path still uses the same kernel container. | Upstream `CONTRIBUTING.md:42`; `docker/Dockerfile:1-25`. |
| [V] Host command-line tools | `command -v adb fastboot lz4 zstd cpio python3 ssh unzip debugfs simg2img lpunpack`; `command -v mkbootimg` is useful but not assumed | Every required command resolves. `debugfs` comes from `e2fsprogs`; `simg2img`/`lpunpack` and `erofs-utils` are needed for firmware extraction. | `adb`/`fastboot` remain useful for capture and install, but image construction must not assume Pixel partitions or Pixel fastboot behavior. | Upstream `CONTRIBUTING.md:43`; upstream `docker/Dockerfile:6-16`. |
| [V] Android clang | `test -x "$CLANG_DIR/bin/clang"; "$CLANG_DIR/bin/clang" --version` | Clang runs and reports its Android toolchain version. `bin/omamobile kernel` accepts it and mounts it read-only into the container. | Use the same clang for kernel and initramfs helper binaries; no Qualcomm compiler is implied by the SoC. | Upstream `CONTRIBUTING.md:44`; upstream `bin/omamobile:39-49,337-365,764-815`. |
| [V] AOSP image tools | `test -f "$SRC_DIR/system/tools/mkbootimg/mkbootimg.py"; test -f "$SRC_DIR/system/libufdt/utils/src/mkdtboimg.py"` | Both Python tools exist, or the pinned toolchain equivalents are present. | `mkbootimg.py` must support header version 3. `mkdtboimg.py` remains needed for a separate `dtbo.img`; its board id/revision and page size must come from Stage 0, not Pixel values. | Upstream `CONTRIBUTING.md:44`; upstream `bin/omamobile:48-56,875-880,1044-1052`. |
| [V] Optional AVB tool, only if required | `test -f "$SRC_DIR/external/avb/avbtool.py"` and inspect stock `vbmeta` descriptors with the owner's offline copy | Pass only if stock `vbmeta_b` chains the images as hash/chain descriptors requiring the corresponding footer policy. Record rollback index and security patch from stock. | `AVB_FOOTERS` is not Pixel-only: it is conditional on how `vbmeta` verifies the named image. Do not set it merely because the phone is Qualcomm; for instantnoodlep leave unset until `vbmeta` evidence says a footer is required. Never write `vbmeta`. | Upstream `docs/RELEASES.md:78-79,189-190`; upstream `bin/omamobile:216-237,1084-1093`; local `device/instantnoodlep/device.conf:57-60`. |
| [V] Kernel source checkout | `git clone https://github.com/derekross/linux-omarchy-mobile.git ~/omamobile-kernel/linux; git -C ~/omamobile-kernel/linux switch omamobile` | Checkout exists at `~/omamobile-kernel/linux` on published `omamobile`, or `KERNEL_DIR` points at an equivalent checkout. | Port the SM8250 board DTS in this tree; do not put DTS in this repository. The local draft's `DTB=qcom/sm8250-oneplus-instantnoodlep.dtb` is a path proposal, not a verified tree path. | Upstream `CONTRIBUTING.md:45`; upstream `CONTRIBUTING.md:218-219`; local `device/instantnoodlep/device.conf:29-33`. |
| [V] Isolated worktree and output | `KERNEL_DIR=~/omamobile-kernel/wt-instantnoodlep KERNEL_OUT=~/omamobile-kernel/out-instantnoodlep DEVICE=instantnoodlep bin/omamobile kernel` | Build uses the intended worktree and writes only to its matching output directory. | Keep one worktree/output pair per subsystem branch. Never share `KERNEL_OUT` between DTS, driver, or bring-up builds. Older setups may use `~/android/mainline`; do not mix old and new output directories. | Upstream `AGENTS.md:36,42`; upstream `CONTRIBUTING.md:167`; upstream `bin/omamobile:11-18,337-365`. |
| [V] Shared settings and local overrides | `grep -E '^(SRC_DIR|JOBS|IMAGE|DEVICE)=' omamobile.conf; test -f omamobile.local.conf || true` | `DEVICE=instantnoodlep` is supplied per command or in ignored `omamobile.local.conf`; `SRC_DIR`, `JOBS`, and `IMAGE` are intentional. | Set `SRC_DIR` to a small AOSP checkout containing clang/tools if not using the large Lineage checkout. `CLANG_DIR`, `MKBOOTIMG_DIR`, `MKDTBOIMG`, `AVBTOOL`, and `AVB_KEY` may override individual paths. | Upstream `omamobile.conf:7-26`; upstream `bin/omamobile:22-56`; local `device/instantnoodlep/device.conf:1-11`. |
| [V] Kernel build inputs | `DEVICE=instantnoodlep KERNEL_DIR=... KERNEL_OUT=... bin/omamobile kernel`; then `... bin/omamobile modules` | `Image`/DTBs/modules are listed; `modules-<release>.tar.zst` exists. | The Qualcomm DTB must be built in the arm64 kernel tree and selected by its descriptor path. Validate the DTS compatible against the live DT in Stage 0; do not infer it from the marketing name. | Upstream `CONTRIBUTING.md:140-144`; upstream `bin/omamobile:356-365,393-400`; local `device/instantnoodlep/device.conf:19-22,29-33`. |
| [I] Qualcomm descriptor method | `DEVICE=instantnoodlep bin/omamobile images` after adding the Qualcomm descriptor fields in the eventual implementation | A dry/offline descriptor validation accepts `BOOT_METHOD` for Qualcomm header-v3, `BOOT_IMAGES="boot dtbo"`, and `UFS_RW="boot_b dtbo_b userdata"`; no Pixel-only required key is demanded. | Current upstream accepts `android-v4`, `android-v0`, and `qcom-abl`; `qcom-abl` is a two-stage **header-v4** chainloader and is not the desired direct boot-v3 layout. Current `android-v4` requires `boot`, `vendor_boot`, and `dtbo`. Add a dedicated direct-v3 path rather than reusing either branch. | Upstream `bin/omamobile:113-126,169-194,925-972`; upstream `docs/RELEASES.md:80-84`; local draft lacks `BOOT_METHOD` and currently has `BOOT_IMAGES="boot dtbo vbmeta"` at lines 52-69. |
| [I] Direct boot-v3 image construction | `python3 "$MKBOOTIMG_DIR/mkbootimg.py" --header_version 3 --kernel "$KERNEL_OUT/arch/arm64/boot/Image.lz4" --ramdisk "$KERNEL_OUT/initramfs.cpio.lz4" --cmdline '<Stage-0 cmdline>' --os_version '<stock>' --os_patch_level '<stock>' --output "$KERNEL_OUT/images/boot.img"` | `mkbootimg` completes; an offline header-info inspection reports version 3 and the expected kernel/ramdisk sizes. Confirm exact accepted arguments with the selected AOSP tool and stock `boot.img` before first phone use. | Header-v3 direct layout: `boot.img` carries kernel and ramdisk; there is no `init_boot`, `vendor_boot`, or `vendor_kernel_boot` in the proposed device model. Do not pass Pixel `--vendor_cmdline`, vendor ramdisk, or vendor DTB arguments. Whether cmdline is in `boot.img` or `/chosen/bootargs` must follow the live Qualcomm boot chain; the local plan currently prefers the DTB `/chosen/bootargs`. | `[I]`: local `device/instantnoodlep/device.conf:46-55`; local `docs/STAGE-0.md:44-52`; contrast upstream v4 commands `bin/omamobile:1054-1083` and upstream `AGENTS.md:168`. |
| [I] Separate dtbo image | `python3 "$MKDTBOIMG" create "$KERNEL_OUT/images/dtbo.img" --page_size=<Stage-0> --id=<Stage-0> --rev=<Stage-0> <compiled-overlay.dtbo>` | `dtbo.img` is produced and its metadata matches the stock device's `dtbo` format; compile with the kernel `dtc` and retain no guessed board ids. | Ship/flash `dtbo_b` separately from `boot_b`. Qualcomm ABL may apply it by board metadata, but this is not Pixel `/soc_id` selection. `SOC_IDS` should remain unset unless the live bootloader proves it uses that mechanism. | `[I]`: local `device/instantnoodlep/device.conf:29-43`; local `docs/STAGE-0.md:44-50`; upstream generic dtbo construction `bin/omamobile:1044-1052`; upstream Pixel selection description `docs/RELEASES.md:71-74`. |
| [V] Image and storage safety gate | `DEVICE=instantnoodlep bin/omamobile initramfs-config "$KERNEL_OUT/initramfs-config"`; inspect `BOOT_IMAGES`, `UFS_RW`, then run the future installer dry-run | Pass only when the allowlist contains exactly the intended slot-B boot images plus `userdata`; stop on any `_a`, `super`, `vbmeta`, radio, or calibration partition. | The local draft currently includes `vbmeta` in `BOOT_IMAGES` and `vbmeta_b` in `UFS_RW`; remove both unless a separately approved future design changes the safety model. `dtbo_b` is allowed; `boot_b` is required. | Upstream `CONTRIBUTING.md:58-60,83-93`; upstream `docs/RELEASES.md:84,181-192`; local `device/instantnoodlep/device.conf:64-69`. |
| [V] Host USB networking for later bring-up | `nmcli connection modify '<profile>' ipv4.addresses 172.16.42.2/24` (owner-run only when hardware is available) | Host has `172.16.42.2/24` on the phone USB interface; this row is not a laptop build prerequisite for offline images. | No Pixel-specific delta, but the Qualcomm device must prove its USB gadget mode and recovery behavior before relying on SSH. | Upstream `CONTRIBUTING.md:47`; local `device/instantnoodlep/BRINGUP-M1-PLAN.md:15-19,68-77`. |

## Conclusions and Gated Follow-ups

1. [V] The minimum laptop is Linux with Docker, the listed host tools, an
   Android clang, AOSP `mkbootimg`/`mkdtboimg.py`, and the kernel checkout;
   the full Lineage checkout is optional because upstream documents a smaller
   AOSP-tools checkout (`CONTRIBUTING.md:44`).
2. [V] Kernel work belongs in `linux-omarchy-mobile`; this repository holds
   the device descriptor, notes, and bring-up overlays (`CONTRIBUTING.md:45`,
   `CONTRIBUTING.md:6.1`).
3. [I] The descriptor must be extended with a direct Qualcomm boot-v3 method
   and must not copy Pixel `SOC_IDS`, `VENDOR_CMDLINE`, vendor image keys, or
   `AVB_FOOTERS` without Stage-0 evidence.
4. [I] Before implementation, Stage 0 must capture boot header version,
   page size, exact `dtbo` metadata, partition names/sizes, live DT
   compatible/cmdline, `ro.boot.dtbo_idx`, and `vbmeta` descriptor behavior.
   The existing gated collection is read-only until the unlock step
   (`docs/STAGE-0.md:11-25,42-52`).
5. [I] The first implementation test should be offline: descriptor validation,
   direct v3 `boot.img` header inspection, `dtbo.img` metadata inspection,
   and a dry-run proving only `boot_b`, `dtbo_b`, and `userdata` could be
   written. No hardware command is authorized by this note.
