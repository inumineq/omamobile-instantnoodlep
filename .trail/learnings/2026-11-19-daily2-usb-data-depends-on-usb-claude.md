---
title: "daily2 USB data depends on USB-C plug orientation; flip the plug first"
author: claude on omabook
date: 2026-11-19
branch: notes-usb-orientation
id: l-35d3f898
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/TYPEC-DP-PLAN.md
---

## Decided

When the daily kernel (k3-daily2) is up but the laptop sees no USB device at all (no add events, only `ucsi_acpi ... GET_CURRENT_CAM command failed`, phone charging), flip the USB-C plug at the phone 180 degrees before anything else. [V 2026-11-19: after a hard reset (Power + Volume Up) the session was up and charging but no gadget enumerated for 15+ minutes; flipping the plug brought `OnePlus 8 Pro tethered Omarchy Mobile` up within seconds.]

## Watch out

- daily2 forces dwc3 peripheral mode and has no Type-C orientation switch, so data depends on plug orientation [I: cause not proven; the same happened once earlier the same morning and cleared after a cable or port change].
- Not the same as the typec-fix1 failure, where the host logs `device not accepting address ... error -71` on the SuperSpeed bus after DisplayPort use.
- A real fix belongs to the Type-C work (TYPEC-DP-PLAN): orientation from the PM8150B port to the QMP PHY, or a USB2-only device path.
