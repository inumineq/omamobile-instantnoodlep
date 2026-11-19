<!-- SPDX-License-Identifier: MIT -->
# CHARGER-RP-RUNBOOK: first attended charging session for the Type-C Rp input limit

The gated session for kernel candidate K1 of
[`POWER-PROGRAM-PLAN.md`](../../device/instantnoodlep/POWER-PROGRAM-PLAN.md)
§3 step 5. It was written from the kernel source without phone access.
**[V]** is checked in the source, **[I]** is to be checked by this runbook.

- Kernel: `inumineq/linux-omarchy-mobile`, branch
  `instantnoodlep-k3-power-chg1` @ `8907ff5b8`, three topics on
  `instantnoodlep-k3-daily2-qce-gmu` @ `bd566b604`, all in
  `drivers/power/supply/qcom_pm8150b_charger.c`:
  - F1: the watchdog bark handler pets at the charger base address.
  - F2: unbind leaves charging off and USB input on at 500 mA.
  - C1: without a bound Type-C driver, a source that advertises Rp 1.5 A or
    3.0 A in sink mode gets that input current limit. Every attach starts at
    500 mA and is classified after about 1 s.
- [V] The series writes no charge-current, float-voltage, termination, HVDCP
  or Type-C mode register. The DTB is byte-identical to the `qce-gmu`
  candidate. The config differs in `LOCALVERSION` only.
- [V] Three independent reviews; the third verdict at `8907ff5b8` is "safe
  for an owner-attended test" under this gate. KUnit 26 of 26.
- [I] Known remaining window: a limit already in force can outlive a
  re-attach until the plug interrupt is serviced. The code gives no hard
  bound for that time. Step G4 measures it from outside. Stop limit S7 and
  the owner at the meter are the protection.
- Not run on the phone. Nothing is flashed; the candidate is RAM-booted.
  Every step needs the owner's go (AGENTS.md rule 1).


## Prerequisites

- P1, on the laptop, phone in fastboot: `fastboot getvar current-slot`. Expect `current-slot: b`.
  This is the slot a reset boots, because `fastboot boot` does not persist [I: confirm here]. If
  it prints anything else, stop and do not start the session.
- P2: image packed on the coordinator host from this `Image.gz` + DTB per PM-PLAN §4.5; modules
  staged under `/usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-power-chg1/`; WATCH
  (`/root/instantnoodlep-charge-watch`) on the phone.
- P3: battery between 40 % and 80 %, gauge `voltage_now` >= 3.75 V.
- P4: meter resolution 0.01 A and 0.01 V, inline between source and phone, visible to the owner.
  Without a meter, see "Session without a meter" below.
- P5: sources with their ratings written down before the session:
  - laptop USB-A port: 0.5 A, or 0.9 A if USB 3;
  - laptop USB-C port: its Rp rating, usually 1.5 A;
  - USB-C brick: 3.0 A at 5 V.

Shell setup on the phone (root), the same in every step:

```
C=/sys/class/power_supply/pm8150b-charger; G=/sys/class/power_supply/bq27411-0
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
ls /sys/kernel/debug/regmap/          # pick the PM8150B (SPMI slave 2) directory as $R
R=/sys/kernel/debug/regmap/<that dir>
rd() { dd if=$R/registers bs=9 skip=$(($1)) count=1 2>/dev/null; }   # prints "addr: val"
```

Registers:

| Register | Meaning |
| --- | --- |
| 0x1310 | bit 4: USBIN present |
| 0x1042 | bit 0: charging enabled |
| 0x1340 | bit 0: USBIN suspended |
| 0x1370 | ICL in 50 mA steps (0a = 500 mA, 1e = 1.5 A, 3c = 3.0 A) |
| 0x150b | Type-C misc: bit 0 CC attached, bit 1 orientation, bit 3 debounce done, bit 6 source mode |
| 0x1506 | Rp: 04 = 1.5 A, 02 = 3.0 A, 08 = default |

## Stop limits, every charging step (G3-G8)

WATCH checks S1-S4 every 5 s; the owner watches the
meter all the time; the coordinator checks the gauge each step. The meter has no added tolerance:
the limit is the displayed value.

| # | Limit | Trip | Action |
| --- | --- | --- | --- |
| S1 | cell voltage high | gauge `voltage_now` > 4.44 V | Emergency |
| S2 | battery temperature | gauge `temp` > 42.0 C, or +3 C within 5 min | Emergency |
| S3 | battery current | \|gauge `current_now`\| > 2.1 A | Emergency |
| S4 | charger state | health not Good/Cool/Warm; dmesg "overvoltage", "watchdog bark", "charging stopped", "Couldn't lower the input limit" | Emergency |
| S5 | input over-voltage | meter VBUS > 5.6 V | Emergency |
| S6 | input voltage sag | meter VBUS < 4.5 V for > 2 s, or < 4.75 V for > 30 s | Emergency |
| S7 | meter over-current | **any** meter reading above the rating of the source in use (P5), or above the ICL in force (0x1370 x 50 mA) + 0.05 A; or a source/meter OCP trip | Emergency, immediately: the owner pulls the cable at the meter first, without waiting for a duration |
| S8 | cell voltage low | gauge `voltage_now` < 3.60 V, or falling > 50 mV in 5 min while on the cable (G7 included) | Soft rollback |
| S9 | heat by touch | phone, cable or source hot to the touch (owner) | Emergency |
| S10 | link lost | SSH gone > 2 min during a charging step | Emergency |

## Emergency stop

The order is fixed, and the first step uses no software.

- E1: the owner pulls the cable at the meter, or at the phone when there is no meter. Input and charging
  end at once.
- E2: the owner holds Power+VolUp until the phone resets. It boots the slot from P1.
- E3: after boot, the coordinator checks `uname -r` is the daily release and saves
  `/root/charge-watch.log` and any step log if reachable.

## Soft rollback (end of every step, and S8)

- R1: `echo 0 > $C/charging_enabled; cat $C/charging_enabled` must print 0. Within 10 s the meter
  must drop to the system load (no charge current). Without a meter: within 10 s the gauge
  `current_now` no longer has the "charging" sign. Otherwise go to E1.
- R2: the owner unplugs at the meter; the meter reads 0 A. Without a meter: the owner unplugs at
  the phone; `cat $C/online` prints 0.
- R3: `sync; reboot -f` if the link is up, else Power+VolUp.
- R4: `uname -r` is the daily release.
- `rmmod` is never a rollback step.

| Step | Exact commands | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| **G0** Type-C evidence, read only, on the current daily before any RAM boot; no Type-C driver may be bound | `for d in /sys/bus/platform/devices/*typec*; do echo "$d -> $(readlink $d/driver)"; done`; then per source (none; USB-A; laptop C both orientations; brick C both orientations), cable in for 5 s: `rd 0x1310; rd 0x150b; rd 0x1506` | no `typec` device has a driver link; no cable: 0x1310 bit 4 = 0, 0x150b bit 0 = 0; C-to-C source: 0x150b bits 0 and 3 set, bit 6 clear, bit 1 flips with the orientation, 0x1506 exactly 04 or 02 matching the source; USB-A: 0x1506 = 08 or bit 0 of 0x150b clear | a `typec` driver is bound: stop, the evidence is not for the no-driver case; `rd` prints nothing: stop and report; bit 3 never set on any C source: report, and stop the C1 program, because C1 then never trusts Rp (a safe no-op) | none needed (read only); unplug |
| **G1** kernel | `uname -r` | `7.3.0-rc6-instantnoodlep-k3-power-chg1` | wrong release | soft rollback |
| **G2** watch, then load, cable out | `nohup /root/instantnoodlep-charge-watch > /root/charge-watch.log 2>&1 & echo $! > /root/charge-watch.pid`; wait 12 s; `tail -2 /root/charge-watch.log`; only then `echo "G2 modprobe $(date)" > /dev/pmsg0; modprobe qcom_pm8150b_charger; dmesg \| grep -E 'pm8150b-charger\|bq27'` | two WATCH lines with numeric gauge voltage, temp and current before modprobe; probe lines `float voltage 3980000 uV`, `charging policy uses bq27411-0`, a zone line | WATCH lines missing or NA (do not load); modprobe > 30 s | soft rollback |
| **G3** USB-A laptop port, 10 min (also fixes the gauge sign) | plug; every 30 s: `cat $C/usb_type $C/input_current_limit $C/current_max $G/current_now $G/voltage_now; rd 0x1370` | `SDP`, 500000, 0x1370 = 0a, meter <= the port rating and <= 0.55 A; gauge `current_now` has one sign throughout: write down the sign that means "charging" for G7 | S1-S10; S7 with the USB-A rating | soft rollback |
| **G4** attach timing, laptop C port then brick | start `while sleep 0.1; do echo "$(date +%T.%N) $(rd 0x1310) $(rd 0x1370) $(cat $C/usb_type)"; done > /root/g4.log &`; then per source: unplug/replug x2 per orientation; a quick swap (out and back in < 0.3 s); on the brick, a swap to the laptop C port within 1 s | attach = first line with 0x1310 bit 4 set; from there 0x1370 <= 0a and usb_type Unknown for >= 900 ms, then 1e (laptop C) or 3c (brick); 0x1370 never above 0a within 900 ms of any attach; after the brick-to-laptop swap never 3c; dmesg has no "Couldn't lower the input limit" | S1-S10; any 0x1370 > 0a within 900 ms of an attach (Emergency; keep `g4.log`) | `kill %1`; soft rollback |
| **G5** laptop C port (Rp 1.5 A), 10 min | as G3 | Unknown/500000 for the first second, then `C`, 1500000, 0x1370 = 1e, meter <= 1.5 A at >= 4.75 V | S1-S10; S7 with 1.5 A | soft rollback |
| **G6** USB-C brick, C-to-C, 15 min, screen on | as G3, plus `cat $G/temp` every 30 s | `C`, 3000000, 0x1370 = 3c, `current_max` stable, \|battery current\| <= 2.0 A, meter <= 3.0 A, VBUS 4.75-5.25 V | S1-S10; S7 with 3.0 A; `current_max` falling below 1 A more than once | soft rollback |
| **G7** unbind (F2), USB-A cable in, battery not full | `echo 0 > $C/charging_enabled; cat $C/charging_enabled` (0); `rmmod qcom_pm8150b_charger; echo rc=$?`; at once and again after 2 min (past the 72 s bite): `test -d /sys/module/qcom_pm8150b_charger && echo LOADED; rd 0x1042; rd 0x1340; rd 0x1370; rd 0x1310; cat $G/current_now $G/voltage_now`; meter | `rc=0`; no LOADED; 0x1042 bit 0 = 0; 0x1340 bit 0 = 0; 0x1370 = 0a; 0x1310 bit 4 = 1; meter between 0.05 A and 0.55 A; gauge `current_now` never has the G3 "charging" sign; `voltage_now` falls by at most 20 mV between the two reads; both register reads equal | any check fails, any `rd` empty, or `rc != 0` (E1 then E2; do not modprobe again) | soft rollback (R1 is a no-op, charging is already off); `modprobe qcom_pm8150b_charger` must give the G2 lines before any further charging step |
| **G8** resume (optional, battery full so the policy allows sleep) | on the brick: G4 loop; `rtcwake -m freeze -s 20` | after resume 0x1370 = 0a for >= 900 ms, then 3c again | S1-S10; no resume within 60 s (E1, E2) | `kill %1`; soft rollback |

## Session without a meter

The owner has no inline USB-C meter. This section replaces every meter rule
above for a session without one. Everything else stands. An independent
review of these rules gave: the 500 mA steps are acceptable with the rules
below; every step above 500 mA needs a meter.

- [V] The phone measures its own USB input: the charger's `current_now` and
  `voltage_now` come from the PMIC ADC, `current_max` is the AICL status and
  `input_current_limit` is register 0x1370
  (`qcom_pm8150b_charger.c:1516-1531`, `pm8150b.dtsi:157-166`).
- [I] Nobody has compared that ADC with a meter on this phone. The readings
  are not independent of the PMIC under test. What the meter gave, an outside
  proof of the true current and of VBUS, is lost, and nothing here replaces it.
- [V] Measured on the daily kernel at 500 mA, screen off: input 5.05 V x
  482 mA, battery 4.03 V x about 230 mA. The input reading sits just under
  the limit, which fits a correct scale at this level. It says nothing about
  higher currents.
- [V] The owner's laptop USB-C port advertises Rp 3.0 A (0x1506 = 02, read
  on the daily kernel). With C1 that port gets a 3 A limit, so it is not a
  500 mA source for this kernel.

What runs without a meter, and what waits:

| Steps | Without a meter |
| --- | --- |
| G0 | yes, read only, every source and cable the owner has. Also `rd 0x150d` (legacy cable status: bit 1 legacy cable, bit 0 non-compliant legacy cable) |
| G1, G2 | yes |
| G3, G7 | yes, on a USB-A port and A-to-C cable that passed M0 below |
| G4, G5, G6, G8 | no. They raise the limit above 500 mA: wait for a meter |
| any C-to-C source | no. Do not plug one while the candidate's charger module is loaded |

M0, the gate for the one source, read only, on the daily kernel, before any
RAM boot. Plug the A-to-C cable into the USB-A port, wait 10 s, then five
times, 2 s apart: `rd 0x1506; rd 0x150d; cat $C/usb_type $C/input_current_limit`.

- Pass: every read has 0x1506 = 08, `usb_type` `SDP` and
  `input_current_limit` 500000.
- No-go for the whole meterless session: 0x1506 = 02 or 04 (the cable
  advertises a current it must not: non-compliant), or `usb_type` `CDP` or
  `DCP` or anything but `SDP`, or a limit above 500000. [V] The driver gives
  CDP and DCP 1.5 A, in the daily kernel as well as in the candidates
  (`qcom_pm8150b_charger.c:273-274`).
- [V] The candidates do not read the PMIC's legacy-cable status (0x150d).
  The 0x150d value is reported only, for a later guard.
- [I] M0 shows what this port and cable did under the daily kernel. It does
  not prove the candidate classifies them the same way. The watch's ceiling
  is the second line, and it reacts only at its next reading, up to about
  1 s after a higher limit is written.

Rules:

- M-P4 (replaces P4): [`tools/instantnoodlep-usbin-watch`](../../tools/instantnoodlep-usbin-watch)
  is on the phone as `/root/instantnoodlep-usbin-watch`. It reads about once
  a second. A faster event can be missed.
- M-P5 (replaces P5): one source only, a laptop USB-A port, direct, no hub.
- Before every plug:
  `nohup /root/instantnoodlep-usbin-watch 500000 > /root/usbin-<step>.log 2>&1 &`.
  After the step: `kill "$(cat /root/usbin-watch.pid)"`.
- A `STOP` line switches charging off and nothing else. The USB input stays
  on. The owner pulls the cable at once; STOP is the signal, not the action.
- An `INPUT LOST` line that the owner did not cause by unplugging means the
  source switched itself off: Emergency.
- A `NOTE AICL result` line is reported, not a stop.
- The owner holds the cable at the phone for the first 30 s after every plug
  and touches plug and port once a minute after that (S9).

| # | Replaces | Trip | Action |
| --- | --- | --- | --- |
| S5m | S5 | watch: `voltage_now` > 5.6 V | Emergency |
| S6m | S6 | watch: `voltage_now` < 4.5 V in two readings in a row, or < 4.75 V in 30 readings in a row | Emergency |
| S7m | S7 | watch: `input_current_limit` above 500000; `current_now` above the limit + 10 % + 100 mA; a reading missing with the input online. Owner: `INPUT LOST` without an unplug | Emergency, at once |

- E1 (replaces E1): the owner pulls the cable at the phone.
- R1 (replaces R1): `echo 0 > $C/charging_enabled; cat $C/charging_enabled`
  must print 0. Within 10 s the gauge `current_now` no longer has the G3
  "charging" sign. Otherwise E1.
- R2 (replaces R2): the owner unplugs at the phone; `cat $C/online` prints 0.
- G3 and G7: `usb_type` is `Unknown` for about the first second after a plug,
  then `SDP`, in every read. Any other type: Emergency.
- G3 expect, instead of the meter: every watch line has `icl_uA` 500000,
  `iusb_uA` <= 650000 and `vusb_uV` between 4750000 and 5250000.
- G7: stop the watch before `rmmod`, because the charger's sysfs directory
  goes away. The meter check is dropped; the register and gauge reads stand.

Report with the rest: the `/root/usbin-*.log` files, and for G3 the input
power (charger `voltage_now` x `current_now`) next to the battery power
(gauge `voltage_now` x `current_now`). The pair is a plausibility note only.
It does not calibrate the ADC.

## Later experiment, not in the first session: L1, a source lowers Rp while attached

(old K1-7,
multi-port charger). The driver follows a lowered Rp only on the next event pass; until then
AICL or the charger's own protection must hold the current, and neither response time is known
[I]. L1 needs its own owner go after G0-G7 pass. It also needs one of these first: a bounded
software follow-up (for example a Type-C status IRQ in the charger node), or a measured AICL
response on this board. Its stop is S7 as above, immediately, with no 10 s grace.

## What to send back

The G0 register reads per source, `/root/g4.log`, the 30 s readings of G3,
G5 and G6 with the meter values (without a meter: the `/root/usbin-*.log`
files), the G7 reads, and `/root/charge-watch.log`.
Remove serial numbers and MAC addresses before pasting anything public.
