---
title: "Feature kernels fit on slim K3 as RAM candidates: pin LOCALVERSION when building without git"
author: claude
date: 2026-11-18
branch: inumineq/slim-features
id: l-9831f600
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/KERNEL-SIZE.md
  - docs/runbooks/SLIM-FEAT-RUNBOOK.md
---

## Watch out
- [V] All five feature series (P2 charger, misc, audio, sensors, kona) fit on the slim K3 base (78f38a2acc99) far under the ABL image_size ceiling 0x2b60000: built image_size 0x1720000 (p2/misc/audio/kona) and 0x1740000 (sensors) with clang 23.1.5 in the MBP k3arch container. The P2 freeze was the ceiling (0x2b70000 on the fat config), not the charger driver.
- [V] The k3arch build tree has no git, so CONFIG_LOCALVERSION_AUTO cannot append -g<sha>: pin the full release string in CONFIG_LOCALVERSION (e.g. "-instantnoodlep-k3-slim-p2-g16aef753f820") and unset LOCALVERSION_AUTO, then olddefconfig with the same clang that builds.
- [V] Config deltas vs the slim .config stayed minimal per feature (p2: CHARGER_QCOM_SMB5=m only; misc: INPUT_AW8695_HAPTICS=m; audio/kona: none; sensors: the in-tree sensors fragment). Verify with a diff after in-container olddefconfig; toolchain-version lines (CC_VERSION_TEXT, ARM64_BTI/LSUI) differ and are expected.
- [V] Ship step trees as git archive of the base + tar of only the changed paths per step (the container has no git/patch); extract the per-step tars AFTER copying the base, or the base overwrites the modified files.
