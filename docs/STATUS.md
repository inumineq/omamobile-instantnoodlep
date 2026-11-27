<!-- SPDX-License-Identifier: MIT -->
# OnePlus 8 Pro (instantnoodlep): status

What works on the phone, block by block, as verified on real hardware. It uses
the columns and legend of upstream's
[supported-devices matrix](https://github.com/derekross/omarchy-mobile/blob/main/docs/DEVICES.md),
so the row can move there once the port is merged. Only what has run on the
owner's phone counts; every cell links the plan or note behind it.
Status as of 2026-11-18.

**Legend** (same as upstream):

- **works**: verified on the phone, on by default;
- **testing**: works by hand (RAM-booted test kernel), not yet on by default;
- **partial**: works on by default, with a known gap that the notes name;
- **WIP**: bring-up in progress, some gates passed;
- **built**: driver and DT written and built, not yet run on the phone;
- **no**: not started, or blocked;
- **-**: the hardware doesn't exist on this device.

"On by default" here means: in the daily kernel on `boot_b` and the installed
packages. "Testing" means it ran on the phone from a RAM boot (`fastboot boot`)
and is waiting for the next daily kernel.

## Matrix

| Device | Codename | SoC | Boot | Storage | Display | GPU | Touch | Buttons | USB net | Wi-Fi | Bluetooth | Battery | Charging | Haptics | Torch | GNSS | AoC | Speakers/mics | Sensors | Modem | NFC | Cameras | Suspend | Fingerprint |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OnePlus 8 Pro | instantnoodlep | SM8250 (Snapdragon 865) | works | works | works (120 Hz) | works | works | works | works | works | works | works | testing | testing | no | built | - | built | built | built | no | WIP | no | no |

## Block by block

| Block | Status | Where it stands | Plan / evidence |
| --- | --- | --- | --- |
| Boot | works | Slot B (`boot_b`), Arch root on `userdata`, stock Android untouched on slot A. Daily kernel `daily2` (flashed 2026-11-19) reaches SSH in about 13 s. A day of RAM tests once deleted the daily kernel's modules; they are now pinned | [DAILY-K3-PLAN](../device/instantnoodlep/DAILY-K3-PLAN.md), [STORAGE-M2-PLAN](../device/instantnoodlep/STORAGE-M2-PLAN.md) |
| Storage | works | UFS, root on `userdata`; `super` and every `_a` partition are never written | [STORAGE-M2-PLAN](../device/instantnoodlep/STORAGE-M2-PLAN.md) |
| Display | works (120 Hz) | DSI-1 1440x3168@120 | [DISPLAY-M3-PLAN](../device/instantnoodlep/DISPLAY-M3-PLAN.md) |
| GPU | works | Adreno 650, msm/freedreno, Hyprland on the GPU | [GPU-USERSPACE-PLAN](../device/instantnoodlep/GPU-USERSPACE-PLAN.md) |
| Touch | works | Corners and both curved edges calibrated (2026-11-18) | [SHELL-UX-PLAN](../device/instantnoodlep/SHELL-UX-PLAN.md) |
| Buttons | works | Power and volume. Alert slider has a plan | [ALERT-SLIDER-PLAN](../device/instantnoodlep/ALERT-SLIDER-PLAN.md) |
| USB net | works | NCM gadget to the laptop. On Type-C test kernels the gadget dies after DisplayPort; two fix candidates are built | [TYPEC-DP-PLAN](../device/instantnoodlep/TYPEC-DP-PLAN.md) |
| Wi-Fi | works | QCA6390 over PCIe (ath11k) | [WIFI-BT-M5-PLAN](../device/instantnoodlep/WIFI-BT-M5-PLAN.md) |
| Bluetooth | works | QCA6390 UART; public address set by the device package | [WIFI-BT-M5-PLAN](../device/instantnoodlep/WIFI-BT-M5-PLAN.md) |
| Battery | works | Fuel gauge: level, voltage, current, temperature | [POWER-M5-PLAN](../device/instantnoodlep/POWER-M5-PLAN.md) |
| Charging | works | PM8150B charger in the daily kernel (`daily2`, flashed 2026-11-19), loaded at boot by the device package. 5 V only; from a 500 mA laptop port it charges at about +150 mA once the session settles | [POWER-M5-PLAN](../device/instantnoodlep/POWER-M5-PLAN.md), [DAILY-K3-PLAN](../device/instantnoodlep/DAILY-K3-PLAN.md) |
| Haptics | works | AW8695 force-feedback rumble, in the daily kernel since 2026-11-19 | [MISC-HW-PLAN](../device/instantnoodlep/MISC-HW-PLAN.md) |
| Torch | no | Not started | [MISC-HW-PLAN](../device/instantnoodlep/MISC-HW-PLAN.md) |
| GNSS | built | Over the SDX55 modem (QRTR LOC); waits on the modem | [GNSS-M5-PLAN](../device/instantnoodlep/GNSS-M5-PLAN.md) |
| AoC | - | Pixel-only block | |
| Speakers/mics | built | DTS for ADSP audio ready; TFA987x speaker amp driver compiles; ADSP still off in test kernels | [AUDIO-M5-PLAN](../device/instantnoodlep/AUDIO-M5-PLAN.md) |
| Sensors | built | SLPI kernel config built, not run | [SENSORS-M5-PLAN](../device/instantnoodlep/SENSORS-M5-PLAN.md) |
| Modem | built | SDX55 kernel candidate built; blocked by the private EFS/DDR policy | [MODEM-M5-PLAN](../device/instantnoodlep/MODEM-M5-PLAN.md) |
| NFC | no | Not started | |
| Cameras | WIP | Front camera (IMX471) hangs the kernel before root. Bisect 2026-11-18: camera clock controller alone boots; adding the CCI camera bus hangs | [CAMERA-PLAN](../device/instantnoodlep/CAMERA-PLAN.md) |
| Suspend | no | Screen-off draw is 360 mA (too high, CPUs likely never reach deep idle); candidate `pm1` built; s2idle not tried | [PM-PLAN](../device/instantnoodlep/PM-PLAN.md), [POWER-M5-PLAN](../device/instantnoodlep/POWER-M5-PLAN.md) |
| Fingerprint | no | Optical under-display sensor; research only | [FINGERPRINT-RESEARCH](../device/instantnoodlep/FINGERPRINT-RESEARCH.md) |

## Beyond the matrix

| Area | Status | Where it stands | Plan / evidence |
| --- | --- | --- | --- |
| USB-C / DisplayPort out | testing | Picture on a Dell U3219Q USB-C monitor from a RAM-booted kernel. Keyboard/mouse behind the monitor's hub don't enumerate yet; fix candidates `typec-fix1`/`fix2` built | [TYPEC-DP-PLAN](../device/instantnoodlep/TYPEC-DP-PLAN.md) |
| Docked desktop | WIP | Plan and a Displays page for Settings (resolution and scale per external monitor) | [DOCK-DESKTOP-PLAN](../device/instantnoodlep/DOCK-DESKTOP-PLAN.md) |
| Phone shell | works | Home strip, dock, Back from both edges, safe insets from the edge calibration (shell 0.2.133-1.3, device package 0.0.7) | [SHELL-UX-PLAN](../device/instantnoodlep/SHELL-UX-PLAN.md) |
| Settings | partial | Upstream's Display and About pages plus our Security page (lock-screen PIN, password) | [patches/omamobile-settings](../patches/omamobile-settings/) |
| Signed package repo | built | Tooling done; owner key not created yet | [LOCAL-REPO-PLAN](../device/instantnoodlep/LOCAL-REPO-PLAN.md) |
| Full-disk encryption | WIP | Plan and touch unlock design | [ENCRYPTION-PLAN](../device/instantnoodlep/ENCRYPTION-PLAN.md) |
| Android apps (Waydroid) | no | Plan + binder fragment written, compile-checked offline; no phone gate has run | [WAYDROID-PLAN](../device/instantnoodlep/WAYDROID-PLAN.md) |

## Next

1. USB-C: gadget recovery after DisplayPort and keyboard/mouse through a dock.
2. Idle power: the interconnect `sync_state()` waits on `1dfa000.crypto` (no QCE driver), so the SoC never sleeps. Fix that, then the first s2idle test.
3. Audio phase 1 (ADSP on), then the camera CCI hang.

Day-to-day detail: [docs/agents/state.md](agents/state.md) and [NOTES](../device/instantnoodlep/NOTES.md).
