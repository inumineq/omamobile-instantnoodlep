---
title: "ALARM aarch64 build fixes for the morning package set"
author: claude worker
date: 2026-11-18
branch: inumineq/arm-pkgs
id: l-bb56c572
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/tools
  - packages/omamobile-device-instantnoodlep/test/all
  - patches/omamobile-settings
  - tools/omamobile-localrepo-packages.tsv
---

## Tried and ruled out
- `pacman -S shellcheck` in the ALARM aarch64 container fails: ALARM aarch64 extra has no shellcheck (no Haskell stack; mirror listing and archlinuxarm.org 404 confirm). The device and settings recipes now bootstrap the official static `shellcheck-v0.10.0.linux.aarch64` binary with a pinned archive sha256 (`324a7e89...a09bb`).
- Running the device package's `test/all` under `makepkg check()` failed on `find: './pkg': Permission denied`: makepkg creates `$pkgdir` mode 0111 during check. `test/all` now prunes `./pkg`.
- The settings security patch missed two things the aarch64 build's check() caught: `tests/core_tests.cpp` still expected 2 root rows (Security makes 3) and `tests/session_app.pro` did not link `credentialscontroller.cpp`. Both are fixed in the patch (regenerated from the applied tree, re-validated with `git apply --check` on pristine `c462357`).

## Watch out
- `qmllint` on ALARM lives in `/usr/lib/qt6/bin`, not `/usr/bin`; the settings build script prepends it to PATH for makepkg.
- The persistent `k3arch` container needs `userdel -r builder` before each verbatim build script (they `useradd -m -u 1000 builder` after `userdel -r alarm`); build paths were sed-adapted from `/work`/`/out` to `/w/pkgs/<pkg>/...`.
