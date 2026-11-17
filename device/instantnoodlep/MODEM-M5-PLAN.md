<!-- SPDX-License-Identifier: MIT -->
# MODEM-M5-PLAN: SDX55, MHI/QRTR, and telephony on instantnoodlep

> 2026-11-17 implementation addendum: read [MODEM-M5-DELTA.md](MODEM-M5-DELTA.md)
> first. [V: D/K17:7-10,33-87 in that delta] The public device uses a
> flashless-specific MHI profile and Sahara host loader, not generic SDX55
> support alone. Its endpoint DTS, MBI route, exact candidate config,
> packages, firmware exclusions and first RAM-boot gate are specified there.
> [I] That first gate stops at ports and `mmcli -L`; SIM, registration,
> GNSS tracking and all later tests below need a separate owner go.
> Private-state provenance blocks release until resolved; no build or
> phone test was performed for this addendum.

House-rule-6 gate for the **modem** subsystem of milestone **M5** of the
wayfinder map ("wayfinder:map — Omarchy Mobile port for instantnoodlep
(OnePlus 8 Pro IN2023), M1-M5"; M5 includes mobile data/SMS, sensors and
cameras [V: device/instantnoodlep/FIRMWARE-PLAN.md §2]). This plan is
documentation only. No kernel or userspace implementation is included.

- Date: 2026-11-17. Branch: `modem-gnss` (documentation only).
- Reading order: `AGENTS.md`, `device/instantnoodlep/DTS-PORT-PLAN.md`,
  `device/instantnoodlep/FIRMWARE-PLAN.md` + `firmware.map`,
  `device/instantnoodlep/DISPLAY-M3-PLAN.md` (template), `NOTES.md`.
- Scope: the external flashless SDX55 modem on PCIe/MHI (not the SM8250 integrated
  MPSS `qcom_q6v5_mss` remoteproc), modem firmware and QRTR/RFS services,
  ModemManager, SIM, SMS and mobile data. Calls are a gated follow-on whose
  audio path depends on the separate AUDIO-M5-PLAN and its ADSP/PDM stack.
- Safety model unchanged: no write to `super` or any `_a` partition; flash
  writes only to slot-B boot images and `userdata`, each behind an owner go
  (AGENTS.md rule 3). M5 phone steps are `fastboot boot` (RAM) first; the
  installed slot-B system is only booted, never written. Firmware comes from
  the owner's own OTA at install time, names only, never from git
  (AGENTS.md rule 8). Never touch `modem*`, `efs*`, `persist`, `fsg`, `fsc`
  partitions (already backed up read-only at stage-0 D4 [V: NOTES.md
  2026-11-16 stage-0 entry]).

- Current test prerequisite: K3 combo is on `boot_b` with its temporary,
  test-only `qcom,kona` machine-match patch, so `qcom_pd_mapper` recognizes
  the live root compatible [V: docs/agents/state.md:22-25; .trail/learnings/
  2026-11-17-the-stock-dtbo-rewrites-the-root-claude.md:17-22]. Never send
  that patch upstream. The phone still has stock `dtbo_b`; the neutral DTBO
  is parked after ABL rejected both tested forms [V: DTBO-PLAN §6; learning
  `l-48e0c482`]. This plan does not ask for another DTBO write or assume a
  neutral root compatible. MHI's SDX55 match is by PCI ID and does not use
  the root-machine PDM table [V: L/drivers/bus/mhi/host/pci_generic.c:988-989].

## 1. Public source pins

- `L/` = torvalds/linux tag [`v7.3-rc6`](https://github.com/torvalds/linux/tree/v7.3-rc6).
  Cite kernel code by repository path and line where available; no private
  kernel worktree or handset dump is an input to this refresh.
- `C/` = community SM8250 tree
  [`soc/qualcomm-sm8250/linux`, tag `7.2.0-dev`](https://gitlab.nura.eco/soc/qualcomm-sm8250/linux),
  as pinned in DTS-PORT-PLAN §1.
- `U/` = [derekross/omarchy-mobile](https://github.com/derekross/omarchy-mobile);
  upstream `AGENTS.md` and `CONTRIBUTING.md` were read before this plan update.
- `D/` = public device reference
  [darknagel/oneplus-instantnoodlep-nura-unofficial](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial),
  especially its README, `modem/README.md`, `modem/install.sh`,
  `modem/sdx55-gnss.py`, and pmaports patches 0018-0020. These are evidence
  for behavior only; do not copy code or vendor firmware.
- `FW/` = `device/instantnoodlep/firmware.map` (names only).

## 2. Hardware identification

| Item | Value | Evidence |
| --- | --- | --- |
| SoC | Qualcomm SM8250 (`soc_id` 356, rev 2.1) | [V: NOTES.md 2026-11-16 A6 socinfo] |
| Modem architecture | External Snapdragon X55 (SDX55) modem reached by the SM8250 host over PCIe/MHI; Linux host loader is `pci_generic`, not the host's `qcom_q6v5_mss` remoteproc/MPSS path | [V: Nura public README identifies the OnePlus 8 Pro modem as SDX55 and cites MHI kernel patches 0018/0020; Nura `pmaports-patches/0019` says QMI is over QRTR for SDX55 on MHI; L `pci_generic.c:405-415, 988-989` binds SDX55 PCI ID and loads `sbl1.mbn`] |
| Modem PCI ID | `17cb:0306`; catch-all `{ PCI_DEVICE(PCI_VENDOR_ID_QCOM, 0x0306) }` → `mhi_qcom_sdx55_info` | [V: L/include/linux/pci_ids.h:2420 `PCI_VENDOR_ID_QCOM 0x17cb`; L/drivers/bus/mhi/host/pci_generic.c:988-989] |
| PCIe port | Mainline SM8250 labels pcie2 as the modem port (MDM ref clock and modem QMP PHY); the public device-specific community patch enables the modem PCIe path. Exact IN2023 endpoint placement and rails still require the owner's stock DTB and first live enumeration | [V: L/arch/arm64/boot/dts/qcom/sm8250.dtsi:2388-2512; C community device DTS, tag `7.2.0-dev`, modem PCIe section (cited in DTS-PORT-PLAN §2.3); Nura pmaports patch 0018]. Unit confirmation: [I-M5-1], O2 and R1 |
| PERST#/wake GPIOs (modem port) | Mainline generic pcie2 defaults describe PERST/CLKREQ/wake lines; do not treat generic line numbers as handset-verified wiring | [V: L/arch/arm64/boot/dts/qcom/sm8250.dtsi:2466-2467, 5877-5896; L/drivers/pci/controller/dwc/pcie-qcom.c:2071-2077]. Unit wiring [I-M5-1], O2/R1 |
| Integrated MPSS vs SDX55 | SM8250 has SoC remoteproc DSPs (ADSP/CDSP/SLPI) and a generic Q6V5-MSS driver for supported integrated modem subsystems, but public instantnoodlep modem support uses an SDX55 PCIe/MHI endpoint. Do not add `mpss`/`qcom_q6v5_mss` for this external modem | [V: L `drivers/remoteproc/qcom_q6v5_mss.c` models MBA/MPSS image loading and the SM8250 DTS contains SoC DSP remoteprocs; Nura public README + MHI/QRTR patches identify SDX55 path] |
| MHI/QRTR services | SDX55 generic MHI profile has QMI control channel 14/15 and IPCR 20/21; Linux exposes QMI as a WWAN control port and QRTR-MHI binds IPCR. `pci_generic.c` does not define an NMEA channel for this SDX55 profile | [V: L `pci_generic.c:314-342`; `mhi_wwan_ctrl.c` QMI/WWAN-port match; `net/qrtr/mhi.c` IPCR match] |
| Extra modem power | Any additional enable GPIO/rail beyond pcie2's generic supplies must be confirmed from public device DTS or owner's stock base DTB before enabling hardware | [I-M5-8], O2 and R1 |

## 3. Inventory per block

The current on-device kernel is K3 combo on `boot_b`; it includes the
test-only `qcom,kona` compatible patch and has not enabled or tested M5
modem support [V: docs/agents/state.md:22-25; DTS-PORT-PLAN §1]. The clean
mainline board DTS baseline has PCIe disabled; the M5 change must enable only
the port confirmed by the device-specific public DTS and owner-run checks.

| Block | Mainline status | Driver + binding | Current K3 | Missing for M5 |
| --- | --- | --- | --- | --- |
| PCIe2 host @ `0x1c10000` | present, generic, disabled [V: sm8250.dtsi:2388-2483] | `qcom,pcie-sm8250`; `drivers/pci/controller/dwc/pcie-qcom.c` (match table, scanned :2470-2499); binding `qcom,pcie-sm8250.yaml`; `CONFIG_PCIE_QCOM=y` [V: L/arch/arm64/configs/defconfig:245]; clocks/resets/GDSC/iommu-map all in the generic node [V: :2433-2461] | not referenced | enable `&pcie2`; check `&apps_smmu` (iommu-map `0x1d00/0x1d01` [V: :2455-2456]) [I-M5-7] |
| PCIe2 PHY @ `0x1c16000` | present, generic, disabled [V: sm8250.dtsi:2485-2512] | `qcom,sm8250-qmp-modem-pcie-phy`; `drivers/phy/qualcomm/phy-qcom-qmp-pcie.c` match (scanned :6460-6461); `CONFIG_PHY_QCOM_QMP=m` [V: defconfig:1780, full-file scan] | not referenced | enable `&pcie2_phy` + PHY supplies from C:718-726 [V: DTS-PORT-PLAN §2.3 row "&pcie2 + &pcie2_phy, C:718-726"]; rail names [I-M5-2] |
| MHI over PCIe (`pci_generic`) | present; `CONFIG_MHI_BUS_PCI_GENERIC=m` [V: defconfig:262] | `L/drivers/bus/mhi/host/pci_generic.c`: `mhi_qcom_sdx55_info` :405-415 — `.fw = "qcom/sdx55m/sbl1.mbn"` :407, `.edl = "qcom/sdx55m/edl.mbn"` :408, `.edl_trigger = true` :409, config `modem_qcom_v1_mhiv_config` :410, mru 32768 :413; pure PCI-ID driver, no DT node/of_match [V: id table :988-989; no `qcom,sdx55` compatible exists — full-file scan] | generic module only; board needs flashless profile [V: MODEM-M5-DELTA §1] | pin `=y` in `device/instantnoodlep/kernel.config`; flashless endpoint/profile required [V: MODEM-M5-DELTA §2-3] |
| MHI channels (SDX55) | present | `modem_qcom_v1_mhi_channels[]` :314-329 — DIAG 4/5, MBIM 12/13, QMI 14/15, IPCR 20/21, FIREHOSE 34/35, IP_SW0 46/47, **IP_HW0 100/101**; events :331-342; controller config :363-370; probe powers up explicitly at probe [V: L `pci_generic.c`] | not tested | channel table is descriptor-defined |
| Firmware load | present | `drivers/bus/mhi/host/boot.c` uses the EDL image only in EDL state, otherwise the normal firmware image; `pci_generic` names the SBL path and EDL trigger [V: L `boot.c`, `init.c`, `pci_generic.c`] | M5 firmware not tested | verify exact `FW/` members by name in O5; do not infer OTA absence of EDL |
| QMI/QRTR control | Mainline has MHI QMI WWAN-control and optional QRTR-MHI drivers; generic SDX55 provides QMI (14/15) and IPCR (20/21) | `mhi_wwan_ctrl.c` maps `QMI` to a WWAN control port; `net/qrtr/mhi.c` binds IPCR [V: L files]. Public reference uses QMI over QRTR; its udev rule ignores unresponsive MHI QMI/MBIM ports [V: D `pmaports-patches/0019`, `modem/78-mm-sdx55-qrtr.rules`, `ModemManager-sdx55.conf`, `sdx55-gnss.py`] | K3 has no modem test | enable QRTR/MHI and audit MM probing; do not treat a created WWAN QMI node as proof QRTR LOC works |
| Data channel | present; `CONFIG_MHI_NET=m` [V: defconfig:350]; `CONFIG_MHI_WWAN_MBIM=m` [V: :522] | `mhi_net.c` id table :389-393: `IP_HW0` → netdev **`mhi_hwip%d`**, `IP_SW0` → `mhi_swip%d`. `mhi_wwan_mbim.c` binds only `IP_HW0_MBIM`, which the SDX55 v1 channel set does **not** name [V: pci_generic.c:327-328 `IP_HW0`] → expected data netdev is `mhi_hwip0` (raw IP); the MBIM data-network driver will not bind to this channel set. | module | pin `=y`; verify the raw-IP path with the exact ModemManager build at O7 |
| Host IPA | not in the public MHI data path [V: L `pci_generic.c`, `mhi_net.c`; no IPA node in generic SM8250 DTS] | `CONFIG_QCOM_IPA` is unrelated to raw MHI host data [V: L `drivers/net/ipa/ipa_main.c`] | existing reserved-memory stays as-is | do not add an IPA node for SDX55 without new evidence |
| RFS / modem services | External SDX55 uses QRTR-based remote file service in the public device setup; it runs before ModemManager. The public installer disables `tqftpserv` to avoid a competing service. This is not the SoC Q6V5 `rmtfs`/MPSS path | [V: D `modem/install.sh`, `modem/README.md`, `modem/rfsd.py`; L `drivers/soc/qcom/rmtfs_mem.c` and `drivers/remoteproc/qcom_q6v5_mss.c` describe SoC shared-memory/remoteproc support] | not configured | O5/R2 must settle safe per-device RFS backing; never point a daemon at modem NV partitions or adopt the public installer wholesale |
| `pd-mapper` | Not required for PCI-ID-bound MHI enumeration or SDX55 QMI transport; needed for SM8250 remoteproc power-domain services, including ADSP call audio | [V: L `drivers/soc/qcom/qcom_pd_mapper.c`; MODEM MHI path uses PCI/MHI drivers; AUDIO-M5-PLAN] | K3 test kernel includes temporary kona machine match so PDM mapping can match current live root [V: docs/agents/state.md:35-37; learning `l-f28ff139`] | keep as shared audio dependency; do not add it as an SDX55 boot dependency |
| ModemManager + SIM | Public device reference uses ModemManager with QMI over QRTR and separate SIM activation; its package carries patches for QRTR+mhi_net and avoiding a location setup abort after SIM unlock | [V: D `pmaports-patches/0019`, `modem/README.md`, `modem/sdx55-sim.py`]. Mainline MM / Arch package support for this exact device is [I-M5-5] | not configured | R2-R4: modem appears, SIM state/PIN, registration, SMS, data; pin exact package versions and plugin support |
| SMS/data | SMS uses QMI WMS; mobile data uses MHI `IP_HW0` → `mhi_hwip0`; the public device reference reports working SMS and mobile data on IN2023 | [V: L `pci_generic.c` SDX55 channels; L `mhi_net.c:389-393`; D `modem/README.md`]. ModemManager backend, SIM-required state and network configuration for this Arch image remain [I] | not tested | R4/R5, with owner SIM/APN; calls are a separate gate |
| Calls and audio routing | Voice calls require modem IMS/telephony support plus host ADSP voice path, QRTR service routing, the AUDIO-M5 ADSP/remoteproc/PDM stack, UCM mixer routes, PipeWire routing and a call UI. Mobile data/SMS working does not prove calls | [V: D current README and `modem/README.md` document differing call status; AUDIO-M5-PLAN covers ADSP/audio]. Exact IN2023/Arch call support [I-M5-9] | not tested | separate R7 only after AUDIO-M5 and telephony prerequisites pass |

## 4. Firmware needs (referenced to `FW/` = firmware.map rows by name; never bytes)

Candidate firmware source is the owner's own verified OTA's `modem` image,
mapped at install time per FIRMWARE-PLAN F1-F6. Only firmware member names
are checked in. Runtime modem file-service data is a separate per-device
input and must not be treated as firmware.

| Requested path (driver) | `FW/` row | Status |
| --- | --- | --- |
| `qcom/sdx55m/sbl1.mbn` [V: L `pci_generic.c`, SDX55 descriptor] | `modem:/image/sdx55m/sbl1.mbn\|qcom/sdx55m/sbl1.mbn` [V: firmware.map:29-30] | candidate MHI boot file; O5 verifies exact OTA member name |
| `qcom/sdx55m/edl.mbn` [V: L `pci_generic.c`, SDX55 descriptor and EDL path] | no row currently | EDL-only request, not normal boot. Whether the owner's OTA supplies it is [I-M5-3]; do not source it elsewhere without a new decision |
| Other mapped `qcom/sdx55m/*` members | firmware.map:31-43 | O5 checks names only; do not assume the host requires all members until source audit and safe runtime checks prove it |
| `efs*`, modem NV, `modemr.jsn`, calibration and identity files | deliberately absent from firmware.map | per-device data is excluded from firmware extraction and commits; see RFS privacy gate and AGENTS.md rules 3-4 |

## 5. Userspace (Arch Linux ARM on the M2+ rootfs)

| Need | Status and evidence |
| --- | --- |
| ModemManager | Use the distro package only after checking QMI-over-QRTR, `mhi_net` raw-IP data, SIM unlock and SMS support. Public device reference carries a ModemManager integration patch for QRTR + `mhi_net`, and a workaround for location setup after SIM unlock [V: D `pmaports-patches/0019`]. Evidence of compatibility work, not code to copy. Arch package/version support is [I-M5-5] |
| QRTR name service | Required for QRTR service discovery. Exact Arch daemon package and activation are [I-M5-6]; R1/R2 identify the transport and services |
| Modem RFS | Public device setup runs a QRTR/TFTP RFS service before ModemManager and disables `tqftpserv` [V: D `modem/install.sh`, `modem/README.md`]. This is distinct from mainline SoC `rmtfs`/MPSS. A safe private backing source is [I-M5-4]; do not let a service read or write protected modem/NV partitions |
| `pd-mapper` | Not needed for PCI-ID MHI enumeration or SDX55 QMI transport; needed by SoC remoteproc power-domain services such as the ADSP call-audio path [V: L `drivers/soc/qcom/qcom_pd_mapper.c`; AUDIO-M5-PLAN] |
| SIM/SMS | Public reference uses a SIM activation helper and ModemManager/QMI messaging [V: D `modem/README.md`, `modem/sdx55-sim.py`]. Ours remains [I-M5-5] until R3/R4 |
| Cellular data | NetworkManager GSM bearer uses `mhi_hwip0` raw IP (not `IP_HW0_MBIM`) [V: L `pci_generic.c`, `mhi_net.c`]. APN and package integration are owner/device gates |
| Calls/audio | Requires IMS/telephony plus ADSP voice session, QRTR routing, AUDIO-M5 ADSP/PDM, UCM/PipeWire routes and a call UI. Public Nura README and modem README give differing call status; neither proves this Arch port [I-M5-9] |
| Other remoteproc helpers | GNSS does not need `hexagonrpcd`/`libssc`/`iio-sensor-proxy`; those belong to SoC DSP sensors, not external SDX55 [V: SENSORS-M5-PLAN] |

## 6. Kernel and userspace implementation order

Only plan documentation is in this repository change. Kernel work belongs
in linux-omarchy-mobile with GPL-2.0 headers; userspace work belongs in
omarchy-mobile. Keep implementation commits scoped.

| # | Work item | Content |
| --- | --- | --- |
| 1 | Confirm modem connection | Use public instantnoodlep pcie2/MHI wiring as candidate; owner checks stock base DTB for port, PERST/wake and rails before enabling. No `mpss`/`qcom_q6v5_mss` node for SDX55. |
| 2 | Kernel DTS | Enable confirmed PCIe controller/PHY, supplies, pinctrl and IOMMU mapping only after step 1. The flashless endpoint/profile delta is in MODEM-M5-DELTA §2-3 [V: D/K17-K18]. |
| 3 | Kernel config | Build in `MHI_BUS`, `MHI_BUS_PCI_GENERIC`, `WWAN`, `MHI_WWAN_CTRL`, `MHI_NET`, `QRTR`, `QRTR_MHI`; retain PCIe/QMP config. Add no q6v5 mss or host IPA solely for SDX55. |
| 4 | Modem services | Owner-approved firmware mapping; QRTR name service; safe per-device RFS backing and service before ModemManager; prevent `tqftpserv` conflict. Never access modem/NV/persist partitions in the runbook. |
| 5 | ModemManager | Audit Arch ModemManager/libqmi/NM build for QMI over QRTR, raw `mhi_net`, SIM unlock and SMS. LOC is covered in GNSS-M5-PLAN. |
| 6 | Calls | Only after AUDIO-M5 passes: validate IMS/telephony, ADSP/QRTR service, PipeWire/UCM route switching and call UI. |

## 7. Gated runbook

Offline gates O0-O7 touch no phone. Phone steps R1-R8 are owner-run only;
RAM boot (`fastboot boot`) is first and is not a flash. Never flash, erase,
change active slot, write `super`, `_a`, or modem/NV partitions. The phone
currently uses stock `dtbo_b` and K3 combo's test-only Kona match; this plan
does not ask for another DTBO write or assume a neutral root compatible
[V: docs/agents/state.md:22-25; DTBO-PLAN §6]. After a refused RAM boot,
cold-reboot to bootloader before retry because ABL may mark a slot
unbootable [V: NOTES.md 2026-11-16 R1 consequence]. A `userdata` write for
packages/profiles requires explicit owner go and a rollback.

```sh
export L=/path/to/linux-omarchy-mobile
export OUT=/path/to/private/m5-build
export DTB="$OUT/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb"
```

### 7.1 Offline gates

| Gate | Command or review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 Inputs | M1b complete; current K3 combo state recorded; M5 build provenance includes temporary Kona patch for device testing only; stock `dtbo_b` retained; FIRMWARE-PLAN F0-F6 status reviewed | inputs and scope explicit; no neutral-DT assumption | missing input or test patch proposed upstream | no changes; return to owning gate |
| O1 Public source audit | Review L `pci_generic.c`, `mhi_wwan_ctrl.c`, `mhi_net.c`, `qrtr/mhi.c`, `qcom_pd_mapper.c`, `qcom_q6v5_mss.c`; D README, modem README/install and patches 0018-0020 | architecture and services match the plan; no implementation copied | source conflict or private-only claim needed | revise plan; no device change |
| O2 Stock modem wiring | Owner decompiles the already-held base DTB privately; checks pcie1/pcie2, PERST/CLKREQ/wake, rails, IOMMU, and modem/remoteproc nodes | confirms endpoint/port and required wiring; updates [I-M5-1/2/7/8] | not unambiguously identified or mismatch with candidate DTS | do not enable PCIe; revise kernel plan |
| O3 Build/schema | Build the board DTB and run relevant `dtbs_check`/schema checks after DTS changes | no new warning/error; only intended PCIe port enabled | any failure | drop build output; fix current commit only |
| O4 Config/DT | inspect merged `.config` and built `fdtget`; compare live DT at R1 while accounting for stock Kona root and combo match | expected PCIe/MHI/QRTR config; root is interpreted under current K3 test context | wrong port, extra PCI enable, missing config/match | discard image; revisit gate |
| O5 Firmware/RFS privacy | verify OTA firmware member names and destinations; inspect ignore rules. Separately review safe private RFS backing without exposing EFS/NV contents | names only; no identity/calibration in map/git; backing and userdata rollback reviewed | direct protected-partition access or no approved private source | stop; no package or phone run |
| O6 Userspace | verify exact Arch package versions/options for `qrtr-ns`, ModemManager, libqmi, NetworkManager, QRTR plugin, `mhi_net`, SIM unlock and SMS; check service ordering and no `tqftpserv` conflict | exact integration understood and RFS precedes MM | assumed package support or unapproved persistent setup | revise userspace plan |
| O7 Release | review O0-O6 logs, hashes, open [I]s and `scripts/trail-lite lint`; owner approves one RAM boot | written go for R1 only | any failed gate | preserve current K3; do not boot |

### 7.2 Owner gates (phone; RAM boot first)

Fill `{{SERIAL}}` and `{{M5_IMG}}` locally. Never run placeholders as-is.
Keep captures in gitignored `captures/<date>/m5/`; redact all output before
notes. Stop if a step would write a protected partition.

| # | Command block / step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | `fastboot -s {{SERIAL}} devices`; `getvar current-slot`; read slot flags | one phone; B active/successful and flags match current state [V: docs/agents/state.md:29-37] | state differs | `fastboot -s {{SERIAL}} reboot`; reconcile M1b state |
| R1 | `fastboot -s {{SERIAL}} boot {{M5_IMG}}`; SSH read `uname -a`, live `/sys/firmware/devicetree/base/compatible`, `lspci -nn`, `ip -brief link`, and dmesg filtered for PCI/MHI/SDX55/firmware | Kona-compatible live root recognized by test-only K3 match; one expected `17cb:0306`; MHI probe succeeds, `mhi_hwip0` appears; firmware request succeeds without NV reads | unexpected root/port, missing device/netdev, firmware error, SSH loss | wait for panic/watchdog; after refusal cold-reboot to bootloader; do not loop RAM boots |
| R2 | Read QRTR name-service and service logs; check `systemctl status qrtr-ns sdx55-rfsd tqftpserv` using reviewed unit names. Do not print backing paths or data | QRTR sees modem; approved RFS service answers before MM; `tqftpserv` not competing; no `rmtfs` started for SDX55 | RFS accesses protected partitions, service conflict, or QRTR absent | stop test; `reboot -f`; preserve private logs; no retry until O5 review |
| R3 | `mmcli -L`; `mmcli -m any`; check SIM state. Enter a SIM PIN only in a private owner-local command, never saved in captures | MM recognizes QMI-over-QRTR modem; SIM detected/unlocked; registration if carrier permits | MM abort/no modem/SIM absent or unclear PIN state | `reboot -f`; record redacted error; stop for integration fix |
| R4 | `mmcli -m any --messaging-list-sms`; with owner-approved recipient send one ordinary test SMS and check for reply | SMS listing works and one test is delivered/received | no messaging support, send failure or no owner consent | stop SMS attempts; reboot only if modem is wedged |
| R5 | Owner enters APN in a test NetworkManager GSM profile; `nmcli connection up {{PROFILE}}`; `ip route`; `ping -c 3 1.1.1.1`; remove test profile unless owner authorizes retaining it | bearer routes via `mhi_hwip0` and traffic works with owner's plan | no bearer/wrong interface/unintended profile write | `nmcli connection down {{PROFILE}}`; remove profile; owner-approved userdata rollback; reboot |
| R6 | Follow GNSS-M5-PLAN R1-R6; don't run `qmicli` or another LOC client while MM owns the service | GNSS works via one chosen control stack and stops cleanly | competing LOC/QMI client or modem wake loop | stop GNSS; reboot; see GNSS plan |
| R7 | After AUDIO-M5 passes, owner-approved call to a consenting non-emergency endpoint; check call state, uplink/downlink, speaker/earpiece, mute and hangup route | two-way audio, correct route switching/restoration, record IMS or fallback status | no audio, modem reset, stuck call or persistent route | end call; restore AUDIO plan's default UCM route; reboot only if modem is wedged |
| R8 | Boot installed slot-B system normally (boot only); repeat R1-R3; compare flags with G1 | same results as RAM boot; flags unchanged | regression or slot-flag difference | stop; keep `boot_b` unchanged; follow M1b recovery instructions |

## 8. Open [I]s

| ID | Open inference | Resolution |
| --- | --- | --- |
| I-M5-1 | Which PCIe controller and exact endpoint wiring this IN2023 uses; pcie2 is the public candidate | O2 owner stock-DTB review, R1 `lspci`/dmesg |
| I-M5-2 | Board-specific pcie2 PERST/CLKREQ/wake GPIOs and PHY rail values | O2; do not assume generic values |
| I-M5-3 | Exact OTA SDX55 firmware member set, including EDL and any extra host-requested files | O5 name-only audit and mainline source audit |
| I-M5-4 | Safe private SDX55 RFS backing consistent with never touching modem/NV partitions | O5; block device tests until owner approves source and rollback |
| I-M5-5 | Arch ModemManager/libqmi versions support QMI over QRTR, SIM, SMS and raw MHI data | O6, then R3-R5 |
| I-M5-6 | QRTR name-service package/activation and required daemon units on Arch | O6/R2 |
| I-M5-7 | Whether `apps_smmu` is required for confirmed PCIe endpoint | O2/O3 and R1 logs |
| I-M5-8 | Any additional modem enable GPIO/rail beyond PCIe PHY/reset | O2/R1 |
| I-M5-9 | Voice/IMS support and end-to-end audio routing on this Arch build | AUDIO-M5 then R7 |

## 9. Definition of done

O0-O7 and G1/R1-R6 pass with redacted output; SDX55 enumerates on the
confirmed PCIe port, SBL firmware loads, QRTR and approved RFS work,
ModemManager sees the SIM and SMS, and mobile data uses `mhi_hwip0` when an
owner SIM/APN permits. Slot flags remain unchanged and no protected
partition is written or exposed. Calls count only after AUDIO-M5 and R7
pass. Record date/kernel release in NOTES.md; keep captures, firmware bytes,
NV and phone identifiers off git.
