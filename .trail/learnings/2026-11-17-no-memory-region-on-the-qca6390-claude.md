---
title: "No memory-region on the QCA6390 wifi@0 node"
author: claude on macbookpro
date: 2026-11-17
branch: inumineq/wifi-bt
id: l-8b77763d
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/WIFI-BT-M5-PLAN.md
---

## Watch out
- Do not add `memory-region = <&wlan_mem>` to `wifi@0` (pci17cb,1101). Its presence alone flips ath11k into fixed-memory mode [V: drivers/net/wireless/ath/ath11k/pci.c:980-981 in the K3 tree]: firmware memory must then fit the region (1 MiB here; QCA6390 asks for about 4 MiB), MHI reads its IOVA window from DT, and board data is written to the fixed physical address 0x4B0C0000 [V: qmi.c:2054-2075, core.c:227].
- The ath11k-pci schema rejects the property; `make CHECK_DTBS=y` on the board DTB catches it [V: macbookpro build 2026-11-17].
- The `wlan_mem` carve-out stays reserved as in the stock layout; nothing references it. Neither the community tree nor mainline elish sets the property.
