---
title: "Kona fallback keeps root matches and needs integration gates"
author: claude on omabook
date: 2026-11-17
branch: inumineq/kona-root
id: l-439b4db4
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/KONA-ROOT-DESIGN.md
  - device/instantnoodlep/KONA-ROOT-PLAN.md
  - device/instantnoodlep/patches/kona-root
---

## Decided
- [V] The three review patches keep every existing root match and add an SM8250-only SMEM fallback, so board-specific UBWC choices and the existing PD inventories are untouched (KONA-ROOT-DESIGN §5, patches/kona-root/0001-0003).
- [V] The cpufreq change keys on the presence of an available cpufreq-hw/EPSS node, not on the root compatible, and walks every matching node so a disabled first controller cannot hide a later enabled one.

## Tried and ruled out
- [V] Adding `qcom,kona` to the three machine tables: it is an undocumented vendor codename and would put a device name into generic SoC tables (KONA-ROOT-DESIGN §3.4).
- [V] Replacing the stock dtbo: ABL rejected both a table-format and a raw-FDT neutral dtbo (DTBO-PLAN §6).

## Watch out
- [V] CPUFREQ_DT_PLATDEV is bool (drivers/cpufreq/Kconfig:245), so only UBWC and the PD mapper have a meaningful `=m` configuration; do not claim a module build for the cpufreq patch.
- [V] The probe builder disables every remoteproc and combo predates the Wi-Fi enablement, so a RAM boot of this candidate cannot prove PD service registration or Wi-Fi association. Those stay open integration gates.
- [V] Two full-build passes were OOM-killed (`Error 137`) while other kernel builds shared the laptop; resume with the same `W=1` argument, because dropping it invalidates every recorded command line and rebuilds the tree.
- [I] Human review, device testing and the DCO sign-off stay with the owner; nothing was sent upstream.
