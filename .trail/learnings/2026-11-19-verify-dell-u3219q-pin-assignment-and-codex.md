---
title: "Verify Dell U3219Q pin assignment and test static UTMI independently"
author: codex worker
date: 2026-11-19
branch: inumineq/usbc-dock
id: l-26d5d710
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/TYPEC-DP-PLAN.md
---

## Watch out
- [V: Dell U3219Q User's Guide pp. 14, 59 and 68] This model documents USB2 data over USB-C and automatic hub routing for USB-C video. Verify the actual pin assignment and OSD before treating a monitor setting as a two-lane control.
- [V: NOTES 2026-11-19] Fix1 displayed DP and charged, but no receiver input or gadget recovery within 60 s. [I] Test fix2 independently with a capture transport that survives a USB role swap before choosing another kernel delta.
