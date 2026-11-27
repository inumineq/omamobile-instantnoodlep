<!-- SPDX-License-Identifier: MIT -->
# S2IDLE-FIRST-RUNBOOK: the first suspend-to-idle on instantnoodlep

The gated ladder for the first `s2idle` on this phone. It runs on the RAM
candidate `k3-daily2-qce-gmu` and needs no new kernel. Nothing is flashed.
Every step changes volatile state only and needs the owner's go for that step
(AGENTS.md rule 1). The recovery path is the owner's forced reboot, so the
owner is present from R4 on.

This runbook replaces gates B2/B3 and G2/G3 of
[`PM-PLAN.md`](../../device/instantnoodlep/PM-PLAN.md) §4.2-§4.3 for the
first attempt. It was written from the kernel source without phone access.
**[V]** cites the kernel tree `instantnoodlep-k3-daily2-qce-gmu` @
`bd566b604`. **[I]** is to be checked by this runbook.

## What the source says before the first try

- [V] Power key, volume keys and the RTC alarm are wake sources as built. No
  DTS or driver change is needed (`drivers/input/misc/pm8941-pwrkey.c:406-431`,
  `drivers/input/keyboard/gpio_keys.c:818-939`,
  `drivers/rtc/rtc-pm8xxx.c:641-655`). The RTC driver is a module: load
  `rtc-pm8xxx` first.
- [V] A relative RTC alarm works on an unsynced clock. `rtcwake -s N` does not
  need the wall clock to be right (`drivers/rtc/rtc-pm8xxx.c`, alarm written
  as seconds minus offset).
- [V] `pm_test` has three usable levels for s2idle: `freezer`, `devices` and
  `platform`. With `processors` or `core` the kernel performs a real sleep,
  because the s2idle loop runs before those test points
  (`kernel/power/suspend.c:445-454`). The step tool refuses both.
- [V] The charger driver returns `-EBUSY` to every suspend while it charges
  (`drivers/power/supply/qcom_pm8150b_charger.c:1124-1136`). The step tool
  turns charging off for the step and back on afterwards.
- [V] Plugging in the cable does not wake the phone: the charger attaches a
  wake IRQ but never marks the device wakeup-capable
  (`qcom_pm8150b_charger.c:1655`). The USB controller arms its wake IRQs in
  host mode only.
- [V] The hardware watchdog is stopped during suspend
  (`drivers/watchdog/qcom-wdt.c:361-369`). A sleep that never wakes needs the
  forced reboot.
- [V] The monotonic clock stops in s2idle on this kernel, because every CPU
  has an idle state with an s2idle entry (`drivers/cpuidle/cpuidle.c:144-154`,
  `kernel/time/tick-common.c:519-541`). The watchdog trouble of upstream
  [#765](https://github.com/derekross/omarchy-mobile/issues/765) should not
  appear. R6 checks it.
- [I] Risks, most likely first: Wi-Fi dead after resume (ath11k powers the
  chip down and up, the PCIe link is stopped), panel black after resume, UFS
  resume failure.

## Tool

[`tools/instantnoodlep-s2idle-step`](../../tools/instantnoodlep-s2idle-step)
runs one step and appends to `/var/lib/s2idle/<step>.log`: suspend statistics,
`qcom_stats`, the cluster domain's idle states and the gauge's charge counter
before and after, the wake IRQ, and the filtered kernel log. It refuses a real
suspend without an RTC dead-man, refuses `processors` and `core`, and refuses
to run unless the boot slot is B.

Install on the phone, from the laptop, over USB SSH:

```sh
ssh root@172.16.42.1 'install -d -m 700 /var/lib/s2idle'
scp tools/instantnoodlep-s2idle-step root@172.16.42.1:/var/lib/s2idle/step
ssh root@172.16.42.1 'chmod 700 /var/lib/s2idle/step; modprobe rtc-pm8xxx; modprobe qcom_stats'
```

Each step starts detached, because USB SSH drops from the `devices` level on:

```sh
systemd-run --unit=s2idle-<step> --collect /var/lib/s2idle/step <step> <level> <rtc seconds>
```

## R0. Pre-checks (read-only)

```sh
uname -r
tr ' ' '\n' </proc/cmdline | grep -E 'slot_suffix|ignore_unused'
cat /sys/power/mem_sleep /sys/power/state /sys/power/pm_test
dmesg | grep -E 'OSI|PC mode|CPU PM domain'
ls /sys/class/rtc/; cat /sys/class/rtc/rtc0/name
a=$(cat /sys/class/rtc/rtc0/since_epoch); sleep 5; b=$(cat /sys/class/rtc/rtc0/since_epoch); echo $((b-a))
grep -l enabled $(find /sys/devices -path '*/power/wakeup') | sed 's#/power/wakeup##'
grep -H . /sys/class/power_supply/*/online /sys/class/power_supply/*/status /sys/class/power_supply/*/charging_enabled 2>/dev/null
grep -H . /sys/power/suspend_stats/*
for f in /sys/kernel/debug/qcom_stats/*; do echo "== ${f##*/}"; cat "$f"; done
cat /sys/kernel/debug/pm_genpd/*cluster*/idle_states
grep -H . /sys/class/remoteproc/*/state
ls /sys/fs/pstore/; systemd-inhibit --list
rtcwake -d rtc0 -m no -s 10; sleep 15; grep -i alarm /proc/interrupts; grep alarm_IRQ /proc/driver/rtc
```

| Expect | Stop condition |
| --- | --- |
| release `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu` | another kernel |
| `androidboot.slot_suffix=_b` | any other slot: slot A holds another system, and this runbook is not valid there |
| `[s2idle]`, `freeze` in `state`, `[none]` in `pm_test` | `freeze` missing |
| a line with `OSI mode` [I] | `PC mode`: record it and continue, the cluster counters will read differently |
| RTC named `pm8xxx`, advances 5 (±1) in 5 s | no RTC or not advancing |
| wakeup-enabled list has the power key, `gpio-keys` and the RTC | power key or RTC missing |
| alarm self-test: the `pm8xxx_rtc_alarm` count goes up by 1, then `alarm_IRQ: no` | count unchanged: the dead-man cannot be trusted, stop before R4 |

Rollback: none, nothing was changed.

## Ladder

One step per owner go. Stop at the first failure and send the log back.

| Step | Start | Expect | Stop condition | Rollback |
| --- | --- | --- | --- | --- |
| R1 freezer | `... step R1 freezer 0` | `PM: suspend entry (s2idle)`, a 5 s wait, `PM: suspend exit`, `state write rc=0`, `success` +1. USB stays up | `Freezing ... failed`, rc not 0 | none needed. Name the refusing task |
| R2 devices | `... step R2 devices 0` | USB networking drops for 5-10 s and returns. Every device's suspend and resume time is in the log, rc=0 | `failed to suspend: error`, `last_failed_dev` set, no USB after 60 s | replug USB. Still dead after 2 min: forced reboot |
| R3 platform | `... step R3 platform 0` | late and noirq phases run, rc=0, Wi-Fi reassociates within 30 s | `late suspend of devices failed`, `noirq suspend of devices failed`, ath11k or qcom-pcie errors | Wi-Fi dead but system alive: record, `modprobe -r ath11k_pci; modprobe ath11k_pci`, then repeat R3 with `ath11k_pci` unloaded to isolate it |
| R4 real sleep, RTC wake | `... step R4 none 60`. Owner present, screen off | resume at about 60 s, wake IRQ `pm8xxx_rtc_alarm`, `Timekeeping suspended for` about 60 s, cluster `usage_s2idle` above 0. The `qcom_stats` deltas are the result, whatever they are | no resume by 120 s: owner presses Power once. No reaction by 180 s: forced reboot. Several `suspend entry` lines within seconds: wake loop, stop | after a forced reboot read `/sys/fs/pstore/*` first, then `journalctl -b -1`. No repeat before review |
| R5 power key | `... step R5 none 300`. Owner presses Power at about 30 s | resume within 2 s of the press, wake IRQ `pm8941_pwrkey`, panel back | as R4, the 300 s alarm is the dead-man. Panel black with SSH alive: record it | as R4. Panel black: restart the display manager or reboot |
| R5b volume key | as R5, Volume Down at about 30 s | wake IRQ of the volume key | as R5 | as R5 |
| R6 systemd path, 300 s | cable out, then from a detached unit: `rtcwake -d rtc0 -m no -s 300 && systemctl suspend` | `Timekeeping suspended for` about 300 s, `journalctl -b \| grep 'Watchdog timeout'` empty, logind and NetworkManager fine | any `Watchdog timeout`, session unusable | reboot |
| R7 suspended current | cable out. Two sleeps with `step`: `R7a none 1800`, then `R7b none 7200` | charge counter delta of R7b minus R7a over 90 min gives the suspended current | wake loop, phone warm | reboot |

The step tool restores `pm_test`, charging and `console_suspend` when it
exits. A reboot clears everything as well.

## What to send back

The files `/var/lib/s2idle/R*.log`. Before pasting them anywhere public,
remove MAC addresses and anything from `/proc/cmdline`.

## Reading the result

- [I] `cxsd` and `aosd` advance in R4: device votes were the blocker while
  awake, and the awake floor is the next problem.
- [I] `ddr` stays 0 while `cxsd` advances: expected, the CPUs' DDR vote is in
  the sleep set (POWER-PROGRAM-PLAN §3, candidate K2).
- [I] All three stay 0 with `usage_s2idle` above 0: suspect the ADSP and SLPI
  coprocessors or clocks held by `clk_ignore_unused`.
- R7 numbers under 10 mA are upper bounds until a USB power meter agrees: the
  gauge counts in 1 mAh steps.
