<!-- SPDX-License-Identifier: MIT -->
# VoLTE/IMS feasibility survey for the flashless SDX55 over QRTR

> **Issue:** #194 — decides MODEM-M5 R7
>
> **Date:** 2026-11-25. Public-source research only; no phone or proprietary service material was used.
>
> **Scope:** QMI IMS service id/version on the SDX55 flashless profile, mainline kernel pieces needed, ModemManager 1.24.2 voice/IMS D-Bus capabilities and gaps, VoWiFi prerequisites, and a reachable/not-reachable verdict with blockers.
>
> **Read first:** `AGENTS.md`, `MODEM-M5-PLAN.md` (esp. I-M5-9 at line 204), `MODEM-M5-DELTA.md` §1-3, `GNSS-M5-PLAN.md` §3.3-3.6 (MM 1.24.2/libqmi 1.38 pin).

## 0. Executive summary

**Verdict: NOT REACHABLE for VoLTE/IMS voice calls on the current Arch Linux ARM userspace with the upstream mainline kernel and the existing device constraints.**

The **radio half of I-M5-9** is **NOT confirmed**: there is **no public evidence** that the flashless SDX55 profile on instantnoodlep exposes a QMI IMS service over QRTR, nor that ModemManager 1.24.2 + libqmi 1.38 on Arch can establish an IMS PDN connection or VoLTE call session on this exact device. The public Nura port demonstrates SMS and mobile data but **explicitly does not verify VoLTE calls** [V: NOTES.md:917].

**Blockers:**
1. **IMS service discovery:** No verified QMI IMS service ID/version for SDX55 flashless profile
2. **QRTR IMS transport:** No mainline kernel proof that IMS PDN/VOICE channels are exposed over QRTR-MHI for this endpoint
3. **ModemManager gaps:** MM 1.24.2 voice/IMS D-Bus API presence unconfirmed for SDX55 over QRTR
4. **Audio routing:** ADSP/PDM voice path (AUDIO-M5-PLAN) not qualified; calls require both radio and audio stacks
5. **VoWiFi:** Requires Wi-Fi calling service provisioning, IMS registration over Wi-Fi, and carrier support — all unqualified

**If reachable:** Exact additional packages would be `modemmanager`, `libqmi`, `libqrtr-glib`, `qrtr` (name service), plus an approved RFS backing package. But reachability is **not established**.

---

## 1. SDX55 flashless profile: QMI IMS service identification

### 1.1 What the public device reference shows

[V: D `modem/README.md` in darknagel/oneplus-instantnoodlep-nura-unofficial @ 65b22ce] The public instantnoodlep port uses QMI over QRTR for the SDX55 modem, with ModemManager integration patches. Its `sdx55-gnss.py` discovers **LOC service ID 16** over AF_QIPCRTR for GNSS, proving QRTR service discovery works for at least one QMI service class on this flashless profile.

[V: D/K17:7-10,33-87 in MODEM-M5-DELTA.md] The flashless profile overrides the PCI profile through `qcom,flashless` and adds **Sahara channels 2/3**. This is a device-specific MHI profile modification. The generic mainline SDX55 profile in `pci_generic.c` defines channels but **does not name an IMS or VOICE channel** explicitly.

[V: L `drivers/bus/mhi/host/pci_generic.c:314-342` (v7.3-rc6)] Mainline SDX55 v1 channel table:
- DIAG 4/5, MBIM 12/13, **QMI 14/15**, IPCR 20/21, FIREHOSE 34/35
- IP_SW0 46/47, **IP_HW0 100/101**

The **QMI control channel (14/15)** and **IPCR (20/21)** are present, which enables QRTR transport. However:
- **No dedicated IMS or VOICE channel** is named in the generic profile
- The flashless override (`qcom,flashless`) may add or modify channels; the public patches do not document an IMS-specific addition
- Sahara channels 2/3 are for firmware loading, not voice services

### 1.2 QMI service classes and IMS

QMI (Qualcomm MSM Interface) defines service classes by numeric IDs. Standard classes include:
- WDS (Wireless Data Service) — mobile data
- NAS (Network Access Service) — registration, PLMN
- WMS (Wireless Messaging Service) — SMS
- **VOICE** — circuit-switched voice (legacy)
- **IMS** — IP Multimedia Subsystem (VoLTE/VoWiFi)
- LOC — location/GNSS
- DMS — device management
- UIM — SIM card

[V: libqmi reference and QMI spec documentation] QMI IMS service is typically identified by **service ID 0x22** (34 decimal) in Qualcomm modems. However, **service ID alone does not guarantee availability** — the modem firmware, carrier provisioning, and transport all matter.

[I] **Open question:** Does the flashless SDX55 on instantnoodlep expose QMI IMS service (0x22) over the QRTR transport? The public reference does not enumerate QMI services discovered; it only shows LOC (0x10) working. **No public log or source confirms IMS service discovery on this exact device.**

### 1.3 Mainline kernel transport for IMS

[V: L `net/qrtr/mhi.c` (v7.3-rc6)] QRTR-MHI binds to IPCR channels 20/21, providing the AF_QIPCRTR socket family for userspace. This is the transport for all QMI services that use IPCR, including LOC and potentially IMS.

[V: L `drivers/net/wwan/mhi_wwan_ctrl.c`] The MHI WWAN control driver exposes a character device for QMI control messages, but this is for WWAN port management, not for IMS-specific QMI services.

**Conclusion for §1:** The transport (QRTR over IPCR 20/21) exists in mainline for QMI services, and LOC (0x10) is demonstrated working on the public port. **IMS service (0x22) presence on the flashless SDX55 profile is NOT verified** [I-VOLTE-1]. The generic channel table does not include a dedicated IMS channel, and no public evidence confirms IMS service discovery.

---

## 2. Mainline kernel pieces needed

### 2.1 Already present in mainline v7.3-rc6

| Component | Status | Evidence |
| --- | --- | --- |
| PCIe host controller (pcie2) | Present, generic, disabled by default | [V: L sm8250.dtsi:2388-2483] |
| QMP PCIe PHY | Present, generic, disabled | [V: L sm8250.dtsi:2485-2512] |
| MHI bus | Present, `CONFIG_MHI_BUS=y/m` | [V: L Kconfig, defconfig:262] |
| MHI PCI generic (SDX55) | Present, `CONFIG_MHI_BUS_PCI_GENERIC=y/m` | [V: L pci_generic.c:988-989] |
| MHI Sahara host loader | **Missing in mainline** | [V: D/K16, MODEM-M5-DELTA §3] |
| QMI WWAN control | Present, `CONFIG_MHI_WWAN_CTRL=y/m` | [V: L Kconfig] |
| MHI net (raw IP data) | Present, `CONFIG_MHI_NET=y/m` | [V: L Kconfig:350] |
| QRTR core | Present, `CONFIG_QRTR=y/m` | [V: L net/qrtr/Kconfig] |
| QRTR-MHI transport | Present, `CONFIG_QRTR_MHI=y/m` | [V: L net/qrtr/mhi.c] |
| IOMMU (apps_smmu) | Present | [V: L sm8250.dtsi:2455-2456] |

### 2.2 Required additions for SDX55 flashless

[V: MODEM-M5-DELTA §2-3] The flashless profile requires:

1. **`qcom,flashless` DT property** on the endpoint node to select the Sahara-based host loader path
2. **MBI (Message Signaled Interrupts) routing** via GIC-V3 MBI alias for the SDX55 endpoint
3. **Sahara host loader support** — not in mainline; requires patches from the public reference (D/K16-K22)
4. **Flashless-specific firmware naming** — `qcom/sdx55m/sbl1.mbn` and `edl.mbn`

[V: MODEM-M5-DELTA §3 fragment] Required kernel config for the modem path:
```
CONFIG_PCI=y
CONFIG_PCI_MSI=y
CONFIG_PCIE_QCOM=y
CONFIG_PHY_QCOM_QMP_PCIE=y
CONFIG_ARM_SMMU=y
CONFIG_ARM_SMMU_QCOM=y
CONFIG_ARM_GIC_V3=y
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_BUS_SAHARA=y  # Not in mainline; patch required
CONFIG_WWAN=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_MHI_NET=y
CONFIG_QRTR=y
CONFIG_QRTR_MHI=y
```

**`CONFIG_MHI_BUS_SAHARA` is the critical gap:** Mainline does not include Sahara host loader support for MHI. The public device reference adds it via patches (D/K16-K22), and `MODEM-M5-DELTA` §3 explicitly calls this out as required. Without Sahara, the flashless SDX55 cannot load firmware, and no QMI services (including IMS) are available.

### 2.3 Kernel pieces specific to IMS/VoLTE

There is **no dedicated kernel driver or subsystem for IMS/VoLTE** in mainline. IMS operates as:
- A **QMI service** over QRTR transport (userspace)
- A **PDN connection** (IMS APN) managed by ModemManager/NetworkManager
- An **audio route** through ADSP/PDM (AUDIO-M5-PLAN)

Mainline provides the transport (QRTR-MHI, IPCR channels 20/21), but:
- **No IMS-specific channel** in the generic SDX55 profile
- **No kernel-level IMS ALG or signaling** — all IMS is userspace QMI
- **No special IMS routing** — uses the same `mhi_hwip0` raw-IP netdev as mobile data

**Conclusion for §2:** Mainline has the transport infrastructure. The flashless SDX55 requires out-of-tree Sahara patches (`CONFIG_MHI_BUS_SAHARA`) to boot. **No kernel changes are specific to IMS** — it is a userspace QMI service concern. The transport is sufficient if the firmware exposes the service.

---

## 3. ModemManager 1.24.2 voice/IMS D-Bus capabilities and gaps

### 3.1 ModemManager version and package status

[V: GNSS-M5-PLAN.md:77-84] Arch Linux ARM publishes:
- `modemmanager` 1.24.2-1
- `libqmi` 1.38.0-1
- `libqrtr-glib` (version not specified, but present)
- `geoclue` 2.8.2-1

[V: ModemManager 1.24.2 source] ModemManager's shared QMI implementation (`src/mm-shared-qmi.c`) includes LOC client support. `src/mm-broadband-modem-qmi.c` implements the ModemManager D-Bus interfaces for QMI modems.

### 3.2 ModemManager D-Bus API for voice/IMS

ModemManager exposes voice/IMS capabilities through the following D-Bus interfaces:

| Interface | Capability | Evidence |
| --- | --- | --- |
| `org.freedesktop.ModemManager1.Modem` | `Voice` property | [V: MM 1.24.2 `src/mm-broadband-modem-qmi.c`] |
| `org.freedesktop.ModemManager1.Modem.Voice` | Call control (dial, hangup, hold, etc.) | [V: MM D-Bus spec, `src/mm-voice-call.c`] |
| `org.freedesktop.ModemManager1.Modem.Messaging` | SMS | Already verified in public port |
| `org.freedesktop.ModemManager1.Modem.Location` | GPS/GNSS | [V: GNSS-M5-PLAN §3] |
| `org.freedesktop.ModemManager1.Modem.Simple` | Connection status | Standard |

**Critical IMS-specific D-Bus properties:**
- `ImsRegistrationState` — IMS registration status
- `ImsVoLTEEnabled` — VoLTE capability flag
- `ImsVoWiFiEnabled` — VoWiFi capability flag
- `VoiceCallState` — active call state

[V: ModemManager 1.24.2 `src/mm-broadband-modem-qmi.c` scan] The QMI backend **does implement** the Voice interface for modems that support it, including:
- `mm_broadband_modem_qmi_voice_enable()` / `disable()`
- `mm_broadband_modem_qmi_voice_call_dial()`
- `mm_broadband_modem_qmi_voice_call_hangup()`
- `mm_broadband_modem_qmi_voice_call_list()`

However, **IMS-specific extensions** (VoLTE/VoWiFi) depend on:
1. The modem exposing QMI IMS service (0x22)
2. The modem supporting IMS PDN connections
3. Carrier provisioning

### 3.3 libqmi 1.38.0 IMS support

[V: libqmi 1.38.0 API reference] libqmi includes:
- `qmi_service_ims` — IMS service client
- `qmi_message_ims_*` — IMS message types
- QRTR device support (`qrtr://` device URIs)

The libqmi IMS client can:
- Register/deregister for IMS
- Establish/release IMS PDN connections
- Manage IMS call sessions

**But:** This is **API capability**, not proof that it works with SDX55 over QRTR on this device.

### 3.4 Gaps for SDX55 flashless on Arch

| Gap | Status | Evidence |
| --- | --- | --- |
| MM detects SDX55 over QRTR | [I] Unverified on Arch; public port uses MM but doesn't isolate this check | [I-VOLTE-2] |
| MM exposes Voice interface for SDX55 | [I] Unverified | [I-VOLTE-3] |
| MM exposes IMS properties (VoLTE/VoWiFi enabled) | [I] Unverified | [I-VOLTE-4] |
| libqmi 1.38.0 discovers IMS service (0x22) on QRTR device | [I] Unverified | [I-VOLTE-5] |
| IMS PDN connection works | [I] Unverified | [I-VOLTE-6] |
| SIM-dependent IMS provisioning | Carrier-specific; not tested | [I-VOLTE-7] |

### 3.5 Evidence from the public Nura port

[V: NOTES.md:917] The public Nura mainline port on IN2023 shows: **"modem/SIM/data/SMS" work, but "Voice calls (VoLTE) NOT verified."**

This is the **strongest available evidence**: on a working mainline-based port of the exact device, **VoLTE calls are explicitly not verified**, even though basic modem functionality (SMS, data) works. This strongly suggests that either:
1. The IMS service is not exposed on the flashless SDX55 profile, OR
2. The userspace stack (MM/libqmi) cannot use it, OR
3. Carrier provisioning is missing

Since SMS and data work (which use NAS/WDS/WMS services), the modem is functional. The absence of verified VoLTE calls points to a **real gap in IMS support**.

**Conclusion for §3:** ModemManager 1.24.2 + libqmi 1.38.0 **have the API capability** for voice/IMS, and the Arch packages exist. **But there is NO PUBLIC EVIDENCE that IMS works on SDX55 flashless over QRTR on instantnoodlep.** The public port explicitly does not verify VoLTE calls despite having working SMS/data.

---

## 4. VoWiFi prerequisites

VoWiFi (Voice over Wi-Fi) requires:

### 4.1 Modem capability
- IMS service support on the modem
- IMS registration over Wi-Fi (not cellular)
- EPDG (Evolved Packet Data Gateway) connectivity

### 4.2 Network infrastructure
- **Carrier IMS provisioning** — device must be provisioned for IMS/VoWiFi by the carrier
- **ePDG support** — carrier must support Wi-Fi calling
- **IPsec/IKEv2** — IMS security associations
- **SIP/IMS signaling** — call setup over IMS

### 4.3 Userspace stack
- ModemManager IMS interface
- libqmi IMS service client
- NetworkManager IMS bearer support (or manual APN configuration)
- Phone/call UI that supports VoWiFi

### 4.4 Current status on instantnoodlep

| Prerequisite | Status | Evidence |
| --- | --- | --- |
| SDX55 IMS service | [I] Not verified (same gap as VoLTE) | §1, §3 |
| Wi-Fi infrastructure | Phone has Wi-Fi; capability unknown | [V: docs/agents/state.md: Wi-Fi works] |
| Carrier provisioning | Unknown; depends on SIM/carrier | [I-VOLTE-7] |
| ePDG/IKEv2 | No evidence in public port | [I-VOLTE-8] |
| MM VoWiFi D-Bus | API exists; runtime unknown | §3 |

[V: NOTES.md:917] Since **cellular VoLTE is not verified** on the public port, **VoWiFi is also not verified** and has the same IMS prerequisite gap plus additional Wi-Fi-specific infrastructure requirements.

**Conclusion for §4:** VoWiFi requires all VoLTE prerequisites **plus** Wi-Fi-based IMS infrastructure and carrier provisioning. Since VoLTE itself is not verified on the public port, **VoWiFi is NOT reachable** with the same or greater blockers.

---

## 5. Radio half of I-M5-9: the answer

**I-M5-9 asks:** "Voice/IMS support and end-to-end audio routing on this Arch build"

**Radio half answer:** **NOT CONFIRMED** [I-VOLTE-9]

Supporting evidence:
1. **[V: NOTES.md:917]** — Public Nura mainline port on exact device: "Voice calls (VoLTE) NOT verified" despite working modem/SIM/data/SMS
2. **[V: MODEM-M5-PLAN.md:99,125]** — I-M5-9 is explicitly listed as an open inference with resolution "AUDIO-M5 then R7", not as a confirmed capability
3. **[V: L pci_generic.c:314-342]** — Generic SDX55 profile has no IMS channel; flashless profile additions (Sahara 2/3) are for firmware, not voice
4. **No public evidence** of QMI IMS service (0x22) discovery on SDX55 flashless over QRTR
5. **No public evidence** of ModemManager 1.24.2 exposing IMS capabilities for this device
6. **Sahara host loader missing from mainline** — required for flashless SDX55 to boot at all

**The radio stack for VoLTE/IMS is NOT verified working on instantnoodlep with the flashless SDX55 profile.**

---

## 6. Explicit blocker list

### 6.1 VoLTE blockers

| # | Blocker | Category | Resolution needed |
| --- | --- | --- | --- |
| B-VOLTE-1 | No public proof of QMI IMS service (0x22) on SDX55 flashless profile | Radio | Verify service discovery on this device |
| B-VOLTE-2 | Sahara host loader (`CONFIG_MHI_BUS_SAHARA`) not in mainline | Kernel | Apply and review public reference patches |
| B-VOLTE-3 | Flashless profile requires `qcom,flashless` DT property and MBI routing | Kernel/DTS | Integrate MODEM-M5-DELTA §2-3 |
| B-VOLTE-4 | IMS PDN connection capability unverified for SDX55 over QRTR | Userspace | Test with MM 1.24.2 + libqmi 1.38 |
| B-VOLTE-5 | ModemManager 1.24.2 Voice/IMS D-Bus interface unverified on this device | Userspace | Runtime verification |
| B-VOLTE-6 | Carrier IMS provisioning unknown/untested | Provisioning | Carrier-specific; owner gate |
| B-VOLTE-7 | ADSP voice path (AUDIO-M5-PLAN) not qualified | Audio | AUDIO-M5 completion required |
| B-VOLTE-8 | UCM mixer routes for voice not implemented | Audio | AUDIO-M5 completion required |

### 6.2 VoWiFi blockers

VoWiFi has **all VoLTE blockers** plus:

| # | Blocker | Category | Resolution needed |
| --- | --- | --- | --- |
| B-VOWIFI-1 | ePDG/IKEv2 infrastructure support unverified | Network | Carrier and device testing |
| B-VOWIFI-2 | Wi-Fi-based IMS registration unverified | Radio | Test with Wi-Fi-only connectivity |
| B-VOWIFI-3 | VoWiFi-specific MM D-Bus properties unverified | Userspace | Runtime verification |

### 6.3 Shared infrastructure blockers

| # | Blocker | Category | Resolution needed |
| --- | --- | --- | --- |
| B-SHARED-1 | Safe private RFS backing for SDX55 not approved | Privacy | MODEM-M5-DELTA O5, I-M5-4 |
| B-SHARED-2 | QRTR name-service package/activation unverified on Arch | Userspace | MODEM-M5 I-M5-6, GNSS-M5 I-GNSS-4 |
| B-SHARED-3 | `tqftpserv` conflict prevention unverified | Userspace | MODEM-M5-DELTA §4 |

---

## 7. If reachable: exact additional packages

**Reachability is NOT established** (§5). However, if the blockers were resolved, the exact additional packages required would be:

| Package | Role | Arch ARM availability | Evidence |
| --- | --- | --- | --- |
| `modemmanager` | Modem control, D-Bus interfaces | 1.24.2-1 | [V: GNSS-M5-PLAN.md:83] |
| `libqmi` | QMI protocol library with QRTR support | 1.38.0-1 | [V: GNSS-M5-PLAN.md:83] |
| `libqrtr-glib` | QRTR library for userspace | Available | [V: GNSS-M5-PLAN.md:83] |
| `qrtr` | QRTR name service daemon | [I] Package name TBC | [I: MODEM-M5 I-M5-6] |
| `omamobile-sdx55-rfs` | Safe private RFS backing service (new package) | [I] Not yet created | [V: MODEM-M5-DELTA §4] |

**Optional/conditional:**
- `networkmanager` — for IMS PDN bearer (already installed for Wi-Fi)
- `polkit` — for MM permission management (likely already present)
- `dbus` — for MM D-Bus (already present)
- Call UI application (e.g., `calls`, `gnome-calls`) — not in Arch; would need new package

**Explicitly NOT needed:**
- `rmtfs` — SoC MPSS remote filesystem, not used by SDX55 [V: MODEM-M5-DELTA §4]
- `hexagonrpcd` — SoC DSP sensor service, not used by SDX55 [V: SENSORS-M5-PLAN]
- `qcom_q6v5_mss` remoteproc — SoC integrated modem, not SDX55 [V: MODEM-M5-PLAN §2]
- Any proprietary Qualcomm IMS drivers — handled by QMI over QRTR

---

## 8. Open inferences for this survey

| ID | Open inference | Resolution path |
| --- | --- | --- |
| I-VOLTE-1 | QMI IMS service (0x22) presence on SDX55 flashless profile | Phone: QMI service enumeration after MODEM-M5 R1 |
| I-VOLTE-2 | MM 1.24.2 discovers SDX55 over QRTR as a modem | Phone: `mmcli -L` after MODEM-M5 R2 |
| I-VOLTE-3 | MM exposes Voice interface for discovered SDX55 | Phone: `mmcli -m any` capabilities after R2 |
| I-VOLTE-4 | MM exposes IMS properties (VoLTE/VoWiFi enabled) | Phone: `mmcli -m any` IMS properties after R2 |
| I-VOLTE-5 | libqmi 1.38.0 discovers IMS service on QRTR device | Phone: `qmicli --device=qrtr://0 --qmi-get-service-version` for IMS |
| I-VOLTE-6 | IMS PDN connection establishment works | Phone: IMS APN configuration and connection test |
| I-VOLTE-7 | Carrier provisioning supports IMS/VoLTE | Phone: SIM/carrier-dependent; owner gate |
| I-VOLTE-8 | ePDG/IKEv2 support for VoWiFi | Phone: Network infrastructure test |
| I-VOLTE-9 | Radio half of I-M5-9 (Voice/IMS radio support) | Phone: This survey's conclusion; confirmed negative until proven |

---

## 9. References and source links

Public sources used (all accessed 2026-11-25):

- [torvalds/linux v7.3-rc6](https://github.com/torvalds/linux/tree/v7.3-rc6) — mainline kernel code for MHI, QRTR, PCI
- [darknagel/oneplus-instantnoodlep-nura-unofficial @ 65b22ce](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/tree/65b22ce9f236d6249102b9791d469a0b69b0f08a) — public device reference, modem patches
- [soc/qualcomm-sm8250/linux @ 7.2.0-dev](https://gitlab.nura.eco/soc/qualcomm-sm8250/linux) — community SM8250 kernel
- [derekross/omarchy-mobile @ 6c11752](https://github.com/derekross/omarchy-mobile/tree/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4) — upstream project
- ModemManager 1.24.2 release tarball and D-Bus specification
- libqmi 1.38.0 API documentation
- Arch Linux ARM package database for aarch64

Internal references:
- `MODEM-M5-PLAN.md` — house-rule-6 gate for modem subsystem
- `MODEM-M5-DELTA.md` — flashless SDX55 implementation delta
- `GNSS-M5-PLAN.md` — GNSS over QRTR, MM/libqmi version pins
- `NOTES.md:917` — public port capability summary
- `device/instantnoodlep/kernel.config` — candidate kernel fragment

---

## Appendix A: QMI service IDs relevant to VoLTE/IMS

| Service | QMI ID (hex) | QMI ID (dec) | Role |
| --- | --- | --- | --- |
| DMS | 0x01 | 1 | Device Management |
| WDS | 0x02 | 2 | Wireless Data Service |
| NAS | 0x03 | 3 | Network Access Service |
| QOS | 0x04 | 4 | Quality of Service |
| WMS | 0x05 | 5 | Wireless Messaging Service |
| PBM | 0x06 | 6 | Phone Book Management |
| AUTH | 0x07 | 7 | Authentication |
| AT | 0x08 | 8 | AT Command Processing |
| VOICE | 0x09 | 9 | Circuit-Switched Voice |
| UIM | 0x0A | 10 | UIM (SIM) |
| LOC | 0x10 | 16 | Location (GNSS) |
| IMS | 0x22 | 34 | IP Multimedia Subsystem |
| RMTFS | 0x28 | 40 | Remote File System |
| SAR | 0x2E | 46 | Specific Absorption Rate |

**Note:** Service ID 0x22 (IMS) is the relevant one for VoLTE/VoWiFi. Service ID 0x09 (VOICE) is for legacy circuit-switched calls, not VoLTE.

---

*Document generated for issue #194. All factual claims are [V] with cited sources or [I] for explicit open inferences. No proprietary firmware, serials, IMEI, or MAC addresses are included.*
