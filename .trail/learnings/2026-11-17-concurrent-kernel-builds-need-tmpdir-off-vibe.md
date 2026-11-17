---
title: "Concurrent kernel builds need TMPDIR off /tmp and a fair nice level"
author: vibe on omabook
date: 2026-11-17
branch: inumineq/sensors
id: l-5cb68983
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/SENSORS-M5-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Watch out
- [V] `/tmp` is a 16 GiB tmpfs on omabook. With several kernel builds running, it filled and one build aborted at `drivers/pci` with `error: unable to open output file '/tmp/pnmtologo-*.o': 'Disk quota exceeded'`. Set `TMPDIR` to a directory on `/home` (747 GiB free) for every kernel build.
- [V] `make ... | tee log` reports `tee`'s exit status, not make's. A killed or failed build then looks like exit 0. Write the real status explicitly (`make ... > log 2>&1; echo "MAKE_EXIT=$?" >> log`).
- [V] `nice -n 19` starves a build to a few objects per minute while other builds run at nice 0/15, and a normal user cannot renice back up. Start the build at the intended level instead of lowering it later.
- [V] `CONFIG_QCOM_PDR_HELPERS` is promptless and select-driven (SLIMBUS, APR/GPR); a fragment line for it is silently ignored and it resolves to `=m` from the defconfig chain. `qcom_q6v5_pas` does not reference it, so the sensors fragment documents this instead of forcing it.
- [V] `LOCALVERSION_AUTO=y` means amending a kernel commit changes `kernel.release`, which invalidates `utsrelease.h` and forces a wide rebuild. Amend before the first full build, not after.
