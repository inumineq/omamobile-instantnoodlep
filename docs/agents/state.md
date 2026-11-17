<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-17 (daily K3 built as the boot_b candidate), claude on omabook.

The one page an agent reads first. Keep it short and current: it is
overwritten, not appended to. History goes to `device/instantnoodlep/NOTES.md`
(findings, newest first), decisions with their reasons to `.trail/learnings/`,
open questions and tickets to the wayfinder map issue
(`docs/agents/issue-tracker.md`). Who is working on what right now is in
`docs/agents/active/`, one file per worker. `scripts/trail-lite brief` prints all
of it from `origin/main` plus the pushed branches.

## Milestones

| Milestone | State |
| --- | --- |
| Stage 0 (stock facts, restore assets R1-R5) | Done [V: NOTES 2026-11-16] |
| M1a: RAM-only first light, K1/K2 | Done [V: NOTES 2026-11-16 evening] |
| M2 tethered (root on `userdata`) | Done, superseded by M1b [V: NOTES 2026-11-16 night] |
| M1b: K2 on slot B as the default boot, B5 success mark | Done [V: NOTES 2026-11-17 night, B4-B5] |
| K3 (panel, touch, keys, GPU) | On `boot_b` (combo build), boots to Hyprland on the GPU, B5 set [V: NOTES 2026-11-17 midday] |
| Daily K3 (combo + Wi-Fi/BT + P1 gauge) | **The `boot_b` candidate.** Built offline, RAM image ready, not yet booted; flash prepared behind owner go [V: DAILY-K3-PLAN §6; runbook `docs/runbooks/DAILY-K3-RUNBOOK.md`] |
| Neutral `dtbo_b` (DTBO-PLAN) | Parked: ABL rejected v1 (table) and v2 (raw FDT); stock dtbo back [V: DTBO-PLAN §6; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Hardware GL works under combo K3 with the freedreno Mesa (rootfs, not upstream yet) [V: NOTES 2026-11-17 day; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, GNSS, audio, sensors, power, camera, misc) | All plans written (GNSS, camera and misc new; modem refreshed); the five original M5 plans cross-reviewed; nothing run on the phone [V: `device/instantnoodlep/*-M5-PLAN.md`, `GNSS-M5-PLAN.md`, `CAMERA-PLAN.md`, `MISC-HW-PLAN.md`, `M5-REVIEW.md`] |

## The phone right now

- [V] Slot B active, successful, stock `dtbo_b`
  (B5 redone after the second dtbo try). The Arch root on `userdata`
  survived both slot-A fallbacks.
- [V] Rootfs carries Mesa 26.2.4-1.5 (freedreno + Turnip) from
  `inumineq/gpu-mesa-freedreno` and its env.d switch; rollback files in
  `/root/mesa-freedreno/rollback` on the phone.
- [V] `boot_b` holds combo K3 (with the test-only kona patch, learning
  `l-48e0c482`), modules on the rootfs, B5 set: the phone boots straight
  into Hyprland on the GPU. Rollback: K2 `~/android/build/m1b/boot_b.img`.
- [V] No power_supply devices: battery level and charging unknown [I].
- [V] Stays off only with the USB cable out (`off-mode-charge:1`;
  learning `l-838f7998`).
- [V] Network: reverse SOCKS over SSH, clock set by hand (learning `l-5c5f509d`).

## Running workers

None (see `docs/agents/active/`).

## Next

0. Daily K3 (`device/instantnoodlep/DAILY-K3-PLAN.md`): coordinator runs
   Part R of `docs/runbooks/DAILY-K3-RUNBOOK.md` (RAM boot, display, touch,
   GL, Wi-Fi, BT, gauge); then Part F (`flash boot_b` + B5) behind owner
   go. Then implement the BT address unit (DAILY-K3-PLAN §5.3).
1. Owner: upstream proposal for freedreno in the omamobile Mesa (PR of
   `inumineq/gpu-mesa-freedreno`; draft in `~/claude/instantnoodlep/`).
2. Power: battery gauge and charger (POWER-M5-PLAN), the daily-use blocker.
3. A kernel-side answer to the `qcom,kona` root rewrite that upstream can
   take (DTBO-PLAN §6).
4. Cross-review GNSS-M5-PLAN, then continue M5 runbooks in the order M5-REVIEW gives.
