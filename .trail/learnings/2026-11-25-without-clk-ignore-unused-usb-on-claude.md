---
title: "Dropping clk_ignore_unused loses USB on instantnoodlep; the wrap1 QUP core clock fix did not reproduce"
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
- [V] Upstream 389a0144c511 (GCC under the CX power domain) together with a dropped `clk_ignore_unused`: froze before the root file system, twice out of two. Ramoops is empty after any restart on this phone, so an early freeze leaves no log.
- [V] Dropping `clk_ignore_unused` alone does not give SoC sleep: cxsd, aosd and ddr stayed 0.
- [V] Plug orientation as the cause of a miss: the same image missed both ways round.

## Watch out
- [V] With `clk_ignore_unused` dropped the USB controller stays "not attached" and the kernel log shows no error.
- [V] Holding `gcc_qupv3_wrap1_core_clk` and `gcc_qupv3_wrap1_core_2x_clk` gave USB in three boots in one session, then the same image missed twice the next day with the same clock state and kernel log. Do not treat these clocks as the cause. Clocks held: 3 hits, 2 misses. Not held: 0 hits, 2 misses.
- Run a positive control (the full daily command line, RAM-booted) in the same session as any USB hit-or-miss test, and build test images on the kernel that is the daily at that time.
- The test images were built on a kernel without Type-C support, which has USB data one way round only. Mark the plug and note its direction.
