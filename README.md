<!-- SPDX-License-Identifier: MIT -->
# omamobile-instantnoodlep

Bring-up workspace for running [Omarchy Mobile](https://omamobile.org) (native
Arch Linux ARM + Hyprland on a mainline kernel, no Android) on the
**OnePlus 8 Pro** (`instantnoodlep`, Qualcomm SM8250 / Snapdragon 865).

Device support request: [derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808)

## Status (2026-11-15)

The current state is in [`docs/agents/state.md`](docs/agents/state.md); this
table is the starting point.

| Item | State |
| --- | --- |
| Support request | Posted and open: issue #808 |
| Stage-0 facts (stock capture, partition map, live DT) | Not collected yet, see `docs/STAGE-0.md` |
| Board DTS | Not started. Base: the community SM8250 fork's `sm8250-oneplus-instantnoodlep.dts` |
| `device/instantnoodlep/device.conf` | Draft in place, values marked TODO/I must be verified by stage 0 |
| Kernel branch | To be based on `omamobile` in [derekross/linux-omarchy-mobile](https://github.com/derekross/linux-omarchy-mobile) |
| First boot on slot B | Not attempted |

## Why this port is plausible

- The SM8250 mainline fork used by Nura (formerly postmarketOS) carries
  `sm8250-oneplus-instantnoodlep.dts` and the fixes this phone needs
  (including the Wi-Fi/BT DTS regression from around v6.11):
  https://gitlab.postmarketos.org/soc/qualcomm-sm8250/linux
- An unofficial Nura image (kernel 7.2) demonstrates on an IN2023 EU unit:
  display at 1440x3168 @ 120 Hz, GPU, audio, Wi-Fi, Bluetooth,
  modem/SIM/SMS/data, GPS, NFC, sensors, and all five cameras via libcamera:
  https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial
- Upstream Linux carries the SM8250 OnePlus family (bindings, common DTS,
  panel and Synaptics TCM touch drivers): https://lwn.net/Articles/979482/
- The phone has A/B boot slots with dynamic partitions inside `super`;
  `userdata` is physical and non-slotted. The install model is: our boot
  images on slot B, the Arch root on `userdata`, `super` and slot A untouched.

## Safety model (non-negotiable)

1. Never write to `super`. Never write to any `_a` partition.
2. The storage guard allowlist (`UFS_RW`) may only name slot B boot images
   and `userdata`, and must contain `userdata`.
3. Every flash goes through a dry-run first.
4. Captures contain serials, the IMEI and MAC addresses. They live in
   `captures/` (gitignored), never in the repository. Quote facts, not files.
5. Restore paths must exist on disk before any experiment:
   see `docs/RESTORE-RUNBOOK.md`.

## Layout

```
docs/STAGE-0.md              Facts to collect from stock, in order
docs/RESTORE-RUNBOOK.md      How stock is restored (OTA, fastbootd, EDL last)
docs/research/               Research notes ([V]/[I]) from the map's research tickets
docs/runbooks/               Owner-run gated runbooks (Expect / Stop / Rollback)
device/instantnoodlep/       Device work: descriptor, plans, notes
scripts/stage0-collect.sh   Read-only stock capture (run before unlocking)
scripts/omabook-fetch-tools.sh  Laptop tools + Magisk APK for the runbooks (no phone)
docs/agents/state.md         Where the port stands now (agents: read first)
docs/agents/where.md         Paths on every host
.trail/learnings/            Decisions and watch-outs (Trail-code format)
scripts/trail-lite           brief / note / lint for the project memory
captures/                    Private captures (gitignored, never commit)
```

## Conventions

- Follow the upstream project's rules: read `AGENTS.md` and `CONTRIBUTING.md`
  in [derekross/omarchy-mobile](https://github.com/derekross/omarchy-mobile)
  before contributing there.
- Evidence discipline: every claim in a plan is marked [V] (checked, with a
  source or `file:line`) or [I] (an inference to check on the device).
- Plans are written before code: `device/instantnoodlep/*-PLAN.md`, modelled
  on cheetah's plans.
- Kernel patches and DTS are GPL-2.0; everything else here is MIT
  (SPDX headers required).

## License

MIT, see [LICENSE](LICENSE). Kernel-side work follows GPL-2.0 as usual.
