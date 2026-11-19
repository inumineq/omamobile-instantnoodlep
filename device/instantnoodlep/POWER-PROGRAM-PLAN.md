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

This is the second version of the ranking. Four research units checked the
first one against the kernel source and against other mainline ports; what
they changed is in §3.1.

| Rank | Step | Needs | Answers | Target |
| --- | --- | --- | --- | --- |
| 1 | s2idle first attempt: `pm_test` ladder, one real sleep with an RTC dead-man, then power-key wake. Runbook: [`S2IDLE-FIRST-RUNBOOK.md`](../../docs/runbooks/S2IDLE-FIRST-RUNBOOK.md) | existing image | whether suspend works, and whether cxsd and aosd move once every CPU is down | T1.2, T1.5, T1.6 |
| 2 | Runtime holder matrix over Wi-Fi SSH, cable out, one volatile toggle per row: Wi-Fi power save on, Bluetooth off, UFS QoS off, bwmon unloaded, CPUs 1-7 offline, USB runtime PM allowed, all combined | existing image, the matrix tool | what breaks the cluster's idle window and which toggle lowers the floor | T1.1, T2.1 |
| 3 | Baseline with the #867 recipe, Part A, B and C | existing image, the baseline tool | the comparable floor for the upstream issue | T2.1, T5 |
| 4 | Kernel K2: CPU DDR votes active-only in `sm8250.dtsi` | kernel build | whether DDR low-power mode appears once the CPUs' vote leaves the sleep set | T1.3 |
| 5 | Charging K1: two driver fixes and a Type-C Rp-aware input limit without the Type-C stack | kernel build, owner present, inline USB-C meter | 1.5 A or 3 A input from USB-C sources that are held at 500 mA today | T3.1, T3.2 |
| 6 | Drop `clk_ignore_unused`, then `pd_ignore_unused`, one flag per boot | repack only. Check the USB node for `qcom,select-utmi-as-pipe-clk` first | whether orphan clocks and domains hold CX | T1.4 |
| 7 | Device package: Wi-Fi power save on, USB `power/control=auto`, Bluetooth off when idle. Each only after its matrix row showed a gain | package build | the awake floor without a kernel change | T2.1, T5 |
| 8 | Charger wake: mark the charger device wakeup-capable so a plug wakes the phone | kernel build | T1.6 | T1.6 |
| 9 | Charging: `charge_control_end_threshold` and `charge_behaviour` | kernel build | T3.5, and the out-of-tree `charging_enabled` property goes away | T3.5 |
| 10 | Charging: FCC step-down from the charger thermistor, then a skin zone | kernel build, owner present | T3.3, T4.2 | T3.3, T4 |
| 11 | Charging: Type-C stack as sink with DP alt mode removed, PD at 5 V / 3 A | kernel build, owner present | whether PD can be had without the DP gadget regression | T3.2 |
| 12 | Device package: sleep profile with `SuspendState=freeze`, wake switches, charge-limit default. Upstream: `omamobile-sleepd` power-key IRQ name | package build | T1.5, T3.5 | T5 |
| 13 | Thermal: `power_allocator` | kernel build | T4.3 | T4 |

USB-PD at 9 V is deferred: at the driver's 2 A charge current, 5 V / 3 A
already covers the cell plus the system load [I: computed in the charging
review, not measured].

### 3.1 What the source review changed

All of this is source analysis on kernel `instantnoodlep-k3-daily2-qce-gmu` @
`bd566b604`. Nothing here was measured on the phone.

- [V] The RPMh sleep set is written only when the cluster power domain turns
  off (`drivers/soc/qcom/rpmh-rsc.c:943-952`). The cluster state needs every
  CPU idle for about 13 ms (`sm8250.dtsi:365-371`, entry plus exit latency
  and minimum residency). [I] With 8 cluster entries in 2.3 h, `Count: 0` on
  ddr, cxsd and aosd is expected whatever the votes look like. Cluster
  collapse is the precondition, and s2idle forces it. That is why s2idle is
  rank 1.
- [V] The eight CPU nodes vote for DDR bandwidth with interconnect tag 0
  (`sm8250.dtsi:111`), and tag 0 means "always", so the vote stays in the
  sleep set (`drivers/interconnect/qcom/icc-rpmh.c:92-93`). sc7180 uses the
  active-only tag on the same path (`sc7180.dtsi:92`). [I] This keeps DDR up
  even in s2idle. It is kernel candidate K2.
- [V] dwc3 forbids runtime PM at probe (`drivers/usb/dwc3/core.c:2383`), so
  the USB controller holds its power domain and bandwidth vote with or
  without a cable.
- [V] Wi-Fi power save is off (Part A in #867). [I] It is probably the
  largest single term in the awake floor.
- [V] `pcie0` has no `interconnects` property in `sm8250.dtsi`, and the bwmon
  votes are active-only. Neither holds DDR in sleep. Both were suspects
  before.
- [V] The charger caps a USB-C source without BC1.2 data lines at 500 mA: the
  Type-C current advertisement is defined in the driver but never read
  (`drivers/power/supply/qcom_pm8150b_charger.c:197-211, 514-517`). The laptop
  port's 500 mA minus the system load is the 150-190 mA seen at the battery
  [I: the load share is computed].
- [V] The charger's kernel policy does not depend on the userspace guard:
  temperature zones from the gauge, a hard stop at 4.46 V, safe limits on bad
  gauge data, and a PMIC watchdog that stops charging when the policy work
  stops (`qcom_pm8150b_charger.c:871-907, 1018-1023, 984-991, 1108-1113`).
- [V] No other mainline SM8250 port publishes cxsd or aosd counts or a
  suspended current, so the T2 goals stay proposals until measured here.

Steps 1-3 need no new kernel. The charging steps run in parallel with the
sleep steps in separate kernel branches and are merged into one daily
candidate only after each passed alone.

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
| 2026-11-19 | s2idle moves to rank 1 | the sleep set is applied only at cluster power-off, which s2idle forces (§3.1) |
| 2026-11-19 | First kernel candidate for sleep is the CPU DDR vote tag, not USB or bwmon | §3.1 |
| 2026-11-19 | Charging starts with a Type-C Rp-aware input limit in the local driver. The local driver is kept instead of porting the `qcom_smbx` smb5 patch | the smb5 patch writes Type-C mode at init and was held up in review for it [I: from the charging review's reading of the list thread] |
| 2026-11-19 | USB-PD at 9 V is deferred | no gain at a 2 A charge current (§3) |
| 2026-11-19 | K2 (CPU DDR vote active-only) is built as `instantnoodlep-k3-power-cpuicc` @ `68b21eb3a` and waits for its phone gate | [V] diff is the eight CPU EBI cells plus one include; DTB-only change. [I] effect on `ddr` counters. The same change is reported applied in the Qualcomm tree; take that commit if K2 passes |
| 2026-11-19 | K1 (Type-C Rp input limit, watchdog pet address, unbind state) is built as `instantnoodlep-k3-power-chg1` @ `8907ff5b8`; gate in `docs/runbooks/CHARGER-RP-RUNBOOK.md` | [V] three independent reviews, the third says safe for an owner-attended test. [I] whether the PMIC reports Rp without a Type-C driver (step G0) |
| 2026-11-19 | The 1 Hz Rp re-read is not used | it ran across suspend and rewrote the limit every second; AICL and the source's own protection cover a source that lowers Rp, and that case is a separate later experiment (L1) |
| 2026-11-19 | Runtime holder matrix and the #867 baseline are scripts with tests (`tools/instantnoodlep-holder-matrix`, `tools/instantnoodlep-power-baseline`) | repeatable on every candidate; [I] until run on the phone |
| 2026-11-19 | K1 and K3 carry a load-time input ceiling, module parameter `max_input_ua` (0 = none). K1 is now `e69b080df`, K3 (`instantnoodlep-k3-power-chg2`) is `8b6d86a4a`; the earlier builds are superseded | [V] with the parameter at 500000 no path writes more than 500 mA to the limit register; KUnit 29/29 and 60/60, also run by the reviewer. With 0 the behaviour is unchanged, so the metered reviews stand |
| 2026-11-19 | A charging session without an inline USB-C meter is not accepted. The 3 A and 1.5 A steps wait for a meter; a 500 mA session with the ceiling is the owner's own decision | four independent reviews ended fix-first: nothing outside the PMIC shows the real input current [V: runbook `CHARGER-RP`, "Session without a meter"] |
| 2026-11-19 | Step G0 is answered: the PMIC reports the source's Rp on the daily kernel with no Type-C driver bound | [V] measured on daily2: laptop USB-C port with a C-to-C cable reads 3.0 A Rp, laptop USB-A port with an A-to-C cable reads default Rp and SDP. Input about 5.0 V and 0.48 A at a 500 mA limit in both |
| 2026-11-19 | A legacy-cable guard for K1 is worth building: an A-to-C cable is visible in the Type-C legacy cable status | [V] the legacy bit is set with the A-to-C cable and clear with C-to-C; the non-compliant bit was clear on this cable. [I] bit 2 of that register is set in both cases, meaning unknown; no non-compliant cable was tried |
| 2026-11-19 | First #867 Part B number: the screen-off floor on daily2 with the cable out is a median of 296.5 mA (12 samples over about 3 minutes, min 294, max 355) | [V] measured with `tools/instantnoodlep-power-baseline --part b`, verdict "clean screen-off floor". This is the awake floor, not a suspended current: the phone has never suspended. [I] the RAM candidate `k3-daily2-qce-gmu` read about 220 mA earlier the same day by another method; the two are not comparable until the tool runs on both |
| 2026-11-19 | Warp charging is noted as a possible separate later track, outside this program's order | the owner asked; the phone charges with Warp 30T under Android. Any work starts from a protocol description built on measurements, with no decompiled code (AGENTS.md rule 5) |
