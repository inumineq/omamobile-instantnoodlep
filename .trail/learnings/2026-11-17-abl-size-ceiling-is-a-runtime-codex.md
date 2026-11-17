---
title: "ABL size ceiling is a runtime gap, not the framebuffer reservation"
author: codex
date: 2026-11-17
branch: inumineq/abl-size
id: l-73bad345
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md
  - device/instantnoodlep/DTS-PORT-PLAN.md
  - tools/build-instantnoodlep-probe
---

## Decided
- Treat `0x2b60000` as the tested configuration's inclusive `Image.image_size` ceiling [V: handset observation reported to this task]. The public Kona-era ABL check is decompressed arm64 Image `ImageSize <= DeviceTreeLoadAddr - KernelLoadAddr` [V: CodeLinaro `LA.UM.11.2.1.c25`, `QcomModulePkg/Library/BootLib/BootLinux.c:641-671,706-717`].
- Do not attribute the ceiling to the `0x9c000000` splash framebuffer. The port's board DTS does not establish the OnePlus ABL staging address or its `KernelSize` UEFI variable [I]. See `device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md`.
## Tried and ruled out
- Header-v2 `mkbootimg` component offsets do not set ABL's runtime kernel destination in the public source [V: BootLinux.c:149-207, 981-1016].
## Watch out
- OnePlus ABL is closed and may differ from this public ABL; don't claim the runtime region or an overlap with any DTS carve-out without a runtime map.
