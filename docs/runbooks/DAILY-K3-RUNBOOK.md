<!-- SPDX-License-Identifier: MIT -->
# DAILY-K3-RUNBOOK: RAM boot, checks, then boot_b

Plan: `device/instantnoodlep/DAILY-K3-PLAN.md`. Roles (AGENTS.md rule 1):
the coordinator runs every non-writing step; steps marked **OWNER GO**
write flash or the GPT and run only after the owner's explicit go for that
step; steps that need the screen are the owner's.

Two parts. Part R is a RAM boot and writes no partition (the only writes
are a new modules directory on the rootfs and, in R6, one file under
`/var/lib/omamobile`). Part F flashes `boot_b` and redoes B5; it starts
only after every R step passed and the results are in NOTES.

Fixed values (from the build, `DAILY-K3-PLAN.md` §6):

- `REL` = `7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99`
- `IMG` = `~/android/build/k3-daily-ram/boot-daily.img`,
  sha256 `710a61b5c56c501934576c732073d736a21b57d62378724c2de4281cc33d4981`
- `MOD` = `~/android/build/k3-daily/modules-7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99.tar.zst`,
  sha256 `da5c9f9f30c09d158d106064370161d34b345be8d44a5a832ecd6a4e7b8fcd33`
- Rollback image (combo K3, today's `boot_b`):
  `~/android/build/k3-combo-ram/boot-r3-gpu.img`, sha256
  `0b3413fa7db9f56bdc23716181a575990dcba2afc13409201d61d28cbcb5264a`.

Captures go to `captures/<date>/daily/` (gitignored). No serial, IMEI, MAC
or BD address in any pasted output: mask the last three octets.

## Part R: RAM boot (no partition writes)

### R0. Prepare (phone on combo K3 from `boot_b`)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R0.1 | Laptop: `cd ~/android/build/k3-daily-ram && sha256sum -c boot-daily.SHA256SUMS`; `sha256sum $MOD` | all `OK`; MOD hash as above | any mismatch | rebuild; do not boot |
| R0.2 | Phone (ssh root@172.16.42.1): `test ! -e /usr/lib/modules/$REL`; push `MOD` to `/tmp/`; `tar --zstd -xf /tmp/modules-$REL.tar.zst -C /usr/lib/modules`; `depmod $REL` | new `/usr/lib/modules/$REL/` only; the combo dir `...-gaa996bae0695` untouched | the dir exists already, or tar lists a path outside `$REL/` (`tar --zstd -tf` first) | `rm -rf /usr/lib/modules/$REL` |
| R0.2b | `grep -x 7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99 /usr/lib/modules/.omamobile-pinned` (append it if missing); `ls /usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-g78f38a2acc99/modules.dep` | the daily release is pinned and its tree exists | tree missing: re-stage `MOD` before any daily boot (upstream `omamobile-modules-cleanup` deletes unpinned trees 10 min after boot; learning 2026-11-18 pin) | none |
| R0.3 | Read only: `ls -l /usr/lib/firmware/ath11k/QCA6390/hw2.0/ /usr/lib/firmware/qca/htbtfw20.tlv /usr/lib/firmware/qca/htnv20.bin`; `pacman -Q bluez bluez-utils iw networkmanager` | the k3-wifi files still present (WIFI-BT-M5-PLAN §7.3); bluez-utils present (`btmgmt`) | a file missing | copy it back per WIFI-BT-M5-PLAN §7.1 P2 |
| R0.4 | `systemctl reboot --reboot-argument=bootloader`; `fastboot getvar current-slot`, `slot-successful:b`, `slot-unbootable:b`, `slot-retry-count:b` | `b`, `yes`, `no`; retry count recorded as G | anything else | `fastboot reboot` |

### R1. Boot

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R1 | `fastboot boot ~/android/build/k3-daily-ram/boot-daily.img` (RAM only); SSH within 2 min; `uname -r`; `systemctl is-system-running`; `systemctl --failed` | `Booting OKAY`; `uname -r` = `REL`; `running` | `FAILED (remote: ...)`; no SSH after 2 min; `degraded` with a unit that combo does not fail | owner holds Power+VolUp 10-30 s; combo K3 boots from `boot_b`. After a refused RAM boot, cold-reboot to the bootloader before another `fastboot boot` |

### R2-R7. Checks (read only unless stated)

| # | Check | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R2 display | Owner looks at the screen. `hyprctl monitors` as the session user (`XDG_RUNTIME_DIR` of that user) | Lock screen as under combo; `DSI-1` `1440x3168@120` | black or garbled panel after msm takes over | `reboot` (back to combo) |
| R3 touch | Owner taps the four corners while the coordinator reads `libinput debug-events --device /dev/input/event2` (or `evtest` if libinput-tools is missing; the device is the one named `s6sy761`) | corners near (168,173), (1312,172), (1295,3078), (144,3041) as on combo (NOTES 2026-11-17 day) | no events | `reboot` |
| R4 GPU GL | `dmesg \| grep -iE 'adreno\|a6xx\|gmu\|zap'`; `basename $(readlink /sys/class/drm/renderD128/device/driver)`; `ls -l /proc/$(pidof Hyprland)/fd \| grep renderD128`; `grep -h drm-driver /proc/$(pidof Hyprland)/fdinfo/* \| sort -u` | no GPU hang or zap error; driver `msm_dpu`; Hyprland holds `renderD128`; `drm-driver: msm` (as NOTES 2026-11-17 day) | `drm-driver` absent and Hyprland on llvmpipe | `reboot` |
| R5 Wi-Fi | `dmesg \| grep -iE 'ath11k\|1c00000.pcie'`; `lspci -nn`; `nmcli radio wifi on; nmcli device wifi rescan; sleep 10; nmcli device wifi list \| wc -l` | `PCIe Gen.2 x1 link up`; `17cb:1101`; ath11k `fw_version`; APs listed | no link, board-data error, empty list after 60 s | `reboot` |
| R6 BT (writes one file in `/var/lib/omamobile`) | (a) `dmesg \| grep -iE 'bluetooth\|hci0\|qca\|998000'`; (b) `udevadm info -a /sys/class/bluetooth/hci0 \| grep DRIVERS`; (c) `btmgmt --index 0 config`; (d) generate the address on the phone, never printed: `install -d -m 700 /var/lib/omamobile; test -s /var/lib/omamobile/bt-public-addr \|\| (umask 077; od -An -N5 -tx1 /dev/urandom \| awk '{printf "02:%s:%s:%s:%s:%s\n",$1,$2,$3,$4,$5}' \| tr a-f A-F > /var/lib/omamobile/bt-public-addr)`; (e) `btmgmt --index 0 public-addr "$(cat /var/lib/omamobile/bt-public-addr)"`; `sleep 2; btmgmt --index 0 info \| grep -c 'current settings:'`; (f) `bluetoothctl power on; bluetoothctl --timeout 15 scan on \| grep -c Device` | (a) `QCA setup on UART is completed`, no `Invalid line`; (b) `DRIVERS=="hci_uart_qca"`; (c) `missing options: public-address`; (e) `1` without a power cycle (DAILY-K3-PLAN §5 [I]s); (f) devices > 0 | hci0 missing; firmware `-2`; index does not return after (e) | `reboot`; the address file stays (harmless; delete with `rm /var/lib/omamobile/bt-public-addr` if unwanted) |
| R7 gauge | `dmesg \| grep -iE 'bq27\|i2c16\|888000'`; `cat /sys/class/power_supply/bq27411-0/{status,capacity,voltage_now,current_now,temp,health}`; twice, 30 s apart | `bq27411-0` present; no `update`/`cfgupdate`/`data memory` line; voltage 3.4-4.45 V; temp 15-45 °C; capacity 0-100 (POWER-M5-PLAN §7.3 P1-4) | no gauge; any data-memory write line; voltage > 4.45 V or temp > 45 °C (then also unplug) | `reboot -f` |
| R8 regressions | `dmesg -l err,crit,alert,emerg` saved; diff against the same command on combo (captured in R0 before the reboot, or on the next combo boot); `lsmod \| wc -l` | no new error class beyond the Wi-Fi/BT/gauge lines expected above | a new error from panel, touch, GPU, UFS or USB | `reboot` |

### R9. Exit

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R9 | `systemctl reboot --reboot-argument=bootloader`; the four slot vars of R0.4; `fastboot reboot` | fastboot reached (PM8009 PON note, WIFI-BT-M5-PLAN §6.1); vars equal to R0.4; combo K3 boots from `boot_b` | slot vars changed | stop, record, ask the owner |

Record R1-R9 in `device/instantnoodlep/NOTES.md` ([V], masked). Part F
needs all of R1-R9 passed.

## Part F: daily on boot_b (prepared, not run)

Facts this part rests on:

- `fastboot flash boot_b` clears `slot-successful:b` and resets the retry
  count to 7 [V: BRINGUP-M1b-PLAN §2; NOTES 2026-11-17 midday, combo K3
  flash]. Each boot without the mark costs one retry; at 0 ABL falls back
  to slot A, and a stock boot can erase the Arch root on `userdata`
  (learning `l-f3c8caea`). So F2-F6 run in one sitting, with no spare
  reboots, and B5 right after the first good boot from flash.
- `dtbo_b` stays stock and is not touched: ABL rejected both neutral
  dtbo images (DTBO-PLAN §6, learning `l-48e0c482`). No `set_active`, no
  `vbmeta`, nothing on any `_a` partition or `super` (rule 3).
- B5 (BRINGUP-M1b-PLAN §7 B5, `tools/instantnoodlep-slot-b-mark`) rebuilds
  its sectors from **fresh** reads each time; the K3 B5 set in
  `~/android/build/b5-20261117-1123-k3` is not reused.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| F0 | Coordinator: R1-R9 recorded in NOTES; `sha256sum` of `IMG` and of `boot-r3-gpu.img` (rollback) on the laptop; the daily modules dir is on the rootfs (R0.2) | both hashes as above | any R step failed or open | none needed |
| F1 | Phone in fastboot (`systemctl reboot --reboot-argument=bootloader`): `fastboot getvar current-slot`, `slot-successful:b`, `slot-unbootable:b`, `slot-retry-count:b` | `b`, `yes`, `no`, recorded | anything else | `fastboot reboot` |
| **F2 OWNER GO** | `fastboot flash boot_b ~/android/build/k3-daily-ram/boot-daily.img` | `Sending 'boot_b'` ... `OKAY`, `Writing 'boot_b'` ... `OKAY` | any `FAILED` | do not reboot; **owner go**: `fastboot flash boot_b ~/android/build/k3-combo-ram/boot-r3-gpu.img`, then F3, F4 on combo and F5 |
| F3 | Same four getvars | `current-slot: b`, `slot-successful:b: no`, `slot-unbootable:b: no`, `slot-retry-count:b: 7` | `current-slot` not `b`; `unbootable: yes`; slot A vars changed | stop; owner decides (combo re-flash as F2 rollback) |
| F4 | `fastboot reboot`; SSH within 2 min; `uname -r`; `systemctl is-system-running`; owner sees the lock screen | `REL`; `running`; lock screen | no SSH after 2 min | to fastboot by `reboot bootloader` from the debug shell on `/dev/ttyACM0`, else the owner's button route (Volume Up + Volume Down held during a reboot, BRINGUP-M1b-PLAN §4 Buttons; a cold start with the cable in reaches EDL, not fastboot), then **owner go** for the combo re-flash (F2 rollback). Retries left: 6, so there is time, but no more than two tries |
| **F5 OWNER GO** | B5, exactly as BRINGUP-M1b-PLAN §7 B5 steps 1-2: fresh reads of `sde` LBA 0-7 and 655352-655359 into a new `~/android/build/b5-<date>-daily/`, `tools/instantnoodlep-slot-b-mark`, then the four `dd` writes and read-backs over SSH | tool changes exactly LBAs 1, 3, 655356, 655359 (bit 54 of entry 34); read-back sha256 equal to the manifest; `/dev/sde` ro again | the tool refuses; any read-back mismatch | write the four `orig/` sectors back the same way and read them back, before any reboot (B5 rollback) |
| F6 | `systemctl reboot --reboot-argument=bootloader`; four getvars; `fastboot reboot`; SSH; `uname -r` | `slot-successful:b: yes`, `unbootable: no`, `current-slot: b`, slot A unchanged; daily boots from flash | `successful:b` still `no` | redo F5 from fresh reads; never let retries reach 0 |
| F7 | Quick R2-R7 on the flashed kernel (no R6 (d), the address file exists); record in NOTES and `docs/agents/state.md` (daily on `boot_b`, combo is the rollback) | all as in Part R | a regression only seen from flash | **owner go**: combo re-flash (F2 rollback), then F5 again |

If ABL ever falls back to slot A anyway (stock recovery shows up): do not
choose anything in recovery; follow the DTBO-PLAN §6 recovery (Advanced,
Reboot to fastboot, `fastboot --set-active=b`, then F5) as an owner-gated
sequence.
