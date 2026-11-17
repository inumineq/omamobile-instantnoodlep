---
title: "The stock dtbo rewrites the root compatible to qcom,kona"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-f28ff139
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DTBO-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Watch out
- ABL applies the stock dtbo on every boot, `fastboot boot` included, and merges root properties from entry 16: the live `/proc/device-tree/compatible` reads `qcom,kona-mtp qcom,kona qcom,mtp`, not `oneplus,instantnoodlep qcom,sm8250` [V: DTBO-PLAN §1].
- Every kernel table keyed on `qcom,sm8250` through the machine compatible misses: UBWC config (msm-mdss -EINVAL), and by code reading `qcom_pd_mapper.c` (audio, sensors, modem) and `cpufreq-dt-platdev.c` [V: DTBO-PLAN §1].
- AOSP `ufdt_apply_overlay` does not reproduce the rewrite, so offline checks miss it [V: DTBO-PLAN §1].

## Decided
- K3 "combo" (`~/src/l-k3`) carries a test-only kona match patch marked DO NOT UPSTREAM; the clean tree `~/src/l-k3c` (branch `instantnoodlep-k3-clean`) has none and is what goes upstream. Never send the kona patch upstream.
