---
title: "Pin the daily kernel's modules: omamobile-modules-cleanup deletes hand-staged trees"
author: claude on omabook
date: 2026-11-18
branch: docs/morning-2026-11-18-results
id: l-be31051d
kind: guardrail
scope: repo
status: active
src: agent
touches:
  - docs/runbooks/DAILY-K3-RUNBOOK.md
  - docs/runbooks/SLIM-FEAT-RUNBOOK.md
  - device/instantnoodlep/NOTES.md
---

## Decided
- Every hand-staged kernel that must survive (the `boot_b` daily) is listed in `/usr/lib/modules/.omamobile-pinned` on the phone. The daily `7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99` is pinned since 2026-11-18 [V: file on the phone].
- Upstream `omamobile-modules-cleanup.timer` (package `omamobile-omarchy`, 10 min after boot) keeps only the running release, trees that arrived this boot, pinned ones, `.omamobile-next`, package-owned ones and the 2 newest others; every other tree under `/usr/lib/modules` is deleted [V: `/usr/lib/omamobile-omarchy/modules-cleanup` header, journal of the unit].

## Tried and ruled out
- Blaming cold vs warm boot for missing Wi-Fi: a warm `fastboot boot` of the daily image also had no PCIe link while its module tree was gone; with the tree restored, a warm reboot from `boot_b` boots in 8.9 s with Wi-Fi [V: journal 2026-11-18].
- Blaming Arch `linux-modules-cleanup.service`: the package drop-in skips it on every boot, `/usr/lib/modules/.old` does not exist [V].

## Watch out
- On 2026-11-18 at 09:10 the timer, running in a RAM-booted test kernel, deleted the daily tree. Every later daily boot came up without modules: no ath11k/pwrseq (no Wi-Fi), an ~80 s hang on the console before the session, and a frozen boot with the glitch band once [V for the deletion and the missing link; I that the freeze has the same cause].
- A day of RAM tests rotates more than 2 kernels through `/usr/lib/modules`, so any unpinned tree older than the two newest is gone after the next 10-minute uptime. Pin before the first RAM boot, or re-stage before trusting a daily boot.
