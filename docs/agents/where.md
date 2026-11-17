<!-- SPDX-License-Identifier: MIT -->
# Where things live

Paths an agent needs, on every host. Update it in the same PR that moves
something.

## Hosts

| Host | What it is | Checkout | Has |
| --- | --- | --- | --- |
| omabook | Owner's Linux laptop | Orca worktrees of this repo | the phone (USB), kernel trees, private build dirs, captures |
| obsidian | Linux VPS (Orca server) | `/home/claude/orca/omamobile-instantnoodlep` | research, docs, PRs; no phone, no build dirs |
| macbookpro | macOS M1 Pro | `~/orca/omamobile-instantnoodlep` | arm64 builds (Mesa); no phone |

The only channel between hosts is git (`origin` on GitHub). Something not
pushed does not exist for the other hosts: describe private files here by
name, never copy them in.

## In the repo

| Path | What |
| --- | --- |
| `AGENTS.md` | House rules (they win over everything here) |
| `docs/agents/state.md` | Where the port stands now (read first) |
| `docs/agents/active/` | One file per running worker |
| `.trail/learnings/` | Decisions, ruled-out paths, watch-outs (Trail-code format) |
| `scripts/trail-lite` | `brief`, `note`, `lint` for the three above |
| `docs/agents/issue-tracker.md` | Wayfinder map and tickets on GitHub issues |
| `device/instantnoodlep/NOTES.md` | Findings log, newest first |
| `device/instantnoodlep/*-PLAN.md` | Gated plans per subsystem (rule 6) |
| `device/instantnoodlep/device.conf`, `kernel.config`, `firmware.map` | Device descriptor, kernel config fragment, firmware list |
| `device/instantnoodlep/dtbo/neutral.dts` | The neutral dtbo ABL rejected (kept for the record) |
| `docs/STAGE-0.md`, `docs/RESTORE-RUNBOOK.md` | Stock facts; how stock is restored |
| `docs/runbooks/` | Owner-run gated runbooks |
| `docs/research/` | Research notes ([V]/[I]) |
| `docs/drafts/` | Drafts for upstream comments and proposals |
| `tools/build-instantnoodlep-probe` | Builds probe/boot images (K1/K2/K3) |
| `tools/instantnoodlep-slot-b-mark` | Builds the B5 GPT sectors that mark slot B successful |
| `scripts/` | Stage-0 capture, laptop tool fetch, initramfs root prep |
| `tests/` | Host tests for the tools |
| `captures/` | Private captures, gitignored, never committed |

## Private on omabook (by name only, never in git)

| Path | What |
| --- | --- |
| `~/src/l-k3` | K3 "combo" kernel tree: carries the test-only `qcom,kona` match patch (DO NOT UPSTREAM) |
| `~/src/l-k3c` | K3 clean kernel tree, branch `instantnoodlep-k3-clean`: the upstreamable one |
| `~/android/build/k1`, `k2`, `k2-full`, `k2-patches`, `k2-d1*` | K1/K2 build outputs and the K2 D1 baseline |
| `~/android/build/k3-clean`, `k3-clean-boot`, `k3-combo`, `k3-combo-ram`, `k3-panel*`, `k3-touch` | K3 builds and RAM-boot images |
| `~/android/build/m1b`, `b5-<date>` | Slot B images; B5 GPT reads and sectors |
| `~/android/build/dtbo-neutral` | The rejected neutral dtbo image and checksums |
| `~/android/build/p3`, `ufdt`, `sink`, `qabl` | Offline dtbo/overlay work, ABL source reading |
| `~/android/build/probe*`, `tethered*`, `m2` | Probe and tethered (M2) images |
| `~/android/build/rootfs*`, `initramfs-root*` | Arch rootfs and initramfs root |
| `~/android/build/firmware` | Firmware split from the owner's OTA (never in git, rule 8) |
| `~/android/build/logs` | Build and boot logs |
| `~/android/reference/instantnoodlep` | Stock OTA images (rollback source, e.g. `images/dtbo.img`) |
