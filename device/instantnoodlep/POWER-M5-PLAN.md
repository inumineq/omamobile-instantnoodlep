<!-- SPDX-License-Identifier: MIT -->
# POWER-M5-PLAN: battery, charging, USB-C, thermal, suspend on instantnoodlep

House-rule-6 gate for milestone **M5** of the wayfinder map
("Omarchy Mobile port for instantnoodlep (OnePlus 8 Pro IN2023)"): the power
subsystem — battery/fuel gauge/charging, USB-C role switching and orientation,
thermal + cpufreq/cpuidle sanity, suspend-to-idle and wake sources, and PON
reboot/bootloader modes. This file is a plan only; no code is written here.
Nothing in the power subsystem is touched before this plan exists with its
gated runbook (AGENTS.md rule 6).

- Date: 2026-11-17. Branch: `m5-plans` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `FIRMWARE-PLAN.md`, `NOTES.md`, `DISPLAY-M3-PLAN.md` (style template).
- Safety model unchanged: never write `super` or any `_a` partition; flash
  writes only ever name slot-B boot images and `userdata`, each behind an
  owner go. All M5 phone steps are `fastboot boot` (RAM) first; nothing in
  this plan flashes anything. Never `fastboot flash`/`erase`/`--set-active`.

## 1. Source pins

- `L/` = `~/src/l`, branch `instantnoodlep-k2` @ `a28aaf1a09db`
  (linux-omarchy-mobile `317d87dc2db0` + our four DTS commits)
  [V: NOTES.md 2026-11-16 "R7, K2 passes R1-R5"]. Line refs below are valid
  in that tree (K2 = the board file `L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`).
- `C/` = community SM8250 kernel, `gitlab.nura.eco/soc/qualcomm-sm8250/linux`,
  tag `7.2.0-dev`, commit `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9` (pin as
  in DTS-PORT-PLAN §1). I could not open the remote from this environment;
  C/ facts are cited through DTS-PORT-PLAN's quoted line ranges.
- `E/` = `~/android/build/p3/entry16.dts`, decompiled stock dtbo **entry 16**
  of `IN2023_13.1.0.591(EX01)` (15974 lines; cited by fragment number).
  Facts only — GPIOs, rails, addresses, compatible strings; no vendor code is
  copied (AGENTS.md rule 5).
- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (FIRMWARE-PLAN pin). `M/` = torvalds/linux @ `aebb7274476403040d582c61478df8f4a7bf9cd3`
  (DISPLAY-M3-PLAN pin). Remote URLs were not reachable from this
  environment; claims resting on them are tagged [I] or cited via repo files.

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| PMIC stack | PM8150 x2 (USID 0,1), PM8150B x2 (USID 2,3), PM8150L x2 (4,5), PM8009 x2 (a,b), PMX55 (8,9) on SPMI | [V: NOTES.md 2026-11-16 stage-0 D5 live-DT list]; generic nodes: L/pm8150.dtsi:47-143, L/pm8150b.dtsi:46-179, L/pm8150l.dtsi |
| Stock wired charger | PM8150B (USID 2) SMB5 block, stock compatible `qcom,qpnp-smb5`, carries VOOC/Warp props (`qcom,vooc_project`, `qcom,input_current_vooc_ma_*`, `qcom,oplus-pps-usbpd-detection`, `qcom,wireless_support`), `qcom,external_gauge`, `qcom,batt_capacity_mah = <0x119e>` (4502 mAh) | [V: E/ fragment@2, `pm8150b_charger: qcom,qpnp-smb5` block] |
| External charger IC | TI **BQ25980** on `i2c5` @ `0x66` | [V: DTS-PORT-PLAN §2.3 quoting C:626-637 `&i2c5` + `charger@66`] |
| Fuel gauge | TI **BQ27411** on `i2c16` @ `0x55`; stock PM8150B FG (`qcom,fg-gen4`) is `status = "disabled"` with `qcom,external_gauge` | [V: DTS-PORT-PLAN §2.3 quoting C:639-647; E/ fragment@2 `pm8150b_fg` disabled] |
| Battery | single pack, ID resistor read via PM8150B VADC `bat_id@4b`; stock profiles: ID 0x6b (107 kΩ) = 3600 mAh/4.35 V, ID 0x3c (60 kΩ) = 3450 mAh | [V: E/ fragment@2 vadc `bat_id@4b`; E/ fragment@72 `kona_mtp_batterydata`] |
| USB-C controller | PM8150B (USID 2) `typec@1500` + `pdphy@1700`; stock sink PDOs 5 V/3 A, 9 V/3 A, 12 V/2.25 A; VBUS reg `0x1100`; stock wires `extcon = <&pm8150b_pdphy>` on usb0 and the QMP DP PHY | [V: E/ fragment@2 `pm8150b_pdphy qcom,default-sink-caps = <0x1388 0xbb8 0x2328 0xbb8 0x2ee0 0x8ca>`; E/ fragments 9-11] |
| Wireless charging | IDT receiver behind OnePlus-specific pinctrl: pm8150 gpio10 `idt_en`, gpio1 `usbin_int` (`op_wlchg_pm8250_gpio`); pm8150l gpio8 `wrx_en`, gpio11 `wrx_otg` (`op_wlchg_pm8150a_gpio`) | [V: E/ fragment@0 `op_wlchg_pm8250_gpio`; E/ fragment@4 `op_wlchg_pm8150a_gpio`] |
| Thermal sensors | SoC TSENS0 (16 sensors) + TSENS1 (9), PM8150/PM8150B/PM8150L temp-alarm (die temp), PM8150B VADC `chg_temp@9`, adc-tm `skin_therm@4d`/`conn_therm@4f` | [V: L/sm8250.dtsi:5039-5061 tsens0/tsens1 `qcom,sm8250-tsens`; L/pm8150.dtsi:78-83; L/pm8150b.dtsi:100-106, 130-133, 135-141; E/ fragment@2 vadc/adc_tm channels; E/ fragment@76 zones] |
| PON / keys / RTC | pm8150@0 `pon@800` `qcom,pm8998-pon` with pwrkey (KEY_POWER) + resin (KEY_VOLUMEDOWN); pm8150b@2 has a second `pon@800` `qcom,pm8916-pon`; `rtc@6000` `qcom,pm8941-rtc` (alarm at 0x6100) | [V: L/pm8150.dtsi:53-74, 108-113; L/pm8150b.dtsi:49-53; E/ fragment@0 `qcom,power-on@800`, `pm8150_rtc`] |

## 3. Inventory per block

"Mainline status" cites `L/`. "K2 today" cites the K2 board file.

### 3.1 Charger paths — PM8150B SMB5 vs glink vs direct drivers

| Path | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| PM8150B SMB5 charger (`qcom,qpnp-smb5`, stock wired/VOOC path) | **no driver, no binding** in L: power/supply bindings list has no smb5; `qcom_smbx.c` matches only `qcom,pmi8998-charger` / `qcom,pm660-charger` | none [V: L/Documentation/devicetree/bindings/power/supply listing; L/drivers/power/supply/qcom_smbx.c:1036-1039] | node doesn't even exist (K2 does not include pm8150b.dtsi) [V: K2 dts includes] | nothing — deliberately not ported; VOOC/Warp is downstream-only (see verdict below) |
| PMIC glink battery manager | exists but is an auxiliary `pmic_glink.power-supply` service for newer SoCs | `qcom_battmgr.c` id `pmic_glink.power-supply` [V: L/qcom_battmgr.c:1716-1720] | n/a | not used: this phone has a local I2C gauge (stock `qcom,external_gauge`, FG disabled) [V: E/ fragment@2] |
| Direct SMBx driver | covers pmi8998/pm660 only, not PM8150B | `qcom_smbx.c` [V: :1036-1039] | n/a | not applicable to PM8150B |
| TI BQ25980 on i2c5@0x66 | **present**: driver + binding | `drivers/power/supply/bq25980_charger.c` of_match `ti,bq25980/75/60` [V: :1271-1275]; binding `bq25980.yaml` requires `compatible`, `reg`, `monitored-battery` [V: L/.../bq25980.yaml:66-70] | node absent; i2c5/qupv3_id_0 disabled [V: L/sm8250.dtsi:1430-1910 i2c5 under qupv3_id_0, `status = "disabled"`; K2 dts enables only qupv3_id_1] | DTS commit: i2c5 + charger@66 node with supplies/interrupt from C:626-637 (values [I] until live-DT compare), qupv3_id_0 okay, pinctrl `qup_i2c5_default` (gpio12/13) [V: L/sm8250.dtsi:5310-5605] |
| USB-PD sink negotiation | present | PM8150B typec + pdphy via `tcpm/qcom/qcom_pmic_typec.c` [V: :136-146] | typec node absent (no pm8150b.dtsi include) | see 3.3 |

**Warp/VOOC verdict.** Stock runs Warp/VOOC on the PM8150B SMB5 with a large
set of `qcom,vooc_*` / `qcom,oplus-pps-*` properties [V: E/ fragment@2]. That
block has no mainline driver or binding [V: above], and the VOOC protocol
itself is downstream-only — porting it would mean reimplementing a proprietary
protocol, which AGENTS.md rule 5 forbids doing from decompiled code. **M5
ceiling is therefore slow charging only: 5 V USB through the BQ25980, plus
USB-PD sink contracts up to 12 V/2.25 A negotiated by the PM8150B PDPHY**
[V: E/ fragment@2 default-sink-caps; L/ qcom,pmic-typec.yaml]. Whether the
BQ25980 or the (driverless) SMB5 sits in the VBUS→BAT path on this unit is
[I-P5-1], resolved at gate R2 by which `power_supply` reports online.

### 3.2 Fuel gauge, battery, temperature

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| Fuel gauge BQ27411 @ i2c16:0x55 | present | `bq27xxx_battery_i2c.c` of_match includes `ti,bq27411` [V: L/bq27xxx_battery_i2c.c:273]; binding `bq27xxx.yaml` enum includes `ti,bq27411`, requires `monitored-battery`, and forbids `interrupts` for it [V: L/.../bq27xxx.yaml:40, 76-96] | node absent; i2c16/qupv3_id_2 disabled [V: L/sm8250.dtsi:1000-1430 i2c16 under qupv3_id_2] | DTS commit: i2c16 + fuel-gauge@55 from C:639-647 ([I] values), qupv3_id_2 okay, pinctrl `qup_i2c16_default` (gpio48/49) [V: L/sm8250.dtsi:5310-5605] |
| Battery node | `simple-battery` binding present (`battery.yaml`) | community uses static design data [V: DTS-PORT-PLAN §2.1 C:274-280] | absent | simple-battery node; design values from C:274-280 [I] cross-checked against stock batterydata (4.35 V max, 3600/3450 mAh by ID) [V: E/ fragment@72] |
| Battery temperature | gauge reports TEMP via power_supply [I-P5-2: confirm prop name at R2]; PM8150B VADC `chg_temp@9` exists [V: L/pm8150b.dtsi:130-133]; adc-tm `skin_therm@4d`/`conn_therm@4f` exist but `pm8150b_adc_tm` is disabled [V: L/pm8150b.dtsi:135-141]; stock zones: skin-therm trips 46/47/49/50 °C, conn-therm 125 °C, all `wake-capable-sensor` [V: E/ fragment@76] | `qcom,spmi-adc5` / `qcom,spmi-adc-tm5` / `qcom,spmi-temp-alarm` drivers in L [V: L/drivers/iio/adc/qcom-spmi-adc5.c, qcom-spmi-adc-tm5.c; L/drivers/thermal/qcom/qcom-spmi-temp-alarm.c] | pm8150b.dtsi not included; pm8150 adc/temp exist but unused | enable pm8150b temp-alarm + adc; optionally adc-tm + 2 board zones with stock trips (commit 4) |

### 3.3 USB-C role switching and orientation

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| PM8150B typec port + pdphy | present, generic | node `pm8150b_typec: typec@1500` `qcom,pm8150b-typec`, regs `0x1500`,`0x1700`, 16 irqs [V: L/pm8150b.dtsi:61-98]; driver `qcom_pmic_typec.c` [V: :136-146]; binding `qcom,pmic-typec.yaml`: for pm8150b-typec requires `vdd-pdphy-supply`, 16 interrupts, `connector` child with `ports` [V: L/.../qcom,pmic-typec.yaml:99-108, 143-200] | not present (no pm8150b.dtsi include) | include pm8150b.dtsi; `&pm8150b_typec` okay + `vdd-pdphy-supply = <&vreg_l2a_3p1>` (stock uses pm8150 L2 = 3.072 V [V: E/ fragment@2]; K2's `vreg_l2a_3p1` is 3072000 µV [V: K2 dts regulators-1]) + `connector` (usb-c-connector, data-role dual, port@0 → dwc3 HS endpoint) [shape: V: binding example qcom,pmic-typec.yaml:143-200; C:751-786 via DTS-PORT-PLAN §2.3] |
| VBUS regulator | present | `pm8150b_vbus: usb-vbus-regulator@1100` `qcom,pm8150b-vbus-reg`, disabled [V: L/pm8150b.dtsi:55-59] | absent | `&pm8150b_vbus` okay for host mode [V: DTS-PORT-PLAN §2.3 C:788-793] |
| dwc3 role switch | present | `usb_1_dwc3` `dr_mode = "peripheral"`, **no `usb-role-switch`**, no HS endpoint [V: K2 dts :369-373]; USB peripheral networking works this way [V: NOTES.md 2026-11-16 R7/R2, 2026-11-17] | fixed peripheral | `dr_mode = "otg"` + `usb-role-switch` + `port@0` endpoint to the typec connector [V: binding example; DTS-PORT-PLAN §4 commit 8 = this change, C:916-918]. CONFIG_TYPEC=y + CONFIG_TYPEC_QCOM_PMIC=y already built in [V: device/instantnoodlep/kernel.config:31-34]; add CONFIG_TYPEC_TCPM + CONFIG_USB_ROLE_SWITCH [I-P5-3: exact symbols vs L Kconfig at O2] |
| Orientation | handled by CC in the typec driver; HS lane swap is board-fixed on this PHY | — | n/a | runtime check: plug flipped both ways, verify enumeration + `data_role` [I-P5-4: SS polarity on QMP combo is board-fixed; verify at R3] |

### 3.4 Wireless charging — out of scope

The hardware is an IDT receiver gated by OnePlus-specific pinctrl
(`idt_en`, `wrx_en`, `wrx_otg`, `usbin_int`) [V: E/ fragments 0 and 4] with
`qcom,wireless_support` on the SMB5 [V: E/ fragment@2]. Out of scope for M5
because: (1) there is no mainline driver or binding for the IDT/OnePlus wlchg
path [I-P5-6: no such compatible in the binding directories I inspected in L;
a full-tree search was not possible in this environment — the pinctrl node
names themselves are OnePlus-proprietary]; (2) driving it would require
describing a proprietary protocol from vendor code, which rule 5 forbids;
(3) a desk phone gains little. Revisit only after M5 if a public protocol
description exists.

### 3.5 Thermal zones, cpufreq, cpuidle sanity

| Piece | Status | Evidence |
| --- | --- | --- |
| TSENS | generic nodes present: tsens0 (16 sensors), tsens1 (9), `qcom,sm8250-tsens` | [V: L/sm8250.dtsi:5039-5061] |
| SoC thermal zones | present in dtsi: cpu0-3, cpu4-7 top/bottom, aoss0/1, cluster0/1, gpu top/bottom (cooling-maps to CPUs/GPU), plus tsens1 zones (wlan, video, mem, camera, npu, compute) | [V: L/sm8250.dtsi:6313-7072] |
| PMIC die-temp zones | `pm8150-thermal` and `pm8150b-thermal` zones with 95/115/145 °C trips ship in the PMIC dtsis; pm8150 one is active once pm8150.dtsi is included (already is), pm8150b one activates with commit 1 | [V: L/pm8150.dtsi:11-37, 78-83; L/pm8150b.dtsi:11-37, 100-106] |
| cpufreq | `cpufreq_hw: cpufreq@18591000` `qcom,sm8250-cpufreq-epss` with 3 freq-domains; cpus reference `&cpufreq_hw` + `cpu0/4/7_opp_table`; driver `qcom-cpufreq-hw.c` | [V: L/sm8250.dtsi:6283-6301, 93-99, 372-700; L/drivers/cpufreq/qcom-cpufreq-hw.c:756-763]. K2 already boots 8 CPUs with no cpufreq defer [V: NOTES.md 2026-11-16 R3] — sanity gate R5 only re-checks `scaling_driver` |
| cpuidle | idle-states `cpu-sleep-0-0`/`cpu-sleep-1-0` (psci suspend param 0x40000004) + `cluster-sleep-0` (0x4100c244); psci `arm,psci-1.0` method smc with cpu_pd0-7 + cluster_pd | [V: L/sm8250.dtsi:337-367, 721-749] |

### 3.6 Suspend-to-idle and wake sources

| Item | Status | Evidence |
| --- | --- | --- |
| Suspend mode | PSCI 1.0 → s2idle only; K2 boot log already shows the PSCI PC-mode firmware note | [V: L/sm8250.dtsi:721-749; NOTES.md 2026-11-16 R3]. `/sys/power/mem_sleep` check at R4 [I-P5-7] |
| Power key wake | `pon_pwrkey` `qcom,pm8941-pwrkey` child, disabled in dtsi; CONFIG_INPUT_PM8941_PWRKEY=y + CONFIG_POWER_RESET_QCOM_PON=y already built in | [V: L/pm8150.dtsi:57-67; kernel.config:53-55] |
| RTC wake | `rtc@6000` `qcom,pm8941-rtc` alarm; driver registers the alarm IRQ as wake IRQ | [V: L/pm8150.dtsi:108-113; L/drivers/rtc/rtc-pm8xxx.c:641-654]. Clock is lost every boot today (RTC at 1970) until time sync [V: NOTES.md 2026-11-17 network/time] — fixing time is network-plan scope, but the RTC device must probe here |
| Thermal wake | tsens calls `device_init_wakeup`; stock zones are `wake-capable-sensor` | [V: L/drivers/thermal/qcom/tsens.c:1426; E/ fragments 1,3,76] |
| Modem wake | SDX55 on PCIe with `wake` pin gpio81 | [V: L/sm8250.dtsi:5310-5605 pcie0_default_state wake-pins gpio81]; runtime ownership belongs to the M5 network plan [I] |
| Type-C/VBUS wake | attach-detach + vbus-change irqs of pm8150b_typec | [V: L/pm8150b.dtsi:61-98] |

### 3.7 PON keys and reboot/bootloader modes

| Item | Status | Evidence |
| --- | --- | --- |
| PON node | pm8150@0 `pon@800` `qcom,pm8998-pon` exists, no mode props; pm8150b@2 `pon@800` `qcom,pm8916-pon` exists (keep disabled: K1 hit `qcom-pon -EEXIST` on the second PON) | [V: L/pm8150.dtsi:53-74; L/pm8150b.dtsi:49-53; NOTES.md 2026-11-16 R2]. K2 board file has no `&pon` override at all [V: K2 dts, 386 lines read] |
| Reboot-mode driver | `qcom-pon.c` matches `qcom,pm8998-pon` (GEN2) and registers a reboot-mode writer | [V: L/drivers/power/reset/qcom-pon.c:66-98] |
| Binding | for `qcom,pm8998-pon`, `mode-bootloader` and `mode-recovery` are the allowed `mode-*` props | [V: L/Documentation/devicetree/bindings/power/reset/qcom,pon.yaml:70-77] |
| Proven values | `mode-bootloader = <0x2>` (QC ABL FASTBOOT_MODE) + `mode-recovery = <1>` were carried by the M1b `boot_b` image (PR #50); `reboot --reboot-argument=bootloader` reached fastboot in 4-6 s | [V: NOTES.md 2026-11-17 B1 and B4] |
| M5 change | move those props from the builder overlay into the board DTS `&pon` block; enable `&pon`, `&pon_pwrkey`, `&pon_resin` | this plan, commit 3 |

## 4. Firmware needs

None for this subsystem. The BQ25980, BQ27411, PM8150B typec/PD, temp-alarm,
ADC, TSENS, RTC and PON drivers request **no firmware** [V: bq25980.yaml and
bq27xxx.yaml have no firmware properties; L/pm8150b.dtsi nodes request none;
L/qcom_pmic_typec.c requests none]. `device/instantnoodlep/firmware.map`
therefore needs **no power rows**; the existing rows (GPU zap, remoteprocs,
sdx55m, ath11k, qca BT) are unchanged and stay names-only from the owner's OTA
(AGENTS.md rule 8; FIRMWARE-PLAN §3-§4). If R2 shows the BQ25980 needing a
firmware blob, that is a stop condition, not a silent map addition.

## 5. Userspace (Arch Linux ARM root on userdata)

| Need | Package / service | Evidence |
| --- | --- | --- |
| Battery + charger status for the shell | `upower` (system service `upower.service`); reads `/sys/class/power_supply` | [I-P5-8: package name per Arch Linux ARM catalogue; confirm at image build gate O6] |
| Power key → suspend/shutdown, lid-less suspend | `systemd-logind` (already running; SDDM session) HandlePowerKey | [V: NOTES.md 2026-11-17 SDDM/Hyprland session] |
| RTC wake test | `rtcwake` (util-linux, already in base) | [I-P5-8 same] |
| Thermal policy | none needed — kernel zones + cpufreq cooling-maps; `thermald` is x86-only, do not install | [V: L/sm8250.dtsi cooling-maps] |
| Modem wake display | ModemManager — owned by the M5 network plan, not here | [I] |
| Power profiles | `power-profiles-daemon` optional; skip for M5 | [I] |

## 6. Kernel-side commit order (in linux-omarchy-mobile `L`, not this repo)

One logical change per commit, GPL-2.0 headers; re-run §7 offline gates after
each. No new bindings are expected (all compatibles exist in L) — O1 proves it.
This plan takes over DTS-PORT-PLAN commits 6 and 8 (power + Type-C) and the
PON part of commit 5; the rest of those commits stays with their owners.

| # | Commit | Content |
| --- | --- | --- |
| 0 | (repo, not kernel) `device/instantnoodlep/kernel.config` additions | POWER_SUPPLY, BQ25980 charger, BQ27XXX battery+I2C, TYPEC_TCPM, USB_ROLE_SWITCH, QCOM_SPMI_ADC5, QCOM_SPMI_ADC_TM5, QCOM_SPMI_TEMP_ALARM, QCOM_TSENS, RTC_DRV_PM8XXX; verify QCOM_CPUFREQ_HW/THERMAL/CPU_IDLE already set. Exact symbols [I-P5-3] checked against L Kconfigs at O2 |
| 1 | `arm64: dts: qcom: instantnoodlep: Add PM8150B Type-C, VBUS and USB role switch` | include pm8150b.dtsi; `&pm8150b_typec` okay + vdd-pdphy-supply + connector graph; `&pm8150b_vbus` okay; `&usb_1_dwc3` otg + usb-role-switch + HS endpoint (DTS-PORT-PLAN commit 8; C:751-793, 916-918) |
| 2 | `arm64: dts: qcom: instantnoodlep: Add battery, fuel gauge and charger` | simple-battery node; `&qupv3_id_0`/`&i2c5` + `charger@66` (ti,bq25980, monitored-battery); `&qupv3_id_2`/`&i2c16` + `fuel-gauge@55` (ti,bq27411, monitored-battery); pinctrl qup_i2c5/16_default (DTS-PORT-PLAN commit 6; C:274-280, 626-647) |
| 3 | `arm64: dts: qcom: instantnoodlep: Enable PON keys and reboot modes` | `&pon` (pm8150@0) okay, `&pon_pwrkey`/`&pon_resin` okay, `mode-bootloader = <2>`, `mode-recovery = <1>`; pm8150b `pon@800` stays disabled |
| 4 | `arm64: dts: qcom: instantnoodlep: Enable PM8150B thermal ADC and skin/conn zones` | `&pm8150b_temp`/`&pm8150b_adc` active via include; `&pm8150b_adc_tm` okay + board thermal-zones skin-therm/conn-therm with stock trips [V: E/ fragment@76] |

## 7. Gated runbook

Offline gates O0-O8 run on the laptop and touch no phone. Owner gates G1 and
R1-R7 run on the phone, **RAM boot first** (`fastboot boot`, nothing written),
as M1a did; every phone command block has Expect / Stop / Rollback (AGENTS.md
rule 1). After any refused RAM boot, cold-reboot to the bootloader before the
next `fastboot boot` [V: NOTES.md 2026-11-16 R1 consequence].

```sh
export L=/path/to/linux-omarchy-mobile
export OUT=/path/to/private/m5-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export K2DTB=/path/to/private/k2-build/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1b complete (slot B default, flags recorded); M2/M3 state recorded; DTS-PORT-PLAN D0-D9 passed; L pinned | all present | any input missing | no changes; return to owning ticket |
| O1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` on unchanged base; repeat after each commit | baseline recorded; no new schema errors (no new bindings expected) | new error | drop the offending edit |
| O2 Build + config | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after every commit; verify the commit-0 config symbols exist in L Kconfig | dtc exit 0, DTB produced; no unknown symbol | build error / unknown CONFIG | delete output; fix current commit only |
| O3 Schema | `make ... dtbs_check` | no new warning/error for this board | typec/connector/power-supply schema failure | revert uncommitted change |
| O4 Node checks | fdtget block below vs `"$DTB"`; diff vs `"$K2DTB"` | diff limited to the M5 set (pm8150b include, typec/vbus, dwc3 otg+role-switch, i2c5/16 children, pon, adc_tm zones) | any extra enable or missing node | discard output; fix defining commit |
| O5 Live-DT compare | decompile `"$DTB"` + stage-0 live.dtb; classify differences; check C's charger/gauge supplies+IRQ GPIOs against live DT | no unexplained power-node difference | unexplained difference | suppress candidate; update plan |
| O6 Packaging | build the M5 boot image with the PR-#44 builder; assert no UFS write allowlist; upower present in rootfs | builder exits 0 | builder refuses | delete images |
| O7 Release | review commits 0-4, O1-O6 logs, hashes, open [I]s with coordinator/owner | written approval for one RAM boot | any failed gate | keep current state; do not boot |

O4 fdtget checks:

```sh
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/typec@1500 status            # okay
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/typec@1500/connector compatible # usb-c-connector
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/usb-vbus-regulator@1100 status # okay
fdtget -t s "$DTB" /soc@0/usb@a6f8800/usb@a600000 dr_mode                     # otg
fdtget -t s "$DTB" /soc@0/usb@a6f8800/usb@a600000 usb-role-switch             # (present)
fdtget -t s "$DTB" /soc@0/geniqup@9c0000/i2c@994000/charger@66 compatible   # ti,bq25980
fdtget -t s "$DTB" /soc@0/geniqup@8c0000/i2c@888000/fuel-gauge@55 compatible # ti,bq27411
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@0/pon@800 status                 # okay
fdtget -t x "$DTB" /soc@0/spmi@c440000/pmic@0/pon@800 mode-bootloader         # 2
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/pon@800 status                 # disabled
fdtget -t s "$DTB" / battery compatible                                      # simple-battery
fdtget -t s "$DTB" / compatible                                              # oneplus,instantnoodlep qcom,sm8250 (unchanged)
```

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` = M5 image from O6; `{{SERIAL}}` = pinned fastboot
serial (private, never pasted). Captures go to `captures/<date>/m5/`
(gitignored).

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` + slot flags recorded | one device; flags equal the M1b B5 capture (`current-slot:b`, successful:b yes) | flags differ | `fastboot reboot`; slot-B Linux boots (B5-marked) |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; ssh root@172.16.42.1; dmesg | `Booting OKAY`; probes: `bq25980` on i2c5, `bq27xxx` on i2c16, `qcom-pon` on pmic@0 only (no -EEXIST), `qcom_pmic_typec`, `qcom-tsens` x2, `qcom-cpufreq-hw`, `rtc-pm8xxx`; SSH works | FAILED remote msg, no SSH in 2 min, pon -EEXIST, any firmware error | hold Power+VolUp 10-30 s; slot-B boots |
| R2 | over SSH: `ls /sys/class/power_supply/`; `cat .../battery/{capacity,status,temp,voltage_now,charge_full*}`; owner plugs a 5 V USB charger; `cat .../charger/{online,current_now,voltage_now}`; `upower -d` | battery psy present with sane values; charger online, current_now > 0; upower lists the battery | no battery psy, no charger psy, or online never asserts | `reboot -f`; record which path is live (I-P5-1) |
| R3 | over SSH: `ls /sys/class/typec/`, `cat .../port0/{power_role,data_role,orientation}`; `cat /sys/class/usb_role/usb_1_dwc3-role-switch/role`; owner plugs the laptop cable both orientations | typec port present; role switches peripheral↔host; data_role dual; orientation flips; dwc3 enumerates as peripheral to the laptop (NCM up) | no typec port; role stuck peripheral; no enumeration either orientation | `reboot -f` |
| R4 | over SSH: `cat /sys/power/mem_sleep`; `systemctl suspend`; owner presses power key to wake; then `rtcwake -m mem -s 15` and watch dmesg for RTC alarm wake | suspend enters (s2idle), wakes on pwrkey and on RTC alarm; `dmesg` shows wake source | hangs in suspend (no wake) | hard reboot; record; check wakeirqs in /proc/interrupts |
| R5 | over SSH: `ls /sys/class/thermal/`; `cat .../thermal_zone*/type temp` (pm8150b-thermal, tsens zones); `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver`; `cat .../scaling_cur_freq` | zones present with sane temps; scaling_driver `qcom-cpufreq-hw`; freq within opp table | missing zones or wrong driver | `reboot -f` |
| R6 | over SSH: `reboot --reboot-argument=bootloader`; expect fastboot in <10 s [V: NOTES B4 precedent]. Optional, owner only: `reboot --reboot-argument=recovery` lands in stock recovery — do NOT choose wipe | fastboot reached; slot flags unchanged afterwards | not in fastboot in 30 s | hold Power 30 s; slot-B boots |
| R7 | `fastboot -s {{SERIAL}} getvar all` (filtered); boot slot-B Linux once normally | slot flags equal G1; nothing written by any step | any flag changed | stop; record; ask on #808 before further boots |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-P5-1 | Which charger IC is in the VBUS→BAT path on this unit (BQ25980 vs the driverless SMB5) | R2: which power_supply reports online + current; O5 live-DT compare of C:626-637 supplies |
| I-P5-2 | BQ27411 reports battery TEMP through power_supply under the name the bq27xxx driver uses | R2 `.../battery/temp` |
| I-P5-3 | Exact CONFIG symbols for commit 0 (POWER_SUPPLY, BQ25980_CHARGER, BQ27XXX_BATTERY*, TYPEC_TCPM, USB_ROLE_SWITCH, QCOM_SPMI_*, QCOM_TSENS, RTC_DRV_PM8XXX) as named in L Kconfig | O2 build |
| I-P5-4 | SS (SuperSpeed) lane polarity on usb_1_qmpphy is board-fixed; only CC/HS orientation is dynamic | R3 flipped-plug test |
| I-P5-5 | C's charger/gauge node values (supplies, IRQ GPIO, reg) match this unit | O5 live-DT compare + R1 probe |
| I-P5-6 | No mainline binding/driver exists for the IDT/OnePlus wlchg path (wireless charging stays out of scope) | full-tree grep at O1 (this environment could not grep L); E/ fragments 0/4 pinctrl evidence |
| I-P5-7 | `/sys/power/mem_sleep` offers `s2idle` only on this PSCI 1.0 firmware | R4 |
| I-P5-8 | Arch Linux ARM package names (upower, rtcwake) as listed in §5 | O6 image build |
| I-P5-9 | `mode-recovery = <1>` lands in stock recovery without touching data (only bootloader mode is proven) | R6 optional owner step; Stop = do not wipe |
| I-P5-10 | Whether host (source) mode with VBUS boost works for OTG accessories | R3; if not, keep `dr_mode="otg"` but document sink-only in practice |

## 9. Definition of done for M5 power

O0-O7 pass; G1 and R1-R7 pass with pasted (redacted) output; upower shows the
battery with capacity/temp and the charger online at 5 V; Type-C role switch
and both orientations work with the K2 gadget networking preserved; suspend
enters s2idle and wakes on power key and RTC alarm; `reboot bootloader` works
from the board DTS alone; thermal zones and qcom-cpufreq-hw report sane
values; slot flags are unchanged; commits 1-4 exist in a linux-omarchy-mobile
branch with gates rerun; results appended to NOTES.md with dates.
