<!-- SPDX-License-Identifier: MIT -->
# DTS port plan: instantnoodlep for M1a K2

Status: plan only; no DTS is written here. This is the gated plan required
before touching the DTS in linux-omarchy-mobile branch `omamobile`. K2 is M1a
step R7, after K1 has passed R1-R5 [V:
`device/instantnoodlep/BRINGUP-M1-PLAN.md`:278-289,397-411].

The goal is the smallest useful K2 board DTS: boot identity, a safe memory map,
simplefb, UFS, fixed-role USB peripheral, a proven debug UART, the inherited
watchdog, and only their regulators. The R7 image remains RAM-only. This plan
adds no phone step: phone execution and rollback belong to the M1 plan and its
runbook.

## 1. Evidence and source pins

The coordinator review at `docs/research/sm8250-dts-gap.md`:11-36 wins over
that note's body wherever they differ. In particular, `uart6` is Bluetooth,
the simple framebuffer is 1080x2376, and all recreated reserved-memory regions
need checking [V: same lines].

Path abbreviations follow `device/instantnoodlep/BRINGUP-M1-PLAN.md`:79-99:

- `C/` = community instantnoodlep DTS,
  `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`, tag `7.2.0-dev`,
  commit `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9` [V:
  <https://gitlab.nura.eco/soc/qualcomm-sm8250/linux/-/tree/3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9>].
- `U/` = upstream Linux, commit
  `fa2933aac170dd19c6a7f0d7b81a8f537e40915c` [V:
  <https://github.com/torvalds/linux/commit/fa2933aac170dd19c6a7f0d7b81a8f537e40915c>].
- `L/` = linux-omarchy-mobile `omamobile`, found and cloned at commit
  `317d87dc2db0c3580be70a9c6341ca1fbd0a762a` [V:
  <https://github.com/derekross/linux-omarchy-mobile/tree/317d87dc2db0c3580be70a9c6341ca1fbd0a762a>].
- `P/` = community SM8250 kernel, `PM/` = postmarketOS device package, `G/` =
  OnePlus GPL kernel, and `R/` = private stock captures, as in the M1 plan.
- `Q/` below means `arch/arm64/boot/dts/qcom/` in the named tree; `S` means
  `Q/sm8250.dtsi`. Line references are valid only at the pins above.

`C/` has `sm8250-oneplus-common.dtsi`, but the instantnoodlep DTS includes only
`sm8250.dtsi`, PM8150, PM8150B, PM8150L and PM8009, not that common file [V:
C:8-12]. The pinned `U/` and `L/` trees have neither an SM8250 OnePlus common
include nor an instantnoodlep DTS/Makefile target [V: their `Q/` listings and
Makefile sequences, U/Makefile:411-419 and L/Makefile:366-375]. Do not import
the 1498-line community common file for K2. A later common-file split must be
rebased against then-current upstream OnePlus work, not copied blindly. The v4
upstream-list patch is only corroboration for the `uart12` candidate [V:
`docs/research/abl-boot-flow.md`:152-166 and its linked patch].

`B` in the inventory means "no instantnoodlep board block or compatible in
either pinned `U/` or `L/`" [V: the Makefile citations above; the SM8250
compatible enums lack `oneplus,instantnoodlep`,
U/Documentation/devicetree/bindings/arm/qcom.yaml:1141-1151 and
L/Documentation/devicetree/bindings/arm/qcom.yaml:1110-1121]. `Partial` means a generic node exists,
not that its OnePlus properties, status or consumer graph already exist.
K2/later entries below are decisions, not claims that hardware already works.

## 2. Inventory of the community instantnoodlep DTS

### 2.1 Root, memory and regulators

| C node or block [V] | What it is | Already in U/L [V] | K2 or later |
| --- | --- | --- | --- |
| Includes, C:3-12 | Binding constants plus SM8250 and four PMIC includes | Partial: common includes exist; `pm8150*.dtsi` and `pm8009.dtsi` are separate files in U/L Q/ | K2 keeps only SM8250, PM8150 and PM8150L. PM8150B and PM8009 arrive with their first consumers. Never copy generic drivers again. |
| Fourteen `/delete-node/` directives, C:15-31 | Replaces generic reserved regions | Partial: generic labels exist, U S:797-862; L S:798-863 | K2, with every replacement checked before R7. |
| Root model/compatible/chassis and IDs, C:33-39 | Board identity used by Linux and ABL selection | No (B); generic SM8250 root is U S:28-32; L S:28-32 | K2, exact values in §3. |
| `aliases/serial0 = &uart6`, C:41-43 | Bluetooth UART alias, not debug console | Partial: `uart6`, U/L S:1708-1722 | Do not port this alias to K2. Bluetooth later; use `uart12` only if its debug gate passes. |
| `/chosen`, C:45-50 | Chosen stdout and framebuffer container | No (B) | K2, but stdout follows the proven debug UART; framebuffer remains present. |
| `framebuffer@9c000000`, C:51-58 | simplefb, 0x9c000000, 1080x2376, 32 bpp, a8r8g8b8 | No (B); other boards are not this board's evidence | K2 exactly. Native-panel DSI is not part of K2. |
| `gpio-keys` and `vol-up`/`vol-down`, C:61-81 | PMIC volume keys | No (B); PMIC GPIO controller is U/L Q/pm8150.dtsi:126 | M2 input usability, with its pinctrl states. Never fake the power key as debug input. |
| `qca6390-pmu`, its `regulators` and `ldo0`-`ldo9`, C:83-142 | QCA6390 power sequencing and ten PMU rails | No (B); similar nodes on other boards do not supply this board's data | M3 Wi-Fi/BT, as one QCA change with PCIe, UART and pinctrl. |
| `reserved-memory`, C:144-228 | Board memory map | Partial: generic parent U S:772-875; L S:772-875 | K2 in full; consumers may arrive later, reservations may not be dropped with them. |
| `removed_mem`, C:145-148 | 0x80b00000, length 0xcd00000 | Partial: generic has length 0x5300000, U S:797-801; L S:798-802 | K2 reserve only. |
| `camera_mem`, C:150-153 | 0x8dc00000, 5 MiB | Partial: generic 0x86200000, U S:802-806; L S:803-807 | K2 reserve; camera later. |
| `wlan_mem`, C:155-158 | 0x8e100000, 1 MiB | Partial: generic 0x86700000, U S:807-811; L S:808-812 | K2 reserve; WLAN later. |
| `ipa_fw_mem`, C:160-163 | 0x8e200000, 64 KiB | Partial: generic 0x86800000, U S:812-816; L S:813-817 | K2 reserve; IPA later. |
| `ipa_gsi_mem`, C:165-168 | 0x8e210000, 40 KiB | Partial: generic 0x86810000, U S:817-821; L S:818-822 | K2 reserve; IPA later. |
| `gpu_mem`, C:170-173 | 0x8e21a000, 8 KiB | Partial: generic 0x8681a000, U S:822-826; L S:823-827 | K2 reserve; GPU after display. |
| `npu_mem`, C:175-178 | 0x8e300000, 5 MiB | Partial: generic 0x86900000, U S:827-831; L S:828-832 | K2 reserve; NPU is not currently scheduled. |
| `video_mem`, C:180-183 | 0x8e800000, 5 MiB | Partial: generic 0x86e00000, U S:832-836; L S:833-837 | K2 reserve; video later. |
| `cvp_mem`, C:185-188 | 0x8ed00000, 5 MiB | Partial: generic 0x87300000, U S:837-841; L S:838-842 | K2 reserve; CVP is not currently scheduled. |
| `cdsp_mem`, C:190-193 | 0x8f200000, 20 MiB | Partial: generic 0x87800000, U S:842-846; L S:843-847 | K2 reserve; CDSP later. |
| `slpi_mem`, C:195-198 | 0x90600000, 21 MiB | Partial: generic 0x88c00000, U S:847-851; L S:848-852 | K2 reserve; SLPI later. |
| `adsp_mem`, C:200-203 | 0x91b00000, 37 MiB | Partial: generic 0x8a100000 with different length, U S:852-856; L S:853-857 | K2 reserve; ADSP later. |
| `spss_mem`, C:205-208 | 0x94000000, 1 MiB | Partial: generic 0x8be00000, U S:857-861; L S:858-862 | K2 reserve; SPSS is not currently scheduled. |
| `cdsp_secure_heap`, C:210-213 | 0x94100000, 70 MiB | Partial: generic 0x8bf00000, U S:862-866; L S:863-867 | K2 reserve; secure CDSP use later. |
| `cont_splash_mem`, C:215-218 | 0x9c000000, length 0x2300000, no-map | No (B) | K2. It protects the larger splash region while simplefb describes the FHD+ rectangle. |
| `ramoops@b0000000`, C:220-227 | 4 MiB pstore/ramoops reservation | No (B) | K2 after the same address check. Crash diagnostics later depend on it. |
| `vph_pwr`, C:230-235 | Fixed 3.7 V parent supply | No (B) | K2. |
| `vreg_s6c_0p88`, C:237-244 | Fixed always-on 0.88 V supply | No (B) | Not K2: no minimal consumer. Add only with a proven consumer. |
| `vreg_s4a_1p8`, C:246-252 | Fixed always-on 1.8 V supply | No (B) | K2 for UFS VCCQ2 and as regulator parent. |
| `qca639x`, C:254-272 | Separate QCA power-domain provider | No (B) | M3 review; never copy if no bound consumer remains. [I] Its necessity is unresolved, I13. |
| `simple-battery`, C:274-280 | Static battery design data | No (B) | M2 with charger/fuel gauge. |

### 2.2 RPMh regulator blocks

All three are children of `&apps_rsc`. The generic RSC exists in U/L, but these
PMIC child blocks and rail values do not [V: B; generic RSC U S:6202; L
S:6208-6234]. K2 includes only the rails named below, plus all parent-supply
properties that those rails and blocks reference.

| C block [V] | Rails and purpose | K2 or later |
| --- | --- | --- |
| PM8009 `regulators-0`, C:283-328 | Parents and `s2f`, `l1f`, `l2f`, `l6f`, `l7f` | Not K2. M3 QCA needs `s2f`; add other rails only with identified consumers. |
| PM8150 `regulators-1` parents, C:330-349 | PM8150 rail parenting through VPH, BOB, `s6a`, `s8c`, `s5a` | K2 keeps the complete parent topology relevant to included rails; `s5a` waits for QCA. |
| `vreg_l2a_3p1`, C:350-355 | 3.072 V | K2 for USB1 HS; Type-C PD PHY later also uses it. |
| `vreg_l3a_0p9`, C:357-362 | 0.9 V rail | Later only with an identified consumer. |
| `vreg_l5a_0p88`, C:364-369 | 0.88 V rail | K2 for UFS PHY and USB1 HS PHY. |
| `vreg_l6a_1p2`, C:371-376 | 1.2 V rail | K2 for UFS VCCQ. |
| `vreg_l7a_1p7`, C:378-383 | 1.7-1.8 V rail | Later with panel or another proven consumer; no K2 consumer. |
| `vreg_l9a_1p2`, C:385-390 | 1.2 V rail | K2 for UFS PHY PLL and USB1 QMP PHY. |
| `vreg_l10a_1p8`, C:392-397 | 1.8 V rail | Later only with an identified consumer. |
| `vreg_l12a_1p8`, C:399-404 | 1.8 V rail | K2 for USB1 HS PHY. |
| `vreg_l13a_ts_3p0`, C:406-411 | Touch supply | M2 touch, not K2. |
| `vreg_l14a_1p8`, C:413-418 | Display/touch candidate supply | Later with the panel or a proven consumer. |
| `vreg_l15a_1p8`, C:420-425 | 1.8 V rail | Later only with an identified consumer. |
| `vreg_l16a_2p7`, C:427-432 | 2.704-2.96 V rail | Later camera/display work, only with a proven consumer. |
| `vreg_l17a_3p0`, C:434-439 | 2.856-3.008 V rail | K2 for UFS VCC. |
| `vreg_l18a_0p92`, C:441-446 | 0.8-0.912 V rail | K2 for USB1 QMP PHY PLL. |
| `vreg_s5a_1p9`, C:448-453 | 1.9 V rail | M3 QCA, not K2. |
| `vreg_s6a_0p95`, C:456-461 | 0.92-1.128 V rail | K2 because it parents `l18a`; also used by QCA later. |
| PM8150L `regulators-2` parents, C:464-481 | PM8150L parent topology | K2 keeps parents needed by BOB and `s8c`; unrelated rails wait. |
| `vreg_bob`, C:483-488 | Buck-boost parent supply | K2, needed by PM8150 rails. |
| `vreg_l1c_1p8`, C:490-495 | Touch AVDD | M2 touch. |
| `vreg_l2c_1p2`, C:497-502 | 1.2 V rail | Later only with an identified consumer. |
| `vreg_l3c_0p8`, C:504-509 | 0.8 V rail | Later only with an identified consumer. |
| `vreg_l4c_1p7`, C:511-516 | 1.704-2.928 V rail | Later camera/display work, only with a proven consumer. |
| `vreg_l5c_1p8`, C:518-523 | 1.8-2.928 V rail | Later camera/display work, only with a proven consumer. |
| `vreg_l6c_2p96`, C:525-530 | 1.8-2.96 V rail | Later camera/display work, only with a proven consumer. |
| `vreg_l7c_cam_vcm0_2p85`, C:532-537 | Camera VCM supply | Later camera work. |
| `vreg_l8c_1p8`, C:539-544 | 1.8 V rail | Later only with an identified consumer. |
| `vreg_l9c_2p96`, C:546-551 | 2.704-2.96 V rail | Later camera/display work, only with a proven consumer. |
| `vreg_l10c_3p0`, C:553-558 | 3 V rail | Later only with an identified consumer. |
| `vreg_l11c_3p3`, C:560-566 | Always-on 3.296 V rail | Later with panel or another proven consumer. |
| `vreg_s8c_1p3`, C:568-573 | 1.352 V rail | K2 because it parents UFS-relevant `l6a`/`l9a`; also QCA later. |

### 2.3 Peripheral and pinctrl overrides

| C node or block [V] | What it is | Already in U/L [V] | K2 or later |
| --- | --- | --- | --- |
| `&adsp`, C:577-580 | ADSP firmware and enable | Partial: U S:6002; L S:6008-6034, disabled | M3 audio/DSP plan; remain disabled in K2. |
| `&cdsp`, C:582-585 | CDSP firmware and enable | Partial: U S:3789; L S:3795-3819, disabled | M3 DSP plan; remain disabled in K2. |
| `&dispcc`, C:587-589 | Explicitly disables display clock controller | Partial: node has no disabled status, U S:5041; L S:5047-5069 | K2 keeps the explicit disable to protect simplefb. Revisit for the panel milestone. |
| `&gmu`, C:591-593 | Enables Adreno GMU | Partial: generic disabled, U S:3006; L S:3012-3040 | Not K2; GPU/GMU together after stable panel output. |
| `&gpi_dma0/1/2`, C:595-605 | Enables QUP DMA engines | Partial: U S:1004,1341,1771; L same lines | Not K2. Fixed-role USB and debug UART need no new DMA enable. Add with QUP consumers. |
| `&gpu`, C:607-609 | Keeps Adreno disabled | Partial: generic already disabled, U/L S:2934-2959; L adds one-line offset | K2 relies on the common disable; no redundant override needed. GPU after display. |
| `&i2c1` + `nfc@28`, C:611-624 | NXP NCI NFC | Partial: generic I2C U/L S:1421; board child: no (B) | M3 NFC with DMA/QUP and pinctrl review. |
| `&i2c5` + `charger@66`, C:626-637 | TI BQ25980 charger | Partial: generic I2C U/L S:1618; board child: no (B) | M2 power plan; normalize status to `okay` when ported. |
| `&i2c16` + `fuel-gauge@55`, C:639-647 | TI BQ27411 gauge | Partial: generic I2C U/L S:1126; board child: no (B) | M2 power plan. |
| `&i2c13` + `touchscreen@48`, C:649-669 | Samsung S6SY761 touch and supplies | Partial: generic I2C U/L S:2045; board child: no (B) | M2 touch with its two pinctrl states. |
| `&mdss`, C:671-673 | Enables display subsystem without a panel node | Partial: generic disabled, U/L S:4680-4711; L adds six-line offset | Not K2; simplefb only. M3 panel/DSI needs a separate gated panel design. |
| `&slpi`, C:675-678 | SLPI firmware and enable | Partial: generic disabled, U S:3085; L S:3091-3117 | M3 sensor/DSP plan; remain disabled in K2. |
| `&pcie0`, `&pcie0_phy`, `wifi@0`, C:681-706 | QCA6390 PCIe controller, PHY and ten child supplies | Partial: generic U/L S:2140,2231-2233,2216-2222; L pcieport0 is line 2222 | M3 QCA, in the same commit as PMU/BT/pinctrl. |
| `&pcie1` + `&pcie1_phy`, C:708-716 | Enables second PCIe port | Partial: U/L S:2260-2262,2356-2360 | Never enable without a real consumer; no K2 or scheduled M3 use. |
| `&pcie2` + `&pcie2_phy`, C:718-726 | Enables third PCIe port | Partial: U/L S:2385-2389,2481-2487 | Never enable without a real consumer; no K2 or scheduled M3 use. |
| `&pm8150_gpios` volume states, C:728-744 | Volume-key pinctrl | Partial: controller U/L Q/pm8150.dtsi:126; states: no (B) | M2 with volume keys. |
| `&pm8150b_charger`, C:746-749 | Enables PMIC charger and battery link | No label/node in pinned U/L Q/pm8150b.dtsi; community defines it at C/Q/pm8150b.dtsi:109-127 | Not K2. M2 is blocked on a separate generic PMIC review; do not invent this label locally, I14. |
| `&pm8150b_typec` + connector/port graph, C:751-786 | Type-C/PD and HS role-switch endpoint | Partial: generic controller U/L Q/pm8150b.dtsi:61-98 | Not in fixed-peripheral K2. M2 USB OTG/PD change. |
| `&pm8150b_vbus`, C:788-793 | VBUS current regulator | Partial: generic disabled, U/L Q/pm8150b.dtsi:55-59 | M2 host/OTG support; peripheral-only K2 leaves it disabled. |
| `&pon_pwrkey`, C:795-797 | PMIC power key | Partial: generic U/L Q/pm8150.dtsi:53 | M2 input; physical forced reboot remains the M1 plan's recovery, not a DTS feature. |
| `&pon_resin`, C:799-802 | PMIC volume-down key | Partial: generic U/L Q/pm8150.dtsi:63 | M2 input. |
| `&qup_spi4_cs_gpio`, `&qup_spi4_data_clk`, C:804-812 | SPI4 pin drive changes | Partial: U/L S:5506-5517; L adds six-line offset | Never add without the consumer that needs it; none in K2. |
| `&qupv3_id_0/1/2`, C:814-824 | Enables all QUP wrappers | Partial: U/L S:1024,1364,1791 | K2 enables only `qupv3_id_1` for `uart12`. Others follow real I2C/SPI/UART consumers. |
| `&tlmm` reserved ranges, C:826-827 | Reserves GPIOs 28-31 and 40-43 | Partial: TLMM U S:5132; L S:5138 | K2 retains these safety reservations even though NFC/fingerprint are out of scope. |
| BT enable/default/sleep states, C:829-847 | QCA BT GPIO pinctrl | Partial: generic TLMM only, L S:5138; states: no (B) | M3 QCA. |
| WLAN default/sleep states, C:849-867 | QCA WLAN GPIO pinctrl | Partial: generic TLMM only, L S:5138; states: no (B) | M3 QCA. |
| Touch active/suspend states, C:869-881 | Touch interrupt/reset pinctrl | Partial: generic TLMM only, L S:5138; states: no (B) | M2 touch. |
| `&ufs_mem_hc`, C:884-892 | UFS VCC/VCCQ/VCCQ2, load limits and enable | Partial: generic disabled, U S:2510-2557; L S:2516-2557 | K2 enabled in base DTB. M1 boot 1's builder derivative disables the host; boot 2 enables it with no write allowlist. |
| `&ufs_mem_phy`, C:894-898 | UFS QMP PHY supplies and enable | Partial: generic disabled, U S:2582-2606; L S:2588-2606 | K2. |
| `&usb_1`, C:900-902 | Primary DWC3 Qualcomm glue enable | Partial: generic disabled, U S:4177-4186; L S:4183-4186 | K2. |
| `&usb_1_dwc3`, C:904-907 | OTG mode and role switch | Partial: generic controller U S:4223-4260; L S:4229-4260 | K2 deliberately changes to `dr_mode = "peripheral"` and has no role-switch property. M2 restores OTG in a separate commit. |
| `&usb_1_hsphy`, C:909-914 | USB1 HS PHY supplies and enable | Partial: generic disabled, U S:3886-3903; L S:3892-3903 | K2. |
| `&usb_1_dwc3_hs_out`, C:916-918 | Type-C HS graph endpoint | Partial: empty generic endpoint U S:4245-4250; L S:4245-4250 | Not K2; M2 with Type-C role switching. |
| `&usb_1_qmpphy`, C:920-924 | USB1 SS/DP QMP PHY supplies and enable | Partial: generic disabled, U S:3917-3968; L S:3923-3968 | K2, matching the enabled DWC3 PHY references. |
| `&usb_2`, `&usb_2_dwc3`, C:926-932 | Secondary DWC3 host mode | Partial: generic U S:4266-4329; L S:4272-4329 | Not K2; M2 only if USB host is required. |
| `&usb_2_hsphy`, C:934-940 | USB2 HS PHY supplies and enable | Partial: generic U S:3899-3915; L S:3905-3915 | M2 with USB2 host. |
| `&usb_2_qmpphy`, C:942-947 | USB2 SS PHY supplies and enable | Partial: generic U S:3965-3992; L S:3971-3992 | M2 with USB2 host. |
| `&venus`, C:949-952 | Video firmware and enable | Partial: generic disabled, U S:4326-4362; L S:4332-4362 | M3 media plan; remain disabled in K2. |
| `&uart6` + Bluetooth child, C:955-968 | QCA6390 BT and six PMU supplies | Partial: generic UART U/L S:1708-1722; child: no (B) | M3 QCA. Never use this UART as K2 earlycon. |
| `&qup_i2c7_default`, `&qup_spi7_data_clk`, C:970-976 | Disables conflicting QUP7 pin states | Partial: U/L S:5346-5349,5559-5565; L adds six-line offset | M3 in the consolidated QCA fix. No K2 consumer. |

Two K2 requirements are inherited or newly intentional, rather than copied C
blocks:

| Node | Existing evidence | K2 decision |
| --- | --- | --- |
| `/soc@0/watchdog@17c10000` | Generic APSS watchdog is present without a disabled status, U S:6136-6140 and L S:6142-6147. C has no override [V: `docs/research/sm8250-dts-gap.md`:157-159]. | Keep the inherited node. Do not add a second watchdog. The initramfs loads `qcom_wdt` and arms the feeder per M1 plan §5.5; actual ABL handoff is I8. |
| `uart12`, `serial@a90000` | Generic GENI debug UART is disabled, U/L S:2028-2042; C instead aliases Bluetooth `uart6` [V: C:41-43,955-968]. | New K2 candidate only after stage-0 live-DT proof: enable `uart12`, alias `serial0` to it and use `serial0:115200n8` as stdout. No `earlycon=` argument is invented here, I5. |

## 3. Minimal K2 DTS specification

The new file will be
`L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`, with one
Makefile entry next to the other SM8250 boards. The DTS does **not** live in
this planning repository.

### 3.1 Includes and exact root identity

Include the binding headers actually used, RPMh regulator constants,
`sm8250.dtsi`, `pm8150.dtsi` and `pm8150l.dtsi`. Do not include PM8150B,
PM8009 or the OnePlus common file in K2.

The root properties are exactly [V: C:33-39; M1 plan:158-167]:

```dts
model = "OnePlus 8 Pro";
compatible = "oneplus,instantnoodlep", "qcom,sm8250";
chassis-type = "handset";
qcom,msm-id = <0x164 0x10000>, <0x164 0x20001>;
qcom,board-id = <0x08 0x00>, <0x00 0x00>;
```

The stock boot image/live DT must confirm these values before R7 [I: M1 plan
P1, lines 399-403]. There is no new root `qcom,pmic-id` by default. If the M1
P1/P3/P4 path chooses an exact-DTB-match variant, add only the captured value
as a separately explained variant; do not confuse it with the string
`qcom,pmic-id` properties inside RPMh regulator blocks [V: C:283-287,330-333,
464-467; M1 plan:205-237].

### 3.2 Exact K2 node list

1. **Root `/`:** model, compatible, chassis and the two ID properties above.
   Add the root binding enum before this DTS is added.
2. **`/aliases`:** `serial0 = &uart12`, gated by I5. Do not alias `uart6` in
   the minimal board DTS.
3. **`/chosen`:** two address/size cells, ranges,
   `stdout-path = "serial0:115200n8"` after I5 passes, and
   `framebuffer@9c000000`. The framebuffer has `simple-framebuffer`, `reg`
   starting at 0x9c000000 with length `1080 * 2376 * 4`, width 1080, height
   2376, stride `1080 * 4`, and format `a8r8g8b8` [V: C:45-58]. Geometry is
   still checked against the stock live `/chosen`, I4. K1/R7 console policy
   stays with the M1 image command line; this plan adds no earlycon argument.
4. **All `/reserved-memory` replacements:** delete and recreate the fourteen
   generic regions, and add `cont_splash_mem` and `ramoops@b0000000` exactly as
   inventoried. Also retain the inherited generic regions that C does not
   delete. Every stock region must be reconciled before use, I2; this is not
   permission to trim apparently unused firmware reservations.
5. **Fixed regulators:** `vph_pwr` and `vreg_s4a_1p8` with C's values.
6. **`&apps_rsc`:** PM8150 `regulators-1` and PM8150L `regulators-2`, their
   required parent links, and only `l2a`, `l5a`, `l6a`, `l9a`, `l12a`, `l17a`,
   `l18a`, `s6a`, `bob` and `s8c` with C's names, voltage ranges, modes and
   loads. PM8009 and other rail nodes stay out. Values still need the live-DT
   comparison in I6.
7. **Debug UART:** `&qupv3_id_1` and `&uart12`, both `status = "okay"`, after
   I5 passes. Do not enable QUP DMA just for this UART.
8. **Display handoff, not native display:** `/chosen/framebuffer@9c000000`
   above plus `&dispcc { status = "disabled"; };`. Keep common `&mdss`,
   `&gpu`, and `&gmu` disabled. No panel, DSI, MDSS, backlight or GPU child is
   added.
9. **UFS:** `&ufs_mem_hc` with C's VCC/VCCQ/VCCQ2 supplies, maximum currents
   and `status = "okay"`; `&ufs_mem_phy` with both C supplies and `okay`.
   The unmodified base K2 DTB is for UFS-on boot 2. The M1 builder's disposable
   probe derivative disables the host for boot 1, as already required [V: M1
   plan:265-274]. No DT property makes storage writable; the initramfs has no
   `omamobile-ufs-rw` allowlist [V: M1 plan:249-256].
10. **USB peripheral:** `&usb_1` okay; `&usb_1_dwc3` with
    `dr_mode = "peripheral"` and no `usb-role-switch`; `&usb_1_hsphy` and
    `&usb_1_qmpphy` with C's supplies and okay. This is the base K2 DTS, so
    the M1 builder has no role-switch removal to perform. Enumeration without
    Type-C role switching is I7 and is proven only in R7.
11. **Watchdog:** retain inherited `/soc@0/watchdog@17c10000` unchanged. Its
    kernel driver and feeder policy are M1 image work, not a new DTS child.
12. **TLMM safety:** `&tlmm` with only `gpio-reserved-ranges = <28 4>, <40 4>`.
    Do not include the BT, WLAN or touch pinctrl states yet.

### 3.3 Deliberately left out

- Native DSI/panel, MDSS enablement, GPU/GMU and DisplayPort; simplefb is the
  only M1 display path [V: C:51-58,607-609,671-673; M1 plan:275-276].
- UFS boot-1 enablement, every write allowlist, persistent installation and
  any DTS-driven partition write.
- The unused PM8150B include, Type-C/PD, role switching, VBUS host mode, USB2
  host, and OTG mode. PM8150B and these consumers return together after
  fixed-role peripheral networking works.
- Volume/power/resin keys, NFC, touch, battery/charger/fuel gauge and all
  unrelated SPI/I2C/DMA enables.
- ADSP, CDSP, SLPI and Venus firmware loading, plus all proprietary firmware
  files. Reserved memory remains even while these consumers are disabled.
- QCA6390 PMU/regulators, PCIe ports, Wi-Fi/BT pinctrl and `uart6`. The entire
  QCA set is one later logical change, including the QUP7 state disables [V:
  `docs/research/sm8250-dts-gap.md`:104-127,160-164].
- The standalone `qca639x`, `vreg_s6c_0p88`, unused PCIe1/2 and rails without a
  named consumer. "Present in C" is not by itself a reason to enable power.
- A common-OnePlus include split, new drivers, and copies of generic SM8250
  bindings/drivers already in L. If a needed binding or driver is actually
  absent at implementation time, stop and gate that work separately [V:
  `docs/research/sm8250-dts-gap.md`:58-69,168-174].

## 4. Commit order and licence

All kernel-side code and bindings are committed in a fresh branch of
**linux-omarchy-mobile**, based on the then-current reviewed `omamobile` pin.
Only this plan is in `omamobile-instantnoodlep`. Re-run §5 after any rebase;
the line citations above describe the research pins, not permission to ignore
newer review findings.

Every DTS or common-DTS change carries `// SPDX-License-Identifier: GPL-2.0`.
Retain applicable upstream/community copyright notices and authorship. Commit
messages name the community tag and the Wi-Fi/BT repair provenance when that
later change is made. No decompiled downstream DT, leaked code or proprietary
firmware is used. The planning Markdown remains MIT.

| Order | Upstream-style commit | Content and gate |
| --- | --- | --- |
| 0 | No commit: base/binding audit | Confirm the selected L base still has the generic SM8250/PMIC nodes and schemas. `make dt_binding_check` on the unchanged base establishes the baseline. Missing generic support stops the series rather than causing a blind driver import. |
| 1 | `dt-bindings: arm: qcom: Document OnePlus 8 Pro` | Add `oneplus,instantnoodlep` with fallback `qcom,sm8250` to `Documentation/devicetree/bindings/arm/qcom.yaml`. No DTS in this commit. Binding check must pass. |
| 2 | `arm64: dts: qcom: Add OnePlus 8 Pro` | New base board DTS and Makefile entry: identity, chosen/simplefb, proven debug UART, full memory map, disabled display takeover and inherited watchdog. No UFS/USB or their regulators yet. D2/D3/D6 plus the applicable root/chosen fdtget checks pass. |
| 3 | `arm64: dts: qcom: instantnoodlep: Enable UFS` | Add UFS host/PHY, VPH/S4A, BOB/S6A/S8C, L5A/L6A/L9A/L17A and their parent links. Keep the M1 boot-1 host-disabled derivative in the builder, not in history. Add UFS fdtget checks and rerun all applicable gates. |
| 4 | `arm64: dts: qcom: instantnoodlep: Enable USB peripheral` | Add USB1 glue, fixed peripheral mode, HS/QMP PHYs, L2A/L12A/L18A and any remaining parent links. All offline checks rerun. Commits 1-4 are the complete R7 candidate. |
| 5 | `arm64: dts: qcom: instantnoodlep: Add input keys` | Volume GPIO keys/states and PON keys as one input-usability change. M2, after R7. |
| 6 | `arm64: dts: qcom: instantnoodlep: Add battery and charging` | Battery, BQ25980, BQ27411 and PMIC charging only after I14 has a reviewed generic-PMIC solution. Bindings first if any new compatible is absent. |
| 7 | `arm64: dts: qcom: instantnoodlep: Add touchscreen` | S6SY761, touch rails, I2C13/QUP dependencies and touch pinctrl. M2. |
| 8 | `arm64: dts: qcom: instantnoodlep: Add USB Type-C and OTG` | Type-C/PD connector graph, HS endpoint, VBUS, OTG role switch and superspeed validation. One logical USB change; it does not undo the recorded K2 result. M2. USB2 host is a separate later commit only if needed. |
| 9 | `arm64: dts: qcom: instantnoodlep: Enable Wi-Fi and Bluetooth` | Port the reviewed `a051db6a` QCA set atomically: PMU/PM8009 rails, PCIe0 child, BT UART, pinctrl and QUP7 disables. Resolve I13 rather than blindly adding `qca639x`. Firmware packaging is a separate non-kernel change. M3. |
| 10 | Panel/remoteproc/media commits, titles set by their own plans | DSI/panel first, then touch handoff validation and GPU/GMU; ADSP/CDSP/SLPI/Venus and NFC each have separate gated subsystem plans and logical commits. Any missing panel binding/driver precedes its DTS. No such work is part of R7. |
| 11 | Optional `arm64: dts: qcom: Add SM8250 OnePlus common support` | Only when at least two supported boards and current upstream review justify a common split. Move facts without changing the resulting instantnoodlep DTB; not an R7 prerequisite. |

Do not squash the K2 commits into the later full-function port. The K2 state
must remain bisectable. One logical change per commit; generic drivers are
added only when a fresh source audit proves them absent and a separate plan
allows them.

## 5. Offline gated runbook

No command below touches a phone. Stage-0 and K1 phone evidence are entry gates,
not steps to reproduce here. Keep captures and generated outputs private. `LIVE`
points to the stage-0 `live.dtb` only after it exists; never commit it or its
full diff.

Set local paths to real locations before running:

```sh
export L=/path/to/linux-omarchy-mobile
export OUT=/path/to/private/k2-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export LIVE=/path/to/private/captures/DATE/live.dtb
export IOMEM=/path/to/private/captures/DATE/iomem.txt
```

| Gate | Offline command or review | Expect/pass | Stop condition | Rollback |
| --- | --- | --- | --- | --- |
| D0 Inputs | Review M1 P0-P5 and K1 R1-R5 results, stage-0 live DT/cmdline/iomem, stock boot IDs and P3/P4 DTBO decision. Pin L and record its commit. | K1 passed; slot/stock evidence accepted by M1; live DT and iomem exist; chosen DTBO policy is written. No open value is guessed. | Any required input is missing, K1 did not pass, or RAM-only is no longer viable. | No changes made; return to the owning M1/stage-0 ticket. |
| D1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` before editing; repeat after commit 1 with `DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom.yaml`. | Baseline is recorded; new `oneplus,instantnoodlep` passes with no new schema error. | Baseline was not recorded, the compatible is rejected, or unrelated new errors appear. | Drop the binding edit; fix only its own commit. |
| D2 DTS build | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` | Compiler/preprocessor and dtc exit 0; the named DTB is newly produced. Repeat after every DTS commit. | Any error, unresolved label, stale output or unexpected deleted node remains. | Delete generated output; fix the single current commit, not a later patch. |
| D3 Full schema | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs_check` | No new warning/error for this board; common baseline differences are documented individually. | The new DTB fails a required property, compatible, PHY/regulator graph or memory schema. | Revert the current uncommitted logical change and correct it. |
| D4 Identity and chosen | Run the `fdtget` block below against `"$DTB"`. | Two exact compatible strings; exact two msm-id pairs and two board-id pairs; FHD+ simplefb values; debug alias/stdout exactly as approved. | Any value differs, a property is missing, or `uart6` appears as debug `serial0`. | Do not package the DTB; fix the defining commit. |
| D5 Minimal surface | Inspect `dtc -I dtb -O dts "$DTB"` and the git diff. Check enabled nodes and regulators against §3.2 and check the UFS boot-1 derivative separately. | Only the exact K2 set is enabled; no Type-C role switch, QCA, native panel, remoteproc, USB2 or extra rails. Boot 1 has no enabled UFS host; boot 2 has it. | Any extra consumer/enable, missing watchdog, missing memory region, or boot-1 UFS host. | Discard output and remove the unintended change. Never compensate by adding an allowlist. |
| D6 Stock memory reconciliation | Decompile built and live DTBs with the block below. Produce a private table of every live and built reserved range: start, end, no-map/reusable and consumer; cross-check with `"$IOMEM"`. | Every stock firmware/splash region is either identically protected or explicitly explained and accepted in the plan. All 16 C replacements are accounted for. | Any stock range is missing, overlaps differently, or cannot be explained. Unexplained `/proc/iomem` residue is not approval. | Stop DTS work; preserve the private evidence and return to the M1 memory risk. |
| D7 Stock live-DT diff | Run the diff block below; separately compare compatible, root/DTBO IDs, `/chosen`, UART node/reg, regulator values and reserved-memory. | Differences are classified as expected mainline/downstream differences, intentional K2 omissions, or defects. Required K2 identity/supply values are confirmed. | Any unexplained identity/UART/regulator difference, or unsafe memory difference. Full text is not pasted into GitHub. | Suppress the candidate; update this plan and one defining commit from the findings. |
| D8 DTBO/probe packaging gate | Apply M1 P3 to the final K2 base and each builder derivative; verify the probe builder's fdtget assertions, image hashes and absence of an UFS write allowlist. | The owner-approved DTBO outcome is unchanged; builder refuses wrong IDs; both boot-1/boot-2 outputs are reproducible and no allowlist exists. | Overlay analysis changes, IDs differ, derivative differs beyond the M1 allowlist of probe edits, or any persistent-write request appears. | Delete images and stop before R7. Do not alter the DTBO partition or boot policy here. |
| D9 Release to M1 R7 | Review commits 1-4, D1-D8 logs, exact L/base/image hashes and all remaining I items with the coordinator/owner. | Written approval for one K2 R7 run under M1's existing Expect/Stop/Rollback rows. K2 is the only kernel change from K1. | Any failed/skipped gate, an unreviewed rebase, or an [I] promoted to fact without evidence. | Keep K1 results; do not run R7. Fix or split the plan. |

### D4: `fdtget` checks

These print values for comparison with §3; the runner must decode cells rather
than accepting a visually similar length or byte order.

```sh
fdtget -t s "$DTB" / compatible
fdtget -t x "$DTB" / qcom,msm-id
fdtget -t x "$DTB" / qcom,board-id
fdtget -t s "$DTB" /aliases serial0
fdtget -t s "$DTB" /chosen stdout-path
fdtget -t x "$DTB" /chosen/framebuffer@9c000000 reg width height stride
fdtget -t s "$DTB" /chosen/framebuffer@9c000000 compatible format
fdtget -t s "$DTB" /soc@0/serial@a90000 status
fdtget -t s "$DTB" /soc@0/ufshc@1d84000 status
fdtget -t s "$DTB" /soc@0/usb@a6f8800/usb@a600000 dr_mode
fdtget -t s "$DTB" /soc@0/watchdog@17c10000 compatible
```

Expected: compatible lines `oneplus,instantnoodlep` and `qcom,sm8250`; msm-id
cells decode to `<0x164 0x10000>` and `<0x164 0x20001>`; board-id cells decode
to `<0x08 0x00>` and `<0x00 0x00>`; framebuffer geometry is 1080x2376 with
stride 4320 and length 10264320 bytes (0x9c9f00); the debug status is `okay`;
USB mode is `peripheral`. The watchdog compatible list is
`qcom,apss-wdt-sm8250`, `qcom,kpss-wdt`. The base DTB reports UFS `okay`; the
separately generated boot-1 derivative reports the host `disabled`.

### D6-D7: local decompile and diff

```sh
dtc -I dtb -O dts -o "$OUT/k2-built.dts" "$DTB"
dtc -I dtb -O dts -o "$OUT/stage0-live.dts" "$LIVE"
diff -u "$OUT/stage0-live.dts" "$OUT/k2-built.dts" > "$OUT/stage0-vs-k2.diff"
```

A zero diff is not expected because the stock DT is downstream and overlaid.
The review goal is an explicit explanation of differences, not a cosmetic match
[V: M1 plan:216-237]. R7's own post-boot live-DT comparison remains M1 R3 and
is not replaced by this offline diff [V: M1 plan:407].

## 6. Risks and every open inference

| ID | Risk and open [I] | Gate needed before relying on it |
| --- | --- | --- |
| I1 | [I] The C root msm-id/board-id pairs match this stock boot image and its selected DTBO entry; root `qcom,pmic-id` requirements are unknown [V: M1 plan:158-167,196-237]. | M1 P1/P3/P4 and D0/D4/D8. A different capture updates the plan, never a guessed fallback. |
| I2 | [I] All fourteen recreated regions, continuous splash and ramoops match stock on this unit. Wrong firmware memory can corrupt RAM silently [V: coordinator review, `docs/research/sm8250-dts-gap.md`:27-29; M1 plan:372-378]. | D6 must cover every live reserved range and iomem line. No exception for an unused consumer. |
| I3 | [I] Stock `dtbo_a` may be rejected, tolerated or partly grafted onto the K2 DTB; exact-match and label-stub variants are unproven [V: M1 plan:196-237]. | M1 P3/P4 plus D8; R3 owns the runtime contamination check. Never flash an empty DTBO as an M1 fix. |
| I4 | [I] ABL leaves this unit's panel lit in FHD+ with 1080x2376 a8r8g8b8 memory at 0x9c000000. Native `PANEL_SIZE=1440x3168` is distinct [V: coordinator review:18-22; C:51-58,662-663]. | Stage-0 live `/chosen` and offline D4/D7, then R7 visual evidence. Do not substitute native dimensions in simplefb. |
| I5 | [I] `uart12` at 0x00a90000 is wired as the stock debug UART and uses 115200n8. The C `serial0 = &uart6` is Bluetooth instead [V: abl-boot-flow review:19-26; U/L S:2028-2042; C:41-43,955-968]. | Live `stdout-path`, resolved UART `reg`, pin routing and cmdline must agree before enabling the alias/stdout. Otherwise leave debug output to simplefb and revise commits 2/D4 before R7. No invented earlycon. |
| I6 | [I] C's UFS/PHY and USB/PHY rail names, voltage ranges, parents and 800 mA load limits are valid for this unit and the selected L schema/driver generation. | Compare stock live DT/regulators, G/ only as a public register reference if needed, D3/D5/D7, then R7's guarded checks. Do not raise currents to bypass a probe failure. |
| I7 | [I] Fixed-role USB peripheral enumerates with no Type-C role-switch graph and with both common PHY references enabled. | D3/D5/D7 then R7's existing USB/SSH gate. If it fails, change one documented item at a time; do not enable host VBUS or OTG during first light. |
| I8 | [I] ABL leaves the APSS watchdog in a state that `qcom_wdt` plus the initramfs feeder can own safely [V: M1 plan:260-264; L S:6142-6147]. | Builder verifies driver/feeder inclusion; R7's existing watchdog checks decide. DTS stays unchanged unless evidence requires a reviewed node change. |
| I9 | [I] Generic node names, labels and semantics have not changed between C `7.2.0-dev` and the rebased L base in a way that invalidates a ported override. The inspected pins already differ in some generic details, and the PMIC charger label is one concrete example [V: C/Q/pm8150b.dtsi:109-127 versus L Q/pm8150b.dtsi:109-160]. | Fresh source audit at implementation/rebase, D1-D7. Port properties, not a wholesale replacement of L's common files. |
| I10 | [I] K1 success does not establish that the same ABL accepts K2's distinct DTB size/layout or DTBO interaction. | Keep IDs and image geometry fixed, use M1's same builder/gates, D8/D9, and treat K2 as the only R7 change. A refusal returns to the DTBO/size analysis, not flashing. |
| I11 | [I] The owner's panel variant and its future panel binding/driver/lane/reset requirements remain unverified [V: M1 plan:385-386; `docs/research/sm8250-dts-gap.md`:152-156]. | Separate panel plan after simplefb K2; do not enable MDSS as a console troubleshooting step. |
| I12 | [I] QCA6390 firmware availability and ath11k/BT runtime success are unproven even after the repaired DTS is ported [V: `docs/research/sm8250-dts-gap.md`:160-164]. | M3 QCA runtime plan and owner-supplied firmware packaging. No firmware enters git and no QCA DTS enters K2. |
| I13 | [I] The standalone `qca639x` power-domain provider is required by the final reviewed QCA design; no consumer is visible in C's instantnoodlep file [V: C:254-272,681-726]. | Trace consumers and review `a051db6a` plus then-current bindings before M3 commit 9. Omit it if unused; never enable it speculatively in K2. |
| I14 | [I] The missing `pm8150b_charger` generic node in pinned U/L requires common PMIC work rather than a board-local workaround [V: C/Q/pm8150b.dtsi:109-127; L Q/pm8150b.dtsi:109-160]. | M2 generic-PMIC binding/driver/source review and its own gate before commit 6. It does not block peripheral-only K2. |
| I15 | [I] The current upstream OnePlus SM8250 common-patch series may supersede this single-board layout before implementation; the inspected U/L pins do not contain it [V: `docs/research/abl-boot-flow.md`:157-160; Q/ listings at the pins]. | Re-read current upstream and the series at branch time. Prefer its reviewed structure if landed, but keep the K2 functional boundary and rerun every gate. |

## 7. Definition of done for this DTS phase

K2 DTS work is ready to hand to M1a R7 only when commits 1-4 exist in L, D0-D9
pass, the exact root IDs and 1080x2376 simplefb are mechanically checked, every
reserved range is reconciled, and the two boot derivatives differ only as the
M1 plan permits. Actual console, SSH, read-only UFS, watchdog and live-DT proof
is then recorded by R7; this plan does not claim it in advance.
