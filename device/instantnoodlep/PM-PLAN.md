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

### 3.1 Wake-source qualification switches

The device package has no upstream-compatible per-source profile syntax.
Linux exposes a per-device `power/wakeup` control when a driver supports
system wake; discover the actual device path after the corresponding gate.
Keep that switch disabled while testing unrelated sources. Automatic sleep
is a separate global switch in upstream Omarchy: the shell's one-time setup
enables the user toggle only when `/usr/share/omamobile/auto-sleep-default`
exists. This package does not install that marker before the complete wake
matrix passes. [V: upstream `omamobile-setup-user:331-341` and Linux
[device wakeup documentation](https://www.kernel.org/doc/html/latest/driver-api/pm/devices.html)]

| Source | Qualification gate | Per-source switch after pass | State |
| --- | --- | --- | --- |
| Power key | B2 | Discovered PON/input device `power/wakeup`, if exposed; test resume before leaving enabled. | Unqualified |
| RTC alarm | B3 | RTC device wake control, if exposed; schedule only after time sync. | Unqualified |
| USB attach | POWER-M5 Type-C gate then existing G4 | Discovered Type-C/PMIC device wake control; do not add charger policy. | Unqualified |
| Wi-Fi WoWLAN | Later Wi-Fi/PM-PLAN gate | Driver WoWLAN configuration plus PCIe/device `power/wakeup`, after AP test. | Unqualified |
| Modem ring/SMS | MODEM-M5 end-to-end call/SMS gate | Modem/PCIe wake route only after resume and service delivery pass. | Unqualified |

## 4. Measurement plan

### 4.1 Controlled baseline

Repeat the owner-reported ~180 mA screen-off/Wi-Fi baseline with stable
network, no active SSH transfer, screen at confirmed DPMS/backlight-off,
Wi-Fi associated, Bluetooth and modem state recorded, and no charging. Run
at least 15 minutes after a 5-minute settle, at a recorded battery and
ambient temperature. Use median and range, plus sample count. Change one
factor per follow-up: Wi-Fi off, BT off, modem absent/present, GNSS, audio,
screen, suspend. [I]

Find the gauge path without assuming its sysfs name:

```sh
for p in /sys/class/power_supply/*; do
  [ -r "$p/current_now" ] && printf '%s\n' "$p/current_now"
done
```

The checked-in timestamped sampler (read-only) is
[`tools/instantnoodlep-pm-sample`](../../tools/instantnoodlep-pm-sample). It
defaults to 15 minutes at 5-second intervals and writes a mode-0600 CSV under
`/tmp`; rows include `current_now` (µA), `voltage_now` (µV), `temp` (0.1°C),
and per-interval `wakeup_sources` and `/proc/interrupts` deltas. It prints no
phone serial, IMEI or MAC address. [V: implementation and package self-test.]

Equivalent minimal current-only loop (read-only):

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

### 4.2 Morning baseline and first suspend gate (owner-run; not executed)

Before the morning run, select the running gauge path with the read-only
discovery loop above, start an external log/recovery observer, and confirm the
known RAM-boot kernel and wall-clock time. No phone access was performed while
writing this plan.

| Step | Exact command / action | Expect | Stop condition | Rollback |
| --- | --- | --- | --- | --- |
| B1: screen-off baseline | Display off, Wi-Fi connected, no audio/GNSS/download/charging; run `tools/instantnoodlep-pm-sample --duration 900 --interval 5` (battery supply is discovered automatically). Keep it screen-off for 15 min after the 5-min settle; do not use an active SSH transfer during the sample. | CSV under `/tmp` with current, voltage, temperature and interval wake/IRQ deltas; observer reports median/range and conditions without copying identifiers. | Gauge or debugfs counters missing, battery heating/current anomaly, unexpected activity, wrong kernel, or only USB SSH is available as observer. | Stop with Ctrl-C; remove the private temporary CSV after recording redacted aggregates; no device state changed. |
| B2: power-key s2idle | After B1 is reviewed and owner separately approves, check `cat /sys/power/mem_sleep; cat /sys/power/state; systemd-inhibit --list`; then `systemctl suspend`. Owner waits 30 s and presses Power once, while external log/recovery observer remains ready. | s2idle entry and success count; power key resumes to usable lock screen; wake IRQ and no hang/oops. | No resume within 60 s, screen remains unrecoverable, kernel warning/oops, reboot, or unexplained wake loop. | Owner uses known recovery/hard reboot; stop and review logs before any repeat. |
| B3: RTC wake | Only after B2 passes and trusted wall-clock is confirmed, arm `rtcwake -m no -s 30`; run `systemctl suspend`. Owner/observer waits 90 s maximum. | RTC wakes close to 30 s, suspend success increments, alarm clears and resumed system is usable. | RTC/time invalid, no wake by 90 s, alarm fires repeatedly, or wake reason is inconsistent. | Power-key wake; clear the one-shot test alarm after resume; do not repeat until RTC/time issue is understood. |

### 4.3 Owner gates (no run performed)

All test blocks require the owner's explicit go for that individual step.
These tests change only volatile runtime state. Use a known RAM-boot image,
external logs and an owner-present recovery path. No fastboot flash/erase,
slot marking, charger probing, or modem NV access.

| Gate | Exact command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| G0: identify state | `adb shell 'uname -r; cat /sys/power/mem_sleep; cat /sys/power/state; cat /sys/power/wakeup_count; grep -H . /sys/class/power_supply/*/current_now'` | Correct daily/RAM image, s2idle present/selected, gauge responds with stable units. | Unexpected kernel, `deep` only, no gauge, or implausible current. | Read-only; stop and update plan/evidence. |
| G1: baseline | Run the sampler for 15 min, display off and Wi-Fi on; collect only aggregate values. | Reproducible distribution and conditions noted. | Gauge path changes/vanishes or heating/current anomaly. | Stop sampler. |
| G2: s2idle/power key | Same as B2 above. | `s2idle` entered, success increments, power key wakes panel/UI, no errors. | No wake by 60 s, hard hang, reboot or unexplained repeated wake. | Owner uses known hard-reboot method; do not retry before logs reviewed. |
| G3: RTC | Same as B3 above. | Resume occurs near 30 s and alarm is no longer armed. | No wake by 90 s, RTC reports invalid time, or wrong clock. | Power-key wake; clear test alarm after resume. Stop RTC testing until time issue fixed. |
| G4: USB attach wake | With owner present and known-safe 5 V source, unplug USB; `systemctl suspend`; reinsert cable after 30 s. | One wake on attach, stable thermal/current, no charger negotiation surprise. | No wake, heat/current abnormality, repeated attach wake or charge state unclear. | Unplug, wake by power key. Do not test higher PD voltage or charging. |
| G5: wake storm | Capture `wakeup_sources`, suspend for 10 min with only qualified wake sources enabled, then power-key wake. | No unexplained IRQ/count growth; observed drain lower than screen-off idle. | Repeated dark resumes, continuously increasing wake counts, drain no better than idle. | Disable auto-suspend for session; return to screen-off idle and review top source. |

When running suspend, USB SSH may disappear. It is not an acceptable sole
observer or recovery channel; use the local console/log stream arrangement
specified by the owner before G2-G5. [I]

### 4.4 Interconnect `sync_state` diagnostic (2026-11-19)

- **[V: owner phone report, k3-daily2, 2026-11-19]** PSCI idle states
  respond, but the `ddr_stats`, `cxsd`, and `aosd` files under
  `/sys/kernel/debug/qcom_stats/` each report `Count 0`. The log reports
  `qnoc-sm8250 163d000.interconnect: sync_state() pending due to
  1dfa000.crypto` and the same consumer on `1700000.interconnect`; `gcc-sm8250`
  and `sm8250-gpucc` report pending due to `3d6a000.gmu`. Screen-off current
  was reported around 360 mA. The capture is private and no identifiers are
  reproduced here.
- **[V: kernel source `arch/arm64/boot/dts/qcom/sm8250.dtsi:2609-2642`]** The
  crypto node has the SM8250/SM8150 QCE compatibles, RX/TX DMA requests on
  channels 4/5 from `cryptobam`, six IOMMU stream mappings and an
  `aggre2_noc` to `mc_virt` interconnect path. Those phandles map to the
  `1700000.interconnect` and `163d000.interconnect` providers respectively
  (`sm8250.dtsi:2105-2124`), matching both reported pending providers. The BAM
  node is declared at `:2609-2624`. **[V: `drivers/crypto/Kconfig:529-536`]**
  The QCE driver is hidden on ARCH_QCOM unless `COMPILE_TEST` or `BROKEN` is
  enabled. Its OF table matches the fallback `qcom,qce` compatible
  (`drivers/crypto/qce/core.c:332-336`); probe acquires the named memory
  interconnect path, requests `rx` and `tx` channels, then checks the hardware
  version (`core.c:198-260`). It requests both named DMA channels
  (`drivers/crypto/qce/dma.c:19-32`), derives the paired pipe ID from the RX
  channel (`drivers/crypto/qce/core.c:151-180`), and rejects QCE v5.0 only
  (`core.c:151-167`). The source and DT declarations line up for SM8250;
  successful BAM/IOMMU probe on this phone remains **[I]**.
  Kconfig also says this driver does not have exclusive access to the engine
  (secure-world races are possible) and is slower than the CPU
  (`drivers/crypto/Kconfig:537-540`), so this is a diagnostic RAM-only enable,
  not a production setting. The BAM DMA driver is enabled by the daily2 base
  config; probe and bind on the handset remain **[I]** until the candidate is
  RAM-booted.
- **[V: `drivers/interconnect/core.c:1218-1246`, `drivers/base/core.c:1382-1400,1848-1878`]** `icc_sync_state()` waits until every provider's sync callback
  has run before clearing initial votes. Under strict fw_devlink sync-state,
  a supplier can remain pending while a managed consumer link is not active.
  Enabling QCE as a module is intended to make its device bind and release the
  crypto-consumer links; whether QCE probes successfully with this phone's BAM
  and IOMMU configuration is **[I]**.
- **[V: `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts:561-575`,
  `arch/arm64/boot/dts/qcom/sm8250.dtsi:3012-3047`,
  `drivers/gpu/drm/msm/adreno/a6xx_gmu.c:2282-2310`]** The board enables both
  the GMU and GPU. The GMU consumer node requests GPUCC and GCC clocks,
  GPUCC CX/GX power domains and the Adreno SMMU (`sm8250.dtsi:3012-3040`),
  matching the reported `gcc-sm8250` and `sm8250-gpucc` suppliers. Adreno's
  GPU probe initializes the GMU through its
  platform-device node, but the GMU helper is called from the GPU driver and
  does not bind a driver to the separate GMU device
  (`drivers/gpu/drm/msm/adreno/a6xx_gmu.c:2282-2310`). Since fw_devlink marks a
  consumer's supplier links active from `device_links_driver_bound()` for that
  consumer (`drivers/base/core.c:1382-1400`), the GPU driver's bind alone is
  not expected to satisfy the GMU device's consumer link. The reported pending
  GMU line after userspace GL works is consistent with this; actual sync-state
  behavior stays **[I]** until measured on the device. Do not disable the GMU
  or alter GPU DTS for this one-variable crypto candidate.

#### Candidate and phone gate

**[V: source `inumineq/linux-omarchy-mobile` daily2 commit
`c5e256242`]** Candidate `k3-daily2-qce` was built on the daily2 DTS with QCE
as a module. This kernel hides `CRYPTO_DEV_QCE` behind `COMPILE_TEST` on
ARCH_QCOM, so `CONFIG_COMPILE_TEST=y` is required; `CRYPTO_DEV_QCE=m`, the
default all-algorithm choice, and `LOCALVERSION=-instantnoodlep-k3-daily2-qce`
are set. The config diff also retains Kconfig-selected `GENERIC_IRQ_CHIP=y`,
`GPIO_EP93XX=y`, `PIC32_EVIC=y`, `VIRTIO_PCI_ADMIN_LEGACY=y` and changes
`GPIO_GENERIC` from module to built-in; most compile-test-only options were
explicitly returned to `n` after `olddefconfig`. Build used clang/LLD 23.1.3
with `LOCALVERSION=` in the build environment to keep Kbuild from appending
`+` to the release. **[I]** `qcrypto.ko` still must load and bind against the
phone's BAM/IOMMU before this can qualify as a sync-state fix.

**[V] Build report:** release
`7.3.0-rc6-instantnoodlep-k3-daily2-qce`, raw Image `image_size=0x1750000`
(below the `0x2b60000` ABL ceiling), and `qcrypto.ko` contains OF aliases for
`qcom,qce`, `qcom,crypto-v5.1`, and `qcom,crypto-v5.4`. Artifacts are in
`~/android/build/k3-daily2-qce/`; `SHA256SUMS` verifies the listed files.

| Artifact | SHA-256 |
| --- | --- |
| `Image.gz` | `96390bff0ca88084c9943b7c9de9a569e4d41ce112860f5c0544e3e39512fa53` |
| `sm8250-oneplus-instantnoodlep.dtb` | `4a58be32100b1baeceb84949b8a58258adbcc473f9e5ba180b2d27408e7984a7` |
| `modules-7.3.0-rc6-instantnoodlep-k3-daily2-qce.tar.zst` | `60fa1ffdef55ee4f9d228c27f0a504c07e5ee60a805fcdda40860d7e19856037` |
| `kernel.release` | `f21dc18a920c9af8db0b994d52e5d2852581c4829ba805e8523de55ff1c72fa7` |
| `image_size.txt` | `a2a5bad47454646aaba23fc62a94e5145ecaf59449ff61235d1d7c0cbe42969b` |
| `kernel.config` | `27db735bc013d50c57f8ba83a0ea0130562afe67361d71ceddf46894c5c24d03` |
| `SHA256SUMS` | `c60a0dffb1b9a08dcf953ad9f8e7c98f46b396a01d49f895fd6765856393d70f` |

No boot image was packed: this host has no prepared initramfs root, stock
entry-16 overlay, AOSP `mkbootimg.py` or `ufdt_apply_overlay`, which the repo
packer requires. **[I]** A boot image may be packed on the owner host from
these exact kernel/DTB artifacts and the established daily2 runbook inputs.

Owner/coordinator only; no phone access or boot has been done by this worker.
This host has no private packer inputs, so no `boot-daily2-qce.img` exists
yet. On the coordinator's host, use the established daily2 inputs to pack it
from the repository root:

```sh
tools/build-instantnoodlep-probe \
  --kernel ~/android/build/k3-daily2-qce/Image.gz \
  --dtb ~/android/build/k3-daily2-qce/sm8250-oneplus-instantnoodlep.dtb \
  --ssh-key ~/.ssh/omamobile_probe.pub \
  --mkbootimg ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py \
  --omarchy-mobile ~/src/omarchy-mobile \
  --initramfs-root ~/android/build/initramfs-root \
  --stock-overlay ~/android/build/p3/entry16.dtbo \
  --ufdt-apply ~/android/build/ufdt/ufdt_apply_overlay \
  --boot 2 --root userdata --debug-shell \
  --out ~/android/build/k3-daily2-qce/boot-daily2-qce.img
```

Use the existing DAILY-K3-PLAN §8 Part R prep and rollback. First verify all
artifact hashes and stage the matching modules archive under
`/usr/lib/modules/<release>/` (do not replace or unpin the installed daily
module tree). With the owner ready and a recovery path available, RAM-boot
only the packed image:

```sh
fastboot boot ~/android/build/k3-daily2-qce/boot-daily2-qce.img
```

**[I]** Expect a successful boot, SSH and `uname -r` equal to
the recorded candidate release. Confirm
`qcrypto` loaded automatically; if it did not, run `sudo modprobe qcrypto`
once. Confirm `/sys/bus/platform/devices/1dfa000.crypto/driver` resolves to
the QCE driver, then capture
`dmesg | grep -E 'sync_state\(\) pending'` and read the following files twice,
60 seconds apart, with screen off and otherwise idle:

```sh
cat /sys/kernel/debug/qcom_stats/ddr_stats
cat /sys/kernel/debug/qcom_stats/cxsd
cat /sys/kernel/debug/qcom_stats/aosd
sleep 60
cat /sys/kernel/debug/qcom_stats/ddr_stats
cat /sys/kernel/debug/qcom_stats/cxsd
cat /sys/kernel/debug/qcom_stats/aosd
```

**[I]** Expect the crypto device driver symlink to resolve; report any GMU pending
line separately. A pending log line is historical, so record whether it was
emitted before or after QCE bound. Compare counter counts and elapsed-time
values between reads; the acceptance condition is that relevant counters
advance, not that any specific count is promised. If QCE reports
probe/defer/DMA/IOMMU errors, fails to bind, boot or SSH is unhealthy, or
counters remain zero, stop and return to the installed daily kernel; do not
try a DTS disable in this same candidate. **[I]** A second, separately built
candidate may set
only `&crypto { status = "disabled"; };` if QCE cannot bind; this would test
fw_devlink's absent-consumer path and would not provide crypto acceleration.

After the 60-second counter interval, collect the separate Part B floor from
[upstream issue #867](https://github.com/derekross/omarchy-mobile/issues/867).
Owner cable out, Wi-Fi SSH, screen off, nothing else running. Run this inside
`tmux` or under `nohup` so an SSH drop cannot terminate it:

```sh
for d in /sys/class/power_supply/*; do
  [ "$(cat "$d/type")" = Battery ] && B=$d
done
echo "gauge: $B"
sleep 600
for i in $(seq 12); do
  echo "$(date +%T) $(cat "$B/status") $(cat "$B/current_now") uA batt=$(cat "$B/temp") zones: $(cat /sys/class/thermal/thermal_zone*/temp | tr '\n' ' ')"
  sleep 15
done | tee floor.txt
```

**[V: upstream issue #867, Part B]** Median `current_now` is the reported
floor and the status column should say `Discharging`.
Record kernel, module/config, Wi-Fi power-save, room temp if known and gauge
calibration state. Values are µA; battery temperature is tenths °C and zone
temperatures are thousandths °C. Stop if SSH drops before the log is safely
running, battery status is not `Discharging`, readings are missing or
implausible, or temperature or current becomes anomalous. Keep the output
private and report only redacted aggregates.

### 4.5 GMU fw_devlink sync_state: analysis, fix and phone gate (2026-11-19)

Related: §4.4 on `inumineq/qce-sleep` (PR #136) covers the QCE half of the
same pending lines. This section covers the GMU half and its driver-side fix.

- **[V: owner phone report, RAM kernel k3-daily2-qce = daily2 +
  `CONFIG_CRYPTO_DEV_QCE=m`, 2026-11-19; PR #136 / PM-PLAN §4.4 there]**
  After QCE bound (no more `sync_state() pending due to 1dfa000.crypto`,
  `qcrypto` bound), the log still reports
  `gcc-sm8250 100000.clock-controller: sync_state() pending due to 3d6a000.gmu`
  and the same for `sm8250-gpucc 3d90000.clock-controller`. GPU works
  (msm_dpu, `a650_gmu.bin` loaded, Hyprland on GPU).
  `/sys/kernel/debug/qcom_stats` `ddr_stats`/`cxsd`/`aosd` stay `Count 0` with
  screen off and cable out; battery-only draw median ~229 mA over 7 min.
  Booting with `fw_devlink.sync_state=timeout` reached the lock screen but the
  USB gadget never attached (no host attach for 15 min) — that parameter is
  ruled out. The cmdline still carries `clk_ignore_unused pd_ignore_unused`.

**Why `3d6a000.gmu` never counts as bound** [V, kernel
`inumineq/linux-omarchy-mobile` `instantnoodlep-k3-daily2-qce-gmu` source,
7.3.0-rc6 base]:

1. `gmu@3d6a000` is a direct child of `soc@0` (`simple-bus`),
   `arch/arm64/boot/dts/qcom/sm8250.dtsi:3012-3047`, so a platform device is
   created for it at boot: `of_platform_default_populate_init()` →
   `of_platform_populate()` recurses through simple-bus children and calls
   `of_platform_bus_create()` per child with a `compatible`
   (`drivers/of/platform.c:443-470` (`of_platform_populate`), `:325-382` (`of_platform_bus_create`)).
2. Its `clocks` (`&gpucc`, `&gcc`), `power-domains` (`&gpucc` GDSCs) and
   `iommus` (`&adreno_smmu`) phandles create **managed** fw_devlink consumer
   links to those suppliers (`drivers/of/property.c:1394-1401,1541-1551`
   `of_supplier_bindings`, `of_link_to_phandle()` `:1258-1275`; the
   `DL_FLAG_MANAGED` flag is set in `device_link_add()`,
   `drivers/base/core.c:826-827`).
3. **No driver ever binds to the GMU device.** The only in-tree uses of the
   `qcom,adreno-gmu` compatible are SMMU ACTLR/client quirk tables
   (`drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c:38,408`), not probe ID
   tables. The Adreno driver binds to the parent `gpu@3d00000` and merely
   *uses* the GMU device: `of_parse_phandle(pdev->dev.of_node, "qcom,gmu", 0)`
   (`a6xx_gpu.c:2711`), `of_find_device_by_node(node)` +
   `gmu->dev = &pdev->dev` (`a6xx_gmu.c:2285,2297`). The `qcom,gmu` phandle is
   not in `of_supplier_bindings`, so it creates no link either. The GMU
   device still needs its `clocks` etc. at runtime
   (`a6xx_gmu_clocks_probe()`: `devm_clk_bulk_get_all(gmu->dev, ...)`), so the
   DT phandles cannot be stripped.
4. `device_links_driver_bound()` — the only path that sets a consumer's
   supplier links to `DL_STATE_ACTIVE` (`drivers/base/core.c:1428-1455`) —
   runs only after a successful driver probe (`driver_bound(dev)` at
   `drivers/base/dd.c:756`). The GMU device never probes, so its links stay
   `DL_STATE_AVAILABLE` (supplier side, `core.c:1408-1416`), never ACTIVE.
5. `__device_links_queue_sync_state()` queues a supplier's `sync_state()`
   only when **all** its managed consumer links are ACTIVE
   (`drivers/base/core.c:1208-1214`). The never-ACTIVE GMU link therefore
   blocks `gcc-sm8250` and `sm8250-gpucc` forever.
6. This kernel has `# CONFIG_FW_DEVLINK_SYNC_STATE_TIMEOUT is not set`
   (`~/android/build/k3-daily2-qce/kernel.config:1892`), so
   `fw_devlink_sync_state == FW_DEVLINK_SYNC_STATE_STRICT`
   (`drivers/base/core.c:1753-1759`). At
   `fw_devlink_probing_done()` (`drivers/base/dd.c:305-318,349-367`;
   `fw_devlink_probing_done()` itself at `drivers/base/core.c:1875`) strict
   mode just prints `sync_state() pending due to 3d6a000.gmu`
   (`core.c:1858-1860`) and leaves the suppliers unsynced.
7. Those suppliers do have sync_state callbacks: the qnoc interconnect
   providers declare `.sync_state = icc_sync_state`
   (`drivers/interconnect/qcom/sm8250.c:1983`; `icc_sync_state()` at
   `drivers/interconnect/core.c:1218-1246` drops the initial votes only when
   called), and the clock controllers get `genpd_sync_state` installed on
   their driver at runtime by the genpd core via `dev_set_drv_sync_state()`
   (`drivers/pmdomain/core.c:2696-2701`, `include/linux/device.h:1130-1141`).
   Since the callbacks never run, the initial interconnect/PM votes are never
   dropped — consistent with the `qcom_stats` counters stuck at `Count 0`.

**How mainline handles it on other SM8250/SM8x50 boards** [V]: every in-tree
SM8x50 dtsi (`sm8150.dtsi`, `sm8250.dtsi`, `sm8350.dtsi`, `sm8450.dtsi`,
`sm8550.dtsi`, …) declares the same `gmu` node as a child of `soc@0` with a
`qcom,adreno-gmu*`/`qcom,adreno-gmu-wrapper`/`qcom,adreno-rgmu` compatible,
and no in-tree driver binds those compatibles (grep over `drivers/` finds
only the SMMU quirk tables above). So mainline boards with `&gmu` enabled hit
the same strict-mode pending lines; the only upstream escape hatch is
`fw_devlink.sync_state=timeout` / `CONFIG_FW_DEVLINK_SYNC_STATE_TIMEOUT`,
which force-calls `sync_state()` after the deferred-probe timeout
(`drivers/base/core.c:1862-1876`, "Timed out. Forcing sync_state()") — ruled
out on this phone because the USB gadget never attached with it. There is no
driver-side mainline fix; the patch below is a local one.

**The fix** [V]: `device/instantnoodlep/patches/pm/0001-drm-msm-adreno-bind-the-GMU-device-so-fw_devlink-sy.patch`
(kernel commit `bd566b604`, branch `instantnoodlep-k3-daily2-qce-gmu` on top
of `instantnoodlep-k3-daily2-qce` `c5e256242`) registers a minimal no-op
`platform_driver` matching `qcom,adreno-gmu`, `qcom,adreno-gmu-wrapper` and
`qcom,adreno-rgmu`. When it binds, `device_links_driver_bound(gmu)` marks the
GMU's supplier links ACTIVE, so `gcc-sm8250`/`sm8250-gpucc`/qnoc get their
`sync_state()` and drop initial votes. All real GMU handling stays in
`a6xx_gmu.c`, driven by the Adreno GPU driver; the new probe is a no-op.
Boards with `&gmu` disabled get no GMU device (`of_device_is_available()`
gate in `of_platform_device_create_pdata()`, `drivers/of/platform.c:161`),
so they are unaffected. [I] On-device effect pending the gate below.

**Candidate and build recipe** [V: built on omaserver, clang/LLD 23.1.3]:

- Source: `~/src/l-k3-daily2-qce`, branch `instantnoodlep-k3-daily2-qce-gmu`
  @ `bd566b604` (single commit on `c5e256242`).
- Config: copy of `~/android/build/k3-daily2-qce/kernel.config` (daily2 +
  `CONFIG_COMPILE_TEST=y`, `CONFIG_CRYPTO_DEV_QCE=m`) with only
  `CONFIG_LOCALVERSION="-instantnoodlep-k3-daily2-qce-gmu"` and
  `# CONFIG_LOCALVERSION_AUTO is not set`:
  `./scripts/config --set-str LOCALVERSION "-instantnoodlep-k3-daily2-qce-gmu" --disable LOCALVERSION_AUTO`,
  then `make O=... ARCH=arm64 LLVM=1 olddefconfig`.
- Build (PATH must include the cached `bc`: `~/android/build/tool-cache/bc-root/bin`;
  keep `TMPDIR` off `/tmp`):

  ```sh
  export PATH=$HOME/android/build/tool-cache/bc-root/bin:$PATH TMPDIR=$HOME/android/build/tmp
  make -C ~/src/l-k3-daily2-qce O=~/android/build/k3-daily2-qce-gmu \
    ARCH=arm64 LLVM=1 -j12 Image.gz dtbs modules
  ```

- Release `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu`; artifacts in
  `~/android/build/k3-daily2-qce-gmu/` (`Image.gz`,
  `sm8250-oneplus-instantnoodlep.dtb`, `arch/arm64/boot/Image` for
  `image_size`, `modules-<release>.tar.zst`, `kernel.release`,
  `kernel.config`, `SHA256SUMS`, `build.log`). `image_size` must stay under
  the ABL ceiling `0x2b60000`.
- **[V: build report, omaserver, clang/LLD 23.1.3, `LLVM=1`,
  `MAKE_EXIT=0`]** Release `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu`
  (`LOCALVERSION=` passed to suppress the `+` suffix;
  `qcrypto.ko` vermagic matches the release), raw Image
  `image_size=0x16ac200` (below the `0x2b60000` ABL ceiling), DTB byte-identical
  to the k3-daily2-qce DTB (same DTS), 802 modules, and `a6xx_gmu.o` carries
  `adreno_gmu_device_driver` with the `qcom,adreno-gmu`/`-wrapper`/`-rgmu`
  match table (`nm`/`strings` on the build output). `dtbs_check` evidence
  carries over from k3-daily2-qce because the DTB hash is unchanged.

  | Artifact (`~/android/build/k3-daily2-qce-gmu/`) | SHA-256 |
  | --- | --- |
  | `Image.gz` | `d4328b4e5c111cd8a3974d7909e9f1c128edfccf661494f6b67530ae26deccc8` |
  | `sm8250-oneplus-instantnoodlep.dtb` | `4a58be32100b1baeceb84949b8a58258adbcc473f9e5ba180b2d27408e7984a7` |
  | `modules-7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu.tar.zst` | `ca7146e3a95c6398f1e78cd423cb28d3ebeec3bf65e0fe55f868417e1e848cec` |
  | `kernel.release` | `4ae3c64609494c8dfa74c0e4633d8da7cf375f4ff1439a60839f44dcc2962be2` |
  | `image_size.txt` | `1f943197f8d9c26a712b40fabb585794cd1311ccc05750d902eaee6356775bec` |
  | `kernel.config` | `90f3ae118a52f16aaa1301fd849609cfbedd3efa63c5602306d90cbe5e3634eb` |
  | `SHA256SUMS` | `72de28f977c78ff3ac51106a556187b1b47a18be8ccd9d3b44e2552296b91526` |
- No boot image is packed on this host (no private packer inputs, as in
  §4.4/PR #136); pack on the coordinator host with the established daily2
  runbook inputs (`tools/build-instantnoodlep-probe`, DAILY-K3-PLAN §8 Part
  R prep and rollback), then `fastboot boot` the packed image (RAM only).

**Phone gate (owner/coordinator only; no phone access by this worker)** —
RAM-boot the packed `boot-daily2-qce-gmu.img`, stage the matching modules
archive under `/usr/lib/modules/<release>/` without touching the pinned daily
module tree, then verify:

| Check | Exact command | Expect | Stop condition |
| --- | --- | --- | --- |
| G-gmu-1 kernel | `uname -r` | `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu` | wrong release → stop, boot the daily image back |
| G-gmu-2 GPU still up | `dmesg \| grep -E 'msm_dpu|adreno|a650_gmu'`, Hyprland renders | GPU probed, GMU firmware loaded, UI on GPU | GPU broken/hang → stop, rollback |
| G-gmu-3 GMU bound | `readlink /sys/bus/platform/devices/3d6a000.gmu/driver` | `.../drivers/adreno-gmu` (or `platform:adreno-gmu`) | no driver → stop, rollback |
| G-gmu-4 no GMU pending | `dmesg \| grep 'sync_state() pending'` (also after `echo 1 > /sys/power/state`-less idle; re-check after 10 min uptime) | **no** `3d6a000.gmu` line; QCE line also gone; record any other pending line | any `3d6a000.gmu` pending after boot → stop, rollback |
| G-gmu-5 USB gadget | host side: watch for new USB device for 5 min after boot; on phone `ls /sys/class/udc` | gadget attaches (contrast: ruled-out `sync_state=timeout` boot never attached in 15 min) | no attach in 5 min → stop, rollback |
| G-gmu-6 counters | screen off, cable out: read `/sys/kernel/debug/qcom_stats/{ddr_stats,cxsd,aosd}` twice 60 s apart | counters **advance** between reads (acceptance = advancing, not a promised count) | counters stay `Count 0` → stop, rollback |
| G-gmu-7 floor | Part B floor loop from §4.4/upstream issue #867 (owner, cable out, screen off, 10 min) | median battery-only draw; compare with the ~229 mA / 7 min k3-daily2-qce report | anomalous heat/current, SSH loss → stop |

Rollback for every stop: `fastboot boot` the installed daily / k3-daily2-qce
image (or reboot to `boot_b`), do not flash anything. Do not combine this
candidate with a DTS disable of `&gmu` or with `fw_devlink.sync_state=timeout`;
one variable per RAM boot.

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
