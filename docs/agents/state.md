<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-17 (night: daily K3 on boot_b, audio phase-1 kernel built offline), claude on omabook.

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
| K3 (panel, touch, keys, GPU) | Superseded on `boot_b` by daily K3; combo stays the rollback image [V: NOTES 2026-11-17 night] |
| Daily K3 (combo + Wi-Fi/BT + P1 gauge) | **On `boot_b`, B5 set**: boots from flash to Hyprland on the GPU, Wi-Fi connected, hci0 present [V: NOTES 2026-11-17 night] |
| Neutral `dtbo_b` (DTBO-PLAN) | Parked: ABL rejected v1 (table) and v2 (raw FDT); stock dtbo back [V: DTBO-PLAN §6; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Hardware GL works under combo K3 with the freedreno Mesa (rootfs, not upstream yet) [V: NOTES 2026-11-17 day; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, GNSS, audio, sensors, power, camera, misc) | All plans written; the five original M5 plans cross-reviewed [V: `device/instantnoodlep/*-M5-PLAN.md`, `GNSS-M5-PLAN.md`, `CAMERA-PLAN.md`, `MISC-HW-PLAN.md`, `M5-REVIEW.md`] |
| M5 Wi-Fi/BT | Daily on `boot_b`: Wi-Fi connects; BT works after `btmgmt public-addr` (persistent address unit still to implement, DAILY-K3-PLAN §5) [V: NOTES 2026-11-17 night] |
| M5 modem/GNSS | Kernel candidate built offline: PCIe2/MHI endpoint, GIC MBI route, bounded image-only Sahara loader, fragment merged; series in `patches/instantnoodlep/kernel-modem/` [V: MODEM-M5-DELTA §6]. No handset test; private EFS/DDR policy still blocks first boot. |
| M5 power | P1 gauge works on a RAM boot; P2 charger image hangs early at boot (P2b in progress); no charging under any of our kernels [V: POWER-M5-PLAN §7.3-7.4] |
| M5 camera (M-CAM1 front IMX471) | Kernel series built and offline-verified: release `7.3.0-rc6-instantnoodlep-k3-camera-g70d0761d1`, clean checkpatch/dt_binding_check/dtbs_check, one IMX471 on CCI1 master 1 to CSIPHY3 in the DTB [V: CAMERA-PLAN §9.4]. No RAM boot or frame yet; coordinator gates C0-C5 pending. |
| M5 audio | Phase 1 kernel delta (ADSP + WCD9385 + VA DMIC + q6 card, amps disabled) built offline on `instantnoodlep-k3-audio`, release `7.3.0-rc6-instantnoodlep-k3-gedc18c3cd5c4`; no handset test yet [V: AUDIO-M5-PLAN §3 build record]. Phase 2 (TFA987x driver, speaker link) designed, not implemented [V: AUDIO-M5-PLAN §8-§9] |

## The phone right now

- [V] Slot B active, successful, stock `dtbo_b`
  (B5 redone after the second dtbo try). The Arch root on `userdata`
  survived both slot-A fallbacks.
- [V] Rootfs carries Mesa 26.2.4-1.5 (freedreno + Turnip) from
  `inumineq/gpu-mesa-freedreno` and its env.d switch; rollback files in
  `/root/mesa-freedreno/rollback` on the phone.
- [V] `boot_b` holds daily K3 (`-g78f38a2acc99`, modules on the rootfs), B5 set
  2026-11-17 22:10: boots straight into Hyprland on the GPU with Wi-Fi.
  Rollback: combo `~/android/build/k3-combo-ram/boot-r3-gpu.img`, then B5.
- [V] The phone does not charge under our kernels (USB holds it at 0 mA; daily has the bq27411 gauge, no charger driver) [V: POWER-M5-PLAN §7.3].
- [V] Stays off only with the USB cable out (`off-mode-charge:1`;
  learning `l-838f7998`).
- [V] Network: Wi-Fi under daily (NTP); USB SSH as before. UFW blocks SSH on `wlp1s0`.

## Running workers

See `docs/agents/active/`. Vibe workers on omabook: power P2b, kona, misc-hw, sensors, repo review.

## Next

0. Daily K3 is on `boot_b`: implement the BT address unit (DAILY-K3-PLAN §5.3); fold further features into daily as they pass RAM tests.
1. Owner: upstream proposal for freedreno in the omamobile Mesa (PR of
   `inumineq/gpu-mesa-freedreno`; draft in `~/claude/instantnoodlep/`).
2. Power: battery gauge and charger (POWER-M5-PLAN), the daily-use blocker.
3. A kernel-side answer to the `qcom,kona` root rewrite that upstream can
   take (DTBO-PLAN §6).
5. Power P2b (charger as a module), then P3 Type-C.
6. Audio: coordinator RAM-boots the phase-1 image (AUDIO-M5-PLAN §7), then phase 2 driver and the quiet speaker gate (§9). Kona upstream series (worker `kona`), UI issue drafts (worker on obsidian); modem/GNSS kernel side is built, gates A-C of MODEM-M5-DELTA §6 (stock wiring, packages, private-state policy) are the coordinator's.
7. Backlog: disk encryption + boot passphrase / lock-screen PIN (issue #70).

## Offline UI proposals

- [V] Shell edge geometry and Wi-Fi BackLink patch proposals plus three unposted
  issue drafts are in `patches/` and `docs/upstream/`; host applicability/model
  checks passed (details: `docs/upstream/README.md`). [I] Phone verification
  remains pending under `device/instantnoodlep/SHELL-UX-PLAN.md`.
