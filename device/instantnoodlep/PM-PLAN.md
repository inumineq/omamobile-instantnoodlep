<!-- SPDX-License-Identifier: MIT -->
# PM-PLAN: phone idle, suspend and wake qualification on instantnoodlep

House-rule-6 plan for the **userspace/kernel power-management policy** on the
OnePlus 8 Pro IN2023. Hardware, charging and M5 power enablement remain under
[`POWER-M5-PLAN.md`](POWER-M5-PLAN.md); modem and GNSS are covered by
[`MODEM-M5-PLAN.md`](MODEM-M5-PLAN.md) and [`GNSS-M5-PLAN.md`](GNSS-M5-PLAN.md).
This is a design and gated runbook only: no phone was accessed and no code or
device configuration was changed. The general design is
[`docs/POWER-MANAGEMENT-ANALYSIS.md`](../../docs/POWER-MANAGEMENT-ANALYSIS.md).

Evidence labels: **[V]** has a cited source/file line; **[I]** is unverified
or must be checked on the handset. Dates refer to this workspace's state on
2026-11-18.

## 1. Current device facts and constraints

- [V] Daily K3 is installed on `boot_b`, reaches Hyprland with GPU, Wi-Fi,
  Bluetooth and BQ27411 gauge; no charging is supported by our kernel.
  [docs/agents/state.md](../../docs/agents/state.md)
- [V] Owner-reported baseline is about 180 mA screen-off with Wi-Fi under the
  daily kernel; test conditions are absent, so this is a starting report, not
  a controlled benchmark. [Task measurement; reproduce in P0.]
- [V] BQ27411 candidate is at I2C16 `0x55`; the mainline bq27xxx I2C driver
  supports `ti,bq27411`. [POWER-M5-PLAN.md:97-103](POWER-M5-PLAN.md#L97)
- [V] Current POWER-M5 plan considers PSCI s2idle the supported path, with
  power key and PMIC RTC as intended wake sources; handset resume is
  unverified. Modem WAKE#, Type-C wake and thermal sources also require
  qualification. [POWER-M5-PLAN.md:137-146](POWER-M5-PLAN.md#L137)
- [V] RTC time resets to 1970 each boot until network time is established;
  alarm scheduling before time sync is unsafe. [POWER-M5-PLAN.md:143](POWER-M5-PLAN.md#L143)
- [V] SDX55 is a candidate PCIe/MHI external modem; board wake wiring is not
  yet confirmed, calls are explicitly unverified, and modem work has not been
  tested on this kernel. [MODEM-M5-PLAN.md:72,79-99](MODEM-M5-PLAN.md#L72)
- [V] GNSS is an on-demand SDX55 QMI/QRTR service and must not run alongside
  another LOC owner; behavior is untested. [GNSS-M5-PLAN.md:48-72](GNSS-M5-PLAN.md#L48)
- [V] Alert-slider electrical interface and input mapping are unknown.
  [MISC-HW-PLAN.md:77](MISC-HW-PLAN.md#L77)
- [I] Current `mem_sleep` list/value, actual wake-enabled IRQs, USB wake, Wi-Fi
  WoWLAN, Hall wake, and interrupt behavior must be read from the current RAM
  boot before policy selection.

**Safety boundary:** no writes to `super`, any `_a` partition, modem/NV,
`persist`, or slot metadata. No flash or erase. Only owner-authorized RAM boot
is in scope, and all power experiments below require a separate explicit go
for that step under AGENTS.md rule 1. Charging experiments are excluded; the
current kernel does not support charging.

## 2. Proposed states and policy

| State | instantnoodlep behavior |
| --- | --- |
| Active | Normal interactive policy; compositor handles brightness and timeout. |
| Screen-off idle | Initial default. DPMS/backlight off, remain reachable in userspace; measure baseline and reduce noisy polling before suspend. |
| s2idle | Enter only after lock secure + display positively confirmed off + grace; start with power key and RTC as candidate wake sources. |
| In-call / ringing | Hold suspend inhibitor until call path is end-to-end qualified; after qualification keep modem wake armed and inhibit during active audio. |
| Media | Inhibit while PipeWire playback is RUNNING; return to normal sleep policy on pause/end. |
| Navigation | Hold inhibitor for active tracking until GNSS/modem resume behavior and power cost pass. |
| Alarm | Program RTC after trusted clock sync; wake at alarm time and keep an inhibitor while alert is active. |
| Charging | Not available under current kernel; preserve the feature as future policy only. Do not use USB attach as proof of charging. |
| Low battery | Defer optional sync and GNSS; keep calls/alarms; reduce scan/background work. Do not set thresholds until battery profile and gauge calibration are reconciled. |

[I] Prefer upstream's existing `omamobile-sleepd` and systemd-logind path as
the policy foundation rather than a second independent daemon. The current
upstream sleep watcher uses 30 s display-off grace and 5 s dark-resume grace;
it checks lock, display, Stay Awake, SSH, logind blockers and PipeWire
playback. [V: upstream
[`omamobile-sleepd`](https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-shell/bin/omamobile-sleepd#L15)]
For this device, keep auto-sleep disabled until P1/P2 prove wake. Use systemd
`MemorySleepMode=s2idle` only after the actual kernel exposes it and the owner
gates qualification. [V: [Linux sleep states](https://kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html)]

## 3. Component inventory / values to verify

| Subsystem | Current evidence | Power-policy relevance / gate |
| --- | --- | --- |
| CPU idle | [V] SM8250 DTS has CPU and cluster PSCI idle states, `arm,psci-1.0` SMC. [POWER-M5-PLAN.md:127-135](POWER-M5-PLAN.md#L127) | Read `/sys/devices/system/cpu/cpuidle/*/{name,usage,time}` before/after idle; CPUIdle is distinct from system suspend. [I] Verify residency increases on display-off. |
| CPU frequency | [V] SM8250 has `qcom-cpufreq-hw` with three frequency domains; stock DT overlay rewrites root compatible and may allow a duplicate generic cpufreq provider. [POWER-M5-PLAN.md:22-28,134](POWER-M5-PLAN.md#L22) | Verify one scaling driver per policy and sensible min/max/governor; do not force governors before measuring. |
| GPU | [V] Freedreno GPU works on combo K3; thermal zones include GPU cooling maps. [docs/agents/state.md](../../docs/agents/state.md); [POWER-M5-PLAN.md:131-134](POWER-M5-PLAN.md#L131) | Read devfreq available/current frequency and governor; test that panel-off and idle compositor allow downscaling. [I] |
| Runtime PM | [V] Linux runtime PM is available per-device; exact enabled devices vary by driver. [Linux runtime PM docs](https://kernel.org/doc/html/latest/power/runtime_pm.html) | Capture `power/control`, `runtime_status`, `autosuspend_delay_ms` for Wi-Fi, PCIe, USB and GPU; do not force `auto` on a device until wake works. [I] |
| Wi-Fi | [V] Daily kernel connects to Wi-Fi. [docs/agents/state.md](../../docs/agents/state.md) | Record NetworkManager powersave setting, association, WoWLAN flags and wake IRQ. WoWLAN not qualified. [I] |
| Display | [V] Hyprland renders on GPU; upstream separates DPMS from suspend and powers down supported panel backlights before system suspend. [upstream patch 0021](https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-omarchy/patches/0021-sleep-turn-the-display-off-before-suspend.patch) | Verify Hyprland DPMS off *and* backlight `bl_power` state; DPMS alone may not power the panel off. [I] |
| Thermal | [V] SM8250 TSENS and multiple thermal zones are described in POWER-M5 plan. [POWER-M5-PLAN.md:131-134](POWER-M5-PLAN.md#L131) | Keep thermal protection active; record temperatures during screen-off, suspend/resume and future charging qualification. |
| Gauge/charger | [V] Gauge candidate is BQ27411; no working charger driver on current kernel. [POWER-M5-PLAN.md:97-103](POWER-M5-PLAN.md#L97); [docs/agents/state.md](../../docs/agents/state.md) | Gauge sampling only; no charger policy inference from USB current. |
| RTC / PON | [V] PMIC RTC + PON power-key nodes exist in generic tree, but power key is disabled in the generic DTS; plan proposes enabling node. [POWER-M5-PLAN.md:66,141-143](POWER-M5-PLAN.md#L141) | Owner must first verify runtime `/dev/rtc*`, alarm support, `wakeup_sources`, and correct wall clock. |
| Modem | [V] Candidate MHI endpoint, no handset test; call support unverified. [MODEM-M5-PLAN.md:85-99](MODEM-M5-PLAN.md#L85) | Keep system-sleep inhibitor in place until modem resume, SMS, ring and voice-call paths each pass their own gate. |
| USB / Type-C | [V] Type-C wake IRQs are identified but Type-C node absent from current K2; no charging. [POWER-M5-PLAN.md:105-112,146](POWER-M5-PLAN.md#L105) | Test attach wake only after node is enabled in a reviewed kernel and charging/thermal limits are safe. |
| Hall / alert slider | [V] Alert slider unknown. [MISC-HW-PLAN.md:77](MISC-HW-PLAN.md#L77) | Not a required wake source for first policy; don't create a binding from guesses. |

## 4. Measurement plan

### 4.1 Controlled baseline

Repeat the owner-reported ~180 mA screen-off/Wi-Fi baseline with stable
network, no active SSH transfer, screen at confirmed DPMS/backlight-off,
Wi-Fi associated, Bluetooth and modem state recorded, and no charging. Run
at least 10 minutes after a 5-minute settle, at a recorded battery and
ambient temperature. Use median and range, plus sample count. Change one
factor per follow-up: Wi-Fi off, BT off, modem absent/present, GNSS, audio,
screen, suspend. [I]

Find the gauge path without assuming its sysfs name:

```sh
for p in /sys/class/power_supply/*; do
  [ -r "$p/current_now" ] && printf '%s\n' "$p/current_now"
done
```

Small timestamped sampler (read-only):

```sh
#!/bin/sh
# Usage: GAUGE=/sys/class/power_supply/<name>/current_now INTERVAL=5 ./sample-current
set -eu
gauge=${GAUGE:?set GAUGE to the verified current_now path}
interval=${INTERVAL:-5}
while :; do
  printf '%s %s\n' "$(date -Is)" "$(cat "$gauge")"
  sleep "$interval"
done
```

Record `/sys/kernel/debug/wakeup_sources` before and after each window,
including `event_count`, `wakeup_count`, `active_count`, `total_time`,
`max_time` and `last_change`; also sample `/sys/power/suspend_stats`,
`/sys/power/pm_wakeup_irq`, `/proc/interrupts`, CPUIdle residency,
`scaling_cur_freq`, GPU devfreq, Wi-Fi power save, display backlight/DPMS,
thermal zones, modem status and gauge SOC/voltage. [V: Linux
[wakeup ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-wakeup),
[suspend interface](https://kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html)]
Debugfs remains diagnostic-only; no regmap/PMU access. [V: AGENTS.md safety
rule in this workspace.]

### 4.2 Owner gates (no run performed)

All test blocks require the owner's explicit go for that individual step.
These tests change only volatile runtime state. Use a known RAM-boot image,
external logs and an owner-present recovery path. No fastboot flash/erase,
slot marking, charger probing, or modem NV access.

| Gate | Exact command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G0: identify state | `adb shell 'uname -r; cat /sys/power/mem_sleep; cat /sys/power/state; cat /sys/power/wakeup_count; grep -H . /sys/class/power_supply/*/current_now'` | Correct daily/RAM image, s2idle present/selected, gauge responds with stable units. | Unexpected kernel, `deep` only, no gauge, or implausible current. | Read-only; stop and update plan/evidence. |
| G1: baseline | Run the sampler for 10 min, display off and Wi-Fi on; collect only aggregate values. | Reproducible distribution and conditions noted. | Gauge path changes/vanishes or heating/current anomaly. | Stop sampler. |
| G2: s2idle/power key | `systemctl suspend`; owner waits 30 s then presses power key once. Watch external kernel log and suspend counters. | `s2idle` entered, success increments, power key wakes panel/UI, no errors. | No wake by 60 s, hard hang, reboot or unexplained repeated wake. | Owner uses known hard-reboot method; do not retry before logs reviewed. |
| G3: RTC | After trusted time sync, `rtcwake -m no -s 30`; then `systemctl suspend`. | Resume occurs near 30 s and alarm is no longer armed. | No wake by 90 s, RTC reports invalid time, or wrong clock. | Power-key wake; clear test alarm after resume. Stop RTC testing until time issue fixed. |
| G4: USB attach wake | With owner present and known-safe 5 V source, unplug USB; `systemctl suspend`; reinsert cable after 30 s. | One wake on attach, stable thermal/current, no charger negotiation surprise. | No wake, heat/current abnormality, repeated attach wake or charge state unclear. | Unplug, wake by power key. Do not test higher PD voltage or charging. |
| G5: wake storm | Capture `wakeup_sources`, suspend for 10 min with only qualified wake sources enabled, then power-key wake. | No unexplained IRQ/count growth; observed drain lower than screen-off idle. | Repeated dark resumes, continuously increasing wake counts, drain no better than idle. | Disable auto-suspend for session; return to screen-off idle and review top source. |

When running suspend, USB SSH may disappear. It is not an acceptable sole
observer or recovery channel; use the local console/log stream arrangement
specified by the owner before G2-G5. [I]

## 5. Roadmap and unresolved items

1. Reproduce screen-off baseline and find dominant wake/power consumers.
2. Pass power-key s2idle and RTC wake on the RAM image, with clean UI resume.
3. Measure USB wake after Type-C support is available; keep charger path out
   of this plan until separate safe charger work is complete.
4. Confirm Wi-Fi WoWLAN support and AP behavior; do not rely on it for calls.
5. Complete MODEM-M5/GNSS-M5 prerequisites; test SMS/ring and voice call wake
   end-to-end with the modem inhibitor policy still explicit.
6. Add visible inhibitor reasons and scheduled wake windows; only then enable
   automatic screen-off suspend in a device package.
7. Re-evaluate deeper suspend, CPUFreq/devfreq and runtime-PM tuning against
   controlled power measurements.

Open [I]s: actual sysfs sleep modes; power-key node state; RTC persistence and
alarm accuracy; USB wake; WoWLAN; PCIe/MHI wake; modem ring/SMS/call delivery;
Hall/slider events; gauge units/averaging; idle current conditions; thermal
behavior during repeated resume. No claim of successful handset suspend or
all-day battery is made by this plan.
