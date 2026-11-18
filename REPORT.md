<!-- SPDX-License-Identifier: MIT -->
# REPORT: feature kernels on slim K3 — RAM-boot candidates (2026-11-18, claude on omabook)

Scope: cherry-pick the pending feature series (PRs #69 power, #83 misc,
#82 audio, #81 sensors, #84 kona) onto the booting slim K3 base
`78f38a2acc99`, build one kernel + one RAM image per step on the MBP Docker
`k3arch` (clang/LLD 23.1.5, native aarch64, `make ARCH=arm64 LLVM=1 -j10
Image.gz dtbs modules`), check `image_size` and `dtbs_check`, and package
modules tarball + probe RAM image + sha256 + runbook per step. No phone
access, no flashing. Kernel branches pushed to
`inumineq/linux-omarchy-mobile`: `instantnoodlep-k3-slim-p2` @ `16aef753f820`,
`instantnoodlep-k3-slim-feat` @ `48f4edd637f6` (step tips `54e78db29e38`,
`a91c151bd3c7`, `31f48b0d15b3`, `48f4edd637f6`).

## Results per image

| Step | Release | image_size (ceiling 0x2b60000) | build rc | dtbs_check | Boot image | sha256 (img) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 slim+P2 | `7.3.0-rc6-instantnoodlep-k3-slim-p2-g16aef753f820` | 0x1720000 | 0 | clean | `~/android/build/k3-slim-p2-ram/boot-slim-p2.img` | `e64d16af3f1f371a33e8842323cf56427b0dc2b27bc3b7fd0122fd3f88f8e55b` |
| 2 +misc | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g54e78db29e38` | 0x1720000 | 0 | clean | `~/android/build/k3-slim-feat-ram/boot-slim-feat-misc.img` | `d9d49fbdf008351af63929d6ae1176febe2d5133569669472a0d5354235e64b7` |
| 3 +audio | `7.3.0-rc6-instantnoodlep-k3-slim-feat-ga91c151bd3c7` | 0x1720000 | 0 | clean | `~/android/build/k3-slim-feat-ram/boot-slim-feat-audio.img` | `dd1167f5f02a98bb43da582331707e226c51d923e597e37f532251f3485d12ff` |
| 4 +sensors | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g31f48b0d15b3` | 0x1740000 | 0 | clean | `~/android/build/k3-slim-feat-ram/boot-slim-feat-sensors.img` | `d2c063e6ec11cdc73b084da42290834fdb422394b6fd837793d43b83d20edf2d` |
| 5 +kona | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g48f4edd637f6` | 0x1720000 | 0 | clean | `~/android/build/k3-slim-feat-ram/boot-slim-feat-kona.img` | `e4eb5b1b383b89e850605a74e25e7f3bb4d52bcd5a7302f020bae84ee3d64849` |

Artefacts per step (all beside the boot image; `sha256sum -c <img>.SHA256SUMS`
passes): `Image-*.gz` / `Image.gz`, `board-*.dtb` / `board.dtb`,
`modules-<REL>.tar.zst` (INSTALL_MOD_STRIP=1, `build`/`source` links removed —
verified 0 entries), `*.manifest.json`, `*.probe.dtb`,
`*.initramfs.cpio.gz`, `.config-*` (the built .config). Modules sha256:
p2 `80150b6c10d7…32c50c2e`, misc `96eedf0c2ef8…d56283a`, audio
`37d5d40a9d7d…fe55da`, sensors `dd6b54b1c90e…3389718`, kona
`749322537e92…c7bd3f` (full lines in each `.SHA256SUMS`). RAM images built
with `tools/build-instantnoodlep-probe` using exactly the boot-daily
manifest flags (`--boot 2 --root userdata --debug-shell`, entry-16 stock
overlay + `--ufdt-apply`); builder read-back passed for all five.

## Config deltas vs the slim `.config` (post-olddefconfig diff, clang 23.1.5)

- p2: `CONFIG_CHARGER_QCOM_SMB5=m` only — nothing outside the charger changed.
- misc: `CONFIG_INPUT_AW8695_HAPTICS=m` only.
- audio, kona: no delta (audio phase 1 is DTS-only; kona is code-only).
- sensors: the in-tree `kernel/configs/instantnoodlep-sensors.config` =y set
  (Q6V5_PAS, FASTRPC, PD_MAPPER, QRTR(+SMD), SYSMON, PDR_MSG, QMI_HELPERS,
  PIL_INFO, RPROC_COMMON, Q6V5_COMMON, RPMSG_QCOM_GLINK_SMEM, IIO_KFIFO_BUF,
  IIO_TRIGGERED_BUFFER) — this is the +0x20000 of image_size.
- All steps: `CONFIG_LOCALVERSION` pinned to the per-step release string,
  `LOCALVERSION_AUTO` off (no git in the container). Toolchain-version lines
  (CC_VERSION_TEXT etc.) differ from the laptop-built slim config — expected.

## Dropped or failed

- Nothing failed: all five builds rc=0, all `image_size` under the ceiling,
  all `dtbs_check` clean, all five probe images read back OK.
- Dropped from the P2 merge on purpose: the debug/panic options that
  `k3-power-p2b/.config` carries vs daily (`PANIC_ON_OOPS`, lockup/hung-task
  detectors with panic) — those were the power worker's hang-diagnostics
  config, not charger config; the runbook points at POWER-M5-PLAN §7.5 if a
  hang is ever diagnosed on this candidate.
- Dropped from the cherry-pick: the gauge commit `11fedfae5` (already in the
  slim base as `78f38a2ac`); conflicts were only the DTS `aliases` hunks
  (daily's `serial1` vs the features' `i2c1`/battery node) — resolved by
  keeping both sides; no feature content was dropped.
- Out of scope / not retried: camera (0x2cd0000) and the modem candidate still
  exceed the ceiling on the fat config and were not part of this task;
  P2 built-in (`=y`) was not built — only the P2b module tip, per the branch.
- Process note: the first container prep copied the base tree over the
  per-step file tars (modified files reverted); caught by the config diff
  (charger symbol missing), fixed by re-extracting after the copy.

## Docs

- `docs/runbooks/SLIM-FEAT-RUNBOOK.md`: candidate table, Part R reuse
  (DAILY-K3-RUNBOOK R0-R9 with per-candidate IMG/MOD/REL), stop conditions,
  and each feature's own gated steps from its PR (#69 §7.5, #83 §8.3 M2-M4,
  #82 AUDIO-M5-PLAN §7, #81 §10.2 S0-S8, #84 §5.2-5.3).
- `device/instantnoodlep/NOTES.md` 2026-11-18 evening entry; `docs/agents/state.md`
  next-step updated; learning
  `.trail/learnings/2026-11-18-feature-kernels-fit-on-slim-k3-claude.md`.
- No RAM boot was run (no phone access in this task); the candidates are
  ready for the coordinator's gated Part R.
