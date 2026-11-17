<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-17 (afternoon), claude on omabook.

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
| Neutral `dtbo_b` (DTBO-PLAN) | Failed: ABL rejected it, rolled back to stock [V: laptop session 2026-11-17; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Open: Hyprland runs on llvmpipe (`LIBGL_ALWAYS_SOFTWARE=1`), no freedreno in the omamobile Mesa [V: NOTES 2026-11-17; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, audio, sensors, power) | Plans written and cross-reviewed, nothing run [V: `device/instantnoodlep/*-M5-PLAN.md`, `M5-REVIEW.md`] |

## The phone right now

- [V] Slot B active and marked successful again, after today's fallback:
  neutral `dtbo_b` rejected by ABL, slot B marked unbootable, the phone fell to
  slot A and stopped in stock recovery; then stock `dtbo_b` flashed back,
  `set_active b`, B5 mark redone (laptop session 2026-11-17; NOTES entry
  pending).
- [I] Whether the Arch root on `userdata` survived the slot-A recovery stop:
  check before the next boot test (learning `l-f3c8caea`).
- [V] `boot_b` holds K2; K3 is RAM-boot only (`fastboot boot`).
- [V] Stays off only with the USB cable out (learning `l-838f7998`).
- [V] Network: reverse SOCKS over SSH, clock set by hand (learning `l-5c5f509d`).

## Running workers

See `docs/agents/active/`. As of this update: `gpu-mesa` (macbookpro, Mesa
with freedreno) and `abl-dtbo` (obsidian, what ABL needs from a dtbo).

## Next

1. NOTES entry for today's dtbo fallback and rollback (facts from the laptop
   session).
2. Check `userdata` after the fallback; then decide the dtbo route from the
   `abl-dtbo` research (or keep the kona patch for now).
3. Hardware GL once `gpu-mesa` has a package: install on the phone, drop
   `LIBGL_ALWAYS_SOFTWARE=1`.
4. M5 runbooks, in the order M5-REVIEW gives.
