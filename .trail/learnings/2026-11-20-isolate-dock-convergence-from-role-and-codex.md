---
title: "Isolate dock convergence from role and lane failures"
author: Codex worker
date: 2026-11-20
branch: inumineq/dual-use
id: l-0229bac3
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DUAL-USE-PLAN.md
---

## Tried and ruled out
- [V] Fix1 alone did not restore Dell receiver input or gadget SSH within 60 seconds (PR #134, November 19 NOTES). It remains a trace comparator for the deferred QMP mux request.
- [V] The U3219Q manual documents USB2 over USB-C and its separate USB3 upstream (pp. 14, 59, 68). [I] Rule out treating a forced two-lane assignment as the Dell USB2 fix. Capture the actual assignment and test static UTMI independently.

## Decided
- [I] Qualify the independent Type-C-only candidate first, then DP/USB/power in RAM. Trigger session reconciliation from Hyprland output topology.
