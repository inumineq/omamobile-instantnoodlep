---
title: "Hyprland renders on llvmpipe: the omamobile Mesa has no freedreno"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-405b6773
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DISPLAY-M3-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Watch out
- The GPU works in the kernel (A650, `gpu-initialized: 1`, zap `a650_zap.mbn` from the owner's OTA, GMU fw v2.1.8) and ALARM's stock Mesa renders on it (`OpenGL renderer: FD650`) [V: NOTES 2026-11-17 early morning].
- But the omamobile Mesa package builds Gallium `panfrost,llvmpipe,softpipe,zink` only (upstream `packages/mesa/PKGBUILD:168`), so Hyprland runs on llvmpipe, with `LIBGL_ALWAYS_SOFTWARE=1` set [V: NOTES 2026-11-17; laptop session 2026-11-17].
- Do not `pacman -Syu` against upstream's channel to get a Mesa: the image is a `--channel local` build and mixing in upstream packages breaks that (NOTES 2026-11-17 night).

## Decided
- A Mesa build with freedreno (and Turnip) runs as the `gpu-mesa` worker on macbookpro. Whether upstream's Mesa should enable freedreno is an upstream decision; propose, do not fork silently.
