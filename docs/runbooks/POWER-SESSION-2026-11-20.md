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
- [I] The two boot options `pd_ignore_unused` and `clk_ignore_unused` keep
  power domains or clocks on through suspend. S1 and S2 test them one at a
  time.

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
adb reboot bootloader            # or the key combination
fastboot getvar current-slot     # Expect: b
fastboot boot <image>
```

**Check after boot**, over USB SSH, or Wi-Fi SSH if USB is missing:

```sh
uname -r
tr ' ' '\n' </proc/cmdline | grep -E 'slot_suffix|ignore_unused'
dmesg | grep -iE 'genpd|gdsc|rpmhpd|clk: .*unused|Disabling unused' | tail -40
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > /var/lib/s2idle/<name>-genpd.txt
modprobe rtc-pm8xxx; modprobe qcom_stats
sha256sum /var/lib/s2idle/step
```

Expect: release `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu`, slot `_b`,
exactly the options the variant should have, and the step tool with sha256
`6c5200f48d0508fba3ceb3d66f350ee408af8898b66065dedc24bd4894309f1e`.

**Smoke test**: the screen shows the desktop, touch reacts, Wi-Fi is
connected, one of the two SSH paths works, and `dmesg` has no UFS error.

**One sleep, cable out** (`<step>` is the step name):

```sh
systemd-run --on-active=45 --unit=s2idle-<step> --collect /var/lib/s2idle/step <step> none 60
```

The owner pulls the cable within 30 s, leaves the screen off, touches
nothing for 2 minutes, then plugs the cable back in. Read
`/var/lib/s2idle/<step>.log`.

**Stop conditions for every boot**: no picture and no SSH on either path
3 minutes after `fastboot boot`: forced reboot. The phone then starts the
kernel on `boot_b`. A failed smoke test: note what failed, skip the sleep,
reboot.

**Stop conditions for every sleep**: no resume after 120 s: press Power
once. No reaction after 180 s: forced reboot, then read `/sys/fs/pstore/*`
and `journalctl -b -1` first, and no repeat before review. Several
`suspend entry` lines within seconds: a wake loop, stop.

**Rollback**: a reboot. Nothing persistent changes in this session.

## Order

| Step | What | Time | Runs when |
| --- | --- | --- | --- |
| S0 | start state | 5 min | always |
| S1 | `nopd`, sleep R4d | 15 min | always |
| S2a | `noclk`, sleep R4e | 15 min | S1 left `cxsd` at 0 |
| S2b | `noboth`, sleep R4f | 15 min | S1 and S2a both left `cxsd` at 0, and both booted cleanly |
| S3 | R5b volume key, R6 systemd path | 15 min | always |
| S4 | holder matrix, short pass | 25 min, unattended | always |
| S5 | `k2dtb`, sleep R4g | 15 min | see S5 |
| evening | R7a and R7b suspended current | 30 min and 2 h, unattended | separate go |

About 75 minutes if S1 answers the question, about 105 minutes if all of S2
is needed. The owner is needed at the phone for S0 to S3 and S5. S4 runs
alone.

### S0. Start state

On the `boot_b` kernel, cable in:

```sh
uname -r; tr ' ' '\n' </proc/cmdline | grep -E 'slot_suffix|ignore_unused'
grep -H . /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
```

Expect: the `boot_b` release, slot `_b`, both options present. Stop on any
other slot: a forced reboot into slot A erases the Arch root.

### S1. Without `pd_ignore_unused` (request 9)

Boot `nopd`, run the check and the smoke test, then one sleep as step `R4d`.

| Expect | Reading |
| --- | --- |
| the command line has `clk_ignore_unused` only | the variant is the one intended |
| the sleep lasts about 60 s and wakes on `pm8xxx_rtc_alarm` | as R4 |
| [I] `cxsd` or `aosd` above 0 after the sleep | the option was the blocker. Skip S2. The option then leaves the daily kernel as its own later step, with a full hardware check |
| [I] all three still 0 | go to S2a |

Send back: `R4d.log`, the `nopd-genpd.txt` file and the `dmesg` lines of the
check.

### S2a. Without `clk_ignore_unused`

Boot `noclk`, run the check and the smoke test, then one sleep as `R4e`.

This variant lets the kernel switch off every clock no driver holds, late
in boot. [I] The risk is a device that worked only because its clock was
left on, for example the panel or USB. Watch the screen during boot. If USB SSH is missing, use Wi-Fi SSH and note it; the
smoke test passes with one working SSH path.

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

- R5b: `... step R5b none 300`, cable out, the owner presses Volume Down at
  about 30 s. Expect a resume within 2 s and the volume key as the wake IRQ.
  The 300 s alarm is the dead-man.
- R6: cable out, from a detached unit:
  `systemd-run --on-active=45 --unit=s2idle-R6 --collect sh -c 'rtcwake -d rtc0 -m no -s 300 && systemctl suspend'`.
  Expect `Timekeeping suspended for` about 300 s, no `Watchdog timeout` in
  `journalctl -b`, logind and NetworkManager working afterwards.

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
  the variant that moved it, run the check, then one sleep as `R4g`. Expect
  [I] the `ddr` count or a DDR low-power row above 0.
- If nothing moved `cxsd`: boot plain `k2dtb`, run the check and
  `cat /sys/kernel/debug/interconnect/interconnect_summary`, and skip the
  sleep. This only confirms that the device tree boots; the sleep result
  would say nothing.

Stop if the boot is unstable or the phone gets warm. Rollback: reboot.

### Evening: R7a and R7b

Cable out, on the kernel that showed the lowest counts: `step R7a none 1800`,
then `step R7b none 7200`. The charge counter difference between the two
gives the suspended current. Under 10 mA it is an upper bound only: the
gauge counts in 1 mAh steps. Planned as an unattended run with its own go.

## What to send back

The files `/var/lib/s2idle/R4*.log`, `R5b.log`, `*-genpd.txt`, the matrix
log and its output directory, and for each variant the sha256 and the
result of the smoke test. Remove MAC addresses and anything from
`/proc/cmdline` beyond the two options before pasting anywhere public.
