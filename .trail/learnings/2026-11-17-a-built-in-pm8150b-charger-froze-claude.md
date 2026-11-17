---
title: "A built-in PM8150B charger froze the P2 boot before userspace; test it as a module with panic-on-hang armed"
author: claude on omabook
date: 2026-11-17
branch: inumineq/power
id: l-be71c565
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/POWER-M5-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Decision
- P2 (charger + ADC5 built in, release `7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e`) RAM-booted to `Booting OKAY` and then froze before userspace: no USB gadget for 3+ min, no journal of that boot, empty pstore, no self-reset despite `panic=10` [V: NOTES 2026-11-17 afternoon; POWER-M5-PLAN §7.4]. P2b therefore builds the charger as a module with no OF alias (loaded only by hand via `modprobe qcom_pm8150b_charger`, behind an owner go) and keeps the pm8150b GPIO/temp-alarm nodes disabled; ADC5 stays `=m` as in P1 [V: device/instantnoodlep/kernel.config; l-k3p @ `8c252b516245`].
- To get crash evidence on a repeat, P2b arms `DETECT_HUNG_TASK` (120 s), `SOFTLOCKUP_DETECTOR`, `HARDLOCKUP_DETECTOR` with `BOOTPARAM_*_PANIC=1`, plus `PANIC_ON_OOPS=y` and `PANIC_TIMEOUT=10`, and a 256 KiB ramoops `pmsg-size`: a hang panics, dumps to pstore and self-reboots into combo K3 [V: P2b `.config`; POWER-M5-PLAN §7.5].
- The blocking line is still unidentified: every wait on the probe path is bounded (hang review with file:line in POWER-M5-PLAN §7.5); the deferred-probe flush (`drivers/base/dd.c:348,359`) is the mechanism that turns a stuck probe into a pre-userspace freeze.

## Watch out
- Do not set `CHARGER_QCOM_SMB5=y` again until the P2 cause is known; the kernel.config comment says the same.
