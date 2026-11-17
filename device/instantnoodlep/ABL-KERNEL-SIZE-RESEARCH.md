<!-- SPDX-License-Identifier: MIT -->
# ABL kernel image size on instantnoodlep

Research date: 2026-11-17. No handset access was used for this research.

Evidence marks: **[V]** means directly checked in a cited source or repository
file. **[I]** means an explanation that still needs confirmation against
OnePlus's closed ABL or a runtime memory map. The ABL sources below are public
Qualcomm/CodeLinaro sources; they are not OnePlus's ABL binary or source.

## Finding

- [V] On the tested boot-image configuration, an arm64 `Image` with
  `image_size = 0x2b60000` boots; images with `image_size = 0x2b70000` and
  `0x2cd0000` stop at the fastboot splash without USB or logs, with a colour
  glitch at the screen top. This is the reported handset observation, not
  source-code evidence.
- [V] The generic Kona-era ABL source has a decompressed-image guard. For a
  gzip kernel it decompresses at `KernelLoadAddr` into a buffer ending at
  `DeviceTreeLoadAddr`, then rejects the arm64 `Image` if its header
  `image_size` exceeds `DeviceTreeLoadAddr - KernelLoadAddr`
  ([`BootLinux.c`, lines 641-671 and 706-717](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/BootLinux.c)).
- [I] The observed inclusive ceiling is therefore `0x2b60000` bytes in this
  device/configuration, and the next tested 64 KiB step is over it. It is
  consistent with the OnePlus ABL's runtime kernel reservation and its
  ramdisk/DTB staging space. The public source does not establish that the
  OnePlus ABL uses this exact value: its runtime `KernelBaseAddr` and
  `KernelSize` UEFI variables and OnePlus-specific PCDs have not been read.

## What the public ABL does

The source pin is CodeLinaro `clo/la/abl/tianocore/edk2`, branch
`LA.UM.11.2.1.c25`, commit
[`ecb3d1713bbb669ece4d9a0de71b266b2c1ca1f6`](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/commit/ecb3d1713bbb669ece4d9a0de71b266b2c1ca1f6), a public SM8250/Kona-era ABL source tree.

- [V] `UpdateBootParams()` first reads UEFI variables `KernelBaseAddr` and
  `KernelSize`. When present, these define the base and end of the reserved
  kernel region; the 64-bit load address adds `KERNEL_64BIT_LOAD_OFFSET`
  (`0x80000`). If the variables are absent, the public fallback uses PCDs
  `KernelLoadAddress = 0x00080000` and `RamdiskEndAddress = 0x05600000`
  ([`BootLinux.c`, lines 119-207](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/BootLinux.c),
  [`BootLinux.h`, lines 91-96](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Include/Library/BootLinux.h),
  [`QcomModulePkg.dec`, lines 157-167](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/QcomModulePkg.dec)).
- [V] The ramdisk and DTB slots are placed downwards from
  `KernelEndAddr`: ramdisk starts at `KernelEndAddr -
  round_page(ramdisk_size + page_size)`; the DTB slot starts 2 MiB plus one
  page below the ramdisk. This is calculated in [`BootLinux.c`, lines
  187-204](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/BootLinux.c).
- [V] For a gzip kernel, `decompress()` writes to `KernelLoadAddr` with output
  capacity `DeviceTreeLoadAddr - KernelLoadAddr`. After decompression, ABL
  reads the arm64 Image header and rejects it when `ImageSize` is larger than
  that gap ([`BootLinux.c`, lines 641-671 and 706-717](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/BootLinux.c)).
- [V] For boot header v2, ABL uses the header's page size and component sizes
  to locate the kernel, ramdisk and appended DTB within the boot image. It
  copies the selected DTB into the separately calculated `DeviceTreeLoadAddr`
  ([`BootLinux.c`, lines 981-1016](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/BootLinux.c),
  [`LocateDeviceTree.c`, lines 395-530](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/blob/LA.UM.11.2.1.c25/QcomModulePkg/Library/BootLib/LocateDeviceTree.c)). The boot header's kernel, ramdisk and DTB *address* fields are not these destinations; `mkbootimg` offsets describe packed file layout.
- [V] The public source has no `KERNEL_SIZE_RESERVED` constant. The effective
  bound comes from the runtime `KernelSize` reservation (or fallback PCD),
  less the actual ramdisk staging space, 2 MiB plus one page for DTB staging,
  and the `0x80000` arm64 load offset. `image_size` is the uncompressed
  kernel's declared size; the compressed `Image.gz` byte count is not the
  relevant limit.

## Comparison with this board's memory map

- [V] The port's board inventory records `removed_mem` at
  `0x80b00000` length `0x0cd00000`, then firmware carve-outs through
  `cdsp_secure_heap` at `0x94100000` length 70 MiB. It records the continuous
  splash reservation at `0x9c000000` length `0x02300000`, `no-map`, and a
  simple-framebuffer beginning at `0x9c000000` ([`DTS-PORT-PLAN.md`, lines
  68-87 and 225-236](DTS-PORT-PLAN.md)). The camera patch retains the board's
  `removed_mem` range ([`0003...patch`, lines 42-47](patches/camera/0003-arm64-dts-qcom-instantnoodlep-Enable-the-front-camer.patch)).
- [V] These DTS ranges describe memory reserved for Linux and devices. They
  are not evidence of the ABL's runtime kernel staging addresses. The port
  itself marks OnePlus's ABL region values [I] in
  [`tools/build-instantnoodlep-probe`, lines 90-97](../../tools/build-instantnoodlep-probe).
- [I] It cannot be established from the checked files whether adding
  `0x2b60000` to the actual `KernelLoadAddr` crosses `removed_mem`, the splash
  region, another carve-out, or none of them. The required start address and
  ABL memory reservation are not in the header-v2 offsets or the Linux DTS.
  The screen splash is at `0x9c000000`; no overlap follows from image size
  alone. Treating it as the cause would be speculation.
- [I] ABL's explicit arm64 size guard gives a source-based explanation for
  the abrupt failure threshold: the image exceeds the runtime gap and the
  boot chain does not proceed. The reported silent fastboot-splash behavior
  matches a failure before Linux takes over, but the exact failure path in
  OnePlus's closed ABL is unverified.

## Conclusion and safe options

- [V] The exact observed limit for the tested configuration is
  `image_size <= 0x2b60000`; `0x2b70000` and `0x2cd0000` are over it. The
  public ABL's exact guard is `ImageSize <= DeviceTreeLoadAddr -
  KernelLoadAddr`, with the DTB destination derived from the configured
  reserved-region end and ramdisk size.
- [I] With the current ABL and boot layout, plan against `0x2b60000` as a
  hard maximum, preferably with margin. Neither `TEXT_OFFSET`/`Image` load
  metadata, `RANDOMIZE_BASE`, nor changing `mkbootimg` component offsets moves
  the ABL's decompression destination or increases its checked output gap.
  DTS memory-layout edits take effect after Linux starts and cannot safely
  enlarge a closed bootloader's reservation.
- [I] A larger kernel could only be made safe by changing the ABL/platform's
  reserved kernel region and staging layout, while proving it avoids all
  firmware and framebuffer carve-outs and preserving the DTB/ramdisk slots.
  That requires OnePlus ABL/platform evidence and is not available here.
  Until then, shrinking the decompressed `Image` below the observed cap is
  the only supported option; do not move the load address or trim a DTS
  reservation as a workaround.
