<!-- SPDX-License-Identifier: MIT -->
# DAILY-K3-PLAN: the first daily kernel for boot_b

Status 2026-11-17: kernel built offline, RAM-boot image ready (§6), nothing
run on the phone. Runbook: `docs/runbooks/DAILY-K3-RUNBOOK.md`.

"Daily" is the integration kernel meant to replace combo K3 on `boot_b`:
everything that has passed its own RAM boot, nothing that has not. It is
the `boot_b` candidate; combo K3 stays the rollback.

## 1. What goes in

Sources (all private on omabook, by name only):

- `K/` = `~/src/l-k3`, branch `instantnoodlep-k3-combo` @ `aa996bae0695`:
  K3 (panel, touch, keys, GPU) plus the test-only `qcom,kona` patch
  (learning `l-48e0c482`; DO NOT UPSTREAM).
- `W/` = `instantnoodlep-k3-wifi` @ `f9a20697e2ae`, fetched from
  `~/android/build/k3-wifi2/instantnoodlep-k3-wifi.bundle` (bundle verified,
  requires `aa996bae0695`): three DTS commits, PM8009, QCA6390 Wi-Fi/BT,
  serial alias (WIFI-BT-M5-PLAN §6.1, PR #68).
- `P/` = `instantnoodlep-k3-power` up to `11fedfae5a37` only: the P1 fuel
  gauge commit (POWER-M5-PLAN §0.4, PR #69). Its 14 P2 charger commits are
  left out on purpose: P2 hangs at boot and is being debugged separately.

| Gate the feature passed | Evidence |
| --- | --- |
| Display, touch, keys, GPU | [V] combo K3 on `boot_b`, NOTES 2026-11-17 midday/day |
| Wi-Fi scan | [V] k3-wifi RAM boot, WIFI-BT-M5-PLAN §7.3 R1-R4 |
| BT | [V per the coordinator's brief for this task] k3-wifi2 RAM boot: hci0 comes up **unconfigured** and works after a manual `btmgmt public-addr`; not yet recorded in WIFI-BT-M5-PLAN §7.3 |
| Gauge | [V] P1 RAM boot, POWER-M5-PLAN §7.3 P1 result: `bq27411-0` 96 %, 4.265 V, 32 °C |
| Charger | not passed: no charging under daily (same as combo) |

## 2. Kernel branch

`~/src/l-k3-daily` (new worktree of `K/`), branch `instantnoodlep-k3-daily`
= `aa996bae0695` + `git cherry-pick aa996bae0..instantnoodlep-k3-wifi` +
`git cherry-pick 11fedfae5`. No conflicts [V]: the Wi-Fi commits touch the
PM8009 include, `aliases`, the PMU/PCIe0/UART6 nodes; the gauge commit adds
`&gpi_dma2`, `&i2c16` and `&qupv3_id_2`. Commit trailers kept as in their
branches (`Assisted-by`; the owner adds `Signed-off-by` before anything is
sent upstream).

```
78f38a2acc99 arm64: dts: qcom: instantnoodlep: Add the battery fuel gauge
497d8995b    arm64: dts: qcom: instantnoodlep: Add a serial alias for the Bluetooth UART
1cc54852f    arm64: dts: qcom: instantnoodlep: Enable Wi-Fi and Bluetooth
74e9e168c    arm64: dts: qcom: instantnoodlep: Add PM8009
aa996bae0    (combo K3)
```

## 3. Config

`device/instantnoodlep/kernel.config` now carries the P1 gauge section
(from `inumineq/power`, without the P2 charger section) and the Wi-Fi/BT
section (from `inumineq/wifi-bt`). Build config = combo `.config` +
`scripts/kconfig/merge_config.sh -m` of `kernel.config` + `olddefconfig`.

[V] The result differs from combo's `.config` in one line only,
`CONFIG_CHARGER_BQ25980` `=m` to unset, and is byte-identical to the P1
build's `.config` (`~/android/build/k3-power/.config`). Wi-Fi/BT adds no
symbol: combo already had them all (WIFI-BT-M5-PLAN §6.2).

Watch-out, pre-existing and unchanged here: the fragment asks for
`CONFIG_TYPEC_QCOM_PMIC=y`, every K3 `.config` (combo, power, daily) has
`=m`; `merge_config.sh` reports the redefinition. Harmless while the probe
DTB forces peripheral mode, but the fragment comment ("built in") is not
what the build gets [V: `grep TYPEC_QCOM_PMIC` on the three `.config`
files]. Why Kconfig lowers it is not traced [I].

## 4. Build (omabook, LLVM=1)

`make O=~/android/build/k3-daily ARCH=arm64 LLVM=1 -j12 Image.gz dtbs
modules`, then `CHECK_DTBS=y` on the board DTB, `modules_install` into
`modinst/` and a `tar.zst` of `lib/modules/<rel>/` (same layout as combo
and P1: top-level dir is the release). RAM image with
`tools/build-instantnoodlep-probe`, flags as combo `boot-r3-gpu`
(`--boot 2 --root userdata --debug-shell`, stock entry-16 overlay,
`--ufdt-apply`), fresh `--out ~/android/build/k3-daily-ram/boot-daily.img`.
Results, hashes and the release string: §6.

## 5. Bluetooth public address (unit written, not yet on the phone)

### 5.1 Problem [V]

- btqca reads the BD address tag from the NVM file and, if the controller
  reports that same address, sets `HCI_QUIRK_USE_BDADDR_PROPERTY`
  [V: K/drivers/bluetooth/btqca.c:410-414, 683-710, called at :995].
- With that quirk the core looks for `local-bd-address` on the firmware
  node; without a valid one the controller is marked `HCI_UNCONFIGURED`
  [V: K/net/bluetooth/hci_sync.c:3726-3750, 5284-5312]. Our DT has no
  `local-bd-address`, and ABL fills none [I: the partial ABL source in
  `~/android/build/qabl` has no BD-address code; the full
  UpdateDeviceTree path is not in that copy].
- `MGMT_OP_SET_PUBLIC_ADDRESS` (`btmgmt public-addr`) needs the controller
  powered off and a `set_bdaddr` hook, which hci_qca gives
  (`qca_set_bdaddr`); on an unconfigured controller it clears
  `HCI_UNCONFIGURED` and the index comes back configured [V:
  K/net/bluetooth/mgmt.c:8385-8415; K/drivers/bluetooth/hci_qca.c:2078-2080].
- The kernel does not remember the address: it is lost at every boot.

### 5.2 Options

| Option | Verdict |
| --- | --- |
| A. `local-bd-address` in our DTS | Rejected: a per-unit address in a git file (house rule 4); a zero placeholder only helps when the bootloader fills it, which ABL does not [I] |
| B. Patch the BD-address tag in `qca/htnv20.bin` on the rootfs | Rejected: edits a firmware file per unit, breaks the package/firmware hash story (rule 8), and a firmware update silently drops it |
| C. Read the real address from Android `persist` at boot | Rejected for now: needs a read of a vendor partition and its format (no source we may use), and the boot path then depends on `persist` |
| D. **udev-triggered oneshot that sets a stored address with `btmgmt public-addr`** | **Recommended** |

### 5.3 Recommendation: D, as upstream already does it

Upstream omarchy-mobile has the pattern twice [V: `~/src/omarchy-mobile`
@ `6c11752ae4c3`]:

- Pixels (cheetah, husky, raven, tegu): `80-omamobile-bt-addr.rules` adds
  `SYSTEMD_WANTS=omamobile-bt-addr@%k.service` on `ACTION=="add",
  SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]*", DRIVERS=="hci_uart_bcm"`; the
  template service (`Type=oneshot`, `Before=bluetooth.service`; a service
  because udev's sandbox has no Bluetooth sockets) runs
  `omamobile-bt-addr hciN`, which waits for mgmt to answer, sets the
  address and, in husky's version, waits for the index to return and
  checks the address it reads back
  [V: `packages/omamobile-device-{cheetah,husky}/bin/omamobile-bt-addr`,
  `vendor/udev/rules.d/80-omamobile-bt-addr.rules`,
  `vendor/systemd/system/omamobile-bt-addr@.service`]. Their address
  source is the bootloader's `/chosen/config/bt_addr`, which we do not have.
- OnePlus 13 (dodge, WCN7860 on hci_qca, the same unconfigured state):
  the real address lives in `persist`, which they never read; the script
  generates a random address **once**, first octet `0x02` (locally
  administered, unicast), keeps it in `/var/lib/omamobile/bt-public-addr`
  (mode 600, never committed) and sets it with `btmgmt -i 0 public-addr`
  [V: `device/dodge/bluetooth/omamobile-bt:15-23, 62-97`].

For instantnoodlep: the Pixel trigger and verification, with dodge's
address source.

1. `80-omamobile-bt-addr.rules`: the Pixel rule with
   `DRIVERS=="hci_uart_qca"` (the serdev driver name,
   [V: K/drivers/bluetooth/hci_qca.c:2829]). udev starts it the moment
   hci0 registers; modules autoload from the DT, so no hand `modprobe`
   as on dodge.
2. `omamobile-bt-addr@.service`: as the Pixels', `Before=bluetooth.service`.
3. `omamobile-bt-addr hciN`:
   - wait (up to 30 s) until `btmgmt --index N config` lists
     `public-address` under missing options (needs an address) or
     `btmgmt --index N info` answers `current settings:` (already
     configured: exit 0). hci_qca downloads `htbtfw20.tlv`/`htnv20.bin`
     before mgmt reports the index [I: timing per dodge's comment, about
     1.5 s on WCN7860].
   - address: `/var/lib/omamobile/bt-public-addr` if it holds a valid
     unicast address; otherwise generate `02:xx:xx:xx:xx:xx` from
     `/dev/urandom` under `umask 077` and store it there. The owner may
     put the unit's real address (read from stock Android's settings)
     into that file by hand instead; either way it lives only on the
     phone.
   - `btmgmt --index N public-addr <addr>`; then wait for the index to
     return with `current settings:` and compare `addr` with the stored
     value (husky's checks). Do not power the controller on before
     setting it: an unconfigured controller cannot be powered, unlike
     the Pixels' BCM case.
4. Packaging: `packages/omamobile-device-instantnoodlep` when the device
   package exists (upstream rule: per-device files there); until then the
   three files are installed by hand on the phone from this plan (§5.5),
   with a rollback that deletes them.

Why not a fixed address derived from a serial number (postmarketOS
`bootmac` style): it needs a stable per-unit ID our boot path exposes, and
whether ABL passes `androidboot.serialno` on our command line is [I]; a
hash of a serial is still a per-unit value and stays out of git, so it buys
nothing over a stored random address except surviving a rootfs reinstall.
Revisit if the owner wants pairings to survive reinstalls.

Wi-Fi MAC is separate (WIFI-BT-M5-PLAN §5, I-M5-13).

Open [I]s for the design, answered on the phone (runbook R6):

| [I] | Check |
| --- | --- |
| hci0's driver is `hci_uart_qca` in udev | `udevadm info -a /sys/class/bluetooth/hci0 \| grep DRIVERS` |
| `btmgmt config` shows `public-address` as missing | R6 |
| The index returns configured after `public-addr` without a power cycle | R6 |

### 5.4 Implementation (this repo)

The three files live under `device/instantnoodlep/rootfs/`, mirroring their
paths on the phone, until the device package exists:

| File in the repo | On the phone | Mode |
| --- | --- | --- |
| `device/instantnoodlep/rootfs/usr/bin/omamobile-bt-addr` | `/usr/bin/omamobile-bt-addr` | 0755 |
| `device/instantnoodlep/rootfs/usr/lib/udev/rules.d/80-omamobile-bt-addr.rules` | same path | 0644 |
| `device/instantnoodlep/rootfs/usr/lib/systemd/system/omamobile-bt-addr@.service` | same path | 0644 |

- The rule is the Pixels' with `DRIVERS=="hci_uart_qca"`; the service is
  theirs unchanged (`Type=oneshot`, `Before=bluetooth.service`).
- The script follows §5.3.3: it waits up to 30 s for mgmt to report the
  index configured (exit 0, nothing to do) or `missing options:
  public-address`; reads `/var/lib/omamobile/bt-public-addr` when it holds
  a unicast address, otherwise generates `02:xx:xx:xx:xx:xx` from
  `/dev/urandom` under `umask 077` and stores it mode 600; sets it with
  `btmgmt --index N public-addr`; then waits for the index to return and
  checks the address it reports. It never powers the controller on (an
  unconfigured one cannot be), and it never prints the address: the journal
  gets "generated a new public address in <file>" or "hci0 now has the
  stored public address", nothing more.
- Idempotent: a second run on a configured controller exits 0 without
  touching the file or calling `public-addr`.
- Two environment variables exist only for the host test
  (`tests/omamobile-bt-addr`, a fake `btmgmt` in `PATH`):
  `OMAMOBILE_BT_ADDR_FILE` and `OMAMOBILE_BT_ADDR_WAIT`. The unit sets
  neither. The test covers generation and mode 600, the no-op second run, a
  hand-written address, a non-unicast or malformed stored value, a
  controller that never answers, an index that does not return after the
  change, and bad arguments. `shellcheck` 0.11.0 clean.

### 5.5 Install and rollback on the phone (coordinator)

Writes no partition: three files under `/usr` and, on the first run, one
file under `/var/lib/omamobile`. The phone is on daily K3 with `hci0`
present (runbook R6). No reboot is needed; the rule fires again on the next
boot.

Install, from the laptop in the repo root (the phone is `root@172.16.42.1`
over USB SSH):

```sh
scp device/instantnoodlep/rootfs/usr/bin/omamobile-bt-addr \
    device/instantnoodlep/rootfs/usr/lib/udev/rules.d/80-omamobile-bt-addr.rules \
    device/instantnoodlep/rootfs/usr/lib/systemd/system/omamobile-bt-addr@.service \
    root@172.16.42.1:/tmp/
```

On the phone:

```sh
install -Dm755 /tmp/omamobile-bt-addr /usr/bin/omamobile-bt-addr
install -Dm644 /tmp/80-omamobile-bt-addr.rules /usr/lib/udev/rules.d/80-omamobile-bt-addr.rules
install -Dm644 /tmp/omamobile-bt-addr@.service /usr/lib/systemd/system/omamobile-bt-addr@.service
systemctl daemon-reload
udevadm control --reload
udevadm trigger --subsystem-match=bluetooth --action=add
```

Expect: every command returns 0 and the trigger starts
`omamobile-bt-addr@hci0.service`. Then verify:

```sh
systemctl status 'omamobile-bt-addr@hci0.service' --no-pager
journalctl -u 'omamobile-bt-addr@hci0.service' -b --no-pager
stat -c '%a %n' /var/lib/omamobile/bt-public-addr
bluetoothctl power on
btmgmt --index 0 info | grep -E 'current settings|addr'
test "$(btmgmt --index 0 info | awk '/addr /{print $2; exit}')" = \
     "$(cat /var/lib/omamobile/bt-public-addr)" && echo address-matches
```

Expect: the unit is `inactive (dead)` with `status=0/SUCCESS`; the journal
holds one of the two lines above and no address; the file is mode `600`;
`current settings:` lists `powered`; the last command prints
`address-matches`. Mask the `addr` line before pasting anything anywhere
(rule 4).

Stop: the unit failed, the journal shows the address, or the last command
prints nothing. Roll back, then record the journal in NOTES.

Rollback (removes the unit; the controller goes back to unconfigured until
a manual `btmgmt public-addr`, runbook R6):

```sh
rm -f /usr/lib/udev/rules.d/80-omamobile-bt-addr.rules \
      /usr/lib/systemd/system/omamobile-bt-addr@.service \
      /usr/bin/omamobile-bt-addr
systemctl daemon-reload
udevadm control --reload
```

The stored address stays in `/var/lib/omamobile/bt-public-addr`: harmless,
and a reinstall reuses it, so pairings survive. `rm` it only if the owner
wants a new address.

## 6. Build results (omabook, 2026-11-17) [V]

| Item | Value |
| --- | --- |
| Kernel | `~/src/l-k3-daily` @ `78f38a2acc99`, release `7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99`, clang 23.1.3, `LLVM=1` |
| Build | `~/android/build/k3-daily`: `Image.gz`, `dtbs`, `modules` exit 0 (first `-j12` run killed by SIGKILL, error 137, with the laptop short of memory; finished incrementally with `-j6`) |
| `Image.gz` | sha256 `d46bcc6932e30bb5f931360c0325d1602f0df802a0d46f1cd0d2c3f7165046ce`; 44,591,616 bytes decompressed |
| Board DTB | sha256 `b459142153a839ee1aaba0b5166e8d4643ad3075a9c94a754000c8140e7dadb6` |
| `dtbs_check` | `CHECK_DTBS=y qcom/sm8250-oneplus-instantnoodlep.dtb` with dtschema from `~/android/build/venv-dt`: no warnings (`dtbs_check.log`) |
| DTB nodes | root `oneplus,instantnoodlep qcom,sm8250`; `serial1` = `serial@998000` `okay` with `bluetooth`; `pcie@1c00000` `okay`; `/qca6390-pmu`; `i2c@888000` `okay`, 100 kHz, `fuel-gauge@55` `ti,bq27411` (`fdtget`/`dtc` on the built DTB) |
| Modules | 1801 (`INSTALL_MOD_STRIP=1`; P1 count, combo minus BQ25980), `modules-7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99.tar.zst` sha256 `da5c9f9f30c09d158d106064370161d34b345be8d44a5a832ecd6a4e7b8fcd33`, top-level dir = release |
| RAM image | `~/android/build/k3-daily-ram/boot-daily.img` sha256 `710a61b5c56c501934576c732073d736a21b57d62378724c2de4281cc33d4981` (`boot-daily.SHA256SUMS`, manifest beside it) |
| Image checks | builder read-back OK; `unpack_bootimg`: kernel equals `Image.gz`, dtb equals `boot-daily.probe.dtb`; header and cmdline equal to combo `boot-r3-gpu.img` except kernel and dtb sizes; ramdisk byte-identical to combo's and P1's (sha256 `86340898…ad99a1`) |

Builder inputs: `--ssh-key ~/.ssh/omamobile_probe.pub` (the key in combo's
ramdisk; a first build with another key differed in `authorized_keys` only
and was deleted), `--omarchy-mobile ~/src/omarchy-mobile`,
`--initramfs-root ~/android/build/initramfs-root`, `--stock-overlay
~/android/build/p3/entry16.dtbo`, `--ufdt-apply
~/android/build/ufdt/ufdt_apply_overlay`, `--mkbootimg
~/aosp-tools/system/tools/mkbootimg/mkbootimg.py`, `--boot 2 --root
userdata --debug-shell`.

## 7. Next

1. Coordinator: runbook R-steps (RAM boot, checks).
2. Owner go: runbook F-steps (`flash boot_b` + B5).
3. Coordinator: install the BT address unit (§5.5) and record the result in
   NOTES; move the three files into
   `packages/omamobile-device-instantnoodlep` when the device package exists.
4. P2 charger joins daily only after its own RAM boot passes.
