---
title: "Audio phase 1 is DTS-only and needs the binding for a clean dtbs_check"
author: agent on omabook
date: 2026-11-17
branch: instantnoodlep-k3-audio
id: l-9ebae977
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/AUDIO-M5-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Decided
- [V] The phase-1 audio delta is one file: `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts` (ADSP firmware-name, WCD9385 on swr1/swr2, LPASS RX/TX/VA, q6 frontend and backend DAIs, the sound card, two disabled TFA9874 nodes). No driver change, so it cannot conflict with the power, wifi or misc workers.
- [V] The disabled TFA9874 nodes still need a schema: dt-validate reports an undocumented compatible for a disabled node too. `Documentation/devicetree/bindings/sound/nxp,tfa987x.yaml` is therefore part of phase 1, without the boost properties (their register codes are not public and the ABI needs maintainer review).
- [V] `dtbs_check` needs the `dtschema` python package, which is not installed system-wide on omabook. A venv at `~/android/build/dtschema-venv` (dtschema 2026.9 + yamllint) makes `CHECK_DTBS=y` and `dt_binding_check` work; without it the build stops at `check_dtschema_version` with "'dt-doc-validate' not found".

## Watch out
- [V] `make dtbs` builds every arm64 board and takes ~40 minutes at nice 19 on a loaded laptop. Build `Image.gz modules qcom/sm8250-oneplus-instantnoodlep.dtb` instead.
- [I] The kernel release is baked in at build start. A doc-only commit after the build starts leaves the artifacts on the earlier release; record the release from `include/config/kernel.release`, not from the branch HEAD.
