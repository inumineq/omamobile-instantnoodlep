<!-- SPDX-License-Identifier: MIT -->
# MISC-HW-PLAN: remaining handset hardware on instantnoodlep

Status: phase 1 offline implementation in progress; no phone test performed.
Kernel branch `instantnoodlep-k3-misc`, worktree `~/src/l-k3-misc`, build
`~/android/build/k3-misc`, based on combo `aa996bae0` (test-only Kona
workaround retained by explicit coordinator instruction). This inventory covers haptics, under-display fingerprint,
NFC, torch, optical/proximity and IR/ToF sensors, alert slider, notification
LED, SIM-tray detection and wired USB audio. This worker had no phone access.

- Date: 2026-11-17. Branch: `camera-misc`.
- Reading order: `AGENTS.md`, `DTS-PORT-PLAN.md`, `DTBO-PLAN.md`,
  `FIRMWARE-PLAN.md` and `firmware.map`, `SENSORS-M5-PLAN.md`,
  `AUDIO-M5-PLAN.md`, `MODEM-M5-PLAN.md`, `POWER-M5-PLAN.md`, `NOTES.md`,
  and `M5-REVIEW.md`.
- Evidence tags: `[V]` means checked against the named public source or local
  plan; `[I]` is an inference or handset-specific item still to verify.
- Plans only. No proprietary firmware, source dumps, register tables,
  fingerprint data, SIM identity, serial, MAC or per-unit calibration belong
  in Git (AGENTS.md rules 4, 5 and 8).

## 1. Shared boot and safety gates

- [V] Slot B is the current Linux boot; its B5 success mark is recorded in
  `docs/agents/state.md` and `device/instantnoodlep/NOTES.md`.
- [V] The stock DTBO rewrites the live root compatible to Kona/MTP and ABL
  rejected both neutral-DTBO attempts; `dtbo_b` remains stock
  (`DTBO-PLAN.md` §1, §6; learnings `l-f28ff139` and `l-48e0c482`).
- [I] Do not enable or test new blocks until a separate owner-approved,
  upstreamable root-compatible/DTBO resolution permits a clean RAM boot.
  This plan does not propose another neutral-DTBO image or an unreviewed
  `qcom,kona` workaround.
- [V] The M5 plans already cover the shared SLPI sensor hub, generic audio
  services and safety model (`SENSORS-M5-PLAN.md`, `AUDIO-M5-PLAN.md`,
  `MODEM-M5-PLAN.md`, `POWER-M5-PLAN.md`). This plan fills only their remaining
  peripheral blocks and does not duplicate those implementation plans.
- [V] Any phone boot is RAM-only first; no `super`, `_a`, radio, `persist`,
  `efs*`, or firmware partition write is allowed (AGENTS.md rules 1 and 3;
  upstream CONTRIBUTING.md §3.1 and §3.2).

## 2. Source pins

- `L/` = upstream Linux `torvalds/linux` tag `v7.3-rc6`,
  <https://github.com/torvalds/linux/tree/v7.3-rc6>.
- `D/` = public OnePlus device sources,
  <https://github.com/LineageOS/android_device_oneplus_instantnoodlep>.
- `C/` = public SM8250 community kernel at tag `7.2.0-dev`,
  <https://gitlab.nura.eco/soc/qualcomm-sm8250/linux>.
- `N/` = public OnePlus 8 Pro community device documentation and GPL patch
  series, particularly
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/patches.md>,
  `docs/sensors.md`, `docs/audio.md`, `kernel-patches/0032` (NFC) and
  `pmaports-patches/0021` (NFC wiring fix).
- [V] OnePlus official 8 Pro specifications:
  <https://www.oneplus.com/hk_en/8-pro/specs>; Nura public README:
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/README.md>.
- Local evidence already checked in: `SENSORS-M5-PLAN.md` §2-§5,
  `AUDIO-M5-PLAN.md` §2-§5, `DTS-PORT-PLAN.md` §2.3, and `NOTES.md` entries
  dated 2026-11-17. Those plans distinguish private-overlay claims from
  checked public support; this inventory uses their public corroboration and
  keeps unresolved unit details `[I]`.

## 3. Block inventory

Priority is for a daily-driver handset: **P1** affects frequent core use,
**P2** useful but has a workable alternative, **P3** optional. Address/bus
values are listed only where checked in a public board source. “Not found”
means no matching upstream driver or public device integration was found in
the stated Linux/source pin, not that the hardware is absent.

| Block | Part / bus / address | Mainline status (`L/`, v7.3-rc6) | Userspace / current public evidence | Daily-driver priority |
| --- | --- | --- | --- | --- |
| Vibrator / haptics | Awinic AW8697 LRA; QUP I2C11, `0x5a` [V: `N/docs/patches.md`, “Haptics”; `SENSORS-M5-PLAN.md` §2]. The public device port reports its stock LRA0619 tuning (170 Hz), but that tuning remains owner-image data, not a Git asset [V: N/docs/patches.md]. | Mainline `aw86927` driver matches AW86927/AW86938, not AW8697 [V: `L/drivers/input/misc/aw86927.c`, `L/Documentation/devicetree/bindings/input/awinic,aw86927.yaml`; `SENSORS-M5-PLAN.md` §3.4]. No upstream AW8697 driver found [V]. | Public community port has AW8697 support and a kernel haptics input path [V: N/docs/patches.md]. Omarchy feedbackd/input integration is [I] pending package review; test through a reviewed FF_RUMBLE interface, not an unbounded vibration loop. | P1 [I] — confirmation and UI taps benefit from haptics; silent touch feedback remains usable. |
| Under-display fingerprint | Optical UDFPS is the publicly described hardware class; exact sensor vendor, model, AP bus/address and secure interface are not identified by the allowed public sources [I]. Nura marks its fingerprint reader “not done” [V: N/README.md, Status]. | No mainline IN2023-specific fingerprint driver or public board integration found [V: `L/drivers/input/` and public device sources checked]. Mainline generic input interfaces do not supply a secure biometric protocol. | No Linux enrollment/unlock path is established by the public port [V: N/README.md]. Use PIN/password unlock; do not probe secure storage, invoke a vendor HAL, access `persist`, or port proprietary protocol code [V: AGENTS.md rule 5]. | P2 [I] — password unlock is a practical fallback. |
| NFC | NXP NCI controller; QUP I2C1 at `0x28`; public community DTS uses GPIO83 for enable, GPIO110 for firmware selection and TLMM GPIO111 for IRQ [V: `DTS-PORT-PLAN.md` §2.3; `N/pmaports-patches/0021` corrects enable/firmware roles]. Exact silicon submodel is not identified in the checked public source [I]. | Generic NCI core and NXP NCI I2C transport are upstream (`L/drivers/nfc/nci/`, `L/drivers/nfc/nxp-nci/`); handset GPIO/pinctrl wiring and a working device node remain board work [V]. | Public port reports NFC tag reading with `neard`/`nfctool`; writing and card emulation are untested [V: N/README.md, NFC]. No proprietary NFC firmware is mapped in `firmware.map` [V]. | P2 [I] — tag reading is useful; no card emulation is established. |
| Flashlight / torch | Dual PM8150L flash channels, on PM8150L SPMI USID5 at register base `0xd300` (not a separate I2C flash chip) [V: L/ `arch/arm64/boot/dts/qcom/pm8150l.dtsi`, `pm8150l_flash`; N/pmaports patch 0075]. The public board integration combines both channels as one torch/flash LED [V: N/docs/patches.md, “Flash LEDs” and “Torch”]. | Mainline `LEDS_QCOM_FLASH` driver supports Qualcomm PMIC flash modules through `qcom,spmi-flash-led`; standard LED and LED-flash classes expose torch/strobe [V: `L/drivers/leds/flash/leds-qcom-flash.c`, `L/drivers/leds/flash/Kconfig`]. Exact handset PM8150L node and safe current limits still need board validation [I]. | Public port reports both channels as one `white:flash` torch target [V: N/docs/patches.md]. Omarchy's torch tile/LED name mapping is [I] until the device package owns it. No flash or torch test is part of camera M-CAM1. | P1 [I] — common utility and camera-light function; test at conservative reviewed current only. |
| Proximity | SLPI-hosted proximity sensor(s); exact physical chip, bus and address are not identified from the checked public sources [I]. | SM8250 SLPI/remoteproc and FastRPC infrastructure are upstream; there is no upstream IN2023-specific sensor endpoint driver or AP-side proximity chip driver [V: `SENSORS-M5-PLAN.md` §3.1; L/ SM8250 DTS and remoteproc/FastRPC]. | Public port exposes proximity through its SLPI sensor stack; `monitor-sensor` reports proximity [V: N/README.md, Sensors and N/docs/sensors.md]. The Omarchy plan's bridge is `hexagonrpcd` + `libssc` + `iio-sensor-proxy` [V: `SENSORS-M5-PLAN.md` §5]. Per-unit proximity calibration is excluded [V: AGENTS.md rule 4; `FIRMWARE-PLAN.md` §3]. | P1 [I] — call-screen behavior and pocket detection; leave near/far calibration gated. |
| IR / ToF | OnePlus documents laser autofocus and a 5 MP colour-filter camera; public community docs say the colour-filter module also sees near-IR [V: OnePlus 8 Pro specs; N/docs/patches.md]. No distinct ToF module or address was identified in the public board descriptions [I]. | No ToF-specific handset node/driver was identified in L/ or the checked public board files [V]; generic media/V4L2 support does not identify an absent board sensor. | Near-IR image capture is the GC5035 camera path, not a documented ToF/proximity path [V: N/docs/patches.md, camera rows]. No ToF userspace feature is planned. | P3 [I] — no separate ToF feature is required for a daily driver. |
| Alert slider | A three-position physical alert slider is expected [I]; exact switch part, bus/address and GPIO/input mapping were not established by the checked public DTS sources [I]. | No upstream OnePlus 8 Pro alert-slider-specific driver or checked board node found [V]. Generic `gpio-keys`/input-switch support could fit only if the electrical interface and positions are verified [I]. | Userspace would map the three positions to ring/vibrate/silent state; shell and desktop behavior is [I] until actual events and switch semantics are documented. | P2 [I] — useful, but ordinary software volume/profile controls are a fallback. |
| Notification LED | No separate notification-light part, bus or address is listed in the checked public hardware/device descriptions [V: OnePlus official specs and `D/`; N/ README feature list]. Whether this handset has an unadvertised discrete LED is [I]. | No device notification-LED node or board-specific driver was found in the checked public sources [V]. A display/AOD notification is not an LED driver. | First confirm physical presence without probing pins; if absent, use the display/AOD notification path. | P3 [I] — notification LED is optional; screen notifications remain. |
| SIM-tray detect | SDX55 modem/UIM reports SIM presence over the modem control path; a separate AP-side tray switch part, bus/address or GPIO was not identified in public device sources [V: N/docs/patches.md, SIM/modem; `MODEM-M5-PLAN.md`]. Dedicated tray-detect hardware, if any, is [I]. | Mainline SDX55 MHI/WWAN/QMI infrastructure is tracked by `MODEM-M5-PLAN.md`; no handset-specific AP tray-switch driver was found [V]. Modem-side UIM state is not a separate tray GPIO. | ModemManager/`mmcli` reads the modem's SIM/UIM state [V: `MODEM-M5-PLAN.md`; N/README.md, Mobile data and SMS]. Do not handle SIM PINs or phone-number identifiers in test logs. | P1 [I] — SIM presence affects mobile service; modem reports provide the baseline. |
| Wired USB audio | USB-C port; no 3.5 mm headphone jack [V: OnePlus 8 Pro specs]. Digital USB Audio Class is bus-based rather than a handset-specific I2C device [V: `L/sound/usb/`]. The WCD938x codec's analog USB-C headset route is a separate board/type-C path [V: `AUDIO-M5-PLAN.md` §2; N/docs/patches.md, “False headset detection”]. | Mainline `snd-usb-audio` supports USB Audio Class devices; WCD938x/MBHC mainline codec and SM8250 sound-card support are covered by `AUDIO-M5-PLAN.md` [V]. Correct Type-C host/role/analog accessory routing remains device integration work [I]. | PipeWire/WirePlumber/ALSA are the planned userspace audio stack [V: `AUDIO-M5-PLAN.md` §5]. Nura says analog USB-C headsets are untested; digital USB audio is the conservative first path [V: N/docs/patches.md]. | P2 [I] — external audio is valuable but speakers/Bluetooth are alternatives. |

### 3.1 Boundaries with existing plans

- [V] SLPI startup, FastRPC, sensor libraries, `iio-sensor-proxy`, ALS and
  orientation already belong to `SENSORS-M5-PLAN.md`; this plan adds only the
  proximity/near-far acceptance caveat and its priority.
- [V] ADSP, WCD938x, analog audio and USB-C headset setup already belong to
  `AUDIO-M5-PLAN.md`; this plan separates the generic digital USB audio-class
  fallback from that codec/Type-C graph.
- [V] MHI/SDX55 SIM registration and ModemManager are tracked in
  `MODEM-M5-PLAN.md`; this plan does not add a modem driver.
- [V] Flash current limits must follow the reviewed PMIC/charger source and
  owner policy. The public camera port documents device-specific flash limits;
  those values are not copied into a default-on userspace service here
  (`N/docs/patches.md`, flash rows; `POWER-M5-PLAN.md` and its M5 review).

## 4. Implementation order (future work; no code in this PR)

1. [I] Resolve the common boot/root-compatible blocker and complete M3's
   screen/input/audio prerequisites. Keep every new miscellaneous node
   disabled until its own stage.
2. [V] Confirm mainline generic drivers and bindings against the then-current
   kernel, especially QCOM flash and NCI; rerun schemas on the base before
   board changes.
3. [I] Implement the low-risk input-class consumers first: AW8697 support
   (a separately licensed/reviewed driver plan if no upstream driver lands),
   then verified alert-slider switch events. No binary tuning/config is
   committed.
4. [I] Add PM8150L LED-flash node in a separately gated camera/torch change;
   keep strobe disabled until conservative limits and thermal behavior are
   reviewed.
5. [I] NFC node and host service follow the public NCI wiring; tag polling
   comes before tag writing/card emulation.
6. [I] Fingerprint remains identify-only until an independently acceptable
   secure implementation and data policy exist. No proprietary protocol or
   calibration extraction is in this plan.
7. [I] Test SLPI proximity only through the existing Sensors plan and do not
   map/copy `persist` calibration. Bring USB digital audio through the
   existing Audio/Type-C plans.

## 5. Gated runbook (owner/coordinator only)

The steps below are a future, staged test outline, not an authorization to run
them now. No phone commands have been run here. Shared entry gates are M1b/M2,
M3, a stable root-compatible solution, a healthy slot-B baseline, a reviewed
RAM image, and written owner go. No step flashes a partition. Notify the owner
before any step that changes screen behavior, makes sound, vibrates or turns
on the torch.

| Step | Command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| O0 — prerequisite review | Check `DTBO-PLAN.md`, M1b/M3 status, `AUDIO-M5-PLAN.md`, `SENSORS-M5-PLAN.md`, `MODEM-M5-PLAN.md`, and the current root-compatible workaround. | Shared boot prerequisites are approved and no rejected neutral-DTBO path is proposed. | Root rewrite remains unresolved, or the only candidate carries the test-only Kona patch. | No changes; return to the common blocker. |
| O1 — source/config audit | Against current `linux-omarchy-mobile`, check NCI, QCOM flash, AW86927/AW8697 coverage, GPIO/input and WCD938x/USB audio bindings and configs. | Each proposed device node matches a current driver/binding; AW8697 remains separately planned if unsupported. | Binding/driver absent, unsupported compatible or unknown rail. | Do not add node/config; update plan and gate the missing support separately. |
| O2 — offline build/schema | Build the board DTB/kernel and run relevant `dt_binding_check`/`dtbs_check` after each future logical change. | No new warnings/errors; only the staged block differs from its reviewed base. | Schema error, extra enabled hardware or new unexplained supply. | Revert only the current offline change; no image reaches the phone. |
| R0 — read-only phone baseline (first phone step) | Owner runs `fastboot -s {{SERIAL}} getvar current-slot; fastboot -s {{SERIAL}} getvar slot-successful:b; fastboot -s {{SERIAL}} getvar slot-unbootable:b; fastboot -s {{SERIAL}} getvar slot-retry-count:b`, then from the existing K3 SSH session `ssh root@172.16.42.1 'cat /sys/firmware/devicetree/base/compatible; uname -r; ls /sys/class/input; ls /sys/class/leds; ls /sys/class/nfc 2>/dev/null || true; ls /dev/snd 2>/dev/null || true; ls /sys/class/remoteproc'`. Never run the fastboot block with an unresolved serial placeholder; filter identifiers from output. | Slot B and root/userdata baseline match current NOTES; root compatible (including the currently observed rewrite) and existing class-device state are recorded; no driver is loaded or hardware activated. | Slot state differs, SSH is unavailable, or a read would expose identity/calibration. | No changes; record redacted output and stop. |
| R1 — one staged input feature | After approval, boot one RAM image containing only the approved haptics or slider change. Inspect event capabilities with `evtest --info {{EVENT_NODE}}`; for haptics the owner then runs one short `fftest {{EVENT_NODE}}`; for the slider the owner moves the switch while `evtest {{EVENT_NODE}}` observes it. Never run with unresolved placeholders. | Expected event appears; one brief buzz only for haptics; slider positions map consistently. | Missing device, driver fault, unexpected continuous vibration or any other block binding. | Stop effect/restore slider, reboot to known-good slot B; no module unload/reprobe in the same boot. |
| R2 — NFC tag read | Separate RAM image with only reviewed NFC wiring; owner enables `neard`, polls using `nfctool --device nfc0 --enable` and `nfctool --device nfc0 --poll=Initiator`, and presents a known test tag. No write operation. | NCI transport registers and a tag is read locally; only redacted status is recorded. | Controller fails, NFC powers a PCIe link or tool offers a tag write/card emulation action. | Stop polling/service and reboot to known-good slot B; no data written to tag or partition. |
| R3 — torch | Separate RAM image after LED node/current-limit review; owner announces screen/torch change and runs `brightnessctl -d {{LED_NAME}} set 5%`, waits only a few seconds, then `brightnessctl -d {{LED_NAME}} set 0`. Never run with an unresolved placeholder; no strobe/flash command is allowed. | Both channels illuminate one torch as expected; no thermal/current/fault warning. | Flash/strobe mode appears, brightness is not bounded, LED fault occurs or temperature rises unexpectedly. | Set brightness to zero; reboot to known-good slot B; leave node disabled pending review. |
| R4 — proximity | Follow `SENSORS-M5-PLAN.md` only after its SLPI, package and calibration gates. Cover/uncover while checking sensor proxy readings; do not read/copy `persist` or calibration. | Proximity updates through the reviewed userspace bridge. | Near/far needs per-unit calibration, service writes to persistent userdata without a separate go, or SLPI errors. | Stop sensor service/test; reboot to known-good slot B; leave calibration excluded. |
| R5 — wired USB audio | Follow the Type-C role/Audio plan. Owner plugs a digital USB-C audio device; inspect `lsusb`, `aplay -l`/`wpctl status`, then play a short low-volume test. Analog USB-C accessories are a separate gate. | Digital USB audio device enumerates and outputs sound through PipeWire/ALSA. | USB role would cut SSH without an approved dead-man path, no device appears, or audio is unexpectedly loud. | Stop playback; unplug accessory; return to peripheral USB mode through the approved Type-C rollback. |
| R6 — state check | Read filtered current-slot and success flags after each separate boot. | Slot flags match R0; no partition was written. | Any change/fallback or unknown phone state. | Stop all feature work; owner follows the existing slot recovery plan. |

Fingerprint, ToF, notification LED and any separate SIM-tray switch have no
hardware activation step in this runbook until public identification, a safe
driver path and a narrower plan exist.

## 6. Open [I]s

| ID | Unknown | Resolution gate |
| --- | --- | --- |
| I-MISC-1 | Exact fingerprint vendor/model, bus and trusted transport. | Public licensed device source / maintainer review; do not inspect secure storage or proprietary protocol. |
| I-MISC-2 | Exact NFC IC submodel (public sources establish NXP NCI, not the silicon code). | Public GPL board source audit; if still unknown retain NCI-level wording and R2 tag-read identification. |
| I-MISC-3 | Exact physical proximity-chip model and SLPI sensor inventory. | Existing Sensors plan's public-source audit and owner-approved read-only service enumeration; calibration excluded. |
| I-MISC-4 | Presence of any distinct ToF unit or notification LED. | Manufacturer documentation / non-invasive physical inspection by owner; no GPIO probing. |
| I-MISC-5 | Alert-slider physical part and GPIO/input mapping. | Public board source audit plus owner-observed `evtest` in R1; never infer GPIO numbers from another OnePlus device. |
| I-MISC-6 | Whether a discrete SIM-tray switch exists outside SDX55 UIM status. | Public board-source audit and modem status comparison; no SIM identifiers in logs. |
| I-MISC-7 | USB-C analog headset accessory route on this unit. | Existing Audio/Type-C plans and a separately owner-approved accessory test; digital USB audio remains the first route. |
| I-MISC-8 | Omarchy shell/desktop consumer for slider and torch events. | Device package implementation and desktop integration review after kernel events pass. |

## 7. Definition of done

This inventory is complete as a plan only when each identified block has a
source/status, userspace route, daily-driver priority and explicit `[I]` gate;
phone activation remains owner-gated. It does not claim that haptics, NFC,
torch, fingerprint, alert slider, proximity, SIM detection or USB audio work
on the owner's current kernel.

## 8. Phase 1 implementation gate (2026-11-17)

- [V] Coordinator authorizes combo-based **offline RAM candidates** despite
  the earlier O0 clean-root gate; this is no claim of upstream readiness.
  The inherited Kona workaround must never be proposed upstream.
- [V] Public GPL-2.0-only driver `drivers/input/misc/aw8695-haptics.c`
  at the C/ tag implements AW8697 and a mathematically generated sine;
  it requests no firmware. It requires safety fixes before import: interrupt
  setup ordering, lifecycle cleanup, bounded playback, calibration error
  propagation and parameter validation. Existing AW86927 is a different
  driver and will not acquire a guessed compatible.
- [V] Public N/ patch 0074 at commit
  `4e04b523eefa5494dae95fe374561ced5b781686` describes I2C11, reset 72,
  IRQ118 and board parameters; patch 0075 describes the PM8150L torch.
  These are public GPL board descriptions, not extracted binary tuning.
- [I] Alert-slider electrical interface remains under source audit; do not
  invent GPIOs or copy another handset's mapping.
- [V] Proximity and SIM status are already assigned to Sensors/Modem (§3.1),
  so the other firmware-free P1 candidate here is the torch. It will remain
  disabled in the committed DTS and use a separate RAM candidate.

| Gate | Command/action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| M0 offline | Import reviewed GPL driver/binding; add disabled board nodes; build with `nice -n 10 make ... LLVM=1 W=1`; checkpatch and schemas | Firmware-free modules and no new relevant build/schema warnings | Missing licence, unsafe calibration, unknown wiring, failed check | Revert only misc work; no phone access |
| M1 stage images | Copy compiled DTB; enable only one reviewed node per candidate with host `fdtput`; probe builder with fresh `--out`, boot 2/root userdata | Separate RAM images, watchdog and storage guard retained | Shared output exists, driver set unexpectedly changes | Discard candidate |
| M2 owner baseline | Coordinator runs §5 R0 and announces haptics/torch activation; verifies B successful before boot | Known-good B and recovery available | Any unknown slot state or insufficient battery | No boot |
| M3 owner input | RAM boot one candidate; inspect input capabilities, one bounded FF_RUMBLE effect, or slider observations only when its wiring is proven | Brief bounded effect / verified position events | Unexpected vibration, fault, boot/USB hang | Stop effect, reboot known-good B; owner buttons if needed |
| M4 owner torch | Separate RAM boot, no automatic trigger; one bounded low brightness test, no strobe | Light turns on briefly and off; no fault | Current/thermal warning or cannot turn off | Brightness zero, reboot known-good B |

[I] Exact artifact hashes, commands and offline outcomes follow below after
build validation; M2-M4 are not authorized to this worker.

### 8.1 Slider identification: confirmed protocol, unconfirmed fitted pair

- [V] Coordinator decision for this phase: defer the Hall driver; enable
  **only the I2C1 controller** in the haptics RAM candidate, with no clients,
  and prepare four device-ID reads. This is an explicit exception to the
  earlier single-block candidate outline, not permission to probe other
  addresses or enable a supply.
- [V] OnePlus GPL source pin
  `cad09e061ef6cf689a4a1e54d27562e0f042236a`,
  [`kona-oem.dtsi:49-95`](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250/blob/cad09e061ef6cf689a4a1e54d27562e0f042236a/arch/arm64/boot/dts/vendor/qcom/kona-oem.dtsi#L49),
  describes alternative IST8801 pairs at `0x18/0x19` and MXM1120 pairs at
  `0x0c/0x0d` on `qupv3_se1_i2c`, with IRQ157/158 and L10A supply.
  This shared vendor description does **not** establish the fitted pair.
- [V] Both public GPL headers identify **register `0x09`** as device ID:
  [MXM1120, `hall_mxm1120.h:151-154`](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250/blob/cad09e061ef6cf689a4a1e54d27562e0f042236a/drivers/oneplus/tri_state_key/hall_ic/hall_mxm1120.h#L151)
  expects `0x9c`;
  [IST8801, `hall_ist8801.h:133-136`](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250/blob/cad09e061ef6cf689a4a1e54d27562e0f042236a/drivers/oneplus/tri_state_key/ist_hall_ic/hall_ist8801.h#L133)
  expects `0x81`. These are public GPL protocol definitions, **not a claim
  to have obtained or checked the chip datasheets**.
- [V] Mainline `sm8250.dtsi` maps `i2c1` to `0x984000`, GPIO4/5 and QUP0
  DMA (`arch/arm64/boot/dts/qcom/sm8250.dtsi:1421-1444,5310-5315`). The
  misc DTS pins alias `i2c1`, uses 100 kHz and adds no client nodes.
- [I] The Hall supply may be off. No L10A node or regulator write is added;
  NACKs do not prove absence. Unknown IDs, bus timeouts or existing client
  drivers require stopping, not resetting, forcing access or enabling rails.
- [V] Do **not** use `i2cdetect -y -r 1 0x0c 0x19`: that range also probes
  ten addresses outside the approved four. Use the four `i2cget` commands
  below. Their command byte selects a documented read register; no device
  data/configuration register is written.

### 8.2 Slider follow-up design (documentation only)

- [I] After identifying the fitted pair and reviewing its power/measurement
  protocol, implement a licensed raw Hall interface and a separate userspace
  calibration tool. No activation or threshold driver is in this phase.
- [I] Owner labels **ring, vibrate, silent** by physically placing the slider
  in each position. Collect stationary paired raw samples, estimate noise
  and centers, and reject overlapping/unstable position clusters. Derive
  thresholds only if the measured projection is monotonic; otherwise stop
  for a reviewed two-dimensional classifier rather than invent cutoffs.
- [I] Store the model, common chip-ID/model, thresholds, hysteresis and noise
  bounds in an owner-created local config, e.g.
  `/var/lib/omamobile/alert-slider/calibration.json`. No serial, unit identity,
  stock partition, `persist` read, calibration extraction or Git asset is
  involved. Owner cancellation leaves the previous local config intact.
- [I] A later service applies debounce/hysteresis, rejects out-of-cluster
  values (magnetic interference), and maps only stable calibrated positions
  to desktop profiles. It must recover a known position after restart and
  resume, and leave profile selection unchanged on sensor failure.
- [I] Future acceptance: owner moves all three positions while `evtest`
  observes the reviewed input adapter; compare profile state separately.
  `libinput debug-events` is useful only if the eventual adapter is a device
  libinput accepts. No synthetic slider event or libinput support is claimed
  by this controller-only candidate.

### 8.3 Offline artefacts and the owner runbook (M2-M4)

[V] Two RAM candidates are built from the same kernel and differ only in the
board DTB, which is edited on the host with `fdtput`; the committed DTS keeps
every new node disabled. Both use the probe builder's `--boot 2 --root
userdata` mode, so the watchdog feeder and the storage guard are unchanged
from the K3 combo image. Nothing here is flashed.

| Candidate | Enabled nodes | Purpose |
| --- | --- | --- |
| A `misc-haptics` | `i2c11` + `haptics@5a`, `i2c1` controller only (no clients) | M3a haptics, M3b Hall chip-ID reads |
| B `misc-torch` | `pm8150l_flash` + `led-0` only | M4 torch |

[V] The haptics module is `aw8695_haptics.ko` (`CONFIG_INPUT_AW8695_HAPTICS=m`)
and registers `EV_FF`/`FF_RUMBLE` through `input_ff_create_memless`
(`drivers/input/misc/aw8695-haptics.c:1224-1226`). The torch is
`leds_qcom_flash.ko` (`CONFIG_LEDS_QCOM_FLASH=m`), whose LED name comes from
the child node's `function`/`color`, i.e. `white:flash`.

[V] Both modules are built for a new release string, so the phone's Arch
rootfs needs that release's module tree before the candidate boots. The
coordinator installs it on `userdata` only (no partition write):

```
# on the phone, from the existing K3 SSH session, after the owner's go
tar -xzf modules-<release>.tar.gz -C /
depmod -a <release>
```

[I] `evtest` and `fftest` (package `linuxconsole`) must be present on the
rootfs; `i2cget` comes from `i2c-tools`. If a tool is missing, stop that step
rather than substituting an untested path.

| Step | Command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| M2 baseline | §5 R0, then confirm `slot-successful:b: yes` and `slot-unbootable:b: no` | Known-good B, recovery available, battery sufficient | Unknown slot state or low battery | No boot |
| M3a-1 boot | Coordinator: `fastboot -s {{SERIAL}} boot misc-haptics.img` | Kernel reaches the Arch rootfs; SSH on `172.16.42.1` returns | No boot, USB never enumerates, or a panic before userspace | Power-cycle to known-good B; no partition was written |
| M3a-2 probe | `ssh root@172.16.42.1 'uname -r; lsmod \| grep aw8695; dmesg \| grep -iE "aw8695\|i2c1"'` | Release `7.3.0-rc6-instantnoodlep-k3-misc-…`; `aw8695_haptics` loaded; probe messages, no `-EIO`/timeout | Probe error, I2C timeout, or the module is not loaded | Reboot to known-good B; do not `modprobe` again in the same boot |
| M3a-3 capabilities | `ssh root@172.16.42.1 'for d in /sys/class/input/event*/device/name; do echo "$d: $(cat $d)"; done'`, then `evtest --info /dev/input/event{{N}}` | One input device named by the driver; `--info` lists `EV_FF` and `FF_RUMBLE` | No FF capability, or the device is not the haptics node | Stop; report the capability dump |
| M3a-4 one bounded effect | Owner runs `fftest /dev/input/event{{N}}`: upload `FF_RUMBLE` (type `82`), length `100` ms, both magnitudes `0x2000`, play once, then stop and quit | One short, weak buzz; the driver returns to idle | Continuous vibration, no stop, a kernel splat, or USB dropping | `fftest` stop, then reboot to known-good B; owner holds power+volume-up if input is dead |
| M3b Hall chip IDs | Same boot as M3a: `ssh root@172.16.42.1 'ls -l /dev/i2c-1; for a in 0x0c 0x0d 0x18 0x19; do printf "%s: " $a; i2cget -y 1 $a 0x09 \|\| echo "no answer"; done'` | `0x9c` on `0x0c`/`0x0d` (MXM1120) **or** `0x81` on `0x18`/`0x19` (IST8801); the other pair does not answer | Any other value, a bus timeout, or a kernel splat | Stop; do not retry with `-f`, do not run `i2cdetect`, do not enable a rail; reboot to known-good B |
| M4 torch | Separate boot of `misc-torch.img`, then `ssh root@172.16.42.1 'ls /sys/class/leds; brightnessctl -d white:flash set 5%; sleep 3; brightnessctl -d white:flash set 0'` | `white:flash` exists; a brief dim light, then off; no fault or thermal warning | Light does not turn off, a fault/thermal warning appears, or the LED name is missing | `echo 0 > /sys/class/leds/white:flash/brightness`, then reboot to known-good B |
| M5 state check | §5 R6 | Slot flags match M2 | Any change | Stop all feature work |

[I] M3a-4 is the only step that moves the actuator, and M4 the only step that
emits light; both are announced to the owner first. No step writes a
partition, and no step runs `i2cdetect`, `-f` forced access, a strobe/flash
command or a second `modprobe` in the same boot.
