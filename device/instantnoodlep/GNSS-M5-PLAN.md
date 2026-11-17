<!-- SPDX-License-Identifier: MIT -->
# GNSS-M5-PLAN: SDX55 location over QRTR on instantnoodlep

House-rule-6 gate for the GNSS subsystem on the OnePlus 8 Pro IN2023. This
is a documentation-only plan: no code, kernel config, firmware or device
state is changed here.

- Date: 2026-11-17. Branch: `modem-gnss`.
- Read first: `AGENTS.md`, `MODEM-M5-PLAN.md`, `FIRMWARE-PLAN.md` and
  `firmware.map`, `AUDIO-M5-PLAN.md`, `SENSORS-M5-PLAN.md`, `NOTES.md`,
  `DTBO-PLAN.md`, and `docs/agents/state.md`.
- Scope: GNSS service from the external SDX55, its QMI LOC interface over
  QRTR/MHI, firmware dependency, location userspace and gated checks.
- Safety: only RAM boot first; never flash modem or NV partitions, never
  write `super` or `_a`; firmware comes from the owner's verified OTA at
  install time and files with identity/calibration content remain private
  (AGENTS.md rules 3-4, 8). A package/profile write to `userdata` requires
  explicit owner approval and rollback.

## 1. Source pins and current state

- `L/` = [torvalds/linux v7.3-rc6](https://github.com/torvalds/linux/tree/v7.3-rc6),
  including `drivers/gnss/`, `drivers/bus/mhi/host/pci_generic.c`,
  `drivers/net/wwan/`, `net/qrtr/`, and the SM8250 DTS.
- `C/` = public community SM8250 kernel
  [`soc/qualcomm-sm8250/linux`, tag `7.2.0-dev`](https://gitlab.nura.eco/soc/qualcomm-sm8250/linux),
  cited by DTS-PORT-PLAN §1-2.3.
- `D/` = public OnePlus 8 Pro reference
  [darknagel/oneplus-instantnoodlep-nura-unofficial](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial):
  README, `modem/README.md`, `modem/sdx55-gnss.py`, `modem/install.sh`,
  and pmaports patches 0018-0020. Facts are behavior precedent only; do not
  copy code or vendor files.
- `U/` = [derekross/omarchy-mobile](https://github.com/derekross/omarchy-mobile),
  including `packages/omamobile-gnss` and upstream `AGENTS.md`/
  `CONTRIBUTING.md`.
- `FW/` = `device/instantnoodlep/firmware.map`, names only.

[V] K3 combo is on `boot_b`; it contains a test-only match for the stock
overlay's live `qcom,kona` compatible, so `qcom_pd_mapper` recognizes the
current machine. The phone still has stock `dtbo_b`; neutral DTBO testing is
parked after ABL rejected both attempted forms [V: `docs/agents/state.md`
22-25, 35-37; DTBO-PLAN §6; learning `l-48e0c482`]. GNSS has not been tested
on this kernel [V: `docs/agents/state.md:25`]. The temporary Kona patch is
for testing only and must never be upstreamed.

## 2. Hardware path and mainline status

| Item | Finding | Evidence |
| --- | --- | --- |
| GNSS owner | GNSS is a service of the external SDX55 modem, reached from SM8250 over PCIe/MHI and QRTR. It is not a GNSS receiver attached to a host UART, I2C or USB bus. | [V: D public README and modem README identify SDX55 on instantnoodlep; D `sdx55-gnss.py` looks up QRTR service 16 (`LOC`) and starts LOC tracking; L `pci_generic.c` names the SDX55 MHI device and channel profile.] |
| Distinguish from SM8250 MPSS | Do not load the external modem with `qcom_q6v5_mss`/MPSS. That remoteproc driver models an SoC-integrated Q6 modem path; this handset's public support uses the SDX55 PCI endpoint and MHI SBL loader. SM8250 ADSP/CDSP/SLPI remoteprocs are separate and matter to audio/sensors, not GNSS location transport. | [V: L `drivers/remoteproc/qcom_q6v5_mss.c`, `drivers/bus/mhi/host/pci_generic.c`; D MHI patch series 0018-0020.] |
| Control and location | SDX55's generic MHI profile includes QMI channel 14/15 and IPCR 20/21. QRTR-MHI exposes the IPCR transport; the public device helper discovers LOC service ID 16 over AF_QIPCRTR and consumes NMEA indications. | [V: L `pci_generic.c` `modem_qcom_v1_mhi_channels[]`; L `net/qrtr/mhi.c`; D `modem/sdx55-gnss.py`.] |
| No direct NMEA MHI channel | The mainline SDX55 profile does not name an `NMEA` MHI channel. `mhi_wwan_ctrl` can expose a WWAN NMEA port for devices whose channel table includes one, but that is not the SDX55 profile here. | [V: L `pci_generic.c` SDX55 channel list; L `drivers/net/wwan/mhi_wwan_ctrl.c` match table.] |
| Generic GNSS class | Mainline `GNSS` supplies a character-device core and drivers for MediaTek serial, SiRF serial, u-blox serial and USB receivers; v7.3-rc6 has no Qualcomm MHI/QRTR/SDX55 LOC driver. A `/dev/gnss0` node is therefore not expected without a new driver/bridge. | [V: L `drivers/gnss/Kconfig`, `drivers/gnss/Makefile`.] |
| Mainline networking stack | Mainline has QRTR and QRTR-MHI transport support and MHI WWAN control/data drivers. Kernel transport support does not by itself provide an application-visible GNSS API or `/dev/gnss-sdx55`. | [V: L `net/qrtr/Kconfig`, `drivers/net/wwan/Kconfig`, `drivers/bus/mhi/host/pci_generic.c`.] |
| GNSS verification precedent | Public device documentation reports GPS fix without SIM. Its helper talks QMI LOC directly over QRTR and relays NMEA to a pseudo-terminal `/dev/gnss-sdx55`; `gpsd` consumes that endpoint. This is not evidence that the current Arch ModemManager build works. | [V: D `modem/README.md`, `modem/sdx55-gnss.py`.] |

The current M5 test stack must use K3 combo while the stock DTBO rewrites
root compatible to Kona. MHI GNSS itself does not require PDM mapping; if
GNSS is requested from ModemManager after SIM unlock, use the K3 combo test
image so the shared machine match remains available. Do not install a
neutral DTBO as a GNSS prerequisite.

## 3. Userspace design

Preferred integration is to expose GNSS on demand through the modem's
ModemManager `Modem.Location` interface, then let GeoClue consume the
ModemManager source for desktop/app location. ModemManager documents raw
GPS/NMEA and parsed GPS location sources, while GeoClue has a ModemManager
provider [V: ModemManager `Modem.Location` API; GeoClue `gclue-modem-manager.c`].
Whether this Arch ModemManager package can open SDX55's QRTR LOC service,
especially before SIM registration, remains [I-GNSS-1]. Do not assume it
from generic QMI support.

If the installed ModemManager cannot provide the LOC source, the fallback
is a small, opt-in instantnoodlep GNSS service that owns QRTR LOC, converts
NMEA indications to a local PTY, and offers an explicit NMEA endpoint for
gpsd clients. This follows the public device's demonstrated architecture
without copying its code. Do not run a direct LOC helper and ModemManager's
LOC client simultaneously: only one process may own a service/session.
Mainline has no direct SDX55 GNSS char-device driver; any future kernel
WWAN-to-GNSS bridge would be a separate upstreamable kernel proposal, not
an implicit part of this package.

| Component | Planned role | Evidence / status |
| --- | --- | --- |
| ModemManager | First check for LOC capability and an on-demand `Modem.Location` API; use `Setup`/`GetLocation` through its D-Bus interface if supported. Disable it before trying a separate LOC owner. | API methods and GPS NMEA/raw sources are public [V: ModemManager D-Bus Location API]. SDX55 QRTR behavior in current Arch build [I-GNSS-1]. |
| GeoClue | Preferred app-facing broker when ModemManager exposes GPS; user-level location permission remains opt-in. | GeoClue includes ModemManager provider [V: GeoClue `src/gclue-modem-manager.c`]. Exact package/config in rootfs [I-GNSS-2]. |
| gpsd | Optional consumer for legacy GPS clients. It needs an NMEA stream, so use only a GNSS-service-owned PTY/endpoint; no raw MHI channel named NMEA exists in the mainline SDX55 descriptor. | Public reference uses `gpsd -n /dev/gnss-sdx55` [V: D README]; Arch gpsd endpoint and access policy [I-GNSS-3]. |
| `omamobile-gnss` | Reuse project on-demand GNSS UX/GeoClue controls only if it can select an SDX55 profile. Current package describes Google's GNSS HAL in a vendor chroot for other hardware; do not run its vendor extractor or imply that Android GNSS libraries are needed here. | [V: U `packages/omamobile-gnss/PKGBUILD`, `install`; instantnoodlep profile [I-GNSS-2].] |
| `qmicli` / libqmi | Diagnostics only when ModemManager is stopped and has released QRTR/QMI clients. Avoid competing clients during normal use. | [V: libqmi LOC API has LOC start/stop, NMEA and position operations; device helper uses LOC over QRTR; ownership sequence [I-GNSS-4].] |

## 4. Firmware and assistance data

The receiver runs inside the SDX55. The host MHI PCI driver requests
`qcom/sdx55m/sbl1.mbn` for modem boot; there is no separate `sdx55 GNSS`
kernel firmware request or GNSS blob row in `firmware.map` today [V: L
`pci_generic.c` SDX55 descriptor; FW map:29-43]. Firmware/member presence
must be checked by name from the owner's exact verified OTA in FIRMWARE-PLAN
F1-F6. Do not import binaries from the public reference project or
linux-firmware. Additional SDX55 GNSS/AMSS requirements beyond SBL and any
normal modem set are [I-GNSS-5].

QMI LOC supports operation mode, NMEA, position and assistance operations
in libqmi [V: libqmi LOC API reference]. This plan starts with standalone GNSS only. Do not configure SUPL,
download XTRA/orbit data, inject location, or enable assisted modes until
their endpoint, privacy behavior, data source and user opt-in are reviewed.
The device clock can be wrong after boot [V: NOTES.md:119-121]; do not inject
system time into the modem unless the host time is known accurate.

Private RFS/EFS/NV is not firmware. Public device setup uses a QRTR file
service and local private state; the exact files it needs and their safe
source are unresolved [I-GNSS-6, MODEM-M5-PLAN I-M5-4]. No GNSS run may read
or write modem partitions, `persist`, or per-device identity/calibration
content. Runtime backing must be isolated, private, and owner-approved.

## 5. Kernel and package plan (future work only)

| Area | Candidate | Gate / decision |
| --- | --- | --- |
| PCIe/MHI | Enable only the modem port verified by MODEM-M5 O2; mainline `pci_generic` brings up SDX55 and exposes IPCR/QMI channels | MODEM-M5 O2-O4 and R1 first; no modem-child DTS node |
| QRTR | `CONFIG_QRTR`, `CONFIG_QRTR_MHI`, and userland QRTR name service | MODEM-M5 O6/R2; record unit/package names |
| GNSS core | No new kernel driver initially; no `CONFIG_GNSS` requirement for QMI LOC-to-ModemManager. If project needs a kernel GNSS char device, scope an upstream design separately. | O1 confirms v7.3-rc6 driver inventory; do not claim `/dev/gnss0` |
| Userspace | First test stock Arch ModemManager location. Only if unsupported, package an opt-in LOC→NMEA PTY bridge and gpsd integration, under GeoClue/on-demand permissions. | O2/O3 and R1-R4; don't copy public script |
| Services | Start QRTR name service and approved RFS only when modem use is requested; no boot-autostart GNSS until opt-in/power behavior is tested. Keep `tqftpserv` from conflicting with RFS. | MODEM-M5 O5/O6 and R2 |

## 6. Gated runbook

All O gates are offline; phone steps R1-R6 are run by the owner only. RAM
boot is first. No fastboot flash, erase, set-active, DTBO change or writes
to modem/NV/persist. Stock DTBO stays installed; the current test boot must
use the K3 combo Kona-match image. After a refused RAM boot, cold-reboot to
bootloader before retry [V: NOTES.md 2026-11-16 R1 consequence]. Captures
remain in gitignored `captures/<date>/m5/gnss/`, and location coordinates
must not be added to notes, commits or issues.

### 6.1 Offline gates

| Gate | Command/review | Expect/pass | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 State | M1b/B5 and M3 status current; K3 combo test-only patch documented; stock DTBO remains; MODEM-M5 gates are available | no neutral-DTBO prerequisite; phone test image provenance recorded | missing M1b state or image uses an unreviewed DTBO | no changes; return to owning plan |
| O1 Mainline audit | Check L `drivers/gnss/Kconfig`, `Makefile`, `drivers/net/wwan/Kconfig`, SDX55 channel table, `qrtr/mhi.c`; compare D GNSS script/docs without copying code | no SDX55 GNSS driver/NMEA MHI channel in mainline; QRTR LOC path is the evidenced device route | source shows a changed channel/driver status | revise plan before implementation |
| O2 Userspace capability | On build host, inspect exact ModemManager/libqmi/GeoClue versions, available MM location source flags, QRTR plugin and SIM-unlock behavior; run `mmcli --help-all` and package tests offline | commands/API verified; choose MM-first or one helper fallback | uncertain LOC transport or duplicate service owner | no GNSS package change |
| O3 Interface design | Document data path for MM/GeoClue and optional gpsd NMEA endpoint; test any bridge only against recorded synthetic NMEA and mock QRTR packets | on-demand lifecycle, endpoint permissions, shutdown, and one-owner lock are explicit | always-on location or multiple LOC clients | discard prototype |
| O4 Firmware/RFS | Run FIRMWARE-PLAN name-only check for SDX55 member names. Review RFS backing and data privacy with MODEM-M5 O5 | no firmware bytes/identity in git; no protected partition access; rollback covers persistent staging | RFS requires protected-partition access or no safe private source | stop and ask owner; no phone step |
| O5 Package checks | `tools/pr-check origin/main`; package `test/all` if package is later written; verify GeoClue/gpsd optional dependencies and no default-on location service | passes; opt-in remains default | test failure or GNSS service auto-starts | revert package draft |
| O6 Release | Review O0-O5, modem plan gates, exact command syntax, privacy and open [I]s with owner | written approval for one RAM boot | any gate missing | do not boot |

### 6.2 Owner gates (phone; RAM boot first)

Placeholders are private; never run an unfilled block. Keep coordinate and
satellite output private; record only pass/fail, time-to-fix bucket and
kernel/package version.

| # | Command block / step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G1 | Fastboot read-only baseline: `fastboot -s {{SERIAL}} devices`, `getvar current-slot`, slot flags | one device; slot B active/successful, flags match current M1b state | unexpected slot/flags | reboot to current installed system and reconcile M1b |
| R1 | `fastboot -s {{SERIAL}} boot {{M5_GNSS_IMG}}`; SSH read `uname -r`, live compatible, `lspci -nn`, QRTR/MHI service status and filtered dmesg | K3 combo test image boots; SDX55 is visible on expected PCIe port; QRTR transport is available; no firmware error | wrong root, missing SDX55, RFS/privacy violation, transport error | wait for watchdog; refused boot => cold-reboot bootloader before any retry |
| R2 | With reviewed ModemManager path: `mmcli -L`, `mmcli -m any`, `mmcli -m any --location-status`; do not yet enable tracking | modem reports Location interface and GPS NMEA/raw capability; record whether SIM is required | no location interface/capability, MM crashes, or SIM state ambiguous | stop MM test; `reboot -f`; don't start direct QRTR helper in same boot |
| R3 | If R2 supports it, run `mmcli -m any --location-enable-gps-nmea`; query `mmcli -m any --location-get` at 5 s intervals outdoors with sky view; never save/print coordinates to repo logs | NMEA GPS source appears and reaches a fix; no network assistance requested; record only pass/fail and a coarse time-to-fix bucket | no capability, error, or only cell-id location | `mmcli -m any --location-disable-gps-nmea`; stop tracking |
| R4 | If R2 fails but O2/O3 approved fallback, stop ModemManager's LOC client; start the single QRTR LOC bridge; check its owned PTY and `timeout 60 gpspipe -r -n 10 {{NMEA_TTY}}` | NMEA sentences arrive; no competing LOC client; service exits/stops cleanly | MM still owns LOC, no NMEA, service loops, or unexpected location disclosure | stop bridge and gpsd; remove temporary runtime PTY; reboot if modem is wedged |
| R5 | If GeoClue is part of approved package: request location from the approved test client and confirm user/session permission prompt; stop client, then check MM GNSS is disabled | GeoClue returns the same GNSS source; service ceases when no clients remain | location available without request/permission or keeps running after client exits | revoke/stop GeoClue test; disable GNSS; reboot if needed |
| R6 | Boot installed slot-B system (boot only); repeat the selected R2/R3 or R4 path; compare fastboot slot flags to G1 | same behavior and clean shutdown; slot flags unchanged | regression or flag change | stop; leave `boot_b` as-is and follow M1b recovery instructions |

## 7. Open [I]s

| ID | Open inference | Resolution |
| --- | --- | --- |
| I-GNSS-1 | Whether current Arch ModemManager exposes SDX55 LOC over QRTR and remains healthy across SIM unlock | O2, then R2/R3 |
| I-GNSS-2 | GeoClue package/config and current project `omamobile-gnss` can use the MM location backend without Google's vendor GNSS chroot | O2/O5 and R5 |
| I-GNSS-3 | gpsd package and local NMEA PTY permissions/endpoint | O2, R4 |
| I-GNSS-4 | Whether `qmicli` diagnostics can use LOC over QRTR on this stack without conflicting with MM; exclusive ownership required | O2; isolated R4 fallback only |
| I-GNSS-5 | Exact SDX55 firmware/RFS members required for GNSS; whether normal modem boot firmware alone suffices | MODEM-M5 O5, firmware name audit only |
| I-GNSS-6 | Safe private RFS backing source and runtime write behavior | MODEM-M5 I-M5-4; no test until approved |
| I-GNSS-7 | Standalone GNSS works without SIM on this IN2023 and its antenna has usable sky visibility | R2-R4; public reference is precedent only |
| I-GNSS-8 | Whether system clock is accurate enough for any future assistance-time injection | check time source; never inject if uncertain |
| I-GNSS-9 | Battery/power cost of a 1 Hz LOC session and whether suspend requires stopping it | measure only after basic fix and power plan review; default service remains off |

## 8. Definition of done

O0-O6 pass and one approved path succeeds in R1-R6: ModemManager exposes
the SDX55 GNSS source to GeoClue, or the single approved fallback feeds a
GPSD-compatible NMEA endpoint. GNSS is user-requested, stops when no client
needs it, and uses no unapproved assistance service. No slot flag changes,
protected partition access, coordinates or private modem data enter git.
Record date and kernel/userspace versions in NOTES.md. A GPS fix is not
claimed until it is measured on the owner's handset.
