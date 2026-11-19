<!-- SPDX-License-Identifier: MIT -->
# POWER-PROGRAM-PLAN: targets and ranked plan for power, battery and charging

This file states what "production level" means for power on the OnePlus 8 Pro
(instantnoodlep, SM8250) and ranks the work that gets there. It is the
program's frame. Runbooks stay where they are: idle, suspend and wake in
[`PM-PLAN.md`](PM-PLAN.md), charger and gauge hardware in
[`POWER-M5-PLAN.md`](POWER-M5-PLAN.md).

The targets follow upstream
[derekross/omarchy-mobile#867](https://github.com/derekross/omarchy-mobile/issues/867):
its Part A/B/C recipe is the measurement method, its Phase 0-4 "done when"
lines are the minimum bar, and its Phase 4 gives every change a home.

Evidence labels: **[V]** is checked and cites its source. **[I]** is an
inference to check on the phone. This file was written without phone access.
Phone facts come from the coordinator's reports of 2026-11-19.

## 1. Where the phone stands

| Layer | State | Evidence |
| --- | --- | --- |
| CPU idle | `psci_idle`, WFI and `cpu-sleep-0-0` / `cpu-sleep-1-0` counters climb | [V: Part A in #867, instantnoodlep comment] |
| Cluster collapse | `power-domain-cpu-cluster0` state S0 entered 8 times, 5 ms in 2.3 h | [V: coordinator report 2026-11-19] |
| SoC sleep | `qcom_stats` ddr, cxsd and aosd `Count: 0` after 7 min screen off, cable out. DDR stays at 768 MHz | [V: same report] |
| `sync_state` | QCE bound and GMU bound by a no-op driver on RAM candidate `k3-daily2-qce-gmu`. No `sync_state() pending` line is left | [V: same report; PRs #136, #141] |
| Screen-off floor | about 220 mA on `k3-daily2-qce-gmu`, about 360 mA earlier on the daily kernel. Gauge not calibrated | [V: same report; #867 comment] |
| Command line | still `clk_ignore_unused pd_ignore_unused` | [V: Part A in #867] |
| Suspend | `mem_sleep` offers `[s2idle]` only. Never tried on this phone | [V: Part A in #867] |
| Thermal | `step_wise` on every zone, no skin zone, no `power_allocator` | [V: Part A in #867] |
| Wi-Fi | power save off | [V: Part A in #867] |
| Charging | local `qcom_pm8150b_charger` driver plus a userspace charge-watch guard. 150-190 mA into the battery from a laptop port at 85-88 %. No PD or QC negotiation, no thermal-aware current | [V: coordinator report 2026-11-19] |
| Type-C | `pm8150b_typec` disabled in the daily2 DTS, USB is peripheral-only | [V: kernel `instantnoodlep-k3-daily2-qce-gmu`, `sm8250-oneplus-instantnoodlep.dts:750-751`] |

## 2. Targets

Each target has a number, a method and a home. "Minimum" is the #867
proposal. "Goal" is what this program aims for. Every goal number is [I]
until a measurement shows it can be reached on mainline.

Battery capacity used for conversions: 4500 mAh nominal [I: stock DT value
`qcom,batt_capacity_mah`, POWER-M5-PLAN §2; the pack profile is not
reconciled yet].

### T1. The SoC sleeps

| ID | Target | Method | Minimum (#867) | Goal |
| --- | --- | --- | --- | --- |
| T1.1 | Cluster power collapse while awake and idle | genpd `idle_states` of `power-domain-cpu-cluster0` over a 10 min screen-off window | counts up | above 50 % residency |
| T1.2 | CX shutdown and AOSS sleep | `qcom_stats` `cxsd` and `aosd` `Count` before and after | not named | both advance in every s2idle cycle |
| T1.3 | DDR low-power mode | `qcom_stats` `ddr` / `ddr_stats`, interconnect summary for `ebi` | bus scaling exists | DDR leaves 768 MHz with the screen off |
| T1.4 | Boot without `clk_ignore_unused pd_ignore_unused` | `/proc/cmdline`, full hardware smoke test | named in Phase 2 | both dropped in the daily kernel |
| T1.5 | s2idle enters and resumes | `/sys/power/suspend_stats`, 20 cycles | 30 min sleep, no service killed | 20 of 20 per wake source |
| T1.6 | Wake sources | power key, RTC alarm, charger plug. Modem and Wi-Fi follow their own plans | 20 of 20 each | same |

### T2. Current

Measured with the #867 Part B recipe: cable out, SSH over Wi-Fi, screen off,
10 min settle, then 12 samples at 15 s, median reported. Suspended current is
computed from the gauge's charge counter across a sleep of 30 min or more,
because `current_now` is not sampled while the phone sleeps.

| ID | Target | Today | Minimum (#867) | Goal |
| --- | --- | --- | --- | --- |
| T2.1 | Screen off, awake, Wi-Fi associated | about 220 mA [V] | under 150 mA | under 80 mA |
| T2.2 | Suspended (s2idle), Wi-Fi off | not measured | not named | under 15 mA, stretch under 8 mA |
| T2.3 | Suspended, Wi-Fi connected | not measured | under 10 % in 8 h, which is 56 mA average | under 25 mA average |
| T2.4 | SoC temperature, screen off | not measured | within 10 °C of the battery | same |

The goals are set from two reference points. Google's power model puts a
stock Pixel 8 Pro at about 77 mA screen off and awake [V: #867 body]. A
second mainline Qualcomm phone on the thread, the OnePlus 13, reads about
134 mA screen off without SoC sleep [V: #867, dodge comment]. Published
mainline SM8250 numbers are being collected and will replace these if they
disagree.

### T3. Charging

| ID | Target | Method | Goal |
| --- | --- | --- | --- |
| T3.1 | Correct source detection and input limit | `power_supply` `usb_type`, `input_current_limit` per source: SDP, CDP, DCP, Type-C 1.5 A and 3 A | limit matches the source, never above it |
| T3.2 | Faster charging on standard chargers | gauge current into the battery at 20-60 % | 5 V up to 3 A from a Type-C source. USB-PD fixed 9 V if the PM8150B input path allows it [I] |
| T3.3 | Thermal and JEITA limits | charge current against battery and skin temperature | no charge below 0 °C or above 45 °C battery, reduced current in the cool and warm bands, skin-temperature step-down |
| T3.4 | Termination and recharge | status reaches `Full`, current stops, recharge threshold | float voltage and termination current from the reconciled pack profile, no trickle at full |
| T3.5 | Charge limit | `charge_control_end_threshold` on the battery supply, 80-100 % | works from the upstream Settings Battery page ([#860](https://github.com/derekross/omarchy-mobile/pull/860)) |
| T3.6 | Userspace view | `upower -d`: status, health, capacity, time to full | correct in charging, full, discharging, not charging and fault cases |
| T3.7 | Safe without a guard | kill the charge-watch guard, suspend while charging | kernel alone keeps every limit. The guard stays as a second layer until this passes |
| T3.8 | No regression | charge-watch guard run, 15 min, laptop port | same pass criteria as P2-5..P2-7 |

OnePlus Warp/VOOC and wireless charging are out of scope: both need a
proprietary protocol [V: POWER-M5-PLAN §3.1, §3.4].

### T4. Thermal

| ID | Target | Minimum (#867) |
| --- | --- | --- |
| T4.1 | 10 min all-core load without a userspace guard | stays under 95 °C |
| T4.2 | Skin zone from the PM8150B ADC thermistor | present, with trips |
| T4.3 | `power_allocator` can bind | energy model on every CPU |

### T5. Upstream shape

Every change gets one home, per #867 Phase 4:

| Home | What goes there |
| --- | --- |
| Mainline kernel, staged in `inumineq/linux-omarchy-mobile` | DTS changes for the board and `sm8250.dtsi`, driver fixes, one topic per commit with a commit message that explains why. Mirrored as patches in `device/instantnoodlep/patches/pm/` and `patches/power/` |
| OmaMobile device package `omamobile-device-instantnoodlep` | sleep profile gates, wake-source switches, charge-limit default, Wi-Fi power save default |
| OmaMobile or Omarchy | shell and compositor wakeups, if Part C shows them |
| This repo | PM-PLAN and POWER-M5-PLAN runbooks, baselines, learnings |

The baseline goes upstream as an issue titled "Power baseline: OnePlus 8 Pro
(instantnoodlep)" with Part A, B and C output, posted by the owner.

## 3. Ranked plan

Ranking rule: phone time is the scarce resource, so work is ordered by
information per boot. Tests that need no new kernel come first. Each kernel
candidate changes one variable and gets a gated RAM-boot runbook in PM-PLAN
before it is requested.

The ranking below is the first version. Four research units are checking it
against the kernel source and against other mainline SM8250 ports. Their
results will reorder steps 3-6 and are recorded in §4.

| Rank | Step | Needs | Answers | Target |
| --- | --- | --- | --- | --- |
| 1 | Baseline with the #867 recipe, Part A, B and C, on the daily kernel and on `k3-daily2-qce-gmu` | existing images | the comparable floor, and who is awake | T2.1, T5 |
| 2 | s2idle first attempt: `pm_test` ladder, then one real suspend with a power-key wake and an RTC dead-man | existing image | whether suspend works at all, and whether cxsd and aosd move inside s2idle | T1.2, T1.5 |
| 3 | Runtime holder matrix over Wi-Fi SSH, cable out: one volatile toggle at a time, reading `qcom_stats`, the cluster domain and the gauge after each. Toggles: unbind the USB gadget, unload bwmon, Wi-Fi off, PCIe ASPM policy, UFS auto-hibernate | existing image | which holder keeps the cluster and CX up | T1.1-T1.3 |
| 4 | Drop `pd_ignore_unused`, then `clk_ignore_unused` | repack only, one flag per boot | whether unused domains and clocks are the CX holder | T1.4 |
| 5 | One kernel candidate per confirmed holder, most valuable first. Suspects: USB interconnect vote held with the cable out, CPU bwmon interrupt rate, UFS and PCIe link power states | kernel build | the fix | T1.1-T1.3, T2.1 |
| 6 | Wake sources in the DTS and drivers: RTC alarm, charger plug | kernel build | T1.6 | T1.6 |
| 7 | Charging C1: source detection and input current limit for DCP and Type-C current advertisement | kernel build, owner present | faster charging from a wall charger at 5 V | T3.1, T3.2 |
| 8 | Charging C2: JEITA and skin-temperature current steps, termination and recharge in the kernel | kernel build, owner present | T3.3, T3.4, T3.7 | T3 |
| 9 | Charging C3: `charge_control_end_threshold` | kernel build | T3.5 | T3.5 |
| 10 | Charging C4: USB-PD sink at 9 V with Type-C enabled and DP alt mode off | kernel build, owner present | whether PD can be had without the DP gadget regression | T3.2 |
| 11 | Thermal: skin zone, then `power_allocator` | kernel build | T4 | T4 |
| 12 | Device package: sleep profile, wake switches, charge-limit and Wi-Fi power save defaults | package build | T1.5, T3.5 | T5 |

Steps 1-3 share one phone session where possible. Steps 7-10 run in parallel
with 4-6 in separate kernel branches and are merged into one daily candidate
only after each passed alone.

### Gates that apply to every step

- No phone access from the program host. Every phone test is a request to the
  coordinator with kernel branch and commit, artifact SHA-256 sums, packer
  inputs, commands, Expect and stop conditions.
- RAM boot only (`fastboot boot`). Nothing is flashed without the owner's go.
  Never `super`, never an `_a` partition.
- Charging tests that raise current or voltage need the owner present, a
  battery temperature ceiling of 45 °C and a battery voltage ceiling from the
  reconciled profile as stop conditions.

## 4. Decision log

| Date | Decision | Why |
| --- | --- | --- |
| 2026-11-19 | Targets and plan live in this file, not in PM-PLAN | PM-PLAN is changed by open PRs #136 and #141 |
| 2026-11-19 | `fw_devlink.sync_state=timeout` is not used | it kills the USB gadget [V: PM-PLAN §4.5 on PR #141] |
| 2026-11-19 | Warp/VOOC and wireless charging stay out of scope | proprietary protocols [V: POWER-M5-PLAN §3.1, §3.4] |
