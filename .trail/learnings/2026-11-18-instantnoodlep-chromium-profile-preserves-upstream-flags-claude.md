---
title: "Instantnoodlep Chromium profile preserves upstream flags"
author: claude on omabook
date: 2026-11-18
branch: inumineq/chromium-profile
id: l-39a753ca
kind: decision
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/MOBILE-UX-RESEARCH.md
---

## Decided
- [V: upstream `omamobile-setup-user` at commit `c4623572be1c141d602cf99a83ae0bf9e3eea09c`, lines 313-328 and 350-378] Upstream seeds no-first-run, Pixel 7 Pro mobile UA, device scale, Wayland IME and text-input version 3. The device profile must merge into the user's existing Chromium flags and keep one managed UA/scale/IME/text-input switch rather than duplicate upstream's switches.
- [I] Instantnoodlep model/Android UA, app-specific zoom needs, overlay scrollbar behavior, touch events, pinch and Wayland selection remain provisional until the morning phone survey. Keep optional Chromium switches at `auto` and app scale at `inherit` until measured; use the helper's reset to restore untouched originals.

## Watch out
- [I] User-managed Chromium flags or desktop files can change after package setup. The profile helper refuses to overwrite changed flags on reset and preserves edited launchers; survey changes should be recorded before enabling optional flags.
