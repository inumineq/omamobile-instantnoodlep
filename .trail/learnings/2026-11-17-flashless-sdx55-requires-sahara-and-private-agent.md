---
title: "Flashless SDX55 requires Sahara and private state review"
author: agent on obsidian
date: 2026-11-17
branch: modem-impl
id: l-931614ba
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/MODEM-M5-PLAN.md
  - device/instantnoodlep/GNSS-M5-PLAN.md
  - device/instantnoodlep/firmware.map
---

## Decided
- [V: MODEM-M5-DELTA.md §1-3, D/K17:7-10,33-87] The public device implementation uses a flashless-specific PCI profile, endpoint DT property and Sahara image server; generic SDX55 PCI support alone is insufficient evidence for a working modem.
- [V: MODEM-M5-DELTA.md §5, D/modem/install.sh:24-35] DDR training backing is per-unit state in the reference, not an ordinary OTA firmware member. Keep it and EFS/NV out of the ordinary firmware map; proposed correction is a reviewable patch only.
## Watch out
- [I] Safe backing provenance and sync behavior are unresolved release gates. Never copy the reference installer or auto-start its SIM/GNSS/EFS services; no protected partition access is part of the first RAM runbook.
- [I] First approved boot stops at MHI ports and mmcli discovery without a SIM; registration, tracking and RF/data tests need separate owner go.
