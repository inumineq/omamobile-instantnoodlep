---
title: "A stock boot can erase the Arch root on userdata; keep slot B active"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-f3c8caea
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/BRINGUP-M1b-PLAN.md
  - device/instantnoodlep/STORAGE-M2-PLAN.md
  - tools/instantnoodlep-slot-b-mark
---

## Watch out
- One stock boot erased an ext4 `userdata` without anyone choosing anything: stock started from slot A, stopped in recovery, the owner chose only "reboot", and `userdata` read f2fs afterwards [V: BRINGUP-M1b-PLAN §1, NOTES 2026-11-16 night].
- Anything that makes ABL fall back to slot A (unbootable slot B, retry count at 0, a rejected dtbo) puts the root at risk.

## Decided
- Linux lives on slot B as the default boot (M1b), with `boot_b` marked successful by `tools/instantnoodlep-slot-b-mark` (B5). After any write to `boot_b` or a slot change, check `slot-successful:b` and redo B5 if it is cleared (owner-gated write).
