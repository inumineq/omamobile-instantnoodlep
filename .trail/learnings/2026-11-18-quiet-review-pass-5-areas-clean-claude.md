---
title: "Quiet review pass: 5 areas clean, PR findings in issues #88-#91, trail-lite fixtures now runtime-built"
author: claude on obsidian
date: 2026-11-18
branch: review/privacy
id: l-594604c8
kind: lesson
scope: repo
status: active
src: agent
touches:
  - docs/agents/review-log.md
  - tests/trail-lite
  - patches/instantnoodlep
  - device/instantnoodlep/patches
---

## Decided
- The quiet review pass (2026-11-17/18, areas 1-5 + PRs #69-#84) found no kernel-patch, config, tool-safety or runbook-gating defects; all 7 merged kernel patches plus the firmware-map patch apply to combo aa996bae0 and the Sahara host test passes [V: docs/agents/review-log.md].
- tests/trail-lite fixtures for private data are now all assembled at run time (the MAC/IMEI/serial-number cases join the email case), so no literal sits in the source [V: tests/trail-lite passes]; the old literals remain in history since 98e6db2, owner decision tracked as issue #90.

## Watch out
- PR #77 package firmware.map still maps mdmddr.mbn and its test/all regex fails on its own map (issues #88/#89); do not merge #77 until fixed.
- Emails in patch headers/MAINTAINERS context/lore citations are by design for DCO; scoping question is issue #91.
