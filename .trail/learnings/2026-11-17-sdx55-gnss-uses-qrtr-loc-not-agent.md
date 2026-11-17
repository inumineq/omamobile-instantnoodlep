---
title: "SDX55 GNSS uses QRTR LOC, not a mainline GNSS tty"
author: agent on obsidian
date: 2026-11-17
branch: modem-gnss
id: l-74f3a5d1
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/MODEM-M5-PLAN.md
  - device/instantnoodlep/GNSS-M5-PLAN.md
---

## Decided
- [V] The public instantnoodlep GNSS helper discovers LOC service 16 over QRTR, starts tracking, and relays NMEA to a PTY; its README feeds that endpoint to gpsd (`D/modem/sdx55-gnss.py`, `D/modem/README.md`).
- [V] Mainline v7.3-rc6's GNSS Kconfig has UART receiver drivers for MediaTek, SiRF and u-blox plus USB, but no Qualcomm MHI/QRTR LOC driver; the generic SDX55 MHI profile also has no `NMEA` channel (`L/drivers/gnss/Kconfig`, `L/drivers/bus/mhi/host/pci_generic.c`).
- Prefer ModemManager's Location API/GeoClue when the installed SDX55 QRTR plugin exposes LOC. Use one QRTR LOC owner only; a GNSS-to-PTY fallback must not compete with ModemManager. This Arch build's behavior remains [I] until its package gate and owner-run test.

## Watch out
- [V] Public device setup uses a QRTR/TFTP RFS daemon before ModemManager and disables `tqftpserv` (`D/modem/install.sh`). It handles per-device modem data; its storage/source policy is not approved here [I]. Do not copy its installer, expose NV, or access protected modem partitions.
- [V] The current test image has the temporary Kona root-match patch, while stock `dtbo_b` remains installed; do not upstream that patch or retry the rejected neutral DTBO (`docs/agents/state.md`, `DTBO-PLAN §6`, learning `l-48e0c482`).
