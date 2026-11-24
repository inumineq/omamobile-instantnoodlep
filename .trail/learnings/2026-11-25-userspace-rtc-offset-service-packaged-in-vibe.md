---
title: "Userspace RTC offset service packaged in the device package (0.0.9)"
author: vibe on omaserver
date: 2026-11-25
branch: inumineq/rtc-offset
id: l-7d089275
kind: decision
scope: repo
status: active
src: agent
touches:
  - packages/omamobile-device-instantnoodlep
  - device/instantnoodlep/RTC-OFFSET-PLAN.md
---

## Decided
- Fix the PM8150 RTC's ~1970 boot clock in userspace, packaged as
  `omamobile-rtc-offset` + five systemd units in
  `packages/omamobile-device-instantnoodlep` (0.0.9): save `wall - rtc` to
  `/var/lib/omamobile/rtc-offset` hourly / after timesyncd syncs / on clean
  shutdown, apply it to the system clock before time-sync.target when the
  clock is below the package build floor. The helper never writes to the RTC
  and never moves the clock backwards [V: package files, host tests].
- The compile-time floor is the package build date, stamped by `./install`
  over a checked-in literal, so a stale state file can never pull the clock
  before the build existed [V: `install`, `test/all` staging check].

## Watch out
- Host checks (bash -n, shellcheck 0.11 via shellcheck-py, makepkg
  --printsrcinfo, staging, 17 helper cases, systemd-analyze verify) do not
  qualify on-device behavior: rtc0 sysfs name, timesyncd clock-file rewrites,
  path-unit firing and pre-NTP timedatectl stay [I] in RTC-OFFSET-PLAN.md §4
  gates T1-T6.
