---
title: "SM8250 idle topology needs measurement before DTS edits"
author: opencode-worker
date: 2026-11-18
branch: pm-cam2
id: l-6d3302c9
kind: decision
scope: repo
status: active
src: agent
touches:
  - docs/research/idle-power-sm8250.md
  - device/instantnoodlep/CAMERA-BISECT.md
  - tools/instantnoodlep-idle-report
---

## Decided
- [V] The slim-all config already enables cpuidle, NO_HZ_IDLE, generic PM domains, and `CONFIG_ARM_PSCI_CPUIDLE_DOMAIN`; `sm8250.dtsi` describes per-core rail collapse plus hierarchical cluster idle states. The SM8250 interconnect provider registers `icc_sync_state`, and GPU runtime-PM power domains are declared. Source review did not identify a defensible DT correction.
- [I] Runtime deep-idle entry, firmware OSI/PC selection, residual GPU/RPMh/ICC votes, and WLAN power-save must be measured on the phone. PM1 therefore changes only the cpuidle governor selection to TEO and makes QCOM sleep statistics built in; it is diagnostic, not a claimed power fix.
- [V] Camera bisect rungs keep one base and stage built-in probe groups: CAMCC; then CCI with its sensor client disabled; then CAMSS plus IMX471 and the front-only graph. Each rung has a dedicated localversion and config fragment so the first failing boot narrows the suspect group.

## Tried and ruled out
- [V] Do not edit PSCI suspend-state IDs/latencies or interconnect votes speculatively: existing DTS/framework declarations are present, and no live counters yet show which resource is preventing low power.
