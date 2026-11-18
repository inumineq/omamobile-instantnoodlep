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
