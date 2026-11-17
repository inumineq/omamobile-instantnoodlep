<!-- SPDX-License-Identifier: MIT -->
# WIFI-BT-M5-PLAN: Wi-Fi (QCA6390/PCIe) + Bluetooth (QCA6390/UART6) on instantnoodlep

House-rule-6 gate for the Wi-Fi + Bluetooth half of milestone **M5**.
Refreshed 2026-11-17 (afternoon) for K3 on `boot_b`; the first version
(branch `m5-plans`, same day) predates K3, the parked neutral dtbo and any
build.

- State today: kernel commits written and built on the Mac, nothing run on
  the phone. Kernel branch `instantnoodlep-k3-wifi` = combo K3 + two DTS
  commits (§6). Artefacts in `~/orca/build-out/k3-wifi/` on macbookpro, not
  in git (§6.3). Next step: the coordinator's RAM boot, §7.
- Reading order: `AGENTS.md`, `docs/agents/state.md`, this file,
  `FIRMWARE-PLAN.md` + `firmware.map`, `M5-REVIEW.md` (Wi-Fi rows).
- Scope: ath11k over PCIe0 (`pci17cb,1101`), the `qcom,qca6390-pmu` power
  sequencer, hci_qca over UART6, firmware, MAC addresses, the Arch
  userspace that drives them. Phone steps are `fastboot boot` (RAM) only;
  no partition is written by this plan. A `boot_b` flash of the result is
  a separate owner-gated ticket (M1b B2/B5 pattern).

## 1. Source pins

- `K/` = `~/src/l-k3`, branch `instantnoodlep-k3-combo` @ `aa996bae0695`,
  the kernel on `boot_b` (`7.3.0-rc6-instantnoodlep-k3-gaa996bae0695`)
  [V: NOTES 2026-11-17 midday]. Mainline v7.3-rc6 base plus the K2/K3 board
  commits and the test-only kona patch. All `K/` line refs below were read
  in this tree on 2026-11-17.
- `W/` = `instantnoodlep-k3-wifi`, `K/` + the two commits of §6.
- `C/` = community tree gitlab.nura.eco/soc/qualcomm-sm8250/linux tag
  `7.2.0-dev`, file `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`,
  fetched 2026-11-17 (the earlier review could not reach it; today it served
  the raw file). Facts only; values cross-checked against mainline elish.
- `E/` = `K/arch/arm64/boot/dts/qcom/sm8250-xiaomi-elish-common.dtsi`, the
  mainline SM8250 board with the same QCA6390 wiring.
- `P/` = pmaports `master`, `device/testing/firmware-oneplus-instantnoodlep/APKBUILD`
  and the firmware tree it pins (github.com/pangwalla/oneplus-instantnoodlep-firmware
  @ `2dce2681`), read 2026-11-17.
- `LF/` = linux-firmware `main` (git.kernel.org), `WHENCE` and
  `ath11k/QCA6390/hw2.0/`, read 2026-11-17.

## 2. What changed since the first version

| Topic | Then | Now |
| --- | --- | --- |
| Neutral `dtbo_b` | Prerequisite for the RAM boot | Parked: ABL rejected both images [V: learning `l-48e0c482`]. Not needed here: every Wi-Fi/BT driver matches a device compatible (`qcom,qca6390-pmu`, `pci17cb,1101`, `qcom,qca6390-bt`), never the root [V: K/drivers/power/sequencing/pwrseq-qcom-wcn.c:566-569; K/drivers/pci/pwrctrl/pci-pwrctrl-pwrseq.c:112; K/drivers/bluetooth/hci_qca.c:2784]. The QCA set boots under the stock dtbo like the GPU did |
| pd-mapper / `qcom,kona` | Not covered | Not involved. ath11k on PCIe talks QMI over QRTR-on-MHI to the chip itself; no remoteproc, no PDR, no pd-mapper [V: K/drivers/net/wireless/ath/ath11k/Kconfig:17-24 selects MHI_BUS, QRTR, QRTR_MHI; the in-kernel QRTR name service needs no userspace]. hci_qca is a serdev driver. The combo kona patch neither helps nor hurts |
| Kernel config | Additions listed | Nothing to add: combo `.config` already has every symbol as `=m` (ATH11K, ATH11K_PCI, MHI_BUS, QRTR_MHI, PCI_PWRCTRL_PWRSEQ, POWER_SEQUENCING_QCOM_WCN, PHY_QCOM_QMP_PCIE, BT, BT_HCIUART, BT_HCIUART_QCA, BT_QCA) and SERIAL_DEV_BUS, SERIAL_QCOM_GENI, PCIE_QCOM `=y` [V: `~/src/l-k3/combo.config`]. `kernel.config` now pins them (§6.2) |
| `memory-region = <&wlan_mem>` on wifi@0 | Planned | **Dropped.** With it ath11k switches to its fixed-memory mode [V: K/drivers/net/wireless/ath/ath11k/pci.c:980-981]: firmware memory must come from that region (1 MiB here, while QCA6390 firmware asks for about 4 MiB [V: qmi.c:1886-1890 comment]; size check fails, qmi.c:2054-2059), MHI takes its IOVA window from DT [V: mhi.c:372-374], and board data goes to the fixed physical `bdf_addr` 0x4B0C0000 [V: qmi.c:2073-2075; core.c:227]. The schema also rejects the property [V: `CHECK_DTBS` run, §6.3]. Neither C nor E sets it. `wlan_mem` stays reserved, unused |
| Board data | Encode the OTA `bdwlan.*`, name unknown | P encodes the phone's `bdwlan.elf` under one name, `bus=pci,qmi-chip-id=0,qmi-board-id=255` [V: P/wlan/board-2.json]. LF `board-2.bin` carries the same generic name (plus `qmi-board-id=4` and two Xiaomi variants) [V: LF board-2.bin, strings]. §4 |
| QUP7 pin-state disables | Port them with the QCA commit | Dropped. C sets `status = "disabled"` on `qup_i2c7_default`/`qup_spi7_data_clk` because they name GPIO 20/21 [V: C:970-976; K/sm8250.dtsi:5352-5357, 5565-5569]; in mainline a pin state is only claimed by a node that references it, and `i2c7`/`spi7` stay disabled. Nothing to undo |

## 3. Hardware and DT description (W/ as built)

| Piece | Value in W/ | Evidence |
| --- | --- | --- |
| PMU node `/qca6390-pmu` | `qcom,qca6390-pmu`; vddaon=s6a, vddpmu=s2f, vddrfa0p95=s2f, vddrfa1p3=s8c, vddrfa1p9=s5a, vddpcie1p3=s8c, vddpcie1p9=s5a, vddio=s4a (fixed 1.8 V); ldo0-ldo9 | [V: C:83-142]. **E differs**: it feeds vddpmu/vddrfa0p95 from s6a [V: E:105-125]. W/ follows C, the board's own tree; the stock overlay's fixups name `pm8009_s2` [V: DTS-PORT-PLAN §2.2 PM8009 row], which fits C. Still [I-M5-15] until R2a |
| Enable GPIOs | `wlan-enable-gpios` TLMM 20, `bt-enable-gpios` TLMM 21, both active high; pin states drive 16 mA, output low, pull-up | [V: C:98-99, 829-858; E:120-121, 928-963]. Same numbers in C and E; the unit check is §7 R2 [I-M5-2] |
| PM8009 s2f | `#include "pm8009.dtsi"`, `regulators-0` `qcom,pm8009-1-rpmh-regulators` pmic-id `f`, smps2 900-952 mV, AUTO | [V: C:284-298]. C uses the `-1` variant, E the plain one; `-1` is taken from the board's own tree [I-M5-11] |
| PCIe0 | `&pcie0` okay; `&pcie0_phy` okay, vdda-phy=l5a, vdda-pll=l9a; perst TLMM 79, wake TLMM 81 from the SoC dtsi | [V: C:681-689; E:809-817; K/sm8250.dtsi:2213-2214] |
| `wifi@0` | under `&pcieport0`: `pci17cb,1101`, reg `0x10000 0 0 0 0`, nine PMU supplies, no `memory-region` | [V: C:692-706; E:819-835; binding qcom,ath11k-pci.yaml] |
| UART6 + BT | `&qupv3_id_0` okay, `&uart6` okay (gpio16-19 qup6 from the dtsi), child `bluetooth` `qcom,qca6390-bt` with six PMU supplies; no `serial0` alias (DTS-PORT-PLAN I5 keeps `uart6` off `serial0`; the GENI driver allocates a free line without one [V: K/drivers/tty/serial/qcom_geni_serial.c:1897-1902, 292-295]) | [V: C:955-968; E:966-979; K/sm8250.dtsi:1708-1723] |
| Power flow | pci-pwrctrl-pwrseq binds the `wifi@0` node, gets pwrseq target `wlan`, powers the chip, rescans the bus [V: pci-pwrctrl-pwrseq.c:37-52,112]; hci_qca for a DT QCA6390 takes power only from pwrseq target `bluetooth` and fails probe without it [V: hci_qca.c:2519-2525] | |
| Reserved memory | `wlan_mem` 0x8e100000 1 MiB stays reserved (stock layout), unreferenced | [V: W/ dts reserved-memory] |
| `__symbols__` | The built DTB has none, so stock dtbo fragments that target labels cannot resolve against it [V: `fdtget -p ... /__symbols__` fails on the built DTB]. What ABL does instead stays [I]; R3 compares live vs built | |

## 4. Firmware

Driver requests, in order [V: K/drivers/net/wireless/ath/ath11k/core.c:222-231
(dir `QCA6390/hw2.0`), fw.c:145-162 (`firmware-2.bin` first), mhi.c:343-353
(`amss.bin`), qmi.c:2514-2545 (`m3.bin`), core.c:1830-1912 (`board-2.bin`,
then `board.bin`); K/drivers/bluetooth/btqca.c:793,886 (`qca/htbtfw%02x.tlv`,
`qca/htnv%02x.bin`)]:

| File under `/lib/firmware` | LF (redistributable) | Owner OTA (firmware.map) | P (public port) | Use for the first RAM boot |
| --- | --- | --- | --- | --- |
| `ath11k/QCA6390/hw2.0/amss.bin` | yes, `WLAN.HST.1.0.1-05266` [V: LF WHENCE] | `modem:/image/qca6390/amss20.bin` [V: firmware.map] | own copy | either; the OTA copy matches the phone's stock stack. Compare hashes at install [I-M5-4] |
| `ath11k/QCA6390/hw2.0/m3.bin` | yes | `modem:/image/qca6390/m3.bin` | own copy | same as amss |
| `ath11k/QCA6390/hw2.0/firmware-2.bin` | no | no row | no | absent; ath11k falls back to amss/m3 [V: fw.c:145-162] |
| `ath11k/QCA6390/hw2.0/board-2.bin` | yes, generic `qmi-board-id=255` entry | no row yet: encode the OTA `bdwlan.elf` | `ath11k-bdencoder -c board-2.json`, name `bus=pci,qmi-chip-id=0,qmi-board-id=255` [V: P] | **the OTA `bdwlan.elf` encoded as P does** (calibrated for this phone's antennas); LF's generic entry is the fallback if encoding fails. The OTA member path of `bdwlan.elf` is [I-M5-12]; FIRMWARE-PLAN F2's names-only listing settles it, then add the row |
| `qca/htbtfw20.tlv` | yes, `BTFM.HST.2.0.0-00943` [V: LF WHENCE] | `bluetooth:/image/htbtfw20.tlv` | own copy | either |
| `qca/htnv20.bin` | yes | `bluetooth:/image/htnv20.bin` | own copy | OTA preferred (board NVM); LF as fallback |

Rules: nothing above enters git (AGENTS.md rule 8); `wlan_mac.bin` is never
mapped. The rootfs carries `linux-firmware-other` only [V: NOTES 2026-11-17
early morning], so the files are copied in by hand for the RAM boot (§7 P2)
and later through the device package's install-time extraction (FIRMWARE-PLAN).

Regulatory: QCA6390 has no regdb in board data (`supports_regdb=false`) and
supports current-country reporting [V: core.c:274,282]; `wireless-regdb` is
in the rootfs; country via `iw reg set` or NetworkManager.

## 5. MAC addresses (never in git, never in a commit, issue or capture name)

- **Wi-Fi.** ath11k takes the per-radio MAC from firmware when valid, else
  `local-mac-address`/`mac-address` on the `wifi@0` node, else the
  firmware's base MAC [V: K/drivers/net/wireless/ath/ath11k/mac.c:10724-10736].
  On Android, `wlan_mac.bin` in vendor carries the unit's address; mainline
  does not read it. Whether firmware reports the unit MAC or a QCA default is
  [I-M5-13], read at R2 by comparing the OUI only (00:03:7f is the QCA
  default). If it is a default: leave the DTS alone (no MAC in the DTS) and
  let NetworkManager use `wifi.cloned-mac-address=stable` (per-connection,
  stable and private), or a systemd `.link` file on the phone written from
  the owner's own `wlan_mac.bin`. Either lives on the phone only.
- **Bluetooth.** btqca compares the controller's address with the one in
  the NVM file; if they match it sets `HCI_QUIRK_USE_BDADDR_PROPERTY`
  [V: K/drivers/bluetooth/btqca.c:683-710, 995], so without a DT
  `local-bd-address` (ABL fills none for us [I]) hci0 shows up
  **unconfigured**. Fix on the phone: `btmgmt --index 0 public-addr <addr>`
  with the owner's own address (from the stock system), or a locally
  administered random one; never written to git.

## 6. Kernel side

### 6.1 Commits on `instantnoodlep-k3-wifi` (GPL-2.0, `Assisted-by`)

| # | Subject | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: instantnoodlep: Add PM8009` | include `pm8009.dtsi`; `regulators-0` with s2f only |
| 2 | `arm64: dts: qcom: instantnoodlep: Enable Wi-Fi and Bluetooth` | PMU node + ldo0-ldo9 + enable GPIOs and pin states; `&pcie0`/`&pcie0_phy` okay; `wifi@0`; `&qupv3_id_0`/`&uart6` okay + `bluetooth` |

Order in the series for upstream: these sit on the clean tree too (no
dependency on the kona patch). `Signed-off-by` is the owner's to add before
anything is sent.

Note on `pm8009.dtsi`: it also adds `pm8009_pon` (`qcom,pm8916-pon`)
without `mode-*` properties. With `POWER_RESET_QCOM_PON=y` it probes and
registers an empty reboot-mode, which writes nothing [I: by reading
`drivers/power/reset/reboot-mode.c`]. R5 checks that
`reboot --reboot-argument=bootloader` still reaches fastboot.

### 6.2 Config

No change to the `.config` the build uses: combo already has all of it.
`device/instantnoodlep/kernel.config` gains a Wi-Fi/BT section that pins
those symbols (modules, nothing boot-critical; `PCIE_QCOM` and
`SERIAL_QCOM_GENI` stay built in).

### 6.3 Build (macbookpro, done 2026-11-17)

Linux arm64 container (Debian trixie, LLVM 23.1.6 from apt.llvm.org, the
laptop has 23.1.3) on a named Docker volume, `LLVM=1 ARCH=arm64`,
`combo.config` + `olddefconfig`: the resolved `.config` differs from combo
only in toolchain version strings (`CC_VERSION_TEXT`, `*_VERSION`,
`CC_CAN_LINK`). Outputs in `~/orca/build-out/k3-wifi/` with `SHA256SUMS`
(see that file for release string and hashes). Offline gates:

| Gate | Result |
| --- | --- |
| W1/W3 schema | `make CHECK_DTBS=y qcom/sm8250-oneplus-instantnoodlep.dtb`: clean after dropping `memory-region` |
| W2 build | `Image.gz`, `dtbs`, `modules`: exit 0 |
| W4 nodes | `fdtget` on the built DTB: pcie@1c00000 `okay`, phy@1c06000 `okay`, wifi@0 `pci17cb,1101` reg `10000 0 0 0 0`, `/qca6390-pmu` ldo0-ldo9, serial@998000 `okay` with `bluetooth` `qcom,qca6390-bt`, root `oneplus,instantnoodlep qcom,sm8250`, stdout `framebuffer0` |
| W5 live-DT compare | Coordinator, at R3 (needs the phone) |

## 7. RAM-boot runbook (coordinator on omabook; owner gates writes)

Nothing below writes a partition. The rootfs file writes (P1, P2) go to
the Arch file system on `userdata` the way the K3 module install did; they
add files and are removed by their rollback. Captures go to
`captures/<date>/m5-wifi/` (gitignored); no MAC, serial or SSID in any
pasted output (mask the last three octets).

Placeholders: `{{REL}}` = the release string in
`~/orca/build-out/k3-wifi/SHA256SUMS`; `{{IMG}}` = the boot image the
coordinator builds from `Image.gz` + the dtb with the same builder flags,
cmdline and ramdisk as `boot-r3-gpu.img`. Never run a block that still has
a `{{...}}` in it.

### 7.1 Prepare (laptop and rootfs; phone on combo K3 from `boot_b`)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P0 | On the laptop: `sha256sum -c SHA256SUMS` in the copied `k3-wifi/` dir; build `{{IMG}}`; `unpack_bootimg` it and check kernel and dtb match the files | all OK; header and cmdline equal to `boot-r3-gpu.img` except the kernel/dtb | any mismatch | delete `{{IMG}}` |
| P1 | Modules: `scp modules-{{REL}}.tar.gz root@172.16.42.1:/tmp/`; on the phone `test ! -e /usr/lib/modules/{{REL}} && tar -C /usr --keep-old-files -xzf /tmp/modules-{{REL}}.tar.gz` (the tarball holds only `lib/modules/{{REL}}/`), then `depmod {{REL}}` | `/usr/lib/modules/{{REL}}/` exists next to the combo release dir, which is untouched | the target dir already exists, or anything outside it would change | `rm -rf /usr/lib/modules/{{REL}}` |
| P2 | Firmware: copy the six files of §4 to the phone (`/usr/lib/firmware/ath11k/QCA6390/hw2.0/`, `/usr/lib/firmware/qca/`), OTA-derived where available, LF otherwise; record which source and sha256 of each (hashes only, private capture) | files present, mode 0644 | a file would overwrite one owned by a package (`pacman -Qo` on each path first) | remove exactly those files |
| P3 | Userspace check: `pacman -Q networkmanager wireless-regdb iw bluez bluez-utils 2>&1` | NM, wireless-regdb present; note iw/bluez | — | — (read only) |

If bluez or iw is missing [I-M5-9], install them over the SOCKS tunnel
(`pacman -S` with `ALL_PROXY=socks5h://127.0.0.1:1080`, clock set first,
learning `l-5c5f509d`) as a separate owner go, or run R2 with `btmgmt`
from a copied static build; it is not needed for the Wi-Fi checks.

### 7.2 Boot and checks

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot getvar current-slot`, `slot-successful:b`, `slot-unbootable:b`, `slot-retry-count:b` (from the bootloader, reached by `systemctl reboot --reboot-argument=bootloader`) | `b`, `yes`, `no`, value recorded | anything else | `fastboot reboot` (combo K3 from `boot_b`) |
| R1 | `fastboot boot {{IMG}}`; SSH at 172.16.42.1 within 2 min; `uname -r`; `systemctl is-system-running` | `Booting OKAY`; `{{REL}}`; `running` (or `degraded` only for units unrelated to Wi-Fi/BT) | `FAILED (remote: ...)`, no SSH after 2 min | hold Power+VolUp to reboot; `boot_b` (combo K3) comes up; per NOTES go via `reboot bootloader` before another `fastboot boot` |
| R2a power | `dmesg \| grep -iE 'pwrseq\|qca6390\|pcie\|1c00000\|ath11k\|mhi\|qmi'`; `lsmod \| grep -E 'pwrseq_qcom_wcn\|pci_pwrctrl_pwrseq\|ath11k\|hci_uart\|btqca'`; `lspci -nn` | modules loaded by udev; `qcom-pcie 1c00000.pcie: PCIe Gen.N x1 link up` [V: format K/drivers/pci/controller/dwc/pcie-designware.c:812]; `lspci` shows `17cb:1101` at `0000:01:00.0` | no link up (C's s2f choice for vddpmu is the first suspect, I-M5-15), or pwrseq/pwrctrl probe error, or `-EPROBE_DEFER` that never clears (`cat /sys/kernel/debug/devices_deferred`) | `reboot` (back to `boot_b`) |
| R2b ath11k | `dmesg \| grep ath11k` | `ath11k_pci 0000:01:00.0: chip_id 0x0 chip_family ... board_id 0xff soc_id ...` [V: format qmi.c:2276; values from P's board name, I-M5-7]; `fw_version ...`; no `failed to fetch board data`; then `ip link show wlan0` exists | `failed to fetch board data for bus=...` (note the name it prints, it is the answer to [I-M5-7]), MHI/QMI timeout, firmware -2 | `reboot`; fix §4 files |
| R2c MAC | `ip -br link show wlan0`, report the OUI only | OUI recorded for [I-M5-13] | — | — |
| R3 live DT | `cp /sys/firmware/fdt /tmp/live.dtb`, pull it, `dtc -I dtb -O dts` both live and built, diff the `/qca6390-pmu`, `pcie@1c00000`, `phy@1c06000`, `serial@998000`, `&tlmm` wlan/bt states | QCA nodes identical; other diffs only the known kona root rewrite | a stock fragment changed a QCA node or GPIO 20/21 | record; `reboot` |
| R4 scan | `iw reg get`; `nmcli radio wifi on`; `nmcli device wifi rescan; nmcli device wifi list` | regdomain shown (world `00` acceptable); access points listed | empty list after 60 s | `reboot` |
| R5 connect (owner go: writes an NM profile to the rootfs) | `nmcli device wifi connect "{{SSID}}" password "{{PASSWORD}}" ifname wlan0 name m5-wifi-test`; `ip route`; `ping -c3 -I wlan0 1.1.1.1`; `timedatectl set-ntp true` and `timedatectl` | DHCP lease, ping replies, NTP syncs (first real network on the phone, no SOCKS) | auth fails, no lease | `nmcli connection delete m5-wifi-test` |
| R6 BT | `dmesg \| grep -iE 'bluetooth\|hci0\|qca'`; `btmgmt info`; if `unconfigured`, §5 `public-addr`; then `bluetoothctl power on`, `bluetoothctl --timeout 15 scan on` | `QCA ROM Version  :0x00000200` [V: format btqca.c:74; ROM 0x0200 per public log, I-M5-8]; `htbtfw20.tlv` and `htnv20.bin` download, `QCA setup on UART is completed` [V: btqca.c:999]; devices found | ROM version other than 0x200 (other file names), `-ENOENT` on a firmware file, hci0 timeout | `reboot` |
| R7 exit | `systemctl reboot --reboot-argument=bootloader`; G1 reads again; `fastboot reboot` | fastboot reached (checks the PM8009 PON note in §6.1); slot vars equal to G1; combo K3 boots from `boot_b` | slot vars changed | stop, record, ask the owner |

After R7 the phone runs the flashed combo K3 again; the added modules
directory and firmware files stay on the rootfs (harmless for combo, needed
for the next RAM boot). Remove them with the P1/P2 rollbacks if wanted.

## 8. Open items

| ID | Open | Resolves at |
| --- | --- | --- |
| I-M5-1 | Unit silicon is QCA6390 hw2.0 | R2b (`chip_family`, firmware dir accepted) |
| I-M5-2 | TLMM 20/21 are WLAN/BT enable on this unit (C and E agree) | R2a/R6 |
| I-M5-4 | OTA `amss20.bin`/`m3.bin` vs LF copies | P2 hash comparison |
| I-M5-7 | Runtime board name = `bus=pci,qmi-chip-id=0,qmi-board-id=255` (P's choice) | R2b: `board_id 0xff` in the info line, no fetch error |
| I-M5-8 | BT ROM 0x0200 → `ht*20` files | R6 |
| I-M5-9 | bluez/iw on the rootfs | P3 |
| I-M5-11 | PM8009 variant (`-1` per C) is right for s2f | R2a: regulator `vreg_s2f_0p95` enables without error |
| I-M5-12 | OTA member path of `bdwlan.elf` | FIRMWARE-PLAN F2 listing |
| I-M5-13 | Wi-Fi MAC from firmware is the unit's or a QCA default | R2c |
| I-M5-14 | ABL's stock dtbo leaves the QCA nodes alone (no `__symbols__` in our DTB) | R3 |
| I-M5-15 | vddpmu/vddrfa0p95 on PM8009 s2f (C) rather than s6a (E) | R2a: PCIe link up; else try s6a in a test build |

Dropped since the first version: I-M5-3 (bdencoder: P shows the method),
I-M5-5 (binding path settled in M5-REVIEW), I-M5-6 (`qca639x` node: not
carried; nothing consumes it), I-M5-10 (`wlan_mem` is not used, §2).

## 9. Done when

R1-R7 pass with redacted output in NOTES.md; wlan0 associates and routes;
hci0 scans with firmware loaded; slot vars unchanged. Then: a `boot_b`
flash ticket for this kernel, the firmware rows (board-2 from `bdwlan.elf`)
in `firmware.map` and the device package, and an upstream proposal of the
two DTS commits on the clean tree.
