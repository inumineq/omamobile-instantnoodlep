---
title: "Kernel image_size above 0x2b60000 hangs ABL boot"
author: claude on omabook
date: 2026-11-17
branch: inumineq/kernel-size
id: l-a049fba1
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/KERNEL-SIZE.md
  - device/instantnoodlep/kernel-slim.config
  - device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md
---

## Watch out
- On instantnoodlep every kernel with arm64 header image_size (offset 0x10, `od -An -tx8 -j16 -N8 Image`) above 0x2b60000 hangs in ABL at the fastboot splash: no USB, no logs, a colour glitch at the top [V: P2 charger 0x2b70000, front-camera 0x2cd0000 vs combo/P1/daily 0x2b60000 which boot]. The public CodeLinaro ABL guard is `ImageSize <= DeviceTreeLoadAddr - KernelLoadAddr` [V: LA.UM.11.2.1.c25 BootLinux.c:641-671,706-717; LA.UM.9.12 SMxx50 tag BootLinux.c:710-715]; header-v2 mkbootimg offsets are file layout and do not move it [V: ABL-KERNEL-SIZE-RESEARCH.md].
- Plan every kernel against image_size <= 0x2b60000, preferably <= 0x2560000 (6 MiB margin); verify offline with `od -An -tx8 -j16 -N8 Image` before any RAM boot. image_size includes .bss and is larger than the Image file bytes.
- Slimming levers that work: turn off =y symbols the SM8250 phone never uses (all ARCH_* but QCOM, KALLSYMS_ALL, KVM/XEN/ACPI/kexec, unused FS/MTD/ATA/MMC/USB-host/8250/ethernet/HDA-SOF, other-SoC bus drivers) — see device/instantnoodlep/kernel-slim.config. DEBUG_INFO does not affect image_size (non-alloc sections); KASAN/KCSAN were already off.
## Tried and ruled out
- Moving ramdisk/dtb offsets in mkbootimg to dodge the limit: the ABL never reads those header fields [V]; only ramdisk_size shifts the boundary ~1:1.
- Attributing the ceiling to the 0x9c000000 splash framebuffer or a DTS carve-out: not established [I: ABL-KERNEL-SIZE-RESEARCH.md].
