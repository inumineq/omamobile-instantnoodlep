<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-17 (day, after the GPU test), claude on omabook.

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
| K3 (panel, touch, keys, GPU) | RAM-boots: panel 1440x3168@120 on DSI-1, s6sy761 touch, power and volume keys, A650 renders as FD650 with ALARM Mesa [V: NOTES 2026-11-17 early morning]. Not flashed. |
| Neutral `dtbo_b` (DTBO-PLAN) | Parked: ABL rejected v1 (table) and v2 (raw FDT); stock dtbo back [V: DTBO-PLAN §6; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Hardware GL works under combo K3 with the freedreno Mesa (rootfs, not upstream yet) [V: NOTES 2026-11-17 day; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, audio, sensors, power) | Plans written and cross-reviewed, nothing run [V: `device/instantnoodlep/*-M5-PLAN.md`, `M5-REVIEW.md`] |

## The phone right now

- [V] Slot B active, successful, K2 on `boot_b`, stock `dtbo_b`
  (B5 redone after the second dtbo try). The Arch root on `userdata`
  survived both slot-A fallbacks.
- [V] Rootfs carries Mesa 26.2.4-1.5 (freedreno + Turnip) from
  `inumineq/gpu-mesa-freedreno` and its env.d switch; rollback files in
  `/root/mesa-freedreno/rollback` on the phone.
- [V] K3 is RAM-boot only; the combo image (with the kona patch) is the one
  with a working display stack (learning `l-48e0c482`).
- [V] Stays off only with the USB cable out (`off-mode-charge:1`;
  learning `l-838f7998`).
- [V] Network: reverse SOCKS over SSH, clock set by hand (learning `l-5c5f509d`).

## Running workers

None (see `docs/agents/active/`).

## Next

1. Owner: upstream proposal for freedreno in the omamobile Mesa (PR of
   `inumineq/gpu-mesa-freedreno`; draft in `~/claude/instantnoodlep/`).
2. Flash K3 to `boot_b` (M3 in the morning runbook): the combo build, since
   the clean one needs the dtbo fix; B5 after.
3. A kernel-side answer to the `qcom,kona` root rewrite that upstream can
   take (DTBO-PLAN §6).
4. M5 runbooks, in the order M5-REVIEW gives.
