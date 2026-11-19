---
title: "SM8250 sleep: the RPMh sleep set is only applied at cluster power-off, so s2idle comes before runtime tuning"
author: claude on omaserver (power program)
date: 2026-11-19
branch: inumineq/power-program
id: l-bc80726c
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/POWER-PROGRAM-PLAN.md
  - docs/runbooks/S2IDLE-FIRST-RUNBOOK.md
  - tools/instantnoodlep-s2idle-step
---

## Decided
- [V] The RPMh sleep set is flushed only when the cluster power domain turns off (`drivers/soc/qcom/rpmh-rsc.c:943-952` at kernel `bd566b604`). `cxsd`, `aosd` and DDR low-power counters cannot move before that. s2idle forces it, so the first s2idle attempt ranks above runtime holder work.
- [V] The CPU nodes' DDR interconnect votes use tag 0, which is also in the sleep set (`sm8250.dtsi:111`). Candidate K2 (`instantnoodlep-k3-power-cpuicc`) makes them active-only.
- [V] `pm_test` levels `processors` and `core` perform a real sleep under s2idle. The step tool refuses them.

## Tried and ruled out
- A 1 Hz re-read of Type-C Rp in the charger driver: it ran across suspend and rewrote the input limit every second. Removed in review.

## Watch out
- [V] The charger driver vetoes suspend while it charges. The step tool switches charging off for a step unless `S2IDLE_KEEP_CHARGING=1` is set.
- [I] All expected counter movements are source inferences until the phone has run the ladder.
