<!-- SPDX-License-Identifier: MIT -->
# OnePlus 8 Pro phone and docked desktop convergence

[V] 2026-11-20, `inumineq/dual-use`. Research and runbook only.
No kernel, packages, or phone tests produced here.

[I] Success means one cable to the Dell U3219Q gives the owner a normal
Omarchy desktop, the MX Keys Mac and MX Vertical through the monitor's
Logitech receiver, and charging. Unplugging restores the touch-first
handset and keeps the same apps and lock state. A subsequent laptop
connection must recover gadget SSH in either plug orientation. Generic
PD docks and DP-to-HDMI adapters follow the Dell qualification.

## Evidence and prior art

[V] The owner reports daily2-qce-gmu is the peripheral-only daily kernel.
The daily2 config deliberately omits Type-C, DP, FSA4480 and xHCI, and
the laptop link has depended on plug orientation. Slim-all needed
`op-sink-microwatt`, the i2c15 mux bus and xHCI. It produced video but
hit a USB2 connect-debounce error and QMP PCS/PIPE and gadget ep0
errors. Fix1 produced video and charging on November 19, with no
keyboard/mouse input and no gadget at 60 s. Fix2 remains an independent
test. Sources: [daily2 §3](DAILY-K3-PLAN.md),
[orientation report](https://github.com/inumineq/omamobile-instantnoodlep/tree/notes-usb-orientation),
[STATUS USB/DP](../../docs/STATUS.md#block-by-block),
[slim-all learning](../../.trail/learnings/2026-11-18-slim-all-ram-tests-typec-needs-claude.md),
[PR #134 including its NOTES and T7](https://github.com/inumineq/omamobile-instantnoodlep/pull/134).

| Reference | What the evidence establishes |
| --- | --- |
| SDM845 OnePlus 6/6T and Pixel 3 | [V] The upstream [OnePlus common DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sdm845-oneplus-common.dtsi#L938) and [Pixel 3 common DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sdm845-google-common.dtsi#L569) select peripheral mode. [I] No verified DP + role-switch + desktop precedent from these boards. |
| SC7280 Herobrine | [V] [Herobrine DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sc7280-herobrine.dtsi#L464) enables external DP and describes ChromeOS EC Type-C connectors. The EC path is a reference for separating connector policy from display handling. |
| SC8280XP ThinkPad X13s | [V] [External display series](https://lists.openwall.net/linux-kernel/2023/02/13/1518) wires PMIC GLINK and DP. [DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sc8280xp-lenovo-thinkpad-x13s.dts#L96) links the connectors and QMP. [UCSI discussion](https://lists.openwall.net/linux-kernel/2025/03/26/718) records a disconnect regression and follow-up. [I] Use it as a DP and detach-order precedent. The [OTG proposal](https://patchew.org/linux/20260313-topic-x13s._5Fotg-v1-1-cb2e4a08e25d%40oss.qualcomm.com/) does not establish shipped gadget or phone-shell transitions. |
| SM8250 family | [V] [RB5 enablement series](https://lore.kernel.org/linux-arm-msm/20230817145516.5924-1-dmitry.baryshkov@linaro.org/) and [DTS](https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable.git/+/7603d8e78023e5883e075b4625fbdf059c6384f7/arch/arm64/boot/dts/qcom/qrb5165-rb5.dts#1494) show PM8150B/TCPM, a board redriver and QMP-to-MSM DP. [V] The [exact-handset report](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/498f76983128/docs/displayport.md) records four-lane DP with USB2 hub, charging and audio in both orientations on a patched kernel. Gadget recovery and an Omarchy profile transition still need our tests. |
| Fairphone | [V] [FP4 DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/sm7225-fairphone-fp4.dts#L935) provides PM7250B Type-C and OTG, a role-switch reference. [FP5 DP series](https://patchew.org/linux/20250425-fp5-pmic-glink-dp-v3-0-cc9c2aeb42fb%40fairphone.com/) and [FP5 DTS](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/qcm6490-fairphone-fp5.dts#L80) show QCM6490 PMIC GLINK, DWC3 OTG, QMP, a SuperSpeed redriver and an FSA4480-compatible SBU mux. The [DP audio series](https://lkml.iu.edu/2506.1/01610.html) provides a later audio reference. |
| Mobile shell and dock behavior | [V] [Purism's Librem 5 lapdock report](https://puri.sm/posts/announcing-the-lapdock-kit/) shows a running app moving to the external screen with dock input under Phosh. [PINE64's PinePhone FAQ](https://pine64.org/documentation/PinePhone/FAQ/) documents HDMI and USB peripherals through its dock. [Plasma Mobile](https://plasma-mobile.org/2024/03/01/plasma-6/) documents docked mode relaxing phone window maximization. [V] [Fairphone maintainer update](https://archive.fosdem.org/2026/events/attachments/ZNAAZX-mainline_kernel_for_fairphones_-_2026_update/slides/266938/fosdem_20_rsemaak.pdf) and the [postmarketOS FP5 audio configuration cited by the kernel author](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/master/device/testing/device-fairphone-fp5/ucm) provide integration references. [I] These support using one session with adaptive layout. Our pass still requires all four of video, input, power and detach/replug on this build. |

[V] Linux [PMIC GLINK](https://github.com/torvalds/linux/blob/master/drivers/soc/qcom/pmic_glink.c)
provides firmware services, including UCSI and a board-dependent
[alt-mode path](https://github.com/torvalds/linux/blob/master/drivers/soc/qcom/pmic_glink_altmode.c).
Here the PM8150B [PMIC Type-C driver](https://github.com/torvalds/linux/tree/master/drivers/usb/typec/tcpm/qcom)
feeds Linux TCPM directly. A [PS883x](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/mux/ps883x.c)
is an external high-speed retimer/mux reference. The board's
[FSA4480](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/mux/fsa4480.c)
selects the SBU/AUX route. The [QMP combo PHY](https://github.com/torvalds/linux/blob/master/drivers/phy/qualcomm/phy-qcom-qmp-combo.c)
switches high-speed lane orientation and mode. Use the board graph in
[TYPEC-DP-PLAN §2–3](TYPEC-DP-PLAN.md) for the actual topology.

## Kernel integration and fault isolation

[I] **Stage 1, USB without DP.** Take the usbgadget worker's candidate,
config and results as inputs. Qualify PM8150B CC/PD, orientation,
DWC3 OTG/role switch, xHCI and laptop gadget before adding DP.
Confirm the connector HS endpoint reaches DWC3 and the SS endpoint
reaches QMP. Confirm TCPM accepts the connector PDOs and sink power
requirement. Test phone as source/host with a simple OTG peripheral,
and as sink/device with the laptop. Where available, test sink/host
with a powered data dock without video before introducing DP.
Sources: [TYPEC-DP-PLAN §3](TYPEC-DP-PLAN.md), [POWER-M5-PLAN §3.3](POWER-M5-PLAN.md).

[I] **Stage 2, DP and hub.** TCPM negotiates the DisplayPort SVID and
configuration after the appropriate data-role transition. QMP routes
DP from MSM DRM and FSA4480 routes AUX over SBU. HPD leads to DRM link
training, EDID and a Hyprland output. DWC3 host mode creates the xHCI
child. Follow root hub → Dell hub → Logitech receiver → HID → libinput.
At detach track HPD low, DRM/PHY power-off, alt-mode and orientation
reset, xHCI removal and fresh UDC bind on laptop attach. A detached
role reading can reflect the peripheral default. Require actual NIC
enumeration and new SSH. Sources: [Type-C bus](https://www.kernel.org/doc/html/latest/driver-api/usb/typec_bus.html),
[PR #134, T7](https://github.com/inumineq/omamobile-instantnoodlep/pull/134).

[V] [Linux DP alt-mode definitions](https://github.com/torvalds/linux/blob/master/include/linux/usb/typec_dp.h)
classify C/E as four DP lanes and D/F as two DP lanes with SuperSpeed
USB. F is legacy and was dropped after DP Alt Mode 1.0b. Dedicated USB2 D+/D− and CC/PD remain available with C/E. The
[Dell user guide, pp. 14, 59, 68](https://downloads.dell.com/manuals/all-products/esuprt_display_projector/esuprt_display/dell-u3219q-monitor_user%27s-guide_en-us.pdf)
documents concurrent DP, USB2 and PD on the USB-C input, a separate
USB3 upstream input and automatic routing for USB-C video.
[I] Expect C/E but capture the assignment. Use an independently
verified D/F dock for the multifunction control. Use Dell USB-C
input with the separate upstream cable disconnected.

[V] [PR #134](https://github.com/inumineq/omamobile-instantnoodlep/pull/134) records the 5 V-only sink restriction.
[I] Keep the restriction until the charger and higher-voltage policy
pass POWER-M5-PLAN P2/P3 and receive owner approval. Stop on an
unexpected contract voltage.

[I] **Power.** The Dell supplies VBUS and the phone sinks power while
the phone is USB DFP/host and DP source. Capture TCPM contract
voltage/current and USB power mode separately from charger input
and battery current/temperature. A sink role or PD icon alone leaves
battery charging unverified. Check for a positive net battery charge
trend under a repeatable desktop load, below the charge cap, using
the gauge sign convention and the stop limits from the approved
[power runbook](POWER-M5-PLAN.md). Keep the charger configuration
constant across USB/PHY tests. Validate the charger driver/policy
through its own gate before the sustained dock run.

| Symptom | Hypothesis and one-variable RAM comparison |
| --- | --- |
| [V] Laptop gadget lost after DP. Fix1 alone failed on November 19 ([PR #134](https://github.com/inumineq/omamobile-instantnoodlep/pull/134)). | [I] QMP drops USB/SAFE mode change while DP is powered. Compare unmodified slim-all with fix1's deferred-mode delta alone. Trace requested/applied mode and DP power-off, then xHCI teardown, role, UDC and fresh laptop SSH. Fix1 already failed the user-facing gate, so use the trace to tell whether replay happened before debugging ep0. If the PHY recovers but UDC stays unbound, isolate gadget rebind as its own comparison. |
| [V] Dell hub debounce/receiver input failure ([slim-all learning](../../.trail/learnings/2026-11-18-slim-all-ram-tests-typec-needs-claude.md)). | [I] First locate the failing layer. If role never becomes host, trace DR_Swap. If host lacks an xHCI child, check host init and bind. With host and xHCI present and no hub, compare slim-all against fix2's static UTMI clock selection alone (T7). Require USB2 enumeration plus HID events; retest plain SuperSpeed separately. If UTMI helps but costs SuperSpeed, test a later mode-aware UTMI/PIPE change alone, serialized with PM and reset (PR #134). |
| [V] QMP PCS init timeout and duplicate PIPE disable ([recovery research](../../docs/research/typec-dp-usb-recovery.md), QMP discussion). | [I] Correlate first timeout with DP entry vs detach. For an entry cleanup imbalance, test a candidate changing only the duplicate timeout clock release, leaving common init/exit responsible for lifetime. Check whether the WARN disappears, whether PCS still times out and whether xHCI/gadget recover. If PCS still starts while held in DP-only reset, test a separate DP-only PCS guard with symmetric common resource accounting and re-enable on USB return. For detach-only timeout, use the fix1 trace before making another change. |

## One session and one event source

[V] [Upstream shell](https://github.com/derekross/omarchy-mobile/tree/main/packages/omamobile-shell)
provides the touch-first shell and dock within Hyprland.
[DOCK-DESKTOP-PLAN](DOCK-DESKTOP-PLAN.md) specifies the desktop
profile. [PR #127](https://github.com/inumineq/omamobile-instantnoodlep/pull/127)
merged the Displays Settings proposal and patch into this project.
The patch validates external modes/scale and persists per-output
rules in `monitors.lua`; the phone panel is read-only there. The
[upstream Display backend](https://github.com/derekross/omarchy-mobile/tree/main/packages/omamobile-settings)
and [Hyprland monitor docs](https://wiki.hypr.land/Configuring/Basics/Monitors/)
are references for the live Lua apply. [I] Qualify the local patch
on the phone and propose the Settings change upstream independently
of the automatic policy.

[I] Implement one session-local reconciler driven by Hyprland's
[monitoraddedv2/monitorremovedv2 socket events](https://wiki.hypr.land/ipc/).
A single event is enough to initiate reconciliation. USB, HID and
DRM udev events are capture evidence. Subscribe then snapshot at
login and after a socket reconnect. Coalesce event bursts and
serialize applies. Requery `hyprctl -j monitors all` after a short
settle interval; if a query or apply fails, retry within a bounded
window. Select the preferred connected, usable external output,
or the handset if none exists. Use a deterministic fallback with
multiple external outputs. Keep an applied topology/profile
snapshot and compare it to live state so duplicate events are
no-ops and partial changes can be reconciled. Requery after apply
to account for cables moving during the transition. Never
interpolate unvalidated monitor names into Lua.

[I] Apply the saved external mode/scale and wait for a usable
output, then move the active workspaces with their windows there
and expose normal tiling, pointer focus and the desktop bar.
Track only placements the transition owns. On unplug, ensure the
internal panel is enabled and awake first, restore the phone
shell, touch mapping, on-screen keyboard and handset scale, then
rehome any workspaces still stranded by compositor fallback.
Preserve the user's in-session moves and every app process.
Physical input arrives through libinput as the hub enumerates.
Desktop entry depends on the usable output so a late receiver
doesn't flap the profile. Test keyboard layout, pointer, shortcuts
and touch even when dock input is absent.

[I] Start with the phone lit as an extended touch display.
Qualify mirroring and panel-off separately, including scaling and
touch coordinates. A panel policy must leave one reachable lock
surface. Keep authentication and idle timers active and keep the
current lock state through every transition; test detach while
locked before enabling panel-off. Keep current audio routing for
the first milestone. Later qualify MSM DP ALSA and PipeWire/
WirePlumber sink availability, select DP only per user preference,
and restore the previous available sink on removal. See
[DOCK-DESKTOP-PLAN gates 2–4](DOCK-DESKTOP-PLAN.md).

## Owner-attended gates

[I] Before each test, record release, image SHA-256 and matched
module tree, verify slot B and its bootable daily fallback, and
use private captures. Use the [daily RAM baseline R0–R9](../../docs/runbooks/DAILY-K3-RUNBOOK.md),
including the kernel image-size limit in [KERNEL-SIZE](KERNEL-SIZE.md).
Get owner approval for each boot and hardware change, with the
owner doing taps and buttons. Check an independent phone console
or fresh Wi-Fi SSH before risking USB. Start the T7 event stream
and a watchdog/hang marker as applicable. For live changes that
can cut access or blank output, arm a timed restore before applying
them. Keep a known-good full-featured cable and the same inputs,
receiver and workload for A/B runs. Record orientation, role,
lane assignment and event uptime.

```sh
sha256sum "$RAM_IMAGE"
fastboot -s "$PHONE_SERIAL" getvar current-slot
fastboot -s "$PHONE_SERIAL" boot "$RAM_IMAGE"
```

[I] Expect manifest match, slot `b`, both phases of fastboot boot
sending/booting `OKAY` for the boot command, expected `uname -r` and
a working handset and independent access within two minutes.
Stop on mismatch, boot error or hang. Roll back by rebooting to the
installed daily B kernel with owner approval. If unresponsive,
stop commands and use the owner button recovery in the daily
runbook. Repeat the baseline per boot before the next comparison.

| Gate and risk | Test and exit criterion [I] | Stop and rollback [I] |
| --- | --- | --- |
| 1. Stage 1, medium | RAM boot the usbgadget image. Use T7 role/UDC snapshot and `lsusb -t`. Laptop replug in both orientations gives NCM and fresh SSH. OTG keyboard enumerates and types. Approved PD source negotiates a recorded contract with phone sink. Replug laptop again. | Stop on role conflict, missing USB, charger or thermal alarm. Unplug and return to daily B. |
| 2. Stage 2 diagnostics, medium | RAM boot T7 fix2 against the matching slim-all baseline. Monitor snapshots through laptop → unplug → Dell → receiver reinsert → unplug → laptop, in both orientations. Compare fixes one at a time as above. Require a stable DRM output, correct role, bound xHCI, hub and HID events, and gadget SSH by 60 s. Test USB3 separately and a D/F dock if available. | Stop on QMP/PIPE/ep0 errors, link loss, failed input or gadget. Keep safe detach observation if the phone responds, then boot daily B. |
| 3. Integrated Dell, medium | RAM boot the minimal passing kernel on the qualified Stage 1 base. Repeat Gate 2, then run a 30-minute representative desktop load with display, keyboard and mouse active. Sample contract, charger status, gauge current and temperature under the approved power procedure. Require stable sink/host, positive net charging below cap and clean gadget recovery after five attach/detach cycles with both orientations represented. | Stop on power stop condition, contract resets, thermal escalation, input/display or gadget loss. Disconnect Dell, capture independently and boot daily B. |
| 4. Session transition, medium | On the qualified RAM kernel stage the session change and Settings as reversible user changes. Save config, observe socket events alongside `hyprctl -j monitors all`, `hyprctl devices`, `hyprctl -j workspaces` and `hyprctl layers`. Test cold login already docked, live plug/unplug, repeated events, rapid replug, delayed HID, manual mode/scale, live apps and locked/unlocked paths. Require usable desktop and visible touch-first phone after detach, with apps and authentication intact. | Stop on inaccessible lock, touch or workspaces. Timed restore re-enables the phone output, stops the reconciler and restores backed-up session settings. |
| 5. Suspend and panel policy, medium-high | While docked, use owner-approved `systemctl suspend` with the existing [PM plan](PM-PLAN.md). Test wake by Power with cable attached, detach during sleep and wake, and reattach after wake. Check journal for PM errors and require video, HID, charge and gadget recovery. Test mirror/panel-off as separate runs after extended mode passes. | Stop on stuck wake, lost panel, input or unstable power. Owner disconnects and wakes with Power, then use button recovery if needed. Restore extended mode and prior suspend policy. |
| 6. Accessory matrix, medium | On the same RAM build qualify a USB-only hub, a known multifunction DP/USB3 dock with PD passthrough and a native DP Alt Mode to HDMI adapter. Record observed lane/USB speed, EDID modes, charge capability and attach/detach behavior against each accessory's advertised features. Test Dell regression after each software change. | Stop on generic regressions or power faults. Unplug and return to the last passing daily or RAM candidate. |
| 7. Daily promotion, high | After RAM qualification and separate owner approval, run Daily K3 F1–F6 with the candidate and the current known-good daily B image. Confirm slot flags and repeat the Dell plug/work/unplug/laptop sequence after a cold boot. | Follow F2–F6 stop and rollback limits. Never exhaust retries or change the active slot as part of this plan. |

[I] Gate 7 is a future owner operation. Prepare the expanded block
with the tested image paths, hashes, expected releases and separate
approval for each write before starting. The only image write here is:

```sh
fastboot -s "$PHONE_SERIAL" flash boot_b "$QUALIFIED_BOOT_IMAGE"
```

[I] Expect `Sending 'boot_b' ... OKAY` and `Writing 'boot_b' ... OKAY`.
On any failure stop before rebooting and use the separately approved
rollback `fastboot -s "$PHONE_SERIAL" flash boot_b "$KNOWN_GOOD_BOOT_IMAGE"`.
The [daily F1–F6 runbook](../../docs/runbooks/DAILY-K3-RUNBOOK.md)
and [B5 gate](BRINGUP-M1b-PLAN.md) govern the separate owner-authorized
success mark and its exact read-back and rollback. This plan grants
no GPT write. Stop promotion if the required success mark cannot be
performed under the approved existing procedure. `super`, slot A and
the `UFS_RW` allowlist are outside the promotion scope.

## Submission and owner decisions

[I] Send independently proven QMP, DWC3, TCPM, DRM fixes and binding
changes to their Linux maintainers after review in linux-omarchy-mobile
(`omamobile`). Keep instantnoodlep DTS/config separate from shared
driver fixes and qualify unrelated devices where shared behavior changes.
Send the session policy and Displays Settings through omarchy-mobile
(`main`), use the device package for board defaults and send reusable
desktop policy changes to Omarchy where appropriate. Follow the upstream
[contribution rules](https://github.com/derekross/omarchy-mobile/blob/main/CONTRIBUTING.md#6-submitting-changes).
Record each pass with date, release, image digest, accessory, orientation
and private capture reference.

- [I] Should the handset stay lit as a touch surface by default once
  extended mode, mirroring and panel-off are qualified?
- [I] What desktop resolution/scale and MX Keys modifier mapping should
  be the initial Dell preference?
- [I] With the session locked and connected to the Dell, should idle
  suspend run on its normal timer or require explicit suspend?
