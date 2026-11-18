<!-- SPDX-License-Identifier: MIT -->
# State: where the port stands now

Last updated: 2026-11-18 afternoon (morning session: RAM tests of slim features, packages 0.0.6/1.2/0.1.3 installed, module-tree loss found and fixed), claude on omabook.

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
| Daily2 candidate | [V] Built on macbookpro with clang/LLD 23.1.6, fixed USB peripheral mode, haptics and manual-load charger, `image_size=0x1750000`. [I] RAM qualification pending. Build evidence and checklist in DAILY-K3-PLAN §8. |
| Slim K3 (daily minus foreign-SoC drivers, `-k3-slim-g78f38a2acc99`) | RAM boot passes on omabook clang 23.1.3: `image_size` 0x1720000 (ceiling `0x2b60000`), USB, `running`, panel, msm GL, Wi-Fi, hci0, gauge; modules on the rootfs. Base for new features; not flashed [V: 2026-11-18 RAM test]. the same tree built with MBP Docker clang 19 freezes on the splash (learning 2026-11-18); P2 froze because its `image_size` 0x2b70000 is over the ceiling |
| Slim-all Type-C recovery | [V] Two clang/LLD 23.1.6 candidates built offline with `image_size=0x1780000`. [I] QMP DP-exit recovery and static UTMI for the USB2 hub await T6/T7 in [TYPEC-DP-PLAN §7](../../device/instantnoodlep/TYPEC-DP-PLAN.md#7-recovery-candidates-after-dp-disconnect). |
| Neutral `dtbo_b` (DTBO-PLAN) | Parked: ABL rejected v1 (table) and v2 (raw FDT); stock dtbo back [V: DTBO-PLAN §6; learning `l-48e0c482`] |
| M3 display stack on the device (hardware GL) | Hardware GL works under combo K3 with the freedreno Mesa (rootfs, not upstream yet) [V: NOTES 2026-11-17 day; learning `l-405b6773`] |
| M5 (Wi-Fi/BT, modem, GNSS, audio, sensors, power, camera, misc) | All plans written; the five original M5 plans cross-reviewed [V: `device/instantnoodlep/*-M5-PLAN.md`, `GNSS-M5-PLAN.md`, `CAMERA-PLAN.md`, `MISC-HW-PLAN.md`, `M5-REVIEW.md`]. Audio phase 2: TFA987x codec driver series compile-checked offline (clang 23.1.3, checkpatch/dt_binding_check clean), patches in `device/instantnoodlep/patches/audio-tfa987x/`, plan §10; first sound still phone-gated (PR #82 §9) [V: AUDIO-M5-PLAN §10] |
| M5 Wi-Fi/BT | Daily on `boot_b`: Wi-Fi connects; BT works after `btmgmt public-addr` [V: NOTES 2026-11-17 night]. One persistent phone-local address helper and device package 0.0.4 are proposed in PR #92; phone qualification remains [I] in `DEVICE-PACKAGE-PLAN.md`. |
| M5 modem/GNSS | Kernel candidate rebuilt on slim K3 with omabook clang 23.1.3: branch `instantnoodlep-k3-slim-modem` @ `7dc2ea318807`, release `7.3.0-rc6-instantnoodlep-k3-slim-modem-g7dc2ea318807`, `image_size` 0x1750000 (ceiling 0x2b60000), dtbs_check clean, RAM image `~/android/build/k3-slim-modem-ram/boot-slim-modem.img` [V: MODEM-M5-DELTA §6.2]. No handset test; private EFS/DDR policy still blocks first boot (gates A-C). The earlier MBP clang 19 candidate (`e9ff58528f8b`) is superseded. |
| M5 power | Charger P2 (`slim-p2`, module loaded by hand) passed P2-5..P2-7 in RAM on 2026-11-18: charges from the laptop at SDP 500 mA, 15 min without a STOP, max 29.7 °C, unplug/replug correct. Not on `boot_b`; the daily K3 still does not charge [V: learning 2026-11-18 slim-all] |
| M5 camera (M-CAM1 front IMX471) | `boot-slim-cam.img` hung before the root on 2026-11-18 (no journal, no USB); with the camera stack loaded the combined slim-all kernel died within a minute. Camera stays off; C2-C5 not reached [V: learning 2026-11-18 slim-all] |

## Combined slim-all candidate (2026-11-18, not flashed)

- [V] `instantnoodlep-k3-slim-all` @ `gc30e3f696707` (local `~/src/l-k3-slim-all`, omabook): slim-feat + p2 + typec + cam, plus fixes for typec (`op-sink-microwatt`, i2c15 on, xHCI), haptics on, camera off. RAM image `~/android/build/k3-slim-all-ram/v3/boot-slim-all.img`. Passes R checks, haptics buzz, typec T1/T2, DP picture on a USB-C monitor.
- [V] Blockers before `boot_b`: after DP alt mode the USB gadget dies until reboot (QMP combo PHY init timeout, `ep0out`), and USB2 behind a 4-lane DP monitor does not enumerate (keyboard/mouse). Learning 2026-11-18 slim-all.

## The phone right now

- [V] Daily K3 on `boot_b` again boots in ~9 s with Wi-Fi after its module tree was restored and pinned in `/usr/lib/modules/.omamobile-pinned`; upstream `omamobile-modules-cleanup` had deleted it at 09:10 (learning 2026-11-18 pin). Packages: device 0.0.6-1, shell 0.2.133-1.2, settings 0.1.3-1 (unsigned, `pacman -U`).

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

See `docs/agents/active/`. Vibe workers on omabook: power P2b, kona, misc-hw, audio, sensors, repo review.

## Next

0. Feature kernels on slim K3 are built offline as 5 RAM candidates (P2 charger, misc, audio, sensors, kona; branches `instantnoodlep-k3-slim-p2`/`-feat` in inumineq/linux-omarchy-mobile, images in `~/android/build/k3-slim-p2-ram`/`k3-slim-feat-ram`, runbook `docs/runbooks/SLIM-FEAT-RUNBOOK.md`) [V: NOTES 2026-11-18 evening]. Next: coordinator runs Part R per candidate; camera and modem candidates still need slimming under the image_size ceiling. Daily K3 is on `boot_b`: implement the BT address unit (DAILY-K3-PLAN §5.3); fold further features into daily as they pass RAM tests.
1. Owner: upstream proposal for freedreno in the omamobile Mesa (PR of
   `inumineq/gpu-mesa-freedreno`; draft in `~/claude/instantnoodlep/`).
2. Power: battery gauge and charger (POWER-M5-PLAN), the daily-use blocker.
3. A kernel-side answer to the `qcom,kona` root rewrite that upstream can
   take (DTBO-PLAN §6).
5. Power P2b (charger as a module), then P3 Type-C.
6. Audio phase 1 (worker on macbookpro), kona upstream series (worker `kona`), UI issue drafts (worker on obsidian); modem/GNSS kernel side is built, gates A-C of MODEM-M5-DELTA §6 (stock wiring, packages, private-state policy) are the coordinator's.
7. Disk encryption + boot passphrase / lock-screen PIN (issue #70): plan and USB unlock path merged. The optional static fbdev/evdev passphrase prototype and QMP-driven virtio GPU/tablet test are under review on `inumineq/enc-touch-unlock`; the QEMU gate is open pending a host with QEMU, cryptsetup, and a suitable kernel. No phone work started.

## Offline UI proposals

- [V] Shell edge geometry and Wi-Fi BackLink patch proposals plus three unposted
  issue drafts are in `patches/` and `docs/upstream/`; host applicability/model
  checks passed (details: `docs/upstream/README.md`). [I] Phone verification
  remains pending under `device/instantnoodlep/SHELL-UX-PLAN.md`.
- [V] Device package 0.0.5 proposal adds per-user Foot, app scale exceptions,
  and Hyprland dialog rules to package 0.0.4's BT address helper, descriptor,
  names-only firmware map, uwsm GL selection, proposed shell edge geometry,
  USB0 policy and boot-service masks. The x86 check script is in
  `packages/omamobile-device-instantnoodlep/test/all`; [I] package install,
  udev match, geometry and vconsole behavior remain unverified on the phone.
  PR #92 supersedes #76 and #77; those PRs are closed. PR #79 remains open
  for the shell's phone verification.
- [V] Chromium and app profile implementation plus x86 self-checks are in PR #99. [I] OnePlus UA/scale, per-app exceptions, optional touch/scroll/pinch and Ozone choices await the morning phone survey in `MOBILE-UX-RESEARCH.md`; no phone testing was done.
- [V] Signed local pacman-repo tooling, an ALARM rebuild recipe for Mesa/shell/device packages, and x86 dummy-package signing tests are in PR #111. [I] Owner-key creation and phone repo switch/rollback are documented but not run; no phone or real key was used.
- [V] Unsigned morning package set built 2026-11-18 on macbookpro in the `k3arch` ALARM container (check() passed for each): `omamobile-device-instantnoodlep 0.0.6-1`, `omamobile-shell 0.2.133-1.2` (upstream `c462357` + patches 0001-0004), `omamobile-settings 0.1.3-1` (security patch, incl. two check() fixes found by the build); archives + `SHA256SUMS` in `~/android/build/arm-pkgs-20261118/` on omabook; owner-attended install runbook in `docs/runbooks/MORNING-PKG-RUNBOOK.md`; the localrepo manifest carries these versions. [V] Installed on the phone 2026-11-18. Shell 1.2 broke the launcher (patch 0004 used `anchors.*Margin` on windows); fixed in `0.2.133-1.3` with device `0.0.7-1` (calibrated edge values), both installed, home strip back. See SHELL-UX-PLAN "Launcher regression and fix".
- [V] Dock/desktop plan and Settings 0.1.4 Displays-page patch are proposed in `device/instantnoodlep/DOCK-DESKTOP-PLAN.md` and `patches/omamobile-settings/0002-settings-displays-page.patch`; the fake-monitor backend fixture passes. The full Settings package check could not build on obsidian because `qmake6` is unavailable. [I] Hotplug desktop transition, persistent monitor rule loading and dock USB input remain phone-gated; keyboard/mouse through the display hub depends on task B.
