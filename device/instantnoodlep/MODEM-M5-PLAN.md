<!-- SPDX-License-Identifier: MIT -->
# MODEM-M5-PLAN: Snapdragon X55 (SDX55) over PCIe/MHI on instantnoodlep

House-rule-6 gate for the **modem** subsystem of milestone **M5** of the
wayfinder map ("wayfinder:map — Omarchy Mobile port for instantnoodlep
(OnePlus 8 Pro IN2023), M1-M5"; M5 = Wi-Fi, mobile data/SMS, sensors,
cameras [V: FIRMWARE-PLAN.md:13-19]). This file is a plan only. No code,
DTS, config or firmware is touched before this plan exists with its gated
runbook (AGENTS.md rule 6).

- Date: 2026-11-18. Branch: `m5-plans` (this document only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md` + `firmware.map`,
  `device/instantnoodlep/DISPLAY-M3-PLAN.md` (template), `NOTES.md`.
- Scope: the external SDX55 modem on PCIe (MHI `pci_generic`, **not** the
  q6v5 mss loader), its firmware set, MHI/WWAN channels, ModemManager, SIM,
  SMS and mobile data. Voice calls are out of scope — see §5.3.
- Safety model unchanged: no write to `super` or any `_a` partition; flash
  writes only to slot-B boot images and `userdata`, each behind an owner go
  (AGENTS.md rule 3). M5 phone steps are `fastboot boot` (RAM) first; the
  installed slot-B system is only booted, never written. Firmware comes from
  the owner's own OTA at install time, names only, never from git
  (AGENTS.md rule 8). Never touch `modem*`, `efs*`, `persist`, `fsg`, `fsc`
  partitions (already backed up read-only at stage-0 D4 [V: NOTES.md
  2026-11-16 stage-0 entry]).

- New prerequisite: install the neutral DTBO on `dtbo_b` under a separate
  owner-gated slot-B write plan before RAM boot. The stock overlay rewrites
  the live root compatible to `qcom,kona-mtp`, `qcom,kona`, `qcom,mtp`
  [V: NOTES.md 2026-11-17 entry]. This PCI-ID-bound MHI path does not rely on
  `qcom_pd_mapper` or a root-machine match [V: L/drivers/bus/mhi/host/pci_generic.c,
  PCI-ID table and probe], but this plan still requires the neutral DTBO for
  a clean live DT and stable device identity. Nura's package builds and
  installs an empty DTBO for this device [V: <https://gitlab.com/postmarketOS/pmaports/-/raw/master/device/testing/device-oneplus-instantnoodlep/APKBUILD>, `kernel_mainline()`].

## 1. Source pins

- `L/` = `/home/inumineq/src/l`, branch `instantnoodlep-k2` @
  `a28aaf1a09db8889ed156212286e942e411dbe93` (Linux 7.3.0-rc6 +
  linux-omarchy-mobile `317d87dc2db0` + the four K2 DTS commits)
  [V: NOTES.md 2026-11-16 night, "R7, K2 passes R1-R5"]. Line references
  below are valid at this commit.
- `C/` = community SM8250 kernel,
  `gitlab.nura.eco/soc/qualcomm-sm8250/linux` tag `7.2.0-dev` @
  `3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9`, as pinned in DTS-PORT-PLAN §1.
- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (FIRMWARE-PLAN pin); local clone `/home/inumineq/src/omarchy-mobile`.
- `E/` = decompiled stock **dtbo entry 16** ("kona MTP 19811"),
  `/home/inumineq/android/build/p3/entry16.dts` (15,974 lines), from the
  verified `IN2023_13.1.0.591(EX01)` OTA [V: NOTES.md stage-0 R4/P3].
- `B/` = stock **base boot DTB 3** ("kona v2.1 SoC 19811",
  `qcom,msm-id = <0x164 0x20001>`), binary at
  `/home/inumineq/android/reference/instantnoodlep/images/boot-dtbs/dtb.3`
  [V: `.../images/boot-dtb-ids.txt:4`].
- `FW/` = `device/instantnoodlep/firmware.map` (DRAFT, names only).
- `D/` = github.com/darknagel/oneplus-instantnoodlep-nura-unofficial: its
  Nura image reports modem/SIM/data/SMS working and VoLTE **not** verified
  on an IN2023 EU unit [V: NOTES.md 2026-11-15 entry].

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| SoC | Qualcomm SM8250 (`soc_id` 356, rev 2.1) | [V: NOTES.md 2026-11-16 A6 socinfo] |
| Modem | Snapdragon X55 (SDX55), external chip on PCIe; host-side loader is MHI `pci_generic`, not `qcom_q6v5_mss` | [V: docs/research/firmware-extraction.md coordinator review item 2] |
| Modem PCI ID | `17cb:0306`; catch-all `{ PCI_DEVICE(PCI_VENDOR_ID_QCOM, 0x0306) }` → `mhi_qcom_sdx55_info` | [V: L/include/linux/pci_ids.h:2420 `PCI_VENDOR_ID_QCOM 0x17cb`; L/drivers/bus/mhi/host/pci_generic.c:988-989] |
| PCIe port | **pcie2** on generic SM8250: its ref clock is `GCC_PCIE_MDM_CLKREF_EN`, its PHY is `qcom,sm8250-qmp-modem-pcie-phy`, its pinctrl is perst/clkreq/wake | [V: L/arch/arm64/boot/dts/qcom/sm8250.dtsi:2439, :2486, :5877-5896]. pcie0 = Wi-Fi (`GCC_PCIE_WIFI_CLKREF_EN`, perst tlmm 79 [V: :2213-2214]; community puts `pci17cb,1101` wifi@0 on pcie0 [V: DTS-PORT-PLAN §2.3 C:681-706]); pcie1 = wigig (`GCC_PCIE_WIGIG_CLKREF_EN`, perst tlmm 82 [V: :2340-2341]; stock enables a wil6210 node [V: E/ fragment@79, L12076-12084]). Which port this unit wires the SDX55 to: [I-M5-1], resolved at O2 (decompile `B/dtb.3`) and R1 (`lspci`) |
| PERST#/wake GPIOs (modem port) | `perst-gpios = <&tlmm 85 GPIO_ACTIVE_LOW>`, `wake-gpios = <&tlmm 87 GPIO_ACTIVE_HIGH>`; pinctrl `pcie2_default_state`: perst gpio85, clkreq gpio86 (function `pci_e2`), wake gpio87 | [V: L/ sm8250.dtsi:2466-2467 and :5877-5896]. Driver parses legacy `perst-gpios` [V: L/drivers/pci/controller/dwc/pcie-qcom.c:2071-2077] and the optional `"mhi"` reg region [V: :2221-2228]. Validity for this unit vs stock: [I-M5-1] (E/ carries **no** pcie/perst pinctrl at all — see below) |
| Stock overlay vs modem | dtbo entry 16 contains **no** pcie/modem/mss/ipa node, no perst/clkreq pinctrl, no modem rail, no reserved-memory fragment: `__symbols__`/`__fixups__` have no `pcie*`/`modem`/`mss`/`sdx55` target | [V: E/ full-file scan; `__symbols__` L14237-14658, `__fixups__` L14660-14813]. Only modem token: `qcom,modem-reset;` on the pmxprairie PON node [V: E/ fragment@7, ≈L2259]. So the overlay cannot contaminate a new pcie2 node, and modem wiring facts must come from `B/dtb.3` + mainline [I-M5-1] |
| Modem power beyond PERST/rails | Any extra modem power-en GPIO/rail lives in the base DTB, not in E/ | [I-M5-8], resolved at O2 (`B/dtb.3`) and R1 (dmesg) |

## 3. Inventory per block

"K2 today" is the booted slot-B kernel: the K2 board DTS references no
`&pcie*`, `&ipa` or MHI node at all [V: L/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts, full read (386 lines); all pcie nodes stay `status = "disabled"` [V: L/ sm8250.dtsi:2220, :2347, :2473]].

| Block | Mainline status | Driver + binding | K2 today | Missing for M5 |
| --- | --- | --- | --- | --- |
| PCIe2 host @ `0x1c10000` | present, generic, disabled [V: sm8250.dtsi:2388-2483] | `qcom,pcie-sm8250`; `drivers/pci/controller/dwc/pcie-qcom.c` (match table, scanned :2470-2499); binding `qcom,pcie-sm8250.yaml`; `CONFIG_PCIE_QCOM=y` [V: L/arch/arm64/configs/defconfig:245]; clocks/resets/GDSC/iommu-map all in the generic node [V: :2433-2461] | not referenced | enable `&pcie2`; check `&apps_smmu` (iommu-map `0x1d00/0x1d01` [V: :2455-2456]) [I-M5-7] |
| PCIe2 PHY @ `0x1c16000` | present, generic, disabled [V: sm8250.dtsi:2485-2512] | `qcom,sm8250-qmp-modem-pcie-phy`; `drivers/phy/qualcomm/phy-qcom-qmp-pcie.c` match (scanned :6460-6461); `CONFIG_PHY_QCOM_QMP=m` [V: defconfig:1780, full-file scan] | not referenced | enable `&pcie2_phy` + PHY supplies from C:718-726 [V: DTS-PORT-PLAN §2.3 row "&pcie2 + &pcie2_phy, C:718-726"]; rail names [I-M5-2] |
| MHI over PCIe (`pci_generic`) | present; `CONFIG_MHI_BUS_PCI_GENERIC=m` [V: defconfig:262] | `L/drivers/bus/mhi/host/pci_generic.c`: `mhi_qcom_sdx55_info` :405-415 — `.fw = "qcom/sdx55m/sbl1.mbn"` :407, `.edl = "qcom/sdx55m/edl.mbn"` :408, `.edl_trigger = true` :409, config `modem_qcom_v1_mhiv_config` :410, mru 32768 :413; pure PCI-ID driver, no DT node/of_match [V: id table :988-989; no `qcom,sdx55` compatible exists — full-file scan] | module only; no DT needed | pin `=y` in `device/instantnoodlep/kernel.config`; no DTS node for the modem itself |
| MHI channels (SDX55) | present | `modem_qcom_v1_mhi_channels[]` :314-329 — DIAG 4/5, MBIM 12/13, QMI 14/15, IPCR 20/21, FIREHOSE 34/35, IP_SW0 46/47, **IP_HW0 100/101**; events :331-342; controller config :363-370; probe powers up explicitly at probe [V: mhi_pci_probe :1443-1450, scanned] | n/a | none — hardcoded |
| Firmware load | present | `drivers/bus/mhi/host/boot.c`: uses `edl_image` only in MHI EDL state and otherwise `fw_image` [V: scanned :499-500]; requests the descriptor's SBL path [V: scanned :522]; EDL also via `trigger_edl` sysfs [V: L/drivers/bus/mhi/host/init.c:129-149] | no firmware on rootfs yet | `FW/` name-only rows (see §4); EDL row is present but OTA member existence remains a gate |
| Control channels (QMI/MBIM/AT/DIAG) | present; `CONFIG_WWAN=m`, `CONFIG_MHI_WWAN_CTRL=m` [V: defconfig:520-521] | `mhi_wwan_ctrl.c` match table :256-265: DUN/DUN2→AT, MBIM→MBIM, QMI→**WWAN_PORT_QMI**, DIAG→QCDM, FIREHOSE, NMEA; creates wwan ports :237-238. QMI is exposed as a WWAN control port, **not** via qrtr [V: full-file scan]. Optional qrtr-mhi binds channel IPCR [V: L/net/qrtr/mhi.c:158-162]; not needed for QMI control/SMS in this plan. | module | pin `=y`; QMI/MBIM control node paths remain [I] until R2 |
| Data channel | present; `CONFIG_MHI_NET=m` [V: defconfig:350]; `CONFIG_MHI_WWAN_MBIM=m` [V: :522] | `mhi_net.c` id table :389-393: `IP_HW0` → netdev **`mhi_hwip%d`**, `IP_SW0` → `mhi_swip%d`. `mhi_wwan_mbim.c` binds only `IP_HW0_MBIM`, which the SDX55 v1 channel set does **not** name [V: pci_generic.c:327-328 `IP_HW0`] → expected data netdev is `mhi_hwip0` (raw IP); the MBIM data-network driver will not bind to this channel set. | module | pin `=y`; verify the raw-IP path with the exact ModemManager build at O7 |
| Host IPA | not in the MHI data path [I-M5-6] | `sm8250.dtsi` has **no** ipa node [V: full-file scan]; driver would match `qcom,sm8350-ipa` [V: drivers/net/ipa/ipa_main.c match, scanned :661]; `CONFIG_QCOM_IPA=m` [V: defconfig:458] | K2 reserves `ipa_fw_mem`/`ipa_gsi_mem` [V: K2 dts:77-85] | keep the reservations, add **no** ipa node unless R-gates show the modem expects host IPA |
| SIM | modem-side on SDX55; no host DT node [I-M5-4] | — | — | verify via ModemManager at R2 |
| SMS | via QMI WMS on the QMI port | ModemManager `mmcli --messaging-*` over `/dev/wwan0qmi0` [I-M5-5: MM version support] | — | R3 |
| Voice calls | **out of scope** | VoLTE needs IMS over QMI + ADSP audio routing (separate M5 audio/remoteproc plan) + a telephony stack; upstream `omaphone`/`omatel` targets Exynos modems [V: U/packages/omaphone/PKGBUILD:1-8 header]; the Nura image did **not** verify VoLTE [V: NOTES.md 2026-11-15] | — | later milestone |

## 4. Firmware needs (referenced to `FW/` = firmware.map rows by name; never bytes)

Source for all modem files: the owner's own OTA `modem` image (already
secured locally [V: `/home/inumineq/android/reference/instantnoodlep/images/modem.img` exists, listing]), mapped at install time per FIRMWARE-PLAN
F1-F6. Names only; AGENTS.md rule 8.

| Requested path (driver) | `FW/` row | Status |
| --- | --- | --- |
| `qcom/sdx55m/sbl1.mbn` [V: pci_generic.c:407] — loaded on every modem boot [V: boot.c:499-522, scanned] | `modem:/image/sdx55m/sbl1.mbn\|qcom/sdx55m/sbl1.mbn` [V: FW/:34] | present |
| `qcom/sdx55m/edl.mbn` [V: pci_generic.c:408] — requested **only** in EDL/emergency mode [V: boot.c:499-500, scanned] | `modem:/image/sdx55m/edl.mbn\|qcom/sdx55m/edl.mbn` [V: FW/:30] | map row now exists; member existence in the verified OTA image remains [I-M5-3] (F2/F3, names only) |
| rest of `qcom/sdx55m/*` (`acdb`, `aop`, `apdp`, `apps`, `devcfg`, `hyp`, `mdmddr`, `multi_image`, `multi_image_qti`, `qdsp6sw`, `sec.elf`, `tz`, `xbl_cfg`) | rows [V: FW/:35-47] | whether the host loads any of these beyond sbl1/edl is [I-M5-3] (FIRMWARE-PLAN §7 item 3 — compare what the Nura image packages at O6); keep the rows regardless |
| per-unit `efs*.bin`, `modemr.jsn` | never mapped [V: FW/ header :12-13] | never extract (AGENTS.md rule 4) |

## 5. Userspace (Arch Linux ARM on the M2+ rootfs)

| Need | Status and evidence |
| --- | --- |
| ModemManager + QMI/MBIM libs | Arch packages `modemmanager`, `libqmi`, `libmbim` [I-M5-5: exact Arch Linux ARM package names/versions confirmed at the packaging gate]; `ModemManager.service` enabled. Upstream pattern: dodge's ModemManager drop-in gated by `/etc/omamobile/modem-probe.enable` [V: U/device/dodge/modem/ModemManager-omamobile.conf:1-7] and udev rule `78-omamobile-mm-fake-net.rules` [V: U/device/dodge/modem/ listing]. Our port adds a `device/instantnoodlep/modem/` dir the same way |
| Mobile data profile | NetworkManager `type=gsm` connection, APN `internet`, route-metric 700 (Wi-Fi stays preferred) [V: U/device/dodge/modem/omamobile-cellular.nmconnection:1-27]. Bearer netdev here will be `mhi_hwip0`, not dodge's `rmnet_ipa0` [V: L/drivers/net/mhi_net.c:379-381] — the profile needs no interface name (type=gsm) [V: same file, no `interface-name` key] |
| SMS | `mmcli -m 0 --messaging-list-sms` over the QMI port [I-M5-5] |
| GNSS | separate M5 item, not this plan |
| hexagonrpcd / libssc / iio-sensor-proxy | not needed for a PCIe modem (they serve remoteproc DSPs) [I]; sensors are a separate M5 plan |
| Calls UI | `omaphone`/`omatel` upstream [V: U/packages/omaphone/PKGBUILD] — Exynos-specific today; out of M5-modem scope (§3 last row) |

## 6. Kernel-side commit order (in linux-omarchy-mobile, not this repo)

One logical change per commit, GPL-2.0 headers on kernel content; this repo
gets only this plan. Re-run the offline gates after every commit.

| # | Commit | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: instantnoodlep: Enable PCIe2 for the SDX55 modem` | `&pcie2` + `&pcie2_phy` `status = "okay"`, PHY supplies ported from C:718-726 [V: DTS-PORT-PLAN §2.3], `&apps_smmu` decision [I-M5-7], perst/wake/pinctrl verified against decompiled `B/dtb.3` at O2 [I-M5-1]. No endpoint child node: `pci_generic` binds by PCI ID [V: pci_generic.c:988-989]. pcie0/pcie1 stay disabled (Wi-Fi is M3, wigig unused) |
| 2 | `config: instantnoodlep: Build in MHI/WWAN for the modem` | `device/instantnoodlep/kernel.config`: `CONFIG_MHI_BUS=y`, `CONFIG_MHI_BUS_PCI_GENERIC=y`, `CONFIG_WWAN=y`, `CONFIG_MHI_WWAN_CTRL=y`, `CONFIG_MHI_NET=y`; `CONFIG_MHI_WWAN_MBIM` and `CONFIG_QRTR_MHI` are not required for this SDX55 v1 raw-IP data/QMI-control path. Defconfig today: :262, :520-522, :350 =m [V: L/arch/arm64/configs/defconfig]. `CONFIG_PCIE_QCOM=y` already [V: :245]. Built-in so the Arch root needs no modules (same rule as the K1 fragment [V: device/instantnoodlep/kernel.config header]) |
| 3 | userspace, separate repo/PR | `device/instantnoodlep/modem/` in omarchy-mobile (MM drop-in, NM gsm profile, udev rule per §5) + `firmware.map` edl.mbn row at FIRMWARE-PLAN F6 (§4) |

## 7. Gated runbook

Offline gates O0-O7 touch no phone. Owner gates G1, R1-R6 run on the phone,
**RAM boot first** (`fastboot boot`, nothing written), exactly as M1a did;
every phone command is a block with Expect, Stop, Rollback (AGENTS.md rule
1). After any *refused* RAM boot, cold-reboot to the bootloader before the
next `fastboot boot` — a refused boot can mark the active slot unbootable
and swap slots [V: NOTES.md 2026-11-16 R1 consequence]. Never `fastboot
flash`, `erase`, `--set-active` anywhere below.

```sh
export L=/home/inumineq/src/l            # branch instantnoodlep-k2 + M5 commits
export OUT=/path/to/private/m5-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
export B=/home/inumineq/android/reference/instantnoodlep/images/boot-dtbs/dtb.3
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1b complete (slot B default, marked) [V: NOTES.md 2026-11-17 B5]; neutral DTBO owner-gated install on `dtbo_b` complete; M2/M3 state recorded; FIRMWARE-PLAN F0-F6 passed or sdx55m rows confirmed; `L` pinned | all present and live root is `oneplus,instantnoodlep`, `qcom,sm8250` | any input missing or stock DTBO still selected | no changes; return to owning ticket |
| O1 Baseline | `make -C "$L" O="$OUT" dt_binding_check` on unchanged base (pattern [V: NOTES.md K2 D1]) | baseline recorded, exit 0 | baseline missing | drop edits |
| O2 Stock modem wiring | `dtc -I dtb -O dts -o "$OUT/dtb3.dts" "$B"` (laptop, read-only); extract pcie1/pcie2 nodes: perst/clkreq/wake GPIOs, modem power rails, any mss node; compare with L/ sm8250.dtsi:2388-2512 and C:708-726 [V: DTS-PORT-PLAN §2.3]; E/ already known to carry none [V: §2 above] | pcie2 = modem confirmed or plan revised; GPIO 85/86/87 and supplies confirmed for this unit | dtb.3 disagrees with mainline on port/GPIOs | do not enable; fix commit 1 from dtb.3 facts |
| O3 Build + schema | `make -C "$L" O="$OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8250-oneplus-instantnoodlep.dtb` and `dtbs_check` after commit 1 | dtc exit 0; no new warning for this board | any error | delete output; fix current commit only |
| O4 Node checks | `fdtget` block below against `"$DTB"` and live DT | pcie2/pcie2_phy `okay`; perst cell 85; pcie0/pcie1 `disabled`; built/live root is `oneplus,instantnoodlep`, `qcom,sm8250` | any extra enable, wrong live compatible, or changed identity | discard output; fix defining commit / return to neutral-DTBO gate |
| O5 Config check | `grep` the built `.config` for the §6 commit-2 symbols | all `=y` | any missing | fix kernel.config fragment |
| O6 Firmware map | `FW/` contains the edl.mbn row; `git check-ignore` on `*.mbn *.img`; grep map for serial/IMEI/MAC patterns; member names of `qcom/sdx55m/*` confirmed present in the modem image by name only (F2/F3 pattern) | names only; all rows present | identity data or a blob pattern | delete draft rows |
| O7 Release | review commits 1-2, O1-O6 logs, hashes, open [I]s with coordinator/owner; verify the exact ModemManager QMI + raw-IP `mhi_hwip0` integration. Any channel rename to `IP_HW0_MBIM` is a separate change only after a source/runtime proof [I-M5-6]. | written approval for one RAM boot | any failed gate | keep M2/M3 state; do not boot |

O4 `fdtget` checks:

```sh
fdtget -t s "$DTB" /soc@0/pcie@1c10000 status
fdtget -t x "$DTB" /soc@0/pcie@1c10000 perst-gpios
fdtget -t s "$DTB" /soc@0/pcie@1c10000/phy@1c16000 status
fdtget -t s "$DTB" /soc@0/pcie@1c10000/phy@1c16000 compatible
fdtget -t s "$DTB" /soc@0/pcie@1c00000 status
fdtget -t s "$DTB" /soc@0/pcie@1c08000 status
fdtget -t s "$DTB" / compatible
```

Expected: `okay` for pcie2 and its phy, perst-gpios decodes to tlmm phandle + 85 + flags, phy compatible `qcom,sm8250-qmp-modem-pcie-phy`, pcie0/pcie1 `disabled`, root compatible `oneplus,instantnoodlep` + `qcom,sm8250`.

### 7.2 Owner gates (phone; RAM boot first)

Placeholders: `{{K5_IMG}}` = M5 boot image from O7; `{{SERIAL}}` = pinned
fastboot serial (private, never pasted). Never run a block with a `{{...}}`
still in it. Captures to `captures/<date>/m5/` (gitignored).

| # | Step (command block) | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot` and slot flags, recorded | one device; flags equal to the M1b B5 capture [V: NOTES.md 2026-11-17 B5] | flags differ | `fastboot -s {{SERIAL}} reboot`; stop |
| R1 | `fastboot -s {{SERIAL}} boot {{K5_IMG}}`; then `ssh root@172.16.42.1`, `dmesg`, `lspci -nn`, `ip link`, and read `/sys/firmware/devicetree/base/compatible` | live root is `oneplus,instantnoodlep` + `qcom,sm8250`; pcie2 link up; `lspci` shows `17cb:0306` [V: pci_generic.c:988-989]; dmesg has `MHI PCI device found: qcom-sdx55m` and sbl1.mbn loaded with no firmware error; `/dev/wwan0qmi0` and `mhi_hwip0` exist. The SDX55 v1 config has no `IP_HW0_MBIM`, so do not expect an MBIM data netdev. | wrong live root; no 17cb:0306; firmware-load error; no MHI probe; no QMI port or data netdev | hold Power+VolUp 10-30 s (or `panic=10`); after a refused boot, cold-reboot to bootloader before any retry [V: NOTES.md R1 consequence]; slot-B system boots |
| R2 | over SSH: `mmcli -L`, then `mmcli -m 0` | one modem (QMI port); SIM present with operator/registration [I-M5-4 until run]; `qmicli -d /dev/wwan0qmi0 --nas-get-signal-info` answers | no modem in mmcli; SIM absent | `reboot -f` over SSH; record; fix DT (I-M5-1/I-M5-8) or firmware rows |
| R3 | over SSH: `mmcli -m 0 --messaging-list-sms` | SMS list returns (may be empty) without error [I-M5-5] | command unsupported/error | record MM version; adjust plugin set |
| R4 | over SSH: `nmcli connection up omamobile-cellular` (or bearer via mmcli); `ip route`; `ping -c3 1.1.1.1` | bearer up on `mhi_hwip0` [V: mhi_net.c:379-381]; default route via cellular; ping OK [I: needs a SIM with a data plan — owner decision] | no bearer; no route | `reboot -f`; record; decide MBIM rename [I-M5-6] |
| R5 | `reboot -f`; boot `{{K5_IMG}}` again; same R1 checks | modem re-enumerates and re-probes idempotently; dmesg shows **no** edl.mbn request in normal boot [V: boot.c:499-500, scanned] | EDL path taken; flaky probe | rollback to M3 image |
| R6 | boot the installed slot-B system (boot only, never write): ModemManager starts via the drop-in; `mmcli -L`; then `fastboot -s {{SERIAL}} getvar all` (filtered) | modem present in installed system; slot flags equal to G1; nothing written | flags changed | stop; record; ask on #808 before any further boot |

## 8. Open [I]s and how each resolves

| ID | Open inference | Resolution gate |
| --- | --- | --- |
| I-M5-1 | The SDX55 sits on **pcie2** of this unit (mainline generic encodes pcie2=modem [V: sm8250.dtsi:2439,:2486]; community enables pcie1+pcie2 [V: DTS-PORT-PLAN §2.3 C:708-726]; E/ is silent [V: §2]); perst 85 / clkreq 86 / wake 87 [V: :2466-2467, :5877-5896] are right for this board | O2 (decompile `B/dtb.3`, compare); R1 (`lspci`, dmesg) |
| I-M5-2 | pcie2 PHY supply rail names/values from C:718-726 [V: existence via DTS-PORT-PLAN §2.3] | O2/O3; live-DT compare like DTS-PORT-PLAN I6 pattern |
| I-M5-3 | edl.mbn member exists in the modem image; whether the host loads more of `qcom/sdx55m/*` than sbl1/edl (FIRMWARE-PLAN §7 item 3) | FIRMWARE-PLAN F2/F3 (names only) + O6; compare Nura packaging |
| I-M5-4 | SIM is modem-side (no host DT) and registers via QMI | R2 (`mmcli -m 0`) |
| I-M5-5 | Arch package names (`modemmanager`/`libqmi`/`libmbim`) and ModemManager version support for wwan QMI ports + SMS | packaging gate (O6/O7); R2/R3 |
| I-M5-6 | Whether the installed ModemManager/NetworkManager versions can drive QMI control plus this modem's `mhi_hwip0` raw-IP data path; the in-tree MBIM data driver requires a different channel name [V: mhi_net.c:389-393; mhi_wwan_mbim.c binds only `IP_HW0_MBIM`] | O7 package/source audit + R4; do not rename the MHI channel unless this is proven necessary |
| I-M5-7 | Whether `&apps_smmu` must be enabled for pcie2 (iommu-map [V: sm8250.dtsi:2455-2456]) or direct DMA suffices | O3 (schema) + R1 dmesg |
| I-M5-8 | Any modem power-en GPIO/rail in the base DTB beyond PERST + PHY supplies | O2 (`B/dtb.3`); R1 |

## 9. Definition of done for M5-modem

O0-O7 pass; G1, R1-R6 pass with pasted (redacted) output; the modem
enumerates as `17cb:0306` on the expected pcie port, `sbl1.mbn` loads from
the owner-extracted file, `/dev/wwan0qmi0` answers QMI, the SIM registers,
SMS listing works, and (if the owner's SIM has data) the NM cellular bearer
carries traffic on `mhi_hwip0`; slot flags unchanged; no partition written;
results appended to NOTES.md with dates. Kernel commits 1-2 exist in a
linux-omarchy-mobile branch with gates rerun per commit.
