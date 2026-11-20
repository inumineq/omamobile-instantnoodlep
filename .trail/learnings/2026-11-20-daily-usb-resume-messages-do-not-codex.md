---
title: "Daily USB resume messages do not prove missing wake configuration"
author: Codex worker
date: 2026-11-20
branch: codex/daily-usb-typec-prep
id: l-e93c1738
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/USB-GADGET-PLAN.md
  - device/instantnoodlep/kernel-daily2-typec.config
  - device/instantnoodlep/TYPEC-DP-PLAN.md
---

## Decided
- [V: kernel source at `bd566b604`, `drivers/usb/dwc3/core.c:2561-2570,2626-2634` and `drivers/usb/dwc3/gadget.c:4993-5018`] System suspend already soft-disconnects a bound gadget and calls soft-connect during resume when `softconnect` remains set. First test this stock path with the NCM gadget still bound; do not add a speculative UDC unbind/rebind.
- [V: `drivers/usb/dwc3/gadget.c:2444-2453`] `remote wakeup not configured` is emitted by a gadget remote-wakeup request without host configuration. It does not identify a failed resume callback.
- [V: `drivers/usb/dwc3/dwc3-qcom-legacy.c:426-445,462-495`] The QCOM `HS-PHY not in L2` message is a pre-suspend status check; resume clears the L2 event bits. Do not interpret that message as a resume return failure.
- [V: `device/instantnoodlep/USB-GADGET-PLAN.md`] The daily Type-C candidate should first enable the PM8150B TCPM and QMP orientation path without DP altmode. Keep the tested 5 V sink PDO and `op-sink-microwatt`; do not change Fable power-program files.

## Tried and ruled out
- [I] Enabling `wakeup-source` alone is not a justified fix for NCM enumeration after s2idle. Remote wake configuration belongs to USB gadget configuration and the attached host; validate that separately if logs identify remote-wake behavior.
- [V: `TYPEC-DP-PLAN.md` §7 and learning `l-4ba3a6b2`] Do not use the old DP exit / static UTMI candidates as a fix for this no-DP daily gadget issue; they address a different failure mode and have not restored USB after DP disconnect.

## Watch out
- [I] A UDC rebind or kernel wake IRQ change may mask a PMIC/QMP orientation or host-side enumeration problem. Capture role, orientation, UDC binding, and both host/phone logs before selecting a second change.
