---
title: "Stop the charge watch by its PID file, never pkill -f over ssh"
author: claude on omabook
date: 2026-11-17
branch: inumineq/power
id: l-e0d28b0a
kind: lesson
scope: repo
status: active
src: agent
touches:
  - tools/instantnoodlep-charge-watch
  - device/instantnoodlep/POWER-M5-PLAN.md
---

## Watch out
- `pkill -f instantnoodlep-charge-watch` run over an ssh shell also matches the ssh session's own shell that runs the pkill (its command line contains the pattern) and kills the session mid-step [V: POWER-M5-PLAN §7.4 P2-9 fix, §7.5 P2b-6].
- `tools/instantnoodlep-charge-watch` therefore writes its PID to `/root/charge-watch.pid` on start; stop it with `kill "$(cat /root/charge-watch.pid)"`, and stop helper loops (`dmesg -w`, the periodic `sync` loop) by the PIDs from `pgrep -f`, one `kill` per PID — never `pkill -f` from the ssh shell.
