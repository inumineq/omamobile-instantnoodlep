---
title: "Charger changes need an independent review per fix round; three rounds found real defects each time"
author: claude on omaserver (power program)
date: 2026-11-19
branch: inumineq/power-program
id: l-0d391cab
kind: lesson
scope: repo
status: active
src: agent
touches:
  - docs/runbooks/CHARGER-RP-RUNBOOK.md
  - docs/runbooks/CHARGE-LIMIT-WAKE-RUNBOOK.md
  - device/instantnoodlep/POWER-PROGRAM-PLAN.md
---

## Decided
- Every change to `qcom_pm8150b_charger.c` gets a review by a different model family before a phone request, and again after each fix round. K1 needed three reviews, K3 three.
- Gates for charging name the first emergency step as hardware: the owner pulls the cable at the inline meter.

## Watch out
- [V] The base driver ignored the result of the charge-disable write in its suspend callback. K3 makes suspend fail instead.
- [V] The verifier does not always run the tests. Ask for the KUnit summary line in the review brief.
- [V] `pgrep -f` over SSH matches the remote shell. Runbooks store a PID file instead.
- [V] A test fixture with an invented file format hid a real parsing defect in the baseline tool. Copy formats from the kernel's `seq_printf` calls.
