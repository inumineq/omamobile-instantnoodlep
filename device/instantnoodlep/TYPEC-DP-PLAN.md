<!-- SPDX-License-Identifier: MIT -->
# TYPEC-DP-PLAN: USB Type-C role/PD and DisplayPort alt mode on slim K3

House-rule-6 gate for the Type-C subsystem: PM8150B Type-C + PD PHY,
TCPM, USB role switch to dwc3, the FSA4480 SBU/AUX mux, DisplayPort alt
mode, and the `mdss_dp` + QMP combo-PHY graph — ported from the public
GPL Nura tree onto slim K3. **Charger programming stays out of this
branch** (the charger has its own owner gate, POWER-M5-PLAN P2b); nothing
here binds a charger driver, writes a charger property, or changes a
charge limit. PD sink PDOs below are only negotiation advertisements,
identical to stock; with no charger driver bound, no charge limit can
change.

- Date: 2026-11-18. Repo branch: `inumineq/typec-dp`. Kernel branch:
  `instantnoodlep-k3-slim-typec` on `78f38a2acc99` in the new worktree
  `~/src/l-k3-typec` (of `~/src/l-k3-slim`).
- Safety model unchanged (AGENTS.md rules 1, 3): everything here is
  offline builds plus a RAM boot; nothing flashes, no `_a`/`super`
  writes. All phone steps are `fastboot boot` (RAM only) run by the
  coordinator; steps needing physical plugs are the owner's. Rollback
  for every phone step: hold Power+VolUp 10-30 s, the phone boots the
  daily K3 from `boot_b` [V: DAILY-K3-RUNBOOK R1].
- Default USB role stays **device/gadget**: the board DTS sets
  `role-switch-default-mode = "peripheral"` on the dwc3 role switch
  (binding default is already `peripheral`,
  `Documentation/devicetree/bindings/usb/usb-drd.yaml:57`), and when the
  laptop is attached the Type-C port assigns the device data role. The
  owner's USB networking to the laptop must keep working (T1).

## 1. Source pins

- `N/` = public GPL Nura tree
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial>
  @ `498f76983128` (cloned to `~/src/nura-ref/nura`): the exact phone has
  working mainline DP alt mode, hub and charging [V: N/docs/displayport.md].
  Ported patches: `0060` (FSA4480 + SBU graph part), `0088` (fsa4480
  keeps USB2 in 4-lane DP), `0095` (enable DisplayPort + role/mode
  switches), `0138` (DP link rates up to HBR3). All GPL-2.0; original
  `From:` and `Signed-off-by:` are kept on each ported commit.
- `L/` = `~/src/l-k3-typec`, branch `instantnoodlep-k3-slim-typec` on
  `78f38a2acc99` (slim K3 base; image_size 0x1720000 vs ceiling
  0x2b60000, KERNEL-SIZE.md).
- `E/` = `~/android/build/p3/entry16.dts`, decompiled stock dtbo entry
  16: PM8150B typec@1500/pdphy@1700, stock sink PDOs 5 V/3 A, 9 V/3 A,
  12 V/2.25 A, VBUS reg 0x1100, `extcon = <&pm8150b_pdphy>` on usb0
  [V: POWER-M5-PLAN §2].
- `G/` = OnePlusOSS public GPL kernel @ `cad09e061ef6`: FSA4480-class
  node on a QUP I2C bus, board override sets its address to `0x42`
  (`kona-oem.dtsi` L421-423) [V: DESKTOP-MODE-RESEARCH §1]. Nura places it
  on `i2c15` @ `0x42` (N/0060) — same bus, adopted.
- `P/` = `POWER-M5-PLAN.md` §3.3 (node shapes: `&pm8150b_typec` +
  `vdd-pdphy-supply = <&vreg_l2a_3p1>`, `&pm8150b_vbus` okay for host
  mode, dwc3 `dr_mode = "otg"` + `usb-role-switch` + HS endpoint) and
  `DESKTOP-MODE-RESEARCH.md` (RB5 mainline precedent, Nura graph).
- Build host: omabook, clang/LLD 23.1.3 (`/usr/bin/clang`), never the
  MBP Docker clang 19 (learning `l-e03ff7fe`).

## 2. Patch review (each Nura patch read before porting)

| Nura patch | Verdict | Notes |
| --- | --- | --- |
| 0060 wire USB-C audio (FSA4480 node, SBU endpoint, codec port) | **Port, partially** | Keep the `fsa4480: typec-mux@42` node on `&i2c15` and the SBU endpoint to the connector's `port@2`. Adapted to this tree's binding (`fcs,fsa4480.yaml` requires a single `port`, cf. in-tree `sm8150-hdk.dts`), so Nura's `ports/port@0` becomes `port`. The `wcd938x` codec port, `mode-switch` on the codec and `accessory-mode-audio` are **dropped**: audio is the audio worker's subsystem and no wcd938x node exists in slim. |
| 0088 fsa4480 retains USB2 routing in 4-lane DP | **Port** | Applies verbatim to `L/drivers/usb/typec/mux/fsa4480.c` (context matches). Needed so a monitor's USB2 hub works while all four SS lanes carry DP (N/docs/displayport.md). |
| 0095 enable DisplayPort (mdss_dp, altmodes, connector ports, dwc3/qmpphy mode-switch) | **Port** | The DTB hunks are split into the Type-C-graph commit and the DP commit to keep one logical change per commit; node labels match `L/arch/arm64/boot/dts/qcom/sm8250.dtsi` exactly (`usb_1_qmpphy_out`, `usb_1_qmpphy_dp_in`, `usb_1_dwc3_hs_out`, `mdss_dp_out`). `From:`/`Signed-off-by:` of Roman Kuraev kept. |
| 0138 allow DP link rates up to HBR3 | **Port** | One line: `link-frequencies = /bits/ 64 <1620000000 2700000000 5400000000 8100000000>` on `&mdss_dp_out`. Authorship kept. |
| 0089-0094, 0097, 0098 (QMP/dwc3-qcom/typec/tcpm race fixes) | **Not ported** | Written against Nura's ~6.12-era base; `L` is 7.3.0-rc6, where the typec/qmp rework has landed upstream. Porting them would conflict and duplicate upstream fixes. Revisit only if T2/T4 show a reconfiguration race on this kernel. |
| 0055, 0057, 0058, 0100, 0102, 0149, 0150 (USB-C/DP audio) | **Out of scope** | Audio subsystem, owned by the audio worker. |
| 0068, 0073, 0082-0087, 0096, 0099, 0165, 0166, 0167 (charger, external VBUS boost, gauge-charging policy) | **Out of scope, owner gate** | Charger programming and the external-boost VBUS path belong to the P2b charger gate. This branch enables only the PMIC's own `pm8150b_vbus` regulator (VBUS *source* for host mode, as Nura's base and POWER-M5-PLAN §3.3 do) and changes no charge limit. |

## 3. Kernel commit order (branch `instantnoodlep-k3-slim-typec`)

One logical change per commit, GPL-2.0 headers; offline gates re-run
after each (§5).

| # | Commit (branch tip order) | Content |
| --- | --- | --- |
| 1 | `arm64: dts: qcom: sm8250-oneplus-instantnoodlep: Add the PM8150B Type-C port, PD PHY, FSA4480 mux and VBUS regulator` | Include `pm8150b.dtsi`; `&pm8150b_typec` okay with `vdd-pdphy-supply = <&vreg_l2a_3p1>`, `vdd-vbus-supply = <&pm8150b_vbus>` and a `usb-c-connector` child: `power-role/data-role = "dual"`, `self-powered`, stock sink PDOs (5 V/3 A, 9 V/3 A, 12 V/2.25 A) + 5 V/3 A dual-role source PDO, `ports` 0 (HS → dwc3), 1 (SS → QMP PHY), 2 (SBU → FSA4480); `&pm8150b_vbus` okay (500 mA-3 A); `&i2c15` okay with `fsa4480: typec-mux@42` (`mode-switch`, `orientation-switch`, `port` → `pm8150b_sbu`). Merges Nura's base graph and N/0060; codec port and `accessory-mode-audio` dropped (audio out of scope), single-`port` binding shape. |
| 2 | `arm64: dts: qcom: sm8250-oneplus-instantnoodlep: Switch dwc3 to OTG with a Type-C role switch` | `&usb_1_dwc3`: `dr_mode = "otg"`, `usb-role-switch`, `role-switch-default-mode = "peripheral"` (default role stays gadget); `&usb_1_dwc3_hs_out` → `pm8150b_hs_in`; `&usb_1_qmpphy`: `mode-switch`, `&usb_1_qmpphy_out` → `pm8150b_ss_in`. RB5 shape; no `mode-switch` on dwc3 (not in this tree's binding). |
| 3 | port of N/0095: enable DisplayPort (author Roman Kuraev, Signed-off-by kept) | `&mdss_dp` okay; `&mdss_dp_out`: `data-lanes = <0 1 2 3>`, `remote-endpoint = <&usb_1_qmpphy_dp_in>`; `&usb_1_qmpphy_dp_in` ← `mdss_dp_out`; connector `altmodes` DP `svid = 0xff01`, `vdo = 0x00001c46`. Adaptation: `data-lanes` on `mdss_dp_out`, not the connector SS endpoint (current usb-connector.yaml). |
| 4 | port of N/0138: allow DP link rates up to HBR3 (authorship kept) | `link-frequencies = /bits/ 64 <1620000000 2700000000 5400000000 8100000000>` on `&mdss_dp_out`. |
| 5 | port of N/0088: fsa4480 keeps USB2 in four-lane DP (authorship kept) | `drivers/usb/typec/mux/fsa4480.c`: DP-only states C/E also enable the USB switch; applies verbatim. |

## 4. Config delta (`device/instantnoodlep/kernel-slim-typec.config`)

Merged on top of `~/android/build/k3-slim/.config` with
`scripts/kconfig/merge_config.sh -m` + `olddefconfig`:

```
CONFIG_LOCALVERSION="-instantnoodlep-k3-slim-typec"
CONFIG_TYPEC_TCPM=y          # was m: role must be known at boot, before any module loads
CONFIG_TYPEC_QCOM_PMIC=y     # was m: PM8150B port/PD PHY, built in for the same reason
CONFIG_TYPEC_MUX_FSA4480=y   # was m
CONFIG_TYPEC_DP_ALTMODE=y    # was m
```

`CONFIG_TYPEC=y`, `CONFIG_USB_ROLE_SWITCH=y`, `CONFIG_USB_DWC3_DUAL_ROLE=y`,
`CONFIG_PHY_QCOM_QMP_COMBO=y`, `CONFIG_DRM_MSM_DP=y`, `CONFIG_USB_HID=y`
are already set in the slim config [V: `~/android/build/k3-slim/.config`].
Built-in (not module) is deliberate: the probe boots with the gadget
path and the owner's USB networking must not depend on a module load
order; with `dr_mode = "otg"` dwc3 waits for the role switch, so the
Type-C stack must be present at boot. Size cost is a few hundred KB
against a 0x1720000 image in a 0x2b60000 ceiling.

## 5. Build and offline gates (omabook, no phone)

```
# config
cp ~/android/build/k3-slim/.config ~/android/build/k3-slim-typec/.config  # fresh O= dir
scripts/kconfig/merge_config.sh -m -O ~/android/build/k3-slim-typec \
    ~/android/build/k3-slim/.config device/instantnoodlep/kernel-slim-typec.config
make -C ~/src/l-k3-typec O=~/android/build/k3-slim-typec ARCH=arm64 LLVM=1 olddefconfig

# build (clang 23.1.3 from PATH; nice 5, -j8; never clang 19)
nice -n 5 make -C ~/src/l-k3-typec O=~/android/build/k3-slim-typec \
    ARCH=arm64 LLVM=1 -j8 Image.gz dtbs modules

# gates
od -An -tx8 -j16 -N8 ~/android/build/k3-slim-typec/arch/arm64/boot/Image   # <= 0x2b60000 (target <= 0x2560000)
~/android/build/dtschema-venv/bin/dtbs_check (or make CHECK_DTBS=y) on qcom/sm8250-oneplus-instantnoodlep.dtb
make ... modules_install INSTALL_MOD_PATH=... && tar.zst of lib/modules/<rel>/
tools/build-instantnoodlep-probe --typec ... (boot-daily manifest flags) -> ~/android/build/k3-slim-typec-ram/boot-typec.img
```

`--typec` is a new `tools/build-instantnoodlep-probe` flag: without it
the tool forces `dr_mode = "peripheral"` and strips `usb-role-switch`
(`make_probe_dtb`); with it, the real Type-C graph is kept and instead
verified (`dr_mode = "otg"`, `usb-role-switch` present, the pm8150b
connector present). Remoteprocs, UFS-per-`--boot`, PON modes and the
stock-overlay sink behave exactly as before. The RAM image uses the
boot-daily manifest flags [V: `~/android/build/k3-daily-ram/boot-daily.manifest.json`]:

```
tools/build-instantnoodlep-probe \
  --kernel ~/android/build/k3-slim-typec/arch/arm64/boot/Image.gz \
  --dtb ~/android/build/k3-slim-typec/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb \
  --ssh-key ~/.ssh/omamobile_probe.pub \
  --mkbootimg ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py \
  --omarchy-mobile ~/src/omarchy-mobile \
  --initramfs-root ~/android/build/initramfs-root \
  --stock-overlay ~/android/build/p3/entry16.dtbo \
  --ufdt-apply ~/android/build/ufdt/ufdt_apply_overlay \
  --typec --boot 2 --root userdata --debug-shell \
  --out ~/android/build/k3-slim-typec-ram/boot-typec.img
```

Offline stop conditions: `image_size` > 0x2b60000 (do not RAM-boot);
any new `dtbs_check` warning on this board; modules tarball missing;
builder refusing (e.g. overlay no longer applies). Rollback: none
needed, nothing was booted; fix and rebuild.

## 6. Gated runbook T1-T4 (RAM boot only; AGENTS.md rule 1 format)

Roles: the coordinator runs every command; **OWNER** steps are the
physical plugs/screen. `{{SERIAL}}` is the pinned fastboot serial
(private). `IMG` = `~/android/build/k3-slim-typec-ram/boot-typec.img`,
`MOD` = the typec modules tarball, `REL` = `7.3.0-rc6-instantnoodlep-k3-slim-typec-g<sha>`.
Captures to `captures/<date>/typec/` (gitignored, masked). Nothing
here writes a partition; the only rollback is the hardware one.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| T0 | Laptop: `sha256sum -c` the RAM image SHA256SUMS; `od` image_size recorded in NOTES. Phone in fastboot on slot B (`getvar current-slot` = `b`, `slot-successful:b` = `yes`) | hashes OK; vars as daily | hash mismatch or slot vars differ | `fastboot reboot`; daily boots from `boot_b` |
| T1 | `fastboot -s {{SERIAL}} boot $IMG` (RAM only). **OWNER** has the laptop USB cable attached. SSH `root@172.16.42.1` within 2 min; `uname -r` = `REL`; `systemctl is-system-running`; `ip a` shows the NCM interface to the laptop; `dmesg \| grep -i dwc3` | `Booting OKAY`; `running`; SSH over USB; dwc3 in **peripheral** mode; `cat /sys/class/typec/port0/power_role` = `sink`, `data_role` = `device` (laptop attached); USB networking to the laptop works as under daily | no SSH in 2 min; dwc3 stuck host/none; no NCM enumeration; any new boot error vs daily | hold Power+VolUp 10-30 s → daily K3 from `boot_b`. After a refused RAM boot, cold-reboot to the bootloader before another `fastboot boot` |
| T2 | Over SSH, no plug change, then **OWNER** unplugs and replugs the laptop cable in both orientations: `ls /sys/class/typec/`; `cat /sys/class/typec/port0/{power_role,data_role,orientation}`; `ls /sys/class/typec/port0/partner/` (exists while attached); `cat /sys/class/usb_role/usb_1_dwc3-role-switch/role`; `dmesg \| grep -iE 'typec|tcpm|pm8150b|fsa4480|qcom-pmic'` | one `port0`; while attached `partner/` present; `power_role` sink, `data_role` device, `orientation` flips on replug; role-switch `device`; probes: `qcom_pmic_typec` (typec@1500), `fsa4480` on i2c15, `typec-dp` altmode registered (`/sys/class/typec/port0/altmodes/`); replug re-enumerates NCM both orientations | no typec port; role stuck `host` or `none`; partner absent while attached; fsa4480 did not probe; enumeration fails in one orientation | `reboot -f` (back to daily via boot_b); record dmesg |
| T3 | **OWNER**: with the phone on the RAM-booted kernel and SSH alive, unplug the laptop, attach a USB keyboard through a USB-C OTG adapter. Over SSH: `cat /sys/class/typec/port0/{power_role,data_role}`; `cat /sys/class/usb_role/usb_1_dwc3-role-switch/role`; `ls /sys/class/input/`; `dmesg \| grep -iE 'dwc3|hid|usb [0-9]'`; `evtest`/libinput shows key events on the new device | `power_role` = `source`, `data_role` = `host`, role-switch `host`; VBUS on (`/sys/class/typec/port0/vbus_present` or regulator); a `hid` input appears; keys register | role stuck `device`/`none`; no VBUS; no input device; dwc3 or typec crash in dmesg | unplug the adapter, replug the laptop cable: expect return to `sink`/`device` and NCM back (T1 state); if not, `reboot -f` → daily. Do not leave the adapter attached |
| T4 | **OWNER**: attach a USB-C monitor/dock (self-powered, SuperSpeed cable). Over SSH: `cat /sys/class/typec/port0/{power_role,data_role}`; `ls /sys/class/typec/port0/altmodes/`; `cat /sys/class/drm/card*-DP-*/status` (a `DP-*` connector appears, `connected`); `modetest`-style mode list via `cat /sys/class/drm/card*-DP-*/modes`; `dmesg \| grep -iE 'mdss_dp|qmp|dp_altmode|typec_mux|fsa4480'`; hub: `lsusb` shows the dock's USB2 devices (4-lane DP keeps D+/D-) | DP altmode entered (state C/D/E per `dmesg`); `DP-1` `connected` with modes up to the monitor's cap; link trained (4-lane HBR3 when the sink allows, per N/0138); USB2 hub enumerates; `power_role` per the dock (sink, or source if the dock sources) | no `DP-*` connector; altmode never entered; display engine or PHY crash; USB role flip-flops; anything in dmesg at err level from dp/qmp/dwc3 | unplug the dock; expect `DP-1` gone and T1 state restored; if the typec stack is wedged, `reboot -f` → daily. Never flash |
| T5 | Exit: `systemctl reboot --reboot-argument=bootloader`; four slot getvars; `fastboot reboot`; SSH; `uname -r` = daily REL | fastboot reached; slot vars unchanged; daily K3 from `boot_b` | slot vars changed | stop, record, ask the owner |

Definition of done for this branch: offline gates pass; T1 and T2 pass
with pasted (masked) output — that is the RAM-boot qualification this
branch claims; T3/T4 are owner-gated phone steps recorded in NOTES when
run. `trail-lite lint` clean; branch pushed; PR open.

## Coordinator change 2026-11-18: sink 5 V only

The ported connector node advertised the stock sink PDOs 5 V/3 A, 9 V/3 A and
12 V/2.25 A. This kernel binds no driver that programs the PM8150B charger, so
a PD charger or dock must not raise VBUS above 5 V yet. Kernel commit
`ed709a578` keeps only `PDO_FIXED(5000, 3000, PDO_FIXED_USB_COMM)` [V: probe
DTB `sink-pdos = <0x401912c>`]. Only the DTB changed; the Image and modules
(`7.3.0-rc6-instantnoodlep-k3-slim-typec-g8930ae7af4b6`) are unchanged.

Use `~/android/build/k3-slim-typec-ram5v/boot-typec-5v.img` (sha256
`1ea62c7675956544b946bf9881211c80a863117860584fae7241b557aae9cf8f`) for T1-T4
instead of `boot-typec.img`. Restore the 9 V/12 V PDOs only together with the
qualified charger (POWER-M5-PLAN P2/P3) and its owner gate.

## 7. Dell U3219Q hub and gadget recovery

[V: 2026-11-19 attended phone report] RAM kernel typec-fix1
(`d3b1dfc5c376`) showed DP and charged on the U3219Q, but the Logitech
receiver produced neither keyboard nor mouse input. The laptop gadget
had not returned 60 seconds after replug. [V: 2026-11-18 slim-all RAM
test, learning `l-4ba3a6b2`] The prior failure included USB root-port
`connect-debounce failed`, a QMP timeout and DWC3 `ep0out` failure.
[I] The fix1 result alone does not establish where either path failed.

### Required transitions

- [V: kernel base `c30e3f696707`, `drivers/usb/typec/tcpm/tcpm.c:1224-1234`,
  `drivers/usb/dwc3/drd.c:450-473`, `drivers/usb/dwc3/core.c:290-301`]
  TCPM passes the negotiated USB data role to DWC3, which queues role
  work. [I] For this dock expect the phone to remain a power **sink** but
  become the data **host** (DFP), via a PD data-role swap if attached as
  UFP. Expect `[host]` in Type-C `data_role` and `host` from the DWC3 role
  switch, then a bound `xhci-hcd` child and USB2 root hub. The root hub must
  detect, debounce, reset and enumerate the Dell hub, and the receiver
  must enumerate below it and bind a HID driver before testing input.
  Picture and charging alone establish neither data role nor hub status.
- [V: base `drivers/phy/qualcomm/phy-qcom-qmp-combo.c:4810-4848` and
  mainline commit `f546912bcac6`] C/E allocates all four SuperSpeed pairs
  to DP. D/F allocates two to DP and leaves one SuperSpeed TX pair and one RX pair for USB.
  USB2 D+/D− remains available in both modes through the separate
  USB2 PHY. [V: base `drivers/usb/typec/mux/fsa4480.c:88-105`] The existing
  FSA4480 code enables the USB path in all four of those states.
- [V: Dell U3219Q User's Guide, pp. 14, 59 and 68] Dell documents USB2 data
  on the USB-C input alongside DP and PD, with a separate USB 3.0 upstream
  input. The guide documents automatic USB upstream selection for USB-C
  video. [I] Treat this U3219Q connection as a USB2 hub test, expect C/E
  and read the negotiated assignment. The guide does not establish the
  pin assignment or document a High Data Speed control. If the actual
  OSD offers one, log it and require D/F before treating it as a two-lane
  control. A known multifunction DP dock is another D/F control.
  [Dell U3219Q User's Guide](https://downloads.dell.com/manuals/all-products/esuprt_display_projector/esuprt_display/dell-u3219q-monitor_user%27s-guide_en-us.pdf)
- [V: base QMP lines 4044–4099 and legacy DWC3 glue lines 517–531, 787–795]
  QMP holds USB3 PCS in reset in DP-only mode and keeps a common PIPE
  clock reference for USB2. Fix2 selects UTMI as the wrapper's PIPE
  clock source at probe using `qcom,select-utmi-as-pipe-clk`; its DTB
  still describes both PHYs. [I] If the phone reaches host and xHCI
  appears but the Dell hub only works on fix2, the clock selection is
  implicated. This is USB2 operation over D+/D− with the normal xHCI
  driver. Static UTMI is a diagnostic, and SuperSpeed needs a separate
  baseline check over a known SuperSpeed laptop port and cable.
- [V: base TCPM lines 5147–5205, DWC3 core role worker and QMP lines
  4201–4214, 4810–4848] TCPM requests SAFE/none and removes the partner
  on detach. QMP's base mux drops mode changes while DP is powered.
  Fix1 queues the request for DP power-off. [I] On detach expect DP
  shutdown, xHCI teardown and restoration of QMP USB-only routing.
  Laptop attach should negotiate phone UFP/device, restore PIPE for
  SuperSpeed-capable operation and let the gadget bind and enable ep0.
  A role readout of `device` alone is insufficient. Require a new
  laptop enumeration, network function binding and usable gadget SSH.
  The detached DWC3 role can reflect the board's peripheral default.

### T7 owner-attended RAM gate

[V: build inputs, sizes and SHA-256 manifest in
[recovery research](../../docs/research/typec-dp-usb-recovery.md#fix2)]
Fix2 is the independent static-UTMI candidate `255b48e80527`, with
`image_size=0x1780000` and clang/LLD 23.1.6. [I] Run fix2 first. Verify
the inputs before packing and check the packed boot image against the
coordinator's packing manifest. Check T1/R baseline and working Wi-Fi
SSH or a phone-local terminal before unplugging the laptop. Use the same
cable orientation for each comparable run and keep the receiver and
monitor input fixed. Unplug the separate USB-B upstream cable for this
test. Keep captures in the coordinator's private `captures/` and share
only redacted excerpts.

```sh
fastboot -s "{{SERIAL}}" boot ~/android/build/k3-typec-fix2/boot-typec-fix2.img
```

[I] **Expect** fastboot sending and booting both `OKAY`, then
`uname -r` = `7.3.0-rc6-instantnoodlep-k3-typec-fix2`. Take a plain laptop
replug baseline before DP. Start the event stream below before the first
disconnect. Take snapshots at laptop baseline, unplugged, dock attached
with picture, receiver removal/reinsert, dock detached, and laptop
replug immediately and at 60 s. Record the owner-visible picture, charge
state and both keyboard/mouse actions. On the laptop compare `lsusb -t`,
`sudo dmesg -w` and gadget SSH before and after DP.

[I] **Expect on the dock** sink/host, C/E, bound xHCI, the hub below
the USB2 root hub (normally `480M`) and the receiver below the hub with
a HID interface. **Expect after laptop replug** device role, gadget NIC
enumeration and SSH within 60 s. [I] **Stop** on wrong release, missing
baseline or independent capture access, unresponsive phone, lost DP,
or new QMP/PIPE/ep0 errors. A missing hub or input fails the dock gate.
If the phone remains responsive, finish the single detach/replug
observation and stop if the gadget has not returned at 60 s. Capture
before rollback. Use T5 to leave the RAM boot and return to daily2 on
`boot_b`. If unresponsive the owner disconnects USB and uses the
Power+VolUp recovery from the candidate recovery procedure. No partition writes.

[V: capture interfaces are Linux Type-C, USB role, platform driver,
UDC and USB device sysfs plus usbutils/systemd tools] Run this snapshot
on the phone as root for each phase, replacing the phase label.
Missing attributes are printed explicitly.

```sh
phase=laptop-baseline
printf '\nphase=%s uptime=' "$phase"
cat /proc/uptime
uname -r
for f in /sys/class/typec/port0/data_role /sys/class/typec/port0/power_role \
         /sys/class/typec/port0/port_type /sys/class/typec/port0/power_operation_mode \
         /sys/class/typec/port0/orientation \
         /sys/bus/typec/devices/port0*/displayport/pin_assignment \
         /sys/class/usb_role/*/role /sys/class/udc/*/state \
         /sys/class/udc/*/current_speed; do
    printf '%s: ' "$f"
    if [ -r "$f" ]; then cat "$f"; else printf 'absent\n'; fi
done
printf 'Bound xHCI platform devices:\n'
find /sys/bus/platform/drivers/xhci-hcd -maxdepth 1 -type l \
    -name 'xhci-hcd.*' -printf '%f\n' 2>/dev/null
lsusb -t
dmesg --color=never | grep -Ei 'pmic.typec|tcpm|typec|fsa4480|displayport|msm.*dp|qmp|pipe_clk|utmi|dwc3|xhci|usb [0-9]+-|usb[0-9]+-port|logitech|hid|ep0|cdc_ncm|cdc_ether'
```

[V: `udevadm monitor` supports repeatable subsystem filters and kernel
and udev event sources] In a second phone session independent of the USB
gadget, start this before the baseline. Stop it with Ctrl+C after the
final snapshot. Use uptime to align events with dmesg. Collect this over
Wi-Fi to a private laptop log or watch it from the phone console.

```sh
stdbuf -oL udevadm monitor --kernel --udev \
    --subsystem-match=typec --subsystem-match=usb_role \
    --subsystem-match=platform --subsystem-match=usb \
    --subsystem-match=udc --subsystem-match=hid --subsystem-match=input
```

### Build-host decision after T7

- [I] If Type-C remains device or DWC3 never reaches host, inspect TCPM
  DR_Swap and the DWC3 role worker first. If host is reported without
  xHCI, check the `dwc3_host_init()` return and child binding. If the hub
  and receiver enumerate, check HID binding and pairing before proposing
  PHY changes.
- [I] If fix2 restores the four-lane hub but loses SuperSpeed in ordinary
  USB or D/F, make the next candidate dynamic instead of carrying
  static UTMI into daily2. In
  `drivers/usb/dwc3/dwc3-qcom-legacy.c`, adapt the v3 clock switching
  sequence to `dwc3_qcom_select_utmi_clk()`: gate the clock using
  `PIPE_UTMI_CLK_DIS`, set `PIPE_UTMI_CLK_SEL | PIPE3_PHYSTATUS_SW` for
  C/E and clear those bits when USB PHY PIPE is ready again. Serialize
  the switch against wrapper PM and controller reset. Keep the static
  property semantics for existing USB2-only boards. Use the legacy
  wrapper `&usb_1` in
  `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts` for any
  wrapper `mode-switch` registration and add the matching legacy
  binding and connector graph routing. Arrange notification order so
  entry selects UTMI before PHY PIPE is withdrawn and exit selects PIPE
  after PHY restoration. The same-board Nura 0090/0092 QMP/controller
  guard is a reference for coordinating those transitions.
  [DWC3 UTMI v3 proposal](https://lkml.iu.edu/2611.1/15253.html)
- [I] If logs instead show the QMP PCS timeout during four-lane entry,
  isolate the QMP change before combining it with dynamic UTMI.
  In `drivers/phy/qualcomm/phy-qcom-qmp-combo.c`, make
  `qmp_combo_usb_init()` and `qmp_combo_usb_exit()` hold and release
  common resources symmetrically even in DP-only, while
  `qmp_combo_usb_power_on()` and `qmp_combo_usb_power_off()` skip USB PCS
  work in DP-only. Remove the USB PCS timeout path's duplicate PIPE
  disable and keep that clock's lifetime in common init/exit. Verify
  the first USB-capable transition powers PCS back up with an existing
  USB init reference. If the failure instead starts at detach, trace
  `qmp_combo_typec_mux_set()`, `qmp_combo_dp_power_off()` and the DWC3
  role worker together before settling on a combined candidate.
- [I] Once the trace identifies a change, build it on the slim-all
  comparison base with one delta, clang/LLD 23, pinned LOCALVERSION
  without git metadata, and arm64 header `image_size < 0x2b60000`.
  Use the same attended gate and then a verified D/F or plain SuperSpeed
  control before proposing a daily2 integration.
