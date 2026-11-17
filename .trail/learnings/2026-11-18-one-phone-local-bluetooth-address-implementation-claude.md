---
title: "One phone-local Bluetooth address implementation in device package"
author: claude on omabook
date: 2026-11-18
branch: inumineq/device-consolidation
id: l-453af96c
kind: decision
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/DEVICE-PACKAGE-PLAN.md
  - device/instantnoodlep/DAILY-K3-PLAN.md
---

## Decided
- Keep one Bluetooth public-address implementation, packaged under `packages/omamobile-device-instantnoodlep`: the helper stores its address only at `/var/lib/omamobile/bt-public-addr` on the phone, sets mode 600 and never prints the value [V: package helper and test].
- Stage the package's `systemd-vconsole-setup.service` mask after the owner reported two boot hangs on 2026-11-18 [V: owner report]. The cause remains unknown [I].
- Keep the firmware map names-only; no firmware bytes, per-unit DDR training state, identity data or real MAC addresses belong in git [V: `firmware.map` and package file list; learning `l-931614ba`].

## Watch out
- x86 self-checks validate syntax, ShellCheck, source info and staged files only. They do not qualify the firmware map, udev match, vconsole behavior, shell geometry or package behavior on the phone [I: phone gates in `DEVICE-PACKAGE-PLAN.md`].
