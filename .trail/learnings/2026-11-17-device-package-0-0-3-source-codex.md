---
title: "device package 0.0.3 source was not tracked"
author: codex worker
date: 2026-11-17
branch: inumineq/device-pkg
id: l-d3d77fef
kind: lesson
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/DEVICE-PACKAGE-PLAN.md
  - device/instantnoodlep/device.conf
---

## Decided
- [V: `device/instantnoodlep/NOTES.md`, 2026-11-17] The installed 0.0.3 package came from a local package artifact installed with `pacman -U`; its build checkout and file manifest are not recorded. The repository history and inspected upstream clone contain no package source for instantnoodlep. Keep the new 0.0.4 build explicit about the inferred USB policy and do not claim provenance for 0.0.3.
- [V: `DAILY-K3-PLAN.md` §5] Bluetooth address must be stored on the phone only, with a generated local address or an owner-entered address; do not derive it from an identifier or commit per-device address data.

## Watch out
- [I] The new udev trigger and public-address behavior still need the DAILY-K3-PLAN D6 device check. Do not treat package staging as hardware qualification.
