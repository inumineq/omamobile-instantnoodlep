---
title: "Separate DP exit recovery from UTMI clock test"
author: opencode
date: 2026-11-18
branch: inumineq/typec-fix
id: l-a6c927a4
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/TYPEC-DP-PLAN.md
  - docs/research/typec-dp-usb-recovery.md
---

## Decided

- [V] The QMP mux callback in kernel base `instantnoodlep-k3-slim-all` at `c30e3f696707` returns while DP is powered but does not save the requested mode; `qmp_combo_dp_power_off()` only clears `dp_powered_on` (`drivers/phy/qualcomm/phy-qcom-qmp-combo.c:4201-4214, 4840-4848`). Candidate 1 records and applies the pending mode after DP power-off.
- [V] `qcom,select-utmi-as-pipe-clk` selects UTMI during DWC3 glue probe and is documented for systems without an SSPHY (`drivers/usb/dwc3/dwc3-qcom-legacy.c:787-795`). Mainline's SM8250 Samsung DTS uses it with a high-speed-only DWC3 node (`arch/arm64/boot/dts/qcom/sm8250-samsung-common.dtsi:166-179`). Candidate 2 tests that clock path separately; it may sacrifice SuperSpeed.
- [V] The board already sets `role-switch-default-mode = "peripheral"`, and the FSA4480 driver enables USB routing in all DP states (`arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts:951-960`, `drivers/usb/typec/mux/fsa4480.c:95-105`). Do not spend a candidate repeating either change.
- [I] Four-lane DP should retain USB2. Do not use a two-lane DP mapping as the first fix for a USB2 hub debounce failure. Check the QMP/UTMI clock and FSA route on the phone first.
