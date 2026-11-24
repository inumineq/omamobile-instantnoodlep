---
title: "Without clk_ignore_unused, USB on instantnoodlep needs the wrap1 QUP core clocks; refgen and CX were dead ends"
author: claude on omaserver (power program)
date: 2026-11-25
branch: inumineq/power-program
id: l-15a49ff8
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/POWER-PROGRAM-PLAN.md
  - docs/runbooks
---

## Tried and ruled out
- [V] The PCIe reference-generator clocks: holding them did not bring USB back.
- [V] Upstream 389a0144c511 (GCC under the CX power domain) together with a dropped `clk_ignore_unused`: froze before the root file system, twice out of two. Do not retry it blind; ramoops is empty after any restart on this phone, so an early freeze leaves no log.
- [V] Dropping `clk_ignore_unused` alone does not give SoC sleep: cxsd, aosd and ddr stayed 0.

## Watch out
- [V] With `clk_ignore_unused` dropped the USB controller stays "not attached" and the kernel log shows no error.
- [V] Holding `gcc_qupv3_wrap1_core_clk` and `gcc_qupv3_wrap1_core_2x_clk` brings USB up 6 s after boot. Why is not explained: the wrapper carries touch, haptics and a UART.
- The method that found them: add unowned clocks to the USB node's clock list (dwc3-qcom enables every clock listed) and halve the list per RAM boot.
