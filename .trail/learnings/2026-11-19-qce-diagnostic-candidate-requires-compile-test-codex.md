---
title: "QCE diagnostic candidate requires COMPILE_TEST on SM8250"
author: codex worker
date: 2026-11-19
branch: inumineq/qce-sleep
id: l-f290331e
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/PM-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Decided
- [V: Linux `drivers/crypto/Kconfig:529-540`] QCE is hidden on ARCH_QCOM unless COMPILE_TEST or BROKEN is enabled, and its help warns that secure-world races are possible and software may be faster. The diagnostic candidate uses `CONFIG_COMPILE_TEST=y` plus QCE as a module; keep it RAM-only pending owner qualification and do not promote it to daily config.
- [V: Linux `drivers/gpu/drm/msm/adreno/a6xx_gmu.c:2282-2310`, `drivers/base/core.c:1382-1400`] Adreno initializes the GMU through a platform-device reference in the GPU probe. This is not the GMU consumer's own driver bind, so GPU bind alone does not establish that fw_devlink's GMU supplier links became active. [I] Verify the logged sync-state result on device.
- [V: Linux `drivers/crypto/qce/dma.c:19-32`, `arch/arm64/boot/dts/qcom/sm8250.dtsi:2609-2642`] The board QCE node requests BAM RX/TX channels 4/5, already described by `cryptobam`; probe and successful binding remain device-gated.

## Tried and ruled out
- [I] Do not disable the GMU or edit GPU DTS as part of this crypto candidate; that would change a second variable and could break the proven GPU path.
