<!-- SPDX-License-Identifier: MIT -->
# WIFI-BT-M5-PLAN: Wi-Fi (QCA6390/PCIe) + Bluetooth (QCA6390/UART6) on instantnoodlep

House-rule-6 gate for milestone **M5** of the wayfinder map: "Wi-Fi, mobile
data/SMS, sensors, cameras" — this file covers only the Wi-Fi + Bluetooth
half. This is a plan only; no code, DTS or firmware is written here. Nothing
in the QCA6390 subsystem is touched before this plan exists with its gated
runbook (AGENTS.md rule 6).

- Date: 2026-11-17. Branch: `m5-plans` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md`, `device/instantnoodlep/NOTES.md`,
  `device/instantnoodlep/DISPLAY-M3-PLAN.md` (style), `docs/research/sm8250-dts-gap.md`.
- Scope: ath11k over PCIe0 (`pci17cb,1101`), the `qcom,qca6390-pmu` power
  sequencer and its rails/GPIOs, hci_qca over UART6 (`qcom,qca6390-bt`),
  firmware (amss/m3/board-2, htbtfw/htnv) from the owner's OTA per
  `firmware.map`, regulatory, and the Arch userspace that drives them.
  M5 runs after M1b (Linux default on slot B [V: NOTES.md 2026-11-17 night])
  and M3. Phone steps are `fastboot boot` (RAM) first; no boot/DTBO flash is
  part of this plan. R4's optional persistent test Wi-Fi profile writes to
  `userdata` only after explicit owner go, and its rollback deletes that
  profile.
- New prerequisite: the neutral DTBO must be installed on `dtbo_b` by a
  separate owner-gated slot-B write plan before this plan's RAM boot. The
  stock overlay rewrites the live root compatible to `qcom,kona-mtp`,
  `qcom,kona`, `qcom,mtp` [V: NOTES.md 2026-11-17 entry]. The QCA drivers
  here match device/PCI compatibles, not the machine root, but M5 requires
  the neutral overlay for the correct live DT identity and to avoid unrelated
  overlay grafts. Public precedent: the Nura pmaports package builds and
  installs its empty `dtbo.img` [V: <https://gitlab.com/postmarketOS/pmaports/-/raw/master/device/testing/device-oneplus-instantnoodlep/APKBUILD>, `kernel_mainline()`].
- Safety model unchanged: never `super`, any `_a` partition, `vbmeta`,
  `persist`, `efs*`, `modem*` (AGENTS.md rule 3). A `boot_b` re-flash after a
  kernel change is a separate owner-gated ticket (M1b B2/B5 pattern), not
  part of this plan.

## 1. Source pins

- `L/` = local mainline tree `~/src/l`, branch `instantnoodlep-k2`
  @ `a28aaf1a09db` (linux-omarchy-mobile `317d87dc2db0` + the four K2 DTS
  commits) [V: NOTES.md 2026-11-16 night, R7]. All `L/` line refs below were
  read in this tree on 2026-11-17.
- `C/` = community SM8250 kernel, gitlab.nura.eco/soc/qualcomm-sm8250/linux
  tag `7.2.0-dev` @ `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9`, as pinned in
  DTS-PORT-PLAN §1. Not re-fetched here; C line refs are quoted from
  DTS-PORT-PLAN §2.3 / `docs/research/sm8250-dts-gap.md`.
- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (FIRMWARE-PLAN pin); `~/src/omarchy-mobile` is that tree locally.
- `E16/` = decompiled stock dtbo entry 16, `~/android/build/p3/entry16.dts`
  (facts only; never copied) plus `~/android/build/p3/fixup-labels.txt`.
- `a051db6a` = community Wi-Fi/BT repair merge commit
  `a051db6ac16943fb87ed365a001f49c27f890188` [V: docs/research/sm8250-dts-gap.md:104-119].

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| WLAN chip | QCA6390 hw2.0, PCI `17cb:1101` on `pcie0` | [V: L/drivers/net/wireless/ath/ath11k/pci.c:29,36 (id table); L/.../qcom,ath11k-pci.yaml:16-18; C:681-706 `wifi@0` pci17cb,1101 via DTS-PORT-PLAN §2.3] Unit silicon [I-M5-1] until R1 dmesg |
| WLAN enable | TLMM GPIO + `qcom,qca6390-pmu` sequencer | [V: L/drivers/power/sequencing/pwrseq-qcom-wcn.c:483,494 (`bt-enable`/`wlan-enable` gpios); C:83-142,849-867 via DTS-PORT-PLAN §2.3] GPIO numbers [I-M5-2] |
| BT | QCA6390 on UART6 (QUP6, 4-wire), `qcom,qca6390-bt` | [V: L/arch/arm64/boot/dts/qcom/sm8250.dtsi:1707-1722 `uart6: serial@998000`, :5765-5769 `qup_uart6_default` gpio16-19 func qup6; E16/entry16.dts:11296-11303 fragment@65 sets `&qupv3_se6_4uart` `status="ok"`; C:955-968 via DTS-PORT-PLAN §2.3] |
| BT/WLAN rails | PMU LDOs ldo0-ldo9 under the `qca6390-pmu` node, parents PM8150 s6a/s8c/s5a/s4a + PM8009 s2f | [V: L/.../sm8250-xiaomi-elish-common.dtsi:107-156 (same SoC sibling: vddaon/vddpmu/vddrfa0p95=s6a, vddrfa1p3/vddpcie1p3=s8c, vddrfa1p9/vddpcie1p9=s5a, vddio=s4a, ldo0-ldo9); DTS-PORT-PLAN §2.1-2.2 (C PM8009 `s2f` needed for M3 QCA)] |
| WLAN reserved mem | `wlan_mem` 0x8e100000, 1 MiB, already in K2 | [V: L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts:62-65; C:155-158 via DTS-PORT-PLAN §2.1] |

## 3. Inventory per block

### 3.1 Wi-Fi: PCIe0 + ath11k

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| PCIe0 controller | present, generic | `qcom,pcie-sm8250` @0x1c00000, perst TLMM 79, wake TLMM 81 [V: L/sm8250.dtsi:2139-2220, :2206-2207] | `disabled` | `status = "okay"` [V: shape C:681-706 via DTS-PORT-PLAN §2.3] |
| PCIe0 PHY | present, generic | `qcom,sm8250-qmp-gen3x1-pcie-phy` @0x1c06000 [V: L/sm8250.dtsi:2222-2259] | `disabled` | okay + `vdda-phy-supply`/`vdda-pll-supply` = l5a/l9a [V: elish :812-817; a051db6a makes the PHY independent of the QCA power domain, sm8250-dts-gap.md:104-119] |
| PCI child `wifi@0` | present, generic bus; board child absent | `pci17cb,1101`, `reg = <0x10000 0 0 0 0>`; binding requires 9 supplies for 1101 [V: L/.../qcom,ath11k-pci.yaml:16-18,66-80] | absent | node with vddrfacmn/vddaon/vddwlcx/vddwlmx/vddrfa0p8/vddrfa1p2/vddrfa1p7/vddpcie0p9/vddpcie1p8 = PMU ldo0-ldo9, `memory-region = <&wlan_mem>`, optional `qcom,calibration-variant` [V: elish :818-835; C:681-706 "ten child supplies" via DTS-PORT-PLAN §2.3] |
| ath11k driver | present | `ATH11K` + `ATH11K_PCI` (selects MHI_BUS, QRTR, QRTR_MHI, PCI_PWRCTRL_PWRSEQ) [V: L/.../ath11k/Kconfig:3-24]; id 0x1101 [V: pci.c:29,36]; hw_rev QCA6390_HW20 from TCSR major==2 [V: pci.c:997-1016] | not in kernel.config | config additions (as modules are fine: kmod is in the rootfs [V: U/rootfs/packages.base:13]): ATH11K, ATH11K_PCI, PCI_PWRCTRL_PWRSEQ, POWER_SEQUENCING_QCOM_WCN [V: L/drivers/power/sequencing/Kconfig:16-28] |
| WLAN power sequencing | present | pci-pwrctrl-pwrseq binds `pci17cb,1101`, requires `vddaon-supply`, gets pwrseq target "wlan" [V: L/drivers/pci/pwrctrl/pci-pwrctrl-pwrseq.c:37-52,119-122] → pwrseq-qcom-wcn "wlan" target [V: pwrseq-qcom-wcn.c:241-247] | absent | DT only (see 3.2); no driver port needed |
| WLAN firmware files | driver requests: `firmware-2.bin` first (magic `QCOM-ATH11K-FW`, embeds AMSS+M3 IEs) [V: L/.../fw.h:9-10, fw.c:145-162]; if no embedded AMSS, `ath11k/QCA6390/hw2.0/amss.bin` [V: mhi.c:343-353]; M3 similarly from firmware-2.bin else `m3.bin` [V: qmi.c:2514-2545]; board data `board-2.bin` [V: hw.h:75-83, core.c:1703-1912]; MODULE_FIRMWARE dir [V: pci.c:1331] | hw params: fw.dir `QCA6390/hw2.0`, board_size 256 KiB, cal_offset 128 KiB, bdf_addr 0x4B0C0000 [V: core.c:222-231] | no firmware on phone | files per firmware.map rows (see §4); decide firmware-2.bin vs amss/m3 at W-gates (§4) |
| Board data naming | — | QCA6390 uses default search: `bus=pci,qmi-chip-id=<id>,qmi-board-id=<id>[,variant=...]`, then w/o variant, then `bus=pci,qmi-chip-id=<id>`, then api-1 `board.bin` [V: core.c:1505-1556, 1830-1912]; `qcom,calibration-variant` from DT [V: core.c:1477-1497, binding qcom,ath11k-pci.yaml:20-24]; path = `ath11k/QCA6390/hw2.0/board-2.bin` (board files skip firmware-name prefix) [V: core.h:1336-1354] | n/a | see §4 board-2.bin resolution |
| Regulatory | present | QCA6390: `supports_regdb=false` (no regdb from board-2) [V: core.c:274], `current_cc_support=true` [V: core.c:282]; world regd "00" fallback [V: reg.c:23-31], notifier [V: reg.c:47]; userspace `wireless-regdb` is in the rootfs [V: U/rootfs/packages.base:20] | n/a | none kernel-side; set country via `iw reg set` / NM at R5 |

### 3.2 QCA6390 PMU power sequencer

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| PMU node | driver present | `qcom,qca6390-pmu` [V: pwrseq-qcom-wcn.c:566-569]; 8 rails vddio/vddaon/vddpmu/vddrfa0p95/vddrfa1p3/vddrfa1p9/vddpcie1p3/vddpcie1p9, pwup 60 ms, gpio delay 100 ms [V: :309-325]; targets "bluetooth"/"wlan" [V: :236-247]; consumer match via `vddaon-supply` grandparent check [V: :403-438]; gpios `bt-enable`/`wlan-enable` [V: :483,:494]. Binding is `Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml` [V: L/ binding]. | absent | root node + `regulators` ldo0-ldo9 + the 8 supply properties + 2 enable GPIOs + pinctrl [V: shape C:83-142 via DTS-PORT-PLAN §2.1; elish :107-156] |
| PM8009 block (s2f) | generic dtsi present | `qcom,pm8009-rpmh-regulators` under &apps_rsc [V: L/.../pm8009.dtsi exists; elish regulators-2 :~490-530] | not included (K2 includes only pm8150/pm8150l [V: K2 dts:13-14]) | add `pm8009.dtsi` include + `regulators-0` with `s2f` and parents [V: DTS-PORT-PLAN §2.2 PM8009 row "M3 QCA needs s2f"; E16/fixup-labels.txt:64 `pm8009_s2`] |
| Standalone `qca639x` power-domain | — | C carries a `qca639x` provider node with no visible consumer [V: DTS-PORT-PLAN §2.1 C:254-272, I13] | absent | omit unless a consumer binds; resolve I13 at W4 [I-M5-6] |
| WLAN/BT pinctrl | generic TLMM present | states under &tlmm [V: C:829-867 via DTS-PORT-PLAN §2.3; E16/fixup-labels.txt:14 `bt_en_sleep`] | only touch states + reserved ranges [V: K2 dts:303-322] | add BT default/sleep + WLAN default/sleep states; GPIO numbers [I-M5-2] until live-DT compare |

### 3.3 Bluetooth: UART6 + hci_qca

| Piece | Mainline status | Driver / binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| UART6 (QUP6) | present, generic | `qcom,geni-uart` @0x998000, irq SPI 607 [V: L/sm8250.dtsi:1707-1722]; 4-wire pinctrl gpio16-19 [V: :5765-5769; E16 confirms 4uart] | `disabled` (never aliased to serial0 — K2 stdout is framebuffer0 [V: K2 dts:44]) | `&qupv3_id_0` + `&uart6` okay (no DMA) [V: DTS-PORT-PLAN §3.2 item 7 pattern for id_1] |
| BT child node | binding present | `qcom,qca6390-bt` [V: L/.../bluetooth/qcom,qca6390-bt.yaml:14-16]; requires vddaon/vddbtcmx/vddrfa0p8/vddrfa1p2/vddrfa1p7/vddrfacmn supplies [V: :36-42]; + qcom,bluetooth-common.yaml `firmware-name` = [nvm, rampatch] [V: :12-17] | absent | child of &uart6 with the 6 PMU supplies [V: elish :967-980; C:955-968 via DTS-PORT-PLAN §2.3] |
| hci_qca driver | present | of_match `qcom,qca6390-bt` → QCA_QCA6390 [V: hci_qca.c:2784]; for DT QCA6390 power comes **only** from pwrseq target "bluetooth" (mandatory) [V: hci_qca.c:2506-2514; soc_data num_vregs=0 :2116-2119]; proto oper_speed 3M [V: :2094-2096]; `firmware-name` array read at probe [V: :2408-2410] | not in kernel.config | config: BT, BT_HCIUART (+SERDEV default y), BT_QCA [V: L/drivers/bluetooth/Kconfig:17-20,106]; no hciattach needed (serdev DT binding) |
| BT firmware names | — | QCA6390 rampatch `qca/htbtfw%02x.tlv`, NVM `qca/htnv%02x.bin`, rom_ver from SoC version [V: btqca.c:779-782,886-889]; rom_ver = ((soc_ver&0xf00)>>4)|(soc_ver&0xf), soc_ver=(soc_id<<16)|rom_ver [V: btqca.c:756-760, btqca.h:47-49]; DT `firmware-name[1]`/`[0]` override as `qca/<name>` [V: btqca.c:767-769,863-873] | no files | see §4 — the "10 vs 20" resolution |
| QUP7 conflicts | — | disable conflicting QUP7 states with the QCA commit [V: C:970-976 via DTS-PORT-PLAN §2.3; a051db6a does it, sm8250-dts-gap.md:104-119] | present in common, unmodified | add the two disables in the same commit |

## 4. Firmware needs (firmware.map rows by name; never bytes)

All from the owner's own verified OTA at install time (AGENTS.md rule 8;
FIRMWARE-PLAN §4 wiring). Rows already drafted in `device/instantnoodlep/firmware.map`:

| File (driver-requested path) | firmware.map row | Notes / resolution |
| --- | --- | --- |
| `ath11k/QCA6390/hw2.0/amss.bin` | `modem:/image/qca6390/amss20.bin\|ath11k/QCA6390/hw2.0/amss.bin` [V: firmware.map:35] | Used only if no `firmware-2.bin` embedded AMSS [V: mhi.c:343-353]. F5 compares with linux-firmware copy [I-M5-4] |
| `ath11k/QCA6390/hw2.0/m3.bin` | `modem:/image/qca6390/m3.bin\|...m3.bin` [V: firmware.map:36] | QCA6390 has m3_fw_support=true [V: core.c:288]; embedded-in-firmware-2.bin preferred if present [V: qmi.c:2514-2545] |
| `ath11k/QCA6390/hw2.0/firmware-2.bin` | **not yet mapped** | If the OTA vendor/modem image or linux-firmware carries it, map it and amss/m3 become fallback-only. Decide at W6 [I-M5-4] |
| `ath11k/QCA6390/hw2.0/board-2.bin` | deliberately unmapped until encoded [V: firmware.map:32-33] | **board-2.bin resolution (offline):** encode the OTA `bdwlan.*` (vendor `/firmware/wlan/`, names-only listing at FIRMWARE-PLAN F2) with `ath11k-bdencoder` (qca-swiss-army-knife; tool not in L/ tree [I-M5-3]) into `board-2.bin`. The driver looks up entry `bus=pci,qmi-chip-id=<c>,qmi-board-id=<b>[,variant=...]` [V: core.c:1505-1556,1830-1912]; chip/board ids are QMI runtime values [I-M5-7 until R1 dmesg "using board name"]. Ensure the encoded JSON carries an entry matching that name, or set DT `qcom,calibration-variant` to a suffix present in it [I-M5-7]. Fallback if no match: linux-firmware's generic board-2.bin entry. Never map `wlan_mac.bin` (per-unit) [V: firmware.map:12] |
| `qca/htbtfw20.tlv` | `bluetooth:/image/htbtfw20.tlv\|qca/htbtfw20.tlv` [V: firmware.map:49] | **BT 10/20 resolution (offline):** for QCA6390 the driver derives rom_ver from the controller ROM version; a ROM of 0x0200 yields rom_ver 0x20, printed `%02x` as "20" → `htbtfw20.tlv`/`htnv20.bin` [V: btqca.c:756-760,779-782,886-889; btqca.h:47-49]. The public instantnoodlep fix independently reports ROM `0x0200` and requests `htbtfw20.tlv`/`htnv20.bin` [V: <https://gitlab.com/sm8250-mainline/linux/-/merge_requests/8>, test log]. The owner's ROM remains to be checked at R2; if it differs, remap that variant from the bluetooth image (F2 lists members). FIRMWARE-PLAN's old `hpbtfw21/hpnv21` row was wrong and is corrected there: those `hp*` names are not QCA6390. DT `firmware-name = "htnv20.bin", "htbtfw20.tlv"` forces exact names if ever needed [V: hci_qca.c:2408-2410; btqca.c:863-873] |
| `qca/htnv20.bin` | `bluetooth:/image/htnv20.bin\|qca/htnv20.bin` [V: firmware.map:50] | NVM alt `.bin` retry exists [V: btqca.c:278-300]; board-id-suffixed NVM (`htnv20.bXXXX`) only for QCA2066/WCN6855 paths [V: btqca.c:688-700], not QCA6390 |

The rootfs carries only `linux-firmware-other` [V: U/rootfs/packages.base:19], so Arch packages are **not** the source for ath11k/qca files here; OTA-mapped rows are. Keep the linux-firmware comparison purely as an offline sanity check (FIRMWARE-PLAN F5).

## 5. Userspace (Arch Linux ARM rootfs)

| Need | Status and evidence |
| --- | --- |
| Wi-Fi connection manager | NetworkManager is in the base rootfs [V: U/rootfs/packages.base:8] and already runs on the phone (usb0 172.16.42.1) [V: NOTES.md 2026-11-17 night]. NM drives wlan0 via wpa_supplicant; no iwd needed. Phone currently has no upstream route (reverse SOCKS only) [V: NOTES.md same entry] — M5 Wi-Fi replaces that |
| Regulatory DB | `wireless-regdb` in base rootfs [V: U/rootfs/packages.base:20]; ath11k takes regd from firmware/11d, `iw reg set` at R5 |
| Bluetooth | bluez is **not** in `rootfs/packages.base` or `rootfs/packages.omamobile` [V: those files, read 2026-11-17]; whether Omarchy's own base set pulls bluez is [I-M5-9] — if absent, add `bluez` + enable `bluetooth.service` in the instantnoodlep device package (pattern: `omamobile-device-instantnoodlep` 0.0.3 [V: NOTES.md 2026-11-17 night]) |
| Tools for R-gates | `iw`, `btmgmt`/`bluetoothctl` (bluez), `lspci` (pciutils in base [V: packages.base:12]), `kmod` [V: packages.base:13] for module loading |
| Kernel config delta | append to `device/instantnoodlep/kernel.config` (separate ticket, not this file): ATH11K=m, ATH11K_PCI=m, PCI_PWRCTRL_PWRSEQ=m, POWER_SEQUENCING_QCOM_WCN=m, BT=m, BT_HCIUART=m, BT_QCA=m, SERIAL_DEV_BUS=y, QCOM_QMI_HELPERS, QRTR, QRTR_MHI, MHI_BUS (selected by ATH11K_PCI [V: ath11k/Kconfig:17-24]) |

## 6. Kernel-side commit order (in linux-omarchy-mobile, not this repo)

One logical commit, upstream order, GPL-2.0 headers (DTS-PORT-PLAN §4
commit 9: the QCA set is atomic [V: DTS-PORT-PLAN §4]):

| # | Commit | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: instantnoodlep: Add PM8009 regulators for the QCA6390 PMU` | include `pm8009.dtsi`, `regulators-0` under &apps_rsc with `vreg_s2f_*` + parents [V: DTS-PORT-PLAN §2.2; elish regulators-2] |
| 2 | `arm64: dts: qcom: instantnoodlep: Enable Wi-Fi and Bluetooth (QCA6390)` | `qca6390-pmu` node + ldo0-ldo9 + 8 supplies + bt/wlan enable GPIOs + pinctrl; `&pcie0`/`&pcie0_phy` okay with l5a/l9a; `wifi@0` under `&pcieport0` with 9 PMU supplies + `memory-region = <&wlan_mem>` + `qcom,calibration-variant` (value decided at W4/I-M5-7); `&qupv3_id_0` + `&uart6` okay + `bluetooth` child with 6 PMU supplies + optional `firmware-name`; BT/WLAN pinctrl states; QUP7 conflicting-state disables. Port the reviewed `a051db6a` set [V: sm8250-dts-gap.md:104-119], values cross-checked against C and the live DT |

No new bindings or drivers are needed: ath11k, pwrseq-qcom-wcn,
pci-pwrctrl-pwrseq, hci_qca/btqca and all bindings are in L/ (§3). The
pwrseq PMU binding yaml path is [I-M5-5]; W1 confirms via `dt_binding_check`
that the `qca6390-pmu` node schema-checks like elish's.

## 7. Gated runbook

Offline gates W0-W8 run on the laptop and touch no phone. Owner gates G1,
R1-R6 run on the phone, **RAM boot first** (`fastboot boot`, nothing
written), as M1a did; the installed slot-B system may be booted read-only
for R5/R6 only, and slot flags must be unchanged afterwards. Never
`fastboot flash`, `erase`, `--set-active` anywhere below (AGENTS.md rule 1;
after any refused RAM boot, cold-reboot to the bootloader before the next
`fastboot boot` [V: NOTES.md 2026-11-16 stage-0 R1 note]).

```sh
export L=/path/to/linux-omarchy-mobile          # branch instantnoodlep-k2 + commit 2
export OUT=/path/to/private/m5-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export K2DTB=/path/to/private/k2-build/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W0 Inputs | M1b done and recorded; neutral DTBO owner-gated install on `dtbo_b` is complete; DTS-PORT-PLAN D0-D9 passed; FIRMWARE-PLAN F0-F6 passed; M3 status recorded; `L` pinned | all present, with live root compatible `oneplus,instantnoodlep`, `qcom,sm8250` | any input missing or stock DTBO still selected | no changes; return to owning ticket |
| W1 Binding baseline | `make -C "$L" O="$OUT" dt_binding_check` on unchanged base, then after commit 2 with `DT_SCHEMA_FILES=Documentation/devicetree/bindings/regulator/qcom,qca6390-pmu.yaml` | baseline recorded; the existing PMU binding and this board pass | new errors | drop the DTS edit |
| W2 Build | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` after each commit | dtc exit 0, DTB produced | any error/stale output | delete output; fix current commit only |
| W3 Schema | `make ... dtbs_check` | no new warning/error for this board | schema failure on pmu/wifi/bt/pcie/uart nodes | revert uncommitted change |
| W4 Node checks | `fdtget` block below + `dtc -I dtb -O dts` diff vs `"$K2DTB"` and live DT | nodes exactly as §3; diff vs K2 limited to QCA set; built/live root compatible is `oneplus,instantnoodlep`, `qcom,sm8250`; simplefb unchanged | any extra enable, missing node, `qcom,kona-mtp` live root, or changed identity | discard output; fix defining commit / return to neutral-DTBO gate |
| W5 Live-DT compare | decompile `"$DTB"` and the stage-0/K2 `live.dtb`; classify every diff; pay attention to `/soc@0/spmi_bus@...` and `&tlmm` children: entry 16 has 5 spmi_bus + 8 tlmm fragments [V: NOTES.md 2026-11-16 P3] that graft onto real nodes on RAM boot | no unexplained QCA-related difference; GPIO numbers of bt/wlan enable match live DT [I-M5-2 resolved] | unexplained difference | suppress candidate; update plan |
| W6 Firmware packaging | from FIRMWARE-PLAN F2/F3 output: confirm `modem:/image/qca6390/amss20.bin`, `m3.bin`, `bluetooth:/image/htbtfw20.tlv`, `htnv20.bin` exist; run `ath11k-bdencoder` on OTA `bdwlan.*` → `board-2.bin`; decide `firmware-2.bin` presence [I-M5-4]; list encoded board-2 entry names vs expected `bus=pci,qmi-chip-id=...` names [I-M5-7]; extend `firmware.map` with the board-2.bin row (names only) | every row maps to an existing member; board-2 entry-name strategy written down | any member missing, or board-2 entries can't match any plausible runtime name | delete scratch; keep map unchanged |
| W7 Packaging | probe/image builder asserts (hashes, no UFS write allowlist) on the M5 image with the new kernel.config | builder exits 0 | builder refuses | delete images |
| W8 Release | review commits, W1-W7 logs, hashes, open [I]s with coordinator/owner | written approval for one RAM boot | any failed gate | keep M1b state; do not boot |

W4 `fdtget` checks:

```sh
fdtget -t s "$DTB" /soc@0/pcie@1c00000 status
fdtget -t s "$DTB" /soc@0/pcie@1c00000/phy@1c06000 status
fdtget -t s "$DTB" /soc@0/pcie@1c00000/pcie@0/wifi@0 compatible
fdtget -t x "$DTB" /soc@0/pcie@1c00000/pcie@0/wifi@0 reg
fdtget -t s "$DTB" /qca6390-pmu compatible
fdtget -t s "$DTB" /qca6390-pmu/regulators/ldo0 regulator-name   # ldo0..ldo9 present
fdtget -t s "$DTB" /soc@0/serial@998000 status
fdtget -t s "$DTB" /soc@0/serial@998000/bluetooth compatible
fdtget -t s "$DTB" / compatible
fdtget -t s "$DTB" /chosen stdout-path
```

Expected: `okay`/`okay`, wifi `pci17cb,1101` reg `0x10000`, pmu
`qcom,qca6390-pmu` with ldo0-ldo9, uart6 `okay`, bluetooth
`qcom,qca6390-bt`, root compatible `oneplus,instantnoodlep qcom,sm8250`,
stdout still `framebuffer0` (uart6 must NOT become serial0 [V:
DTS-PORT-PLAN I5]).

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` = M5 boot image from W7; `{{SERIAL}}` = pinned
fastboot serial (private, never pasted). Never run a block with a `{{...}}`
in it. For R4 only, `{{SSID}}` and `{{PASSWORD}}` are owner-supplied private
values; never capture or paste them. Captures to `captures/<date>/m5/`
(gitignored).

| # | Step (command block) | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` + slot flags, recorded | one device; `current-slot: b`; flags equal to the M1b B5 capture | flags differ | `fastboot -s {{SERIAL}} reboot`; stock path per M1b |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; then `ssh root@172.16.42.1`, `dmesg \| grep -iE 'ath11k|qca6390|pwrseq|pci 0000:0'`, `lspci -nn \| grep -i 1101`, and read `/sys/firmware/devicetree/base/compatible` | `Booting OKAY`; live root is `oneplus,instantnoodlep` + `qcom,sm8250`; pwrseq-qcom-wcn and pci-pwrctrl probe; `ath11k_pci 0000:01:00.0` probe; `qca6390 hw2.0` line; dmesg "using board name 'bus=pci,qmi-chip-id=…,qmi-board-id=…'"; wlan0 registered | unexpected live root compatible, `FAILED (remote: ...)`, no SSH after 2 min, ath11k probe error, firmware load error | hold Power+VolUp 10-30 s; per NOTES, `fastboot reboot bootloader` before the next `fastboot boot`; slot B boots the old image |
| R2 | over SSH: `ip link show wlan0`, `iw dev wlan0 info`, `iw reg get`; BT: `dmesg \| grep -iE 'qca|bluetooth|htnv|htbtfw'`, `hciconfig hci0` / `btmgmt info` | wlan0 present; `iw reg get` shows a regdomain (world "00" acceptable until R5 [V: reg.c:23-31]); hci0 exists; "QCA ROM Version" line; the matching rampatch/NVM files download without -ENOENT | no wlan0; hci0 absent or ROM_FW flag set (no patch/NVM found [V: hci_qca.c:2054-2064]) | `reboot -f`; old slot-B image boots |
| R3 | over SSH: `cat /sys/firmware/fdt > live.dtb` (or the R3 pattern from M1), diff vs built DTB for the QCA nodes and `/compatible`; confirm the neutral `dtbo_b` image applied and no stock fragments grafted into wifi@0/pmu/bluetooth | QCA nodes and intended root compatible are identical to the built DTB; no unexplained overlay fragments | overlay touched a QCA node/root compatible or a TLMM/SPMI property changed | `reboot -f`; record; fix W5 / return to neutral-DTBO gate |
| R4 | Over SSH: `iw dev wlan0 scan \| head`. **Owner go required for the following `userdata` profile write:** `nmcli device wifi connect "{{SSID}}" password "{{PASSWORD}}" ifname wlan0 name instantnoodlep-m5-test`; then `ip route` and `ping -c3 1.1.1.1`. | scan lists APs; profile activates; DHCP + ping work over wlan0 | scan empty after 60 s, auth fails, profile name already exists, or no owner go for the `userdata` write | `nmcli connection delete instantnoodlep-m5-test`; `reboot -f`; old slot-B image boots |
| R5 | over SSH: `iw reg set <CC>`; `btmgmt info` shows powered; `bluetoothctl scan on` briefly (if bluez present, else defer I-M5-9) | regdomain applies (`iw reg get`); hci0 pairable/scanning | reg set rejected; hci0 wedged | `reboot -f` |
| R6 | boot the installed slot-B system (read-only; no flash writes): reboot normally, then repeat R2/R4/R5 checks on the installed image | same results on the installed system | any difference | record; keep RAM-boot results as the reference |
| R7 | `fastboot -s {{SERIAL}} getvar all` (filtered); compare slot flags to G1 | flags equal; nothing written by any step | any flag changed | stop; record; ask on #808 before further boots |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-M5-1 | Owner's unit has QCA6390 hw2.0 (TCSR major 2) silicon | R1 dmesg hw_rev line [V: pci.c:997-1016 mechanism] |
| I-M5-2 | BT/WLAN enable GPIO numbers and pinctrl drive/pull from C:829-867 are valid for this unit | W5 live-DT compare + R1 runtime (E16 confirms `bt_en_sleep` label exists [V: fixup-labels.txt:14]) |
| I-M5-3 | `ath11k-bdencoder` availability (qca-swiss-army-knife repo; not in L/ tools [V: L/tools listing]) | W6; package from AUR/source at install time only |
| I-M5-4 | Whether a `firmware-2.bin` exists in the OTA/LF for QCA6390 hw2.0, and whether OTA amss20.bin == LF amss.bin | W6 + FIRMWARE-PLAN F5; driver prefers embedded IEs [V: fw.c:145-162, mhi.c:343-353, qmi.c:2514-2545] |
| I-M5-6 | Standalone `qca639x` power-domain node (C:254-272) is unneeded — no consumer binds | W4 (absent from our DTB) + R1 (no -EPROBE_DEFER on PMU consumers); DTS-PORT-PLAN I13 |
| I-M5-7 | Runtime board name (`qmi-chip-id`/`qmi-board-id`) and whether the encoded board-2.bin entry matches it; whether to set `qcom,calibration-variant` | R1 dmesg board-name line vs W6 entry list |
| I-M5-8 | Owner's QCA6390 ROM version and corresponding firmware variant. Public instantnoodlep testing reports ROM 0x0200 and `ht*20` files [V: <https://gitlab.com/sm8250-mainline/linux/-/merge_requests/8>, test log]; that is not a substitute for the owner's R2 check. | R2 dmesg "QCA ROM Version"; remap firmware.map row if needed |
| I-M5-9 | bluez present in the phone rootfs via Omarchy's own package set | R2/R5 (`bluetoothctl` exists?); else device package adds bluez |
| I-M5-10 | `wlan_mem` 1 MiB @0x8e100000 is sufficient (FIXED_MEM_RGN path [V: pci.c:974-977, mhi.c:313-330]) | R1 ath11k QMI mem allocation success |

## 9. Definition of done for M5 (Wi-Fi/BT half)

W0-W8 pass; G1, R1-R7 pass with pasted (redacted) output; wlan0 scans and
associates with a working route; hci0 comes up with the OTA rampatch+NVM;
regulatory country set; slot flags unchanged; results appended to NOTES.md
with dates. Kernel commit 2 exists in a linux-omarchy-mobile branch with
W1-W7 rerun. Firmware lives only as firmware.map rows + files extracted
from the owner's OTA at install time; nothing firmware-like is committed.
