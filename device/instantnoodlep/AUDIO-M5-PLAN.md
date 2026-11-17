<!-- SPDX-License-Identifier: MIT -->
# AUDIO-M5-PLAN: sound on instantnoodlep (ADSP remoteproc + WCD938x + amps)

House-rule-6 gate for the **audio** subsystem of milestone **M5** of the
wayfinder map ("wayfinder:map — Omarchy Mobile port for instantnoodlep
(OnePlus 8 Pro IN2023), M1-M5"). This file is a plan only. No code, DTS or
config is written here; nothing in the audio subsystem is touched before
this plan exists with its gated runbook (AGENTS.md rule 6).

- Date: 2026-11-17. Branch: `m5-plans` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md` + `firmware.map`,
  `device/instantnoodlep/DISPLAY-M3-PLAN.md` (style template),
  `device/instantnoodlep/NOTES.md`.
- Scope: ADSP remoteproc (`qcom_q6v5_pas`), the q6 DSP audio services and
  the SM8250 sound card (machine driver `sm8250.c`, q6afe/q6asm/q6adm — not
  audioreach, §3.1), the WCD938x codec on SoundWire, LPASS macros, speaker
  amplifiers, DMICs, earpiece, USB-C headphones, alsa-ucm-conf profile,
  pipewire/wireplumber. CDSP/SLPI decision in §3.8. All M5 phone steps are
  `fastboot boot` (RAM) first; the installed slot-B system is only booted,
  never written.
- Safety model unchanged: no write to `super`, any `_a` partition, `vbmeta`,
  `devinfo`, `persist`, `efs*`, `modem*` or bootloader/radio partitions
  (AGENTS.md rule 3). Firmware comes from the owner's own OTA at install
  time per `firmware.map`, never from git (rule 8).
- Current boot prerequisite: **stock DTBO stays installed**. [V: learning
  `l-48e0c482`, DTBO-PLAN §6] Neutral DTBO was rejected by ABL and must not
  be retried. K3-combo carries the temporary `qcom,kona` machine-table match
  including `qcom_pd_mapper.c`; this is a private bring-up dependency, not
  an upstream candidate. [V: kernel `aa996bae0`, drivers/soc/qcom/qcom_pd_mapper.c:661]
  Live root compatibility will therefore be `qcom,kona-mtp`, `qcom,kona`,
  `qcom,mtp`, while the input board DTB retains its mainline identity.

## 1. Source pins

- `L/` = the kernel tree at `~/src/l`, branch `instantnoodlep-k2` @
  `a28aaf1a09db` (linux-omarchy-mobile `317d87dc2db0` + the four K2 DTS
  commits; kernelrelease `7.3.0-rc6-instantnoodlep-k2-ga28aaf1a09db`)
  [V: NOTES.md 2026-11-16 R7]. All `L/` line references are valid at this
  commit. Its base is upstream `317d87dc2db0c3580be70a9c6341ca1fbd0a762a`
  [V: DTS-PORT-PLAN §1].
- `E/` = decompiled stock dtbo **entry 16** ("kona MTP 19811",
  `oplus,dtsi_no = 0x4d63`; 19811 is this project) at
  `~/android/build/p3/entry16.dts`, 15975 lines, produced offline from the
  verified `.591` OTA [V: NOTES.md 2026-11-16 (morning) P3]. Facts only:
  GPIOs, rails, addresses, compatibles; no vendor code is copied.
- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (FIRMWARE-PLAN pin), read locally at `~/src/omarchy-mobile`.
- `C/` = community SM8250 kernel
  `gitlab.nura.eco/soc/qualcomm-sm8250/linux` @ `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9`
  (pinned in DTS-PORT-PLAN §1). **Not opened in this session** (no network
  here): every C/-dependent claim below is [I] until the tree is fetched.
- `D/` = public Nura/OnePlus 8 Pro sources; `docs/audio.md` and the main README
  were checked during review. `alsa-ucm-conf` upstream's generic RB5
  `ucm2/Qualcomm/sm8250/HiFi.conf` was also checked; it is not an
  instantnoodlep-specific profile.
- The pinned Nura kernel `C/` audio tree was still unavailable behind its
  Anubis gate, so C-only node-shape claims remain [I].

## Implementation correction (2026-11-17, authoritative over the historical inventory)

- [V] Public community patch `0005-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Enable-.patch`
  in `darknagel/oneplus-instantnoodlep-nura-unofficial` at
  `4e04b523eefa5494dae95fe374561ced5b781686` identifies **WCD9385**, reset
  TLMM GPIO32 active-low, RX mapping `<1 2 3 4 5>`, TX mapping **`<2 2 3 4>`**.
  Source: <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/4e04b523eefa5494dae95fe374561ced5b781686/kernel-patches/0005-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Enable-.patch>.
- [V] The same public GPL patch identifies **TFA9874**, not TFA989x or WSA881x:
  mainline `i2c15`, top 0x34/GPIO91 active-high, bottom 0x35/GPIO99 active-high,
  S4A VDDD, tertiary MI2S playback (`TERTIARY_MI2S_RX`, SD line 1).
  The board nodes are described but disabled in **phase 1**; no speaker DAI
  link is registered and no speaker test is permitted for this image.
- [V] The patch uses VA DMIC01 + DMIC23, BOB micbias supply and 2.4 MHz;
  its VA routing supplies micbias1/3/4 from WCD9385 for the board microphones.
  This supersedes the generic RB5 600 kHz/S4A assumption below.
- [I] These are published board wiring facts, not verification on this unit.
  Board-specific codec registration, recording, headset routing and all sound
  remain untested until the owner gates below.
- [V] K3 has no TFA987x driver; `tfa989x.c` supports only TFA9890/95/97.
  Phase 2 will add the GPL TFA987x driver/binding separately. Its starting
  register/protocol reference is the public GPL community implementation at
  <https://gitlab.nura.eco/soc/qualcomm-sm8250/linux/-/blob/3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9/sound/soc/codecs/tfa987x.c>.
  It is **not** proprietary firmware or vendor binary code.

The sections below retain the original planning inventory for provenance;
where they describe neutral DTBO, TFA989x/WSA alternatives or generic MTP/RB5
wiring, use this correction and the phase-specific runbook instead.

## 2. Current implementation and phases

| Block | Phase 1 | Phase 2 | Source/evidence |
| --- | --- | --- | --- |
| ADSP | enabled; mapped firmware-name | unchanged | [V: kernel branch `instantnoodlep-k3-audio`, commit `9756a70c4`; firmware.map ADSP row] |
| APR/q6 | classic q6core/AFE/ASM/ADM and audio_pd; frontend DAIs 0–7, WCD RX/TX and VA backend DAIs | tertiary MI2S RX backend | [V: K3 `sm8250.dtsi` ADSP glink edge; commit `229413b9e`] |
| WCD9385 | GPIO32, S4A/BOB supplies, 1.8/2.7/1.8/1.8 V micbias, RX/TX SDW slaves | unchanged | [V: D 0005; kernel `0f34833c2`] |
| LPASS | RX/TX and swr1/swr2 enabled; VA DMIC01/23, BOB, 2.4 MHz | unchanged | [V: D 0005; kernel `f9e85f5de`] |
| Speakers | two factual TFA9874 nodes disabled; i2c15 disabled; **no speaker link**; binding `nxp,tfa987x.yaml` documents the nodes | checked TFA987x module, QUP/i2c15 enabled, speaker link | [V: D 0005; phase-1 kernel `35e0d094d`, binding `edc18c3cd`; I: phase-2 runtime] |
| WSA/swr0, CDSP, SLPI | disabled | disabled | [V: K3 dtsi defaults; no overrides in phase-1 DTS] |
| USB-C analog | no SBU/FSA4480/Type-C changes | unchanged | [V: phase-1 DTS diff; I: physical WCD headset route unavailable until separate USB work] |

[V] Phase 1 kernel commits are based on combo `aa996bae0695`, in an isolated
`~/src/l-k3-audio` git worktree. The published branch is
<https://github.com/inumineq/linux-omarchy-mobile/tree/instantnoodlep-k3-audio>.
The inherited temporary Kona patch is **DO NOT UPSTREAM**; the audio delta
must be rebased onto the clean kernel before any upstream proposal.

[I] Registering the card does not establish sound, mic wiring, codec revision
on this unit or safe playback. Those remain the coordinator/owner gates.
The top speaker as earpiece and USB-C analog path are separate runtime
questions; no claim of working phone-call audio is made here.

## 3. Offline gates (each phase)

1. [V] Source audit: GPL board sources and kernel bindings/drivers above;
   firmware names only. No proprietary files in git; no phone contact.
2. [I] Fresh output directory under `~/android/build/`, `ARCH=arm64 LLVM=1`,
   `nice -n 10` (coordinator subsequently requested effective nice 19 for
   audio), at most `-j4`. Merge arm64 defconfig, upstream
   `kernel/configs/omamobile.config` and this repository's `kernel.config`.
   Verify final `.config` has APR, QRTR/GLINK/PDR, PD mapper, SoundWire,
   SM8250 machine, WCD938x SDW and LPASS RX/TX/VA modules.
3. [I] Build `Image.gz qcom/sm8250-oneplus-instantnoodlep.dtb modules`;
   `modules_install` into a fresh staging directory and archive it with zstd.
   Record the actual `include/config/kernel.release` and hashes, not a guessed
   uname suffix. Keep phase-1 and phase-2 artifacts separate.
4. [I] Board schema check: `make ... CHECK_DTBS=y
   qcom/sm8250-oneplus-instantnoodlep.dtb` (the targeted dtbs_check path).
   Inspect warnings, since dt-validate can print diagnostics with exit zero.
   Stop for any new audio warning. Classify unrelated inherited board warnings
   separately. Phase 2 additionally runs `dt_binding_check
   DT_SCHEMA_FILES=sound/nxp,tfa987x.yaml` and `checkpatch.pl --strict`.
   [V] One new warning is expected and accepted in phase 1, and only this one:
   `nxp,tfa9874` has no binding until phase 2, so dt-validate and checkpatch
   both report the two disabled amplifier nodes as un-documented. The nodes
   carry no DAI link and stay `disabled`, so the warning is a phase-2
   bookkeeping item, not a wiring defect. Any other new audio warning stops
   the phase.
5. [I] DT inspection: mapped ADSP path, WCD9385 + RX `<1 2 3 4 5>` /
   TX `<2 2 3 4>`, correct sound links and phase-specific amp status.
   Every non-ADSP remote processor disabled in the **packaged** probe DTB;
   CDSP/SLPI stay off. Source root is mainline identity; runtime root follows
   the known stock-DTBO rewrite and combo workaround.
6. [V] Builder defaults disable every DSP. Audio explicitly uses
   `--enable-adsp`; it checks the SM8250 PAS compatible and exact mapped
   firmware-name, and rechecks the final packed DTB after boot-image readback.
   Tests cover ADSP-only enablement and rejection of another firmware-name.
   Run `tests/instantnoodlep-probe` with upstream/AOSP paths set; require no skips.
7. [I] Packaging command (fresh `OUT_IMAGE`; never overwrite an earlier image):

```sh
tools/build-instantnoodlep-probe \
  --kernel "$BUILD/arch/arm64/boot/Image.gz" \
  --dtb "$BUILD/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb" \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --mkbootimg ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py \
  --omarchy-mobile ~/src/omarchy-mobile \
  --initramfs-root ~/android/build/initramfs-root \
  --stock-overlay ~/android/build/p3/entry16.dtbo \
  --ufdt-apply ~/android/build/ufdt/ufdt_apply_overlay \
  --boot 2 --root userdata --debug-shell --enable-adsp --out "$OUT_IMAGE"
```

Expect: successful offline overlay apply, boot payload readback, manifest and
SHA256SUMS, ADSP-only DTB, `UFS_RW=userdata` only. Stop: any failure or stale
output name. Rollback: discard only that candidate; no phone was contacted.

### Phase 1 build record (2026-11-17, omabook)

[V] Built offline from `~/src/l-k3-audio` (branch `instantnoodlep-k3-audio`,
HEAD `edc18c3cd`, base combo `aa996bae0`) in a fresh
`~/android/build/k3-audio-p1`, `ARCH=arm64 LLVM=1`, `nice -n 19`, `-j6`.
Kernel release from `include/config/kernel.release`:
`7.3.0-rc6-instantnoodlep-k3-gedc18c3cd5c4`.

| Artefact | Path | Bytes | sha256 |
| --- | --- | --- | --- |
| kernel | `~/android/build/k3-audio-p1/arch/arm64/boot/Image.gz` | 16120307 | see `REPORT.md` |
| board DTB | `~/android/build/k3-audio-p1/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb` | 122762 | see `REPORT.md` |
| modules | `~/android/build/k3-audio-p1-modules.tar.zst` | 21937880 | `ee4599682e887eca87ab6392045c1dd2782d20c93177b2e8058b11c652d11a8b` |
| RAM image | `~/android/build/k3-audio-p1-ram/boot.img` | 24137728 | `c4f706ef0919c8fec009cdd1f7bd2f11f030ca2ffc2e14c9c32008325bb42dfd` |

[V] Gates that passed: `CHECK_DTBS=y qcom/sm8250-oneplus-instantnoodlep.dtb`
with dtschema 2026.9 (no output, exit 0); `dt_binding_check
DT_SCHEMA_FILES=sound/nxp,tfa987x.yaml` (CHKDT, LINT, DTEX, DTC [C], no
warnings); `checkpatch.pl --strict` on the final DTS (0 errors, 0 warnings,
0 checks); `tests/instantnoodlep-probe` (0 skipped). The series still has
cosmetic checkpatch checks in the intermediate commits (blank lines fixed by
the last DTS commit, one over-long commit-message line); the final file is
clean.

[V] Probe DTB read back from the packed image: ADSP `okay` with
`firmware-name = "qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn"`, CDSP and
SLPI `disabled`, `qcom,sm8250-sndcard` with 11 DAI links, WCD9385
`reset-gpios = <&tlmm 32 GPIO_ACTIVE_LOW>`, swr1/swr2 codecs present, i2c15
and both TFA9874 nodes `disabled`, stock overlay applied (156 labels).

## 4. Firmware contract

[V] The ADSP `firmware.map` row is
`modem:/image/adsp.mdt|qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn`.
FIRMWARE-PLAN extraction gates decide the input member layout and reassembly;
never equate an MDT header alone with a complete MBN. The user's verified OTA
is the only vendor source for this candidate. No codec/amp firmware request
is added. CDSP/SLPI rows remain unused by audio.

## 5. Definition of done

[I] Phase 1: offline gates pass, artifacts and matching modules delivered,
coordinator can RAM boot, ADSP runs, q6 services and WCD/VA card register,
`aplay -l` / `arecord -l` list frontends, then a reviewed mic route records.
No speaker claim or speaker test in phase 1. Headset playback is optional,
only if the physical WCD path has separately been established.

[I] Phase 2: driver/binding and board enablement pass strict style/schema/build
gates, a separate RAM candidate is delivered, and the coordinator performs
the explicit low-level speaker gate below. Offline deliverables are complete
without pretending phone tests ran; working audio remains unverified until
redacted runtime results are recorded in NOTES.md by the coordinator.

## 6. Phase 1 userspace outline (draft; no automatic mixer writes)

- [V] Install the owner's OTA `modem:/image/adsp.mdt` plus its associated
  `modem:/image/adsp.b*` segments as the **reassembled**
  `/usr/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn`, exactly
  `firmware.map`'s ADSP row. Never rename the MDT alone into an MBN.
  Extraction/validation belongs to FIRMWARE-PLAN; commit paths only.
- [V] CDSP/SLPI stay disabled. WCD9385 and LPASS macro drivers request no
  external firmware. No TFA firmware is installed by either audio phase.
- [I] Device package layout: `ucm2/OnePlus/instantnoodlep/instantnoodlep.conf`
  (`Syntax 6`, `SectionUseCase.HiFi` loading `HiFi.conf`) and
  `ucm2/conf.d/sm8250/OnePlus 8 Pro.conf` redirecting by the observed ALSA
  card long name. Confirm the actual name using `cat /proc/asound/cards`
  before installing the redirect; do not install a generic sm8250-wide alias.
- [I] `HiFi.conf`: `SectionVerb` selects the observed MultiMedia capture
  frontend, routes `VA Capture` to it, and configures one DMIC at a time;
  `SectionDevice.Mic` exposes only verified capture channel(s). Record exact
  enumerated control names and values from `amixer -c "$CARD" contents` before
  writing EnableSequence/DisableSequence. The published D patch's route
  strings are DAPM widgets, not proven ALSA mixer control names.
- [I] Add `Headphones` only after WCD path validation. Analog USB-C also
  requires SBU/Type-C routing outside phase 1; do not assume physical headset
  insertion works from WCD registration alone. Add `Speaker` only in phase 2.
- [I] PipeWire/WirePlumber should consume the verified UCM profile with
  `omamobile-audio` dependencies. No bring-up service writes mixer settings
  automatically; autoload matching kernel modules through udev/depmod first.

### Files the device package installs (paths only)

| Path on the phone | Source | State |
| --- | --- | --- |
| `/usr/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn` | owner's OTA, `firmware.map` ADSP row, reassembled with pil-squasher | required before the RAM boot |
| `/usr/lib/modules/<release>/` | the phase-1 modules tarball from §3.3 | required, release must equal `uname -r` |
| `/usr/share/alsa/ucm2/OnePlus/instantnoodlep/instantnoodlep.conf` | new, `Syntax 6` | draft only, after the card name is observed |
| `/usr/share/alsa/ucm2/OnePlus/instantnoodlep/HiFi.conf` | new | draft only, after `amixer contents` is recorded |
| `/usr/share/alsa/ucm2/conf.d/sm8250/OnePlus 8 Pro.conf` | new redirect, `Syntax 6` | draft only, filename must match the observed card long name |

- [I] Module autoload order is udev/depmod's, not a script's:
  `qcom_q6v5_pas` (ADSP), `qcom_pd_mapper`, `soundwire_qcom`, `snd_soc_wcd938x_sdw`,
  `snd_soc_lpass_va_macro`, `snd_soc_sm8250`. `modprobe snd_soc_sm8250` last
  pulls the card in; the runbook does this explicitly so a missing module is
  visible instead of silent.
- [V] No firmware file is added to git by this phase, and no UCM file is
  installed by the worker: both are owner/coordinator steps after the runtime
  names are known (rule 8, and §6's "no automatic mixer writes").

### UCM draft (not installed; every value confirmed at runtime)

[V] Upstream `alsa-ucm-conf` already ships the VA-macro control names this
board needs, so the draft reuses them instead of inventing strings:
`/usr/share/alsa/ucm2/codecs/qcom-lpass/va-macro/DMIC0EnableSeq.conf` sets
`VA DEC0 MUX`, `VA DMIC MUX0`, `VA_AIF1_CAP Mixer DEC0` and `VA_DEC0 Volume`,
and `/usr/share/alsa/ucm2/Qualcomm/sm8250/HiFi.conf` wires
`MultiMedia3 Mixer VA_CODEC_DMA_TX_0` to the `VA Capture` frontend. Those are
the same names §8's candidate sequence uses. [V: local alsa-ucm-conf read
2026-11-17; `codecs/qcom-lpass/va-macro/DMIC0EnableSeq.conf`,
`Qualcomm/sm8250/HiFi.conf`, `conf.d/sm8250/Qualcomm-RB5-WSA8815-Speakers-DMIC0.conf`]

[I] The card long name, the PCM index and the DMIC pair are this board's, not
RB5's, so the values below stay placeholders until §7 records them. The
redirect uses an absolute `File` path, as the sm8250 RB5 redirect does.

`/usr/share/alsa/ucm2/OnePlus/instantnoodlep/instantnoodlep.conf`:

```
Syntax 6

SectionUseCase."HiFi" {
	File "HiFi.conf"
	Comment "Default"
}
```

`/usr/share/alsa/ucm2/OnePlus/instantnoodlep/HiFi.conf`:

```
# instantnoodlep phase 1: capture only. No Speaker device before phase 2.
SectionVerb {
	EnableSequence [
		cset "name='MultiMedia3 Mixer VA_CODEC_DMA_TX_0' 1"
	]
	DisableSequence [
		cset "name='MultiMedia3 Mixer VA_CODEC_DMA_TX_0' 0"
	]
	Value {
		TQ "HiFi"
	}
}

SectionDevice."Mic" {
	Comment "Microphone"
	Include.lpassvae.File "/codecs/qcom-lpass/va-macro/DMIC0EnableSeq.conf"
	Include.lpassvad.File "/codecs/qcom-lpass/va-macro/DMIC0DisableSeq.conf"
	Value {
		CapturePriority 100
		CapturePCM "hw:${CardId},2"
	}
}
```

`/usr/share/alsa/ucm2/conf.d/sm8250/OnePlus 8 Pro.conf`:

```
Syntax 6

SectionUseCase."HiFi" {
	File "/OnePlus/instantnoodlep/HiFi.conf"
	Comment "Default"
}
```

- [I] `CapturePCM "hw:${CardId},2"` is RB5's MultiMedia3 index. §7 must confirm
  the index from `arecord -l` before the file is installed; a different index
  means a different `MultiMediaN` mixer name in `SectionVerb` too.
- [I] The redirect filename must equal the observed card long name, which is
  the DTS `model` property (`OnePlus 8 Pro`). `cat /proc/asound/cards` decides
  it; if the observed name differs, rename the file rather than editing the
  DTS to match a guess.
- [V] `DMIC0EnableSeq.conf` sets `VA_DEC0 Volume` to 100, which is +16 dB:
  `SOC_SINGLE_S8_TLV` exposes 0..124 and writes `value - 84` to the register,
  so 84 is 0 dB and 100 is +16 dB. [V: `sound/soc/codecs/lpass-va-macro.c:1312`,
  `sound/soc/soc-ops.c:136-162`] [I] If the include is used unchanged, record
  +16 dB as the reviewed first-capture level instead of editing the shared
  upstream file; the plan's own candidate sequence uses 84 (0 dB).

## 7. Phase 1 coordinator runbook

[V] Worker has no phone access. All commands below are for the coordinator,
with the owner present and explicit go before reboot/RAM boot or sound.
Never flash, change slot, retry neutral DTBO, or boot stock Android.
Private captures stay outside git. The installed combo kernel on boot_b is
rollback; reboot returns to it. [V: docs/agents/state.md]

### Preparation (coordinator, current installed Linux)

1. Owner go to stage the **matching phase-1** modules and the already verified
   owner firmware on the existing rootfs. Command (replace `MODULES` with the
   artifact path in the build record; no literal placeholders):
   `scp "$MODULES" root@172.16.42.1:/tmp/audio-modules.tar.zst`, then
   `ssh root@172.16.42.1 'tar --zstd -xf /tmp/audio-modules.tar.zst -C /; depmod -a RELEASE; test -s /usr/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn'`.
   Expect: correct `/lib/modules/RELEASE`, depmod success, firmware exists.
   Stop: mismatched release, missing firmware or any extraction error.
   Rollback: remove only the newly staged release directory and `/tmp` archive;
   retain existing combo modules and firmware. No block-device writes.
2. Owner go: `ssh root@172.16.42.1 'reboot bootloader'`.
   Expect: bootloader ready. Stop: unexpected UI/stock boot; coordinator handles
   recovery using the existing restore plan. Rollback: boot installed slot B.

### RAM boot and read-only diagnostics

- Command: `fastboot -s "$PHONE_SERIAL" getvar current-slot` and
  `fastboot -s "$PHONE_SERIAL" getvar slot-successful:b`.
  Expect: B, successful yes. Stop: either differs; do not change slots.
  Rollback: no changes; return to coordinator's recovery plan.
- Owner go: `fastboot -s "$PHONE_SERIAL" boot "$AUDIO_P1_IMAGE"`.
  Expect: Booting OKAY and SSH within two minutes. Stop: refusal, hang,
  crash loop or no SSH. Rollback: owner cable out and Power+VolUp force restart,
  return to installed successful slot B; never select stock recovery actions.
- Command: `ssh root@172.16.42.1 'uname -r; modprobe qcom_pd_mapper; modprobe snd_soc_sm8250; modprobe snd_soc_wcd938x_sdw; modprobe snd_soc_lpass_va_macro; modprobe qcom_q6v5_pas; for r in /sys/class/remoteproc/remoteproc*; do cat "$r/name" "$r/state"; done; cat /proc/asound/cards; aplay -l; arecord -l'`.
  Expect [I]: matching release; only ADSP running, q6 card registered, frontend
  playback/capture PCMs listed (BE links need not appear as separate PCMs).
  Stop: module/firmware error, ADSP not running, absent card or crash.
  Rollback: owner-approved `systemctl reboot` to installed combo.
- Command: `ssh root@172.16.42.1 'dmesg | grep -Ei "adsp|q6|apr|soundwire|wcd|snd|firmware"; cat /sys/kernel/debug/devices_deferred; amixer -c 0 contents'`.
  Expect [I]: WCD RX/TX and VA present; no audio deferred probe.
  Stop: wrong codec/firmware, persistent deferral. Rollback: reboot to combo.

### Recording and optional headset (separate owner go)

- Choose `CARD`/`PCM` from `arecord -l` and inspect controls above. The UCM
  outline is deliberately not an executable guessed mixer script.
  Once coordinator has a reviewed exact VA mixer sequence, apply it, then
  `arecord -D "hw:$CARD,$PCM" -f S16_LE -r 48000 -c 2 -d 3 /tmp/audio-p1.wav`.
  Expect [I]: three-second recording with nonzero samples, no XRUN/crash.
  Stop: silence, errors or routing uncertainty. Rollback: restore the saved
  mixer state, remove `/tmp/audio-p1.wav`, reboot to combo.
- Headset playback is optional and blocked until the coordinator verifies a
  physical WCD route/SBU support. With explicit owner go and a reviewed quiet
  route, play a separately attenuated test file with `aplay -D "hw:$CARD,$PCM"
  /tmp/quiet-headset.wav`. Expect [I]: quiet headset-only output. Stop
  immediately on unexpected sound, distortion or route. Rollback: stop aplay,
  restore mixer, reboot. **No speaker test in phase 1**; the only speaker
  gate is §9 (phase 2, separate image and separate owner go).
- Owner go to `systemctl reboot`; expect installed combo release and the same
  B-successful slot flags afterwards. Stop on any slot difference; no automatic
  slot writes or stock boot. Rollback/recovery belongs to the coordinator.

## 8. Phase 2 driver design and source boundary (before implementation)

- [V] Community `tfa987x.c` at C `3c5440e9dd3c` is explicitly
  GPL-2.0-only, credits NXP 2014–2020 register definitions and `tfa9895.c`.
  D patch 0136 at `4e04b523eefa` by Timo supplies a raw gain control and
  independently requested amp switch. Retain those credits; no vendor
  container, calibration bytes or decompiled code is imported.
- [V] Goodix's public TFA9874B datasheet rev 2.1 describes VDDD, reset,
  TDM input and a boost converter, but does not publish the register table:
  <https://www.goodix.com/en/download?objectId=49&objectType=document&version=267>.
  Register field definitions therefore come from the public GPL community
  driver, not an inferred register map. No physical dB conversion is claimed.
- [V] Community source defects found in review: absent optional boost values
  can be read uninitialized; the TFA9873/74 second voltage field is written
  to CTRL0 instead of CTRL6; reset GPIO/VDDD are not acquired; register errors
  are mostly ignored; amp is not independently disabled by default.
- [I] Implement regmap I2C + managed VDDD/reset, validate chip revision against
  compatible, checked register writes, fixed 48 kHz/S16/stereo direct input,
  and left/right slot selection. Initial state: powered down, switch false,
  stream muted, raw gain 0. No boost unless the board explicitly opts in;
  this board supplies no boost override properties. Preserve absent boost
  fields at reset values; present zero is a valid override. Validate all
  provided values before writing any optional boost field.
- [I] Amp enable requires **all three**: DAPM powered, user Playback Switch,
  unmuted playback stream. Serialize those transitions; latch a control-bus
  error off and assert hardware reset, requiring rebind before retry.
  Shutdown/unbind must silence the amp before resetting/removing VDDD.
- [I] New binding exposes bounded, namespaced boost register codes because
  their physical-unit conversion is not documented in these public sources.
  The optional-property ABI needs maintainer review before upstream submission;
  never invent coil-current or voltage conversions. This work remains a
  private bring-up candidate until electrical behavior is verified.
- [I] Phase 2 enables i2c15 and its QUP wrapper, the two TFA9874 nodes and a
  tertiary-MI2S speaker DAI link. Keep WSA macro/swr0 disabled. First sound
  uses a short host-generated PCM at -60 dBFS, raw amp gain 0, boost off,
  one speaker at a time and a separate explicit owner go. No full-scale
  `speaker-test`, automatic gain increase, or unreviewed UCM enable sequence.

### Candidate VA mic sequence (phase 1 or 2; explicit owner go)

[V] Candidate control names follow D's public microphone UCM patch
`0007-oneplus-instantnoodlep-enable-microphones.patch` at `4e04b523eefa`,
checked against K3 `lpass-va-macro.c` and `q6routing.c`. [I] They must all
exist with these enum choices on this card before any write. Select CARD
and PCM from `arecord -l`: this example uses **MultiMedia3**, normally PCM 2;
stop if the device listing differs. Run over the coordinator's SSH session:

```sh
# Set only after inspecting arecord -l; this is not a discovery default.
CARD=0
PCM=2
alsactl -f /tmp/audio-before.state store "$CARD" || exit 1
for control in \
  'MultiMedia3 Mixer VA_CODEC_DMA_TX_0' \
  'VA_AIF1_CAP Mixer DEC0' 'VA_AIF1_CAP Mixer DEC1' \
  'VA DEC0 MUX' 'VA DEC1 MUX' 'VA DMIC MUX0' 'VA DMIC MUX1' \
  'VA_DEC0 Volume' 'VA_DEC1 Volume'; do
  amixer -c "$CARD" cget "name='$control'" || exit 1
done
# Owner go for mic recording and these reviewed mixer writes.
set -e
trap 'alsactl -f /tmp/audio-before.state restore "$CARD"' EXIT
amixer -c "$CARD" cset "name='MultiMedia3 Mixer VA_CODEC_DMA_TX_0'" 1
amixer -c "$CARD" cset "name='VA_AIF1_CAP Mixer DEC0'" 1
amixer -c "$CARD" cset "name='VA_AIF1_CAP Mixer DEC1'" 1
amixer -c "$CARD" cset "name='VA DEC0 MUX'" VA_DMIC
amixer -c "$CARD" cset "name='VA DEC1 MUX'" VA_DMIC
amixer -c "$CARD" cset "name='VA DMIC MUX0'" DMIC2
amixer -c "$CARD" cset "name='VA DMIC MUX1'" DMIC1
amixer -c "$CARD" cset "name='VA_DEC0 Volume'" 84
amixer -c "$CARD" cset "name='VA_DEC1 Volume'" 84
arecord -D "hw:$CARD,$PCM" -f S16_LE -r 48000 -c 2 -d 3 /tmp/audio-mic.wav
```

[V] Volume 84 is the zero-dB code for K3's `SOC_SINGLE_S8_TLV` range -84..40;
D's 108 adds 24 dB and is deliberately not the first capture setting.
Expect [I]: three-second non-silent capture; inspect sample peaks offline
without playing it through a speaker. Stop: any missing control, invalid enum,
write/capture error, ADSP crash, or silence. Rollback: trap restores the saved
mixer state; delete `/tmp/audio-mic.wav` after analysis and reboot to installed
combo with the owner's go. No unreviewed persistent UCM profile is installed.

## 9. Phase 2 gated runbook: first speaker sound

[I] Phase 1 has no speaker DAI link and no amplifier driver, so a speaker test
is impossible there and is not part of §7. This section is the only place a
speaker is allowed to make sound, and it needs its own RAM image, its own
modules and a separate explicit owner go. Nothing here is executed by a
worker.

Preconditions, all [I] until the coordinator confirms them on the device:

- the phase-2 RAM image (i2c15 + QUP wrapper enabled, both TFA9874 nodes
  `okay`, tertiary-MI2S speaker DAI link present) is the one booted, and
  `uname -r` matches the phase-2 modules staged on the rootfs;
- `modprobe snd_soc_tfa987x` binds both amplifiers: `ls -l
  /sys/bus/i2c/devices/15-0034 /sys/bus/i2c/devices/15-0035` shows a bound
  driver, and `dmesg` shows the revision line for each;
- the card is registered and `aplay -l` lists the speaker frontend.

### Step 1: read-only amplifier state (no owner go needed)

```sh
ssh root@172.16.42.1 'uname -r; ls -l /sys/bus/i2c/devices/15-0034/driver \
  /sys/bus/i2c/devices/15-0035/driver; dmesg | grep -i tfa987; \
  cat /proc/asound/cards; aplay -l'
```

Expect [I]: both amplifiers bound, one revision line each, the card present,
the speaker frontend listed. Stop: an amplifier unbound, a revision mismatch,
an i2c error, or no card. Rollback: nothing was written; reboot to the
installed combo with the owner's go.

### Step 2: prepare a quiet test signal on the laptop (offline)

```sh
sox -n -r 48000 -c 2 -b 16 /tmp/quiet-speaker.wav synth 2 sine 1000 \
  vol -60d
scp /tmp/quiet-speaker.wav root@172.16.42.1:/tmp/quiet-speaker.wav
```

Expect: a two-second 1 kHz stereo file at -60 dBFS. Stop: any other level;
never substitute `speaker-test`, a music file or a full-scale tone.

### Step 3: one speaker, muted by default (owner go required)

The amplifier is muted at probe and stays muted until all three of DAPM
power, the user switch and an unmuted playback stream agree. Set the raw gain
to 0 and leave boost off; this board supplies no boost properties.

```sh
ssh root@172.16.42.1 'amixer -c 0 cget "name=Top Speaker Playback Switch"; \
  amixer -c 0 cget "name=Top Speaker Playback Volume"'
```

Expect [I]: the switch reads 0 (off) and the volume reads 0. Stop: a missing
control, a nonzero switch, or a nonzero volume. Rollback: nothing was written.

Owner go, then exactly one speaker. The gate is a script so the rollback
trap cannot be lost to shell quoting:

```sh
cat > /tmp/speaker-gate.sh <<'SH'
#!/bin/sh
set -e
alsactl -f /tmp/audio-before.state store 0
trap 'amixer -c 0 cset "name=Top Speaker Playback Switch" 0;
      alsactl -f /tmp/audio-before.state restore 0' EXIT
amixer -c 0 cset "name=Top Speaker Playback Switch" 1
aplay -D "hw:0,0" /tmp/quiet-speaker.wav
SH
scp /tmp/speaker-gate.sh root@172.16.42.1:/tmp/speaker-gate.sh
ssh root@172.16.42.1 'sh /tmp/speaker-gate.sh'
```

Expect [I]: a faint 1 kHz tone from the top speaker only, no pop, no
distortion, no other speaker. Stop immediately on any loud sound, a click or
pop, distortion, the wrong speaker, an i2c/ADSP error in `dmesg`, or any
smell or heat from the phone. Rollback: the trap switches the amplifier off
and restores the saved mixer state; then reboot to the installed combo.

### Step 4: bottom speaker, separate owner go

Repeat step 3 with `Bottom Speaker` and the same file. Never enable both
amplifiers at once in this gate, and never raise the raw gain or the file
level inside the same session.

### Step 5: return to the installed system

Owner go to `systemctl reboot`. Expect the installed combo release and the
same B-successful slot flags. Stop on any slot difference; no automatic slot
writes and no stock boot. Rollback/recovery belongs to the coordinator.

[I] A successful step 3 establishes only that one amplifier can reproduce a
quiet tone. Loudness, speaker protection, thermal behaviour and call audio
remain unverified and are not claimed by this plan.
