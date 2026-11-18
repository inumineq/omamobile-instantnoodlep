---
title: "Daily2 keeps USB peripheral-only"
author: OpenCode
date: 2026-11-18
branch: inumineq/k3-daily2
id: l-82d0aadb
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DAILY-K3-PLAN.md
---

## Decided
- [V: kernel commit `b08288732784` and candidate config] Daily2 starts from slim-all `c30e3f` and restores the fixed peripheral-only USB path. It disables the PMIC Type-C port, DP alt mode, FSA4480 mux, and xHCI host. The coordinator reported the DP/gadget and dock USB2 faults in the 2026-11-18 test brief.
- Keep `CHARGER_QCOM_SMB5=m`. The driver has no `MODULE_DEVICE_TABLE` [V: kernel source `drivers/power/supply/qcom_pm8150b_charger.c:1723`], so the coordinator loads it by hand after the owner's go.

## Watch out
- [V: Docker `stat` on both source paths] The Mac bind mount gives `xt_TCPMSS.c` and `xt_tcpmss.c` the same inode. Both exist in the kernel tree and implement different netfilter operations. The bind-mounted build exited 2 at `No rule to make target net/netfilter/xt_TCPMSS.o` (`logs/kernel-build.log`). Extract the archive directly in a case-sensitive Docker volume before building.
- [I] Promotion to `boot_b` is gated on the RAM checklist in `DAILY-K3-PLAN.md`.
