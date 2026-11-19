---
title: "GMU fw_devlink sync_state: bind the GMU device with a no-op platform driver"
author: agent on omaserver
date: 2026-11-19
branch: inumineq/gmu-sync
id: l-feefaf06
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/patches/pm
---

## Decided
- [V: kernel 7.3.0-rc6 source, `instantnoodlep-k3-daily2-qce-gmu`] The GMU DT node (`gmu@3d6a000`, child of `soc@0`, sm8250.dtsi:3012) becomes a platform device at boot, but no driver ever binds to it: adreno binds only to `gpu@3d00000` and uses the GMU device via `of_find_device_by_node()` (a6xx_gmu.c:2285). Under strict fw_devlink sync_state (CONFIG_FW_DEVLINK_SYNC_STATE_TIMEOUT unset) the GMU's managed consumer links never become DL_STATE_ACTIVE (core.c:1208-1214,1428-1455), so gcc-sm8250/sm8250-gpucc never get sync_state() and log "sync_state() pending due to 3d6a000.gmu" (core.c:1858-1860); qcom_stats counters stay Count 0.
- Fix (not DT): register a no-op platform_driver matching `qcom,adreno-gmu`/`-wrapper`/`-rgmu` in a6xx_gmu.c so device_links_driver_bound() marks the GMU's supplier links ACTIVE. Patch: device/instantnoodlep/patches/pm/, kernel branch instantnoodlep-k3-daily2-qce-gmu @ bd566b604. DT phandles on the gmu node must stay (a6xx_gmu_clocks_probe uses devm_clk_bulk_get_all(gmu->dev)).

## Tried and ruled out
- `fw_devlink.sync_state=timeout` on k3-daily2-qce: lock screen reached but the USB gadget never attached (15 min) — stays ruled out (owner report 2026-11-19, PR #136).

## Watch out
- Phone gate PM-PLAN §4.5 G-gmu-1..7 (RAM boot only): no 3d6a000.gmu pending line, /sys/bus/platform/devices/3d6a000.gmu/driver bound, USB gadget attaches, qcom_stats counters advance screen-off/cable-out. One variable per boot; rollback to the daily image on any stop.
