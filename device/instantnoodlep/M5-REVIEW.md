<!-- SPDX-License-Identifier: MIT -->
# M5 subsystem plan cross-review

Adversarial review of `WIFI-BT-M5-PLAN.md`, `MODEM-M5-PLAN.md`,
`AUDIO-M5-PLAN.md`, `SENSORS-M5-PLAN.md`, and `POWER-M5-PLAN.md`. Kernel
citations were checked against [torvalds/linux v7.3-rc6](https://github.com/torvalds/linux/tree/v7.3-rc6),
not the unavailable `~/src/l` checkout; line references may differ slightly.
Private `entry16.dts` claims were skipped as instructed and are not counted in
the sample. A table row marked WRONG has been corrected in its plan;
UNVERIFIABLE marks a sampled claim backed by a remote source that could not be
independently fetched here.

The checked-claim sample contains **75 [V] assertions**: **67 OK, 4 WRONG,
4 UNVERIFIABLE**. Counts below are per-plan table counts, not a count of every
statement in the source documents.

## WIFI-BT-M5-PLAN.md — 13 OK / 1 WRONG / 1 UNVERIFIABLE

| Checked claim | Verdict | Source |
|---|---|---|
| PCI ID `17cb:1101` is ath11k's QCA6390 ID | OK | [`ath11k/pci.c:25-39`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/pci.c#L25-L39) |
| TCSR major revision 2 selects QCA6390 hw2.0 | OK | [`ath11k/pci.c:997-1016`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/pci.c#L997-L1016) |
| QCA6390 firmware directory and 256 KiB board size | OK | [`ath11k/core.c:219-231`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/core.c#L219-L231) |
| QCA6390 uses M3 firmware support | OK | [`ath11k/core.c:219-288`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/core.c#L219-L288) |
| `qcom,qca6390-pmu` is supported by the WCN power-sequencing driver | OK | [`pwrseq-qcom-wcn.c:560-569`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/power/sequencing/pwrseq-qcom-wcn.c#L560-L569) |
| QCA6390 PMU has eight named input rails and 60/100 ms delays | OK | [`pwrseq-qcom-wcn.c:314-325`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/power/sequencing/pwrseq-qcom-wcn.c#L314-L325) |
| PCI power-control wrapper maps `pci17cb,1101` to the WLAN pwrseq target | OK | [`pci-pwrctrl-pwrseq.c:37-52,119-122`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/pci/pwrctrl/pci-pwrctrl-pwrseq.c#L37-L52) |
| Binding path for QCA6390 PMU | WRONG (corrected) | Draft said no binding under `bindings/power/`; it is [`bindings/regulator/qcom,qca6390-pmu.yaml`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/regulator/qcom%2Cqca6390-pmu.yaml). The plan now points W1 at this schema. |
| PMU binding requires the eight QCA6390 supply handles | OK | [`qcom,qca6390-pmu.yaml`, required properties](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/regulator/qcom%2Cqca6390-pmu.yaml) |
| PCIe ath11k selects MHI, QRTR/QRTR-MHI, and PCI power control | OK | [`ath11k/Kconfig:3-24`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/Kconfig#L3-L24) |
| QCA6390 board lookup uses chip/board identifiers and optional calibration variant | OK | [`ath11k/core.c:1477-1497,1505-1556,1830-1912`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/core.c#L1477-L1497) |
| QCA6390 doesn't use firmware board regdb; current-country support is present | OK | [`ath11k/core.c:274,282`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wireless/ath/ath11k/core.c#L274-L282) |
| QCA6390 UART firmware names use `htbtfw%02x.tlv` and `htnv%02x.bin` | OK | [`btqca.c:756-782,886-889`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bluetooth/btqca.c#L756-L782) |
| Community instantnoodlep repair reports ROM `0x0200`, `htbtfw20.tlv`, and `htnv20.bin` | OK | [GitLab MR 8 test log](https://gitlab.com/sm8250-mainline/linux/-/merge_requests/8) |
| C-tree OnePlus GPIO/pinctrl values are independently verified | UNVERIFIABLE | The cited Nura tree/tag was behind an anti-bot challenge in this review; retain the live-DT gate before relying on the board-specific GPIO values. |

### Substantive findings

- The PMU binding search looked in the wrong directory; it is a regulator
  binding, not a power-sequencing binding. Corrected in W1 and §3.2.
- The draft's Bluetooth firmware row in `FIRMWARE-PLAN.md` used `hp*21`,
  which is not QCA6390's naming. The QCA6390 `ht*20` names are now in that
  plan and the ROM version remains a device gate.
- The plan now requires the neutral `dtbo_b` before RAM boot. Wi-Fi itself
  uses PCI/device compatible matches, but the built-vs-live DT check and all
  M5 boots still depend on removing the stock overlay.
- The Wi-Fi AP test creates persistent NetworkManager state. R4 now requires
  explicit owner go for the `userdata` profile write and deletes that test
  profile during rollback.

## MODEM-M5-PLAN.md — 13 OK / 1 WRONG / 1 UNVERIFIABLE

| Checked claim | Verdict | Source |
|---|---|---|
| PCI vendor/device ID `17cb:0306` maps to the SDX55 generic MHI descriptor | OK | [`pci_generic.c:988-989`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bus/mhi/host/pci_generic.c#L988-L989) |
| SDX55 descriptor names `sbl1.mbn`, `edl.mbn`, and enables EDL trigger | OK | [`pci_generic.c:405-415`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bus/mhi/host/pci_generic.c#L405-L415) |
| SDX55 v1 MHI channel set includes QMI, MBIM control, `IPCR`, `IP_SW0`, and `IP_HW0` | OK | [`pci_generic.c:314-342`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bus/mhi/host/pci_generic.c#L314-L342) |
| MHI WWAN control maps `QMI` to `WWAN_PORT_QMI` | OK | [`mhi_wwan_ctrl.c:256-265`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wwan/mhi_wwan_ctrl.c#L256-L265) |
| `IP_HW0` produces `mhi_hwip%d` | OK | [`mhi_net.c:389-393`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/mhi_net.c#L389-L393) |
| The SDX55 M5 config needs `MHI_WWAN_MBIM` for its `IP_HW0` raw-IP data channel | WRONG (corrected) | [`pci_generic.c:327-328`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bus/mhi/host/pci_generic.c#L327-L328) names `IP_HW0`; [`mhi_wwan_mbim.c:660-661`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wwan/mhi_wwan_mbim.c#L660-L661) binds only `IP_HW0_MBIM`. The config row now requires MHI_NET and treats MBIM as unnecessary for this channel. |
| pcie2 generic node uses the SM8250 modem clock/PHY | OK | [`sm8250.dtsi:2388-2512`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L2388-L2512) |
| pcie2 default pinctrl includes PERST/CLKREQ/wake lines 85/86/87 | OK | [`sm8250.dtsi:5877-5896`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L5877-L5896) |
| Qualcomm PCIe parses the legacy `perst-gpios` property | OK | [`pcie-qcom.c:2071-2077`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/pci/controller/dwc/pcie-qcom.c#L2071-L2077) |
| `pci_generic` matches SDX55 by PCI ID rather than a modem DT compatible | OK | [`pci_generic.c`, `mhi_pci_id_table`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/bus/mhi/host/pci_generic.c) |
| QMI control port is a WWAN port, not QRTR | OK | [`mhi_wwan_ctrl.c`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/net/wwan/mhi_wwan_ctrl.c); optional QRTR-MHI binds `IPCR` separately. |
| `edl.mbn` is now present in the name-only firmware map | OK | [`firmware.map:28-31`](firmware.map) |
| MHI PCI generic support is enabled in the arm64 defconfig | OK | [`arm64/configs/defconfig:262`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/configs/defconfig#L262) |
| Nura's public instantnoodlep image reports SMS and mobile data | OK | [Nura README, Mobile data and SMS](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial#mobile-data-and-sms); this does not establish the Arch ModemManager build. |
| Community pcie2 supply/rail values are valid for this handset | UNVERIFIABLE | The pinned community tree could not be fetched in this review; retain the planned stock/live-DT comparison before using C's rail values. |
| Stock overlay machine-compatible rewrite and neutral-DTBO requirement | OK | [`NOTES.md:35-46`](NOTES.md) records observation; `pci_generic` itself is PCI-ID-bound, so this is a shared clean-DT prerequisite rather than a modem-PDM dependency. |

### Substantive findings

- `MHI_WWAN_MBIM` does not provide a data netdev for the SDX55 v1 channel
  name `IP_HW0`; the driver binds only `IP_HW0_MBIM`. The plan now requires
  raw-IP validation and removes the unsupported channel rename as a default.
- The M5 image now maps the EDL firmware row, previously absent from
  `firmware.map`; F2 must still confirm the member exists.
- MHI over PCIe does not depend on `qcom_pd_mapper`; pcie2's actual board
  wiring and ModemManager compatibility remain explicit gates.
- The neutral DTBO is a common prerequisite. No pcie2 implementation step
  may proceed while the live root reports the stock Kona/MTP compatible list.

## AUDIO-M5-PLAN.md — 15 OK / 0 WRONG / 0 UNVERIFIABLE

| Checked claim | Verdict | Source |
|---|---|---|
| SM8250 ADSP PAS descriptor uses PAS ID 1 and auto-boot | OK | [`qcom_q6v5_pas.c`, `sm8250_adsp_resource`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/remoteproc/qcom_q6v5_pas.c) |
| PAS driver accepts a DT `firmware-name` override | OK | [`qcom_q6v5_pas.c`, probe firmware-name read](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/remoteproc/qcom_q6v5_pas.c) |
| PAS remoteproc attaches a PDM auxiliary subdevice | OK | [`qcom_q6v5_pas.c`, `qcom_add_pdm_subdev`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/remoteproc/qcom_q6v5_pas.c); [`qcom_common.c`, PDM auxiliary registration](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/remoteproc/qcom_common.c) |
| PDM mapper selects platform domains by `of_machine_get_match()` | OK | [`qcom_pd_mapper.c`, `qcom_pdm_start`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/qcom_pd_mapper.c) |
| SM8250 PDM domain list contains ADSP audio and SLPI services | OK | [`qcom_pd_mapper.c`, `sm8250_domains`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/qcom_pd_mapper.c) |
| SM8250 DTS declares classic q6core/q6afe/q6asm/q6adm APR services | OK | [`sm8250.dtsi:6046-6097`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L6046-L6097) |
| `QCOM_APR` Kconfig selects PDR helpers for the q6 audio stack | OK | [`drivers/soc/qcom/Kconfig`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/Kconfig), `QCOM_APR` |
| `qcom,sm8250-sndcard` is a mainline SM8250 sound-card compatible | OK | [`sm8250.c` and sound binding](https://github.com/torvalds/linux/tree/v7.3-rc6/sound/soc/qcom) |
| Mainline WCD938x uses split SoundWire RX/TX compatibles | OK | [`qcom,wcd938x-sdw.yaml`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/sound/qcom%2Cwcd938x-sdw.yaml) |
| RB5 SM8250 UCM profile exists but is not an instantnoodlep profile | OK | [`ucm2/Qualcomm/sm8250/HiFi.conf`](https://raw.githubusercontent.com/alsa-project/alsa-ucm-conf/master/ucm2/Qualcomm/sm8250/HiFi.conf) |
| Mainline `tfa989x` supports the enumerated TFA9890/95/97 models | OK | [`tfa989x.c`, OF match table](https://github.com/torvalds/linux/blob/v7.3-rc6/sound/soc/codecs/tfa989x.c) |
| SM8250 machine driver requires the APR and SoundWire components cited by the plan | OK | [`sound/soc/qcom/Kconfig:185-196`](https://github.com/torvalds/linux/blob/v7.3-rc6/sound/soc/qcom/Kconfig#L185-L196) |
| SM8250 VA macro node is present in the generic DTS | OK | [`sm8250.dtsi:2695-2707`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L2695-L2707) |
| Mainline MTP sound card shows WCD playback/capture DAI-link structure | OK | [`sm8250-mtp.dts:702-799`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250-mtp.dts#L702-L799) |
| Nura public notes say sound works on its tested IN2023 image | OK | [Nura README, Status](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial#status); this is precedent, not proof of this plan's driver configuration. |

### Substantive findings

- The plans relied on root-compatible matching for PDM mapper behavior but
  neither gated nor configured that dependency. Audio now requires the neutral
  DTBO on `dtbo_b`, explicitly verifies `QCOM_PD_MAPPER` and dependencies, and
  checks the live root compatible before loading ADSP.
- The original config audit did not include PDM mapper: APR/SoundWire are
  necessary, but they do not substitute for `QCOM_PD_MAPPER` and a working
  SM8250 machine match.
- PAS firmware-name overrides and firmware-map destinations must match exactly.
  Corrected the `firmware.map`-to-plan target path mismatch for zap, ADSP,
  CDSP, SLPI, and Venus.
- The UCM profile citation was too broad: the verified upstream RB5 profile
  is not a OnePlus profile. Device-specific routing remains required.
- Recording now uses `/tmp`, avoiding an incidental persistent `userdata`
  audio-capture write.

## SENSORS-M5-PLAN.md — 13 OK / 1 WRONG / 1 UNVERIFIABLE

| Checked claim | Verdict | Source |
|---|---|---|
| SM8250 SLPI PAS compatible exists and uses PAS ID 12/auto-boot | OK | [`qcom_q6v5_pas.c`, SM8250 SLPI match](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/remoteproc/qcom_q6v5_pas.c) |
| FastRPC SLPI node declares the `sdsp` label and non-secure domain | OK | [`sm8250.dtsi:3129-3155`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L3129-L3155) |
| FastRPC creates `/dev/fastrpc-SDSP` from the `sdsp` label | OK | [`fastrpc.c`, device-name construction](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/misc/fastrpc.c) |
| `QCOM_PD_MAPPER` uses a machine match and has an SM8250 domain table | OK | [`qcom_pd_mapper.c`, match/start and domain list](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/qcom_pd_mapper.c) |
| SM8250 PDM mapper table includes SLPI root and sensor domains | OK | [`qcom_pd_mapper.c`, `sm8250_domains`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/qcom_pd_mapper.c) |
| `gpio-keys` binding allows switch-named children with `linux,code` | OK | [`gpio-keys.yaml`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/input/gpio-keys.yaml) |
| `SW_LID` is a Linux switch code | OK | [`input-event-codes.h`](https://github.com/torvalds/linux/blob/v7.3-rc6/include/uapi/linux/input-event-codes.h) |
| Mainline AW86927 driver binds `awinic,aw86927` and `awinic,aw86938`, not AW8697 | OK | [`aw86927.c`, OF table](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/input/misc/aw86927.c); [`awinic,aw86927.yaml`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/input/awinic%2Caw86927.yaml) |
| `evtest --play` is a valid force-feedback test command | WRONG (corrected) | [`evtest(1)` synopsis](https://manpages.debian.org/testing/evtest/evtest.1.en.html) only provides monitor/query modes; [`aw86927.c`, FF_RUMBLE registration](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/input/misc/aw86927.c) exposes force feedback, now tested with `fftest`. |
| Nura documents `hexagonrpcd` + `libssc` + `iio-sensor-proxy` on instantnoodlep | OK | [Nura sensors docs, “What the image does”](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/sensors.md) |
| Nura SLPI file comes from modem `/image/slpi.mdt` and its sensor libraries from `dsp_<slot>/sdsp` | OK | [Nura `dsp-firmware.sh`](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/firmware/dsp-firmware.sh), `need_fw` / `need_libs` |
| Nura's sensor configuration is under vendor `/etc/sensors` and ODM `/etc/sensor` | OK | [Nura sensors docs, setup steps](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/sensors.md#setting-up-sensors-on-older-images-or-your-own-build) |
| Nura imports device-specific proximity calibration from `persist` | OK | [Nura `dsp-firmware.sh`](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/firmware/dsp-firmware.sh), `need_cal`; plan explicitly excludes it. |
| `QCOM_FASTRPC` exists in the arm64 defconfig | OK | [`arm64/configs/defconfig:312`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/configs/defconfig#L312) |
| Community hall GPIO/rail values match this exact handset | UNVERIFIABLE | The pinned community tree could not be fetched in this review; keep the live-DT comparison before porting those values. |

### Substantive findings

- SLPI depends on the same PDM mapper machine table as audio. The neutral DTBO
  dependency and `QCOM_PD_MAPPER` config check are now explicit.
- The public setup distinguishes SLPI firmware (`modem` image) from sensor
  libraries (`dsp/sdsp`) and per-unit proximity calibration (`persist`). The
  plan now checks the first two by names only and forbids mapping calibration;
  proximity near/far behavior is deferred to a separate privacy-safe plan.
- The draft's `evtest --play` command is invalid; switched to `fftest`.
- The exact userspace bridge is not yet specified for this Arch package. The
  public Nura stack is evidence of a working precedent, but O6/R3 must pin and
  prove the actual library-to-IIO integration.

## POWER-M5-PLAN.md — 13 OK / 1 WRONG / 1 UNVERIFIABLE

| Checked claim | Verdict | Source |
|---|---|---|
| SM8250 TSENS nodes are `qcom,sm8250-tsens`; TSENS supports compatible-node matching | OK | [`sm8250.dtsi:5039-5061`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L5039-L5061); [`tsens.c`, match table](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/thermal/qcom/tsens.c) |
| PM8150B Type-C node has 16 interrupts and is disabled in generic DTS | OK | [`pm8150b.dtsi:61-98`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/pm8150b.dtsi#L61-L98) |
| PM8150B VBUS regulator is disabled by default | OK | [`pm8150b.dtsi:55-59`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/pm8150b.dtsi#L55-L59) |
| `qcom,pmic-typec.yaml` defines the connector/port graph requirements | OK | [`qcom,pmic-typec.yaml`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/connector/qcom%2Cpmic-typec.yaml) |
| SM8250 cpufreq hardware node uses the EPSS compatible and three domains | OK | [`sm8250.dtsi:6283-6301`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L6283-L6301) |
| QCOM cpufreq-hw driver matches the generic EPSs fallback | OK | [`qcom-cpufreq-hw.c`, OF match table](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/cpufreq/qcom-cpufreq-hw.c) |
| `cpufreq-dt-platdev` blocklist contains `qcom,sm8250` | OK | [`cpufreq-dt-platdev.c`, blocklist/init](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/cpufreq/cpufreq-dt-platdev.c) |
| That machine blocklist is affected when stock DTBO replaces root compatible | OK | [`NOTES.md:35-46`](NOTES.md) plus the cited upstream blocklist logic; fixed by neutral `dtbo_b` prerequisite. |
| TSENS uses node-compatible matching, not the root machine table | OK | [`tsens.c`, `tsens_table`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/thermal/qcom/tsens.c) matches sensor nodes. This differs from POWER's root-machine cpufreq-dt blocklist dependency. |
| PM8150 PON key/RTC node compatibles and addresses | OK | [`pm8150.dtsi:53-74,108-113`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/pm8150.dtsi#L53-L74) |
| QCOM SMBx driver does not match `qcom,qpnp-smb5` | OK | [`qcom_smbx.c`, OF match table](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/power/supply/qcom_smbx.c) has only the listed PMI/PM660 compatibles. |
| BQ25980 driver sets input/charge limits during probe initialization | OK | [`bq25980_charger.c`, `bq25980_hw_init`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/power/supply/bq25980_charger.c) |
| The BQ25980 is proven to be this unit's safe primary charging path | WRONG (corrected) | Neither the generic driver nor the inaccessible private DTS proves the VBUS-to-battery topology or policy. The plan defers its node and all charging tests. |
| Community BQ27411/BQ25980 node supplies and IRQ values match this handset | UNVERIFIABLE | The pinned community tree could not be fetched in this review; retain the live-DT comparison. Separately, the draft itself contains conflicting private battery-capacity values, so no profile is selected. |
| Nura documents an earlier overvoltage and later BQ27411 policy fix | OK | [Nura README warning](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial#status); [charging policy notes](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/charging.md) |

### Substantive findings

- Root-compatible replacement breaks the `cpufreq-dt-platdev` machine
  blocklist. POWER now requires neutral `dtbo_b` and checks for a duplicate
  generic cpufreq instance. TSENS is node-matched and is not affected by this
  specific root-compatible lookup.
- The original charging conclusion (“5 V USB through BQ25980”) was unsupported:
  generic driver availability does not prove the phone's charge path. The draft
  identifies SMB5 as the stock wired charger, but its private entry16 source was
  not checked here and mainline `qcom_smbx` does not match `qcom,qpnp-smb5`.
  More importantly,
  public Nura documentation records an overvoltage regression. The M5 power
  image now omits the BQ25980 node/driver and does not plug in a charger; safe
  charging requires its own battery-profile and policy review.
- Private battery-data claims were not independently verified and the draft
  cited inconsistent capacities. No static capacity or voltage is selected
  until the owner's profile is reconciled.
- `BATTERY_BQ27XXX_DT_UPDATES_NVM` can update gauge NVM; POWER now requires it
  to remain disabled.

## Cross-plan dependencies

1. **Neutral DTBO is the common M5 entry gate.** A separate owner-gated task
   must install a neutral image on `dtbo_b`; no subsystem plan writes it.
   M3/UBWC, audio and sensors/PDM mapping, and POWER/cpufreq all require the
   live root compatible to retain `oneplus,instantnoodlep`, `qcom,sm8250`.
   MODEM's PCI-ID MHI driver does not need PDM mapping, but still gates on the
   neutral DT for identity and to avoid overlay grafts. The Nura device package
   provides a public empty-DTBO precedent.
2. **Audio and sensors share remoteproc infrastructure.** ADSP and SLPI both
   use PAS, GLINK/QRTR, and `QCOM_PD_MAPPER`; configure/enable those shared
   modules once and preserve root matching. Firmware names must exactly match
   `firmware.map`. SLPI firmware is sourced from the modem image; sensor DSP
   libraries are a separate `dsp/sdsp` candidate. Do not map `persist`
   calibration.
3. **PCIe and PMIC ownership spans plans.** Wi-Fi uses pcie0 + QCA6390 PMU
   rails (including PM8009 `s2f`); the SDX55 uses pcie2 + its own PHY and MHI.
   Keep pcie1 disabled. Merge shared `apps_smmu`, clock, RPMh, PMIC regulator,
   and board DTS changes rather than duplicating controller/regulator nodes.
4. **QUP and USB changes are shared.** POWER, Wi-Fi/BT, audio amplifiers, and
   sensors enable overlapping QUP wrappers/controllers and PMIC rails. Merge
   `qupv3_id_0` status and bus pinctrl once; keep uart6 exclusively for BT.
   POWER's Type-C role-switch change must preserve USB peripheral/NCM as the
   default so other runbooks can keep using the tested SSH path.
5. **Firmware-map rows are cross-plan interfaces.** The review adds the SDX55
   `edl.mbn` row, corrects QCA6390 `ht*20` Bluetooth naming, and aligns the
   zap/ADSP/CDSP/SLPI/Venus DTS targets with the map destinations. Firmware
   blobs remain install-time owner assets; maps contain names only.
6. **M3 precedes all M5 desktop checks.** Sensors rotation/ALS tests depend on
   the M3 panel/backlight and compositor; audio PipeWire/UCM checks and the
   sensor bridge belong to the device package, not the kernel DTS series.
7. **Charging is deferred from this M5 run.** Do not enable BQ25980 or test
   charging until a separate plan validates the battery profile and a
   safe BQ27411-driven policy; no charger control writes are permitted here.

## Safety/runbook corrections

- All five M5 plans now gate phone runs on the neutral `dtbo_b` prerequisite;
  RAM boot remains first. The neutral-DTBO write itself belongs to its own
  owner-approved, slot-B-only runbook.
- Wi-Fi R4's persistent NetworkManager profile is explicitly a `userdata`
  write requiring owner go and has a delete rollback. Audio test capture moved
  under `/tmp`. POWER no longer activates a charger or performs a charging
  test.
- No `super` or `_a` partition is written by these plan runbooks; no phone was
  accessed during this review. No firmware bytes, serials, IMEI, or MAC
  addresses were added.
