<!-- SPDX-License-Identifier: MIT -->
# Power management for an always-reachable Linux phone

**Status:** design analysis for a future Omarchy Mobile proposal. No code,
package, phone state or upstream repository was changed for this analysis.
The device experiment plan is [`device/instantnoodlep/PM-PLAN.md`](../device/instantnoodlep/PM-PLAN.md).

Evidence labels are strict: **[V]** is supported by a cited source or local
file and line; **[I]** is a design inference or a device fact that still needs
measurement. “Upstream” below is derekross/omarchy-mobile at commit
[`c4623572be1c`](https://github.com/derekross/omarchy-mobile/tree/c4623572be1c141d602cf99a83ae0bf9e3eea09c),
checked read-only on 2026-11-18.

## 1. Product model: a phone has to be reachable

A laptop can often suspend when its lid closes because no one expects a call
to wake it. A phone has a different contract: spend most of the day with the
display dark and the radios reachable, wake briefly for calls, messages and
alarms, and still last the day. [I] The target is not “suspend whenever the
display turns off”; it is “meet a bounded reachability contract at the lowest
measured idle power.”

| State | Display / work | Reachability and transition policy |
| --- | --- | --- |
| **Active** | Screen lit, interactive, normal performance. | Power key/touch enters this state. Screen timeout locks and blanks, then enters screen-off idle. |
| **Screen-off idle** | Panel/backlight off; CPU remains available. Reduce refresh, brightness, radios' scan activity, CPU/GPU policy. | Initial safe default; notification sockets and call signaling stay alive. After a short, configurable idle grace, suspend only if every required wake route is qualified and no inhibitor is active. |
| **Deep sleep** | System suspend; only selected wake hardware remains armed. | Enter from idle after lock and grace. Wake on power key, RTC alarm, and only qualified modem/Wi-Fi/USB sources. Resume to a short service window; return to sleep if the screen remains dark. |
| **In-call** | Screen may blank by proximity; audio, modem, DSP and call-control path active. | Sleep is inhibited unless call audio/modem wake behavior has explicit qualification. End call returns to prior idle/active policy. |
| **Media playing** | Audio pipeline remains active; screen can be off. | Suspend inhibited while a real playback stream is RUNNING. Pause/end returns to idle. Background audio should not be mistaken for an idle sink. |
| **Navigation / location** | GPS/location session and display policy may remain active; screen can be off. | Continuous GNSS session inhibits full suspend unless the receiver and host can maintain tracking through suspend. End navigation releases the inhibitor. |
| **Charging** | USB or wireless power present; thermal and charge policy apply. | Do not assume “plugged in means safe to suspend”: preserve alarms and thermal protections. Charging may allow background maintenance; display timeout remains normal. Charging must be qualified separately from suspend. |
| **Low battery / critical** | Reduce performance and optional work; preserve user-facing alarms and emergency reachability. | Warn early; defer sync, stop optional GNSS, reduce display/radio work. Critical action should be a last-resort orderly shutdown with enough reserve, never surprise suspend that drops a call. |

Transitions should be event-driven where possible: lock + display off → idle;
idle timer expires and no veto → suspend; qualified wake event → resume;
dark resume → service bounded wake reason and sleep again; power-key or
notification requiring attention → light lock screen; call/media/navigation
start → acquire inhibitor; end → release; charger/thermal/battery events
adjust policy. [I]

## 2. Existing mobile Linux approaches

These projects solve overlapping problems, but their exact stacks and device
assumptions differ. Their published architecture is useful precedent, not
proof that a particular component will work on this phone.

| Stack | Power-management shape | What Omarchy Mobile can learn |
| --- | --- | --- |
| **postmarketOS / Phosh** | [V] Phosh is a shell that talks over D-Bus to GNOME components such as `gnome-settings-daemon`, UPower and `iio-sensor-proxy`; `feedbackd` handles haptics. Phosh/Phoc's Wayland protocols include output power management. [Phosh developer overview](https://gnumdk.pages.gitlab.gnome.org/phosh/gettingstarted.html) | Reuse established desktop services for display state, battery and feedback, but a shell timeout alone does not establish wake-capable suspend or push delivery. [I] |
| **Plasma Mobile / PowerDevil** | [V] PowerDevil tracks idle, screen-lock and sleep inhibitors, applies battery/AC/low-battery profiles, can request suspend and adjusts display brightness; Plasma Mobile supplies its own UI. It talks to UPower, systemd and related services. [PowerDevil README](https://github.com/KDE/powerdevil/blob/master/README.md), [KDE power settings](https://docs.kde.org/stable_kf6/en/powerdevil/kcontrol/powerdevil/) | A shared policy daemon plus UI is a useful model; mobile-specific policy must distinguish screen-off from system suspend. [I] |
| **Sxmo** | [V] Sxmo models `unlock`, `lock`, `screenoff`, `suspend/CRUST`, and proximity states. Configurable suspendable states include `screenoff 3`; a block-suspend hook checks active work, while suspend and post-wake hooks run around sleep. Its described suspend mode leaves the modem available to monitor calls/SMS. [Sxmo man page](https://manpages.debian.org/experimental/sxmo-utils/sxmo.7.en.html), [Sxmo docs](https://sxmo.org/docs/user/sxmo.7.html) | Make state transitions and veto hooks explicit, and treat modem wake as a hardware+driver property that must be measured. [I] |
| **Ubuntu Touch / repowerd** | [V] `repowerd` handles power policy and features such as double-tap-to-wake; per-device configuration can define quirks and a script performance booster that tunes CPU/GPU policy and suspension, including freezing/thawing processes on devices that need it. [UBports repowerd docs](https://docs.ubports.com/sv/latest/porting/configure_test_fix/device_info/Repowerd.html) | Keep SoC/device quirks behind a device policy interface rather than hard-coding them into a generic shell. [I] |
| **Sailfish OS / MCE / DSME** | [V] MCE (Mode Control Entity) manages global screen/touch/power modes and button events; Sailfish documents distinct screen and power modes and radio state coordination. DSME (Device State Management Entity) exposes battery-empty notification and reboot requests in the documented D-Bus API; it is part of device-state/lifecycle handling, and should not be assigned MCE's suspend-policy role. [MCE docs](https://docs.sailfishos.org/Reference/Core_Areas_and_APIs/Device_Management/Mce/), [networking overview](https://docs.sailfishos.org/Reference/Core_Areas_and_APIs/Networking/), [D-Bus APIs](https://docs.sailfishos.org/Reference/Core_Areas_and_APIs/D-Bus_APIs/) | Centralize mode transitions and coordinate radio/network activity with periodic wake windows. [I] |
| **Android Doze / wake locks** | [V] Android Doze delays app network, jobs and sync during long idle periods, then opens maintenance windows; alarms have exemptions/limits and SMS/MMS can temporarily whitelist apps. [AOSP Doze](https://source.android.com/docs/core/power/platform_mgmt), [app guidance](https://developer.android.com/training/monitoring-device-state/doze-standby) | Linux needs a deliberate background-work budget and push path; simply keeping every desktop daemon continuously connected may burn the battery. Avoid copying Android's app-kill semantics as a first step. [I] |

## 3. Kernel mechanisms and SM8250 expectations

### 3.1 System sleep vs idle states

[V] Linux exposes system sleep through `/sys/power/state`; `freeze` means
suspend-to-idle (s2idle), while `mem` selects the current `/sys/power/mem_sleep`
variant (`s2idle`, `shallow`, or `deep`). `deep` conventionally means
suspend-to-RAM and requires platform/firmware support. [Linux sleep-state
docs](https://kernel.org/doc/html/latest/admin-guide/pm/sleep-states.html)

[V] The checked SM8250 DTS describes PSCI 1.0 CPU and cluster idle states; the
instantnoodlep power plan records a PSCI PC-mode firmware note and expects
s2idle only until verified otherwise ([POWER-M5-PLAN.md:127-146](../device/instantnoodlep/POWER-M5-PLAN.md#L127)). [I] A kernel advertising
`deep` does not prove that this handset's firmware enters a usable low-power
state or resumes correctly. The first safe default is explicitly s2idle.
Never select `deep` based solely on a sysfs token.

[V] Kernel `wakeup_sources` accounting reports active events, event counts,
timeouts and timing; `power/wakeup` controls whether wake-capable devices are
allowed to wake the system. `autosleep` is a kernel policy mechanism, but
Linux documentation calls it an opportunistic sleep policy, not a substitute
for application-level phone policy. [Linux wakeup-source ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-wakeup),
[power ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-power),
[device wakeup policy](https://www.kernel.org/doc/html/latest/driver-api/pm/devices.html)

[V] CPUIdle selects per-CPU idle states during ordinary idle; it is separate
from system-wide suspend. CPUFreq governors select operating points within
the active CPU policy; devfreq governs devices such as GPUs and memory
controllers where configured. Runtime PM lets individual devices suspend
while the system stays active. These mechanisms all matter to screen-off
idle, not just `systemctl suspend`. [CPUIdle](https://kernel.org/doc/html/latest/admin-guide/pm/cpuidle.html),
[CPUFreq](https://kernel.org/doc/html/latest/admin-guide/pm/cpufreq.html),
[runtime PM](https://kernel.org/doc/html/latest/power/runtime_pm.html),
[devfreq](https://kernel.org/doc/html/latest/driver-api/devfreq.html)

### 3.2 Expected device wake sources (qualification required)

| Source | Evidence / current status |
| --- | --- |
| Power key | [V] PM8150 PON/power-key node and mainline driver/config are identified in [POWER-M5-PLAN.md:66,141-143](../device/instantnoodlep/POWER-M5-PLAN.md#L141). [I] Board node enablement and resume are not yet qualified on the daily kernel. |
| PMIC RTC alarm | [V] PMIC RTC node/driver and alarm IRQ are described in [POWER-M5-PLAN.md:66,143](../device/instantnoodlep/POWER-M5-PLAN.md#L143). [V] RTC currently loses time across boot until network sync ([NOTES.md:119-121](../device/instantnoodlep/NOTES.md#L119)). [I] Alarm wake and long-term clock keeping need test. |
| Modem call/SMS | [V] SDX55 is a PCIe/MHI endpoint; a candidate host wake GPIO exists in generic SM8250 DTS, but its board mapping and behavior are unresolved ([MODEM-M5-PLAN.md:72,79-99](../device/instantnoodlep/MODEM-M5-PLAN.md#L72)). [I] MHI/QMI SMS notification and voice-call wake during s2idle are not demonstrated; external modem wake requires the modem remain powered, a correctly wired WAKE# route, and userspace resume/service. |
| Wi-Fi WoWLAN | [V] Daily kernel Wi-Fi connects, but WoWLAN qualification is not recorded ([docs/agents/state.md](../agents/state.md)). [I] WoWLAN needs driver/firmware support, wake IRQ routing and an AP configuration; do not promise push while suspended. |
| USB plug | [V] PM8150B Type-C/PD IRQs are in the candidate DTS, but the Type-C node is absent from current K2 and charging is unimplemented ([POWER-M5-PLAN.md:63,80,146](../device/instantnoodlep/POWER-M5-PLAN.md#L63)). [I] Plug wake is not qualified; charging is currently not working under our kernels ([docs/agents/state.md](../agents/state.md)). |
| Hall / alert slider | [V] The alert-slider electrical interface and event mapping are unknown ([MISC-HW-PLAN.md:77](../device/instantnoodlep/MISC-HW-PLAN.md#L77)). [I] Hall/slider wake should be treated as absent until measured; do not assume the display panel's Hall path is a kernel wake source. |
| Thermal / battery | [V] TSENS and fuel-gauge candidate support is documented in [POWER-M5-PLAN.md:97-103,131-146](../device/instantnoodlep/POWER-M5-PLAN.md#L97). [I] Thermal interrupt wake and fuel-gauge polling cost need measurement. |

Wake-source success is not a single property: establish that the IRQ can
wake the SoC, the device driver restores state, the relevant daemon receives
the event, and the screen/audio/UI responds within the target latency. [I]

## 4. Userspace policy and notification delivery

### 4.1 One policy owner, kernel as executor

The desktop compositor owns output state (Hyprland DPMS); `hypridle` can
time out and lock/turn off the display. `systemd-logind` owns system sleep
requests, sleep inhibitors, and the `PrepareForSleep` transition signal;
systemd sleep configuration selects kernel sleep mode. [V: upstream
`packages/omamobile-shell/bin/omamobile-sleepd:15-28,81-107,120-127`,
[`sleep.conf`](https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-device-cheetah/vendor/systemd/sleep.conf.d/10-omamobile.conf),
and upstream `packages/omamobile-omarchy/patches/0021-sleep-turn-the-display-off-before-suspend.patch`).

[V] In the checked upstream tree, `hypridle` does not appear as a tracked
power-policy file; the phone sleep watcher and Omarchy's lock/sleep patches
implement the phone path. The device logind drop-in sets
`HandlePowerKey=ignore` and `HandlePowerKeyLongPress=ignore`, leaving the
short press to Omarchy's Hyprland binding and the long press to hardware. The
device sleep drop-in selects s2idle and disables hibernation. [V: upstream
[`logind.conf`](https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-device-cheetah/vendor/systemd/logind.conf.d/10-omamobile-power-key.conf),
[`sleep.conf`](https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-device-cheetah/vendor/systemd/sleep.conf.d/10-omamobile.conf),
and repository search at that commit.]

[V] Current upstream does not rely on stock `hypridle` alone: its shell's
`omamobile-sleepd` watches secure lock + screen-off, defaults to a 30-second
off/locked delay and a 5-second dark-resume grace, calls `systemctl suspend`,
and vetoes suspend for Stay Awake, an SSH session, a blocking logind inhibitor,
or a running PipeWire sink. A power-key wake lights the lock screen. System
sleep is configured as s2idle on qualified Pixel devices; hibernation is
disabled. The modem package may conservatively hold a systemd sleep inhibitor
until modem suspend is verified. These are current implementation facts, not
a claim that instantnoodlep is qualified. [V: cited files above; upstream
`packages/omamobile-modem/systemd/omamobile-modem-inhibit.service`].

[I] Keep Hyprland/hypridle responsible for screen dim/lock/DPMS, but make one
phone-aware service the sole automatic suspend requester. It should observe
screen and lock state, battery/charger state, inhibitors and device-qualified
wake capabilities; use logind/systemd for actual suspend. Avoid parallel
idle timers in compositor, logind and a separate power daemon. A future
generic service should expose policy and reason telemetry, while device
packages provide sleep mode and wake-source gates.

### 4.2 Inhibitors and scheduled wake

Use logind inhibitors (or a thin project API that maps to them) for bounded
work that cannot pause safely:

- **Call/ring path:** inhibitor begins when call setup/ringing/audio is active;
  release on hangup/timeout. [I] Cellular call signaling may need to remain
  armed while suspended, so this cannot replace modem wake qualification.
- **Alarm:** a near-term alarm schedules an RTC wake, not a permanent blocker.
  Alarm UI/audio holds an inhibitor once fired. [I]
- **Media:** inhibit only while playback is genuinely active; Bluetooth audio
  and call audio count. Pause releases it.
- **GNSS/navigation:** inhibit while continuous tracking is requested; permit
  sleep when an application can resume tracking after wake. [I]
- **Downloads / sync:** prefer resumable work and scheduled maintenance wakes;
  use a bounded inhibitor only for a critical transaction, with watchdog or
  timeout. A download should not silently hold the phone awake indefinitely.
- **User-held:** an explicit Stay Awake toggle is a persistent visible veto.
  SSH/USB tether sessions can be treated as temporary vetoes with clear UI.

For scheduled wakes, maintain the system clock from a trusted sync source,
program the RTC alarm, wake into a short maintenance budget, perform queued
sync, then re-enter suspend. [I] A stale RTC (1970) makes calendar wakes
unreliable until time synchronization is fixed. Coalesce background jobs to
avoid wake storms.

### 4.3 Notifications without Google services

On an always-running system, an app can hold a persistent TLS connection or
IMAP IDLE session. [V] IMAP IDLE lets a server signal mailbox changes over an
open IMAP connection ([RFC 2177](https://www.rfc-editor.org/rfc/rfc2177)); it
still requires the CPU/network path to remain available and periodic
reconnects, so it is not a radio-off push mechanism. [I]

[V] UnifiedPush uses an app-selected distributor; its Linux list includes
KUnifiedPush and its server ecosystem includes ntfy/Gotify/NextPush.
[
UnifiedPush distributors](https://unifiedpush.org/users/distributors/),
[FAQ](https://unifiedpush.org/users/faq/)
]. An ntfy-based implementation still needs a live transport or a wake-capable
network path; a distributor is not by itself a kernel wake source. [I] For
desktop Linux, consider a single system notification broker with a
long-lived connection in screen-off idle; in deeper sleep use modem SMS/call
signaling, tested Wi-Fi WoWLAN, or scheduled network windows. Clearly label
which notification classes may be delayed while sleeping.

## 5. Recommended design for Omarchy Mobile

### 5.1 Components and ownership

1. **Hyprland + shell lock/DPMS:** dim, lock securely, power down the panel;
   keep input wake behavior and the power-key UX. Never equate DPMS with
   system suspend. [I]
2. **`omamobile-sleepd` or its successor:** one policy engine; receives
   idle/lock/display, battery, charging, media, call, GNSS, alarm and explicit
   user-veto state. Requests sleep only through logind/systemd. [V] Existing
   upstream `omamobile-sleepd` already follows most of this shape, but its
   generic policy is cautious about modem suspend. [V: cited upstream file]
3. **systemd-logind + sleep hooks:** canonical suspend coordinator and
   inhibitor API; sleep.conf selects the device-qualified variant. Device
   hooks perform only bounded preparation/resume work, such as stopping a
   known-unsafe radio driver. Never make a shell script write `mem_sleep` on
   every transition. [I]
4. **Device power profile:** a device package declares supported suspend
   mode and qualified wake sources; generic service refuses sleep if required
   reachability is absent. Unknown means unavailable, not assumed. [I]
5. **Kernel policies:** use runtime PM, cpuidle, CPUFreq and GPU devfreq
   defaults first. Add per-device governor/latency changes only after measured
   screen-off energy and performance data. Enable WoWLAN or modem wake only
   after end-to-end resume tests. [I]
6. **Notification broker / background scheduler:** consolidate app delivery,
   coalesce sync, bound maintenance windows, persist pending notifications;
   show the user reachability limitations and current sleep inhibitors. [I]

### 5.2 Initial policy defaults (proposal)

| Setting | Proposed starting value |
| --- | --- |
| Display timeout | 30 s on battery, configurable; then lock and DPMS-off. [I] |
| Suspend grace | 30 s after secure lock + positive display-off state; at least 5 s to avoid racing a power-key interaction. This matches current upstream's conservative default. [V/I] |
| Dark resume grace | 5 s, then resuspend if still locked/dark and no work remains. [V] Existing upstream default is 5 s. |
| Suspend mode | s2idle only until each device has a tested deeper state; no hibernate without swap/encryption/recovery design. [I] |
| Calls / alarm ring / live media / active GNSS | visible suspend inhibitors. Alarms schedule RTC wake rather than inhibit hours in advance. [I] |
| Long transfer | resumable transfer + scheduled wake; explicit bounded inhibitor for non-resumable critical writes. [I] |
| Low battery | defer optional sync and location, keep call/alarm path, reduce display/CPU/GPU and scan frequency; critical shutdown only at a qualified threshold. [I] |
| Charger | allow maintenance while plugged in, retain thermal monitoring; do not disable automatic suspend solely due to cable insertion. [I] |
| Wake-source policy | enable only power key and RTC first; add each radio/USB/Hall source after qualification; log wake IRQ and `wakeup_sources` deltas. [I] |
| Fallback | if suspend fails or required wake route is absent, remain in screen-off idle, report reason, and back off retries (e.g. 30 s). [I] |

### 5.3 Generic upstream work vs device work

**Generic upstream proposal:** define a small policy contract (states,
inhibitors, alarm scheduling, bounded work windows, resume reasons), make
the sleep service the single automatic requester, expose diagnostics for
“why not sleeping?”, and keep compositor display-off separate from system
sleep. Add a testable interface for device wake capabilities. Improve
notification/background scheduling and user visibility. [I]

**Per-device package / kernel:** choose `MemorySleepMode`, report supported
wake sources, install verified power-key/RTC/charger/wireless settings, and
add device sleep hooks only for a measured driver quirk. SM8250/instantnoodlep
must establish modem and Wi-Fi wake first. Do not upstream a device-specific
GPIO number or claim call/SMS reachability from the generic service. [I]

## 6. Measurement and gated experiments

### 6.1 Baseline and tools

[V] The owner reports approximately **180 mA screen-off with Wi-Fi on under
the daily kernel**; the measurement conditions, duration, temperature and
gauge averaging window are not recorded here. Treat this as a reported
baseline to reproduce, not a controlled [V] benchmark. [I]

Read gauge current from the BQ27411 power-supply `current_now` attribute
(the kernel ABI reports microamps; verify sign/units on this driver before
calculating). [V: [POWER-M5-PLAN.md:97-103](../device/instantnoodlep/POWER-M5-PLAN.md#L97)]
Use a fixed interval, timestamp, average/median, battery state, screen/radio
state, ambient temperature and test duration. Minimal read-only sampler:

```sh
#!/bin/sh
# Run as root or with read access; prints no identifiers.
set -eu
gauge=${GAUGE:-/sys/class/power_supply/bq27411-0/current_now}
interval=${INTERVAL:-5}
while :; do
  printf '%s %s\n' "$(date -Is)" "$(cat "$gauge")"
  sleep "$interval"
done
```

Discover the actual name safely with `for p in /sys/class/power_supply/*; do
[ -r "$p/current_now" ] && printf '%s\n' "$p/current_now"; done`.
Capture wakeup-source deltas before/after each fixed window from
`/sys/kernel/debug/wakeup_sources` (mount debugfs only if already permitted
by the owner; no debug register access), and suspend statistics / wake IRQ
from `/sys/power/suspend_stats` and `/sys/power/pm_wakeup_irq`. Also sample
`/proc/interrupts`, CPU idle state residency, CPU/GPU frequencies, Wi-Fi
association/powersave, display `bl_power`/DPMS and thermal zones. [V: kernel
[wakeup-source ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-wakeup),
[CPUIdle docs](https://kernel.org/doc/html/latest/admin-guide/pm/cpuidle.html)]

Run controlled A/B windows: screen on/off; Wi-Fi disconnected/associated;
Bluetooth off/on; modem unavailable/available; GNSS off/on; audio idle/active;
USB cable absent/present; screen-off idle vs s2idle. One factor changes per
run. Report sample count and distribution, not just a single gauge reading.
[I]

### 6.2 Owner-gated phone runbook

No phone experiment was run for this document. These steps require an
explicit owner go for each step under workspace `AGENTS.md` rule 1. Use the
already RAM-booted, known-good image only; no flash, partition writes, DTBO
changes, or slot changes. Keep a fresh SSH/serial observation path where
possible, but note that suspend may cut USB networking. Keep captures private.

| Step | Exact command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P0: baseline | `adb shell 'uname -r; cat /sys/power/mem_sleep; cat /sys/power/state; grep -H . /sys/class/power_supply/*/current_now'` then sample gauge for 10 min with display off, Wi-Fi connected, no transfer. | Kernel release, sleep modes and a stable current distribution recorded; no identity data. | Gauge absent/implausible or unexpected kernel/mode. | No state changed; stop and revise meter path. |
| P1: s2idle entry/exit | Owner starts external log + watchdog per local runbook; check `cat /sys/power/mem_sleep` shows s2idle selected/available; `systemctl suspend`; wake with power key after 30 s. | Suspend success counter increments; power-key wake restores lock UI, touch, Wi-Fi and gauge; wake IRQ recorded. | No wake within 60 s, kernel warning/oops, reboot, or USB/log path lost without recovery observer. | Owner hard-reboots using known recovery; do not repeat before log review. |
| P2: RTC | Set a one-shot alarm 30 s ahead with `rtcwake -m no -s 30`, then `systemctl suspend`; observe externally. | RTC wakes system near target, resume is usable, alarm cleared. | No RTC wake by 90 s or clock/time invalid. | Owner presses power key; clear only the test alarm after resume; investigate before retry. |
| P3: USB wake | With a known-safe USB power source and owner present, suspend with cable unplugged, then insert USB within 30 s. | Type-C/VBUS event wakes system once; no charge-policy error or repeated wake. | No wake, unexpected heating/current, repeated reconnect, or charging behavior not understood. | Unplug cable, wake with power key, stop; do not test charger negotiation. |
| P4: repeatability | Three P1/P2 cycles, then a 30-min screen-off s2idle drain window; compare baseline and wake-source deltas. | Three clean resumes; no unexplained wake storm; drain improves vs idle baseline. | Any failed wake or wake count grows continuously while asleep. | Disable auto-suspend in the test session and return to screen-off idle; report findings. |

The above `adb`/`systemctl` commands are deliberately not executed by this
analysis worker. The existing POWER-M5-PLAN runbook is more conservative and
specifies its own owner gates ([POWER-M5-PLAN.md:245-266](../device/instantnoodlep/POWER-M5-PLAN.md#L245)).

## 7. Risks and roadmap

| Risk | Mitigation |
| --- | --- |
| Missed calls/messages because modem cannot wake or userspace is frozen | Do not claim reachability until end-to-end call/SMS tests pass through suspend; keep modem inhibitor until qualified. |
| Stuck suspend / black screen | Start with s2idle, power-key/RTC recovery, external logs and watchdog; only one change per boot. |
| Wake storms drain battery | Record `wakeup_sources`, `pm_wakeup_irq`, interrupt counts and service wakeups; back off and disable the offending source. |
| High idle drain despite suspend | Measure display, radios, wake count and CPU residency separately; compare screen-off idle and s2idle. Avoid tuning governors by intuition. |
| Battery depletion or unsafe charging | Current kernel charging is unsupported; keep charger experiments separate and safety-gated. Critical policy must not rely on unvalidated capacity thresholds. |
| Thermal runaway / charging while asleep | Maintain thermal protections; qualify charge telemetry/control before charging and suspend overlap. |
| Notification delay / duplicate delivery | Persist notifications, deduplicate on resume, advertise delayed classes; use push only when a tested network wake route exists. |

Ordered roadmap:

1. **Instrument screen-off idle** and reproduce the ~180 mA report; first
   reduce avoidable display/radio/background cost without system suspend.
2. **Prove power-key s2idle entry/resume** and RTC wake on a RAM image;
   retain a visible/manual suspend toggle until stable.
3. **Qualify wake path layers** separately: power key, RTC, USB, Wi-Fi WoWLAN,
   then modem ring/SMS; test resume userspace and notification path, not just
   IRQ wake.
4. **Add inhibitor and alarm policy** for calls, media, GNSS, alarms, transfers
   and user hold; make refusal reasons observable.
5. **Enable automatic sleep conservatively** after display-off grace, with
   dark-resume behavior, bounded retries and low-battery maintenance policy.
6. **Tune runtime PM/CPU/GPU/radio policy** from repeated energy measurements;
   consider deeper sleep only after SoC firmware support and wake matrix pass.
7. **Upstream generic policy proposal** after the design can be demonstrated
   on one device; keep OnePlus wiring, kernel limits and thresholds in its
   device package.

