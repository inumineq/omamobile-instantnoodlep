---
title: "Phone network goes through a reverse SOCKS tunnel; no NTP"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-5c5f509d
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/NOTES.md
---

## Decided
- No sudo on the laptop for networking: the phone reaches the internet through `ssh -N -R 127.0.0.1:1080 root@172.16.42.1`, i.e. `socks5h://127.0.0.1:1080` on the phone [V: NOTES 2026-11-17 night].

## Tried and ruled out
- NetworkManager "shared" mode: needs `dnsmasq` (not installed) and ufw drops forwarding [V: NOTES 2026-11-17 night].

## Watch out
- No UDP, so no NTP, and the RTC comes up wrong on every boot: set the clock over SSH with `date -u -s @$(date -u +%s)` before anything that checks TLS or signatures [V: NOTES 2026-11-17 night].
- The firstboot steps `hardware/qualcomm/dtb-uki.sh` and `firmware.sh` are Windows-on-ARM laptop steps; they must not run on this phone [V: NOTES 2026-11-17 night].
