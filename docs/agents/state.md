<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-17 (evening: patched shell package built offline), claude on macbookpro.

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
| Neutral `dtbo_b` (DTBO-PLAN) | Parked: ABL rejected v1 (table) and v2 (raw FDT); stock dtbo back [V: DTBO-PLAN §6; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Hardware GL works under combo K3 with the freedreno Mesa (rootfs, not upstream yet) [V: NOTES 2026-11-17 day; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, GNSS, audio, sensors, power, camera, misc) | All plans written; the five original M5 plans cross-reviewed [V: `device/instantnoodlep/*-M5-PLAN.md`, `GNSS-M5-PLAN.md`, `CAMERA-PLAN.md`, `MISC-HW-PLAN.md`, `M5-REVIEW.md`] |
| M5 Wi-Fi/BT | Works on a RAM boot of k3-wifi2: Wi-Fi associated (owner's network, NTP synced), BT scan finds devices after `btmgmt public-addr` [V: NOTES 2026-11-17 afternoon]; not on `boot_b` yet (daily kernel) |
| M5 modem/GNSS | Kernel candidate built offline: PCIe2/MHI endpoint, GIC MBI route, bounded image-only Sahara loader, fragment merged; series in `patches/instantnoodlep/kernel-modem/` [V: MODEM-M5-DELTA §6]. No handset test; private EFS/DDR policy still blocks first boot. |
| M5 power | P1 gauge works on a RAM boot; P2 charger image hangs early at boot (P2b in progress); no charging under any of our kernels [V: POWER-M5-PLAN §7.3-7.4] |
| M5 camera (M-CAM1 front IMX471) | Kernel series built and offline-verified: release `7.3.0-rc6-instantnoodlep-k3-camera-g70d0761d1`, clean checkpatch/dt_binding_check/dtbs_check, one IMX471 on CCI1 master 1 to CSIPHY3 in the DTB [V: CAMERA-PLAN §9.4]. No RAM boot or frame yet; coordinator gates C0-C5 pending. |

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
- [V] No power_supply devices under combo K3; the phone does not charge under our kernels (USB holds it at 0 mA) [V: POWER-M5-PLAN §7.3].
- [V] Stays off only with the USB cable out (`off-mode-charge:1`;
  learning `l-838f7998`).
- [V] Network: reverse SOCKS over SSH under combo K3, clock set by hand (learning `l-5c5f509d`); Wi-Fi only under the k3-wifi kernels.

## Running workers

See `docs/agents/active/` (power P2b, daily, kona on omabook; audio on macbookpro; shell-ux, modem-impl on obsidian).

## Next

1. Owner: upstream proposal for freedreno in the omamobile Mesa (PR of
   `inumineq/gpu-mesa-freedreno`; draft in `~/claude/instantnoodlep/`).
2. Power: battery gauge and charger (POWER-M5-PLAN), the daily-use blocker.
3. A kernel-side answer to the `qcom,kona` root rewrite that upstream can
   take (DTBO-PLAN §6).
4. Daily kernel = combo + Wi-Fi/BT + P1 gauge as the `boot_b` candidate (worker `daily`).
5. Power P2b (charger as a module), then P3 Type-C.
6. Audio phase 1 (worker on macbookpro), kona upstream series (worker `kona`), UI issue drafts (worker on obsidian); modem/GNSS kernel side is built, gates A-C of MODEM-M5-DELTA §6 (stock wiring, packages, private-state policy) are the coordinator's.
7. Backlog: disk encryption + boot passphrase / lock-screen PIN (issue #70).

## Offline UI proposals

- [V] Shell edge geometry and Wi-Fi BackLink patch proposals plus three unposted
  issue drafts are in `patches/` and `docs/upstream/`; host applicability/model
  checks passed (details: `docs/upstream/README.md`). [I] Phone verification
  remains pending under `device/instantnoodlep/SHELL-UX-PLAN.md`.
- [V] The patched package for that plan's step 3 is built offline:
  `omamobile-shell-0.2.133-1.1-any.pkg.tar.zst` (sha256 `4ab37382…4ec955`,
  `~/vibe-runs/shellpkg/out/` on macbookpro) from upstream `c462357` with
  patches 0001-0003; `test/all` passes in the ALARM container. [V] The shell is
  not a systemd unit: `omarchy-restart-shell` restarts it, and the geometry goes
  in with `hyprctl eval 'hl.env(...)'` (learning `l-7cf2b6a8`). [I] Nothing is
  installed on the phone; steps 3-6 are the coordinator's.
