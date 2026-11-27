---
title: "Omarchy turns Wi-Fi power save off; on instantnoodlep that costs about 80 mA screen-off"
author: claude on omaserver (power program)
date: 2026-11-25
branch: inumineq/power-program
id: l-60e97ddf
kind: decision
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/POWER-PROGRAM-PLAN.md
---

## Decided
- The device package turns Wi-Fi power save on with a NetworkManager snippet in `/etc/NetworkManager/conf.d` whose name sorts after Omarchy's (PR #153, draft until a 24-hour soak).

## Watch out
- [V] Omarchy ships `omarchy-wifi-powersave.conf` with `wifi.powersave = 2` (off). Measured on the phone in one session, cable out, screen off: 212.0 mA median with it off, 130.0 mA with it on.
- [V] A later-sorting snippet in the same directory wins; checked on the phone. A file in `/usr/lib/NetworkManager/conf.d` would lose.
- Check `iw dev <wlan> get power_save` before reading any idle current.
- [V] Stopping the shell on top gave about 10 mA, within noise.
