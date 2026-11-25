---
title: "device.conf evidence marks are trailing comments, which upstream bin/omamobile refuses"
author: vibe on omaserver
date: 2026-11-25
branch: inumineq/device-conf
id: l-3eeda187
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/device.conf
  - packages/omamobile-device-instantnoodlep/device.conf
  - tests/instantnoodlep-device-conf
---

## Watch out
- Issue #8 asks for a trailing `# [V] <source>` / `# [I] <what resolves it>`
  on every field line of `device/instantnoodlep/device.conf`. Upstream
  `bin/omamobile` `load_device` (upstream bin/omamobile:113-125) accepts
  whole-line comments only: its quoted/bare regexes anchor at end of line,
  so any text after the value makes it die with "not a KEY=value line".
  The values themselves pass every upstream check (UFS_RW allowlist +
  userdata, no _a/super/vbmeta, BOOT_IMAGES _b on UFS_RW, AVB_FOOTERS
  subset and 4096 multiples, AVB_ROLLBACK_INDEX/AVB_SECURITY_PATCH formats,
  UFS_RW_LUNS sd[b-z]) once the trailing marks are stripped; verified with a
  local replication of the parser. Resolved in the same PR: the marks sit on
  the comment line above each key, and tests/instantnoodlep-device-conf
  fails on any trailing text, on diverging repo/package copies, and on a
  UFS_RW entry that is _a, super or vbmeta.
- Locked per the recorded answers: chain-partition vbmeta case (issue #10
  comment) -> `AVB_FOOTERS="boot:0x6000000 dtbo:0x1800000"`,
  `AVB_ROLLBACK_INDEX=0`, `AVB_SECURITY_PATCH=2024-06-05`; `UFS_RW_LUNS=sde`
  (boot_b/dtbo_b on LUN 4, userdata on sda); `NV_PARTS="persist modemst1
  modemst2 fsg fsc"`; `OS_VERSION=12.0.0`/`OS_PATCH_LEVEL=2024-06` from the
  stock boot header (not the Android 13 system build); `COMPATIBLE=
  "oneplus,instantnoodlep"` from the ported DTS.
