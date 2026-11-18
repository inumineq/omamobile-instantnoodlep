<!-- SPDX-License-Identifier: MIT -->
# REPORT: audio phase 2 driver work (TFA987x codec) — 2026-11-18

Task: upstreamable ASoC codec driver `sound/soc/codecs/tfa987x.c` + DT
binding (`nxp,tfa9874`) for the NXP TFA9874 speaker amps, compile-checked
only, no full kernel builds, no phone. Branch `inumineq/tfa987x`.

## What was delivered

Kernel tree `~/src/l-k3-audio`, new branch `instantnoodlep-k3-tfa987x`
(commit `bf29d8b47`) created on top of `instantnoodlep-k3-audio`
(`edc18c3cd`, PR #82, which already carries the `nxp,tfa987x.yaml` binding
with the `nxp,tfa9874` enum, the two disabled TFA9874 nodes on i2c15 with
reset GPIO91/99 and VDDD `vreg_s4a_1p8`):

- `sound/soc/codecs/tfa987x.c` (GPL-2.0-only): ASoC codec driver for
  `nxp,tfa9872/9873/9874` with:
  - reset GPIO (active-high) and `vddd` supply handling (managed, with a
    devm action that silences the amp, asserts reset, then disables VDDD);
  - chip revision validated against the compatible (die byte 0x72/73/74);
  - after the I2C soft reset, every managed register written as a full
    16-bit safe default (powered down, amp off, boost off at reset
    defaults, 16-bit single-slot TDM on the `sound-channel` slot) — no
    uninitialized field can be read or written (fixes the community
    driver's uninitialized-DCDC defect by removing the boost DT ABI
    entirely, as the binding already does);
  - amp starts muted with gain 0; `Playback Volume` (raw gain, no dB
    claim) and `Playback Switch` controls; hardware enable requires DAPM
    power + switch + unmuted stream, serialized under a mutex, bus errors
    latched with the amp held in reset until rebind;
  - regmap 8/16 with readable/writeable/volatile ranges (key reg
    write-only, REV read-only + volatile, rbtree cache);
  - component PM suspend (power down) / resume (restore defaults, keep
    user gain).
- Kconfig `SND_SOC_TFA987X`, Makefile entries, MAINTAINERS entry.
- Register field definitions credited to the public GPL-2.0-only community
  `tfa987x.c` (Nura `3c5440e9dd3c`; NXP 2014-2020 register definitions). No
  leaked or decompiled vendor code, no firmware/calibration (rule 5).
- Repo patch copy: `device/instantnoodlep/patches/audio-tfa987x/`
  (0001 patch + README.md); plan section: `AUDIO-M5-PLAN.md` §10.

## Verified offline [V] (omabook, 2026-11-18)

- Compile-check of the single file with clang 23.1.3:
  `make ARCH=arm64 LLVM=1 O=~/android/build/k3-tfa M=sound/soc/codecs tfa987x.o`
  (defconfig + `CONFIG_SND_SOC_TFA987X=m`, `prepare`): exit 0, zero
  errors/warnings, `tfa987x.o` (309872 B) built for aarch64. No full kernel
  build was run.
- Binding: `make ... DT_SCHEMA_FILES=.../nxp,tfa987x.yaml dt_binding_check`
  with dtschema 2026.9: CHKDT, LINT, STYLE, DTEX, DTC [C] all clean, no
  warnings. The binding needed no changes for the driver.
- `scripts/checkpatch.pl --strict` on the patch: 0 errors, 0 warnings,
  0 checks (651 lines).
- `scripts/trail-lite lint`: ok.

## Not verified — needs a phone test [I]

All device behavior: i2c15 probe of 0x34/0x35, revision readout, register
writes, `Top/Bottom Speaker Playback Switch` reading 0 and `Playback
Volume` reading 0 at probe, suspend/resume, and first sound. First sound
stays gated by the PR #82 §9 runbook: phase-2 RAM image, one speaker at a
time, -60 dBFS test PCM, raw gain 0, boost off, separate explicit owner go.
The phase-2 DTS enablement (i2c15 + nodes okay + tertiary-MI2S speaker
link) is not part of this work. No phone was touched; nothing was flashed.

## Links

- Kernel branch: `instantnoodlep-k3-tfa987x` @ `bf29d8b47` in
  `inumineq/linux-omarchy-mobile` (worktree `~/src/l-k3-audio`), on top of
  PR #82's `instantnoodlep-k3-audio` @ `edc18c3cd`.
- Repo PR: this branch (`inumineq/tfa987x`) — patches +
  `AUDIO-M5-PLAN.md` §10 + this REPORT.md.
- Design source: AUDIO-M5-PLAN §8-§9 as updated in PR #82.
