---
title: "Audio phase 1 candidate k3-daily2-adsp: daily2 config plus LOCALVERSION is enough for ADSP"
author: vibe
date: 2026-11-19
branch: inumineq/audio-adsp
id: l-04427b64
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/AUDIO-M5-PLAN.md
---

## Watch out

- [V] Branch `instantnoodlep-k3-daily2-adsp` @ `625fc540c` = flashed daily2 (`instantnoodlep-k3-slim-daily2` @ `c5e256242`) + one DTS commit that keeps only `&adsp` (status okay, firmware-name per firmware.map:25). Every phase-1 prerequisite is already in the daily2 base config — `REMOTEPROC=y`, `QCOM_Q6V5_PAS=y` (auto_boot), `QCOM_SYSMON=y`, `RPMSG_QCOM_GLINK_SMEM=y`, `QRTR=y`, `QCOM_QMI_HELPERS=y`, `QCOM_PD_MAPPER=y`, `AUXILIARY_BUS=y`, `QCOM_APR=m`, `QCOM_PDR_HELPERS=m` — so the candidate config is the daily2 config plus `LOCALVERSION="-instantnoodlep-k3-daily2-adsp"` only; build evidence in AUDIO-M5-PLAN §11.3 (image_size 0x1750000, dtbs_check clean, release 7.3.0-rc6-instantnoodlep-k3-daily2-adsp).
- [V] pd-mapper already falls back to the SMEM SoC ID (`fa0731ea7` in the daily2 base), so the stock-dtbo `qcom,kona` live root compatible does not block the sm8250 domain table — the preamble's neutral-DTBO gate is covered on the kernel side for PD_MAPPER.
- [V] On a git worktree not sitting on an annotated tag, `CONFIG_LOCALVERSION_AUTO` unset still appends `+` to kernel.release unless the environment variable `LOCALVERSION` is set (even empty): build with `LOCALVERSION= make ...`. On omaserver, `bc` is not installed system-wide; `include/generated/timeconst.h` fails without it — use `~/android/build/tool-cache/bc-root/bin` on PATH, and dtschema for `CHECK_DTBS` lives in `~/android/build/venv-dt/bin`.
- [I] ADSP reaching `running` with the q6 services on the phone awaits the RAM gate AUDIO-M5-PLAN §11.5; no phone was touched and nothing was flashed.
