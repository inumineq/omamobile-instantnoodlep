<!-- SPDX-License-Identifier: MIT -->
# KERNEL-SIZE: the ABL image_size ceiling and the slim K3 kernel

Finding [V, coordinator 2026-11-17]: every kernel that boots on
instantnoodlep has arm64 header `image_size` (offset 0x10,
`od -An -tx8 -j16 -N8 Image`) of **0x2b60000**; every kernel that hangs
early on the fastboot splash (no USB, no logs, a colour glitch at the
top) is larger. This document carries the evidence, the public-source ABL
rule (detail in `ABL-KERNEL-SIZE-RESEARCH.md`, learning `l-73bad345`),
the slim kernel built against the ceiling, and the gated RAM runbook.

Evidence marks: **[V]** checked with a source or file:line, **[I]**
inference still to confirm on the device or in OnePlus's closed ABL.

## 1. Evidence table [V]

`image_size` read from the built `Image` at offset 16 (arm64
`struct kernel64_hdr.ImageSize`, CodeLinaro
`QcomModulePkg/Include/Library/BootImage.h:298-309`). Boot results from
NOTES and the plans.

| Kernel (build dir) | Image file bytes | image_size | Result |
| --- | --- | --- | --- |
| k1 (`~/android/build/k1`) | 42,072,576 | 0x28f0000 | RAM boot OK (M1a) |
| k2-full (`k2-full`) | 43,260,416 | 0x2a10000 | RAM boot OK (M1b) |
| k3-touch (`k3-touch`) | 43,260,416 | 0x2a10000 | RAM boot OK |
| k3-panel / k3-combo / k3-clean / k3-power (P1) / k3-misc / k3-daily | 44,591,616 | **0x2b60000** | RAM boot OK; combo and daily also from `boot_b` |
| k3-power-p2, k3-power-p2b (P2 charger) | 44,657,152 | **0x2b70000** | hangs at the fastboot splash (no USB, no logs) |
| k3-camera (front IMX471) | 46,135,808 | **0x2cd0000** | hangs at the fastboot splash |

(k3-panel/combo/clean/power/misc/daily have byte-identical Images: the
Wi-Fi/BT/gauge commits since combo are DTS-only.)

The boundary pinned by the evidence: `image_size` **0x2b60000** boots,
**0x2b70000** does not; the true limit is in [0x2b60000, 0x2b70000).
Note `image_size` (0x2b60000 = 45,481,984) is larger than the Image file
(44,591,616): `image_size` counts to `_end` including .bss, which the
file omits. ABL checks the header field, so that is the number that
matters.

## 2. The ABL rule (summary; pins in ABL-KERNEL-SIZE-RESEARCH.md)

Source pins: CodeLinaro `clo/la/abl/tianocore/edk2` —
`LA.UM.11.2.1.c25` (Kona-era, used by ABL-KERNEL-SIZE-RESEARCH.md) and
`LA.UM.9.12.c25-06200-SMxx50.QSSI13c28.0` (SM8250 tag, line numbers below
are from this tag's `QcomModulePkg/Library/BootLib/BootLinux.c`).

- Load addresses are **not** taken from the boot-image header. The
  `kernel_addr`/`ramdisk_addr`/`second_addr`/`dtb_addr` fields
  (`BootImage.h:56-164`) are never read in BootLinux.c; for header v2 the
  DTB is located *in the image file* at
  `page * (1 + kernel_pages + ramdisk_pages + second_pages +
  recovery_dtbo_pages)` [V BootLinux.c:478-491].
- `UpdateBootParams` [V BootLinux.c:139-208]: UEFI variables
  `KernelBaseAddr`/`KernelSize` win if present [V BootLinux.c:120-137,
  152-160], with `KernelLoadAddr += KERNEL_64BIT_LOAD_OFFSET (0x80000)`
  [V BootLinux.h:96]; otherwise PCDs `KernelLoadAddress = 0x00080000`
  [V QcomModulePkg.dec:157] and `RamdiskEndAddress = 0x05600000`
  [V QcomModulePkg.dec:160] give
  `KernelLoadAddr = BaseMemory | 0x80000`,
  `KernelEndAddr = BaseMemory + RamdiskEndAddress` [V BootLinux.c:171-183].
- `RamdiskLoadAddr = KernelEndAddr - (round_page(ramdisk_size +
  vendor_ramdisk_size) + page)` [V BootLinux.c:191-195];
  `DeviceTreeLoadAddr = RamdiskLoadAddr - (DT_SIZE_2MB + page)` with
  `DT_SIZE_2MB` = 2 MiB [V BootLinux.c:197-199; BootLinux.h:93];
  `DeviceTreeLoadAddr <= KernelLoadAddr` fails the boot
  [V BootLinux.c:201-205].
- The kernel-size guard [V BootLinux.c:710-715]: a gzip kernel is
  decompressed to `KernelLoadAddr` with output capped at
  `DeviceTreeLoadAddr - KernelLoadAddr` [V BootLinux.c:642-660], then
  ```c
  if (Kptr->ImageSize > (BootParamlistPtr->DeviceTreeLoadAddr -
                         BootParamlistPtr->KernelLoadAddr)) {
    DEBUG ((EFI_D_ERROR, "DTB header can get corrupted due to runtime kernel size\n"));
    return RETURN_OUT_OF_RESOURCES;
  }
  ```
  i.e. **`image_size` (offset 0x10) ≤ `KernelEndAddr −
  round_page(ramdisk_size + page) − (2 MiB + page) − KernelLoadAddr`**.
  Failing this aborts inside ABL before USB/kernel logs — the observed
  early hang.

### What fits the evidence

- The header offsets in our boot images (base 0, kernel 0x8000, ramdisk
  0x01000000, dtb 0x01f00000 — `boot-daily.manifest.json`) are **packed
  file layout, not load addresses**; the image is not placed at
  base+0x8000 growing into the ramdisk slot. Proof [V]: daily has
  image_size 0x2b60000 ≫ 0x1000000 (the header ramdisk offset) and boots,
  and the pmaports SM8250 kernel (48,228,864 B decompressed) also boots
  with the same header geometry (`docs/research/abl-kernel-size.md` §2).
- **Would moving the ramdisk/dtb offsets in mkbootimg avoid the limit?
  No** [V: the ABL never reads those fields; ABL-KERNEL-SIZE-RESEARCH.md
  "Tried and ruled out"]. Only `ramdisk_size` shifts the boundary, ~1:1.
  With our probe ramdisk (7,867,486 B, page 4096) the subtraction is
  `0x782000 + 0x201000 + 0x80000 = 0xa03000`, so
  `limit = KernelEndAddr − 0xa03000`; the evidence boundary
  [0x2b60000, 0x2b70000) pins the IN2023 ABL's reserved-region end to
  ≈ 0x3563000-0x3573000 from the RAM base [I, arithmetic]. The exact
  PCD/UEFI-variable value in OnePlus's closed fork is not public.

## 3. The slim kernel

Branch `instantnoodlep-k3-slim` in `~/src/l-k3-slim` — a worktree of the
daily tip `78f38a2acc99`, **no source changes**. Config recipe:

```
scripts/kconfig/merge_config.sh -m -O ~/android/build/k3-slim \
    ~/android/build/k3-daily/.config device/instantnoodlep/kernel-slim.config
make O=~/android/build/k3-slim ARCH=arm64 LLVM=1 olddefconfig
```

`device/instantnoodlep/kernel-slim.config` records every change with a
reason (1008 `=y` symbols turned off; `=m` objects stay modules, so only
the loaded Image shrinks):

- `KALLSYMS_ALL` off (`KALLSYMS=y` kept for oops symbols): in daily's
  vmlinux the kallsyms tables in .rodata total 0x298081 + 0xe99c0 +
  0xaf378 + 0xe9c + 0x3f4 ≈ **4.4 MB** [V: `nm --size-sort vmlinux` on
  `~/android/build/k3-daily`]; ALL adds the data symbols on top of the
  text-only tables.
- All `ARCH_*` platforms except `ARCH_QCOM` off (52, listed from
  `arch/arm64/Kconfig.platforms`): kills the mediatek/meson/hisi/
  rockchip/stm32/tegra/exynos/... clk, pinctrl, phy, regulator, mfd, soc,
  UFS and net drivers arm64 defconfig builds in (several MB of .text).
- KVM/VIRTUALIZATION, XEN, ACPI, KEXEC/CRASH_DUMP off.
- Unused filesystems (NFS/ROOT_NFS, squashfs, ubifs, ...), MTD, ATA,
  non-QCOM SCSI/UFS glue, MMC (no SD slot; `SCSI_UFS_QCOM` does not select
  `MMC_QCOM_DML`, drivers/ufs/host/Kconfig), USB host controllers
  (xhci/ehci/ohci/uhci, vendor dwc3), SERIAL_8250, wired ethernet,
  ChromeOS/Google firmware, HDA/SOF audio, other-SoC i2c/spi/regulator/
  mfd/dma/reset/nvmem/leds/soc/clk/phy/pinctrl/gpio/mailbox/irqchip/
  watchdog/thermal drivers, bridge/VLAN/qdiscs.
- `CONFIG_LOCALVERSION="-instantnoodlep-k3-slim"`.
- DEBUG_INFO deliberately left on: it only bloats vmlinux's non-alloc
  debug sections (460 MB vmlinux), never the loaded Image — daily's Image
  file (44.6 MB) is exactly its alloc sections (.text 19.6 + .rodata
  15.1 + .data 5.6 + init/exit) [V: `readelf -SW vmlinux`].

Kept, verified identical to daily in the merged .config: panel/DSI
(DRM_MSM*), s6sy761 touch, GENI i2c/spi/uart + CCI, GPU, ath11k/BT as
modules, bq27411 gauge, dwc3 gadget (NCM/ACM) + QCOM PHYs + Type-C, UFS
(SCSI_UFS_QCOM + QMP UFS PHY + ICE), PCIe/SMMU, MHI/WWAN, CAMSS/IMX471
(`=m` in daily too), and the probe initramfs needs (DEVTMPFS, INITRD,
PSTORE_RAM, QCOM_WDT, PON, PM8941 pwrkey). The merged .config differs
from daily's in 2240 removed lines and 6 added (5 harmless `=y`→`=m`
demotions of orphaned helpers + LOCALVERSION) [V: diff of the two
.config files]. `=y` count drops 3420 → 1856.

## 4. Size budget and offline verification (before any RAM boot)

- Hard ceiling [V]: `image_size` ≤ **0x2b60000**.
- Target for the slim kernel: `image_size` ≤ **0x2560000** (6 MiB margin
  below the ceiling), i.e. ≥ 6,160,384 bytes under 0x2b60000.
- Verify on the build host, no phone needed:
  ```
  od -An -tx8 -j16 -N8 ~/android/build/k3-slim/arch/arm64/boot/Image
  # must print <= 0000000002560000
  stat -c%s .../Image          # file bytes (smaller than image_size: no .bss)
  ```
- Estimate basis [I]: daily's built-in .text by directory (from
  `modules.builtin` + `size`) puts the removed non-QCOM platform drivers
  at ≈ 2.5-3 MB of .text, the removed storage/USB/serial/MMC/MTD/host
  stack at ≈ 2-2.5 MB, KVM/XEN/ACPI/kexec at ≈ 1-1.5 MB, kallsyms ALL at
  ≈ 2 MB of .rodata — total ≈ 7.5-9 MB, i.e. expected `image_size`
  ≈ 0x2500000-0x2700000. The measured value from the actual build is
  recorded in NOTES when the coordinator fetches it.
- Build host (coordinator decision 2026-11-17): the MacBook Pro in Docker
  (volume `k3slim`, `-j10`), same tree `78f38a2acc99` + this .config;
  fetch `Image.gz`, the board dtb and the modules tarball from there.
  Local recipe for reference:
  `nice -n 19 make O=~/android/build/k3-slim ARCH=arm64 LLVM=1 -j6 Image.gz dtbs modules`,
  then `CHECK_DTBS=y` on `qcom/sm8250-oneplus-instantnoodlep.dtb` with the
  dtschema venv, `modules_install` into `modinst/`, `tar.zst` of
  `lib/modules/<rel>/`.

## 5. Gated runbook for the coordinator (RAM boot only)

Roles per AGENTS.md rule 1: the coordinator runs every step; nothing here
writes a partition. No phone access from agents.

0. **Offline gate (laptop)** — after fetching the MBP build outputs:
   `od -An -tx8 -j16 -N8 Image` must be ≤ 0x2560000; `dtbs_check` clean;
   modules tarball present. If `image_size` is still > 0x2560000, do not
   RAM-boot; record the value and pick the next levers (demote more
   `=y` QCOM drivers for other SoCs to `=m`, drop `KALLSYMS` entirely,
   `CC_OPTIMIZE_FOR_SIZE`), rebuild on the MBP.
1. **RAM image** with `tools/build-instantnoodlep-probe`, exact flags of
   the daily manifest (DAILY-K3-PLAN §6 builder inputs):
   ```
   tools/build-instantnoodlep-probe \
     --kernel <k3-slim Image.gz> --dtb <k3-slim sm8250-oneplus-instantnoodlep.dtb> \
     --ssh-key ~/.ssh/omamobile_probe.pub \
     --mkbootimg ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py \
     --omarchy-mobile ~/src/omarchy-mobile \
     --initramfs-root ~/android/build/initramfs-root \
     --stock-overlay ~/android/build/p3/entry16.dtbo \
     --ufdt-apply ~/android/build/ufdt/ufdt_apply_overlay \
     --boot 2 --root userdata --debug-shell \
     --out ~/android/build/k3-slim-ram/boot-slim.img
   ```
   Builder read-back must pass; manifest beside the image.
2. **RAM boot and checks**: run `docs/runbooks/DAILY-K3-RUNBOOK.md`
   **Part R (R0-R9)** with `IMG` = `boot-slim.img`, `MOD` = the slim
   modules tarball, `REL` = `7.3.0-rc6-instantnoodlep-k3-slim-g<sha>`:
   R0 image/module hashes, R1 `fastboot boot` (RAM only), R2 display,
   R3 touch, R4 GPU, R5 Wi-Fi, R6 BT, R7 gauge, R8 regressions, R9 exit.
   Expect exactly the daily results; the slim kernel must not lose any of
   them — that is the point of the keep list in §3.
3. **Stop conditions**: `image_size` > 0x2560000 offline; any R step
   failing that combo/daily passes (panel, touch, GPU, Wi-Fi, BT, gauge,
   UFS, USB); no SSH after 2 min. Rollback: the phone reboots to combo K3
   from `boot_b` (`~/android/build/k3-combo-ram/boot-r3-gpu.img` if a
   re-flash is ever needed, owner-gated). After a refused RAM boot,
   cold-reboot to the bootloader before another `fastboot boot`.
4. Record R1-R9 in `device/instantnoodlep/NOTES.md` ([V], masked). Only
   after all of Part R passes does any Part F (flash `boot_b`) discussion
   start, as a separate owner-gated runbook.

## 6. Open items

- [I] Measured `image_size` of the slim Image (MBP build) — record in
  NOTES; the §4 estimate is not evidence.
- [I] The IN2023 ABL's reserved-region end (≈ 0x3563000-0x3573000 by
  arithmetic) is inferred, not read from the closed ABL.
- The P2 charger (0x2b70000) and camera (0x2cd0000) kernels can be retried
  only after their configs are slimmed under the same ceiling.
