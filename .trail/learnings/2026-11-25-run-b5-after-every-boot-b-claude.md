---
title: "Run B5 after every boot_b flash, or ABL burns slot B's tries and falls back to stock recovery"
author: claude on omabook
date: 2026-11-25
branch: inumineq/b5-after-flash
id: l-bf0ca383
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/NOTES.md
  - tools/instantnoodlep-slot-b-mark
---

## Watch out
- Every `fastboot flash boot_b` clears `slot-successful:b` (NOTES.md
  2026-11-17, Q/FastbootCmds.c:1024-1049). Until B5
  (`tools/instantnoodlep-slot-b-mark`, BRINGUP-M1b-PLAN 5/B5) runs again,
  each Linux boot from boot_b costs one of 7 tries; `fastboot boot` RAM
  boots and fastboot visits cost none.
- 2026-11-25: B5 was skipped after the gmu (11-20) and typec (11-24)
  flashes. A day of hard resets used the 7 tries; ABL set
  `slot-unbootable:b yes`, switched to slot A, and the phone stopped on
  stock recovery's language screen. Nothing on boot_b or userdata changed.
- Recovery (owner go each): fastboot via Power+VolUp+VolDown,
  `fastboot --set-active=b` (retry back to 7, unbootable no), boot, then
  B5 from fresh reads. Do not pick anything in stock recovery.
## Decided
- A boot_b flash block is not done until B5 has run and fastboot reads
  `slot-successful:b: yes`. Put B5 in the same owner go as the flash.
