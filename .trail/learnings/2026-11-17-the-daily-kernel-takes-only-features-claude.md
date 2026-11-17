---
title: "The daily kernel takes only features that passed a RAM boot; BT address is stored on the phone"
author: claude on omabook
date: 2026-11-17
branch: inumineq/daily
id: l-d0ce095f
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DAILY-K3-PLAN.md
  - docs/runbooks/DAILY-K3-RUNBOOK.md
  - device/instantnoodlep/kernel.config
---

## Decided
- `instantnoodlep-k3-daily` = combo K3 + the three Wi-Fi/BT DTS commits + the P1 gauge commit (`11fedfae5a37`) only. P2 charger commits stay out until their own RAM boot passes; a feature joins daily only after its RAM boot [V: DAILY-K3-PLAN §1-2].
- Bluetooth public address: udev rule on `hci_uart_qca` starts a oneshot that sets an address stored on the phone (`/var/lib/omamobile/bt-public-addr`, random `02:` locally administered, or the owner's real one written by hand) with `btmgmt public-addr`. Same pattern as upstream's Pixel `omamobile-bt-addr` and dodge's `omamobile-bt` [V: DAILY-K3-PLAN §5.3].

## Ruled out
- `local-bd-address` in the DTS (a per-unit value in git; ABL fills none) and patching `htnv20.bin` (per-unit firmware edit) [V: DAILY-K3-PLAN §5.2].

## Watch out
- The fragment asks `CONFIG_TYPEC_QCOM_PMIC=y`, every K3 `.config` has `=m`; `merge_config.sh` reports it. Not traced [I].
