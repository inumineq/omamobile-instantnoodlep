<!-- SPDX-License-Identifier: MIT -->
# SM8250 screen-off idle: source audit and first diagnostic candidate

Date: 2026-11-18. This is an offline source/configuration audit and a proposed
owner-run RAM boot. No phone command was run by this worker.

## Evidence boundary

- **[V]** The task's 15-minute screen-off sample reports 360 mA median with
  USB unplugged and Wi-Fi associated, collected by
  `tools/instantnoodlep-pm-sample`. The captured CSV is private and is not
  included here.
- **[V]** The existing `PM-PLAN.md:21-23` separately records an older,
  unconditioned owner report of about 180 mA. These are different observations;
  do not combine them as one baseline.
- **[I]** CPU/cluster collapse failure, a persistent RPMh/interconnect vote,
  GPU runtime activity, and Wi-Fi power-save state are hypotheses. The current
  source alone cannot identify which, if any, explains the measured draw.
- **[V]** All source/config observations below are checked against the
  `instantnoodlep-k3-slim-all` kernel branch at base commit `c30e3f696` and
  `~/android/configs/slim-all.config` (SHA256 begins
  `8a7b72e0de22f85d`). Line references name the checked-out Linux tree;
  `.config` line numbers are from that exact base config.

## Audit and ranking

| Rank | Area | Checked evidence | Assessment / next check |
| --- | --- | --- | --- |
| 1 | CPU and cluster idle | **[V]** `CONFIG_PM=y`, `CONFIG_PM_SLEEP{,_SMP}=y`, PM debug/sleep debug, generic PM domains, `CONFIG_CPU_IDLE=y`, `CONFIG_NO_HZ_IDLE=y`, `CONFIG_ARM_PSCI_CPUIDLE=y`, and `CONFIG_ARM_PSCI_CPUIDLE_DOMAIN=y` (`~/android/configs/slim-all.config:91,605-620,635-647`). The shared SM8250 DTS has PSCI CPU rail-collapse states for silver and gold cores plus a hierarchical cluster state, with entry/exit/min-residency data (`arch/arm64/boot/dts/qcom/sm8250.dtsi:340-371`). Each CPU references its PSCI power domain and the cluster domain (`:98-109,699-750`). **[V]** The PSCI domain driver uses OSI when firmware advertises OS-initiated suspend support, otherwise PC mode, and logs the selected mode (`drivers/firmware/psci/psci.c:89-92,161-173`; `drivers/cpuidle/cpuidle-psci-domain.c:130-169`). | **[V]** The required OS-side cpuidle machinery and deep states are described, and the kernel selects OSI/PC based on PSCI firmware capability. **[I]** Whether deep states are actually entered still requires device counters and boot-log review. Do not rewrite suspend-state IDs or latencies without firmware evidence. |
| 2 | RPMh / sleep statistics | **[V]** `qcom,rpmh-rsc` has three drivers, active/sleep/wake/control TCS counts, and a power-domain link to the CPU cluster (`sm8250.dtsi:6208-6222`). The DTS also declares the `qcom,rpmh-stats` shared-memory block (`:5115-5118`). `CONFIG_QCOM_RPMH=y`, `CONFIG_QCOM_RPMHPD=y`, and `CONFIG_QCOM_STATS=m` in the baseline (`slim-all.config:6724,6732,6779`). The QCOM sleep-stats driver exports remote-subsystem and SoC counters in debugfs (`drivers/soc/qcom/qcom_stats.c:42-57,337-345`). | Promote only `QCOM_STATS` to built-in for PM1 so its counters do not depend on module staging/loading. **[I]** Whether this firmware populates useful APSS/RPMh records is device-gated. |
| 3 | Interconnect | **[V]** The baseline enables the generic Qualcomm interconnect framework and SM8250 provider (`slim-all.config:7710-7712,7748`; `sm8250.dtsi:375-379,2091-2138,6281-6294`). The provider nodes use the apps BCM voter. The SM8250 provider registers `.sync_state = icc_sync_state` (`drivers/interconnect/qcom/sm8250.c:1977-1984`), and the core exposes the read-only `interconnect_summary` debugfs file (`drivers/interconnect/core.c:1262-1265`). | **[V]** No sync-state omission is identified in this tree. Read `/sys/kernel/debug/interconnect/interconnect_summary` before and after the interval if present; do not zero or alter votes as a diagnostic. |
| 4 | Adreno / display runtime PM | **[V]** The device DTS enables `&gmu` and `&gpu` (`sm8250-oneplus-instantnoodlep.dts:561-575`); the GPU/GMU nodes describe CX/GX power domains (`sm8250.dtsi:2940-2963,3012-3040`). `CONFIG_DRM_MSM=y`, `CONFIG_PM_DEVFREQ=y`, and `CONFIG_PM_OPP=y` (`slim-all.config:4552,6784,7705`). The Adreno driver enables runtime PM, uses autosuspend and defines runtime-suspend/resume operations (`drivers/gpu/drm/msm/adreno/adreno_device.c:106-123,316-405`). | Read runtime-PM state/time and devfreq with the report script after display-off. **[I]** A blank panel may or may not leave an outstanding GPU/display reference; source declarations do not prove runtime suspension. |
| 5 | Wi-Fi power save / wakeups | **[V]** `CONFIG_ATH11K=m` and both PCI/AHB variants are modules (`slim-all.config:2414-2416`); the existing device report identifies Wi-Fi as associated during sampling. ath11k sends a firmware power-save mode through mac80211 (`drivers/net/wireless/ath/ath11k/mac.c:1275,7273`; `wmi.c:1373-1392`). The PCI PM callbacks cover system suspend (`ath11k/pci.c:1228-1292`), distinct from an awake screen-off interval. | **[I]** Record `iw dev wlp1s0 get power_save`, wakeup-source deltas and interrupt deltas. An associated interface does not prove firmware power-save is active. Do not infer system suspend from display-off; PM1's sleep interval deliberately does not request suspend. |
| 6 | CPU frequency / general PM | **[V]** `CONFIG_CPU_FREQ=y`, schedutil is the default frequency governor, and generic PM/sleep support is enabled (`slim-all.config:605-611,654,663`). | Frequency scaling is not a substitute for cpuidle. Leave the CPUFreq policy unchanged in PM1 to keep the A/B variable narrow. |

### Mainline board comparison

- **[V]** The RB5 board DTS includes `sm8250.dtsi`
  (`arch/arm64/boot/dts/qcom/qrb5165-rb5.dts:13`); Xiaomi elish and pipa
  board DTS files also include that same SoC description
  (`sm8250-xiaomi-elish-common.dtsi:11`,
  `sm8250-xiaomi-pipa.dts:11`). A tree search found no board-level
  `idle-states` override in those files; the CPU/domain states therefore come
  from the shared SM8250 description checked above.
- **[V]** This pinned kernel tree has no `sm8250-oneplus-kebab.dts`, so a
  mainline kebab board comparison cannot be made from this source checkout.
- **[I]** Published reports of lower idle draw on another SM8250 handset would
  not prove the same firmware, panel, wireless policy, or peripheral state on
  this IN2023. The most useful first comparison is the phone's own cpuidle,
  RPMh, interconnect, runtime-PM, wakeup and current deltas under matched
  conditions.

## Candidate `instantnoodlep-k3-pm1`

- **[V]** Source branch: `instantnoodlep-k3-pm1` at
  `e13b631da615`, based on `instantnoodlep-k3-slim-all`; PM config fragment:
  `arch/arm64/configs/instantnoodlep-k3-pm1.config` in the kernel repository.
- **[V]** Minimal config delta: enable `CONFIG_CPU_IDLE_GOV_TEO=y`, disable
  `CONFIG_CPU_IDLE_GOV_MENU`, and change `CONFIG_QCOM_STATS` from module to
  built-in. The TEO-only candidate makes the governor choice explicit while
  the built-in stats driver exposes available Qualcomm sleep counters. TEO is
  described as a tickless idle governor in `drivers/cpuidle/Kconfig:27-34`;
  the report records `/sys/devices/system/cpu/cpuidle/current_governor` so the
  owner can confirm what actually selected.
- **[V]** CPU idle, PSCI, CPUFreq, RPMh, interconnect and device DTS
  descriptions are unchanged. The source audit found no justified DTS repair;
  making speculative changes to PSCI state parameters or power-domain links
  would confound the diagnostic.
- **[I]** TEO may improve state selection for the phone's screen-off idle
  pattern, but no lower current is claimed before measurement. PM1 is a
  diagnostic candidate, not a production power fix.
- **[V] Build report:** clang/LLD `23.1.3`; release
  `7.3.0-rc6-instantnoodlep-k3-pm1-ge13b631da615`; source commit
  `e13b631da615`; raw Image header is `0x1780000`, below `0x2b60000`.
  Artifacts are in `~/android/build/k3-pm1/`: `Image.gz` SHA256
  `22a58a6817387b44b1feef66ba6203adebbfcfc88598097afe0a653680fcffe9`, DTB
  SHA256 `daffe04b12104c0ebb90cae837735ec1e0f35ced5c51ee9ed2a05eafbe2c7f7f`,
  modules archive SHA256
  `8cc8ab6fb695ca1debf07db96411d7a67e4e96065aa9514ee885ff18e4c2d048`.
  `SHA256SUMS` SHA256 is
  `d3ef3ce3401e3161438b1dd503e049d190b817c8de9445429869886f4bc9e249` and
  verifies all deliverables in that directory. Header command:
  `od -An -tx8 -j16 -N8 ~/android/build/k3-pm1-kbuild/arch/arm64/boot/Image`.

## Read-only counter report

`tools/instantnoodlep-idle-report` snapshots these counters before and after a
timed `sleep`: per-CPU cpuidle state `name`, `usage`, `time`, `residency`,
`disable`, current driver/governor, generic genpd summary, Qualcomm
`/sys/kernel/debug/qcom_stats/*`, interconnect summary, matching GPU/Wi-Fi/PCIe
runtime-PM attributes, GPU devfreq, CPUFreq policy/governor/frequency and
`time_in_state` when exposed, wakeup sources and `/proc/interrupts`.
The script only reads these paths and does not change governor, runtime PM,
brightness, or suspend state. Missing optional debugfs/sysfs counters are
reported as unavailable.

**Interpretation:** growing usage/time in the `silver-rail-power-collapse`,
`gold-rail-power-collapse` and cluster states is software evidence that the
kernel requested those states; it is not direct proof of physical rail
collapse. QCOM sleep stats and generic genpd/interconnect summaries are
independent corroboration when exposed. Compare all counter deltas alongside
the battery-current CSV; never treat software counters as a substitute for
gauge current or an external power measurement.

## Proposed owner/coordinator test (RAM boot only)

1. **[V] Baseline:** keep the known-good slot-B daily kernel untouched. Record
   `uname -r`, `/proc/cmdline`, `dmesg | grep 'Initialized CPU PM domain topology'`,
   cpuidle current driver/governor, Wi-Fi
   power-save (`iw dev wlp1s0 get power_save`), and current idle-state usage
   and time. Confirm the screen is off, USB is unplugged, Wi-Fi is associated,
   and the phone is not being charged.
2. Run the existing 900-second `tools/instantnoodlep-pm-sample` and
   `tools/instantnoodlep-idle-report --duration 900` under those conditions.
   Keep both output files private under `/tmp`; do not upload or commit raw
   device data.
3. Verify PM1's hashes, release, matching modules, and
   `image_size <= 0x2b60000`; stage only its unique module directory. After
   written owner approval and the coordinator's slot/ABL checks, run exactly
   `fastboot boot "$PM1_BOOT_IMG"` with the coordinator's real image path.
   This is RAM boot only: no `flash`, `erase`, `set_active`, or slot change.
4. Repeat the same 900-second sample/report interval, then return to the
   known-good slot-B daily kernel by normal reboot. Stop on ABL refusal,
   boot/root/USB failure, a kernel warning, unexpected slot state, missing
   cpuidle states, or a large temperature/thermal change. After an ABL
   refusal, cold-reboot to the bootloader before any further RAM boot.
5. Compare matched baseline and PM1 current medians, cpuidle usage/time
   deltas, wakeup/IRQ activity, GPU runtime-PM state, Wi-Fi power-save and
   RPMh/interconnect counters. **[I]** A lower median with increased deep
   state residency would support (not prove) a CPU-idle governor contribution;
   persistent current with little deep-state residency directs the next
   investigation to wakeups, Wi-Fi, GPU/display, RPMh votes or other devices.

No kernel was flashed, no phone step was run, and no claim of reduced power
draw is made by this report.
