---
title: "Use upstream phone sleep profile gates for instantnoodlep"
author: codex worker
date: 2026-11-18
branch: inumineq/pm-profile
id: l-ffd65d47
kind: decision
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/PM-PLAN.md
---

## Decided
- [V: derekross/omarchy-mobile at c4623572be1c, `packages/omamobile-shell/bin/omamobile-setup-user:331-341`, `packages/omamobile-shell/systemd/user/omamobile-sleepd.service:4-7`, and `packages/omamobile-shell/bin/omamobile-sleepd:31-36`] Upstream has no generic per-wake-source profile parser. Its existing phone configuration uses `/usr/share/omamobile/auto-sleep-default` as a marker to turn on the user's automatic-sleep toggle once, and reads `OMAMOBILE_SLEEP_AFTER_OFF` from the user systemd environment; the device systemd sleep drop-in selects `MemorySleepMode`.
- Keep the sleep mode and 30-second post-display-off wait in those supported config files, but omit `auto-sleep-default` until instantnoodlep wake routes pass the owner-gated matrix. Individual source enablement remains a gated driver `power/wakeup` setting discovered on the phone; do not add an unconsumed invented profile syntax.

## Watch out
- [I] This device has not demonstrated end-to-end resume on any wake source; selecting s2idle does not itself enable automatic suspend or qualify radio reachability.
