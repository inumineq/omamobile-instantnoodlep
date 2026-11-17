<!-- SPDX-License-Identifier: MIT -->
# MODEM/GNSS M5 implementation delta and first RAM gate

2026-11-17; documentation and candidate DTS/config only. No kernel built,
no phone accessed, no firmware copied. This delta supersedes the generic
SDX55 assumptions in MODEM-M5-PLAN and is shared by GNSS-M5-PLAN.

## 1. Source ledger and readiness

[V] `D` below is the public device reference pinned at
[`65b22ce9f236d6249102b9791d469a0b69b0f08a`](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/tree/65b22ce9f236d6249102b9791d469a0b69b0f08a).
`D/K16`, `K17`, `K18`, `K19`, `K26`, `K31` mean the correspondingly
numbered files in `kernel-patches/`; `D/P19` means `pmaports-patches/0019-*`.
[V] `U` is omarchy-mobile at `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
([source](https://github.com/derekross/omarchy-mobile/tree/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4)).
Line numbers count the patch file itself, not its resulting C file.
[V] `C` is the community board DTS at commit
`3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9`,
`arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`
in [soc/qualcomm-sm8250/linux](https://gitlab.nura.eco/soc/qualcomm-sm8250/linux).
[V] `L` is Linux v7.3-rc6; references below link to public source.

[V: D/K17:7-10,33-87] This board's public working implementation describes
an **external flashless SDX55**, with a subsystem-ID collision with a Foxconn
module. It overrides the PCI profile through `qcom,flashless`, adds Sahara
channels 2/3, and uses a host image server. PCI ID alone does not select
that profile. A generic PCIe-enable patch is therefore an enumeration
experiment, not a complete modem implementation.

[V: D/K16:244-262; D/modem/install.sh:29-35,90-93] The reference also serves
private EFS/NV/DDR data and handles EFS sync via devcoredump. Those operations
are outside our safety model. **[I] Full AMSS, ports and `mmcli -L` success
are blocked until a safe private-state source and bounded runtime-only sync
policy are approved.** Do not substitute empty EFS, distro firmware, OTA
`mdmddr.mbn`, or the reference installer. No protected partition reads or
writes are requested by this delta.

[I] The following is ready for a kernel implementer to review and split
into binding, loader/profile, then board commits. It is not a claim that
these patches alone will boot the modem. Stock-DTB wiring comparison,
Sahara implementation review, schema validation and the private-state gate
remain prerequisites; do not apply the reference debug series wholesale.

## 2. Exact board candidate (GPL-2.0-only DTS content)

[V: C:718-725,364-388] Enable `pcie2` and `pcie2_phy`; reuse existing PM8150
L5A 880000 uV and L9A 1200000 uV. No new regulator or voltage change.
[V: L `arch/arm64/boot/dts/qcom/sm8250.dtsi:2455-2467,5877-5896`]
Keep inherited stream IDs `0x1d00/0x1d01`, PCI reset `GCC_PCIE_2_BCR`,
PHY reset `GCC_PCIE_2_PHY_BCR`, PERST TLMM85 active low, CLKREQ TLMM86
function `pci_e2`, and wake TLMM87 active low. PERST/wake belong to
`pcie@0`, not the host node. [I] Their IN2023 wiring is still O2, not proven
by a generic SoC DTS. Preserve the already working `apps_smmu` configuration.

[V: L `sm8250.dtsi:2467-2468`] The SoC DTS declares `perst-gpios` TLMM85
`GPIO_ACTIVE_LOW` and `wake-gpios` TLMM87 `GPIO_ACTIVE_HIGH` on the host node.
The candidate deletes both and puts `reset-gpios` TLMM85 `GPIO_ACTIVE_LOW`
and `wake-gpios` TLMM87 `GPIO_ACTIVE_LOW` on the root port, i.e. it also
inverts the inherited WAKE# polarity. [I] That inversion is this delta's
claim, not something the SoC DTS supports; gate A must confirm it against the
stock DTBO. Wrong WAKE# polarity costs wake events, not enumeration.

[V: L `drivers/pci/of.c:175-185,140-163`] The endpoint `reg` first cell
`0x10000` is not a devfn: `of_pci_get_devfn()` masks it to `(reg[0] >> 8) & 0xff`,
which is 0, so the node attaches to the device at bus 1, devfn 0 and
`qcom,flashless` reaches the driver through `device_property_read_bool()`.
Keep the value as the reference has it; a plain `0x0` would also match devfn 0
but would lose the bus-1 encoding the reference uses.

[V: D/K18:18-28; D/K19:18-34] The device reference adds the endpoint and GIC
MBI route shown below. [I] `qcom,flashless` needs a reviewed binding plus
profile driver support; otherwise it has no effect. MBI SPI range/alias
needs stock confirmation and schema/interrupt testing before boot.

```dts
/* SPDX-License-Identifier: GPL-2.0-only */
/* Candidate board additions; review against the exact K3 board first. */
&intc {
        msi-controller;
        mbi-ranges = <832 32>;
        mbi-alias = <0x0 0x17a10000>;
};

&pcie2 {
        msi-parent = <&intc>;
        status = "okay";

        pcie@0 {
                modem@0,0 {
                        compatible = "pci17cb,306";
                        reg = <0x10000 0x0 0x0 0x0 0x0>;
                        qcom,flashless;
                };
        };
};

&pcie2_phy {
        vdda-phy-supply = <&vreg_l5a_0p88>;
        vdda-pll-supply = <&vreg_l9a_1p2>;
        status = "okay";
};
```

[V: D/K26:18-34] The reference additionally hogs TLMM56 (`ap2mdm-status`)
high and TLMM57 (`ap2mdm-errfatal`) low. [I] These are DEBUG additions,
not verified power/reset sequencing; keep them **out** of the initial DTS
until O2 identifies their function and safe assertion order. No additional
modem-enable regulator/GPIO is evidenced here; do not invent one.
[V: D/K31:1-44] IP_HW0 channels 100/101 remain enabled, with doorbell burst
disabled in that reference. [I] A reviewed board/profile quirk may be needed;
do not change every SDX55 device's channel table globally.

## 3. Kernel fragment and required driver work

[V] The fragment is now in `device/instantnoodlep/kernel.config` (last
section) and was merged into the candidate build recorded in §6. Merge it
after the Wi-Fi/BT section: it overrides those module defaults on purpose.
[V: L `drivers/bus/mhi/host/Kconfig:7-28`, `drivers/net/wwan/Kconfig`,
`drivers/net/Kconfig` (MHI_NET), `net/qrtr/Kconfig`,
`drivers/phy/qualcomm/Kconfig` (QMP_PCIE), `drivers/irqchip/Kconfig`]
These are mainline symbols; built-in transport avoids module staging failures:

```config
# SPDX-License-Identifier: MIT
CONFIG_PCI=y
CONFIG_PCI_MSI=y
CONFIG_PCIE_QCOM=y
CONFIG_PHY_QCOM_QMP_PCIE=y
CONFIG_ARM_SMMU=y
CONFIG_ARM_SMMU_QCOM=y
CONFIG_ARM_GIC_V3=y
CONFIG_MHI_BUS=y
CONFIG_MHI_BUS_PCI_GENERIC=y
CONFIG_MHI_BUS_SAHARA=y
CONFIG_WWAN=y
CONFIG_MHI_WWAN_CTRL=y
CONFIG_MHI_NET=y
CONFIG_QRTR=y
CONFIG_QRTR_MHI=y
# GNSS over LOC needs no CONFIG_GNSS driver, host IPA or Q6V5_MSS.
```

[V: L `drivers/irqchip/Makefile:35`] There is no `CONFIG_ARM_GIC_V3_MBI`
symbol: `ARM_GIC_V3` builds `irq-gic-v3-mbi.o` directly. The earlier draft of
this fragment listed it, and Kconfig dropped it silently — exactly the failed
gate this section warns about. Do not re-add it.

[V: L `drivers/net/wwan/Kconfig:9`] `config WWAN` is `depends on GNSS || GNSS
= n`, so a `GNSS=m` from the Wi-Fi/BT section would cap `WWAN` at `=m`. The
fragment therefore sets `# CONFIG_GNSS is not set`; LOC arrives over QRTR, not
through a GNSS tty.

[V: D/K16:35-47; L host Kconfig:7-28] `CONFIG_MHI_BUS_SAHARA` exists only in
the public WIP series, not mainline. [V] It now exists in this tree because
`patches/instantnoodlep/kernel-modem/0002` defines it; without that patch the
line is dropped silently, so a build that does not show `CONFIG_MHI_BUS_SAHARA=y`
in the merged `.config` did not apply the series. Required work that is still
open: large-transfer fixes (D/K20-K22) and a privacy-reviewed sync lifecycle.
[V: D/K28-K30; D/modem/install.sh:90-93] Debug RAM/EFS dump paths are present
in the reference. [I] Exclude unrestricted dump collection and EFS persistence
from the first candidate; if the modem cannot run without them, stop.

## 4. Userspace package delta (specification, not installed)

| Package / component | Exact role and acceptance gate |
| --- | --- |
| `modemmanager`, `libmm-glib`, `libqmi`, `libqrtr-glib` | [I] Arch target package names/version availability must be checked with `pacman -Si` offline before staging; compile MM with QMI/QRTR and qcom-soc plugin. [V: D/P19:4-19,72-100; D/modem/README.md:53-57] Reference needs fixes for LOC reinitialization and mhi_net association; audit current source for both, port only absent fixes. |
| `qrtr` (`qrtr-ns`, `qrtr-lookup`) | [I] Verify exact Arch recipe/installed binaries and `qrtr-ns.service` with `pacman -Ql qrtr`; do not assume a distro unit exists. [V: L `net/qrtr/mhi.c` IPCR match] QRTR-MHI is the kernel transport; the userspace name server is separate. |
| `rmtfs` | [V: D/modem/install.sh:46-57] SDX55 reference uses TFTP/QRTR instance 3, not rmtfs. [I] Do not install/start rmtfs for SDX55; if required by ADSP later, keep that separate and prevent partition-backed defaults. |
| `pd-mapper` | [V: L `drivers/soc/qcom/qcom_pd_mapper.c`; AUDIO-M5-PLAN] SoC DSP service-domain mapping, not external MHI boot. [I] No new daemon for this gate; retain the existing kernel PDM/Kona arrangement, avoid duplicate userspace PDM ownership; audio owns later DSP package choices. |
| new `omamobile-sdx55-rfs` | [I] Package a reviewed instance-3 QRTR/TFTP service only after backing policy passes. Runtime-only private working directory, mode 0700, no `/dev` access, no partition discovery, no firmware/NV logging, no autostart. [V: D/modem/install.sh:46-57,96] Start before MM and prevent competing tqftpserv. Public Python code is behavior evidence, not copied here. |
| `networkmanager`, `mobile-broadband-provider-info`, `polkit`, `dbus` | [I] Keep available but GSM profiles/auto-connect absent for first boot. No network or APN changes in first gate. |
| `geoclue`, optional `gpsd` | [I] Later GNSS-only gate; no default tracking, SUPL or XTRA. MM LOC first, exclusive QRTR LOC bridge only if MM lacks support. [V: D/modem/README.md:28-31,49-50] Reference has NMEA PTY and a no-SIM GNSS path; not a mainline `/dev/gnss0`. |

[V: U `packages/omamobile-mmd/PKGBUILD:6,12-16`] `omamobile-mmd` owns
`org.freedesktop.ModemManager1` and conflicts with real ModemManager.
[I] Device package selection must choose real MM on instantnoodlep and keep
SIT/Exynos services off; don't remove the project's bridge globally.
[V: D/modem/78-mm-sdx55-qrtr.rules:4-11] Reference associates mhi_net with
qcom-soc, ignores WWAN control probes, ignores SWIP data and sets HWIP MTU
1500. [I] Scope equivalent udev rules to this endpoint's actual PCI ancestry,
not every WWAN device; record the live ancestry before writing the rule.
WWAN device-node appearance is evidence of channel binding, not proof QMI
works there. Reference MM instead uses QRTR. Start mhi_net before MM;
D/modem/ModemManager-sdx55.conf:1-5 uses a net-ready condition [V].

[I] Future device service ordering: qrtr-ns -> approved RFS -> mhi_net/udev
settle -> ModemManager, explicit start only. Test setup/teardown and package
rollback on a rootfs copy first. Never install the reference SIM/GNSS
activation or EFS saver services for this gate.

## 5. Firmware-map delta: paths only

[V: L `drivers/bus/mhi/host/pci_generic.c`, `mhi_qcom_sdx55_info`]
Generic mainline names `qcom/sdx55m/sbl1.mbn` and recovery
`qcom/sdx55m/edl.mbn`. [I] EDL member existence in the owner's OTA is
unverified; no EDL trigger or recovery loader is authorized. Do **not** add
an unconditional EDL map row solely because the driver names it.

[V: D/K16:244-262] The public flashless loader's non-EFS image names below
are already represented in firmware.map: `acdb.mbn`, `aop.mbn`, `apdp.mbn`,
`apps.mbn`, `devcfg.mbn`, `hyp.mbn`, `multi_image.mbn`,
`multi_image_qti.mbn`, `qdsp6sw.mbn`, `sbl1.mbn`, `sec.elf`, `tz.mbn`,
`xbl_cfg.elf`, all under `qcom/sdx55m/`. [I] Verify OTA members by name using
FIRMWARE-PLAN F1-F6; no extraction or firmware bytes in this change.

[V: D/modem/install.sh:24-35] `mdmddr.mbn` is specially excluded from ordinary
firmware copying; reference obtains per-unit DDR training state instead.
[I] The current map's OTA `mdmddr.mbn` row must not be treated as valid runtime
backing. The companion `patches/instantnoodlep/0001-firmware-map-exclude-modem-ddr-state.patch`
removes that unsafe assumption;
apply it only as part of the eventual extractor change, after review.
EFS/NV, `modemr.jsn` and calibration remain excluded. An approved existing
private backup, if usable, stays outside git and outside the firmware map.

## 6. First RAM boot: coordinator only, no SIM or registration

[I] This gate is still **not released**: stock wiring, MM package capability
and safe private backing must pass first. The kernel side now exists and is
built offline; nothing has run on the phone.

[V] Base `aa996bae0` (`instantnoodlep-k3-combo`, release
`7.3.0-rc6-instantnoodlep-k3-gaa996bae0695`), series
`patches/instantnoodlep/kernel-modem/0001-0004`, branch
`instantnoodlep-k3-modem` at `e9ff58528f8b`. Do not mix in the hanging power
P2 branch.

### 6.1 Offline artefacts (macbookpro, LLVM=1, arm64)

[V] Built in a case-sensitive Docker volume (`k3modem-work`, container
`k3modem`) from the series applied on `aa996bae0`, with the combo `.config`
as base. Release `7.3.0-rc6-instantnoodlep-k3-modem-ge9ff58528f8b`: the
release string names the series tip, not the working tree, so it is set
explicitly after the merge.

```sh
# $SRC = kernel tree with patches/instantnoodlep/kernel-modem/0001-0004 applied
cd "$SRC"
scripts/kconfig/merge_config.sh -m -O "$OUT" "$COMBO_CONFIG" "$FRAGMENT"
# $FRAGMENT = this repo's device/instantnoodlep/kernel.config
scripts/config --file "$OUT/.config" \
  --set-str LOCALVERSION -instantnoodlep-k3-modem-ge9ff58528f8b \
  --disable LOCALVERSION_AUTO
make O="$OUT" ARCH=arm64 LLVM=1 olddefconfig
nice -n 19 make O="$OUT" ARCH=arm64 LLVM=1 -j4 \
  Image.gz qcom/sm8250-oneplus-instantnoodlep.dtb modules
make O="$OUT" ARCH=arm64 LLVM=1 INSTALL_MOD_PATH="$STAGE" modules_install
```

[V] `dtbs_check` was run as `make O="$SCHEMA" ARCH=arm64 LLVM=1 CHECK_DTBS=y
qcom/sm8250-oneplus-instantnoodlep.dtb`; it reports `DTC [C]` with no
warnings. A deliberately invalid property on `modem@0,0` is rejected by
`qcom,sdx55-mhi.yaml`, so the new binding is really applied to the node.

| Artefact | Path (private, macbookpro) | sha256 |
| --- | --- | --- |
| kernel | `~/android/build/k3-modem/Image.gz` | `006ace3a75d81022abfa32f43e4b68f4c4b190cb6e43f1b9768482572a8f49e7` |
| board dtb | `~/android/build/k3-modem/sm8250-oneplus-instantnoodlep.dtb` | `646c38c28e930c98fd4a8a679773bfb40ea9f233c68b60d5ca56acb604bcadbb` |
| modules | `~/android/build/k3-modem/modules-7.3.0-rc6-instantnoodlep-k3-modem-ge9ff58528f8b.tar.gz` | `9a6317634e1bad3b8002ffff24e9b4743053403b1263ede53472b85f71634608` |
| merged config | `~/android/build/k3-modem/config-7.3.0-rc6-instantnoodlep-k3-modem-ge9ff58528f8b` | `e244cc1c1f31980d44b022f2ad3681314776caedf425cbfc6e1113017ef53d82` |

[V] The merged `.config` carries `CONFIG_MHI_BUS_SAHARA=y`,
`CONFIG_MHI_BUS=y`, `CONFIG_MHI_BUS_PCI_GENERIC=y`, `CONFIG_MHI_NET=y`,
`CONFIG_MHI_WWAN_CTRL=y`, `CONFIG_WWAN=y`, `CONFIG_QRTR=y`,
`CONFIG_QRTR_MHI=y`, `CONFIG_PCIE_QCOM=y`, `CONFIG_PHY_QCOM_QMP_PCIE=y`,
`CONFIG_ARM_SMMU_QCOM=y`, `CONFIG_ARM_GIC_V3=y` and `# CONFIG_GNSS is not
set`. A build without `CONFIG_MHI_BUS_SAHARA=y` did not apply the series.

[V] `dtbs_check` on the board DTS and `checkpatch --strict` on the series are
clean except `Missing Signed-off-by` (the owner's DCO) and two
"DT binding docs and includes should be a separate patch" warnings, which are
false positives: the bindings are separate patches. `tests/modem-sahara/check
<kernel tree>` passes against the real `sahara.c` with a synthetic MHI
transport; it is a parser/bounds test, not DMA or lifecycle testing.

[I] The coordinator builds the RAM image on omabook from the same series; the
artefacts above are the reference build, not a transferable file. Rebuild
there with the same fragment and check the release string before use.

| Gate | Command / review | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| A offline | Review O2 stock-DTB privately against §2; review bindings, loader/profile, source licences and private-state policy. `dtbs_check`, `checkpatch --strict` and the merged-config audit are done [V: §6.1] | [I] exact wiring confirmed; no unknown symbol/schema error, no dump/NV path; base and new commit recorded | mismatch, protected-state requirement, unknown firmware provenance | discard candidate, keep combo K3 |
| B offline | Audit `pacman -Si modemmanager libqmi libqrtr-glib qrtr`; inspect package files/units and MM meson options on build host | [I] qcom-soc/QRTR enabled, mhi_net/LOC fixes present; only real MM owns bus; exact daemon units documented | unavailable package, competing MM bridge, auto SIM/GNSS service, partition access | restore rootfs staging snapshot |
| C offline | Owner confirms physical SIM absent and no eSIM/subscription activation, no GSM auto-connect, MM initially stopped, bounded private RFS policy approved; stage packages/modules only with a separate userdata-write go | [I] no registration/SIM-helper action possible in first test | SIM present or unable to guarantee non-registration | no boot; owner removes SIM or requests new scope |
| D image | Builder uses fresh paths and the command below; `sha256sum` and manifest/release review against §6.1 | [I] reviewed RAM-only candidate and matching rootfs/modules; stock DTBO retained | output exists, wrong release, incomplete A-C | discard output; no phone action |
| E baseline (owner local) | `fastboot -s "$SERIAL" getvar current-slot`; `getvar slot-successful:b`; `getvar slot-unbootable:b` | [I] B active, successful, bootable; identifiers kept private | state differs from M1b/B5 | reconcile M1b; no RAM boot |
| F RAM boot (one owner go) | `fastboot -s "$SERIAL" boot "$M5_IMG"` | [I] boots once to USB SSH; hash/release match D | refusal, lost USB, hang | owner cold-reboots to bootloader after refusal; no repeated attempts, no slot writes; boot installed B only once state is checked |
| G enumeration (owner SSH) | run read block below | [I] `17cb:0306`, reviewed flashless profile, AMSS/mission mode, IPCR/QRTR, HWIP netdev and WWAN control nodes | wrong profile, firmware failure, SBL stall, IOMMU/MSI errors, sync dump or modem reset loop | stop test; owner-approved reboot to installed B; private logs only |
| H MM discovery (owner SSH, separate go) | start block below after approved RFS/QRTR and mhi_net ready | [I] `mmcli -L` lists one modem; `sim-missing` is acceptable without SIM | no modem, crash, protected backing request, attempted registration | stop MM and test RFS/QRTR units; owner-approved reboot to installed B |
| I restore | stop block below; compare slot flags to E after owner-controlled return to bootloader | [I] services stopped, installed kernel unchanged, no slot flag change | device wedged or flags changed | M1b recovery owner only; never set-active/flash in this runbook |

[I] Build operator only, after A-C; this worker did not run it. All
variables are private paths and must be filled and checked; fresh `M5_IMG`
means neither it nor its sidecars exists. The builder's `--root userdata`
permits ordinary rootfs writes; it does not imply a read-only phone test
[V: tools/build-instantnoodlep-probe:31-42,root allowlist constants].

[V] `$ART` is the artefact directory of §6.1 (`~/android/build/k3-modem` on
macbookpro, or the coordinator's own build on omabook). The modules tarball
must be unpacked into the rootfs before the RAM boot, or the release will not
match and udev will load nothing:

```sh
ART="$HOME/android/build/k3-modem"
REL=7.3.0-rc6-instantnoodlep-k3-modem-ge9ff58528f8b
sha256sum "$ART/Image.gz" "$ART/sm8250-oneplus-instantnoodlep.dtb" \
  "$ART/modules-$REL.tar.gz"
# On the rootfs (userdata), as root, before the RAM boot:
#   tar -xzf modules-$REL.tar.gz -C / && depmod -a "$REL"

tools/build-instantnoodlep-probe \
  --kernel "$ART/Image.gz" \
  --dtb "$ART/sm8250-oneplus-instantnoodlep.dtb" \
  --ssh-key "$SSH_PUBLIC_KEY" --mkbootimg "$MKBOOTIMG" \
  --omarchy-mobile "$OMARCHY_MOBILE" --initramfs-root "$INITRAMFS_ROOT" \
  --stock-overlay "$STOCK_ENTRY16" --ufdt-apply "$UFDT_APPLY" \
  --boot 2 --root userdata --out "$M5_IMG"
sha256sum "$M5_IMG"
```

[I] G: owner runs locally on the phone, output private; do not paste full
MM status, network addresses, firmware logs or QRTR topology into an issue.

```sh
uname -r
lspci -nn -d 17cb:0306
find /sys/bus/mhi/devices -maxdepth 1 -type l -printf '%f\n'
find /sys/class/net -maxdepth 1 -name 'mhi_*' -printf '%f\n'
find /sys/class/wwan -maxdepth 2 -name '*qmi*' -printf '%f\n'
qrtr-lookup
# Inspect privately for AMSS, firmware/MSI/IOMMU errors; publish pass/fail only.
dmesg | rg -i 'pcie|mhi|sahara|firmware|iommu|qrtr'
```

[I] H/I use exact unit names established in B, not guessed units. Name
variables are unfilled until reviewed; stop on any command error. No
`mmcli --enable`, SIM status/PIN, bearer, registration, SMS, GNSS tracking or
network activation commands are authorized by this gate.

```sh
systemctl start "$QRTR_UNIT" "$APPROVED_RFS_UNIT"
# Transport is built in; verify mhi_hwip* exists before starting MM.
systemctl start ModemManager.service
mmcli -L
# Teardown after discovery; do not query identity-bearing modem details.
systemctl stop ModemManager.service
systemctl stop "$APPROVED_RFS_UNIT" "$QRTR_UNIT"
```

[I] Kernel ports and `mmcli -L` are intended pass criteria, not measured
results. GNSS remains at capability inspection only; a fix, SIM activation,
network registration and all RF/data/voice tests need later explicit owner go.
