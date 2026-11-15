<!-- SPDX-License-Identifier: MIT -->

# SM8250 instantnoodlep DTS gap

Research comparison, checked 2026-11-15.  `[V]` means directly checked in a
primary source; `[I]` is an inference from the checked source and still needs
validation on hardware.  The community source is the Nura-hosted SM8250 fork,
the current location reached from the ticket's postmarketOS URL.

## Sources and baseline

* [V] Community DTS:
  <https://gitlab.nura.eco/soc/qualcomm-sm8250/linux/-/blob/7.2.0-dev/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts>
  (raw file is 976 lines).  It includes `sm8250.dtsi`, `pm8150.dtsi`,
  `pm8150b.dtsi`, `pm8150l.dtsi`, and `pm8009.dtsi` at lines 8-12.
* [V] `omamobile` tree API:
  <https://api.github.com/repos/derekross/linux-omarchy-mobile/git/trees/omamobile?recursive=1>
  contains `sm8250.dtsi` and the generic PMIC includes, but no
  `sm8250-oneplus-instantnoodlep.dts` (the qcom directory listing confirms the
  absence):
  <https://api.github.com/repos/derekross/linux-omarchy-mobile/contents/arch/arm64/boot/dts/qcom?ref=omamobile>
* [V] The `omamobile` generic `sm8250.dtsi` has the SM8250 GCC node and clock
  bindings, UFS host/PHY, Adreno 650/GMU, USB controllers/PHYs, DSI blocks,
  and APSS watchdog.  Representative lines in that branch's file are GCC
  962, UFS 2516-2602, Adreno 2940-3067, USB 4183-4327, DSI 4873-5034, and
  watchdog 6142-6147.
* [V] The branch has the generic driver and binding files too:
  `drivers/clk/qcom/gcc-sm8250.c`, `drivers/ufs/host/ufs-qcom.c`,
  `drivers/phy/qualcomm/phy-qcom-qmp-ufs.c`, `drivers/usb/dwc3/dwc3-qcom.c`,
  `drivers/gpu/drm/msm/adreno/`, and
  `Documentation/devicetree/bindings/clock/qcom,gcc-sm8250.yaml` are all
  present in the API tree.  Therefore the primary gap is not missing generic
  code, but the absent phone DTS and its board-level enablement.

## Phone DTS additions over common SM8250

The following is the file/node inventory.  Line numbers refer to the community
DTS URL above.

* [V] Boot identity and console: `model`, OnePlus compatible, chassis type,
  MSM/board IDs, and `serial0 = &uart6` at lines 33-43.  The chosen node
  selects `framebuffer0` and defines a 1080x2376 `simple-framebuffer` at
  lines 45-59.  This is a bootloader/XBL framebuffer handoff, not an
  `earlycon=` declaration.
* [V] Input and power sequencing: volume GPIO keys at lines 61-81;
  `qca6390-pmu` and its ten internal regulators at lines 83-142; fixed
  `vph_pwr`, `vreg_s6c_0p88`, and `vreg_s4a_1p8` supplies at lines 230-252;
  and the QCA6390 WLAN power-domain regulator at lines 254-272.
* [V] Memory map: the board deletes common reserved-memory labels at lines
  15-31 and recreates device-specific modem/remoteproc/GPU/video regions,
  continuous splash memory, and ramoops at lines 144-228.
* [V] PMIC rails: `apps_rsc` regulator blocks for PM8009, PM8150, and PM8150L
  at lines 283-575, plus a simple battery at lines 274-280.  These rails are
  consumed by UFS, USB PHYs, PCIe/Wi-Fi, Bluetooth, and display components.
* [V] Peripheral enablement: ADSP/CDSP/SLPI/Venus firmware and status at
  lines 577-585 and 949-952; QUP DMA at 595-605; NFC, charger, fuel gauge,
  touchscreen, and MDSS status at 611-673; PCIe controllers and Wi-Fi
  supply-backed child at lines 681-726; PMIC Type-C/PD connector, VBUS,
  power-key and resin at lines 746-802.
* [V] Pin and storage setup: TLMM GPIO/pinctrl states for BT, WLAN and touch
  at lines 826-882; UFS host and QMP PHY supplies/status at lines 884-898;
  and USB1 OTG plus USB2 host, HS/QMP PHY supplies, and the Type-C endpoint
  connection at lines 900-947.
* [V] Bluetooth: UART6 and `qcom,qca6390-bt` with all six PMU supply inputs
  at lines 955-968.  The DTS has no explicit DSI panel node; it only enables
  `&mdss` at 671-673.  It also explicitly disables `&gpu` at 607-609.

## Wi-Fi/BT regression fix

* [V] The upstream-style merge commit is `a051db6ac16943fb87ed365a001f49c27f890188`,
  “Merge branch `fix/instantnoodlep-wifi` into `sm8250/v6.12`”, dated
  2024-11-23:
  <https://gitlab.com/sm8250-mainline/linux/-/commit/a051db6ac16943fb87ed365a001f49c27f890188>
* [V] Its diff touches only the instantnoodlep DTS and restores the
  `qca6390-pmu` regulators/GPIOs, changes the WLAN pinctrl label, makes the
  PCIe0 PHY independent of the QCA power domain, adds the `pci17cb,1101`
  Wi-Fi child with ten supplies, and moves Bluetooth to supply-based
  `qcom,qca6390-bt`; it also disables unused QUP I2C7/SPI7 states.  The exact
  diff is available from the commit's primary API endpoint:
  <https://gitlab.com/api/v4/projects/sm8250-mainline%2Flinux/repository/commits/a051db6a/diff>
* [V] The preceding device-DTS addition is commit
  `66a72dc49013`, “arm64: dts: qcom: sm8250-oneplus-instantnoodlep: Add device
  tree for Oneplus 8 Pro”, in the same fork history:
  <https://gitlab.com/sm8250-mainline/linux/-/commit/66a72dc49013>
* [V] The merge request records why the fix exists: Wi-Fi and BT stopped
  working around v6.11 and the fix restores both; it includes ath11k PCIe and
  QCA6390 UART probe evidence:
  <https://gitlab.com/sm8250-mainline/linux/-/merge_requests/8>
* [V] Searching the community fork's commit API for `instantnoodlep` returns
  the initial DTS and the later Wi-Fi/BT repair as the relevant phone-DTS
  commits; no later instantnoodlep DTS repair was found in that query.

## Gap against `omamobile`

* [V] There is no phone DTS target, Makefile entry, or board-specific
  `instantnoodlep` file in the `omamobile` qcom tree.  Consequently all
  board-level boot identity, reserved-memory overrides, PMIC rail values,
  UFS/PHY supplies, USB role/gadget wiring, Wi-Fi/BT power sequencing and
  UART child, keys, touch, and peripheral status are absent.
* [V] The common branch already supplies the generic bindings/drivers and
  hardware nodes for GCC clocks, UFS+QMP UFS PHY, qcom APSS watchdog, DWC3
  Qualcomm glue, DSI/MDSS, Adreno 650/GMU, and PMIC include files.  Porting
  those generic drivers again would be duplication, not a M1 requirement.
* [V] M1 boot essentials missing at board level are: OnePlus compatible/MSM
  and board IDs; serial alias and a chosen node; simple framebuffer; device
  reserved-memory map; PMIC/RPMh regulators; UFS host+PHY supply/status;
  USB1 OTG `dr_mode`/role-switch and Type-C endpoint; and a watchdog takeover
  policy.  The common watchdog node exists, but the phone DTS does not
  explicitly enable or document ownership, so takeover is [I] until boot
  testing.
* [V] Earlycon is not present in the community phone DTS: it selects
  `stdout-path = "framebuffer0"` (line 49).  [I] A first-light port should
  use the common `uart6` node with a kernel command-line earlycon setting or
  an explicitly reviewed chosen-console change; do not infer earlycon from
  the serial alias alone.
* [V] DSI controller/PHY and Adreno 650 nodes are in common SM8250, but the
  phone DTS has no panel node and disables `&gpu`.  Thus DSI/panel is not a
  complete M1 display path, and GPU acceleration is intentionally not part of
  this DTS.  [I] A panel port needs the correct OnePlus panel binding/driver
  and lane/power/reset GPIO data before enabling MDSS.
* [V] The community DTS carries no `&watchdog` override and no kernel driver
  addition: watchdog takeover is a board policy/configuration gap, not a
  missing SM8250 watchdog implementation.
* [V] Wi-Fi/BT are wholly absent from `omamobile`'s instantnoodlep support
  because the phone DTS itself is absent; the `a051db6a` QCA6390 PMU, PCIe
  Wi-Fi child, UART BT supplies, pinctrl labels, and QUP disables must be
  ported together.  [I] Firmware availability and ath11k/QCA6390 runtime
  success still require device validation.

## Proposed porting order

1. Confirm the kernel base and add/validate bindings first (SM8250 GCC,
   QMP-UFS, DWC3 Qualcomm, QCA6390 PMU/BT, simple-framebuffer, panel and
   regulator schemas).  Keep one commit per binding family and run DT schema
   checks.
2. Reuse existing generic drivers; only port a driver commit when the selected
   base demonstrably lacks it.  In particular, do not copy GCC/UFS/DWC3/
   watchdog/Adreno implementations already present in `omamobile`.
3. Add a minimal `sm8250-oneplus-instantnoodlep.dts`: includes, compatible and
   board IDs, chosen serial/framebuffer, reserved memory, PMIC rails, and
   explicit watchdog ownership.  Build the DTB before enabling peripherals.
4. Enable UFS host/QMP PHY and then USB1 OTG: add exact supplies, Type-C
   connector graph, role switch, and `dr_mode = "otg"`.  Validate storage and
   USB gadget networking independently; USB2 host can follow.
5. Add the display path (MDSS/DSI, panel binding/driver, reset/enable GPIOs),
   retaining simple framebuffer for first light until handoff is proven.
6. Port Wi-Fi/BT as one logical DTS change based on `a051db6a`: QCA6390 PMU,
   PCIe child/supplies, UART child/supplies, GPIO states, and QUP state
   disables.  Then add firmware packaging/configuration separately; no
   proprietary firmware belongs in this repository.
7. Enable Adreno only after first-light stability and panel bring-up.  Keep
   the final history in upstream order: bindings, driver (if truly missing),
   then DTS, with one commit per logical change.
