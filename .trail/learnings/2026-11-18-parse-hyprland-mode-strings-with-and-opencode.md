---
title: "Parse Hyprland mode strings with and without Hz"
author: opencode on obsidian
date: 2026-11-18
branch: inumineq/dock-desktop
id: l-655a79d7
kind: lesson
scope: repo
status: active
src: agent
touches:
  - patches/omamobile-settings
  - device/instantnoodlep/DOCK-DESKTOP-PLAN.md
---

## Watch out
- `hyprctl -j monitors all` reports `availableModes` with an `Hz` suffix, while the `hl.monitor` Lua call and the Settings selection use canonical values without it. The mode parser must make the whole suffix optional (`(?:Hz)?`); `Hz?` makes the `H` mandatory and rejects canonical selections. Test both current-mode parsing and applying a selected mode with a fake monitor fixture.
- The Displays fixture now asserts that the current mode is parsed, as well as all listed modes, and runs the set path through the fake `hyprctl eval` command.
- The managed `monitors.lua` block stores a metadata comment followed by each generated `hl.monitor(...)` line. When updating a saved output, parse and validate those pairs rather than treating every line between the markers as metadata; exercise a second mode change in the same fixture.
