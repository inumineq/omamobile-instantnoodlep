---
title: "Quickshell windows take margins { }, not anchors.*Margin; shell tests miss it"
author: claude on omabook
date: 2026-11-18
branch: shell-launcher-margins-fix
id: l-da667190
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - patches/0004-device-safe-insets.patch
  - packages/omamobile-shell
  - device/instantnoodlep/tools/lint-panelwindow-margins
---

## Watch out

Quickshell PanelWindow margins go in `margins { left: ... }`; `anchors.leftMargin` on a window with boolean anchors makes the whole QML file fail to load. Patch 0004 did that on eight windows, which killed the launcher (dock and home strip) on the phone in shell 0.2.133-1.2: apps covered the screen with no way out.

The shell package's test/all does not catch it: its render/touch harnesses rewrite each PanelWindow into an Item, where anchors.*Margin is valid. Run device/instantnoodlep/tools/lint-panelwindow-margins on the patched plugins/ before building, and read the phone's quickshell log (/run/user/1000/quickshell/by-id/*/log.qslog, grep 'qml\[') after installing a shell: a missing layer in hyprctl layers is the symptom.
