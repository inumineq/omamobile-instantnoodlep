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
- Remote sources I could not open in this session (no network connector):
  the darknagel repo, postmarketOS wiki/pmaports, alsa-ucm-conf upstream.
  Claims relying on them are [I].

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| Audio DSP | ADSP (Hexagon, pas_id 1) carries all audio services on SM8250: the dtsi glink edge exposes q6core, **q6afe** (+q6afedai, q6afecc clocks), **q6asm** (+q6asmdai), **q6adm** (+q6routing) | [V: L/ sm8250.dtsi:6008-6097] |
| Codec | **WCD938x** (WCD9380/WCD9385 family), split codec: TX slave on swr2 (0x3230000), RX slave on swr1 (0x3210000); MBHC headset detect incl. **USB-C analog audio** | [V: E/ 10424-10488 (slaves), 10551-10577 (codec, `qcom,split-codec = <1>`), 10602 (`qcom,msm-mbhc-usbc-audio-supported = <1>`); L/ wcd938x.c:30-31 chip IDs] |
| Speaker amps | Two amps, two candidates in the overlay: (a) **NXP TFA98xx on i2c adapter 2, addrs 0x35 and 0x34** ("tfa98xx.2-0035", "tfa98xx.2-0034", vendor "nxp") [V: E/ 10795-10801]; (b) four **WSA881x** SoundWire slaves on swr0, dev ids 0x20170211/12/13/14 [V: E/ 10500-10547] with `qcom,wsa-max-devs = <0>` [V: E/ 10606]. Which set is populated on the owner's unit is [I-A1] | see §3.4 |
| Digital mics | 3 DMIC pairs on LPASS TLMM: dmic01 gpio6/7, dmic23 gpio8/9, dmic45 gpio12/13 (clk drive 8 mA, data input) | [V: E/ 10180-10364; mainline has dmic01 states only: L/ sm8250.dtsi:2849-2878] |
| Analog mics | WCD938x AMIC inputs on micbias (stock routing uses AMIC2→MIC BIAS2) | [V: E/ 10590 routing] |
| Earpiece | No separate earpiece amp node appears in entry 16; earpiece is on the WCD938x RX path (HPHL/HPHR out) | [V: E/ 10590-10591 has only IN1_HPHL/IN2_HPHR; exact DAI mapping is [I-A9]] |
| Headphones | No 3.5 mm jack. USB-C only: analog via WCD938x MBHC (`usbc-audio-supported`) and/or USB audio class in host mode | [V: E/ 10602; I-A7 for the runtime path] |
| Codec rails | `vreg_s4a_1p8` (S4A) → va-macro micb + wcd vdd-rxtx/vddio/vdd-buck; `vreg_bob` (BOB) → wcd vdd-mic-bias | [V: E/ 14705, 14709, 10379, 10559-10568; both rails already in K2: DTS-PORT-PLAN §2.2 s4a row, bob row] |
| WCD micbias | micbias1/3/4 = 1.8 V, micbias2 = 2.7 V | [V: E/ 10571-10574 (0x708, 0xa8c)] |

## 3. Inventory per block

"K2 today" is the board DTS at `L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`
(387 lines): it keeps the `adsp_mem`/`cdsp_mem`/`slpi_mem` reservations
[V: L/ K2 dts:107-127] and adds no adsp/sound/swr/i2c-amp overrides, so
everything below is disabled or absent in K2 [V: grep of the K2 file for
adsp|sound|swr|wcd|amp is empty apart from the memory nodes].

### 3.1 ADSP remoteproc and the q6 service choice (q6afe/q6asm, not audioreach)

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| ADSP node | generic, `remoteproc@17300000`, `qcom,sm8250-adsp-pas`, `memory-region = <&adsp_mem>`, status disabled | `qcom_q6v5_pas`: `sm8250_adsp_resource` (pas_id 1, auto_boot, default fw `adsp.mdt`, DT `firmware-name` overrides) [V: L/ qcom_q6v5_pas.c:1066-1081, :1891, :838-846]; dtsi node L/ sm8250.dtsi:6008-6034 | disabled; `adsp_mem` reserved (37 MiB at 0x91b00000) [V: DTS-PORT-PLAN §2.1] | `status = "okay"` + `firmware-name` matching the firmware.map adsp row (§4) |
| APR / glink | generic (smp2p, ipcc, aoss_qmp, rpmhpd all present in dtsi) | `qcom,apr-v2` edge with services q6core/q6afe/q6asm/q6adm [V: L/ sm8250.dtsi:6046-6097]; drivers `qdsp6/q6afe*.c, q6asm*.c, q6adm.c, q6routing.c, q6core.c` [V: L/ sound/soc/qcom/qdsp6/ listing] | not enabled (child of adsp) | nothing — comes up with ADSP; needs CONFIG_QCOM_APR + SOUNDWIRE [V: L/ sound/soc/qcom/Kconfig:187] |
| **q6afe/q6asm/q6adm vs audioreach** | SM8250 dtsi describes the **classic** q6 services; `audioreach.c`/`q6apm*.c` exist in the tree but bind to `qcom,q6apm*` compatibles that sm8250.dtsi does **not** have | decision: **q6afe/q6asm/q6adm** (audioreach is for newer SoCs whose ADSP firmware speaks the APM protocol) | n/a | nothing; the ADSP firmware from the OTA serves the v2 APR services the dtsi encodes [V: L/ sm8250.dtsi:6046-6097; I-A8: C/ tree not opened, but the Nura image runs speakers/mics on this SoC family [V: NOTES.md 2026-11-15]] |
| Machine driver | `sound/soc/qcom/sm8250.c`, compatible `qcom,sm8250-sndcard` [V: L/ sm8250.c:214; Kconfig SND_SOC_SM8250:185-196, depends on QCOM_APR && SOUNDWIRE, selects QDSP6/QCOM_COMMON/QCOM_SDW]; binding `qcom,sm8250.yaml` enum includes `qcom,sm8250-sndcard` [V: L/ bindings/sound/qcom,sm8250.yaml:54] and dai-link subnode schema :76-115, `aux-devs` :66-70 | `sound: sound {}` empty node exists, board fills it [V: L/ sm8250.dtsi:6315-6316] | sound card with dai-links (§3.7), mtp pattern [V: L/ sm8250-mtp.dts:655-757] |

### 3.2 LPASS macros and SoundWire controllers

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| rx macro + swr1 (RX bus, WCD RX) | `rxmacro@3200000` `qcom,sm8250-lpass-rx-macro` (disabled), `swr1@3210000` `qcom,soundwire-v1.5.1` (disabled, 5 dout ports) [V: L/ sm8250.dtsi:2709-2753] | drivers `lpass-rx-macro.c` (sm8250 @ :3942), `drivers/soundwire/qcom.c` (`qcom,soundwire-v1.5.1` @ :1834, Kconfig SOUNDWIRE_QCOM :50) | disabled | enable both; swr1 carries the wcd_rx slave |
| tx macro + swr2 (TX bus, WCD TX) | `txmacro@3220000`, `swr2@3230000` (disabled, 5 din ports) [V: L/ sm8250.dtsi:2755-2801] | `lpass-tx-macro.c` (sm8250 @ :2494), same soundwire driver | disabled | enable both; swr2 carries the wcd_tx slave |
| va macro (DMIC) | `vamacro@3370000` `qcom,sm8250-lpass-va-macro`, **no status = disabled** (on by default), DMIC0-3 channel regs [V: L/ sm8250.dtsi:2695-2707; L/ lpass-va-macro.c:36-61, :1774] | `lpass-va-macro.c`, Kconfig SND_SOC_LPASS_VA_MACRO (codecs/Kconfig:2931-2936) | on, but no pinctrl/micb | `pinctrl-0 = <&dmic01_active>`, `vdd-micb-supply = <&vreg_s4a_1p8>`, `qcom,dmic-sample-rate = <600000>` — exactly the rb5 pattern [V: L/ qrb5165-rb5.dts:1458-1463]; stock agrees (S4A, 600 kHz) [V: E/ 10379-10382] |
| wsa macro + swr0 (speaker bus) | `wsamacro@3240000` + `swr0@3250000` (both disabled) [V: L/ sm8250.dtsi:2652-2693] | `lpass-wsa-macro.c` (:2892), SND_SOC_LPASS_WSA_MACRO (depends on PM_CLK, codecs/Kconfig:2924-2929), soundwire driver | disabled | needed **only if** the owner's unit has WSA881x speakers [I-A1]; wsa macro provides swr0's iface clock [V: L/ sm8250.dtsi:2677] |
| lpass_tlmm | `pinctrl@33c0000` `qcom,sm8250-lpass-lpi-pinctrl`, gpio6/7 = dmic01 clk/data, gpio0-5/10-11 = swr pins [V: L/ sm8250.dtsi:2803-2937] | `drivers/pinctrl/qcom/pinctrl-lpass-lpi.c` | present | add dmic23 (gpio8/9) and dmic45 (gpio12/13) states to reach the stock 6 DMICs [V: E/ 10242-10364]; function names follow the dtsi pattern `dmic1_clk`/`dmic1_data` [V: L/ sm8250.dtsi:2852,2858] |

### 3.3 WCD938x codec (SoundWire slaves + codec node)

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| SDW slaves | binding `qcom,wcd938x-sdw.yaml`: `compatible = "sdw20217010d00"`, `reg = <0 devnum>`, rx-port-mapping (5), tx-port-mapping (4); example: rx `codec@0,4` under 0x3210000, tx `codec@0,3` under 0x3230000 [V: L/ bindings/sound/qcom,wcd938x-sdw.yaml:17-68]; mtp uses exactly rx@0,4 `<0 4>` map <1 2 3 4 5> and tx@0,3 `<0 3>` map <2 3 4 5> [V: L/ sm8250-mtp.dts:781-799] | `wcd938x-sdw.c` + Kconfig SND_SOC_WCD938X_SDW (codecs/Kconfig:2488-2498) | absent | two slave nodes under &swr1/&swr2; stock dev ids 0x1170224 (rx) / 0x1170223 (tx) [V: E/ 10446, 10484] — mainline uses DT-declared devnums (mtp: <0 4>/<0 3>); port mapping from mtp unless live enumeration disagrees [I-A8] |
| Codec node | binding `qcom,wcd938x.yaml`: `qcom,wcd9380-codec`/`qcom,wcd9385-codec`, `reset-gpios`, supplies, micbias, `qcom,rx-device`/`qcom,tx-device` [V: L/ bindings/sound/qcom,wcd938x.yaml:20-58]; mtp node: reset `&tlmm 32`, vdd-buck/rxtx/io = `&vreg_s4a_1p8`, vdd-mic-bias = `&vreg_bob`, micbias 1.8 V, mbhc thresholds [V: L/ sm8250-mtp.dts:27-48] | `wcd938x.c` (MBHC incl.), Kconfig SND_SOC_WCD938X | absent | codec node in `/` with supplies = K2's `vreg_s4a_1p8`/`vreg_bob` [V: both rails in K2, DTS-PORT-PLAN §2.2], micbias values from stock [V: E/ 10571-10574]; reset GPIO number [I-A3] (stock uses a dedicated pinctrl "msm_cdc_pinctrl@32", E/ 10708-10714; mtp uses tlmm gpio32 [V: L/ sm8250-mtp.dts:30,804-818]) |

### 3.4 Speaker amplifiers

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| Path A: NXP TFA98xx on i2c | `sound/soc/codecs/tfa989x.c` supports `nxp,tfa9890`, `nxp,tfa9895`, `nxp,tfa9897` [V: L/ tfa989x.c:406-412]; binding `nxp,tfa989x.yaml` [V: L/ bindings/sound/ nxp,tfa989x.yaml]; Kconfig SND_SOC_TFA989X [V: codecs/Kconfig:2300-2306] | i2c bus "2" downstream (`qupv3_se2_i2c`, E/ 11315, 14745), addrs **0x34 and 0x35** [V: E/ 10799-10800] | absent | two `tfa98xx@34/35` nodes on the right mainline `&i2cN` [I-A2 which label maps to downstream adapter 2]; exact part (9890/95/97) [I-A5]; amp supplies/reset GPIOs live in the base DTB (dtb_idx=3), not in entry 16 [I-A3] |
| Path B: WSA881x on swr0 | `wsa881x.c` SDW ids (0x0217,0x2010) and (0x0217,0x2110) [V: L/ wsa881x.c:1196-1200]; Kconfig SND_SOC_WSA881X [V: codecs/Kconfig:2765]; rb5 speaker shape `sdw…` @ reg <0 3>/<0 4> with powerdown-gpios [V: L/ qrb5165-rb5.dts:1111-1131] | four slaves on swr0, dev ids 0x20170211-14, sd-n via pinctrls [V: E/ 10517-10547] | absent | four slave nodes under &swr0 + `powerdown-gpios` [I-A3 GPIO numbers]; enable wsamacro+swr0 (§3.2) |
| Decision | the stock overlay names the TFA98xx pair as the speaker codecs (`oplus,speaker-vendor = "nxp"`) [V: E/ 10797-10800]; the WSA881x nodes sit next to them with `qcom,wsa-max-devs = <0>` [V: E/ 10606] | — | — | pick per unit at gate R3 (i2c probe of 0x34/0x35 vs swr0 enumeration) — [I-A1]; mainline supports both, so the DTS can carry both and let probing decide |

### 3.5 Microphones

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| VA DMIC (digital) | va macro DAIs + generic `dmic` codec (codecs/dmic.c); rb5: `&vamacro { pinctrl-0 = <&dmic01_active>; vdd-micb-supply; qcom,dmic-sample-rate = <600000>; }` + va-dai-link `VA_CODEC_DMA_TX_0` → `&vamacro 0` [V: L/ qrb5165-rb5.dts:1077-1090, 1458-1463]; DAI id 110 [V: L/ include/dt-bindings/sound/qcom,q6dsp-lpass-ports.h:115] | present | va macro on, no board props | board props as rb5; extend dmic23/dmic45 states for the stock 6 mics (§3.2) [I-A10: start with one pair] |
| WCD analog mics (AMIC) | wcd938x TX path + micbias; capture link `TX_CODEC_DMA_TX_3` → `<&wcd938x 1>, <&swr2 0>, <&txmacro 0>` [V: L/ sm8250-mtp.dts:715-727; DAI id 120, ports.h:125] | present in wcd938x driver | absent | dai-link + audio-routing entries (AMIC2/MIC BIAS2 per stock [V: E/ 10590]) |

### 3.6 Earpiece and USB-C headphones

- Earpiece: WCD938x RX playback channel; stock routing maps IN1_HPHL/IN2_HPHR → HPHL_OUT/HPHR_OUT [V: E/ 10590-10591]. No separate amp node in the overlay [V: grep of E/ for earpiece/receiver amps is empty]. Exact UCM device naming is [I-A9].
- USB-C headphones: analog headsets via WCD938x MBHC (`qcom,msm-mbhc-usbc-audio-supported = <1>` [V: E/ 10602]) need the Type-C altmode/SBU path — that is M2 USB work; until then, USB-C **digital** audio via `snd-usb-audio` in host mode (or q6usb offload, `qdsp6/q6usb.c` exists, SND_SOC_QDSP6_USB [V: L/ qcom/Kconfig:124-131]) is the fallback. Which path the owner uses is [I-A7]. No 3.5 mm jack exists on IN2023 [V: E/ contains no jack node; I: physical check trivial].

### 3.7 Sound card node (board DTS)

Pattern from the SM8250 MTP, which mainline already ships [V: L/ sm8250-mtp.dts:655-757]:

```dts
&sound {
    compatible = "qcom,sm8250-sndcard";   /* already in the binding enum [V: qcom,sm8250.yaml:54] */
    model = "OnePlus 8 Pro";
    audio-routing = /* HPH, AMIC, WSA/TFA spkr, VA DMIC — from E/ 10590 shape */;
    mm1-dai-link { cpu { sound-dai = <&q6asmdai MSM_FRONTEND_DAI_MULTIMEDIA1>; }; };
    wcd-playback-dai-link { cpu { sound-dai = <&q6afedai RX_CODEC_DMA_RX_0>; };   /* 113 */
        codec { sound-dai = <&wcd938x 0>, <&swr1 0>, <&rxmacro 0>; };
        platform { sound-dai = <&q6routing>; }; };
    wcd-capture-dai-link  { cpu { sound-dai = <&q6afedai TX_CODEC_DMA_TX_3>; };  /* 120 */
        codec { sound-dai = <&wcd938x 1>, <&swr2 0>, <&txmacro 0>; };
        platform { sound-dai = <&q6routing>; }; };
    /* + speaker link: WSA_CODEC_DMA_RX_0 (105) → amps (swr0/wsamacro) or TFA aux-devs */
    va-dai-link { cpu { sound-dai = <&q6afedai VA_CODEC_DMA_TX_0>; };            /* 110 */
        codec { sound-dai = <&vamacro 0>; }; platform { sound-dai = <&q6routing>; }; };
};
```

[V: L/ sm8250-mtp.dts:702-756; DAI ids L/ qcom,q6dsp-lpass-ports.h:110-125; aux-devs for i2c amps L/ bindings/sound/qcom,sm8250.yaml:66-70].

### 3.8 CDSP / SLPI decision

CDSP is **not needed for audio** on SM8250: its glink edge carries only fastrpc compute CBs, no audio services [V: L/ sm8250.dtsi:3821-3843]. Keep `&cdsp` disabled for M5 audio; it may be enabled later for non-audio subsystems under its own plan. SLPI is sensors (separate M5 plan), not audio [V: L/ sm8250.dtsi:3091-3135]. `slpi.mbn`/`cdsp.mbn` firmware.map rows stay unused by this plan.

## 4. Firmware needs (tied to firmware.map rows, names only)

| firmware.map row | Needed by | Milestone |
| --- | --- | --- |
| `modem:/image/adsp.mdt → qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn` | ADSP PAS load; the ported DTS sets `firmware-name` to exactly this destination string [V: firmware.map:22; L/ qcom_q6v5_pas.c:838-846 override; mtp precedent `qcom/sm8250/adsp.mbn` L/ sm8250-mtp.dts:171-174] | M5 |
| `modem:/image/cdsp.mdt → …/cdsp.mbn` | not for audio (§3.8); row exists for later subsystems [V: firmware.map:23] | not this plan |
| linux-firmware `qcom/sm8250/adsp.mbn` alternative | if F5 shows the OTA copy equals LF's, the LF file could be used instead; the map row decides at install time [V: FIRMWARE-PLAN §5 F5; I-A6] | M5 |

No codec/amp firmware: wcd938x, wsa881x, tfa989x, dmic request none [V: no request_firmware in L/ wcd938x.c, wsa881x.c, tfa989x.c, dmic.c]. Audio needs **no new extraction**; the adsp row is already mapped. Rule unchanged: names only, never bytes (AGENTS.md rule 8).

## 5. Userspace (Arch Linux ARM)

| Need | Plan | Evidence |
| --- | --- | --- |
| PipeWire + WirePlumber + ALSA | upstream's `omamobile-audio` package already depends on `alsa-ucm-conf pipewire wireplumber swh-plugins alsa-lib alsa-utils` and ships pipewire/wireplumber config, udev rules and ucm2 overrides (`ucm2/Google/`, `conf.d/`) | [V: U/ packages/omamobile-audio/PKGBUILD:10; dir listing pipewire/ wireplumber/ ucm2/ systemd/ udev.rules] |
| UCM profile for this card | ship `ucm2/OnePlus/instantnoodlep*.conf` in our device package (dodge precedent: `device/dodge/audio/ucm2/OnePlus/` + `OnePlus-dodge.m4`), installed over alsa-ucm-conf's `conf.d`. Whether upstream alsa-ucm-conf already has a qcom sm8250 profile is [I-A4] (remote not opened); either way the device package wins | [V: U/ device/dodge/audio/ listing] |
| Bring-up service | dodge pattern: `omamobile-<device>-audio.service` running an `audio-bringup.sh` that waits for `/sys/class/remoteproc/*/name = adsp` to reach `online`, loads fastrpc + snd-soc modules in order, checks `/proc/device-tree/sound/compatible` | [V: U/ device/dodge/audio/audio-bringup.sh:36-40, install:8-26] |
| Kernel modules | audio drivers as **modules** (K2 kernel limit unmeasured [V: device/instantnoodlep/kernel.config:12-13]); pin in the M5 config fragment: `SND_SOC_SM8250=m`, `SND_SOC_WCD938X_SDW=m`, `SND_SOC_LPASS_RX_MACRO/TX_MACRO/VA_MACRO=m` (+`WSA_MACRO` if path B), `SND_SOC_WSA881X=m` or `SND_SOC_TFA989X=m`, `SND_SOC_DMIC=m`, `SOUNDWIRE_QCOM=m`, `QCOM_APR` (with glink), `SND_USB_AUDIO=m` for USB-C digital; QDSP6/QCOM_COMMON/QCOM_SDW come via `select` [V: L/ qcom/Kconfig:185-196]; K2 config has only `QCOM_Q6V5_PAS=m`/`QCOM_SYSMON=m`, no SND* [V: kernel.config:70-71] | config edit belongs to the M5 implementation ticket, not this file |
| hexagonrpcd / libssc | **not needed** for basic audio — the q6 services are kernel-side via APR; userspace never opens the DSP directly for playback/capture. Revisit only for offload use-cases | [I: dodge runs them for other reasons; not verified here] |

## 6. Kernel-side commit order (in linux-omarchy-mobile `~/src/l`, not this repo)

One logical change per commit, GPL-2.0 headers; this repo gets only this
plan. Re-run the offline gates after every commit.

| # | Commit | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: instantnoodlep: Enable ADSP` | `&adsp { status = "okay"; firmware-name = "qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn"; }` (string must equal the firmware.map adsp destination [V: firmware.map:22]) |
| 2 | `arm64: dts: qcom: instantnoodlep: Enable WCD938x on SoundWire` | `&rxmacro`/`&swr1`/`&txmacro`/`&swr2` okay, wcd_rx/wcd_tx `sdw20217010d00` slaves with mtp port mappings [V: L/ sm8250-mtp.dts:781-799], wcd938x codec node (supplies s4a_1p8/bob, micbias 1.8/2.7 V, reset GPIO [I-A3]) |
| 3 | `arm64: dts: qcom: instantnoodlep: Add speaker amplifiers` | path per [I-A1]: tfa98xx@34/35 on the mapped `&i2cN` [I-A2] and/or wsa881x slaves on `&swr0` + `&wsamacro`; amp GPIOs [I-A3] |
| 4 | `arm64: dts: qcom: instantnoodlep: Add DMICs` | `&vamacro` pinctrl/micb/sample-rate [V: rb5 pattern], dmic23/dmic45 states in `&lpass_tlmm` [V: E/ pins] |
| 5 | `arm64: dts: qcom: instantnoodlep: Add sound card` | `&sound` `qcom,sm8250-sndcard` with the dai-links of §3.7 + audio-routing |
| 6 | `config: instantnoodlep: enable audio drivers` (this repo's `kernel.config`, separate ticket) | module pins of §5 |

## 7. Gated runbook

Offline gates run on the laptop and touch no phone. Owner gates run on the
phone, **RAM boot first** (`fastboot boot`, nothing written), exactly as
M1a/M3 did; every phone command is a block with Expect / Stop / Rollback
(AGENTS.md rule 1). M5 assumes M1b (slot B default) and M2 (Arch root on
`userdata`) have passed [V: NOTES.md 2026-11-17 M1b complete]. The adsp
firmware file must already be in the rootfs from install time (firmware.map
extraction) or pushed over SSH — never flashed.

```sh
export L=/home/inumineq/src/l
export OUT=/path/to/private/m5-audio-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export K2DTB=/path/to/private/k2-build/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1b/M2/M3 results recorded; FIRMWARE-PLAN F0-F6 passed (adsp row mapped, names only); L pinned at `a28aaf1a09db` | all present | any input missing | no changes; return to owning ticket |
| O1 Config audit | `make -C "$L" O="$OUT" ARCH=arm64 defconfig` + omamobile.config + kernel.config; grep resulting `.config` for QCOM_APR, GLINK, SOUNDWIRE, SND_SOC | APR/glink/soundwire core present or pinned by the commit-6 fragment; no SND_SOC_SM8250 yet on base | base lacks a prerequisite that commit 6 does not add | fix the fragment, not the base |
| O2 Build | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after every commit; full Image build for commit 6 | dtc exit 0; DTB produced; Image builds | any error or stale output | delete output; fix current commit only |
| O3 Schema | `make ... dtbs_check` | no new warning/error for this board | sound/swr/codec schema failure | revert uncommitted change |
| O4 Node checks | `fdtget` block below on `"$DTB"`; `dtc -I dtb -O dts` diff vs `"$K2DTB"` | nodes exactly as §3; diff limited to the M5 audio set; root compatible unchanged | extra enable, missing node | discard output; fix defining commit |
| O5 Live-DT compare | decompile `"$DTB"` and stage-0 `live.dtb`; classify every audio-related difference (swr/macros/wcd/amps/dmic/gpios) | no unexplained audio difference; GPIO numbers [I-A3] confirmed against live DT | unexplained difference | suppress candidate; update plan |
| O6 Packaging | device-package build installs ucm2/wireplumber files + service; builder asserts (no UFS write allowlist, image hashes) | builder exits 0; `omamobile-audio` deps resolvable in the local repo | builder refuses | delete images |
| O7 Release | review commits 1-6, O1-O6 logs, hashes, open [I]s with coordinator/owner | written approval for one RAM boot | any failed gate or [I] promoted to fact | keep M3 state; do not boot |

O4 `fdtget` checks:

```sh
fdtget -t s "$DTB" /soc@0/remoteproc@17300000 status
fdtget -t s "$DTB" /soc@0/remoteproc@17300000 firmware-name
fdtget -t s "$DTB" /soc@0/soundwire@3210000 status
fdtget -t s "$DTB" /soc@0/soundwire@3210000/codec@0,4 compatible
fdtget -t s "$DTB" /soc@0/soundwire@3230000/codec@0,3 compatible
fdtget -t s "$DTB" /soc@0/rxmacro@3200000 status
fdtget -t s "$DTB" /soc@0/txmacro@3220000 status
fdtget -t s "$DTB" /soc@0/codec@3240000 status        # wsamacro, only if path B
fdtget -t s "$DTB" /audio-codec compatible
fdtget -t s "$DTB" /sound compatible
fdtget -t s "$DTB" /soc@0/remoteproc@8300000 status     # cdsp stays disabled
fdtget -t s "$DTB" / compatible
```

Expected: adsp `okay` with firmware-name exactly
`qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn`; swr1/swr2 and slaves
`sdw20217010d00`; rx/tx macro `okay`; codec `qcom,wcd9380-codec` (or 9385 —
[I-A5-style runtime chipid read decides which enum string, both allowed
[V: L/ wcd938x.yaml:22-24]]); sound `qcom,sm8250-sndcard`; cdsp `disabled`;
root compatible `oneplus,instantnoodlep` `qcom,sm8250` unchanged.

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` M5 boot image from O6/O7; `{{SERIAL}}` pinned
fastboot serial (private). Never run a block with `{{...}}` in it. Captures
to `captures/<date>/m5-audio/` (gitignored).

| # | Step (command block) | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` + slot flags, recorded | one device; flags equal to the M1b B5 baseline | flags differ | `fastboot -s {{SERIAL}} reboot`; stock boots |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; SSH `root@172.16.42.1`; `dmesg \| grep -Ei 'adsp\|q6\|apr\|glink\|soundwire\|swr\|wcd\|snd'`, `cat /sys/class/remoteproc/remoteproc*/name,state` | `Booting OKAY`; adsp firmware loads from the mapped path (no firmware error), state `online`; q6core/q6afe/q6asm/q6adm services appear; swr1/swr2 enumerate; wcd938x slaves attach; `snd-soc-sm8250` card registers (`/proc/asound/cards`) | `FAILED (remote: …)`: paste, stay in fastboot; no SSH after 2 min; any firmware-load error; adsp crash loop | hold Power+VolUp 10-30 s; stock/active slot boots; per NOTES, cold-reboot to bootloader before the next `fastboot boot` after a refused boot [V: NOTES.md 2026-11-16 R1 consequence] |
| R2 | over SSH: `aplay -l`, `arecord -l`, `amixer -c 0 scontrols \| head` | one card (sm8250); WCD + VA + (WSA or TFA) DAIs listed; controls present (HPH, AMIC, micbias) | no card, or card without codec DAIs | `reboot -f` |
| R3 | amp identification: `i2cdetect -l` + probe of the amp bus for 0x34/0x35; `cat /sys/bus/soundwire/devices/*/dev_id` on swr0; resolve [I-A1] | exactly one amp family populated; record which | both or neither | `reboot -f`; keep both node sets in DTS, disable the absent one at commit 3 |
| R4 | playback test at minimal volume (owner sets volume on screen first — no screen steps by the agent): `speaker-test -c 2 -t wav -l 1` at lowest volume, then `amixer` HPH: `arecord -d 3 -f S16_LE -r 48000 t.wav` on VA DMIC and on AMIC; `aplay t.wav` via HPH | sound from the correct speaker/earpiece; captures non-silent (DMIC and AMIC) | no sound, or wrong device | `reboot -f`; check routing/UCM |
| R5 | USB-C: plug a USB-C headset (owner action), check `qcom,msm-mbhc-usbc-audio-supported` path via MBHC (`dmesg \| grep -i mbhc`) and/or `lsusb` + `aplay -D hw:...` via snd-usb-audio | analog: MBHC insertion detected, WCD RX plays; digital: snd-usb-audio enumerates and plays | neither | `reboot -f`; record which path works [I-A7] |
| R6 | boot the installed slot-B system (not RAM): `systemctl status pipewire wireplumber omamobile-instantnoodlep-audio.service`; `wpctl status`; play via `pw-play` | card appears as a PipeWire node; UCM profile loaded; playback works | service failed or no node | reboot; fix userspace (§5) |
| R7 | `fastboot -s {{SERIAL}} getvar all` (filtered) after rebooting to bootloader | slot flags equal to G1; nothing written by any step | any flag changed | stop; record; ask on #808 before further boots |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-A1 | Which speaker amps the owner's unit has: TFA98xx on i2c2 0x34/0x35 [V: E/ 10799] vs WSA881x on swr0 [V: E/ 10517-10547] | R3 (i2c probe + swr0 dev_id enumeration); C/ community DTS when fetched [I-A8] |
| I-A2 | Mainline `&i2cN` label for downstream i2c adapter 2 (`qupv3_se2_i2c`) | O5 live-DT/base-DTB compare (base DTB dtb_idx=3 not in p3/) |
| I-A3 | GPIO numbers for wcd938x reset and amp sd_n (stock keeps them in the base DTB / separate `msm_cdc_pinctrl` nodes, not in entry 16) [V: E/ 10688-10714, 14721-14726] | O5 live-DT compare; candidates: tlmm 32 for wcd reset [V: mtp pattern L/ sm8250-mtp.dts:30] |
| I-A4 | Whether upstream alsa-ucm-conf ships a usable qcom/sm8250 UCM (remote not opened this session) | O6: inspect the `alsa-ucm-conf` package contents in the local repo; device package overrides regardless (dodge precedent [V: U/ device/dodge/audio/ucm2/OnePlus/]) |
| I-A5 | Exact TFA98xx part (mainline covers tfa9890/9895/9897 [V: L/ tfa989x.c:406-412]) and WCD938x variant (9380 vs 9385 [V: L/ wcd938x.c:30-31]) | R1/R3 chip-id reads; O4 accepts either enum string |
| I-A6 | OTA `adsp.mbn` vs linux-firmware `qcom/sm8250/adsp.mbn` equivalence | FIRMWARE-PLAN F5 hash compare [V: FIRMWARE-PLAN §5 F5]; firmware.map row is the default |
| I-A7 | USB-C headphone path: analog via MBHC (needs M2 Type-C altmode) vs USB audio class in host mode | R5; until M2 Type-C lands, snd-usb-audio is the fallback [V: SND_USB_AUDIO plan §5] |
| I-A8 | C/ community audio node shape (gitlab.nura.eco not opened in this session — no network) | fetch C/ at implementation time; cross-check §3 node shapes; Nura image proves speakers/mics work on this SoC [V: NOTES.md 2026-11-15] |
| I-A9 | Earpiece exact DAI/UCM naming (on WCD RX path per stock routing [V: E/ 10590]) | R4/R6 UCM test |
| I-A10 | DMIC count to expose: start with the dmic01 pair (gpio6/7, in mainline dtsi [V: L/ sm8250.dtsi:2849-2878]); stock wires 3 pairs / 6 mics [V: E/ 10180-10364] | R4 arecord tests; extend dmic23/45 states if needed |

## 9. Definition of done for M5 audio

O0-O7 pass; G1, R1-R7 pass with pasted (redacted) output; ADSP loads the
firmware.map adsp file and the sm8250 sound card registers with WCD938x
playback+capture, speaker output through the identified amps, VA/AMIC
capture, and a working USB-C headphone path recorded; PipeWire/WirePlumber
on the installed slot-B system expose the card with the device UCM profile;
slot flags unchanged; results appended to NOTES.md with dates. Kernel
commits 1-6 exist in `~/src/l` with gates rerun per commit.
