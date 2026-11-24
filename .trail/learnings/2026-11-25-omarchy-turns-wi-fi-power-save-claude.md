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

Omarchy ships /etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf with wifi.powersave = 2. Measured on the phone in one session, cable out, screen off: 212.0 mA median with power save off, 130.0 mA with it on. A snippet in the same directory whose name sorts later wins (checked on the phone); files in /usr/lib would lose. Check `iw dev <wlan> get power_save` before reading any idle current. Stopping the shell on top gave about 10 mA, within noise.
