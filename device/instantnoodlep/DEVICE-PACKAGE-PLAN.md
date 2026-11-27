<!-- SPDX-License-Identifier: MIT -->
# Device package plan: instantnoodlep

Status: draft package 0.0.5. No phone was accessed by this work. Sources in
this plan are local repository files unless named otherwise.

## Package contents

| Path in package | Source / behavior | Evidence |
| --- | --- | --- |
| `/usr/share/omamobile/device.conf` | `device/instantnoodlep/device.conf`; boot images `boot dtbo`, writable list `boot_b dtbo_b userdata`; `ROOTFS_PACKAGES` opts into `vulkan-freedreno` | [V: `STORAGE-M2-PLAN.md` §1, §3 and `GPU-USERSPACE-PLAN.md` §2] |
| `/usr/share/omamobile/firmware.map` | Names-only mapping from `device/instantnoodlep/firmware.map`; `FIRMWARE_MAP=firmware.map`; no firmware bytes are packaged | [V: `FIRMWARE-PLAN.md` F6; `M5-REVIEW.md` §2] |
| `/usr/share/uwsm/env.d/90-omamobile-instantnoodlep-graphics` | GL selection from checked-in uwsm env.d file; freedreno only when DRM driver and loader are present, otherwise llvmpipe | [V: `GPU-USERSPACE-PLAN.md` §4-5] |
| `/usr/lib/environment.d/50-omamobile-back.conf` | Provisional shell edge inset 48 and strip width 32 logical px | [I: `SHELL-UX-PLAN.md` §1; geometry not yet calibrated] |
| `/usr/bin/omamobile-bt-public-addr`, one udev rule and one systemd oneshot | On QCA UART controller add, assigns a phone-local BT public address with `btmgmt public-addr`; the helper stores it only in `/var/lib/omamobile/bt-public-addr`, mode 600, and does not print it | [V: package helper and host test; runtime trigger assumptions remain [I]] |
| `/etc/systemd/system/systemd-vconsole-setup.service` | Masked by the package | [V: owner report, 2026-11-18: service hung two boots; [I] cause unknown] |
| `/usr/share/omamobile/instantnoodlep-mobile-profile/` | Candidate Chromium and per-app profiles; user service applies after upstream setup-user. Revert with the package helper. | [V: upstream setup-user at `c4623572be1c141d602cf99a83ae0bf9e3eea09c`, lines 313-378; every OnePlus value and app result is [I].] |
| `/usr/share/omamobile/instantnoodlep-scaling/` and user service | Foot phone profile, per-user desktop-file scale overrides, and Hyprland dialog rules. Values and app IDs are provisional [I] until the morning survey; desktop overrides copy into `~/.local/share/applications`, never global environment files. | [V: upstream setup-user Foot edits `packages/omamobile-shell/bin/omamobile-setup-user:439-446`; other values [I].] |

The package follows the upstream device-package shape (`PKGBUILD`, `install`,
`version`, `README.md`, package hook, `device.conf`). I read upstream's
`AGENTS.md` and `CONTRIBUTING.md`, then inspected cheetah, felix, tegu,
akita and oriole examples in a read-only clone at the current upstream
checkout. Those examples stage device data with `install` and keep package
hooks passive; this package likewise has no boot-success or flash action.

## Existing installed package

[V: `device/instantnoodlep/NOTES.md`, 2026-11-17 “device package 0.0.3”]
The phone had `omamobile-device-instantnoodlep` 0.0.3-1, installed using
`pacman -U`, and owned its USB network files and systemd-firstboot mask.
The note does not give a build checkout or source commit. Git history in
this repository has no package source at that version, and the read-only
upstream clone has no instantnoodlep device package. Therefore its exact
origin cannot be established beyond “local package artifact”; this package
bumps the version to 0.0.4 to upgrade it without claiming recovered source.

## Firmware map and provenance

`firmware.map` contains paths only for QCA6390 Wi-Fi (`amss20.bin`,
`m3.bin`), QCA6390 Bluetooth (`htbtfw20.tlv`, `htnv20.bin`), Adreno 650 zap
shader (`a650_zap.mdt`→`.mbn`), SM8250 ADSP/CDSP/SLPI/Venus, and SDX55 MHI
members. Sources are vendor/owner OTA images at install time; ADSP/CDSP may
also come from linux-firmware where names and device suitability match.
SLPI, zap, and modem source membership/segments still need names-only
verification against the owner's OTA. The map intentionally omits per-unit
DDR training state, EFS, modem NV, identity, calibration and WLAN MAC data.
[V: `FIRMWARE-PLAN.md`
§5-7 and `firmware.map`; source-member uncertainties are [I] per that plan.]

The repo map's `image:` prefix represents the multiple OTA images used by
this phone. Upstream's currently documented `FIRMWARE_MAP` format is
`source-in-vendor|destination`; supporting the image selector and owner-OTA
extraction requires a companion extractor change before the map can drive
installation. [V: upstream `docs/RELEASES.md` §4; local `FIRMWARE-PLAN.md`
§3-4. Actual extractor compatibility is [I] until implemented and reviewed.]

No OTA, firmware blob, `payload.bin`, factory image, calibration file, MAC,
IMEI or serial is included in this package.

## Descriptor and B5 constraints

[V: `STORAGE-M2-PLAN.md` §1 and §3] `BOOT_IMAGES="boot dtbo"` and
`UFS_RW="boot_b dtbo_b userdata"`; the plan says no vbmeta, super, or any
slot-A partition may be writable. Other bootloader, OS metadata, NV and
install-key fields remain [I] or unset pending source/evidence. In
particular, do not use the descriptor to authorize writes to protected radio
partitions.

[V: `NOTES.md`, 2026-11-17 B5] slot B is marked successful and active. Every
`boot_b` flash clears the success mark, so B5 must be repeated by the owner
after a kernel image update using the exact runbook. The package does not
enable a slot marker, boot hook, flash command, reboot, or boot image update.

## Remaining gates

1. [I] Verify firmware source member paths and any segment joining from an
   owner's verified OTA by listing names only; ship no bytes. Implement and
   review the multi-image extractor path before using `FIRMWARE_MAP`.
2. [I] Verify the `hci_uart_qca` udev parent match, controller readiness,
   and `btmgmt public-addr` behavior on the phone under its approved runbook.
3. [I] Calibrate both shell edges at scale 3 before relying on the proposed
   geometry.
4. [I] Complete descriptor release qualification (DTBO/AVB details,
   OS/patch metadata, install key combinations and remaining descriptor
   fields) before using it for an installer or published image.
5. The B5 slot-success mark must be redone after any `boot_b` write; owner
   approval and the runbook gate apply. No package script performs that
   write.

## Package install and rollback gate

No phone was accessed for this change. Before an owner installs the package,
confirm the exact installed 0.0.3 package manifest and keep an existing root
terminal available. The package owns masks for `systemd-firstboot.service`
and `systemd-vconsole-setup.service`; staging checks require both links to
target `/dev/null`. [V: package `install` and `test/all`.] The latter service
hung two boots on 2026-11-18 [V: owner report]; the cause is unknown [I].

After approval, install the built package using the phone's existing package
workflow, then check `pacman -Q omamobile-device-instantnoodlep`,
`systemctl is-enabled systemd-vconsole-setup.service`, and
`readlink /etc/systemd/system/systemd-vconsole-setup.service`. Expect version
0.0.4-2, `masked`, and `/dev/null`. Stop if the package version differs or
the mask is absent. Roll back by reinstalling the recorded prior package;
confirm the service mask state matches the prior manifest before rebooting.

The BT unit remains a separate on-phone gate: verify the actual udev driver
match, controller readiness, resulting address, and that no address appears
in the journal under `DAILY-K3-PLAN.md` §5.5. The address file must remain on
the phone at `/var/lib/omamobile/bt-public-addr`, mode 600; never capture its
value in notes or logs. [I: runtime behavior until that gate passes.]

## Mobile browser profile survey gate

Package release 0.0.4-2 applies after the existing user profile marker and
after upstream's `omamobile-setup-user.service`. The upstream script's
`--no-first-run`, mobile UA, scale and IME seeds are at
`packages/omamobile-shell/bin/omamobile-setup-user:313-378` in upstream commit
`c4623572be1c141d602cf99a83ae0bf9e3eea09c`. This package replaces only the
Pixel UA with the OnePlus candidate, keeps one scale and IME switch, and does
not force touch emulation, overlay scrollbars, pinch or Ozone Wayland while
their settings are `auto`. [I: the OnePlus UA, scale, optional feature
choices, and every app-specific scale remain unmeasured.]

The user helper stores original flags and launcher files under
`~/.local/state/omamobile/instantnoodlep-mobile-profile/`; backups stay on the
phone. `reset` restores exact originals only when no post-apply edits are
detected. Per-app scale overrides are in `apps.conf`; defaults are `inherit`,
so all eight launchers share the global Chromium profile or keep their
Electron defaults until the survey finds a concrete need.

## App scaling quick wins survey gate

The device package's UI setup service runs after upstream
`omamobile-setup-user.service`. It may adjust Foot's known upstream default
font size, padding and scroll multiplier while leaving upstream's 300 ms
long-press setting intact. Every OnePlus-specific value is [I] until the
morning survey; setup changes only exact upstream defaults so existing user
edits survive. Desktop-file overrides are per-user copies and apply only to
source entries present on the system; no global `environment.d` variable is
added. Existing user desktop entries are left untouched.

[I] Initial candidates: Foot `JetBrainsMono Nerd Font:size=8`, `pad=4x4`,
scroll multiplier `2.0`; Qt V4L2 tools and Fcitx config tool
`QT_SCALE_FACTOR=0.85`; Pinta and LibreOffice desktop entries
`GDK_SCALE=2`. These are reversible hypotheses, not measured recommendations.
Hyprland rules make modal windows and the Nautilus file chooser maximized so
they fit the usable workspace above the on-screen keyboard; verify polkit and
all picker classes on-device.

### Gated coordinator runbook

1. Before install, back up `~/.config/foot/foot.ini` and matching
   `~/.local/share/applications/*.desktop`; record which are user-authored.
   Expect the service and data files in the package manifest. Stop if an
   existing desktop entry would be overwritten. Roll back by uninstalling the
   package and restoring the recorded user files.
2. After owner approval and the morning survey, install the package and start
   the graphical session. Expect the service to run after upstream setup-user,
   Foot only to change known defaults, and copied entries to contain the
   candidate variable. Stop if an app is double-scaled, an Exec line is
   malformed, or dialogs are hidden by the keyboard. Roll back with
   `systemctl --user disable --now
   omamobile-instantnoodlep-scaling.service`, remove package-created desktop
   copies/rules, and restore Foot from backup.
3. Test Foot text/selection/scrolling; each listed application, its dialogs,
   file picker and polkit prompt; keyboard open/closed; and workspace
   geometry. Record observed app IDs and smallest usable scale. Package
   staging does not qualify UI.

### Unrelated upstream weather check

[V] The prior local run stopped at `test/weather.py`, the unit test called
before package staging in upstream `packages/omamobile-shell/test/all`; the
weather-timer staging assertions later in `test/all` were not reached. The
mismatch is JavaScript `Number(null) === 0` in the widget model versus Python
`None` meaning unknown in the service test. This device-package change does
not touch upstream code; report that unit-test mismatch upstream instead of
describing it as a timer-staging failure.

## Wi-Fi power save gate

Package 0.0.9 turns Wi-Fi power save on.

Why. Omarchy ships `/etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf`
with `wifi.powersave = 2` (off). [V, read on the phone by the coordinator]
With the screen off and the cable out, the phone drew a median of 212.0 mA
(210 to 227) with it off and 130.0 mA (124 to 137) with it on, 12 samples
each after 300 s of rest, in one session on the daily kernel
(`k3-daily2-qce-gmu-typec`), measured with
`tools/instantnoodlep-power-baseline --part b`. [V, coordinator's report
2026-11-25] Wi-Fi stayed associated and the kernel log had no `ath11k`
error during the 5 minutes of that step. That is one run of a few minutes,
not a stability test.

How. The package installs
`/etc/NetworkManager/conf.d/zz-omamobile-instantnoodlep-wifi-powersave.conf`
with `wifi.powersave=3` for Wi-Fi devices. NetworkManager gives files that
are read later the higher priority, and files in `/etc` shadow those in
`/usr/lib`, so the file has to sit in `/etc` and sort after Omarchy's.
[V, `NetworkManager.conf(5)`, "Across multiple files later definitions take
precedence"] Omarchy's file is not edited. A connection profile that sets
`wifi.powersave` itself still wins over both.

### Gated soak runbook (owner, through the coordinator)

Run before the package is installed, with the file placed by hand. It
writes one file under `/etc` and no partition image.

1. On the phone, as root:

   ```sh
   cat /etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf
   printf '%s\n' '[connection-omamobile-instantnoodlep-wifi-powersave]' 'match-device=type:wifi' 'wifi.powersave=3' > /etc/NetworkManager/conf.d/zz-omamobile-instantnoodlep-wifi-powersave.conf
   nmcli general reload conf
   w=$(iw dev | awk '$1=="Interface"{print $2; exit}'); c=$(nmcli -g GENERAL.CONNECTION device show "$w")
   nmcli -g 802-11-wireless.powersave connection show "$c"
   nmcli connection up "$c" && iw dev "$w" get power_save
   ```

   Expect: the first command shows `wifi.powersave = 2`; the profile value
   is `0` (default, so the configuration decides); the last line is
   `Power save: on`.
   Stop: the last line says `off`. Run the whole rollback block below and
   report the profile value; the precedence is then not what this plan
   assumes.

2. Restart the phone, wait until Wi-Fi is connected, then read:

   ```sh
   iw dev "$(iw dev | awk '$1=="Interface"{print $2; exit}')" get power_save
   ```

   Expect: `Power save: on`, with no other command run after the restart.

3. Use the phone normally for 24 hours on Wi-Fi: SSH over Wi-Fi if it is
   open, a video call or stream, and at least one night with the screen
   off. Then read:

   ```sh
   journalctl -k -b | grep -i 'ath11k\|wlan\|deauth\|disconnect' | grep -v UFW | tail -40
   journalctl -u NetworkManager -b | grep -ci 'disconnected\|supplicant.*fail'
   ```

   Expect: no `ath11k` error or firmware crash line, and no more
   disconnects than the owner is used to.
   Stop, at any time: Wi-Fi drops out repeatedly, calls stutter, or the
   phone no longer answers pushes. Run the rollback.

Rollback:

```sh
rm /etc/NetworkManager/conf.d/zz-omamobile-instantnoodlep-wifi-powersave.conf
nmcli general reload conf && nmcli connection up "$(nmcli -g GENERAL.CONNECTION device show "$(iw dev | awk '$1=="Interface"{print $2; exit}')")"
```

Then check:

```sh
iw dev "$(iw dev | awk '$1=="Interface"{print $2; exit}')" get power_save
```

Expect: `Power save: off`. The rollback needs Wi-Fi to be connected; if it
is not, remove the file and restart the phone.

The package check (`test/all`) only checks that the file is staged with the
right name and content. It does not run NetworkManager, so step 1 is the
first real check of the precedence. When 0.0.9 is built, the local repo
manifest (`tools/omamobile-localrepo-packages.tsv`) and
`docs/agents/state.md` get the new version in the same change as the
artefacts.

Known limits. Incoming traffic waits for the next beacon wake-up while
power save is on, so latency for pushes and SSH keystrokes can rise; how
much is not measured here. The 82 mA is one session; other access points
can give another number.
