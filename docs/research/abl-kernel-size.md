<!-- SPDX-License-Identifier: MIT -->
# Research: is the builder's 16 MiB kernel guard right? The ABL load model

Ticket: "is the builder's 16 MiB kernel guard right? ABL load model"
(research). Question: `tools/build-instantnoodlep-probe`
`check_image_sizes()` refused the K1 kernel (community 7.2.0-dev, gzip
`Image.gz` 15,314,546 bytes) because kernel + DTB + 2 MiB + one page must
fit in `RAMDISK_OFF - KERNEL_OFF` = 0x1000000 - 0x8000 = 16,744,448 bytes
while K1 needs 17,542,610. The guard came from
`device/instantnoodlep/BRINGUP-M1-PLAN.md` §5.2 citing `Q/`
(Qualcomm reference ABL).

Evidence marks: **[V]** means checked against the cited source.
**[I]** means an inference still to check on instantnoodlep. A statement
about generic Qualcomm ABL is [V] only for that source, never for OnePlus's
closed ABL fork. Research date: 2026-11-16. No device was involved.

Source pins:

- `Q/` = <https://github.com/QRD-Development/abl> @ `6922a8a066a6`
  (shallow-cloned to `/tmp/vibe-abl` for this note, deleted afterwards).
  Line numbers are `QcomModulePkg/Library/BootLib/BootLinux.c` unless named.
- `U/` = <https://github.com/derekross/omarchy-mobile> @ `6c11752ae4c3`.
- `PM/` = <https://gitlab.com/postmarketOS/pmaports> master,
  `device/testing/device-oneplus-{instantnoodlep,kebab}` and
  `device/testing/linux-postmarketos-qcom-sm8250`.

## 1. The Q/ load model, from source

**Are the header's kernel/ramdisk offsets used as-is or relocated?**
Relocated; the addr fields are never read. For header v2, `Q/` reads only
`kernel_size`, `ramdisk_size`, `second_size`, `page_size` and `cmdline`
from the header [V Q/BootLinux.c:876-879]; `kernel_addr`, `ramdisk_addr`
and `dtb_addr` are not referenced anywhere in BootLinux.c. Load addresses
come from `UpdateBootParams` [V Q/BootLinux.c:141-217]: if the UEFI
variables `KernelBaseAddr`/`KernelSize` exist they win
[V Q/BootLinux.c:122-138,155-169]; otherwise the PCDs
`KernelLoadAddress` = 0x00080000 and `RamdiskEndAddress` = 0x05600000
[V Q/BootLinux.c:180-192; QcomModulePkg/QcomModulePkg.dec:157,160] give
`KernelLoadAddr = BaseMemory | 0x80000` and a reserved kernel region of
0x5600000 bytes ending at `KernelEndAddr` [V Q/BootLinux.c:169,191-192].
`BaseMemory` is the smallest RAM-partition base [V
Q/BootLib/Board.c:149-167]. Then [V Q/BootLinux.c:200-209]:

- `RamdiskLoadAddr = KernelEndAddr - round_page(ramdisk_total + page)`
- `DeviceTreeLoadAddr = RamdiskLoadAddr - (DT_SIZE_2MB + page)`
  (`DT_SIZE_2MB` = 2 MiB, [V QcomModulePkg/Include/Library/BootLinux.h:92])

**Is the "Not Enough space" overlap check made against the compressed or
the decompressed kernel size?** Against neither directly: the check
[V Q/BootLinux.c:211-215] is `DeviceTreeLoadAddr <= KernelLoadAddr`, i.e.
it fires when the *ramdisk* plus the 2 MiB + page DTB slot do not fit
below the end of the *reserved* kernel region. The kernel image size is
checked separately, and there against the **decompressed** size: for a
gzip kernel, `GZipPkgCheck` sets the output buffer to
`OutAvaiLen = DeviceTreeLoadAddr - KernelLoadAddr` [V Q/BootLinux.c:652-653],
calls `decompress()` [V Q/BootLinux.c:663-671], and afterwards requires the
decompressed header's `ImageSize <= DeviceTreeLoadAddr - KernelLoadAddr`
[V Q/BootLinux.c:720-726, "DTB header can get corrupted due to runtime
kernel size"]. For a 32-bit kernel the page-rounded file size is checked
against the same region [V Q/BootLinux.c:803-815].

**Where does a gzip kernel get decompressed to, and how big may it be?**
To `KernelLoadAddr`, with the output capped at
`DeviceTreeLoadAddr - KernelLoadAddr` bytes [V Q/BootLinux.c:652-653,
663-671]. `decompress()` additionally refuses when `out_buf_len <= in_len`
[V QcomModulePkg/Library/BootLib/Decompress.c:94-98] and when the output
buffer fills [V Decompress.c:136-140]. With the Q/ default PCDs the
region is `0x5600000 - 0x80000 - round_page(ramdisk + page) - 2 MiB - page`
≈ 84 MiB minus the ramdisk, not 16 MiB.

**Where does the DTB go?** For header v2 the DTB is located *in the image*
at `page * (1 + kernel_pages + ramdisk_pages + second_pages +
recovery_dtbo_pages)` [V Q/BootLinux.c:487-491] and copied to
`DeviceTreeLoadAddr`; after a dtbo overlay it must fit in
`RamdiskLoadAddr - DeviceTreeLoadAddr` = 2 MiB + one page
[V Q/BootLinux.c:400-405].

**What does `fastboot boot` add?** The whole image must fit the fastboot
download buffer: `mNumDataBytes > MaxDownLoadSize` fails the download
[V QcomModulePkg/Library/FastbootLib/FastbootCmds.c:1422-1425] and
`CmdBoot` refuses `MaxDownLoadSize - image < page`
[V FastbootCmds.c:2883-2885]; `MaxDownLoadSize` is the largest allocatable
memory chunk [V FastbootCmds.c:2347-2380,2516]. After that, `CmdBoot` calls
the same `BootLinux()` [V FastbootCmds.c:2894; Q/BootLinux.c:984], so the
flashed-boot and RAM-boot load models are identical.

## 2. Real-world evidence

- [V] `PM/device-oneplus-instantnoodlep/deviceinfo`: mainline header v2,
  page 4096, base 0, kernel 0x00008000, ramdisk 0x01000000, second 0,
  tags 0x00000100, dtb 0x01f00000 — the same geometry the builder writes.
  `device-oneplus-kebab/deviceinfo` has the same offsets.
- [V] `linux-postmarketos-qcom-sm8250` 6.12.0-r0 (postmarketOS v24.12
  aarch64 repo): `boot/vmlinuz` is gzip (magic 1f 8b), 14,448,521 bytes,
  decompressing to 48,228,864 bytes; `sm8250-oneplus-instantnoodlep.dtb`
  is 124,442 bytes. pmaports MR !3990 reports this mainline kernel booting
  on instantnoodlep (framebuffer, touchscreen, wifi, bluetooth, nfc), with
  a header-v2 boot.img in the geometry above. A 48 MB decompressed kernel
  cannot sit below 0x1000000, so on this ABL family the header offsets are
  not load addresses.
- [V] The community 7.2.0 kernel family: Nura unofficial release
  v2026.11.11.2 for instantnoodlep ships
  `linux-postmarketos-qcom-sm8250-7.2.0_git20261010-r79.apk` whose
  `boot/vmlinuz` is 15,194,562 bytes gzip decompressing to 49,020,928
  bytes, `sm8250-oneplus-instantnoodlep.dtb` 147,221 bytes, and a
  29,614,080-byte `boot.img` that boots the IN2023. K1's 15,314,546-byte
  `Image.gz` is the same shape.
- [V] `U/tools/dipper/build-boot.py:17-37` @ `6c11752ae4c3`: dipper
  (MSM8998, header v1, DTB appended to the kernel) has a *measured* kernel
  limit `KERNEL_MAX = 0xF80000` (16,252,928 bytes) just under
  `RAMDISK_OFF - KERNEL_OFF` = 0xFF8000 — that ABL does enforce the header
  gap, which is where the guard's model came from. `U/device/enchilada`
  (SDM845 OnePlus, header v0, gzip kernel + appended DTB) has no kernel
  size limit, only `max-download-size` 805306368 (768 MiB) [V
  U/device/enchilada/NOTES.md:194].

## 3. Conclusion

- [V] In `Q/`, the header's kernel/ramdisk offsets are file-layout fields,
  not load addresses; the "Not Enough space" check is the ramdisk + DTB
  slot vs the reserved kernel region, and the kernel-size check is on the
  **decompressed** image vs the region below the DTB slot. The real
  `fastboot boot` limits on this ABL family are: image ≤ download buffer
  (`max-download-size`; 768 MiB measured on enchilada, [I] for
  instantnoodlep), decompressed kernel ≤ region below the DTB slot
  (Q/ defaults ≈ 84 MiB minus ramdisk), DTB ≤ 2 MiB + one page.
- [I] OnePlus's closed fork: the pmaports and Nura kernels above
  (48-49 MB decompressed, header offsets 0x8000/0x1000000) boot on
  instantnoodlep, so its ABL also relocates; the exact reserved region is
  still unmeasured.
- [V] The builder's old guard compared the **compressed** kernel plus DTB
  against the **header-offset gap** — the wrong quantity on both axes for
  this ABL family. `check_image_sizes()` now checks the decompressed
  kernel + ramdisk + 2 MiB + page against the reserved region
  (`KERNEL_REGION = 0x5600000 - 0x80000`, Q/ default PCDs, [I] for
  OnePlus) and the DTB alone against its 2 MiB + page slot, keeping the
  64 MiB image cap. K1 (15,314,546 gzip → ≈49 MB decompressed) passes.
