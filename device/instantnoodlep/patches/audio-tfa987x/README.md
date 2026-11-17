<!-- SPDX-License-Identifier: MIT -->
# TFA987x speaker-amplifier kernel series (audio phase 2 driver)

[V] Apply the single patch in filename order to the kernel branch
`instantnoodlep-k3-audio` (`edc18c3cd`, PR #82) in `inumineq/linux-omarchy-mobile`
(worktree `~/src/l-k3-audio`); the series branch is `instantnoodlep-k3-tfa987x`
(commit `bf29d8b47`). The DT binding `nxp,tfa987x.yaml` with the
`nxp,tfa9874` enum is already part of that base (`edc18c3cd`); this series
adds only the codec driver plus its Kconfig/Makefile/MAINTAINERS entries.

[V] The driver targets the two TFA9874 amplifiers on i2c15 (0x34 reset
GPIO91, 0x35 reset GPIO99, VDDD = `vreg_s4a_1p8`) staged as disabled nodes
in the board DTS at the base commit. It programs the chips directly over
I2C: managed VDDD + active-high reset GPIO, revision validated against the
compatible, all managed registers written to safe full-register defaults
after the I2C soft reset, amp starts muted with gain 0, raw
`Playback Volume` + `Playback Switch` controls, enable gated on DAPM power
+ switch + unmuted stream under a mutex, latched bus fault with reset
assert, regmap readable/writeable/volatile ranges, component suspend/resume,
silence-before-reset/VDDD on unbind. The boost converter stays disabled at
reset defaults; no boost DT ABI is exposed (PR #82 AUDIO-M5-PLAN §8).

[V] Register field definitions follow the public GPL-2.0-only community
driver `tfa987x.c` (gitlab.nura.eco soc/qualcomm-sm8250/linux @
`3c5440e9dd3c`), which credits the NXP tfa98xx register definitions
(Copyright 2014-2020 NXP Semiconductors). No vendor firmware, calibration
data or decompiled code is included (AGENTS.md rule 5).

## Offline gates (all run 2026-11-18 on omabook, clang 23.1.3, dtschema 2026.9)

```sh
cd ~/src/l-k3-audio
export O=~/android/build/k3-tfa
make ARCH=arm64 LLVM=1 O=$O defconfig
./scripts/config --file $O/.config -e SND -m SND_SOC -m SND_SOC_TFA987X
make ARCH=arm64 LLVM=1 O=$O olddefconfig
make ARCH=arm64 LLVM=1 O=$O prepare
# compile-check of the single file only (no full kernel build):
make ARCH=arm64 LLVM=1 O=$O M=sound/soc/codecs tfa987x.o        # exit 0, no warnings
# binding check:
PATH=<dtschema-venv>/bin:$PATH make ARCH=arm64 LLVM=1 O=$O \
  DT_SCHEMA_FILES=Documentation/devicetree/bindings/sound/nxp,tfa987x.yaml \
  dt_binding_check                                               # CHKDT/LINT/STYLE/DTEX/DTC clean
# style:
git format-patch -1 --stdout | scripts/checkpatch.pl --strict -  # 0 errors, 0 warnings, 0 checks
```

Results: `tfa987x.o` built for `--target=aarch64-linux-gnu` with zero
errors/warnings; `dt_binding_check` clean (CHKDT, LINT, STYLE, DTEX,
DTC [C]); checkpatch `--strict` 0/0/0 over 651 lines.

[I] Not verified here: probe/revision on the real chips, register writes,
control enumeration, suspend/resume and first sound. Those stay gated by
AUDIO-M5-PLAN (PR #82) §9: RAM boot, one speaker at a time, -60 dBFS test
PCM, raw gain 0, boost off, separate explicit owner go. The phase-2 DTS
enablement (i2c15 + both nodes `okay` + tertiary-MI2S speaker link) is not
part of this series.
