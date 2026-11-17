---
title: "The shell is Hyprland's child, not a systemd unit; restart it with omarchy-restart-shell"
author: claude on macbookpro
date: 2026-11-17
branch: inumineq/shell-pkg
id: l-7cf2b6a8
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/SHELL-UX-PLAN.md
  - patches
  - device/instantnoodlep/tools
---

## Decided
- [V] No systemd user unit runs the shell: `omamobile-shell` 0.2.133-1 ships none that runs it, and `omarchy` 4.5.0-3 (sha256 d367067c…, the version `rootfs/packages.pinned` holds) has no shell unit either. `omarchy-restart-shell` kills `quickshell -p /usr/share/omarchy/shell` and re-spawns `omarchy-launch-shell` through `hyprctl dispatch 'hl.dsp.exec_cmd(...)'`, waits for `omarchy-shell shell ping`, and refuses while the session is locked. That is the restart command for every shell test.
- [V] Because the shell is Hyprland's child, `systemctl --user set-environment` never reaches it. Set the shell's environment in the compositor instead: `hyprctl eval 'hl.env("NAME", "value")'` (Hyprland 0.57's `hl.env` is `setenv` in the compositor, and `hyprctl eval` runs Lua in the same state), then restart the shell. `omarchy-shell` needs `OMARCHY_PATH=/usr/share/omarchy` when called from outside the session.

## Watch out
- [V] Patch 0002 alone makes `test/back-surfaces.py` fail ("WifiPanel.qml registers with Back but isn't tested here"), so the package's own `check()` cannot pass. `patches/0003-back-surfaces-test-wifi-picker.patch` is the missing test entry; it belongs in the upstream PR with 0002.
- [I] A pkgrel bump (0.2.133-1.1) outranks the released 0.2.133-1, so the phone keeps the patched build through `omarchy update` until upstream releases 0.2.134. Roll back explicitly after the gesture session.
