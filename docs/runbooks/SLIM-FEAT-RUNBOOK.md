<!-- SPDX-License-Identifier: MIT -->
# SLIM-FEAT-RUNBOOK: feature kernels on slim K3, RAM-boot candidates

Built 2026-11-18 (claude on omabook). Five RAM-boot candidates: the pending
feature kernel series (PRs #69, #83, #82, #81, #84) cherry-picked onto the
booting slim K3 base `78f38a2acc99`, each built with clang/LLD 23.1.5 in the
MBP Docker `k3arch` (native aarch64), config = slim `.config` +
per-feature fragment + `olddefconfig`. No phone was accessed; nothing is
flashed; no partition was written. Roles per AGENTS.md rule 1: the
coordinator runs every non-writing step below; feature steps that program
hardware (the charger) keep their own owner gate from the source PR.

Base facts: `device/instantnoodlep/KERNEL-SIZE.md` (hard ceiling
`image_size` <= 0x2b60000, slim boots at 0x1720000), build guardrail
learning `l-e03ff7fe` (clang 23 only; Debian clang 19 freezes).

## Candidates

| # | Branch (inumineq/linux-omarchy-mobile) | Commit | Release `REL` | image_size | Boot image (sha256) |
| --- | --- | --- | --- | --- | --- |
| 1 | `instantnoodlep-k3-slim-p2` | `16aef753f820` | `7.3.0-rc6-instantnoodlep-k3-slim-p2-g16aef753f820` | 0x1720000 | `~/android/build/k3-slim-p2-ram/boot-slim-p2.img` `e64d16af3f1f371a33e8842323cf56427b0dc2b27bc3b7fd0122fd3f88f8e55b` |
| 2 | `instantnoodlep-k3-slim-feat` | `54e78db29e38` (misc) | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g54e78db29e38` | 0x1720000 | `~/android/build/k3-slim-feat-ram/boot-slim-feat-misc.img` `d9d49fbdf008351af63929d6ae1176febe2d5133569669472a0d5354235e64b7` |
| 3 | `instantnoodlep-k3-slim-feat` | `a91c151bd3c7` (+audio) | `7.3.0-rc6-instantnoodlep-k3-slim-feat-ga91c151bd3c7` | 0x1720000 | `~/android/build/k3-slim-feat-ram/boot-slim-feat-audio.img` `dd1167f5f02a98bb43da582331707e226c51d923e597e37f532251f3485d12ff` |
| 4 | `instantnoodlep-k3-slim-feat` | `31f48b0d15b3` (+sensors) | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g31f48b0d15b3` | 0x1740000 | `~/android/build/k3-slim-feat-ram/boot-slim-feat-sensors.img` `d2c063e6ec11cdc73b084da42290834fdb422394b6fd837793d43b83d20edf2d` |
| 5 | `instantnoodlep-k3-slim-feat` | `48f4edd637f6` (+kona) | `7.3.0-rc6-instantnoodlep-k3-slim-feat-g48f4edd637f6` | 0x1720000 | `~/android/build/k3-slim-feat-ram/boot-slim-feat-kona.img` `e4eb5b1b383b89e850605a74e25e7f3bb4d52bcd5a7302f020bae84ee3d64849` |

All five `image_size` values are far under the 0x2b60000 ceiling [V:
`od -An -tx8 -j16 -N8 Image` on each build]. The sensors step adds
0x20000 (the SLPI/SSC fragment's built-ins); all others are byte-identical
in `image_size` to slim because their drivers are `=m` or DTS-only.

Modules tarballs (one top-level `<release>/` dir, `INSTALL_MOD_STRIP=1`,
`build`/`source` links removed, verified 0 in the archive):

| REL | sha256 |
| --- | --- |
| `...-k3-slim-p2-g16aef753f820` | `80150b6c10d7b45ca2b7ea212044dd4d41faa9e317fdc689cac1bfdc32c50c2e` |
| `...-feat-g54e78db29e38` | `96eedf0c2ef864ab61f3d94be70df527554e20ffbe7749a5ebb888008d56283a` |
| `...-feat-ga91c151bd3c7` | `37d5d40a9d7d7395090771383452f10848827b348e077eaea8a70db9c0fe55da` |
| `...-feat-g31f48b0d15b3` | `dd6b54b1c90e0db4673a63a5509dba6f47b48df0154424dd6cd7d5cba3389718` |
| `...-feat-g48f4edd637f6` | `749322537e9225197164ef4aa62e224a06ce797b58048c3480b4ec390ac7bd3f` |

Each boot image was built with `tools/build-instantnoodlep-probe` using
exactly the daily-manifest flags (`--boot 2 --root userdata --debug-shell`,
stock entry-16 overlay with `--ufdt-apply`, shared initramfs root) and read
back by the builder; per-image `Image.gz`/`board.dtb`/modules hashes are in
`<image>.SHA256SUMS` beside each image (`sha256sum -c` passes). Manifests
sit next to the images (`*.manifest.json`).

Offline gates passed per candidate [V]: build rc=0 (clang 23.1.5, `-j10`,
`Image.gz dtbs modules`); `image_size` as above; `CHECK_DTBS=y` on
`qcom/sm8250-oneplus-instantnoodlep.dtb` exit 0, no diagnostics (dtschema
2026.9 venv, local worktree per step); config diff vs the slim `.config`
shows only the feature symbols (§"Config deltas" below).

## Config deltas (vs `~/android/build/k3-slim/.config` after in-container olddefconfig)

- p2: `CONFIG_CHARGER_QCOM_SMB5=m` only (P2b tip: module, no autoload).
  Nothing outside the charger changed [V: `cfgdiff` on the build host].
- misc: `CONFIG_INPUT_AW8695_HAPTICS=m` only.
- audio: none (phase 1 is DTS-only; the slim config already keeps the QCOM
  audio symbols as `=m`).
- sensors: the in-tree `kernel/configs/instantnoodlep-sensors.config`
  (`QCOM_Q6V5_PAS/FASTRPC/PD_MAPPER/QRTR/QRTR_SMD/SYSMON/PDR_MSG/
  QMI_HELPERS/PIL_INFO/RPROC_COMMON/Q6V5_COMMON/RPMSG_QCOM_GLINK_SMEM/
  IIO_KFIFO_BUF/IIO_TRIGGERED_BUFFER` `=y`; `QCOM_PDR_HELPERS` stays
  select-driven `=m`).
- kona: none (code-only fallbacks in already-enabled drivers).
- All: `CONFIG_LOCALVERSION` pinned to the per-step release string and
  `LOCALVERSION_AUTO` off (the build tree on the MBP has no git, so `-g<sha>`
  cannot be appended; the pinned string reproduces it exactly).

## Part R: RAM boot and checks (per candidate)

Run `docs/runbooks/DAILY-K3-RUNBOOK.md` **Part R (R0-R9)** with the
candidate's `IMG`, `MOD`, `REL` from the tables above (R0.1: `sha256sum -c`
in the image's directory; R0.2: push the candidate's modules tarball,
`tar --zstd -xf ... -C /usr/lib/modules; depmod $REL`). Expect exactly the
slim/daily results — the slim base must not lose panel, touch, GPU, Wi-Fi,
BT, gauge, UFS or USB. Stop conditions per KERNEL-SIZE §5.3: `image_size`
over the ceiling (already checked offline: none is), any R step failing
that slim passes, no SSH after 2 min. Rollback: the phone reboots to the
installed daily K3 from `boot_b`. After a refused RAM boot, cold-reboot to
the bootloader before the next `fastboot boot`. Record R1-R9 in
`device/instantnoodlep/NOTES.md` ([V], masked). No Part F (flash) exists for
these candidates; that is a separate owner-gated runbook after all R steps
pass.

## Feature sections (each adds its own gated steps on top of Part R)

The probe builder disables every remoteproc and keeps the new misc/audio
nodes disabled in the packed DTB (committed DTS state), so ADSP/SLPI and
the haptics/torch/amp nodes are **off** in all five images as shipped;
enabling them is a staged-DTB coordinator gate per the source plans.

### P2 — slim+P2 charger (`boot-slim-p2.img`)

The tip carries the P2b commit (`DO NOT UPSTREAM: ... load only by hand`):
`qcom_pm8150b_charger.ko` has no `MODULE_DEVICE_TABLE`, udev never autoloads
it, and `&pm8150b_gpios`/`&pm8150b_temp` stay disabled. Boot differs from
slim only by the new SPMI MFD/ADC probes. The charger **programs hardware**,
so it stays on its own branch with its own owner gate. After Part R passes,
follow POWER-M5-PLAN §7.5 (branch `inumineq/power`, PR #69): P2b-0..P2b-6 —
hashes, module staging, RAM boot, watch logs (`instantnoodlep-charge-watch`),
then the **owner go** `modprobe qcom_pm8150b_charger`, cable-in observation
per §7.4 P2-6..P2-8, and stop-by-PID. The built-in P2 freeze is explained by
its `image_size` 0x2b70000 over the ceiling (KERNEL-SIZE §6), not by the
driver; on slim the same series fits at 0x1720000.

### misc — haptics/torch/Hall (`boot-slim-feat-misc.img`)

Follow MISC-HW-PLAN §8.3 (branch `inumineq/misc-hw`, PR #83), steps M2-M4:
baseline slot check; boot a staged DTB variant with `i2c11`+`haptics@5a`
(candidate A) or `pm8150l_flash`+`led-0` (candidate B) enabled via `fdtput`
on a copy of `boot-slim-feat-misc.probe.dtb`, repacked with the same
mkbootimg arguments (never edit the shipped `.img` in place); then
M3a `fftest` one bounded `FF_RUMBLE` (100 ms, magnitude 0x2000), M3b four
`i2cget -y 1 <addr> 0x09` Hall chip-ID reads on 0x0c/0x0d/0x18/0x19, M4 one
bounded `white:flash` test (5%, 3 s, back to 0). Stop/rollback per the
table.

### audio — phase 1 (`boot-slim-feat-audio.img`)

Follow AUDIO-M5-PLAN §7 (branch `instantnoodlep-k3-audio`, PR #82): RAM boot,
read-only diagnostics (`/proc/asound/cards`, `dmesg` for q6/wcd/swr),
optional headset capture under a separate owner go. Phase 1 keeps **no
speaker test** (amps stay disabled; §9 phase-2 runbook governs the first
speaker sound). ADSP is disabled in the shipped probe DTB (builder
disable-all-remoteprocs); the staged-DTB gate is the builder's
`--enable-adsp` opt-in on the audio branch, asserting the exact mapped
firmware name `qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn`.

### sensors — SLPI phase 1 (`boot-slim-feat-sensors.img`)

Follow SENSORS-M5-PLAN §10.2 (branch `inumineq/sensors`, PR #81), gates
S0-S8: offline hash/DTB check; firmware prerequisite `slpi.mbn` at the
firmware.map path; boot construction with SLPI re-enabled in a staged copy
of `boot-slim-feat-sensors.probe.dtb` (`fdtput -t s
/soc@0/remoteproc@5c00000/status okay`), repacked with identical mkbootimg
arguments; preflight slot vars; RAM boot; S5 remoteproc state +
`/dev/fastrpc-sdsp` + S5a one explicit SLPI start if the only failure was
early firmware availability; S6/S7 ephemeral `/run` userspace
(`hexagonrpcd`/`ssccli`/`monitor-sensor` per SENSORS-PACKAGING); S8 restore.
No persist/calibration import.

### kona — root-compatible fallback (`boot-slim-feat-kona.img`)

Follow KONA-ROOT-DESIGN §5.2-5.3 (branch `inumineq/kona-root`, PR #84):
stage the modules into the new release dir only, RAM boot, then read checks
against the installed baseline: `uname -r`, `/proc/device-tree/compatible`
(still shows the vendor kona strings — ABL rewrites the root), `findmnt`,
DRM driver, `journalctl -b -k` for UBWC/PD-mapper/cpufreq lines, and per
`policy*` `scaling_driver` = `qcom-cpufreq-hw` (not `cpufreq-dt`). The
kona probe DTB hash equals the daily one (`d869935b…`): the local revert
restores the `qcom,sm8250` root compatible, so the stock overlay applies
unchanged. Open integration gates from PR #84 stay: PD service registration
and Wi-Fi association are proven only on a candidate that enables them.

## Stop conditions (all candidates)

Any Part R stop condition; any feature step's stop condition in its source
plan; `image_size` over 0x2b60000 (rebuild slimmer before any RAM boot);
any request to flash, set_active, touch `_a`/`super` — out of scope here.
