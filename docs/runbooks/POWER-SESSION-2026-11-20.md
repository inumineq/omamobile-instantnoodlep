<!-- SPDX-License-Identifier: MIT -->
# POWER-SESSION-2026-11-20: one phone session for the sleep work

One ordered session for the owner and the coordinator. It finds what keeps
the SoC out of its low-power modes during suspend-to-idle, then finishes the
open steps of [`S2IDLE-FIRST-RUNBOOK.md`](S2IDLE-FIRST-RUNBOOK.md).

Nothing is flashed. Every kernel in this session is a RAM boot
(`fastboot boot <image>`), and a reboot returns to the kernel on `boot_b`.
Each numbered step needs the owner's go (AGENTS.md rule 1). **[V]** is
checked, **[I]** is to be checked by this session.

## Where we stand

- [V] `boot_b` holds `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu`
  (kernel tree @ `bd566b604`). Steps R0 to R5 passed on it: RTC alarm and
  power key wake the phone.
- [V] In every sleep so far the `aosd`, `cxsd` and `ddr` counts stayed 0,
  with the cable in and with the cable out. Memory dropped to its lowest
  frequency but entered no low-power mode.
- [V] Every driver has reached `sync_state`. That suspicion is closed.
- [V] After a suspend from the `devices` level on, USB networking returns
  only after a physical replug. Plan for a replug after every sleep.
- [V] Thirty seconds after boot the rails `cx`, `mx` and `mmcx` are on.
  `mmcx` is held at a performance vote by the display and camera clock
  controllers.
- [V] The boot log has `failed to set PC mode: -3`. It comes from the
  kernel's first attempt to select the default PSCI mode
  (`drivers/firmware/psci/psci.c:160-174`, `:792-796`). [I] The firmware
  refuses because it is already in OSI mode; harmless if so.
- [I] What holds the SoC up is not known. S1 and S2 are cheap tests that can
  rule the two boot options `pd_ignore_unused` and `clk_ignore_unused` in or
  out. Each option only skips one clean-up late in boot: of power domains no
  device uses (`drivers/pmdomain/core.c:1366-1387`), and of clocks no driver
  holds (`drivers/clk/clk.c:1588-1627`). Neither is a suspend switch, so a
  negative result is as likely as a positive one. The captures in the check
  block serve the other suspects: a device that keeps `mmcx` or `cx` voted,
  the coprocessors, and the CPU cluster's own state.

## Images

All images are made on the coordinator's host by unpacking the `boot_b`
image and repacking it with `mkbootimg`. The check before any variant is
used: repacking with no change reproduces the `boot_b` image byte for byte
(sha256 starts `c431ddb9`) [V: done for `nopd`].

| Name | Change against the `boot_b` image | State |
| --- | --- | --- |
| `nopd` | the token `pd_ignore_unused` and one space removed from the command line | packed, sha256 `f4e7f325cb5e30a72a22bfb545a01e823ad5be61aef4b8027934f889ef1c023b` [V: reported by the coordinator, 76 bytes differ, all in the command line] |
| `noclk` | the token `clk_ignore_unused` and one space removed; `pd_ignore_unused` stays | to pack |
| `noboth` | both tokens removed | to pack |
| `k2dtb` | the device tree replaced by the K2 one, sha256 `f64634a212b96770de9e93f5edb841d3b5d5489a2a2914836b6bd831001e9e49` (`~/android/build/k3-power-cpuicc/sm8250-oneplus-instantnoodlep.dtb` on omaserver); kernel, initramfs and command line unchanged | to pack |

For `noclk`, `noboth` and `k2dtb`: record the sha256, and confirm with a
binary compare against the `boot_b` image that the difference lies only in
the command line field (`noclk`, `noboth`) or only in the device tree
(`k2dtb`). Stop if anything else differs.

`k2dtb` keeps the kernel release of `boot_b`, so the modules on the root
file system still match. [V] The K2 device tree differs from the base one in
the eight CPU memory-bus cells only (plan §4, K2 row).

## Common blocks

**Boot a variant** (owner's go):

```sh
IMG=boot-daily2-qce-gmu-nopd.img   # the variant's image file
adb reboot bootloader              # or the key combination
fastboot getvar current-slot       # Expect: b
sha256sum "$IMG"                   # Expect: the value in the Images table
fastboot boot "$IMG"
```

**Check after boot**, over USB SSH, or Wi-Fi SSH if USB is missing:

```sh
V=nopd        # the variant's name: boot_b, nopd, noclk, noboth or k2dtb
D=/var/lib/s2idle
case $V in boot_b|nopd|noclk|noboth|k2dtb) ;; *) echo "STOP: unknown variant $V";; esac
uname -r
tr ' ' '\n' </proc/cmdline | grep -E 'slot_suffix|ignore_unused'
findmnt -no SOURCE,FSTYPE / || echo "STOP: no root mount shown"
test -d $D && test -w $D && echo "log directory ok" || echo "STOP: no writable $D"
sha256sum $D/step
modprobe rtc-pm8xxx; modprobe qcom_stats
dmesg | grep -iE 'genpd|gdsc|rpmhpd|unused|PC mode|OSI|failed|error' > $D/$V-dmesg.txt
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > $D/$V-genpd.txt
cat /sys/kernel/debug/clk/clk_summary > $D/$V-clk-before.txt
grep -H . /sys/class/remoteproc/*/state > $D/$V-rproc.txt
grep -H . /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
find /proc/device-tree -name 'qcom,select-utmi-as-pipe-clk' | wc -l
```

Expect: release `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu`, slot `_b`,
exactly the options the variant should have, the root file system on
`userdata` as on the daily boot, the log directory present, and the step
tool with sha256
`6c5200f48d0508fba3ceb3d66f350ee408af8898b66065dedc24bd4894309f1e`. The last
line prints 0 or 1; record it. Stop if the slot is not `_b`, if the root is
not the usual one, or on any line that starts with `STOP`: this runbook is
only valid there, and the captures below would be lost.

After each sleep, once SSH is back, with the same `V` and `D`:

```sh
cat /sys/kernel/debug/clk/clk_summary > $D/$V-clk-after.txt
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > $D/$V-genpd-after.txt
dmesg | grep -E 'PC mode|suspend entry|suspend exit|failed|error' > $D/$V-dmesg-after.txt
```

**Smoke test**: the screen shows the desktop and an animation moves
smoothly (GPU), touch reacts, Wi-Fi is connected and a `ping` to the gateway
answers, one of the two SSH paths works and `scp` of a small file passes,
`$V-dmesg.txt` has no UFS, PCIe, GPU or clock error, and the temperature
check passes:

```sh
grep -H . /sys/class/power_supply/*/temp
```

Each line names a supply and its temperature in tenths of a degree Celsius
[V: `drivers/power/supply/bq27xxx_battery.c:1706-1728`]. Pass: at least the
battery gauge prints a value, and no value is above 400 (40.0 °C). No line
at all is a failed check.

**One sleep, cable out**:

```sh
STEP=R4d      # R4d, R4e, R4f or R4g, as the step says
systemd-run --on-active=45 --unit=s2idle-$STEP --collect /var/lib/s2idle/step $STEP none 60
```

The owner pulls the cable within 30 s, leaves the screen off, touches
nothing for 2 minutes, then plugs the cable back in. Read
`/var/lib/s2idle/$STEP.log`.

**Stop conditions for every boot**: no picture and no SSH on either path
3 minutes after `fastboot boot`, a black panel that stays black, a
spontaneous reboot, a file system or UFS error, or a temperature above
40 °C: forced reboot. The phone then starts the kernel on `boot_b`. After
any forced reboot, run the check block with `V=boot_b` before anything else.
A failed smoke test: note what failed, skip the sleep, reboot.

**Stop conditions for every sleep**: no resume after 120 s: press Power
once. No reaction after 180 s: forced reboot, then read `/sys/fs/pstore/*`
first, the step's log second (the tool syncs it before the sleep) and
`journalctl -b -1` third; the journal of the lost boot may be incomplete.
No repeat before review. Several
`suspend entry` lines within seconds: a wake loop, stop.

**Rollback**: a reboot. The session writes log files under
`/var/lib/s2idle` and nothing else persistent. A kernel crash can damage
files being written at that moment, so do not run other work on the phone
during the session.

## Order

| Step | What | Time | Runs when |
| --- | --- | --- | --- |
| S0 | start state | 10 min | always |
| S1 | `nopd`, sleep R4d | 20 min | always |
| S2a | `noclk`, sleep R4e | 20 min | S1 left `cxsd` at 0 |
| S2b | `noboth`, sleep R4f | 20 min | S1 and S2a both left `cxsd` at 0, and both booted cleanly |
| S3 | R5b volume key, R6 systemd path | 15 min | always |
| S4 | holder matrix, short pass | 25 min, unattended | always |
| S5 | `k2dtb`, sleep R4g | 15 min | see S5 |
| evening | R7a and R7b suspended current | 30 min and 2 h, unattended | separate go |

About 85 minutes if S1 answers the question, about 125 minutes if all of S2
is needed. The owner is needed at the phone for S0 to S3 and S5. S4 runs
alone.

### S0. Start state

On the `boot_b` kernel, cable in:

```sh
uname -r; tr ' ' '\n' </proc/cmdline | grep -E 'slot_suffix|ignore_unused'
grep -H . /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
```

Expect: the `boot_b` release, slot `_b`, both options present. Stop on any
other slot: slot A holds another system, and this runbook is not valid
there.

Then run the check block with `V=boot_b`, and confirm that SSH over Wi-Fi
works from the laptop. [V] The firewall on the phone blocked SSH on the
Wi-Fi interface earlier (`docs/agents/state.md`). If it still does, S4
cannot run as written; say so and skip it.

### S1. Without `pd_ignore_unused` (request 9)

Boot `nopd`, run the check and the smoke test, then one sleep as step `R4d`.

| Expect | Reading |
| --- | --- |
| the command line has `clk_ignore_unused` only | the variant is the one intended |
| the sleep lasts about 60 s and wakes on `pm8xxx_rtc_alarm` | as R4 |
| `cxsd` or `aosd` above 0 after the sleep | the option was a blocker. Skip S2. The option then leaves the daily kernel as its own later step, with a full hardware check |
| all three still 0 | the option is ruled out on its own. Go to S2a |

Send back: `R4d.log` and every `nopd-*.txt` file.

### S2a. Without `clk_ignore_unused`

Boot `noclk`, run the check and the smoke test, then one sleep as `R4e`.

This variant lets the kernel switch off every clock no driver holds, late
in boot. [I] The risk is a device that worked only because its clock was
left on, for example the panel or USB. Watch the screen during boot. If
USB SSH is missing, use Wi-Fi SSH and note it; the smoke test passes with
one working SSH path. Compare `noclk-clk-before.txt` with
`boot_b-clk-before.txt` and send both: the difference is the list of clocks
the option kept on.

Reading: as in S1. If `cxsd` moves, skip S2b.

### S2b. Without both

Boot `noboth`, run the check and the smoke test, then one sleep as `R4f`.
Run it only if `nopd` and `noclk` each booted and passed the smoke test.

Reading: if all three counts are still 0 here, the boot options are not the
blocker. Send back `R4f.log` and `noboth-genpd.txt`; the next suspect is the
camera clock controller, which holds the multimedia rail and has no runtime
power management [V: plan §4].

### S3. Volume key and the systemd path

Run on the kernel that is booted at this point. If a variant failed its
smoke test, reboot to `boot_b` first.

R5b, volume key:

```sh
systemd-run --on-active=45 --unit=s2idle-R5b --collect /var/lib/s2idle/step R5b none 300
```

Cable out within 30 s. The owner presses Volume Down about 30 s after the
screen went dark. Expect a resume within 2 s and the volume key as the wake
IRQ in `R5b.log`. The 300 s alarm is the dead-man.

R6, the systemd path:

```sh
systemd-run --on-active=45 --unit=s2idle-R6 --collect sh -c \
  '{ date; rtcwake -d rtc0 -m no -s 300 && systemctl suspend; sleep 20; date; journalctl -b -k | grep -E "Timekeeping suspended|suspend e"; journalctl -b | grep "Watchdog timeout"; } > /var/lib/s2idle/R6.log 2>&1'
```

Cable out within 30 s; the alarm is set when the unit starts, 45 s after the
command. The `sleep 20` only gives the journal time to catch up after the
resume; it proves nothing. Expect in `R6.log`: `Timekeeping suspended for`
about 300 s and no `Watchdog timeout` line. Then, with the cable back in and
within 2 minutes of the resume, all three must hold:

```sh
systemctl is-system-running        # Expect: running or degraded, not stopping
loginctl list-sessions --no-legend | wc -l    # Expect: 1 or more
nmcli -t -f STATE general          # Expect: connected
```

Stop conditions and rollback as in `S2IDLE-FIRST-RUNBOOK.md`, rows R5b and R6.

### S4. Holder matrix, short pass

Reboot to the `boot_b` kernel first, so the rows compare with the baseline
of 222 mA measured on it. Follow `HOLDER-MATRIX-RUNBOOK.md` (PR #143):
Wi-Fi SSH, cable out, screen off, started detached with
`--wait 120 --settle 20`. About 19 minutes. The owner is not needed after
the start.

### S5. K2: CPU memory-bus votes active-only

[I] K2 can only show an effect on the `ddr` count once the SoC reaches its
sleep at all.

- If S1 or S2 moved `cxsd`: boot `k2dtb` repacked with the command line of
  the variant that moved it, run the check, save
  `/sys/kernel/debug/interconnect/interconnect_summary` before the sleep,
  then one sleep as `R4g`. [I] Expect the `ddr` count or a DDR low-power row
  above 0. Compare the CPU rows of the interconnect summary and the DDR rows
  with the earlier variant; the `ddr` count alone proves no cause.
- If nothing moved `cxsd`: boot plain `k2dtb`, run the check and
  `cat /sys/kernel/debug/interconnect/interconnect_summary`, and skip the
  sleep. This only confirms that the device tree boots; the sleep result
  would say nothing.

Stop conditions as for every boot. Rollback: reboot.

### Evening: R7a and R7b

Cable out, on the kernel that showed the lowest counts: `step R7a none 1800`,
then `step R7b none 7200`. The charge counter difference between the two
gives the suspended current. Under 10 mA it is an upper bound only: the
gauge counts in 1 mAh steps. Planned as an unattended run with its own go.

## What to send back

The files `/var/lib/s2idle/R4*.log`, `R5b.log`, `R6.log`, every
`<variant>-*.txt` file, the matrix log and its output directory, and for each variant the sha256 and the
result of the smoke test. Remove MAC addresses and anything from
`/proc/cmdline` beyond the two options before pasting anywhere public.
