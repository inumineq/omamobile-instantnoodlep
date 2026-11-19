<!-- SPDX-License-Identifier: MIT -->
# CHARGE-LIMIT-WAKE-RUNBOOK: charge limit and cable wake, first attended session

The gated session for kernel candidate K3 of
[`POWER-PROGRAM-PLAN.md`](../../device/instantnoodlep/POWER-PROGRAM-PLAN.md)
§3 steps 8 and 9. It was written from the kernel source without phone access.
**[V]** is checked in the source, **[I]** is to be checked by this runbook.
Run it only after [`CHARGER-RP-RUNBOOK.md`](CHARGER-RP-RUNBOOK.md) (K1) and
the ladder in [`S2IDLE-FIRST-RUNBOOK.md`](S2IDLE-FIRST-RUNBOOK.md) have
passed, because K3 is built on K1 and its sleep steps use the s2idle step
tool.

- Kernel: `inumineq/linux-omarchy-mobile`, branch
  `instantnoodlep-k3-power-chg2` @ `8ef0c4799`, two topics on K1
  (`instantnoodlep-k3-power-chg1` @ `8907ff5b8`), both in
  `drivers/power/supply/qcom_pm8150b_charger.c`:
  - A: `charge_control_end_threshold` on the charger supply. Accepted values
    are 50 to 100. 100 is the default and means no limit. Below 100 charging
    stops at the limit and resumes 5 points below it. USB input stays on.
  - B: a cable plug or unplug wakes the phone from s2idle. Userspace can turn
    it off at `pm8150b-charger/device/power/wakeup`.
- [V] Suspend is refused unless the charge-disable write succeeded. This
  also applies at the default limit of 100, where the base driver ignored
  the write's result.
- [V] The limit can only stop charging. It never enables charging against
  the safety policy or `charging_enabled=0`. If the gauge capacity cannot be
  read, charging stays off while a limit below 100 is set.
- [V] Three independent reviews; the third verdict at `8ef0c4799` is "safe
  for an owner-attended test" under this gate. KUnit 57 of 57.
- [I] Everything the steps below expect. Not run on the phone. Nothing is
  flashed; the candidate is RAM-booted. Every step needs the owner's go
  (AGENTS.md rule 1).

The sleep steps use
[`tools/instantnoodlep-s2idle-step`](../../tools/instantnoodlep-s2idle-step)
installed as `/var/lib/s2idle/step`, with `S2IDLE_KEEP_CHARGING=1` so the
tool does not switch charging off and the driver's own decision is what is
tested. Its log is `/var/lib/s2idle/<step>.log`.

AGENTS.md rule 1). The owner is present, with the inline meter, for every step that has a cable
in (H1-H8, W1, W2, W4, W5) and for the plug in W3.

## Prerequisites

- P1, on the laptop, phone in fastboot: `fastboot getvar current-slot`. Expect `current-slot: b`,
  the slot a reset boots, because `fastboot boot` does not persist. Anything else: stop, do not
  start the session.
- P2: image packed on the coordinator host from this round's `Image.gz` + DTB (SHA-256 in the
  phone request) per PM-PLAN §4.5; modules from the round's tarball under
  `/usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-power-chg2/`; WATCH
  (`/root/instantnoodlep-charge-watch`) on the phone.
- P3: battery between 40 % and 80 %, gauge `voltage_now` >= 3.75 V.
- P4: meter resolution 0.01 A and 0.01 V, inline between source and phone, visible to the owner.
- P5: only the laptop USB-A port is used (SDP, 0.5 A, or 0.9 A if USB 3); rating written down.
- P6: the R0 pre-checks of S2IDLE-FIRST-RUNBOOK and its RTC self-test
  (`rtcwake -d rtc0 -m no -s 10`) passed on this boot. The step tool is installed at
  `/var/lib/s2idle/step` from a revision that knows `S2IDLE_KEEP_CHARGING`.

## Shell setup, root, every step

```
C=/sys/class/power_supply/pm8150b-charger; G=/sys/class/power_supply/bq27411-0
W=$C/device/power/wakeup
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
ls /sys/kernel/debug/regmap/          # pick the PM8150B (SPMI slave 2) directory as $R
R=/sys/kernel/debug/regmap/<that dir>
rd() { dd if=$R/registers bs=9 skip=$(($1)) count=1 2>/dev/null; }   # prints "addr: val"
st() { echo "$(date +%T) cap=$(cat $G/capacity) st=$(cat $C/status) gst=$(cat $G/status) en=$(cat $C/charging_enabled) end=$(cat $C/charge_control_end_threshold) ibat=$(cat $G/current_now) vbat=$(cat $G/voltage_now) $(rd 0x1042) $(rd 0x1340) $(rd 0x1370)"; }
ss() { for f in success fail failed_prepare failed_suspend last_failed_dev last_failed_errno; do printf '%s=%s ' $f "$(cat /sys/power/suspend_stats/$f 2>/dev/null)"; done; echo; }
gate() { dmesg | grep -E 'not suspending|cannot s(et|top) charging|charger watchdog bark|charge limit' | tail -8; }
```

Registers: 0x1042 bit 0 charging enabled (`charging_enabled` reads the same bit); 0x1340 bit 0
USBIN suspended; 0x1370 ICL in 50 mA steps (0a = 500 mA); 0x1310 bit 4 USBIN present.

## How a sleep step records its outcome

Before every `run`: `ss; rd 0x1042`. After it: `ss`,
`gate`, `rd 0x1042`, and the wrapper log `/var/lib/s2idle/<step>.log` (it has `state write rc` and the
suspend_stats snapshots). Exactly one of these is the outcome:

| Outcome | How it shows | Meaning |
| --- | --- | --- |
| **Slept** | `state write rc=0`; `success` +1; `pm_wakeup_irq` names the waking IRQ | 0x1042 bit 0 was confirmed clear by the suspend callback |
| **Refused, charging** | `state write rc` != 0; `fail` +1, `failed_suspend` unchanged; dmesg `battery is charging, not suspending` | the notifier vetoed: the policy wants charging with the cable in |
| **Refused, cable pending** | `state write rc` != 0; `fail` +1; dmesg `cable change pending, not suspending`; `failed_suspend` +1 and `last_failed_dev` the charger device if the callback refused, unchanged if the notifier did | a plug edge not yet decided by the policy; released within 5 s |
| **Refused, cannot stop charging** | `state write rc` != 0; `fail` +1, `failed_suspend` +1, `last_failed_dev` the charger device, `last_failed_errno` the write's error; dmesg `cannot stop charging, not suspending: <err>` | the charge-disable write or its read failed; the PMIC state is not under the driver's control. Always S11 |

## Stop limits, every step with a cable in

WATCH checks S1-S4 every 5 s; the owner watches the
meter all the time; the coordinator checks the gauge each step. The meter has no added tolerance.

| # | Limit | Trip | Action |
| --- | --- | --- | --- |
| S1 | cell voltage high | gauge `voltage_now` > 4.44 V | Emergency |
| S2 | battery temperature | gauge `temp` > 42.0 C, or +3 C within 5 min | Emergency |
| S3 | battery current | \|gauge `current_now`\| > 2.1 A | Emergency |
| S4 | charger state | health not Good/Cool/Warm; dmesg "overvoltage", "watchdog bark", "charging stopped", "Couldn't lower the input limit". Exception: one `charger watchdog bark` right after a resume from a sleep of more than 64 s with the cable in (H7, W4) is expected; a second one, or one while awake, trips S4 | Emergency |
| S5 | input over-voltage | meter VBUS > 5.6 V | Emergency |
| S6 | input voltage sag | meter VBUS < 4.5 V for > 2 s, or < 4.75 V for > 30 s | Emergency |
| S7 | meter over-current | any meter reading above the USB-A rating (P5), or above 0x1370 x 50 mA + 0.05 A; or a source/meter OCP trip | Emergency, at once: the owner pulls the cable at the meter |
| S8 | cell voltage low | gauge `voltage_now` < 3.60 V, or falling > 50 mV in 5 min while on the cable | Soft rollback |
| S9 | heat by touch | phone, cable or source hot to the touch (owner) | Emergency |
| S10 | link lost | SSH gone > 2 min during a step with the cable in | Emergency |
| S11 | charger write failed | any dmesg `cannot set charging` or `cannot stop charging, not suspending`, at any time | cable in: Emergency; cable out: soft rollback, then end the session. No repeat until reviewed |
| S12 | charging against the decision | 0x1042 bit 0 = 1 while `status` is not `Charging` or `Full`, read twice 6 s apart | Emergency |

## Emergency stop

Fixed order; the first step uses no software.

- E1: the owner pulls the cable at the meter. Input and charging end at once.
- E2: the owner holds Power+VolUp until the phone resets. It boots the slot from P1.
- E3: after boot, the coordinator checks `uname -r` is the daily release and saves
  `/root/charge-watch.log`, `/var/lib/s2idle/*.log` and `/sys/fs/pstore/*` if reachable.

## Soft rollback (end of every step, and S8)

- R0: `echo 100 > $C/charge_control_end_threshold`.
- R1: `echo 0 > $C/charging_enabled; cat $C/charging_enabled` must print 0. Within 10 s the meter
  must drop to the system load (no charge current). Otherwise go to E1.
- R2: the owner unplugs at the meter; the meter reads 0 A.
- R3: `sync; reboot -f` if the link is up, else Power+VolUp.
- R4: `uname -r` is the daily release.
- `rmmod` is never a rollback step.

## Sleep-step timeouts

For a `run <step> none N`: no resume by N + 60 s:
the owner presses Power once; no reaction by N + 120 s: forced reboot (long-press), then
`cat /sys/fs/pstore/*` and `journalctl -b -1` before anything else. A wake loop (more than one
`suspend entry` within 60 s) is a stop in every sleep step. `run X a b` below is short for
`systemd-run -E S2IDLE_KEEP_CHARGING=1 --unit=k3-x --collect /var/lib/s2idle/step X a b`.

| Step | Exact commands | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| **H0** load, cable out | `uname -r`; start WATCH as CHARGER-RP-RUNBOOK G2 (`nohup /root/instantnoodlep-charge-watch > /root/charge-watch.log 2>&1 &`, wait 12 s, `tail -2 /root/charge-watch.log`); `modprobe qcom_pm8150b_charger`; `dmesg \| grep -E 'pm8150b-charger\|bq27'`; `cat $C/charge_control_end_threshold; ls $C/ \| grep -c charge_control_start; cat $W; grep usbin-plugin /proc/interrupts` | release `7.3.0-rc6-instantnoodlep-k3-power-chg2`; two numeric WATCH lines before modprobe; probe lines `float voltage 3980000 uV`, `charging policy uses bq27411-0`, a zone line; `100`; `0`; `enabled`; one `usbin-plugin` line | wrong release; WATCH lines missing (do not load); missing file; `disabled` | soft rollback |
| **H1** limit off = today, USB-A, 5 min | plug; `st` every 30 s | `Charging`, 0x1042 bit 0 = 1, 0x1370 = 0a, meter <= 0.55 A; gauge `current_now` keeps one sign (write it down as "charging"); no `charge limit` line in dmesg | S1-S12 | soft rollback |
| **H2** hold now | `cap=$(cat $G/capacity); e=$(( cap < 50 ? 50 : cap )); echo $e > $C/charge_control_end_threshold; echo rc=$?`; `st` at 1 s, 10 s, then every 30 s for 5 min | rc 0. If cap >= 50: within 1 s `Not charging`, 0x1042 bit 0 = 0, 0x1340 bit 0 = 0, 0x1370 = 0a; dmesg `charge limit N %, battery at M %: not charging`; gauge `current_now` within +-100 mA of 0 or a small discharge; meter = system load <= 0.55 A. If cap < 50 (end is 50, the lowest accepted): the battery charges toward 50, `Charging` stays; continue only if H1's checks still hold, then go to H4 | S1-S12; `Charging` or 0x1042 bit 0 = 1 more than 5 s after the write when cap >= 50 | soft rollback |
| **H3** invalid writes | `cur=$(cat $C/charge_control_end_threshold); for v in 101 -1 30 49; do echo $v > $C/charge_control_end_threshold; echo "$v rc=$?"; cat $C/charge_control_end_threshold; done`; then `echo 80 > $C/charge_control_end_threshold; echo rc=$?; cat $C/charge_control_end_threshold` | each of the four: rc != 0 (`write error: Invalid argument`) and the read-back equals `$cur`; status unchanged from H2; then 80: rc 0, reads `80` | a refused value read back; 80 refused | `echo $cur > $C/charge_control_end_threshold` |
| **H4** charge to a raised limit | `e=$(( $(cat $G/capacity) + 2 )); (( e < 50 )) && e=50; echo $e > $C/charge_control_end_threshold; echo rc=$?`; `st` every 30 s until `Not charging` or 40 min | rc 0; `Charging` within 1 s; within 5 s of `capacity` reaching the end: `Not charging`, 0x1042 bit 0 = 0, dmesg `... : not charging` | S1-S12; still `Charging` 60 s after `capacity` >= end | soft rollback |
| **H5** no restart inside the band | keep H4's limit; the owner unplugs for 2 min, screen on, replugs; `st` | if `capacity` > end - 5: stays `Not charging`, 0x1042 bit 0 = 0; if <= end - 5: `Charging` | `Charging` while `capacity` > end - 5 | soft rollback |
| **H6** limit off again | `echo 100 > $C/charge_control_end_threshold`; `st` at 1 s | `Charging` (or `Full`) within 1 s; dmesg `... : charging allowed` | S1-S12 | soft rollback |
| **H7** sleep while held, cable in, longer than the watchdog bite | set the limit as in H2 and wait for `Not charging`, 0x1042 bit 0 = 0 (twice, 6 s apart); `ss; rd 0x1042`; `systemd-run -E S2IDLE_KEEP_CHARGING=1 --unit=k3-h7 --collect /var/lib/s2idle/step H7 none 120`; after it: `ss; gate; st` | Outcome **Slept**: resume at ~120 s, `pm_wakeup_irq` = the `pm8xxx_rtc_alarm` IRQ; no `not suspending` line; after resume `Not charging`, 0x1042 bit 0 = 0; one `charger watchdog bark` allowed (S4 exception: 120 s is past the 64 s bark and the 72 s bite). Record the outcome row in every case | Refused, cannot stop charging (S11, Emergency); Refused, charging (the limit did not hold: soft rollback); Refused, cable pending (nobody touched the cable: record, soft rollback); timeouts 180 s / 240 s | S2IDLE-FIRST-RUNBOOK R4 rollback if it did not resume, then soft rollback |
| **H8** control: no limit, charging, suspend refused; bite recovery | `echo 100 > $C/charge_control_end_threshold`; `st` at 1 s and 10 s; confirm `Charging`; `ss`; `systemd-run -E S2IDLE_KEEP_CHARGING=1 --unit=k3-h8 --collect /var/lib/s2idle/step H8 none 60`; `ss; gate` | bite recovery after H7: `Charging` and 0x1042 bit 0 = 1 within 10 s of the write, meter shows charge current again; then outcome **Refused, charging**: `state write rc` != 0, `fail` +1, `failed_suspend` unchanged, dmesg `battery is charging, not suspending`, no sleep | the phone sleeps while `Charging`; any other outcome; 0x1042 bit 0 = 0 or no charge current 10 s after the write (bite not recovered: record, soft rollback) | soft rollback |
| **W1** plug wakes | cable **out**; `cat $W` (`enabled`); `ss`; `systemd-run -E S2IDLE_KEEP_CHARGING=1 --unit=k3-w1 --collect /var/lib/s2idle/step W1 none 120`; the owner plugs the USB-A cable at ~30 s (meter in line); `ss; gate; st` | outcome **Slept**, resume within 2 s of the plug; `pm_wakeup_irq` names `usbin-plugin`; within 5 s `online` 1 and `Charging` (end 100), the phone stays awake (charging veto) | no resume at the plug and none by 180 s: Power; by 240 s: forced reboot; wake loop; S11, S12 | S2IDLE-FIRST-RUNBOOK R4 rollback, soft rollback |
| **W2** unplug wakes | cable **in**, limit holding as H2 (`Not charging`, 0x1042 bit 0 = 0); `ss`; `run W2 none 120`; the owner unplugs at ~30 s | outcome **Slept**; resume within 2 s of the unplug; wake IRQ `usbin-plugin`; `online` 0, `Discharging` | as W1; Refused, cannot stop charging (S11, Emergency) | as W1 |
| **W3** wake off by userspace | `echo disabled > $W`; cable out; `ss`; `run W3 none 60`; the owner plugs at ~20 s; after resume `ss; gate; st`; `echo enabled > $W` | outcome **Slept**; no wake at the plug; resume at ~60 s by `pm8xxx_rtc_alarm`; within 5 s of resume `online` 1 and the cable classified (0x1370 = 0a, `usb_type` SDP) | a wake at the plug; cable not seen 10 s after resume; S11, S12 | `echo enabled > $W`; soft rollback |
| **W4** no wake loop with the cable in | cable in, limit holding (0x1042 bit 0 = 0); `grep -E 'usbin-plugin\|wdog-bark' /proc/interrupts; ss`; `run W4 none 300`; the same grep, `ss; gate` after | outcome **Slept**; one `suspend entry`; resume at ~300 s by RTC; `usbin-plugin` count unchanged; `wdog-bark` +0 or +1, at most one `charger watchdog bark` (S4 exception) | more than one suspend entry; a wake by `usbin-plugin` with nobody touching the cable; Refused, cannot stop charging (S11, Emergency); timeouts 360 s / 420 s | S2IDLE-FIRST-RUNBOOK R4 rollback, soft rollback |
| **W5** re-suspend guard (optional) | cable out, end 100; `run W5 none 120`; the owner plugs at ~30 s; at once after resume: `ss; systemd-run -E S2IDLE_KEEP_CHARGING=1 --unit=k3-w5b --collect /var/lib/s2idle/step W5b none 60; ss; gate` | W5: **Slept**, plug wake as W1. W5b, one of: **Refused, cable pending** (the first pass after resume had not run; record whether `failed_suspend` moved, which shows notifier or callback); or **Refused, charging** (the pass ran, the battery is below the limit). Never **Slept** while `online` 1 and `Charging` is expected | W5b **Slept** while a new `usbin-plugin` count shows and no charging decision was logged since; S11, S12 | soft rollback |

## What to send back

`/var/lib/s2idle/H7.log`, `H8.log` and `W*.log`, the `st`, `ss` and `gate`
output of every step with the meter readings, and `/root/charge-watch.log`.
Remove serial numbers and MAC addresses before pasting anything public.
