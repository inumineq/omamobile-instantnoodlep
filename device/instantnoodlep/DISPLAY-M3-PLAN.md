<!-- SPDX-License-Identifier: MIT -->
# DISPLAY-M3-PLAN: usable desk phone on instantnoodlep

House-rule-6 gate for milestone **M3** of the wayfinder map
("wayfinder:map — Omarchy Mobile port for instantnoodlep (OnePlus 8 Pro
IN2023), M1-M5"): "usable desk phone: touch, GPU (Hyprland), display with
brightness and 120 Hz". This file is a plan only. No code is written here.
Nothing in the display/touch/GPU subsystem is touched before this plan exists
with its gated runbook (AGENTS.md rule 6).

- Date: 2026-11-16. Branch: `plan/display-m3` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md`,
  `device/instantnoodlep/BRINGUP-M1-PLAN.md`,
  `docs/runbooks/STAGE-0-RUNBOOK.md` (runbook style).
- Scope: panel + DSI, backlight/brightness, 120 Hz, touch, GPU + zap
  firmware, the userspace that makes them usable (Mesa freedreno/turnip,
  Hyprland on msm DRM), and the gated runbook. All M3 work happens **after
  M2** (Arch root on `userdata`); RAM boot first wherever possible.
- Safety model unchanged: no write to `super`, any `_a` partition, `vbmeta`,
  `devinfo`, `persist`, `efs*`, `modem*` or bootloader/radio partitions.
  M3 phone steps are `fastboot boot` (RAM) first; the installed slot-B /
  `userdata` system is only booted, never written, by this plan.

## 1. Source pins

All sources are public. Shallow clones lived in `/tmp/vibe-m3` during
research and were deleted afterwards; only this document lands in git.

- `M/` = torvalds/linux master @ `aebb7274476403040d582c61478df8f4a7bf9cd3`
  (Linux 7.4-rc3, shallow clone, fetched 2026-11-16). Line references below
  are valid at this commit.
- `N/` = linux-next, read through kernel.org cgit (no clone), 2026-11-16:
  <https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git>.
- `C/` = community SM8250 kernel, `gitlab.nura.eco/soc/qualcomm-sm8250/linux`,
  commit `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9` (tag `7.2.0-dev`), as
  pinned in DTS-PORT-PLAN.
- `L/` = linux-omarchy-mobile `omamobile` @
  `317d87dc2db0c3580be70a9c6341ca1fbd0a762a`; its line pins are quoted from
  DTS-PORT-PLAN §2.
- `U/` = derekross/omarchy-mobile @
  `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4` (FIRMWARE-PLAN pin).
- `P/` = pmaports @ `ce3ebdba08cdd09a6fb9a01da7d750f05638a25e`
  (redirects to gitlab.nura.eco/postmarketOS/pmaports).
- `W/` = postmarketOS wiki page "OnePlus 8 Pro (instantnoodlep)"
  <https://wiki.postmarketos.org/wiki/OnePlus_8_Pro_(instantnoodlep)>.
- `D/` = github.com/darknagel/oneplus-instantnoodlep-nura-unofficial, a
  public unofficial mainline image for this exact phone: its README and its
  `kernel-patches/` series (GPL patches) are the only public source that
  carries a panel driver for this panel. Cited by patch number.

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| Panel | Samsung **AMS678UW01**, 6.78", 1440x3168, MIPI-DSI **command mode**, **DSC**, AMOLED | [V: D/README "Tested on a single device with the Samsung AMS678UW01 display panel ... Android reports it as `oppo19811_samsung_1440_3168_dsc_cmd`"; D kernel-patches/0001 binding title "Samsung AMS678UW01 6.78\" 1440x3168 MIPI-DSI Panel ... DSC command mode AMOLED ... found in the OnePlus 8 Pro"; W/ hardware table "Display 1440 x 3168 pixels"] |
| Panel variants | Other IN2023 units may carry a different panel; the public driver is written for exactly AMS678UW01 and the screen stays black otherwise | [V: D/README + D/docs/panel-log.md] The owner's unit is [I] until stage-0/R1 shows the panel string (I-M3-1) |
| Touch IC | Samsung **S6SY761** on `i2c13` at `0x48`, interrupt TLMM GPIO 39, supplies `vreg_l13a_ts_3p0` (vdd) and `vreg_l1c_1p8` (avdd), size 1440x3168 | [V: C:649-669 at the pinned commit; pinctrl states C:869-881; rails C:406-411 and C:490-495; W/ feature table "Touchscreen Works"] |
| GPU | Adreno 650 (a6xx gen3, chip id `0x06050002`) + GMU | [V: M/arch/arm64/boot/dts/qcom/sm8250.dtsi:2934-2936 `qcom,adreno-650.2`, :3006-3007 `qcom,adreno-gmu-650.2`; M/a6xx_catalog.c:1052-1054] |

## 3. Inventory per block

"Mainline status" cites `M/` (identical generic nodes exist in `L/` per
DTS-PORT-PLAN §2 and in `N/` [V: N/ sm8250.dtsi carries `qcom,dsi-phy-7nm`
twice; N/ qcom Makefile has no SM8250 OnePlus DTB; N/ panel dir has no
ams678uw01]). "K2" is the M1a kernel-2 DTS from DTS-PORT-PLAN §3.2.

### 3.1 Panel + DSI

| Piece | Mainline status | Driver / binding | K2 today | Missing for M3 |
| --- | --- | --- | --- | --- |
| MDSS + DPU | present, generic | `qcom,sm8250-mdss` / `qcom,sm8250-dpu`, M/ sm8250.dtsi:4680, 4711; DPU KMS M/ dpu_kms.c:1510; catalog `catalog/dpu_6_0_sm8250.h` | `&mdss` disabled; simplefb only [V: DTS-PORT-PLAN §3.2 item 8; C:671-673 has it okay] | enable `&mdss`, `&dispcc` (C:587-589 disables it) |
| DSI host 0 | present, generic | `qcom,sm8250-dsi-ctrl` @ `0xae94000`, M/ sm8250.dtsi:4867-4868; host driver `drivers/gpu/drm/msm/dsi/`; command mode + DSC supported M/ dsi_host.c:941-978 | not enabled | enable `&mdss_dsi0`, `vdda-supply`, panel child, `&mdss_dsi0_out` `data-lanes = <0 1 2 3>` [V: shape from C-pin sm8250-oneplus-common.dtsi:787-812 and D patch 0003] |
| DSI PHY 7nm | present, generic | `qcom,dsi-phy-7nm` @ `0xae94400`, M/ sm8250.dtsi:4944-4945; M/ dsi/phy/dsi_phy.c:558-559 → `dsi_phy_7nm.c`; binding `qcom,dsi-phy-7nm.yaml` | not enabled | enable `&mdss_dsi0_phy` with `vdds-supply` [V: C-pin common:814-817 uses `vreg_l5a_0p88`; D patch 0003 same] |
| Display clocks | present, generic | `drivers/clk/qcom/dispcc-sm8250.c` [V: M/ file exists, clocks at :1157] | `&dispcc` disabled to protect simplefb | enable; **and** add dispcc clocks + `power-domains = <&dispcc MDSS_GDSC>` to the `/chosen` simple-framebuffer, else the bootloader framebuffer loses its clocks when dispcc probes and the display freezes [V: D patch 0003 commit message; simplefb clocks supported, M/ drivers/video/fbdev/simplefb.c:223-248] |
| DSC | present, generic | DPU has 4 DSC blocks M/ catalog/dpu_6_0_sm8250.h:257-268, `:372-373`; `drivers/gpu/drm/display/drm_dsc_helper.c` | unused | used by the panel driver (`select DRM_DISPLAY_DSC_HELPER` [V: D patch 0002]) |
| Panel driver | **absent from mainline and linux-next** [V: grep M/ and N/ for `ams678uw01` is empty] | needed: `samsung,ams678uw01` + `panel-samsung-ams678uw01.c`. Public source: D patches 0001 (binding `samsung,ams678uw01.yaml`) and 0002 (`DRM_PANEL_SAMSUNG_AMS678UW01`, 464 lines, generated with linux-mdss-dsi-panel-driver-generator from the vendor device tree). Sibling in community: `panel-samsung-amb655x.c` for the 8T (kebab), with 60/120 modes and mode switching [V: C-pin sm8250-oneplus-kebab.dts:31-38 `samsung,amb655x`; C-pin panel-samsung-amb655x.c:170-172, 271-295] | no panel node; `&mdss` disabled | port binding + driver (re-derived from the owner's own OTA device tree or ported from the public GPL patch — never from leaked/proprietary sources, AGENTS.md rule 5), then the board panel node: `panel@0` under `&mdss_dsi0`, `compatible = "samsung,ams678uw01"`, reset GPIO, `vddio-supply`/`vdd-supply`, pinctrl default/sleep states, port/endpoint graph [V: shape from C-pin common:792-812 and D patch 0003; rails l14a/l11c/l9a/l5a inventoried in DTS-PORT-PLAN §2.2 as C:413-418, 560-566, 385-390, 364-369] |
| Panel supplies | rails exist in C, not yet in K2 | `vreg_l9a_1p2` (dsi vdda), `vreg_l14a_1p8` (vddio), `vreg_l11c_3p3` (vdd), `vreg_l5a_0p88` (phy vdds) | not in K2 [V: DTS-PORT-PLAN §2.2 lists them as "later with panel"] | add the four rails + PM8150/PM8150L parents with C's values, live-DT checked (DTS-PORT-PLAN I6 pattern) |
| Panel pinctrl | states exist in C community common file | `panel_reset_default/suspend`, `panel_vout_default/suspend`, `panel_vsync` [V: C-pin common:1305-1339] | not in K2 | add with the panel node; GPIO numbers verified against the live stock DT [I-M3-6] |

### 3.2 Backlight / brightness on an AMOLED panel

There is no PWM backlight on an AMOLED panel. Brightness is a DSI DCS
command (set display brightness) sent by the **panel driver**, which
registers a standard `backlight` device; userspace then uses
`/sys/class/backlight/<panel>`.

| Piece | Status |
| --- | --- |
| Mechanism in mainline | panel drivers register the backlight device themselves, e.g. `panel-samsung-sofef00.c`: `sofef00_panel_bl_update_status` → `mipi_dsi_dcs_set_display_brightness_large`, `devm_backlight_device_register`, M/ panel-samsung-sofef00.c:172-208, 245 [V] |
| AMS678UW01 driver | registers a backlight device with `max_brightness = 2047`, DCS-based update [V: D patch 0002, backlight ops at patch lines 396-445] |
| K2 today | none (simplefb has no backlight) |
| Missing for M3 | the panel driver (which brings the backlight device); no DT backlight node is needed. Brightness range on this unit is [I-M3-9] until gate R2 |

### 3.3 120 Hz mode

| Piece | Status |
| --- | --- |
| Panel timings | the public driver carries four vendor timings: 1080x2376 and 1440x3168, each at 60 and 120 Hz; DSC PPS differs per mode, so the mode is chosen at probe time with the `mode` module parameter, **default 1440x3168@120**; `get_modes` exposes that single fixed mode [V: D patch 0002 commit message and `ams678uw01_get_modes`] |
| DPU/DSI capability | 120 Hz needs no extra mainline code: DPU vsync clock is assigned in the generic DPU node [V: M/ sm8250.dtsi:4723-4724 `assigned-clocks` VSYNC], DSI host computes DSC timing in cmd mode [V: M/ dsi_host.c:941-978] |
| K2 today | simplefb is 1080x2376 (ABL FHD+ handoff) [V: C:51-58; DTS-PORT-PLAN I4] |
| M3 target | native 1440x3168@120 as the default and only connector mode. Runtime 60/120 switching is **not** in the public driver (mode fixed at probe) — [I-M3-3]; the kebab sibling switches at runtime [V: C-pin panel-samsung-amb655x.c:170-172], so a later driver extension can expose both modes. M3 does not require runtime switching |

### 3.4 Touch

| Piece | Status |
| --- | --- |
| Mainline driver | present: `drivers/input/touchscreen/s6sy761.c`, compatible `samsung,s6sy761` [V: M/ s6sy761.c:525-526] |
| Binding | present: `Documentation/devicetree/bindings/input/touchscreen/samsung,s6sy761.yaml`; requires `compatible`, `reg`, `interrupts`, `avdd-supply`, `vdd-supply` [V: M/ binding file] |
| Firmware | none requested [V: FIRMWARE-PLAN §3 last row; M/ s6sy761.c has no `request_firmware`] |
| Board node | complete in C: `&i2c13` + `touchscreen@48` with irq, supplies, size, pinctrl [V: C:649-669, 869-881] |
| K2 today | absent; DTS-PORT-PLAN schedules it as commit 7 ("Add touchscreen", M2) [V: DTS-PORT-PLAN §4] |
| Missing for M3 | nothing new if M2's commit 7 landed; otherwise this plan carries it: node + `vreg_l13a_ts_3p0`/`vreg_l1c_1p8` rails + pinctrl, one commit |

### 3.5 GPU + zap

| Piece | Status |
| --- | --- |
| GPU nodes | present, generic: `gpu@3d00000` `qcom,adreno-650.2` [V: M/ sm8250.dtsi:2934-2936], `gpu_zap_shader: zap-shader` with `memory-region = <&gpu_mem>` [M/ :2955-2957], `gmu@3d6a000` [M/ :3006-3007] |
| Driver catalog | a650 entry: chip id `0x06050002`, family `ADRENO_6XX_GEN3`, fw `a650_sqe.fw` + `a650_gmu.bin`, `zapfw = "a650_zap.mdt"` [V: M/ a6xx_catalog.c:1052-1064] |
| K2 today | `&gpu` disabled (common disable), `&gmu` disabled, `gpu_mem` reserved at `0x8e21a000` 8 KiB [V: DTS-PORT-PLAN §2.1 C:170-173, §2.3 gpu/gmu rows; C:591-609] |
| Missing for M3 | `&gpu` and `&gmu` `status = "okay"`, plus `&gpu_zap_shader { firmware-name = ...; }` pointing at the extracted vendor-signed zap [V: shape from D patch 0004, which uses `qcom/sm8250/OnePlus/instantnoodlep/a650_zap.mbn`]. gpu_mem size sufficiency for zap is [I-M3-8] |
| Proven on this hardware | D reports "GPU (Adreno 650, Mesa freedreno) works", patch 0004 "Tested with Mesa freedreno: OpenGL ES 3.2, kmscube at 120 Hz" [V: D/docs/patches.md GPU row, D patch 0004] |

## 4. Firmware needs (tied to FIRMWARE-PLAN)

Only one M3 firmware file is not already in the M2 rootfs; the rule is
unchanged: from the owner's own factory image at install time, names only,
never committed (AGENTS.md rule 8; FIRMWARE-PLAN §4).

| File | Needed by | Source | Milestone |
| --- | --- | --- | --- |
| `a650_zap.mbn` / `.mdt` (vendor-signed, device-specific) | a6xx zap via the DT `zap-shader/firmware-name` [V: M/ a6xx_catalog.c:1064 `a650_zap.mdt`; FIRMWARE-PLAN §3 GPU row] | owner's OTA `vendor`/`odm` image, member path [I-M3-2], extracted per FIRMWARE-PLAN F1-F6 | M3 |
| `a650_sqe.fw`, `a650_gmu.bin` | a6xx SQE/GMU [V: M/ a6xx_catalog.c:1056-1057] | linux-firmware `qcom/`, already carried by the M2 rootfs package [V: FIRMWARE-PLAN §3] | M3 (no extraction) |
| panel / touch | none | mainline DSI/DRM path and `s6sy761` request no firmware [V: FIRMWARE-PLAN §3 last row] | n/a |

The DT `firmware-name` we port and the extractor's target path must be the
same string [I: FIRMWARE-PLAN §7 item 7; D patch 0004 uses
`qcom/sm8250/OnePlus/instantnoodlep/a650_zap.mbn`]. Decide once, record in
FIRMWARE-PLAN's `firmware.map` draft at F6.

## 5. Userspace

| Need | Status and evidence |
| --- | --- |
| Mesa with freedreno (GLES) | Upstream's shared Mesa build is 26.2.4 but packages only panfrost today [V: U/ packages/mesa/PKGBUILD `pkgver=26.2.4`, pkgname `vulkan-panfrost`]; upstream PR #500 "mesa 1:26.2.4-1.5: build the Freedreno Gallium driver for Adreno phones" is **open** (created 2026-11-07) and adds exactly `msm_dri.so` for Qualcomm phones [V: derekross/omarchy-mobile#500, state open]. Arch extra carries mesa `1:26.2.7-1` [V: archlinux.org/packages/extra/x86_64/mesa], and Arch Linux ARM ships mesa for aarch64 [V: archlinuxarm.org/packages/aarch64/mesa]. M3 needs a Mesa with the freedreno Gallium driver — either upstream #500 lands first, or our device packaging adds it [I-M3-7]. Proven on this GPU: freedreno GLES 3.2, kmscube at 120 Hz [V: D patch 0004] |
| Mesa turnip (Vulkan) | turnip on Adreno 6xx is officially Vulkan 1.3 conformant [V: Collabora news "Turnip implements full Vulkan 1.3 support for Adreno 600 series GPUs", Khronos conformant products]; a650 is a6xx gen3 [V: M/ a6xx_catalog.c:1052-1054]. Needed for Vulkan apps, not for Hyprland's GLES renderer |
| Hyprland on msm DRM | upstream pins Hyprland 0.57.0 with a `monitor-rule-vrr.patch` [V: U/ packages/hyprland/PKGBUILD `pkgver=0.57.0`, patch list]. Precedent: dodge (OnePlus 13, SM8750) runs Hyprland on the msm DSI panel via `device/dodge/desktop/omamobile-hyprland.service` with a simpledrm fallback; today it renders llvmpipe until freedreno lands [V: U/ service file comment]. Hyprland's renderer backend on 0.57 is [I-M3-4], confirmed from the Hyprland log at gate R6 |
| Brightness interface | `/sys/class/backlight/<panel>` created by the panel driver (§3.2); consumed by wlroots' wlr backlight / logind, and by the omamobile shell [I: which omamobile shell control reads it — check at R6] |
| Refresh-rate switching | the connector exposes one mode, 1440x3168@120 (§3.3); `hyprctl monitors` shows it. Switching to 60 Hz at runtime needs a driver extension exposing both modes [I-M3-3]. Upstream's `monitor-rule-vrr.patch` [V: U/ packages/hyprland] is the userspace side; VRR on this command-mode panel is unproven [I] |

## 6. Kernel-side commit order (in linux-omarchy-mobile, not this repo)

One logical change per commit, upstream order, GPL-2.0 headers on all
kernel content; this repo gets only this plan. Re-run the offline gates
after every commit.

| # | Commit | Content |
| --- | --- | --- |
| 1 | `dt-bindings: display: panel: Add Samsung AMS678UW01` | `samsung,ams678uw01.yaml` (ported from D patch 0001 / re-derived from the owner's OTA DT) |
| 2 | `drm/panel: Add Samsung AMS678UW01 panel driver` | `panel-samsung-ams678uw01.c`, `DRM_PANEL_SAMSUNG_AMS678UW01` (D patch 0002 lineage) |
| 3 | `arm64: dts: qcom: instantnoodlep: Enable display` | dispcc/mdss/dsi0/phy enable, panel node + supplies + pinctrl + data-lanes, simplefb clocks + MDSS_GDSC (D patch 0003 shape) |
| 4 | `arm64: dts: qcom: instantnoodlep: Enable GPU` | `&gpu`/`&gmu` okay, `&gpu_zap_shader` firmware-name (D patch 0004 shape) |
| 5 | `arm64: dts: qcom: instantnoodlep: Add touchscreen` | only if M2's DTS-PORT-PLAN commit 7 has not landed: s6sy761 node + rails + pinctrl |

## 7. Gated runbook

Offline gates O0-O7 run on the VPS/laptop and touch no phone. Owner gates
G1, R1-R6 run on the phone, **RAM boot first** (`fastboot boot`, nothing
written), exactly as M1a did; every phone command is a block with Expect,
Stop and Rollback (AGENTS.md rule 1). All of M3 happens after M2 has
passed; if the M1b slot-B install has landed, booting the installed system
is allowed for R6 only, and slot flags must be unchanged afterwards.
Never `fastboot flash`, `erase`, `--set-active` anywhere below.

Set local paths before running:

```sh
export L=/path/to/linux-omarchy-mobile
export OUT=/path/to/private/m3-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export K2DTB=/path/to/private/k2-build/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1 (K2/R7) and M2 results recorded; DTS-PORT-PLAN D0-D9 passed; FIRMWARE-PLAN F0-F6 passed (zap mapped, names only); `L` pinned and recorded | all present | any input missing | no changes made; return to the owning ticket |
| O1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` on the unchanged base; repeat after commit 1 with `DT_SCHEMA_FILES=.../samsung,ams678uw01.yaml` | baseline recorded; new binding passes with no new schema error | baseline missing or new errors | drop the binding edit |
| O2 Build | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after every commit | dtc exit 0, DTB produced | any error or stale output | delete output; fix the current commit only |
| O3 Schema | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs_check` | no new warning/error for this board | panel/DSI/GPU schema failure | revert the uncommitted change |
| O4 Node checks | `fdtget` block below against `"$DTB"`, and `dtc -I dtb -O dts` diffed against `"$K2DTB"` | panel/dsi/gpu/touch nodes exactly as §3; diff vs K2 limited to the M3 set; simplefb keeps geometry 1080x2376 and gains clocks+GDSC | any extra enable, missing node, changed identity | discard output; fix the defining commit |
| O5 Live-DT compare | decompile `"$DTB"` and the stage-0 `live.dtb`; classify every difference (expected mainline/downstream, intentional, defect) | no unexplained panel/GPU/touch difference | unexplained difference | suppress candidate; update plan |
| O6 Packaging | probe builder asserts (root IDs, image hashes, no UFS write allowlist) on the M3 image | builder exits 0 | builder refuses | delete images |
| O7 Release | review commits 1-5, O1-O6 logs, hashes and open [I]s with coordinator/owner | written approval for one RAM boot | any failed gate or [I] promoted to fact | keep M2 state; do not boot |

O4 `fdtget` checks:

```sh
fdtget -t s "$DTB" /soc@0/display-subsystem@ae00000 status
fdtget -t s "$DTB" /soc@0/display-subsystem@ae00000/dsi@ae94000 status
fdtget -t s "$DTB" /soc@0/display-subsystem@ae00000/dsi@ae94000/phy@ae94400 status
fdtget -t s "$DTB" /soc@0/display-subsystem@ae00000/dsi@ae94000/panel@0 compatible
fdtget -t s "$DTB" /soc@0/clock-controller@af00000 status
fdtget -t x "$DTB" /chosen/framebuffer@9c000000 clocks | head -1   # non-empty
fdtget -t s "$DTB" /soc@0/gpu@3d00000 status
fdtget -t s "$DTB" /soc@0/gpu@3d00000/zap-shader firmware-name
fdtget -t s "$DTB" /soc@0/gmu@3d6a000 status
fdtget -t s "$DTB" /soc@0/i2c@a94000/touchscreen@48 compatible   # if commit 5 landed
fdtget -t s "$DTB" / compatible
```

Expected: `okay`/`okay`/`okay` for mdss/dsi0/phy/dispcc/gpu/gmu; panel
`compatible` is `samsung,ams678uw01`; zap `firmware-name` is the one string
agreed with FIRMWARE-PLAN; root compatible unchanged
(`oneplus,instantnoodlep`, `qcom,sm8250`).

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K3_IMG}}` is the M3 boot image from O6; `{{SERIAL}}` is
the pinned fastboot serial (private, never pasted); `{{MAX}}` in R2 is the
`max_brightness` value read earlier in the same step. Never run a block
with a `{{...}}` still in it. Captures go to `captures/<date>/m3/`
(gitignored).

| # | Step (command block) | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices` (one line); `fastboot -s {{SERIAL}} getvar current-slot` and slot flags, recorded | one device; slot flags equal to the stage-0 capture | more than one device, or flags differ | `fastboot -s {{SERIAL}} reboot`; stock boots |
| R1 | `fastboot -s {{SERIAL}} boot {{K3_IMG}}`; then `ssh root@172.16.42.1` and `dmesg` | `Booting OKAY`; panel/DSI/DPU probe lines; `ams678uw01` probe; `s6sy761` probe; a6xx probe with zap loaded (no firmware error); SSH works | `FAILED (remote: ...)`: paste it, stay in fastboot; no SSH after 2 min; any firmware-load error | hold Power+Volume Up 10-30 s (or `panic=10` does it); stock boots from the active slot |
| R2 | over SSH: `ls /sys/class/drm/`, `cat /sys/class/drm/card0-DSI-1/modes`, `cat /sys/class/drm/card0-DSI-1/status`, `ls /sys/class/backlight/`, then `echo 100 > /sys/class/backlight/*/brightness`, read back `cat .../brightness` and `.../max_brightness`, then `echo {{MAX}} > ...` | one mode `1440x3168` at 120 Hz; status `connected`; a backlight device exists; brightness writes read back; panel visibly dims/brightens | no DSI connector; mode list empty or 1080x2376 only; no backlight device; brightness write rejected | `reboot -f` over SSH; stock boots |
| R3 | over SSH: find the touch event node (`ls /dev/input/`, `libinput list-devices` or `evtest`); tap the screen | S6SY761 events register; coordinates within 1440x3168 | no touch device, or no events | `reboot -f` |
| R4 | over SSH: `ls /dev/dri/`, then `kmscube`/`glmark2-es2` with the freedreno driver and `vulkaninfo --summary` if turnip is packaged | `renderD128` present; GLES app renders (fps ~120 at 1440x3168); vulkaninfo lists `Turnip Adreno 650` Vulkan 1.3 [I until run] | GPU probe failed in R1, or only llvmpipe | `reboot -f` |
| R5 | over SSH: `cat /sys/class/drm/card0-DSI-1/modes` with refresh, `cat /proc/cmdline`; confirm no `simplefb` freeze after dispcc probe (screen still on, console on DSI) | mode shows 120 Hz; display alive after `dispcc` probe | display froze at probe (simplefb clocks missing — DTS defect) | `reboot -f`; fix commit 3, rerun O2-O7 |
| R6 | boot the installed M2 system (not RAM): start Hyprland (`omamobile-hyprland.service` pattern), then `hyprctl monitors`, brightness via the shell/wlr, tap in Hyprland | Hyprland on card0 1440x3168@120; brightness control works; touch works; renderer is freedreno, not llvmpipe [I-M3-4] | Hyprland falls back to simpledrm or llvmpipe; black screen | reboot; record; fix userspace (I-M3-7) or DTS |
| R7 | back to stock/active slot: `fastboot -s {{SERIAL}} getvar all` (filtered output only) | slot flags equal to G1; nothing written by any step | any slot flag changed | stop; record; ask on #808 before any further boot |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-M3-1 | The owner's unit has the AMS678UW01 panel (D tested one EU unit; other variants exist [V: D/README]) | stage-0/owner panel string (`dsi_display` on the stock cmdline, or D's panel-log procedure); if different, stop and re-plan — do not enable the panel node |
| I-M3-2 | The zap shader's OTA member path, and the single `firmware-name` string shared by DTS commit 4 and the FIRMWARE-PLAN extractor | FIRMWARE-PLAN F2-F3 (names only) + O4; FIRMWARE-PLAN §7 item 7 |
| I-M3-3 | Runtime 60/120 Hz switching: the public driver fixes one mode at probe [V: D patch 0002]; M3 ships 120 Hz default only | later driver extension exposing both modes (kebab amb655x switches at runtime [V: C-pin amb655x.c:170-172]); not an M3 gate |
| I-M3-4 | Hyprland 0.57's renderer backend on msm (GLES via freedreno expected; upstream pins 0.57.0 [V: U/ packages/hyprland/PKGBUILD]) | R4/R6 logs (`hyprctl` / Hyprland log renderer line) |
| I-M3-5 | simplefb handoff: without dispcc clocks + MDSS_GDSC on the framebuffer node the display freezes when dispcc probes [V: D patch 0003 message] | commit 3 carries the fix; R5 proves the display survives probe |
| I-M3-6 | C's panel GPIOs/rails (reset TLMM 75, `l14a_1p8`, `l11c_3p3`, `l9a_1p2`, `l5a_0p88` values) are valid for this unit [V: C-pin common:787-817, D patch 0003] | O5 live-DT compare + DTS-PORT-PLAN I6 pattern; R1-R2 runtime |
| I-M3-7 | Mesa with freedreno in the phone rootfs: upstream #500 (open) vs a device-side overlay [V: PR #500 state] | M2 packaging ticket; R4/R6 prove `msm_dri.so` loads |
| I-M3-8 | The reserved `gpu_mem` (8 KiB at `0x8e21a000` [V: C:170-173]) is enough for this unit's zap | R1 dmesg (zap load success); if it fails, size the region from the live DT, never by guessing |
| I-M3-9 | Backlight range: public driver uses max 2047 [V: D patch 0002] | R2 reads `max_brightness` on the unit |
| I-M3-10 | Panel init-sequence provenance: D's driver was generated from a vendor device tree [V: D patch 0002]; our port re-derives from the owner's own OTA DT or ports the public GPL patch — never from leaked sources (AGENTS.md rule 5) | review at commit 2; O1/O3 |

## 9. Definition of done for M3

O0-O7 pass; G1, R1-R7 pass with pasted (redacted) output; Hyprland runs on
the native panel at 1440x3168@120 with working brightness control and
touch; the zap loads from the owner-extracted file; slot flags are
unchanged; results are appended to NOTES.md with dates. Kernel commits 1-5
exist in a linux-omarchy-mobile branch, each with its gates rerun; M4
upstream submission is a separate plan.
