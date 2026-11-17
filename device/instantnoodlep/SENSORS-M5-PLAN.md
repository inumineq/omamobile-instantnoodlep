<!-- SPDX-License-Identifier: MIT -->
# SENSORS-M5-PLAN: SLPI sensors + AP-wired input for instantnoodlep

House-rule-6 gate for milestone **M5** of the wayfinder map (sensors part):
SLPI remoteproc boot, FastRPC path to accelerometer/gyroscope/magnetometer/
proximity/ALS, iio-sensor-proxy for rotation and auto-brightness, plus the
AP-wired parts (hall sensors, under-display fingerprint, vibrator). This file
is a plan only; no code is written here. Nothing in the sensor subsystem is
touched before this plan exists with its gated runbook (AGENTS.md rule 6).

- Date: 2026-11-17. Branch: `m5-plans` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md`, `device/instantnoodlep/firmware.map`,
  `device/instantnoodlep/DISPLAY-M3-PLAN.md`, `device/instantnoodlep/NOTES.md`.
- Scope: kernel (SLPI enable, hall, vibrator DTS; config), userspace
  (hexagonrpcd + libssc + iio-sensor-proxy, services, udev), firmware mapping
  (names only). Fingerprint is identify-and-document only: no open driver is
  ported (§3.3). Cameras, modem, Wi-Fi are other M5 plans.
- Safety model unchanged: never `super` or any `_a` partition; flash writes
  only to slot-B boot images and `userdata`, each behind an owner go
  (AGENTS.md rules 1, 3). All M5 phone steps are `fastboot boot` (RAM) first;
  the installed slot-B system is only booted, never written, by this plan.
- New prerequisite: the neutral DTBO must be installed on `dtbo_b` through a
  separate owner-gated slot-B write plan before RAM boot. Stock entry 16
  rewrites live `/compatible` to `qcom,kona-mtp`, `qcom,kona`, `qcom,mtp`
  [V: NOTES.md 2026-11-17 entry]. Both PAS PDM mapper and the SLPI sensor
  service depend on the machine-compatible domain table; `QCOM_PD_MAPPER`
  uses `of_machine_get_match()` and its SM8250 table includes `slpi_root_pd`
  and `slpi_sensor_pd` [V: L/drivers/soc/qcom/qcom_pd_mapper.c,
  `sm8250_domains`/`qcom_pdm_start`]. It cannot select that table under the
  stock overlay's root compatible. Nura's package builds/installs an empty
  DTBO [V: <https://gitlab.com/postmarketOS/pmaports/-/raw/master/device/testing/device-oneplus-instantnoodlep/APKBUILD>, `kernel_mainline()`].

## 1. Source pins

- `L/` = local mainline tree `~/src/l`, branch `instantnoodlep-k2` @
  `a28aaf1a09db`, kernelrelease `7.3.0-rc6-instantnoodlep-k2-ga28aaf1a09db`
  [V: NOTES.md 2026-11-16 "R7, K2 passes R1-R5"]. Paths cited relative to it.
- `E/` = decompiled stock DTBO entry 16 ("kona MTP 19811",
  `oplus,dtsi_no = 0x4d63`) at `~/android/build/p3/entry16.dts` [V: NOTES.md
  2026-11-16 morning, P3]. Facts only: GPIOs, addresses, compatibles.
- `U/` = `~/src/omarchy-mobile` checkout (upstream pin `6c11752ae4c3...` per
  FIRMWARE-PLAN §1 [V]); line refs are from this checkout.
- `C/` = community SM8250 kernel @ `3c5440e9dd3c` (tag `7.2.0-dev`). **Not
  re-opened in this session (no network)**; its facts are cited second-hand
  via `DTS-PORT-PLAN.md` §2, which quotes C line numbers [V: DTS-PORT-PLAN
  §1-§2]. Anything only C could prove is [I].
- Public source checks completed during review: `D/` darknagel Nura
  `docs/sensors.md`, `docs/audio.md`, and `firmware/dsp-firmware.sh`;
  `github.com/linux-msm/hexagonrpc` README; and `codeberg.org/agx/libssc`
  README/docs. These verify the documented stack and firmware/config
  locations, not the exact packages/firmware members for this build.
- The pinned Nura kernel `C/` tree remains unavailable behind its Anubis
  gate; Arch Linux ARM package availability also remains [I] with a gate in
  §8.

## 2. Hardware identification

| Part | Identity | Evidence |
| --- | --- | --- |
| Sensor hub | Qualcomm **SLPI** (remoteproc `slpi` @ `0x05c00000`, `qcom,sm8250-slpi-pas`) hosting accel/gyro/mag/ALS/prox | [V: L/arch/arm64/boot/dts/qcom/sm8250.dtsi:3091-3092]; stock DT lists gsensor, 2x msensor, lsensor, psensor, ssensor, sdsensor, cctrsensor + virtual pickup/lux_aod under `oplus_sensor` ("oplus,sensor-devinfo") [V: E:11164-11257]; accel/gyro/mag/ALS/prox on SLPI per task scope |
| Physical sensor chips on SLPI | not named in DT (vendor uses sensor-name ids, e.g. bus-number 5 / irq 0x7a for lsensor/psensor) | [V: E:11193-11215]; chip models [I-S5-4] — resolve from public docs or Nura's sensor output at packaging gate |
| Hall sensors (2) | **iST8801** @ `0x19`/`0x18` or **Magnachip MXM1120** @ `0x0d`/`0x0c` on QUP SE1 I2C (`qupv3_se1_i2c`), IRQ TLMM GPIO 157 (`0x9d`) and 158 (`0x9e`), supply `pm8150a_l10`; compatibles `oplus,hall-ist8801,up/down`, `oplus,hall-mxm1120,up/down` | [V: E:12579-12643]; which of the two parts this unit has is [I-S5-3]; mainline rail name for `pm8150a_l10` is `vreg_l10a_1p8` [V: DTS-PORT-PLAN §2.2, C:392-397] |
| Fingerprint | **Goodix optical under-display**, chip names `G_OPTICAL_19811_G5` / `G_OPTICAL_19811_G6`, compatible `goodix,goodix_fp`, IRQ GPIO 23 (`0x17`), reset GPIO 68 (`0x44`), power GPIO 125 (`0x7d`), id GPIO 77 (`0x4d`) | [V: E:11407-11448]; no separate SPI/I2C address node — vendor talks to it over a secure channel, FOD brightness is panel-side (`oplus,dsi-fod-brightness`) [V: E:5998] |
| Vibrator | **Awinic AW8697** LRA @ `0x5a` on QUP SE11 I2C (`qupv3_se11_i2c`), reset GPIO 72 (`0x48`), IRQ GPIO 118 (`0x76`), compatible `awinic,aw8697_haptic` | [V: E:11687-11703]; a second node `pm8150b_haptics` `qcom,haptics@0xc000` (LRA, boost rail `vreg_hap_boost` on pm8150b_gpios GPIO 5) also exists [V: E:1116-1127, 2279-2289]; which actuator is wired on this unit is [I-S5-2] |

## 3. Inventory per block

"K2 today" is the M1b kernel-2 DTB state [V: DTS-PORT-PLAN §3.2-§3.3].

### 3.1 SLPI remoteproc + GLINK + FastRPC

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| SLPI remoteproc node | present, generic, `status = "disabled"` | `qcom,sm8250-slpi-pas`, L/sm8250.dtsi:3091-3117; binding enum lists it [V: L/Documentation/devicetree/bindings/remoteproc/qcom,sm8150-pas.yaml:37,112,169] | disabled [V: DTS-PORT-PLAN §3.3: "ADSP, CDSP, SLPI ... remain disabled in K2"] | `&slpi { status = "okay"; firmware-name = "qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn"; }` — match the firmware.map destination. Public Nura setup confirms its phone-specific SLPI source is `/image/slpi.mdt` in the active modem image, joined with `pil-squasher`; the OTA member/hash must still be checked at F2/F3 [V: D/firmware/dsp-firmware.sh, `modem_$slot` and `/image/$fw.mdt`] |
| SLPI load data | present | `qcom_q6v5_pas.c`: `qcom,sm8250-slpi-pas` → `sdm845_slpi_resource_init`: firmware `slpi.mdt`, pas_id 12, auto_boot, proxy PDs lcx/lmx, sysmon `slpi` [V: L/drivers/remoteproc/qcom_q6v5_pas.c:1382-1396, 1893] | driver built as module [V: device kernel.config:70 `CONFIG_QCOM_Q6V5_PAS=m`]; defconfig also =m [V: L/arch/arm64/configs/defconfig:1629] | nothing new; module load at boot or =y in device config |
| SLPI reserved memory | generic `slpi_mem` 0x88c00000/21 MiB [V: L/sm8250.dtsi:848-851]; community uses 0x90600000/21 MiB [V: DTS-PORT-PLAN §2.1, C:195-198] | reserved-memory binding | K2 already carries the community region [V: DTS-PORT-PLAN §3.2 item 4] | nothing |
| GLINK edge + IPCC + SMP2P | present, generic: `glink-edge` under `&slpi` with `qcom,remote-pid = <3>`, IPCC mboxes [V: L/sm8250.dtsi:3119-3127]; `ipcc` @0x408000 [V: :976]; `smp2p-slpi` [V: :931-948]; `aoss_qmp` [V: :5103]; `rpmhpd` LCX/LMX (SM8250_LCX=4, LMX=5) [V: :6231; L/include/dt-bindings/power/qcom,rpmhpd.h:171-172] | `RPMSG_QCOM_GLINK` (qcom_glink.o includes `qcom_glink_native.o`) selected via `RPMSG_QCOM_GLINK_RPM=y` in defconfig [V: L/drivers/rpmsg/Makefile:8-9, Kconfig:43-49; L/arch/arm64/configs/defconfig:1637-1638]; `QCOM_IPCC=y`, `QCOM_SMP2P=y`, `QCOM_SMEM=y`, `REMOTEPROC=y` [V: defconfig:1615,1663,1661,1624] | nodes exist, unused (slpi disabled) | verify `CONFIG_RPMSG_QCOM_GLINK=y` and `CONFIG_QCOM_PD_MAPPER` + QRTR/QMI/PDR dependencies at O2; PDM mapper needs the neutral root compatible to register SM8250 service domains |
| FastRPC on SLPI | present, generic: `fastrpc` child `compatible = "qcom,fastrpc"`, channel `fastrpcglink-apps-dsp`, `label = "sdsp"`, `qcom,non-secure-domain`, 3 `compute-cb` with iommus `apps_smmu 0x541-0x543` [V: L/sm8250.dtsi:3129-3155; apps_smmu @ L/sm8250.dtsi:5902] | binding [V: L/Documentation/devicetree/bindings/misc/qcom,fastrpc.yaml:20-60 — label enum includes `sdsp` (:33-44), `qcom,non-secure-domain` (:58-60)]; driver creates misc device `fastrpc-<label>` (+ `-secure` if secure) [V: L/drivers/misc/fastrpc.c:2468-2469], domain id from label [V: :2484-2498], `qcom,non-secure-domain` clears secure [V: :2599] → `/dev/fastrpc-sdsp` non-secure | node exists (disabled with slpi); `QCOM_FASTRPC=m` in defconfig [V: defconfig:312] | enable with slpi; config `=y` or module loaded by service; sensor service needs the `dsp_<slot>/sdsp` libraries, a separate source from `modem`'s SLPI image [V: D/firmware/dsp-firmware.sh] |
| Kernel IIO for SLPI sensors | **absent**: no qcom/slpi/sns entry in `drivers/iio` Kconfig, `drivers/iio/common/`, prox/mag/light listings, and no `slpi` in L/Documentation [V: greps over L/drivers/iio and L/Documentation, empty] | none in kernel; sensors are consumed over FastRPC in userspace | n/a | userspace stack (§5); the exact IIO bridge iio-sensor-proxy reads is [I-S5-1] |

### 3.2 Hall sensors (AP-wired)

| Piece | Status |
| --- | --- |
| Mainline driver for `oplus,hall-*` | **none** — no `hall` in L/Documentation/devicetree/bindings/input or bindings/iio, none in drivers/iio/{light,magnetometer,proximity} listings or drivers/input/misc/Kconfig [V: greps empty] |
| Generic mainline path | `gpio-keys` with switch nodes: binding allows `switch` child nodes and arbitrary `linux,code` [V: L/Documentation/devicetree/bindings/input/gpio-keys.yaml:26,55,106]; `SW_LID` is a standard input switch code [V: L/include/uapi/linux/input-event-codes.h:935] → two `switch` nodes on GPIO 157/158 reporting `SW_LID` (cover open/closed), no new driver |
| Node data | IRQ GPIOs 157/158, edge-both (0x2008), supply `pm8150a_l10` = `vreg_l10a_1p8` [V: E:12586-12608, 12619-12641; DTS-PORT-PLAN §2.2 C:392-397] — that rail is currently "later only with an identified consumer" [V: DTS-PORT-PLAN §2.2] and M5 is that consumer |
| K2 today | absent; TLMM reserved ranges `<28 4>, <40 4>` do not cover 157/158 [V: DTS-PORT-PLAN §3.2 item 12] | add nodes + `vreg_l10a_1p8` + pinctrl |

### 3.3 Fingerprint under display (AP-wired, identify only)

| Piece | Status |
| --- | --- |
| Part | Goodix optical FOD, G5/G6 variants, `goodix,goodix_fp` [V: E:11414-11448] |
| Mainline driver | **none**: L/drivers/input has no `fingerprint/` subdir [V: listing of L/drivers/input], no qbt handler in drivers/soc/qcom [V: listing + grep empty], no goodix anywhere in U/ [V: grep over ~/src/omarchy-mobile for `goodix` empty]. U/ has a generic `fingerprint/bridge/omamobile-fp-bridge.c` + `fingerprint/shim/omamobile-fp-shim.c` used by Pixel (Trusty `/dev/trusty-ipc-dev0` path) [V: U/fingerprint/{bridge,shim}/ listings; U/kernel/configs/omamobile.config:201] — not applicable to Goodix |
| M5 scope | document the part and GPIOs; **no driver port** — the vendor protocol runs over a secure channel and no GPL source was opened; per AGENTS.md rule 5 we describe, not copy. Unlock-via-fingerprint stays out of scope for M5 [I: whether any community GPL goodix_fod driver exists — check darknagel repo / pmaports at gate O6; not opened here] |

### 3.4 Vibrator / haptics (AP-wired)

| Piece | Status |
| --- | --- |
| AW8697 node | `awinic,aw8697_haptic` @0x5a, reset GPIO 72, IRQ 118 [V: E:11693-11702] |
| Mainline driver | `aw86927.c` (i2c driver, `module_i2c_driver`) matches **only** `awinic,aw86927` [V: L/drivers/input/misc/aw86927.c:864, 870-878]; binding enum `awinic,aw86927`/`aw86938` only, requires compatible/reg/reset-gpios/interrupts, example is literally `vibrator@5a` [V: L/Documentation/devicetree/bindings/input/awinic,aw86927.yaml:13-19,30-34,47-52]; `CONFIG_INPUT_AW86927=m` in defconfig [V: defconfig:545] |
| aw8697 coverage | **not covered** by driver or binding [V: aw86927.c:864 single id; yaml:13-19]; whether AW8697 is register-compatible with AW86927 (then: add `awinic,aw8697` to driver+binding) is [I-S5-5] — compare against a public GPL aw8697 source at gate O6, never from a leaked one |
| PMIC fallback | `qcom,haptics@0xc000` on PM8150B with boost rail [V: E:1116-1127, 2279-2289]; binding `qcom,spmi-haptics.yaml` exists [V: L/Documentation/devicetree/bindings/input/qcom,spmi-haptics.yaml], but **no matching driver found** under L/drivers/input, /leds, /platform, /char (Kconfig + listings grepped empty) [V; driver location in this tree [I-S5-2]] |
| K2 today | absent | add i2c child + pinctrl + driver/binding extension if [I-S5-5] resolves yes |

## 4. Firmware needs (tied to firmware.map, names only)

Rule unchanged: from the owner's own verified OTA at install time, names only,
never committed (AGENTS.md rule 8; FIRMWARE-PLAN §4).

| Need | firmware.map row / proposal | Evidence |
| --- | --- | --- |
| SLPI firmware | existing row `modem:/image/slpi.mdt\|qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn` (joined with .bNN via pil-squasher per map header) | [V: firmware.map "SoC remoteprocs" block]; driver default `slpi.mdt` overridden by our DT `firmware-name` [V: L/qcom_q6v5_pas.c:1384] |
| Sensor platform configuration | Nura documents configuration under the phone's `/vendor/etc/sensors` and a separate `/odm/etc/sensor` directory [V: D/docs/sensors.md, “Setting up sensors…”]. Candidate map rows may be added only after F2 names-only listing and a privacy/licence review; do not map every file blindly. Exact OTA members and the subset required by libssc remain [I-S5-6]. | [V: D/docs/sensors.md; public `hexagonrpc` README describes the HexagonFS sensor config/registry paths] |
| Sensor DSP libraries | Nura's service copies libraries from the active `dsp_<slot>/sdsp` tree into the HexagonFS path [V: D/firmware/dsp-firmware.sh, `need_libs` section]. Names and whether the verified OTA contains the same layout are [I-S5-6]; if a safe mapping is needed, add names-only rows after F2. | [I-S5-6; FIRMWARE-PLAN F1/F2 must include a names-only inspection of the `dsp` image if present] |
| Proximity calibration / sensor registry data | Nura obtains factory proximity calibration from `persist` [V: D/firmware/dsp-firmware.sh, `need_cal`; D/docs/sensors.md, “Proximity”]. This is per-unit calibration and is explicitly not mapped or extracted by this plan (AGENTS.md evidence/privacy policy and FIRMWARE-PLAN §3). Functional near/far calibration is out of scope until a separately gated privacy-safe local provisioning plan exists. | [V: D/firmware/dsp-firmware.sh; no persist member row permitted here] |
| Hall / fingerprint / vibrator | none requested by the gpio-keys path or aw86927-family driver [V: aw86927.c requests no firmware; gpio-keys none] | [V] |

## 5. Userspace pieces (Arch Linux ARM rootfs on `userdata`)

| Need | Plan | Evidence |
| --- | --- | --- |
| FastRPC daemon + sensor protocol | `hexagonrpcd` + `libssc` in the device package; systemd unit runs it after `remoteproc` brings `slpi` up; opens `/dev/fastrpc-sdsp` | device node name [V: L/fastrpc.c:2468-2469 + sm8250.dtsi label `sdsp` :3132]; hexagonrpc documents FastRPC/HexagonFS and the sensor config/registry paths [V: <https://github.com/linux-msm/hexagonrpc>, README]; libssc documents its Sensor Core client and supported sensor classes [V: <https://codeberg.org/agx/libssc>, README/docs]; no package pins selected yet (must be pinned at implementation). Keep mutable registry/cache under `/run` (tmpfs); persistent writes under `/var/lib` on `userdata` require a separately owner-gated decision and rollback. |
| IIO consumers | `iio-sensor-proxy` + D-Bus `net.hadess.SensorProxy` for rotation/ALS. The Nura device documentation confirms the `hexagonrpcd` + `libssc` + `iio-sensor-proxy` stack on instantnoodlep [V: D/docs/sensors.md, “What the image does” and “Setting up…”]; exact bridge/library packaging in our Arch image is still [I-S5-1]. **Do not install `omamobile-sensors`**: its PKGBUILD is Pixel-7-Pro-AoC-specific and conflicts/provides `iio-sensor-proxy` [V: U/packages/omamobile-sensors/PKGBUILD:6-13] | Arch Linux ARM package availability remains [I-S5-8] |
| Rotation / brightness consumers | wlroots/Hyprland read iio-sensor-proxy over D-Bus for auto-rotate; brightness from the ALS channel; which omamobile shell control drives brightness is [I-S5-9], check at R6 against the running shell | [I-S5-9] |
| Permissions | udev rule: `MODE="0666"` (or group `sensors`) on `/dev/fastrpc-sdsp` so the service runs non-root | device node [V: L/fastrpc.c:2468-2469]; rule content [I] |
| Hall events | gpio-keys → `/dev/input/event*` `SW_LID`; consumed by logind (lid) | [V: L/input-event-codes.h:935] |
| Vibrator | AW86927-family driver exposes input force-feedback `FF_RUMBLE`; inspect events with `evtest` and exercise force feedback with `fftest` (there is no `evtest --play` mode) | driver [V: L/drivers/input/misc/aw86927.c, input_ff_create_memless and FF_RUMBLE] |

## 6. Kernel-side commit order (in linux-omarchy-mobile, not this repo)

One logical change per commit, GPL-2.0 headers; re-run offline gates after
each. No new bindings needed for SLPI (binding exists [V: qcom,sm8150-pas.yaml:37])
or hall (gpio-keys [V]). 

| # | Commit | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: instantnoodlep: Enable SLPI` | `&slpi` okay + `firmware-name = "qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn"` (string identical to firmware.map row) [V: firmware.map; L/sm8250-xiaomi-elish-common.dtsi:920-921 shape] |
| 2 | `arm64: dts: qcom: instantnoodlep: Add hall sensors` | two gpio-keys `switch` nodes (GPIO 157/158, SW_LID), `vreg_l10a_1p8` rail + pinctrl [V: E:12586-12643; DTS-PORT-PLAN §2.2 C:392-397] |
| 3 | `dt-bindings: input: awinic: Add AW8697` + `input: aw86927: add aw8697 compatible` | only if [I-S5-5] confirms register compatibility; else a small new driver commit |
| 4 | `arm64: dts: qcom: instantnoodlep: Add vibrator` | `aw8697@5a` on the SE11 i2c + pinctrl (reset 72, irq 118) [V: E:11693-11702]; mainline `&i2cN` label for `qupv3_se11_i2c` resolved by address against the stock base DT [I-S5-3] |
| 5 | `config: instantnoodlep: sensors` | device `kernel.config`: `QCOM_Q6V5_PAS`, `QCOM_FASTRPC`, `QCOM_PD_MAPPER`, `QRTR`/QMI/PDR helpers, `RPMSG_QCOM_GLINK*` (via defconfig chain [V: defconfig:1637-1638,1615]), `IIO` + buffer/triggered-buffer, `INPUT_AW86927`, `INPUT_GPIO_KEYS`, `INPUT_EVDEV` [V: defconfig:525,1693] — pin =y the boot-critical drivers and ensure `QCOM_PD_MAPPER` is ready before SLPI start; neutral DTBO must restore machine-compatible matching |

Fingerprint: no commit (documented in §3.3).

## 7. Gated runbook

Offline gates O0-O7 touch no phone. Owner gates G1, R1-R7 run on the phone,
**RAM boot first** (`fastboot boot`, nothing written), as M1a/M1b did; every
phone command is a block with Expect / Stop / Rollback (AGENTS.md rule 1).
Never `fastboot flash`, `erase`, `--set-active` anywhere below. M5 runs after
M3 has passed (panel+Hyprland up), because R6 reads rotation/brightness in the
shell.

```sh
export L=/path/to/linux-omarchy-mobile
export OUT=/path/to/private/m5-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export K2DTB=/path/to/private/k2-build/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1b + M3 results in NOTES.md; neutral DTBO owner-gated install on `dtbo_b` complete and live root compatible verified; DTS-PORT-PLAN D0-D9 passed; FIRMWARE-PLAN F0-F6 passed with SLPI firmware and sensor-library source names audited | all present; `modem:/image/slpi.mdt` and candidate `dsp` library members are names-only evidence, with no persist calibration row | any input missing or firmware/library source unresolved | no changes; return to owning ticket |
| O1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` on base; repeat after commit 3 (aw8697) with its yaml | no new schema errors | new error | drop the binding edit |
| O2 Build + config | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after every commit; `grep` the .config for `CONFIG_RPMSG_QCOM_GLINK=y`, `QCOM_FASTRPC`, `QCOM_Q6V5_PAS`, `QCOM_PD_MAPPER`, QRTR/QMI/PDR, `IIO=y`, `INPUT_AW86927`, `INPUT_GPIO_KEYS` | dtc exit 0; all configs set as planned | any config missing (defconfig chain broke) | pin it in device kernel.config; rebuild |
| O3 Schema | `make ... dtbs_check` | no new warning/error for this board | schema failure | revert current commit |
| O4 Node checks | `fdtget` block below vs `"$DTB"`, diff vs `"$K2DTB"` limited to the M5 set, and read live `/compatible` | slpi okay + firmware-name string; hall switch nodes; vibrator node; built/live root is `oneplus,instantnoodlep`, `qcom,sm8250` | any extra enable or wrong live root identity | discard output; fix defining commit / return to neutral-DTBO gate |
| O5 Live-DT compare | decompile `"$DTB"` + stage-0 `live.dtb`; classify every hall/vibrator/slpi-related difference | no unexplained difference | unexplained difference | suppress candidate; update plan |
| O6 Userspace packaging | pin public `linux-msm/hexagonrpc` and `libssc` source revisions; build/package them with the device-specific sensor service and audit candidate config/library file names; keep mutable registry/cache under `/run` and assert no persistent `userdata` writes; PKGBUILD asserts no firmware bytes, identity or per-unit calibration data, and firmware.map is names-only (`git check-ignore '*.mbn'`) | package builds; provenance/file allowlist reviewed; no `persist` calibration mapped; generated state is volatile | any blob, identity/calibration data, unapproved persistent state write, or unpinned source | delete package |
| O7 Release | review commits 1-5, O1-O6 logs, hashes, open [I]s with coordinator/owner | written approval for one RAM boot; no sensor calibration from `persist` is packaged | any failed gate or [I] promoted to fact | keep M3 state; do not boot |

O4 `fdtget` checks:

```sh
fdtget -t s "$DTB" /soc@0/remoteproc@5c00000 status
fdtget -t s "$DTB" /soc@0/remoteproc@5c00000 firmware-name
fdtget -t s "$DTB" /soc@0/remoteproc@5c00000/glink-edge/fastrpc label
fdtget -t s "$DTB" /soc@0/remoteproc@5c00000/glink-edge/fastrpc qcom,non-secure-domain   # present
fdtget -t s "$DTB" /soc@0/gpio-keys status                       # hall (path per commit 2)
fdtget -t x "$DTB" /soc@0/gpio-keys/switch-up gpios              # tlmm phandle + 157
fdtget -t s "$DTB" /soc@0/i2c@a94000 status                      # any enabled consumer bus, per commit 4 label
fdtget -t s "$DTB" / compatible
```

Expected: slpi `okay`, firmware-name exactly
`qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn` [V: firmware.map], fastrpc
label `sdsp` with `qcom,non-secure-domain` [V: L/sm8250.dtsi:3132-3133], root
compatible unchanged (`oneplus,instantnoodlep`, `qcom,sm8250`).

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` = M5 boot image from O6/O7; `{{SERIAL}}` = pinned
fastboot serial (private). Never run a block with a `{{...}}` in it. Captures
to `captures/<date>/m5/` (gitignored).

| # | Step (command block) | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` + slot flags, recorded | one device; flags equal to the last NOTES.md capture (slot B active, successful) [V: NOTES.md 2026-11-17 B5] | flags differ | `fastboot -s {{SERIAL}} reboot`; record |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; then `ssh root@172.16.42.1` [V: NOTES.md 2026-11-17, usb0 172.16.42.1], read `/sys/firmware/devicetree/base/compatible`, and `dmesg` | `Booting OKAY`; live root is `oneplus,instantnoodlep` + `qcom,sm8250`; SSH; `qcom_q6v5_pas` loads `slpi` firmware with no firmware error; glink edge `slpi` up; `fastrpc` probe creates a device; PDM mapper selects SM8250 service domains | wrong live root; firmware-load error; no SSH after 2 min | cold-reboot to bootloader first (a refused RAM boot can swap slots [V: NOTES.md 2026-11-16 R1 lesson]), then stop and return to the neutral-DTBO gate |
| R2 | over SSH: `for r in /sys/class/remoteproc/remoteproc*; do cat "$r/name" "$r/state"; done`; `ls -l /dev/fastrpc*` | `slpi` in `running`; `/dev/fastrpc-sdsp` exists (non-secure) | remoteproc in `offline`/`error`, or no fastrpc node | `reboot -f`; fix commit 1/O2 |
| R3 | over SSH: start `hexagonrpcd` (unit or foreground), verify its mutable registry/cache is under `/run`, inspect `dmesg`, then `ssccli --sensor accelerometer --timeout 3` if packaged and list sensor interfaces | daemon opens `/dev/fastrpc-sdsp`, SLPI SNS service answers; the public Nura stack uses `hexagonrpcd` + `libssc` + `iio-sensor-proxy` [V: D/docs/sensors.md], but this build's IIO bridge must be identified at O6/R3; no persistent registry write occurs | daemon fails to open/invoke, writes into `userdata` without a separate owner go, or no sensor interface is exposed | `reboot -f`; record; resolve bridge/packaging and remove any test state before retry |
| R4 | over SSH: verify the concrete bridge selected at O6/R3; query `iio-sensor-proxy` over D-Bus (`busctl`/`gdbus` call `net.hadess.SensorProxy`) only if the libssc integration is installed; otherwise query the bridge's documented test client. Read accel + ALS while moving the phone/covering the light sensor. Do not test proximity calibration from `persist` in this plan. | accelerometer and ALS values change with orientation/light; proximity reports discovery only, not calibrated near/far | no sensor data or a test requires reading/copying per-unit calibration | `reboot -f`; resolve [I-S5-1]/[I-S5-6] before retry |
| R5 | over SSH: `evtest` on the hall event node; cover/uncover with a magnet | `SW_LID` events toggle | no events | `reboot -f` |
| R6 | boot the installed slot-B system; in Hyprland: rotate the phone, watch `hyprctl monitors` orientation; change ambient light, watch panel brightness via `/sys/class/backlight` + iio-sensor-proxy ALS | rotation follows accel; brightness follows ALS | no rotation/brightness response | reboot; record; fix consumer [I-S5-9] |
| R7 | over SSH: identify the vibrator input event node with `evtest --info`; use `fftest /dev/input/eventN` to test `FF_RUMBLE` (AW8697 driver) | actuator buzzes (AW8697 or PMIC, per [I-S5-2]) | no vibration; check dmesg for driver probe | `reboot -f` |
| R8 | `fastboot -s {{SERIAL}} getvar all` (filtered); confirm slot flags equal G1 | nothing written by any step | any flag changed | stop; record; ask on #808 before any further boot |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-S5-1 | Exact userspace IIO bridge/library integration used by the public Nura image and whether the selected Arch packages provide it. Nura confirms `hexagonrpcd` + `libssc` + `iio-sensor-proxy` on instantnoodlep [V: D/docs/sensors.md], but the implementation must be pinned and audited for this package. | O6 public source/package audit + R3/R4 on device |
| I-S5-2 | Which actuator is wired (AW8697 vs PM8150B `qcom,haptics`), and where the spmi-haptics driver lives in this L tree (binding exists, driver not found under input/leds/platform/char [V: §3.4]) | R7 dmesg + i2cdetect; O6 source audit |
| I-S5-3 | Unit's hall part (iST8801 vs MXM1120) and the mainline `&i2cN` labels for `qupv3_se1_i2c` / `qupv3_se11_i2c` (address match vs stock base DT) | O5 live-DT compare + stage-0 capture; R5 |
| I-S5-4 | Physical accel/gyro/mag/ALS/prox chip models behind the SLPI | C/ docs / Nura README at O6; R4 dmesg from the sns service |
| I-S5-5 | AW8697 register-compatible with AW86927 (then extend aw86927.c + yaml [V: aw86927.c:864]) | O6: compare against a public GPL source only; O1 binding check |
| I-S5-6 | Exact OTA member names for sensor config (`vendor/etc/sensors`, `odm/etc/sensor`) and DSP libraries (`dsp/sdsp`); which are needed by libssc | FIRMWARE-PLAN-style F2 listing of vendor/odm/dsp images (names only), source audit + R3; never enumerate/dump `persist` calibration |
| I-S5-7 | Exact pinned revisions and build deps for hexagonrpc and libssc | Public sources are verified: <https://github.com/linux-msm/hexagonrpc> README and <https://codeberg.org/agx/libssc> README/docs; select immutable revisions and record their build dependencies at O6 |
| I-S5-8 | Arch Linux ARM ships `iio-sensor-proxy` for aarch64 | O6: query archlinuxarm.org / pacman on the phone |
| I-S5-9 | Which omamobile shell element consumes ALS for brightness on this device | R6 on the installed system |

## 9. Definition of done for M5 sensors

O0-O7 pass; G1, R1-R8 pass with pasted (redacted) output; SLPI runs
`slpi.mbn` from the owner-extracted file (firmware.map row), the vetted sensor
libraries are sourced from the owner's image without mapping `persist`
calibration, `/dev/fastrpc-sdsp` exists, accel/ALS data are exposed through
the verified bridge, Hyprland auto-rotates/auto-brightens, hall reports
`SW_LID`, and the vibrator plays; slot flags unchanged; results appended to
NOTES.md with dates. Proximity near/far remains gated on a separate
privacy-safe calibration plan. Commits 1-5 exist in a linux-omarchy-mobile
branch with gates rerun. Fingerprint remains documented-only (no open driver
ported, AGENTS.md rule 5).


## 10. Phase 1 implementation: isolated combo candidate (2026-11-17)

[V] This section supersedes the neutral-DTBO prerequisite and the full-M5
completion gates **for phase 1 only**. Neutral DTBO was rejected by ABL;
stock `dtbo_b` stays installed (learning `l-48e0c482`). The combo base
`aa996bae0695` has a test-only `qcom,kona` PDM-table entry
(`drivers/soc/qcom/qcom_pd_mapper.c:661`), selecting `sm8250_domains`,
including `slpi_root_pd` and `slpi_sensor_pd` (:579-585). Live root compatible
is therefore expected to remain `qcom,kona-mtp`, `qcom,kona`, `qcom,mtp`,
not the built DTB identity. This inherited workaround must never go upstream.
No DTBO change, hall, vibrator, fingerprint, charger, or other remoteproc
enable is part of phase 1. [I] SLPI runtime and SSC sensors remain untested.

### 10.1 Reproducible kernel inputs

[V] Worktree `~/src/l-k3-sensors`, branch `instantnoodlep-k3-sensors`, based
on combo `aa996bae0695`. The two portable patches are in
`device/instantnoodlep/patches/sensors/`; apply only to that base with
`git am`. Commit 1 enables `&slpi` with the exact firmware.map destination;
commit 2 records `kernel/configs/instantnoodlep-sensors.config`.
The existing SM8250 SLPI GLINK/FastRPC nodes and context banks need no new
DTS definitions (`arch/arm64/boot/dts/qcom/sm8250.dtsi:3129-3155`).
[V] The device-node name is **lowercase** `/dev/fastrpc-sdsp`: the driver
formats the literal DT label (`drivers/misc/fastrpc.c:2468-2469`), which is
`sdsp` (`sm8250.dtsi:3132`). Earlier uppercase references were corrected.

[V] Fresh output root: `~/android/build/k3-sensors-20261117/`.
Build inputs: the verified combo output `.config`, with the sensors fragment
settings and `CONFIG_LOCALVERSION="-instantnoodlep-k3-sensors"`.
The build started with `nice -n 10`; the coordinator subsequently set
non-critical builds to nice 15 due to laptop contention. It uses
`ARCH=arm64 LLVM=1 -j4`, targets `Image.gz`,
`qcom/sm8250-oneplus-instantnoodlep.dtb`, `modules`.
All driver settings in the fragment survived `olddefconfig` as `=y`.
The sensor client uses QRTR/QMI; enabling IIO does not create an SSC IIO
kernel driver. Userspace integration is documented in
[SENSORS-PACKAGING.md](SENSORS-PACKAGING.md).

### 10.2 Coordinator-only gates

[I] No phone command below has been run by this worker. Each gate requires
coordinator/owner review and must stop independently on failure. Captures
stay private in gitignored `captures/`; do not paste identifiers or raw
sensor registries into issues. There is no partition write command here.
Use the owner's pinned private transport selector without publishing it.

| Gate | Command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| S0 offline | Verify artifact hashes and release in §10.3; inspect final boot DTB; independently confirm known-good slot-B boot and private rollback assets | Same Image.gz/DTB/module release; only SLPI newly enabled; no battery/charger change | Any hash/config mismatch or insufficient power for test | Discard candidate; keep combo boot |
| S1 firmware prerequisites | Over the coordinator's existing private SSH transport, `test -r /lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn`; confirm the FIRMWARE-PLAN owner-OTA provenance/hash privately; review names-only sensor config + DSP-library allowlist | Joined SLPI firmware at exact path; libraries/config audited without persist | Missing firmware, unaudited library/config provenance, any need to copy persist | Stop; no boot or provisioning; return to F2/F3 |
| S2 boot construction | Use `tools/build-instantnoodlep-probe --help` and the working M3/combo flags, fresh `--out`, the Image.gz/DTB below, `--boot 2 --root userdata`; perform SLPI restoration described below and unpack-check the final image | Final boot image uses same kernel, DTB SLPI okay, GPU state retained; all other remoteprocs remain disabled; no partition allowlist except userdata | Generic probe still disables SLPI, new output already exists, size or overlay check fails | Delete only the fresh candidate outputs; keep combo image |
| S3 preflight | Coordinator: `fastboot getvar current-slot`; `fastboot getvar slot-successful:b`; `fastboot getvar slot-unbootable:b` (private selector on each command) | b active, successful yes, unbootable no | Any mismatch | Stop in bootloader; ask owner; no slot change |
| S4 RAM boot | `fastboot boot /absolute/path/to/reviewed-fresh-sensors.img`; connect by existing SSH transport within 2 minutes; `tr '\0' ' ' < /sys/firmware/devicetree/base/compatible`; `uname -r` | Booting OKAY; combo live kona root; exact sensors release | Boot rejection, hang/no SSH, unexpected release/root | Owner returns to bootloader with buttons; verify S3 before rebooting installed combo; no automatic stock fallback or slot repair |
| S5 SLPI/FastRPC | `for r in /sys/class/remoteproc/remoteproc*; do printf '%s: ' "$r"; cat "$r/name" "$r/state" "$r/firmware"; done`; `ls -l /dev/fastrpc*`; `dmesg | grep -Ei 'slpi|fastrpc|pdr|pd.mapper|firmware'` | SLPI running with mapped firmware; `/dev/fastrpc-sdsp`; no crash/restart/firmware error | SLPI offline/crashing, missing node, SMMU fault | Reboot to bootloader, verify S3, reboot installed combo; do not retry until logs reviewed |
| S6 ephemeral userspace | Follow packaging note's reviewed `/run` layout and foreground service command; inspect daemon output and `dmesg`; `ssccli --sensor accelerometer --timeout 3`; `ssccli --sensor light --timeout 3` | SNS service responds; changing acceleration and light readings; no persistent state write | Missing vetted userspace/config/libs, DSP crash, daemon failure, any persistent calibration dependency | Stop daemon; reboot installed combo after S3; /run state disappears |
| S7 D-Bus | With reviewed SSC-enabled proxy and temporary udev properties: `timeout 20 monitor-sensor`; `timeout 10 monitor-sensor --proximity`; rotate phone and cover light sensor (owner actions) | Orientation and ALS update; proximity discovery/value if available without factory calibration | No readings, incorrect orientation, calibration access required | Stop proxy/daemon, undo only temporary udev/runtime overrides, reboot installed combo after S3 |
| S8 restore check | Stop foreground services; `reboot bootloader`; repeat S3; `fastboot reboot` only with unchanged flags | Known-good installed combo boots; no partition changed | Slot flag changed or unexpected fallback | Stop in bootloader and ask owner; flash/slot-repair are outside this runbook |

[V] Builder caveat: `make_probe_dtb()` disables every remoteproc
(`tools/build-instantnoodlep-probe:456-457`). Its intermediate
`OUT.probe.dtb` must be copied to a **new** staging path, then only
`/soc@0/remoteproc@5c00000/status` set to `okay` with `fdtput -t s`.
The coordinator must repack with the same known-good mkbootimg arguments
and fresh output, preserving the builder's overlay sink, initramfs,
command line, load addresses and size checks; inspect the unpacked final
DTB and verify its SLPI firmware-name before S4. Do not merely edit the
sidecar DTB and boot the unchanged `.img`. [I] This repack is a pending
coordinator gate; the raw kernel artifacts alone are not a boot image.

[I] S7 proximity is observation only: no persist extraction, factory
calibration import, calibrated near/far acceptance claim, or shell rotation /
auto-brightness acceptance is included in phase 1. Failure to expose sensors
without calibration stays a recorded blocker; it does not authorize a
calibration import. Hall/vibrator and full M5 gates remain future work.

[V] Built-in PAS requests firmware asynchronously before userspace may have
mounted the root filesystem (`drivers/remoteproc/remoteproc_core.c:1685-1700`).
[I] An early missing-file failure can therefore require one explicit SLPI
start after rootfs firmware availability is confirmed. Coordinator gate S5a:
identify exactly the remoteproc whose `firmware` equals the mapped SLPI name;
if and only if its state is `offline` and the only failure was early firmware
availability, run `printf start > "$SLPI/state"` once. Expect running and
`/dev/fastrpc-sdsp`; stop on crash, authentication/SMMU error, or failure to
reach running; rollback via S8. Never guess the remoteproc number or start
another DSP. This is a volatile sysfs action, not a partition write.

### 10.3 Build result

[I] Build and schema validation are in progress; final artifact manifest
will be recorded here before review.
