---
title: "Shell edge geometry needs calibration; keep Wi-Fi Back below keyboard and lock"
author: claude on obsidian
date: 2026-11-17
branch: shell-ux
id: l-ecac9b32
kind: lesson
scope: repo
status: active
src: agent
touches:
  - patches
  - docs/upstream
  - device/instantnoodlep/SHELL-UX-PLAN.md
---

## Decided
- [V] Shell proposals are pinned to upstream c4623572be1c141d602cf99a83ae0bf9e3eea09c; keep Wi-Fi at the normal BackLink surface tier so keyboard dismissal remains first (BackLink.js:35-40).

## Watch out
- [I] Corner taps are not a measured touch boundary. Treat the 48/32 logical-pixel device geometry as provisional; verify both edges and mapping at scale 3 before enabling.
- [V] Source shows Wi-Fi Escape depends on focus, but cannot prove the observed failure cause. Do not add above-lock input to the picker or back strips (phone.lua:142-157).
