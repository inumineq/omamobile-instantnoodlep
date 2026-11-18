---
title: "Rebuild the camera and modem kernel candidates on slim K3 with clang 23 on omabook"
author: claude
date: 2026-11-18
branch: inumineq/slim-cam-modem
id: l-cf24972a
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/CAMERA-PLAN.md
  - device/instantnoodlep/MODEM-M5-DELTA.md
  - docs/agents/state.md
---

## Decision
- [V] Both M5 feature candidates were re-based from combo `aa996bae0` onto the slim K3 tip `78f38a2acc99` and rebuilt on omabook with clang/LLD 23.1.3 (`nice -n 5 make ARCH=arm64 LLVM=1 -j8`, separate `O=` dirs), because the MBP clang 19 builds freeze (learning `l-e03ff7fe`) and the camera one was also over the ABL image_size ceiling:
  - camera: branch `instantnoodlep-k3-slim-cam` @ `d53d0fd6baaa`, release `7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa`, `image_size` 0x1720000; config delta vs slim is only `VIDEO_IMX471=m` + `LOCALVERSION`, the whole camera stack (CAMSS, camcc, CCI, V4L2_CCI) stays `=m` so a probe hang cannot block boot; RAM image `~/android/build/k3-slim-cam-ram/boot-slim-cam.img` [V: CAMERA-PLAN §9.5]
  - modem: branch `instantnoodlep-k3-slim-modem` @ `7dc2ea318807`, release `7.3.0-rc6-instantnoodlep-k3-slim-modem-g7dc2ea318807`, `image_size` 0x1750000 (built-in MHI/QRTR transport costs 0x30000 over slim); config delta is only the SDX55 fragment's symbols; `CONFIG_MHI_BUS_SAHARA=y` present; RAM image `~/android/build/k3-slim-modem-ram/boot-slim-modem.img` [V: MODEM-M5-DELTA §6.2]
- Both pass `CHECK_DTBS=y` (dtschema venv), modules tarballs (`INSTALL_MOD_STRIP=1`), and `tools/build-instantnoodlep-probe` with exactly the daily-manifest flags (`--boot 2 --root userdata --debug-shell`).
- Feature branches were fetched from macbookpro (`~/src/l-k3-camera`, `~/src/l-k3-modem`) via `git bundle` + `scp` and cherry-picked; the board DTS commits needed a merge resolution against the daily tip's Wi-Fi/BT/gauge DTS (both sides kept). `dtbs_check` caught one misplacement (`regulator-cam-front-avdd` inside `qca6390-pmu`) before release.

## Watch out
- The modem gates A-C (stock wiring, MM packages, private-state policy) and the camera gates C0-C5 are unchanged and still closed; no phone was touched. Do not build phone kernels with clang 19 or on the MBP while it is in use.
