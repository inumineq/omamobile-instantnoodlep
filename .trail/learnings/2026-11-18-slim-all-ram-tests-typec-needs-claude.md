---
title: "Slim-all RAM tests: typec needs op-sink-microwatt and xHCI; DP kills the gadget; camera hangs"
author: claude on omabook
date: 2026-11-18
branch: docs/morning-2026-11-18-results
id: l-4ba3a6b2
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/TYPEC-DP-PLAN.md
  - device/instantnoodlep/CAMERA-PLAN.md
  - device/instantnoodlep/POWER-M5-PLAN.md
  - device/instantnoodlep/MISC-HW-PLAN.md
---

## Decided
- Branch `instantnoodlep-k3-slim-all` (local `~/src/l-k3-slim-all` on omabook) = slim-feat + slim-p2 + slim-typec + slim-cam merged, plus fixes: `op-sink-microwatt = <10000000>` on the Type-C connector, i2c15 left on for the FSA4480, haptics enabled, camera off, `CONFIG_USB_XHCI_HCD=y`, `CONFIG_I2C_CHARDEV=m` [V: git log on that branch]. Not flashed: DP/gadget bug below.
- Passed in RAM 2026-11-18 [V]: kona fallbacks (cpufreq-hw on all policies), haptics M3a (owner felt one 100 ms buzz), charger P2-5..P2-7 on slim-p2 (15 min, no STOP, max 29.7 C, SDP 500 mA), Type-C T1/T2 both orientations, DP picture on a Dell U3219Q, xHCI host role.

## Tried and ruled out
- `qcom,pmic-typec` without `op-sink-microwatt`: probe -EINVAL from `tcpm_fw_get_caps()` (drivers/usb/typec/tcpm/tcpm.c:8444) [V].
- The audio series' `&i2c15 { status = "disabled"; }` for its speaker amps: in a merge it turns the FSA4480 bus off and typec defers forever [V]. Disable the amp nodes, not the bus.
- Slim config without `USB_XHCI_HCD`: host role is reached but nothing enumerates [V].

## Watch out
- DP alt mode entry: `qcom-qmp-combo-phy: phy initialization timed-out`, WARN `gcc_usb3_prim_phy_pipe_clk already disabled` from `qmp_combo_typec_mux_set`; after unplug `dwc3: failed to enable ep0out` and the USB gadget never returns until reboot [V: journal of two boots].
- Behind the U3219Q (4-lane DP) the USB2 hub fails `usb1-port1: connect-debounce failed`, so no keyboard/mouse [V]. Try the monitor's "High Data Speed" (2-lane DP + USB3) next [I].
- `boot-slim-cam.img` hung before the root (no journal); the slim-all with the camera stack died within a minute after userspace; with camera modules blacklisted it runs [V]. Camera stays off.
- The per-step slim-feat images are not cumulative: audio, sensors and kona each carry only their own fragment (no aw8695 in kona, kona DTB without haptics) [V], despite SLIM-FEAT-RUNBOOK's table.
