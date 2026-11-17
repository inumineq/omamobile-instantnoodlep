<!-- SPDX-License-Identifier: MIT -->
# Device package plan: instantnoodlep

Status: draft package 0.0.4. No phone was accessed by this work. Sources in
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
0.0.4-1, `masked`, and `/dev/null`. Stop if the package version differs or
the mask is absent. Roll back by reinstalling the recorded prior package;
confirm the service mask state matches the prior manifest before rebooting.

The BT unit remains a separate on-phone gate: verify the actual udev driver
match, controller readiness, resulting address, and that no address appears
in the journal under `DAILY-K3-PLAN.md` §5.5. The address file must remain on
the phone at `/var/lib/omamobile/bt-public-addr`, mode 600; never capture its
value in notes or logs. [I: runtime behavior until that gate passes.]
