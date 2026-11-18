<!-- SPDX-License-Identifier: MIT -->
# Morning session 2026-11-18: order of phone work

Coordinator plan for the owner's session. Each step points to its own gated
runbook; nothing here replaces their Command/Expect/Stop/Rollback rows. RAM
boots are coordinator steps (AGENTS rule 1); writes and screen steps need the
owner. Rollback for every RAM boot: Power+VolUp 10-30 s, the phone boots daily
K3 from `boot_b` (B5 set).

| # | Step | Who | Runbook | Image |
| --- | --- | --- | --- | --- |
| 1 | Slim + all features (misc, audio phase 1, sensors, kona): Part R checks | coordinator, owner taps (R3) and feels the vibrator | `SLIM-FEAT-RUNBOOK.md`; on a hang bisect down the step images | `k3-slim-feat-ram/boot-slim-feat-kona.img` |
| 2 | Charger P2: boot with the module blocked, start the charge watch, then `modprobe qcom_pm8150b_charger` | owner go for the modprobe, watches temperature | POWER-M5-PLAN §7.4-7.5 | `k3-slim-p2-ram/gated/boot-slim-p2-gated.img` |
| 3 | Type-C T1-T4: USB networking kept, typec sysfs, OTG keyboard, USB-C monitor/dock | owner plugs devices | `TYPEC-DP-PLAN.md` | `k3-slim-typec-ram5v/boot-typec-5v.img` (sink 5 V only) |
| 4 | Front camera C1-C4 | owner go, camera at the ceiling | `CAMERA-PLAN.md` §9.5 | `k3-slim-cam-ram/boot-slim-cam.img` |
| 5 | Packages: device 0.0.6, shell 0.2.133-1.2, settings 0.1.3 (`pacman -U`) | owner go per package | `MORNING-PKG-RUNBOOK.md` | `~/android/build/arm-pkgs-20261118/` |
| 6 | UI survey screenshots + edge calibration | owner unlocks, taps both edges | `tools/instantnoodlep-ui-survey`, `tools/instantnoodlep-edge-calibrate` | daily K3 |
| 7 | PM baseline 15 min screen off, then first s2idle test (power key, RTC) | coordinator; owner go for s2idle | `PM-PLAN.md` §4 | daily K3 |
| 8 | Combine the features that passed into one slim kernel, RAM test, then flash `boot_b` + B5 | owner go for flash and B5 | `DAILY-K3-RUNBOOK.md` part F | built after steps 1-4 |

Modem (gates A-C) and audio first sound (AUDIO-M5-PLAN §10) stay closed this
session unless the owner opens them.
