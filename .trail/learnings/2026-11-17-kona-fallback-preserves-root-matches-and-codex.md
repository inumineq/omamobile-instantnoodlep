---
title: "Kona fallback preserves root matches and needs integration gates"
author: codex on omabook
date: 2026-11-17
branch: inumineq/kona-root
id: l-d31a4e93
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
- [V] Preserve every existing root match and add an SM8250-only SMEM fallback, rather than replacing board-specific root choices wholesale (KONA-ROOT-DESIGN §5; patches/kona-root/0001 and 0002).

## Watch out
- [V] cpufreq node detection must scan all matching nodes: a disabled first node must not hide a later enabled controller (patches/kona-root/0003).
- [V] CPUFREQ_DT_PLATDEV is bool; module linkage is only meaningful for UBWC and PD mapper (kernel drivers/cpufreq/Kconfig:245).
- [V] The existing probe builder disables all remoteprocs, and combo predates Wi-Fi enablement; a RAM boot of this candidate cannot prove runtime PD services or Wi-Fi association (KONA-ROOT-DESIGN §5.1).
- [I] Keep those integration gates open and require human DCO sign-off before sending patches upstream.
