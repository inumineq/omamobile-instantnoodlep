<!-- SPDX-License-Identifier: MIT -->
# Daily kernel USB gadget robustness

Date: 2026-11-20. Scope: `instantnoodlep-k3-daily2-qce-gmu` at kernel
commit `bd566b604`, with no phone access during preparation. No flash or
merge is in scope. The Fable power program owns suspend and its files are
not changed here.

## Findings [V]

- The field note records that after a hard reset the host saw no gadget
  for 15+ minutes, and flipping the plug brought NCM up within seconds
  (`l-35d3f898`, 2026-11-19). It explicitly says the cause is not proven
  and distinguishes this from the SuperSpeed `-71` error seen after DP.
  [I] Missing CC orientation programming is a strong explanation for the
  hard-reset orientation dependence; this candidate tests that explanation.
- The daily DTS includes the PM8150B Type-C controller and connector, but
  disables `&pm8150b_typec`; DWC3 is `dr_mode = "peripheral"` and the QMP
  PHY lacks `mode-switch` (`sm8250-oneplus-instantnoodlep.dts:750-808,
  952-972` at `bd566b604`). Therefore the kernel does not publish CC
  orientation to the QMP combo PHY. The DWC3 SS PHY remains wired through
  QMP (`...dts:1354-1361`).
- TCPM requests orientation through the Type-C switch (`tcpm.c:1217-1224,
  1318-1362`); the QMP Type-C switch updates its orientation and reinitializes
  the common PHY (`phy-qcom-qmp-combo.c:4775-4795`). A high-speed-only
  `maximum-speed` would remove SuperSpeed from the experiment and likely
  make the link orientation-independent, at the cost of a 480 Mbit/s
  theoretical ceiling. It is a useful fallback, not the primary fix.
- The PMIC port driver reads CC attach/state with `regmap_read()` in its
  TCPC `get_cc` operation (`drivers/usb/typec/tcpm/qcom/qcom_pmic_typec_port.c:
  361-430`); the DTS maps the PM8150B Type-C and PD PHY windows starting at
  `0x1500` and `0x1700` (`arch/arm64/boot/dts/qcom/pm8150b.dtsi:61-80`).
- The PM8150B TCPM driver supports CC detection without a separate Type-C
  userspace read; it owns PMIC register access in the kernel. The existing
  disabled connector already has a 5 V sink PDO and
  `op-sink-microwatt = <10000000>` (`...dts:750-780`). The prior slim Type-C
  RAM work found that omitting this property causes `-EINVAL` during TCPM
  capability setup (learning `l-4ba3a6b2`). Keep the 5 V sink contract and
  charger configuration unchanged.
- On gadget system suspend, DWC3 soft-disconnects, and on resume it
  soft-connects if the gadget driver remains bound and `softconnect` is
  true (`drivers/usb/dwc3/core.c:2561-2570,2626-2634`,
  `drivers/usb/dwc3/gadget.c:4993-5018`). The QCOM glue logs `HS-PHY not
  in L2` after reading its power-event status bit, before disabling clocks
  (`drivers/usb/dwc3/dwc3-qcom-legacy.c:426-445`); its resume restores
  clocks and clears L2 event bits (`:462-495`). Thus the message is not
  itself evidence that resume returned an error.
- `remote wakeup not configured` comes from a gadget wake request when
  `wakeup_configured` is false (`drivers/usb/dwc3/gadget.c:2444-2453`). It
  concerns USB remote-wakeup signaling, not the kernel's resume callback.
  Enabling a DT wakeup flag alone would not configure the NCM function's
  remote-wakeup feature or prove the observed enumeration failure fixed.
- Existing slim Type-C experiments establish that DP altmode entry can
  wedge QMP and lose the gadget until reboot (learning `l-4ba3a6b2`);
  Type-C fix1 did not restore USB after display detach (learning
  `l-a6c927a4`). Step 1 therefore has no DP altmode. The separate fixes
  tested QMP DP-exit state and UTMI clocks; neither is a justification for
  adding DP to this candidate.

## Candidate decision

| Candidate | Single variable | Assessment |
| --- | --- | --- |
| Primary `k3-daily2-qce-gmu-typec` | Enable PM8150B TCPM, Type-C-to-QMP orientation/mode switch, DWC3 USB role switch (peripheral default), and xHCI; leave DP altmode absent | Addresses the missing CC orientation and enables host role. Includes the known `op-sink-microwatt` 10 W sink bound. Must qualify gadget attach in both orientations, host attach, unchanged sink behavior, replug and s2idle restoration. |
| Fallback `k3-daily2-qce-gmu-usbhs` | Add `maximum-speed = "high-speed"` to the current peripheral-only DTS | Cheap orientation-independent diagnostic, but caps the gadget at USB 2.0 (480 Mbit/s theoretical). Keep only if Type-C role integration is unstable or unavailable. |

Do not combine the high-speed cap with the Type-C primary: it would hide
whether QMP orientation switching works. For resume, first collect evidence
with the stock DWC3 soft-disconnect/reconnect path. Only consider a forced
UDC unbind/rebind after resume if logs show the gadget remains bound but
does not reconnect; only consider a QCOM wake IRQ change if traces show the
PHY wake event is required and missing. These are separate follow-up
candidates, not part of the Type-C build.

The PMIC CC register can be read without binding TCPM, but a userspace
reader plus direct QMP programming has no supported interface in this
branch: the QMP driver receives orientation through its Type-C switch
callback (`phy-qcom-qmp-combo.c:4775-4795`). That path also coordinates
PHY reinitialization. [I] A userspace register writer would race PHY
power-management and omit attach/detach notifications. Keep the read and
orientation programming inside the existing PMIC TCPM + QMP switch drivers.

For B, a userspace UDC unbind/bind is the cheapest diagnostic if the normal
resume hook fails, because it recreates the configfs gadget without a
kernel change. It is not the first candidate: DWC3 already invokes
soft-connect on resume if the function remains bound and soft-connect is
enabled. A QCOM wakeup/IRQ change is less justified: the glue's PHY wake
interrupt arming is gated on host role (`dwc3-qcom-legacy.c:451-455`),
while this bug is device/gadget role, and the remote-wakeup log is emitted
by the gadget function path rather than the QCOM PM layer.

## Build record

Primary source worktree: `~/src/l-k3-usbtypec`, branch
`instantnoodlep-k3-daily2-qce-gmu-typec` at `32be29867`, based on
`bd566b604`. Configuration delta: `kernel-daily2-typec.config`; build used
clang/LLD 23.1.3, `LLVM=1`, `ARCH=arm64`, out-of-tree output seeded from
`k3-daily2-qce-gmu`. Release: `7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu-typec`;
`image_size=0x1780000` (below the `0x2b60000` limit). Kernel image, compressed
image, DTB, config, module archive and source patch are in
`~/android/build/k3-daily2-qce-gmu-typec/artifacts/`; checksums are in
`~/android/build/k3-daily2-qce-gmu-typec/SHA256SUMS` and pass `sha256sum -c`.
This is an offline kernel build only: the host did not have the private
`omamobile_probe.pub`, the initramfs root, factory overlay or boot packaging
inputs needed to create `boot-typec.img`. No phone boot, orientation, suspend,
replug, host-role or charging result is claimed. A human must add kernel DCO
sign-off before proposing the source branch upstream; the worker commit has
`Assisted-by: LLM Codex` and intentionally has no `Signed-off-by`.

## RAM runbook (owner-run only; never flash)

`IMG=~/android/build/k3-daily2-qce-gmu-typec/boot-typec.img` (not yet present; first package it using the owner-controlled boot inputs).
`REL=7.3.0-rc6-instantnoodlep-k3-daily2-qce-gmu-typec` (verify actual
`uname -r` from the artifact before boot). Preserve the phone's existing
active slot B. All commands below are prepared only; this worker has no
phone access.

| Step | Action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| T0 | Host: `sha256sum -c ~/android/build/k3-daily2-qce-gmu-typec/SHA256SUMS`; verify `od -An -tx8 -j16 -N8 ~/android/build/k3-daily2-qce-gmu-typec/Image` is at most `0x2b60000`; in fastboot, read `getvar current-slot` and `getvar slot-successful:b`. | Hashes pass; current slot `b`, B successful. | Any hash mismatch, image over ceiling, or slot differs. | Do not boot candidate; `fastboot reboot` to existing daily. |
| T1 | **Blocked until `boot-typec.img` is packaged from the owner-controlled initramfs, factory overlay and boot-signing inputs.** Then owner in fastboot: `fastboot -s {{SERIAL}} boot "$IMG"` (RAM only). USB cable attached in baseline orientation. Over USB SSH run `uname -r`, `cat /sys/class/typec/port0/{power_role,data_role,orientation}`, `cat /sys/class/usb_role/*/role`, `lsusb -t`, `ip a`, and `dmesg | grep -iE 'typec|tcpm|pm8150b|qmp|dwc3|xhci'`. | Candidate release; `sink`/`device` roles for laptop attachment; orientation is non-`none`; role switch `device`; NCM link works. No DP altmode directory or DP registration. | No SSH within 2 min, role `host`/`none`, no NCM, new probe error or crash. | Owner holds Power+VolUp 10-30 s to force reboot; daily on `boot_b` starts. If USB networking is lost, owner flips plug; if still unavailable, forced reboot. |
| T2 | Ten orientation trials. Owner disconnects and reconnects the same cable each time, alternating plug orientation; count 1-10. After each attach run host `dmesg -w`/`lsusb -t`, and on the phone repeat T1 sysfs and NCM checks. | 10/10 attaches enumerate without `-71`; observed Type-C `orientation` alternates normal/reverse and DWC3 remains `device`; NCM works every time. | Any single failure, repeated `-71`, orientation stuck/none, or role flip. | Flip plug once to recover connectivity; otherwise forced reboot to daily `boot_b`; do not retry until logs reviewed. |
| T3 | Replug recovery: after T2, owner unplugs for 10 s and reconnects in each orientation once; repeat host and phone checks. | Every attach yields a new USB enumeration and SSH returns within 2 min. | Any attach fails or NCM does not return. | Owner flips plug or force-reboots to daily. |
| T4 | S2idle resume with cable attached to exercise USB restoration. From a fresh SSH shell, start the existing helper detached: `systemd-run --unit=s2idle-R4c-usb --collect /var/lib/s2idle/step R4c none 60`. This is prepared only; no run occurred. The helper writes `/var/lib/s2idle/R4c.log`; after wake, collect it and `dmesg` over fresh SSH. This reuses `tools/instantnoodlep-s2idle-step` with R4c's 60-second RTC wake and adds the attached-cable check. | RTC wakes in about 60 s; helper restores pm_test/console settings; new SSH succeeds without replug; host shows the same device or a clean re-enumeration; role returns to `device`; no new DWC3/PHY errors. | No wake within 90 s, log missing, reboot/oops, or USB absent after 2 min. Do not repeat suspend on this candidate. | Owner wakes with power key; if cable SSH is absent, owner flips plug or forces reboot to daily `boot_b`. |
| T5 | Optional host-role check, only after T1-T4 pass: owner disconnects laptop, attaches known low-power USB-C OTG keyboard, then checks `/sys/class/usb_role/*/role`, `lsusb -t`, input events and VBUS. | `host`, keyboard enumerates; after removing adapter and attaching laptop, `device` and NCM recover. | Unexpected VBUS/heat, role stuck, no recovery. | Remove adapter and reconnect laptop; if role remains stuck, force reboot to daily. |
| T6 | Compare input behavior to the daily baseline with the same source/cable and an inline USB-C meter, following the owner's existing metered power-program procedure. Do not load a charger module or write a charger limit for this candidate. | No unexpected change in sink voltage/current, phone temperature or charging state; capture meter and gauge readings privately. | Unexpected voltage/current, temperature rise, charger driver binding, or any need to alter charge limits. | Unplug the source and return to daily K3; hand charger behavior to the power-program owner. |

Power-program note: this candidate changes Type-C/DWC3 role and PHY
configuration only. It does not alter Fable power-program code, s2idle
policy, or charger input limits. The attached-cable T4 is an additional
USB regression check; it must not be reported as changing the R4c power
result.

## Open questions

- Does PM8150B TCPM reliably publish both CC orientations on this phone
  with the daily2 no-DP config and keep NCM alive through role discovery?
- Does the stock DWC3 gadget soft reconnect suffice after R4c when the
  cable stays attached, or is a userspace UDC rebind needed?
- Does the Type-C candidate change actual input power or charging state?
  Compare before/after only with the existing power-program's metered
  procedure; this plan makes no charging claim.
- If step 1 passes, keep the QMP SS path and avoid the 480 Mbit/s cap; if
  it fails, test the high-speed-only fallback as an independent boot.
