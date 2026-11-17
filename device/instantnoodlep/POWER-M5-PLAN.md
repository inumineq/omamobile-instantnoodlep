<!-- SPDX-License-Identifier: MIT -->
# POWER-M5-PLAN: battery, charging, USB-C, thermal, suspend on instantnoodlep

House-rule-6 gate for milestone **M5** of the wayfinder map
("Omarchy Mobile port for instantnoodlep (OnePlus 8 Pro IN2023)"): the power
subsystem — battery/fuel gauge/charging, USB-C role switching and orientation,
thermal + cpufreq/cpuidle sanity, suspend-to-idle and wake sources, and PON
reboot/bootloader modes. The kernel work lives in linux-omarchy-mobile
branches, not here; this file stages it and gates every phone step
(AGENTS.md rule 6).

- Date: 2026-11-17 (first draft, branch `m5-plans`); refreshed 2026-11-17
  evening on branch `inumineq/power` for K3 and the P1 fuel-gauge image (§0).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `FIRMWARE-PLAN.md`, `NOTES.md`, `DISPLAY-M3-PLAN.md` (style template).
- Safety model unchanged: never write `super` or any `_a` partition; flash
  writes only ever name slot-B boot images and `userdata`, each behind an
  owner go. All M5 phone steps are `fastboot boot` (RAM) first; nothing in
  this plan flashes anything. Never `fastboot flash`/`erase`/`--set-active`.
- ~~New prerequisite: neutral DTBO on `dtbo_b`~~ **Parked** [V: DTBO-PLAN §6;
  learning `l-48e0c482`]: ABL rejected both neutral `dtbo_b` forms, so
  `dtbo_b` stays stock and K3 carries the test-only `qcom,kona` patch
  instead (§0.2). The original reasoning follows. Stock entry 16 changes the
  live root compatible to `qcom,kona-mtp`, `qcom,kona`, `qcom,mtp`
  [V: NOTES.md 2026-11-17 entry]. `cpufreq-dt-platdev.c` checks the machine
  compatible blocklist before creating its generic platform device; with the
  stock root it misses the `qcom,sm8250` blocklist entry and may register a
  second cpufreq provider despite the SM8250 `cpufreq_hw` node [V:
  L/drivers/cpufreq/cpufreq-dt-platdev.c, `blocklist` and
  `cpufreq_dt_platdev_init`]. Nura's device package also installs an empty
  DTBO [V: <https://gitlab.com/postmarketOS/pmaports/-/raw/master/device/testing/device-oneplus-instantnoodlep/APKBUILD>, `kernel_mainline()`].

## 0. State and staging (2026-11-17 evening)

### 0.1 Where power stands

- [V] The phone runs combo K3 from `boot_b`, release
  `7.3.0-rc6-instantnoodlep-k3-gaa996bae0695` (kernel `~/src/l-k3`, branch
  `instantnoodlep-k3-combo`), and `/sys/class/power_supply` is empty: no
  gauge, no charger driver [V: NOTES.md 2026-11-17 midday].
- [I] Whether the phone charges at all under our kernels is unknown. With
  no charger driver the PM8150B runs on whatever the boot chain left in it.
- [V] D/ is now read locally (`~/android/build/m3-src/D`), and the C/ files
  that matter here were fetched at the C/ pin (`~/android/build/m3-src/C`:
  the board DTS, `pm8150b.dtsi`, `qcom_pm8150b_charger.c`). D/'s kernel
  patches apply to that tag [V: D/docs/patches.md:125,139, tag
  `sm8250-7.2.0_git20261010` = C/ pin `3c5440e9`].

### 0.2 The `qcom,kona` root under K3 and power

`dtbo_b` stays stock, so the live root compatible is `qcom,kona-mtp`,
`qcom,kona`, `qcom,mtp` [V: learning `l-48e0c482`]. Every table in the K3
tree keyed on the root `qcom,sm8250` is one of three: the `cpufreq-dt-platdev`
blocklist, `qcom_pd_mapper` and `ubwc_config` [V: `grep -rn '"qcom,sm8250"'
drivers/` in `~/src/l-k3p`, three hits], and the combo patch adds
`qcom,kona` to all three [V: `~/src/l-k3` commit `6ea434b7a`]. So none
misses under K3. The power drivers in this plan (bq27xxx, qcom_pmic_typec,
TSENS, SPMI ADC/temp-alarm, qcom-pon, rtc-pm8xxx, D/'s PM8150B charger)
match their own nodes, not the root, and are unaffected. R5's "no duplicate
`cpufreq-dt`" check still applies, now as a check of the kona patch.

### 0.3 Stages

| Stage | Content | Writes to hardware | State |
| --- | --- | --- | --- |
| **P1** fuel gauge | bq27411 on i2c16 @0x55, read only: capacity, voltage, current, temperature, status through `/sys/class/power_supply/bq27411-0` | none (gauge reads only, see 0.4) | **Built**, RAM-boot image ready; runbook §7.3 step P1-R1 |
| **P2** charger | D/'s PM8150B charger driver with the gauge-led stock policy (§0.5) | PM8150B charger registers (float voltage, currents, watchdog) | **Built** after P1 passed; RAM-boot image ready; runbook §7.4, first boot behind an owner go |
| **P3** USB-C | PM8150B Type-C/PD + dwc3 role switch (old commit 1 in §6) | Type-C/VBUS block | Not started; changes the USB link we SSH over, so it runs after P2 |

### 0.4 P1: what the image contains

- Kernel branch `instantnoodlep-k3-power` in worktree `~/src/l-k3p`, one
  commit on `instantnoodlep-k3-combo`: `arm64: dts: qcom: instantnoodlep: Add
  the battery fuel gauge` (`&qupv3_id_2`, `&gpi_dma2`, `&i2c16` at 100 kHz,
  `fuel-gauge@55` `ti,bq27411`). Node values: C:639-647, unchanged by any
  D/ patch [V: `grep -l 'i2c16\|smart_battery\|bq27' D/kernel-patches/*`
  hits only 0076/0166/0167, none of which touches the node]. Stock agrees:
  E/ fragment@80 targets `qupv3_se16_i2c` with `qcom,clk-freq-out =
  <0x186a0>` (100 kHz) and `bq27541-battery@55` [V: E/ lines 12085-12098].
- **No `monitored-battery`, no `simple-battery` node.** The bq27411 is a
  RAM data-memory part: `BQ27XXX_DATA(bq27411, ..., BQ27XXX_O_RAM)` [V:
  L/drivers/power/supply/bq27xxx_battery.c:1048], and for `O_RAM` chips
  `bq27xxx_battery_update_dm_block()` writes design values from the DT
  regardless of `CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM` [V: same file
  :1339-1358]; `bq27xxx_battery_settings()` triggers that whenever the
  battery node has both design capacities or a min voltage [V: :1561-1564].
  C/D's `battery` node has both (C:274-280), so D/ rewrites the gauge's
  design capacity on every boot. Without the node,
  `power_supply_get_battery_info()` fails and the driver returns before any
  write [V: :1521-1522]. The binding does not require `monitored-battery`
  [V: L/Documentation/devicetree/bindings/power/supply/bq27xxx.yaml,
  `required` lists only `compatible` and `reg`]; this corrects §3.2's
  "requires `monitored-battery`".
- Config: identical to combo K3 except `CONFIG_CHARGER_BQ25980` dropped
  (was `=m`). `POWER_SUPPLY`, `BATTERY_BQ27XXX`, `BATTERY_BQ27XXX_I2C` were
  already `=y`; `BATTERY_BQ27XXX_DT_UPDATES_NVM` stays unset. All pinned in
  `device/instantnoodlep/kernel.config`.
- Correction to §2/§3.1: the part at i2c5:0x66 is a **BQ2597x wireless
  charge pump, not a BQ25980** [V: D/kernel-patches/0076, commit message:
  the stock overlay identifies it as BQ2597x; "the BQ25980 driver has a
  different register layout"]. Never bind `ti,bq25980` there; the driver is
  now out of the build.

### 0.5 P2: D/'s safe charging policy, staged

The overvoltage: D/ images up to v2026.11.10 charged the cell to 4.76 V
instead of 4.35 V [V: D/README.md:10-13]. Cause: the float-voltage register
counts from 3.6 V in 10 mV steps, and the old formula (3.4875 V base,
7.5 mV steps) wrote 0x74, which selects 4.76 V [V: D/kernel-patches/0068,
commit message]. The fixed encoding is `(fv_uv - 3600000) / 10000`,
bounded to 3.6-4.79 V [V: C/ driver + D/ series, `FLOAT_VOLTAGE_*` :86-90,
:844-849].

The later policy (v2026.11.15, D/kernel-patches/0165-0167): the PM8150B
charges, the bq27411 decides. Limits [V: D/docs/charging.md:16-41; driver
table `smb5_zones[]` :315-321 and `POLICY_*` :334-336 after the D/ series]:

| Battery temperature | Charge current | Float voltage |
| --- | --- | --- |
| below −2 °C | none | |
| −2 to 0 °C | 0.3 A | 3.98 V |
| 0 to 5 °C | 1.2 A | 4.435 V |
| 5 to 45 °C | 2 A | 4.435 V |
| 45 to 50 °C | 1.1 A | 4.13 V |
| above 50 °C | none | |

Plus: full at > 4.385 V with < 230 mA, or gauge full, or resting > 4.35 V;
recharge below 4.235 V; hard stop at 4.46 V; **3.98 V / 0.5 A until the
first valid gauge reading and whenever gauge data is invalid**; charger
watchdog on (only the policy work pets it, so a dead kernel stops
charging); input 5 V only, ≤ 3 A from PD, 500 mA SDP / 1.5 A DCP [V:
D/docs/charging.md:3-7,26-41].

These match the stock charger properties in E/ fragment@2 [V: E/ lines
645-711]: `qcom,iterm_ma` 230, `temp_normal_fastchg_current_ma` 2000,
`temp_normal_vfloat_mv` 4435, `temp_warm_vfloat_mv` 4130,
`temp_warm_fastchg_current_ma` 1100, `warm_bat_decidegc` 450,
`hot_bat_decidegc` 500, `normal_vfloat_sw_limit` 4385,
`normal_vfloat_over_sw_limit` 4445, `vfloat_step_mv` 8. D/ restarts
200 mV below the float voltage where stock's `recharge-mv` is 100 (D/ is
the stricter one). The stock fast-charge MCU node carries
`qcom,oplus_batt_4400mv` [V: E/ line 12105], i.e. a 4.4 V-class cell, which
is why a 4.435 V float at the charger (measured behind the charge path)
and a 4.385 V cell "full" are stock.

Why P2 was staged at first (resolved: P1 passed, §7.3 P1 result; P2 built as below):

1. D/'s policy is only as safe as the gauge data it reads; P1 has not yet
   shown plausible bq27411 readings on this unit (P1-R1).
2. The driver is out of tree: `qcom_pm8150b_charger.c` (C/, GPL-2.0-only,
   Teguh Sobirin, 964 lines) plus eight D/ patches (0068, 0073, 0082-0085,
   0165, 0166; 1739 lines after them [V: applied in
   `~/android/build/m3-src/C-applied`, all eight apply cleanly]). There is
   no `qcom,pm8150b-charger` binding in L, and L's `pm8150b.dtsi` has no
   `charger@1000` node (C/pm8150b.dtsi:109-126 + D/0086 add it).
3. It needs `pm8150b.dtsi` included, whose second `pon@800` must stay
   disabled (K1 `-EEXIST`, §3.7), and the PM8150B ADC for USB-in telemetry.

P2 port as built (kernel branch on top of P1, author of each patch kept,
Assisted-by on our own). Two additions over the first sketch: the C/ base
adds a `charging_enabled` power_supply property in the core, which the
driver needs (P2.0, `DO NOT UPSTREAM`), and the binding was written and
passes `dt_binding_check`:

| # | Commit | Source |
| --- | --- | --- |
| P2.0 | `DO NOT UPSTREAM: power: supply: Add the charging_enabled property` | C/include/linux/power_supply.h, C/power_supply_sysfs.c at the C/ pin |
| P2.1 | `power: supply: Add the Qualcomm PM8150B charger driver` (author Teguh Sobirin) + Kconfig/Makefile | C/drivers/power/supply/qcom_pm8150b_charger.c at the C/ pin |
| P2.2-P2.9 | D/ 0068, 0073, 0082, 0083, 0084, 0085, 0165, 0166 with `git am`, authors kept | D/kernel-patches |
| P2.10 | `dt-bindings: power: supply: Add the Qualcomm PM8150B charger` | new, ours: the binding, plus its entry in the `qcom,spmi-pmic.yaml` `charger@` list; dt_binding_check and dtbs_check clean |
| P2.11 | `arm64: dts: qcom: pm8150b: Add the charger` (+ D/0086 source-change IRQ) | C/pm8150b.dtsi:109-126, D/0086 |
| P2.12 | board: include `pm8150b.dtsi`, keep `&pm8150b` `pon@800` disabled; `battery` node; `&pm8150b_charger` okay with `monitored-battery`, `qcom,fuel-gauge = <&fuel_gauge>` (D/0167); no `power-supplies` until P3 (the driver then uses its own APSD detection [V: driver :1512 `has_tcpm` is optional]) | C:274-280, D/0087, D/0167 |

P2.12 settled the safety question this way (built): the
charger needs `monitored-battery` (voltage-max 4.35 V, 2 A limit from
D/0087), but the gauge must not get one (0.4). Give the charger its own
`battery` node and leave the gauge without; do not copy C/'s design
capacity/energy into any node the gauge sees. Config: the charger `=y`
(boot-critical for charge safety), `QCOM_SPMI_ADC5=y`.

## 1. Source pins

- `L/` = `~/src/l`, branch `instantnoodlep-k2` @ `a28aaf1a09db`
  (linux-omarchy-mobile `317d87dc2db0` + our four DTS commits)
  [V: NOTES.md 2026-11-16 "R7, K2 passes R1-R5"]. Line refs below are valid
  in that tree (K2 = the board file `L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`).
- `C/` = community SM8250 kernel, `gitlab.nura.eco/soc/qualcomm-sm8250/linux`,
  tag `7.2.0-dev` = `sm8250-7.2.0_git20261010`, commit
  `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9` (pin as in DTS-PORT-PLAN §1).
  Since 2026-11-17 evening the board DTS, `pm8150b.dtsi` and
  `drivers/power/supply/qcom_pm8150b_charger.c` at that pin are in
  `~/android/build/m3-src/C` (raw file fetches; a shallow clone timed out),
  and the same files with D/'s charger patches applied are in
  `~/android/build/m3-src/C-applied`. `C:<line>` refers to the board DTS.
- `E/` = `~/android/build/p3/entry16.dts`, decompiled stock dtbo **entry 16**
  of `IN2023_13.1.0.591(EX01)` (15974 lines; cited by fragment number).
  Facts only — GPIOs, rails, addresses, compatible strings; no vendor code is
  copied (AGENTS.md rule 5).
- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (FIRMWARE-PLAN pin). `M/` = torvalds/linux @ `aebb7274476403040d582c61478df8f4a7bf9cd3`
  (DISPLAY-M3-PLAN pin). `D/` = public Nura/OnePlus 8 Pro repository at
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial>,
  including README and `docs/charging.md` (checked during review).
- Local copy of D/: `~/android/build/m3-src/D` (README, docs/charging.md,
  `kernel-patches/` 0001-0167 against the C/ tag [V: D/docs/patches.md:139]).
  `D/0068` etc. name `D/kernel-patches/0068-*.patch`.

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| PMIC stack | PM8150 x2 (USID 0,1), PM8150B x2 (USID 2,3), PM8150L x2 (4,5), PM8009 x2 (a,b), PMX55 (8,9) on SPMI | [V: NOTES.md 2026-11-16 stage-0 D5 live-DT list]; generic nodes: L/pm8150.dtsi:47-143, L/pm8150b.dtsi:46-179, L/pm8150l.dtsi |
| Stock wired charger | PM8150B (USID 2) SMB5 block, stock compatible `qcom,qpnp-smb5`, carries VOOC/Warp props (`qcom,vooc_project`, `qcom,input_current_vooc_ma_*`, `qcom,oplus-pps-usbpd-detection`, `qcom,wireless_support`), `qcom,external_gauge`, `qcom,batt_capacity_mah = <0x119e>` (4502 mAh) | [V: E/ fragment@2, `pm8150b_charger: qcom,qpnp-smb5` block] |
| i2c5 @ `0x66` | **BQ2597x wireless charge pump**, not the BQ25980 C/ names (C:626-637); D/ renames it `ti,bq2597x-standalone` and disables it | [V: D/0076 commit message and diff]. Not a wired charger; never bind `ti,bq25980` to it |
| Fuel gauge | TI **BQ27411** on `i2c16` @ `0x55` (stock: `oplus,bq27541-battery`, 100 kHz); stock PM8150B FG (`qcom,fg-gen4`) is `status = "disabled"` with `qcom,external_gauge` | [V: C:639-647; E/ fragment@80, lines 12085-12098; E/ fragment@2 `pm8150b_fg` disabled] |
| Battery | single pack; the draft cites different capacities for the SMB5 and batterydata profiles | [I-P5-11: reconcile the owner's actual battery ID/profile before using any capacity or voltage value; the referenced entry16 source was not independently available in this review]. Do not choose a `simple-battery` capacity or charge limit from either value until the live profile is reconciled. |
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
| ~~TI BQ25980~~ BQ2597x on i2c5@0x66 (see §0.4) | driver + binding exist, but probing registers a charger supply and programs current/voltage limits during init [V: L/drivers/power/supply/bq25980_charger.c, `bq25980_hw_init`/`bq25980_set_input_*`] | `ti,bq25980` [V: :1271-1275]; binding requires `compatible`, `reg`, `monitored-battery` [V: L/.../bq25980.yaml:66-70] | node absent; i2c5/qupv3_id_0 disabled [V: L/sm8250.dtsi:1430-1910 i2c5 under qupv3_id_0, `status = "disabled"`; K2 dts enables only qupv3_id_1] | **Do not enable this node in M5** until a separate gated plan validates the exact unit battery profile and safe charger policy. A generic BQ25980 node is not proof it can safely replace the unsupported SMB5 control path. |
| USB-PD sink negotiation | present | PM8150B typec + pdphy via `tcpm/qcom/qcom_pmic_typec.c` [V: :136-146] | typec node absent (no pm8150b.dtsi include) | see 3.3 |

**Warp/VOOC verdict.** Stock runs Warp/VOOC on the PM8150B SMB5 with a large
set of `qcom,vooc_*` / `qcom,oplus-pps-*` properties [V: E/ fragment@2]. That
block has no mainline driver or binding [V: above], and the VOOC protocol
itself is downstream-only — porting it would mean reimplementing a proprietary
protocol, which AGENTS.md rule 5 forbids doing from decompiled code. This
plan does **not** claim charging support: the main wired charger is SMB5, for
which this tree has no driver. The external BQ25980 driver programs charger
limits on probe, so enabling it before a reviewed policy is unsafe. A public
Nura report documents an earlier 4.76 V overcharge and a later BQ27411-based
charging-policy fix [V: D/README, warning; D/docs/charging.md]. Defer all
charger-node enablement and charging tests to a separate gated plan with the
exact battery profile, regulator path, voltage/current safety bounds, and
owner approval. M5 checks battery telemetry and Type-C role/PD detection only;
it makes no charger property writes and requests no charging/high-voltage PD.

### 3.2 Fuel gauge, battery, temperature

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| Fuel gauge BQ27411 @ i2c16:0x55 | present | `bq27xxx_battery_i2c.c` of_match includes `ti,bq27411` [V: L/bq27xxx_battery_i2c.c:273]; binding `bq27xxx.yaml` enum includes `ti,bq27411` and forbids `interrupts` for it; `monitored-battery` is optional [V: L/.../bq27xxx.yaml, corrected 2026-11-17 evening, §0.4] | **P1 done** in the K3 power branch (§0.4) | nothing for P1; never give the gauge a `monitored-battery` (RAM data memory, §0.4) |
| Battery node | `simple-battery` binding present (`battery.yaml`) | community DTS includes static design data [V: DTS-PORT-PLAN §2.1 C:274-280] | absent | fuel-gauge node only for M5 telemetry; add `simple-battery` only after the exact unit battery ID/profile is reconciled. Do not port static capacity/voltage values from C or infer them from the conflicting draft evidence. |
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
| TSENS | generic, node-matched sensors present: tsens0 (16 sensors), tsens1 (9), `qcom,sm8250-tsens`; the TSENS driver matches node compatibles, not the root machine compatible | [V: L/sm8250.dtsi:5039-5061; L/drivers/thermal/qcom/tsens.c, `tsens_table`] |
| SoC thermal zones | present in dtsi: cpu0-3, cpu4-7 top/bottom, aoss0/1, cluster0/1, gpu top/bottom (cooling-maps to CPUs/GPU), plus tsens1 zones (wlan, video, mem, camera, npu, compute) | [V: L/sm8250.dtsi:6313-7072] |
| PMIC die-temp zones | `pm8150-thermal` and `pm8150b-thermal` zones with 95/115/145 °C trips ship in the PMIC dtsis; pm8150 one is active once pm8150.dtsi is included (already is), pm8150b one activates with commit 1 | [V: L/pm8150.dtsi:11-37, 78-83; L/pm8150b.dtsi:11-37, 100-106] |
| cpufreq | `cpufreq_hw: cpufreq@18591000` `qcom,sm8250-cpufreq-epss` with 3 freq-domains; CPUs reference `&cpufreq_hw` + `cpu0/4/7_opp_table`; driver `qcom-cpufreq-hw.c` | [V: L/sm8250.dtsi:6283-6301, 93-99, 372-700; L/drivers/cpufreq/qcom-cpufreq-hw.c:756-763]. The separate `cpufreq-dt-platdev` init uses a root-machine blocklist containing `qcom,sm8250`; if stock DTBO replaces the root with Kona/MTP strings, that check misses and may register generic `cpufreq-dt` in addition to the hardware provider [V: L/drivers/cpufreq/cpufreq-dt-platdev.c, `blocklist` and `cpufreq_dt_platdev_init`]. K2's previous clean boot is not proof with the stock overlay; after neutral DTBO, verify no `cpufreq-dt` device and `scaling_driver=qcom-cpufreq-hw` |
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
| 0 | (repo, not kernel) `device/instantnoodlep/kernel.config` additions | POWER_SUPPLY, BQ27XXX battery+I2C, TYPEC_TCPM, USB_ROLE_SWITCH, QCOM_SPMI_ADC5, QCOM_SPMI_ADC_TM5, QCOM_SPMI_TEMP_ALARM, QCOM_TSENS, RTC_DRV_PM8XXX; do **not** enable BQ25980 until its separate safe-charge plan passes; verify `BATTERY_BQ27XXX_DT_UPDATES_NVM` is unset because that option writes gauge NVM [V: L/drivers/power/supply/Kconfig, option help]. Verify QCOM_CPUFREQ_HW/THERMAL/CPU_IDLE already set. Exact symbols [I-P5-3] checked against L Kconfigs at O2 |
| 1 | `arm64: dts: qcom: instantnoodlep: Add PM8150B Type-C, VBUS and USB role switch` | include pm8150b.dtsi; `&pm8150b_typec` okay + vdd-pdphy-supply + connector graph; `&pm8150b_vbus` okay; `&usb_1_dwc3` otg + usb-role-switch + HS endpoint (DTS-PORT-PLAN commit 8; C:751-793, 916-918) |
| 2 | `arm64: dts: qcom: instantnoodlep: Add battery and fuel-gauge telemetry` | **Done as P1 (§0.4), without any battery node.** Original: `simple-battery` only after the unit's battery ID/profile is reconciled; `&qupv3_id_2`/`&i2c16` + `fuel-gauge@55` (ti,bq27411, monitored-battery); pinctrl `qup_i2c16_default` (DTS-PORT-PLAN commit 6; C:274-280, 639-647). Do not enable `&i2c5`/BQ25980 in this series; require a separate charger-policy plan first. |
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
| O0 Inputs | M1b complete (slot B default, flags recorded); neutral DTBO owner-gated install on `dtbo_b` complete; live root compatible verified; M2/M3 state recorded; battery ID/profile reconciled for `simple-battery`; DTS-PORT-PLAN D0-D9 passed; L pinned | all present; no BQ25980 node/driver in the M5 image | missing prerequisite, unresolved battery profile, or an unreviewed charger node | no changes; return to owning ticket |
| O1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` on unchanged base; repeat after each commit | baseline recorded; no new schema errors (no new bindings expected) | new error | drop the offending edit |
| O2 Build + config | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after every commit; verify the commit-0 config symbols exist in L Kconfig and `CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM` is unset | dtc exit 0, DTB produced; no unknown symbol; gauge NVM-update option disabled | build error / unknown CONFIG or gauge NVM-update option enabled | delete output; fix current commit only |
| O3 Schema | `make ... dtbs_check` | no new warning/error for this board | typec/connector/power-supply schema failure | revert uncommitted change |
| O4 Node checks | fdtget block below vs `"$DTB"`; diff vs `"$K2DTB"` and live DT | diff limited to the M5 set (PM8150B Type-C/thermal, dwc3 role-switch, i2c16 gauge, PON); built/live root is `oneplus,instantnoodlep`, `qcom,sm8250`; no BQ25980 node | any extra enable, wrong live compatible, or missing node | discard output; return to neutral-DTBO gate / fix defining commit |
| O5 Live-DT compare | decompile `"$DTB"` + stage-0 live.dtb; classify differences; check the gauge supplies/IRQ against live DT; do not enable BQ25980 | no unexplained power-node difference | unexplained difference | suppress candidate; update plan |
| O6 Packaging | build the M5 boot image with the PR-#44 builder; assert no UFS write allowlist; upower present in rootfs | builder exits 0 | builder refuses | delete images |
| O7 Release | review commits 0-4, O1-O6 logs, hashes, open [I]s with coordinator/owner | written approval for one RAM boot | any failed gate | keep current state; do not boot |

O4 fdtget checks:

```sh
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/typec@1500 status            # okay
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/typec@1500/connector compatible # usb-c-connector
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/usb-vbus-regulator@1100 status # okay
fdtget -t s "$DTB" /soc@0/usb@a6f8800/usb@a600000 dr_mode                     # otg
fdtget -t s "$DTB" /soc@0/usb@a6f8800/usb@a600000 usb-role-switch             # (present)
fdtget -t s "$DTB" /soc@0/geniqup@8c0000/i2c@888000/fuel-gauge@55 compatible # ti,bq27411
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@0/pon@800 status                 # okay
fdtget -t x "$DTB" /soc@0/spmi@c440000/pmic@0/pon@800 mode-bootloader         # 2
fdtget -t s "$DTB" /soc@0/spmi@c440000/pmic@2/pon@800 status                 # disabled
fdtget -t s "$DTB" / battery compatible                                      # simple-battery
fdtget -t s "$DTB" / compatible                                              # oneplus,instantnoodlep qcom,sm8250
```

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` = M5 image from O6; `{{SERIAL}}` = pinned fastboot
serial (private, never pasted). Captures go to `captures/<date>/m5/`
(gitignored).

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` + slot flags recorded | one device; flags equal the M1b B5 capture (`current-slot:b`, successful:b yes) | flags differ | `fastboot reboot`; slot-B Linux boots (B5-marked) |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; ssh root@172.16.42.1; read `/sys/firmware/devicetree/base/compatible`; dmesg | `Booting OKAY`; live root is `oneplus,instantnoodlep` + `qcom,sm8250`; probes: `bq27xxx` on i2c16, `qcom-pon` on pmic@0 only (no -EEXIST), `qcom_pmic_typec`, `qcom-tsens` x2, `qcom-cpufreq-hw`, `rtc-pm8xxx`; no BQ25980 probe; SSH works | wrong live root; BQ25980 unexpectedly bound; FAILED remote msg, no SSH in 2 min, pon -EEXIST, any firmware error | hold Power+VolUp 10-30 s; slot-B boots |
| R2 | over SSH: `ls /sys/class/power_supply/`; read battery capacity/status/temp/voltage/charge-full properties and `upower -d`. **Do not plug a charger for this M5 plan**; no charger control/property write and no BQ25980 node is enabled. | BQ27411 battery telemetry is present and plausible; upower lists the battery; battery ID/profile is recorded without changing charge limits | missing gauge data, implausible voltage/temp, or unit profile not reconciled | `reboot -f`; record telemetry; do not proceed to charging until the separate safe-charge plan passes |
| R3 | over SSH: `ls /sys/class/typec/`, `cat .../port0/{power_role,data_role,orientation}`; `cat /sys/class/usb_role/usb_1_dwc3-role-switch/role`; owner plugs the laptop cable both orientations | typec port present; role switches peripheral↔host; data_role dual; orientation flips; dwc3 enumerates as peripheral to the laptop (NCM up) | no typec port; role stuck peripheral; no enumeration either orientation | `reboot -f` |
| R4 | over SSH: `cat /sys/power/mem_sleep`; `systemctl suspend`; owner presses power key to wake; then `rtcwake -m mem -s 15` and watch dmesg for RTC alarm wake | suspend enters (s2idle), wakes on pwrkey and on RTC alarm; `dmesg` shows wake source | hangs in suspend (no wake) | hard reboot; record; check wakeirqs in /proc/interrupts |
| R5 | over SSH: `ls /sys/class/thermal/`; read thermal zone types/temps; `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver`; list cpufreq platform devices and confirm no generic `cpufreq-dt` instance | TSENS/PMIC zones present with plausible temps; `scaling_driver` is `qcom-cpufreq-hw`; no duplicate `cpufreq-dt`; frequency within OPP table | missing zones, `cpufreq-dt` also registered, wrong driver, or implausible temperatures | `reboot -f`; stop and review neutral-DTBO / machine matching |
| R6 | over SSH: `reboot --reboot-argument=bootloader`; expect fastboot in <10 s [V: NOTES B4 precedent]. Optional, owner only: `reboot --reboot-argument=recovery` lands in stock recovery — do NOT choose wipe | fastboot reached; slot flags unchanged afterwards | not in fastboot in 30 s | hold Power 30 s; slot-B boots |
| R7 | `fastboot -s {{SERIAL}} getvar all` (filtered); boot slot-B Linux once normally | slot flags equal G1; nothing written by any step | any flag changed | stop; record; ask on #808 before further boots |

### 7.3 P1 fuel-gauge RAM boot (K3 power image)

Read-only on the battery; nothing is flashed; `boot_b` keeps combo K3. The
coordinator runs the phone, the owner does button combos. Captures go to
`captures/<date>/power/` (gitignored); never paste serials.

Inputs [V: built 2026-11-17 evening, §0.4]:

- Kernel `~/src/l-k3p` @ `11fedfae5a37` (branch `instantnoodlep-k3-power`),
  build dir `~/android/build/k3-power`, release
  `7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37`.
- Image `~/android/build/k3-power-ram/boot-p1-gauge.img`, sha256
  `b69df9433a17d736524d8138965679968224dde1aa964b334752435c35ffe85b`; manifest
  `~/android/build/k3-power-ram/boot-p1-gauge.manifest.json`; builder flags as
  combo `boot-r3-gpu` (`--boot 2 --root userdata --debug-shell`, stock
  entry-16 overlay); the manifests differ only in kernel/DTB size and
  hashes, the ramdisk sha256 is the same (`86340898…a1`). `dtbs_check` on
  the board DTB: no warnings (`~/android/build/k3-power/dtbs_check.log`).
- Modules `~/android/build/k3-power/modules-7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37.tar.zst`
  (one top-level `<release>/` dir, 1801 modules: combo's 1802 minus `bq25980_charger`), sha256 `6d92d5c458a06c490ad723e91eb743086b57d36a464b1af02f9848128baf60af`.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P1-0 | Laptop: `sha256sum ~/android/build/k3-power-ram/boot-p1-gauge.img` | `b69df9433a17d736524d8138965679968224dde1aa964b334752435c35ffe85b` | mismatch | rebuild; do not boot |
| P1-1 | Phone on combo K3 (flash), over adb/ssh: push the modules tarball and unpack it as root with `tar --zstd -xf modules-7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37.tar.zst -C /usr/lib/modules`, then `depmod 7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37` | new `/usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37/` only; the combo release dir untouched | unpack touches anything outside that dir | `rm -rf /usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37` |
| P1-2 | `adb reboot bootloader` (or `reboot --reboot-argument=bootloader`); `fastboot getvar current-slot` | `current-slot: b` | other slot | `fastboot reboot` |
| P1-3 | `fastboot boot ~/android/build/k3-power-ram/boot-p1-gauge.img` (RAM only) | `Booting OKAY`; K3 comes up to SSH/Hyprland as combo does; `uname -r` = `7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37` | `FAILED (remote: ...)`, or no SSH within 2 min | owner holds Power+VolUp 10-30 s; the phone boots combo K3 from `boot_b`. After a refused RAM boot, cold-reboot to the bootloader before another `fastboot boot` |
| P1-4 | Read only: `dmesg \| grep -iE 'bq27\|i2c16\|geni\|888000'`; `ls /sys/class/power_supply/`; `cat /sys/class/power_supply/bq27411-0/{status,capacity,voltage_now,current_now,temp,health,charge_full,charge_full_design,charge_now,cycle_count,technology}`; read twice, 30 s apart; once on the cable, once with the owner unplugging it for a minute | `bq27411-0` present [I: name from the driver's `%s-%d` pattern]; no `update ... to` and no `cfgupdate` lines in dmesg (proof of no data-memory write); `voltage_now` 3.4-4.45 V (µV); `temp` 150-450 (0.1 °C); `capacity` 0-100 and in line with Android's last reading; `current_now` changes sign or size when the cable comes out | no `bq27411-0` (i2c16 timeout/NACK); any `update`/`cfgupdate`/`data memory` line; voltage > 4.45 V; temp > 45 °C | `reboot -f` → combo K3 from flash. A voltage above 4.45 V or temp above 45 °C: unplug, stop, report |
| P1-5 | `reboot` | combo K3 from `boot_b`, as before | anything else | Power+VolUp, then §7.2 G1 |

P1-4 tells P2 three things: whether the gauge reads plausibly on this unit
(D/'s policy relies on it), whether the battery charges at all on combo K3
without a charger driver (the cable test), and the gauge's own
`charge_full_design` (the stock value it keeps, since we write none).

#### P1 result (2026-11-17, RAM boot of `boot-p1-gauge.img`, run by the coordinator)

- [V] `uname -r` = `7.3.0-rc6-instantnoodlep-k3-g11fedfae5a37`;
  `/sys/class/power_supply/bq27411-0` present. Readable: `status`,
  `capacity`, `voltage_now`, `current_now`, `temp`, `charge_full`,
  `charge_full_design`, `charge_now`, `technology`. Absent: `health`,
  `cycle_count` (P1-4 listed them; the bq27411 property set lacks them).
- [V] Readings: capacity 96 %, 4.265 V, 32.3 °C, `charge_full` 4111000 µAh,
  `charge_full_design` 4455000 µAh (the gauge's own value; we write none),
  `technology` Li-ion. All inside the P1-4 Expect ranges.
- [V] 5 s log, cable in: `Not charging`, `current_now` 0. USB carries the
  system load; **the battery does not charge on K3 without a charger
  driver**. Cable out: `Discharging`, −178 to −382 mA idle (screen off),
  4.213-4.235 V.
- [V] First re-plug: stayed `Discharging` at −178 mA (USB input not
  restored) and the USB gadget did not re-enumerate. Second re-plug about
  1 min later: `Not charging`, 0 mA, gadget back. This is the behaviour
  D/0165 describes (USB input suspended after a detach and not restored
  while VBUS is present) [V: D/0165 commit message].
- Consequence: I-P5-2 resolved (temp is `temp`, 0.1 °C). The gauge reads
  plausibly, which was P2's gate (§0.5 reason 1). P2 is built next (§7.4).

#### Input for P3 (Type-C)

The re-plug finding means the PM8150B USB input and the gadget link do not
always recover from a detach/attach under K3, where nothing drives the
PM8150B Type-C block. P3 must test repeated unplug/replug (≥ 5 cycles,
both orientations) and check both VBUS input (charger `online`, gauge
current) and gadget re-enumeration (`ip link` on the laptop) each time.
Until P3, a re-plug that leaves the phone `Discharging` with no gadget is
known and is cleared by a second re-plug; do not read it as a P2 fault on
its own.

### 7.4 P2 charger RAM boot (K3 power + PM8150B charger)

**This boot programs the PM8150B charger** (float voltage, charge and input
current, termination current, charger watchdog) the moment the driver
probes, before anyone can type. P2-4 therefore needs the **owner's explicit
go**, given after reading this section. Nothing is flashed; `boot_b` keeps
combo K3.

Inputs [V: built 2026-11-17, §0.5]:

- Kernel `~/src/l-k3p` @ `28bdb8d1614e` (branch `instantnoodlep-k3-power`,
  P1 + 14 commits), build dir `~/android/build/k3-power-p2`, release
  `7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e`.
- Image `~/android/build/k3-power-ram/boot-p2-charger.img`, sha256
  `8bf4fc47b4cdcccaa00dc109665982455b7b8b17a2c99fc4881a459bb4def37e`; manifest
  `~/android/build/k3-power-ram/boot-p2-charger.manifest.json`; same builder
  flags and ramdisk as P1 and combo.
- Modules `~/android/build/k3-power-p2/modules-7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e.tar.zst`,
  sha256 `19bd68eff5d3ac4f21575e6c53a3aea89d409da18dbf3c5943a0ef940c3b1e22` (1799 modules: P1 minus the now built-in charger and ADC5).
- Watch script `tools/instantnoodlep-charge-watch` (this repo): runs on the
  phone, logs gauge + charger every 5 s, and on a stop condition writes 0 to
  `charging_enabled` itself and exits.

What the driver does with this DT [V: driver after the D/ series, §0.5]:
it starts at 3.98 V / 0.5 A, looks up the bq27411 through
`qcom,fuel-gauge`, and every 5 s sets the zone limits from the gauge's
temperature (2 A / 4.435 V at 5-45 °C, capped by the charger battery
node's 2 A); full at > 4.385 V and < 230 mA or when the gauge says full;
hard stop at 4.46 V; back to 3.98 V / 0.5 A whenever gauge data is invalid;
the charger watchdog stops charging if the policy work stops petting it;
3.98 V float on shutdown/reboot. With no Type-C link (P3) the input limit
comes from the PM8150B's own detection: 500 mA from the laptop (SDP), 1.5 A
from a wall charger (DCP). So on the laptop cable the battery current is
bounded by about 0.5 A minus the system load.

Stop conditions for every step (the watch script enforces the first five;
the coordinator watches the rest): gauge temp > 42.0 °C; gauge voltage
> 4.44 V; |gauge current| > 2.1 A; USB input > 5.6 V; charger `health`
Overvoltage/Overheat/Cold or other error; a `pm8150b-charger` kernel line
with "overvoltage", "watchdog bark" or "charging stopped"; no
`charging policy uses bq27411-0` within 30 s of boot; `no fuel gauge data`
warnings after the first 30 s; on the laptop cable, battery current above
0.6 A. Generic rollback for all steps: `echo 0 >
/sys/class/power_supply/pm8150b-charger/charging_enabled`, unplug the cable,
`reboot -f` (or Power+VolUp 10-30 s) → combo K3 from `boot_b`, which has no
charger driver (P1: no charging under combo K3).

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P2-0 | Laptop: `sha256sum` of the image and modules tarball | `8bf4fc47b4cdcccaa00dc109665982455b7b8b17a2c99fc4881a459bb4def37e`, `19bd68eff5d3ac4f21575e6c53a3aea89d409da18dbf3c5943a0ef940c3b1e22` | mismatch | rebuild; do not boot |
| P2-1 | Phone on combo K3: unpack the modules as P1-1 (`-C /usr/lib/modules`), `depmod 7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e`; push `tools/instantnoodlep-charge-watch` to `/root/` and `chmod +x` | new release dir only; script present | anything else changes | `rm -rf /usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e` |
| P2-2 | Record the starting point from combo K3: battery %, and that the phone is not hot to the touch (owner) | battery 20-97 %; phone at room temperature | phone warm, or battery outside the range | do not proceed; report |
| P2-3 | `reboot --reboot-argument=bootloader`; `fastboot getvar current-slot` | `current-slot: b` | other slot | `fastboot reboot` |
| **P2-4 GO** | **Owner go required.** Then `fastboot boot ~/android/build/k3-power-ram/boot-p2-charger.img` (RAM only) | `Booting OKAY`; SSH within 2 min; `uname -r` = `7.3.0-rc6-instantnoodlep-k3-g28bdb8d1614e` | `FAILED`, or no SSH in 2 min | Power+VolUp; combo K3 boots; cold-reboot to the bootloader before another `fastboot boot` |
| P2-5 | At once over SSH: `nohup /root/instantnoodlep-charge-watch > /root/charge-watch.log 2>&1 &`; then `dmesg \| grep -E 'pm8150b-charger\|bq27'`; `ls /sys/class/power_supply/` | `bq27411-0` and `pm8150b-charger`; dmesg: `float voltage 3980000 uV`, `charging policy uses bq27411-0`, a `battery temperature zone -2 -> 4` (or the zone for the measured temp); watch log running | probe error; no policy line within 30 s; any stop condition | generic rollback |
| P2-6 | Laptop cable, 15 min: `tail -f /root/charge-watch.log` over SSH | `usb_type` SDP, `input_current_limit` 500000, `online` 1; gauge status `Charging` or `Full`, current 0-0.6 A; vbat rising slowly, ≤ 4.44 V; temp ≤ 42 °C and not rising more than 3 °C; the charger may report `Full` and restart cycles near 96 % (D/0166 notes the last 10 % are slow) | any stop condition; watch exited with STOP | generic rollback |
| P2-7 | Owner unplugs for 1 min, replugs (twice if the gadget does not come back, §7.3 P3 note); then read the log | while out: gauge `Discharging`, charger `online` 0; after replug: `online` 1, `Charging`/`Full`, same limits as P2-6 | charging continues with the cable out; any stop condition | generic rollback |
| P2-8 | Optional, **separate owner go**: wall charger (DCP) for 15 min; SSH is gone while on it, the watch script still enforces the limits; afterwards back on the laptop cable, read the log | `usb_type` DCP, `input_current_limit` 1500000, battery current ≤ 1.5 A, temp ≤ 42 °C, vbat ≤ 4.44 V in the whole log | any STOP line in the log; phone hot to the touch (owner: unplug at once) | generic rollback |
| P2-9 | `kill "$(cat /root/charge-watch.pid)"` (by PID: `pkill -f` over ssh also matches the ssh shell running it and kills the session); copy `/root/charge-watch.log` to `captures/<date>/power/`; `reboot` | combo K3 from `boot_b`; under combo the battery shows no charging again | anything else | Power+VolUp, then §7.2 G1 |

What P2 does not cover: Type-C/PD (P3; no `power-supplies` link yet),
charging while suspended (the driver turns charging off in suspend), and
flashing a charger kernel to `boot_b` (only after P2-5 to P2-7 pass, behind
its own owner go).

#### P2 result (2026-11-17 12:49, run by the coordinator): froze before userspace

- [V] `fastboot boot boot-p2-charger.img` (sha256 `8bf4fc47…`): `Booting
  OKAY`, the fastboot device left at 12:49:31, then nothing on the laptop's
  USB for more than 3 min (no gadget, no NCM netdev, no QUSB/ramdump
  device). The screen stayed on the bootloader's fastboot screen with a
  coloured glitch band at the top and no self-reset. Owner forced a reboot
  with Power+VolUp at about 12:55; the phone was not warm; combo K3 came
  back from `boot_b`.
- [V] `journalctl --list-boots` on the rootfs has no boot for
  `-g28bdb8d1614e`, so P2 never mounted the root. `/sys/fs/pstore` is empty
  after the forced reboot.
- [V] P1 (same builder, ramdisk and overlay, no charger) reached SSH, so the
  P2 delta is the suspect.
- The command line carries `panic=10` (`boot-p2-charger.manifest.json`), so
  a panic would have rebooted the phone by itself; it did not. The kernel
  started (the glitch band is the early-K3 `DSI PLL(0) lock failed` /
  simple-framebuffer phase, NOTES 2026-11-17 midday [I]) and then stopped
  progressing without a panic.

#### Review of the P2 delta (offline, 2026-11-17)

What changed between the P1 and P2 probe DTBs [V: `dtc -s` of both
`*.probe.dtb`, diff]: the `battery` node, `pmic@2` (adc@3100 with two new
channels, charger@1000, gpio@c000, temp-alarm@2400; typec, vbus, pon,
adc-tm disabled), `pmic@3` (pwm disabled), and the `pm8150b-thermal` zone.
No reserved-memory, iommu or carveout change; everything else is phandle
renumbering. The Image grew from 44,591,616 to 44,657,152 bytes, far inside
the ABL kernel region (about 84 MiB; mainline kernels of 48-49 MB boot
there) [V: docs/research/abl-kernel-size.md:65-70,95-106].

The leading explanation [I], which fits every observation: **the built-in
charger was probed from the deferred-probe worker and that probe, or
another probe it unblocked, never returned.** The chain:

1. Link order puts `power/` before `watchdog/` before `iio/` [V:
   L/drivers/Makefile:120,123,169]. At its own initcall the charger cannot
   get its ADC channels (`devm_iio_channel_get`,
   L/drivers/power/supply/qcom_pm8150b_charger.c:1525-1534) and defers.
2. ADC5, now built in (it was `=m` in P1), binds at the `iio/` initcall and
   triggers deferred probing, so the charger's probe runs in
   `deferred_probe_work`.
3. `deferred_probe_initcall()` flushes that work twice before initcalls end
   [V: L/drivers/base/dd.c:340-359]. If the work never finishes,
   `kernel_init` never reaches the initramfs: no gadget (set up by the
   init), no msm takeover (msm binds through the same deferred list), no
   journal.
4. `qcom_wdt` is built in and registered before that point (`watchdog/`
   precedes `iio/`), and with `WATCHDOG_HANDLE_BOOT_ENABLED=y` the kernel
   itself pings it [V: kernel.config], so a blocked probe does not bite.
   Without hung-task or lockup detectors in the config [V: P1/P2 `.config`],
   nothing turns the hang into a panic, so `panic=10` never fires and
   ramoops gets no dump.

I could not find the line that blocks. Every wait on the probe path is
bounded: the SMB5 init sequence is plain regmap writes
(`qcom_pm8150b_charger.c:1401-1474`), the IRQ setup is
`devm_request_threaded_irq` (:1476-1490, :1625-1655), the only sleep is
`msleep(100)` in the policy work (:1095), the work items re-arm with
`mod_delayed_work` (status work at most `APSD_MAX_RETRIES` times, :776-781,
:815-816), and ADC5 conversions time out (`qcom-spmi-adc5.c:197-213,
328-339`). Other candidates, all [I] and all new in P2 whether the driver
is built in or a module:

- the PM8150B charger hardware writes at probe while the USB cable is in:
  `USBIN_CMD_IL` unsuspend, ICL 500 mA with AICL and
  `SUSPEND_ON_COLLAPSE_USBIN`, `TYPE_C_CFG.BC1P2_START_ON_CC = 0` and an
  APSD rerun (BC1.2 detection drives D+/D-) with no TCPM present (:1401-1456,
  :806-813). This can explain a lost gadget but not a frozen kernel;
- new SPMI clients at SID 2/3: the `qcom,spmi-pmic` MFD, `pinctrl-spmi-gpio`
  for `gpio@c000` (built in), the pm8150b ADC instance and its EOC
  interrupt, and the charger's five PMIC interrupts (`usbin-plugin` and
  `bat-ov` both-edge). An interrupt the bootloader left pending on a newly
  mapped PMIC line is possible but unproven;
- the core `charging_enabled` property shifts the power_supply property
  enum (P2.0); every user was rebuilt with it, so no mismatch is expected.

P2b is built to tell these apart and to leave evidence (§7.5).

### 7.5 P2b: charger as a module, loaded by hand

Inputs [V: built 2026-11-17 night on omabook; `build.rc` 0; Image.gz 16,128,111 bytes]:

- Kernel `~/src/l-k3p` @ `8c252b516245` (P2 + two commits: a 256 KiB
  ramoops `pmsg-size`, and `DO NOT UPSTREAM: ... load only by hand`, which
  drops the driver's `MODULE_DEVICE_TABLE` so udev never autoloads it and
  disables `&pm8150b_gpios` and `&pm8150b_temp`), build dir
  `~/android/build/k3-power-p2b`, release `7.3.0-rc6-instantnoodlep-k3-g8c252b516245`.
- Config vs P1: `CHARGER_QCOM_SMB5=m`, `QCOM_SPMI_ADC5=m` (as P1), plus
  `SOFTLOCKUP_DETECTOR`, `HARDLOCKUP_DETECTOR` (buddy),
  `DETECT_HUNG_TASK` (120 s), each with its panic-on option,
  `PANIC_ON_OOPS=y` and `PANIC_TIMEOUT=10`. A hang longer than 120 s in a
  blocked task, a soft lockup or a hard lockup now panics; the panic dump
  goes to ramoops and the phone reboots into combo K3 after 10 s, where
  `/sys/fs/pstore` shows it. The builder has no option for extra kernel
  arguments (`tools/build-instantnoodlep-probe --help`), so these are
  Kconfig defaults rather than command-line flags.
- Image `~/android/build/k3-power-ram/boot-p2b-charger-m` (24,145,920 bytes),
  sha256 `c13717473cd76ef789f81e477b1491c7fe6f6168000b31c20170c29fee867202`, manifest next to it; same builder flags as P1/P2
  (`--boot 2 --root userdata --debug-shell`, stock entry-16 overlay,
  `apply_checked`); the ramdisk differs from P1/P2 only in
  `root/.ssh/authorized_keys` [V: identical cpio file list; the laptop's
  `id_ed25519.pub` changed since P2].
- Modules `~/android/build/k3-power-p2b/modules-7.3.0-rc6-instantnoodlep-k3-g8c252b516245.tar.zst`
  (one top-level `<release>/` dir, 1802 `.ko` — P1's 1801 plus the charger,
  ADC5 back as a module as in P1; stripped like P1/P2; unpack on the phone
  with `tar --zstd -xf … -C /usr/lib/modules`, then `depmod <release>`),
  sha256 `08dc9c8e895e18d46c9d32cdf17bcdd8f28d649d62062390d66509c3117e8cd9`.

What still binds at boot that P1 did not have: the `qcom,spmi-pmic` MFD for
SID 2 and 3 (built in, needed by pm8150; it only reads the PMIC revision)
and the pm8150b ADC instance (ADC5 is autoloaded for pm8150/pm8150l as in
P1, and the same module then binds pm8150b's ADC too). Keeping the pm8150b
ADC off would leave the charger nothing to read. If P2b does not reach SSH,
those two are the suspects. The charger itself, the pm8150b GPIOs and its
temperature alarm stay off until the modprobe.

#### Hang analysis of the P2 delta, with file:line (l-k3p @ `8c252b516245`)

The P1→P2 delta is 9 files, +1899 lines [V: `git diff --stat 11fedfae5a37
28bdb8d1614e`]: the new `drivers/power/supply/qcom_pm8150b_charger.c` (1739
lines), one line each in `drivers/power/supply/power_supply_sysfs.c` and
`include/linux/power_supply.h` (the `charging_enabled` property), the
Kconfig/Makefile entries, `pm8150b.dtsi` (+34), the board DTS, and two
bindings. The P2b tip adds only the ramoops `pmsg-size` and the
no-autoload / gpios-off commit [V: `git diff --stat 28bdb8d1614e
8c252b516245`].

What can hang at probe, read in this tree:

- Link order puts `power/` before `watchdog/` before `iio/`
  (`drivers/Makefile:120,123,169`), so a built-in charger cannot get its
  ADC channels and defers: `devm_iio_channel_get` at
  `drivers/power/supply/qcom_pm8150b_charger.c:1525-1534`.
  `deferred_probe_initcall()` then flushes `deferred_probe_work` twice
  before initcalls end (`drivers/base/dd.c:340`, flush at `:348,:359`), so
  a probe that never returns blocks `kernel_init` before the initramfs:
  no gadget, no journal, no pstore — exactly the P2 symptom (§7.4).
- Every wait inside `smb5_probe` (`qcom_pm8150b_charger.c:1498-1670`) is
  bounded: hardware init is plain regmap writes (`smb5_init_hw`
  `:1458-1473` over `smb5_init_seq` `:1401-1455`); the battery-info read
  `:1559` touches only the battery node's DT properties; IRQ setup is
  `platform_get_irq_byname` + `devm_request_threaded_irq`
  (`smb5_init_irq` `:1476-1495`, called at `:1625,:1629,:1634,:1651` and
  optionally `:1639-1647`); the only sleep is `msleep(100)` in the policy
  work `:1095`; works re-arm via `mod_delayed_work`
  (`:639,:816,:836,:1114,:1282,:1333-1335`) and APSD retries are capped
  by `APSD_MAX_RETRIES` 3 (`:277,:779`). ADC5 conversions time out:
  `ADC5_CONV_TIMEOUT` 100 ms (`drivers/iio/adc/qcom-spmi-adc5.c:80`),
  `wait_for_completion_timeout` `:335-336` with the polling fallback
  `adc5_poll_wait_eoc` `:197-213` (400 × ~264 µs), ADC7 10 ms `:371`. No
  unbounded wait was found in the driver or ADC5 [I: the blocking line is
  still unidentified].
- New in P2 whether built in or a module, so still live candidates: the
  charger's probe-time hardware writes with the cable in (`USBIN_CMD_IL`
  unsuspend `:1409`, ICL 500 mA `:1410-1411`, `BC1P2_START_ON_CC=0` `:1414`,
  AICL with `SUSPEND_ON_COLLAPSE_USBIN` `:1451-1454`, applied through
  `smb5_init_hw` at probe `:1536`) — BC1.2 detection drives D+/D- with no
  TCPM present and can lose the USB gadget, but not freeze the kernel; and
  the new SPMI clients on SID 2/3: the `qcom,spmi-pmic` MFD revision reads
  (`drivers/mfd/qcom-spmi-pmic.c:169-195`), `pinctrl-spmi-gpio` for
  `gpio@c000`, the pm8150b ADC instance with its EOC interrupt, and the
  charger's five PMIC interrupts — a bootloader-pending interrupt on a
  newly mapped line could storm.
- In P2b the charger node has no driver at boot (no `MODULE_DEVICE_TABLE`;
  `modinfo` on the module shows 0 aliases [V: `modinst` copy of
  `qcom_pm8150b_charger.ko`]) and `&pm8150b_gpios` / `&pm8150b_temp` are
  disabled (commit `8c252b516`), so the only probes new at boot vs P1 are
  the SPMI MFD and ADC5 (ADC5 autoloads for pm8150/pm8150l as in P1 and then
  binds pm8150b's ADC too). If P2b hangs before SSH, those two are the
  suspects, in that order. The armed detectors turn any hang into a panic —
  hung task > 120 s, soft or hard lockup, or an oops
  (`DETECT_HUNG_TASK`, `SOFTLOCKUP_DETECTOR`, `HARDLOCKUP_DETECTOR` with
  `BOOTPARAM_*_PANIC=1`, `PANIC_ON_OOPS=y`, `PANIC_TIMEOUT=10` [V: P2b
  `.config`]) — the dump lands in ramoops (`pmsg-size` 0x40000, commit
  `b0e1e8f0e`) and the phone self-reboots to combo K3 after 10 s, where
  `/sys/fs/pstore` shows it.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P2b-0 | Laptop: `sha256sum` image and modules tarball | `c13717473cd76ef789f81e477b1491c7fe6f6168000b31c20170c29fee867202`, `08dc9c8e895e18d46c9d32cdf17bcdd8f28d649d62062390d66509c3117e8cd9` | mismatch | rebuild |
| P2b-1 | Phone on combo K3: unpack modules `-C /usr/lib/modules`, `depmod 7.3.0-rc6-instantnoodlep-k3-g8c252b516245`; push the current `tools/instantnoodlep-charge-watch` to `/root/` (it now waits for the charger and writes `/root/charge-watch.pid`); `ls /sys/fs/pstore` (should be empty) | new release dir only | anything else changes | `rm -rf /usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-g8c252b516245` |
| P2b-2 | `reboot --reboot-argument=bootloader`; `fastboot getvar current-slot`; `fastboot boot ~/android/build/k3-power-ram/boot-p2b-charger-m` (RAM only; programs nothing) | `Booting OKAY`; SSH within 2 min like P1; `uname -r` = `7.3.0-rc6-instantnoodlep-k3-g8c252b516245`; `lsmod \| grep qcom_pm8150b` empty; `/sys/class/power_supply` = `bq27411-0` only | no SSH in 3 min | wait for a hung-task panic (≤ 130 s after the hang) and the self-reboot; if none by 5 min, Power+VolUp. Then on combo K3 read `/sys/fs/pstore/*` and `journalctl -b -1` |
| P2b-3 | Over SSH, before the go: `nohup sh -c 'dmesg -w > /root/p2b-dmesg.log' >/dev/null 2>&1 &`; `nohup /root/instantnoodlep-charge-watch > /root/charge-watch.log 2>&1 &`; `nohup sh -c 'while sleep 2; do sync /root/p2b-dmesg.log /root/charge-watch.log; done' >/dev/null 2>&1 &`; check both logs grow | both logs growing; watch prints gauge lines with charger fields NA | logs not growing | kill the three by PID |
| **P2b-4 GO** | **Owner go required** (this programs the charger). Then `echo "P2b modprobe $(date)" > /dev/pmsg0; modprobe qcom_pm8150b_charger` | modprobe returns within seconds; dmesg: `float voltage 3980000 uV`, then `charging policy uses bq27411-0` and a temperature zone line; `pm8150b-charger` appears and the watch fills its fields | modprobe does not return in 30 s; SSH or gadget drops and does not return in 2 min; any §7.4 stop condition | if SSH lives: `echo 0 > .../pm8150b-charger/charging_enabled`, unplug, `reboot -f`. If not: wait for the hung-task panic (self-reboot to combo K3 ≤ 3 min), else Power+VolUp; then read pstore, `/root/p2b-dmesg.log`, `/root/charge-watch.log` under combo K3 |
| P2b-5 | Continue with §7.4 P2-6 to P2-8 (laptop cable 15 min, unplug/replug, optional wall charger with its own go) | as §7.4 | as §7.4 | as §7.4 |
| P2b-6 | `kill "$(cat /root/charge-watch.pid)"`; stop the dmesg and sync loops by their PIDs (`pgrep -f 'dmesg -w'`, then `kill <pid>`; never `pkill -f` from the ssh shell); copy the logs to `captures/<date>/power/`; `reboot` | combo K3 from `boot_b` | anything else | Power+VolUp, then §7.2 G1 |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-P5-1 | Which path charges the battery. Updated: the PM8150B SMB5 block via D/'s out-of-tree driver (§0.5); the i2c5 part is a wireless charge pump, not a wired charger (§0.4) | P2 after P1-4. Original text: not resolved by this M5 plan. A separate charger-policy plan must identify the path, validate the unit battery profile/limits, and gate any charge test; M5 must not enable BQ25980. |
| I-P5-2 | BQ27411 reports battery TEMP through power_supply under the name the bq27xxx driver uses | **Resolved [V]**: `bq27411-0/temp`, 0.1 °C (§7.3 P1 result) |
| I-P5-3 | Exact CONFIG symbols for commit 0 (POWER_SUPPLY, BQ25980_CHARGER, BQ27XXX_BATTERY*, TYPEC_TCPM, USB_ROLE_SWITCH, QCOM_SPMI_*, QCOM_TSENS, RTC_DRV_PM8XXX) as named in L Kconfig | O2 build |
| I-P5-4 | SS (SuperSpeed) lane polarity on usb_1_qmpphy is board-fixed; only CC/HS orientation is dynamic | R3 flipped-plug test |
| I-P5-5 | C's charger/gauge node values (supplies, IRQ GPIO, reg) match this unit | O5 live-DT compare + R1 probe |
| I-P5-6 | No mainline binding/driver exists for the IDT/OnePlus wlchg path (wireless charging stays out of scope) | full-tree grep at O1 (this environment could not grep L); E/ fragments 0/4 pinctrl evidence |
| I-P5-7 | `/sys/power/mem_sleep` offers `s2idle` only on this PSCI 1.0 firmware | R4 |
| I-P5-8 | Arch Linux ARM package names (upower, rtcwake) as listed in §5 | O6 image build |
| I-P5-9 | `mode-recovery = <1>` lands in stock recovery without touching data (only bootloader mode is proven) | R6 optional owner step; Stop = do not wipe |
| I-P5-10 | Whether host (source) mode with VBUS boost works for OTG accessories | R3; if not, keep `dr_mode="otg"` but document sink-only in practice |
| I-P5-11 | A safe charging policy for this unit's exact battery profile; a public Nura release reported an overvoltage before a BQ27411 policy fix [V: D/README; D/docs/charging.md]. Updated: D/'s policy is cited and matches stock E/ values (§0.5); still open is whether it holds on this unit's gauge readings | separate gated charge-policy plan; no charger test or BQ25980 enablement in this plan |

## 9. Definition of done for M5 power

O0-O7 pass; G1 and R1-R7 pass with pasted (redacted) output; upower shows the
battery with capacity/temp; Type-C role switch
and both orientations work with the K2 gadget networking preserved; suspend
enters s2idle and wakes on power key and RTC alarm; `reboot bootloader` works
from the board DTS alone; thermal zones and qcom-cpufreq-hw report sane
values; slot flags are unchanged; commits 1-4 exist in a linux-omarchy-mobile
branch with gates rerun; results appended to NOTES.md with dates. Charging
remains out of scope for this run until the separate safe-charge plan passes.
