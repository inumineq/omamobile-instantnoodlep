---
title: "The phone only stays off with the USB cable out"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-838f7998
kind: lesson
scope: repo
status: active
src: agent
touches:
  - docs/RESTORE-RUNBOOK.md
  - device/instantnoodlep/POWER-M5-PLAN.md
---

## Watch out
- With the USB cable plugged in, a powered-off phone does not stay off (it comes back up on charger power); it only stays off with the cable out [V: owner, laptop session 2026-11-17].
- So any step that needs the phone off, or a clean button-combo entry into fastboot, starts with "cable out". DTBO-PLAN's D-R already does: cable out, Power+VolUp to force restart, hold VolUp+VolDown, then plug in.
