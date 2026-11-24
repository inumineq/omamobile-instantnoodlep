---
title: "Boot-time tools must not gate on the wall clock: the phone reads 1970 until time sync"
author: claude on omaserver (power program)
date: 2026-11-25
branch: inumineq/power-program
id: l-7ae43b44
kind: lesson
scope: repo
status: active
src: agent
touches:
  - tools
  - docs/runbooks
---

## Watch out
- [V] Early in boot the phone's clock reads January 1970: the PMIC clock has no offset, and systemd's saved clock is not applied before early units run.
- [V] A trace tool that accepted its arming file only when it was less than 30 minutes old refused its own arming, and a test run was lost.
- Use uptime for durations, and a marker file that a unit removes on the next normal boot instead of an expiry time. Test with a 1970 time stamp.
