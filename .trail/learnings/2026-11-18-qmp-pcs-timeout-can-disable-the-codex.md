---
title: "QMP PCS timeout can disable the common pipe clock"
author: codex on macbookpro
date: 2026-11-18
branch: inumineq/typec-fix
id: l-8ce95d8d
kind: lesson
scope: repo
status: active
src: agent
touches:
  - docs/research/typec-dp-usb-recovery.md
  - device/instantnoodlep/TYPEC-DP-PLAN.md
---

## Watch out
- [V] Mainline commit `f546912bcac6` moved pipe-clock enable and disable into QMP common init and exit for USB2 during four-lane DP. Base `c30e3f696707` still disables the same clock on USB PCS timeout (`drivers/phy/qualcomm/phy-qcom-qmp-combo.c:4044-4049, 4130, 4259-4271`).
- [I] Match the timing of the owner's `phy initialization timed-out` and `gcc_usb3_prim_phy_pipe_clk already disabled` against DP entry, detach and replug. T6 tests deferred mode switching and T7 tests the controller's clock source. Neither changes the PCS timeout cleanup.
