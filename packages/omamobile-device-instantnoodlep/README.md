<!-- SPDX-License-Identifier: MIT -->
# OnePlus 8 Pro device package

Version 0.0.4 stages the instantnoodlep descriptor, a names-only firmware
map, session environment settings, the Bluetooth address unit, and the
USB0 network policy and firstboot mask already owned by the installed 0.0.3
package. It does
not contain firmware, kernel images, or per-device identifiers. Firmware
must be supplied from the owner's verified OTA or an appropriate
linux-firmware package at install/build time.

The 48 px edge inset and 32 px width are provisional proposals; calibrate
at scale 3 before shipping. The Bluetooth unit generates a stable,
locally administered address in `/var/lib/omamobile/bt-public-addr`, or
accepts an owner's address written there by hand. That state must remain on
the phone and must not be copied into source control or another device.

The device has booted successfully on slot B and B5's boot-success mark is
set, but flashing any new `boot_b` image clears that mark. This package does
not mark slots; the owner must follow the gated B5 runbook after a boot
image update. `BOOT_IMAGES` and `UFS_RW` permit only `boot_b`, `dtbo_b`, and
`userdata`; never add `super`, any `_a` partition, or `vbmeta`.

The USB0 policy follows upstream's dodge network file, matching the local
phone address in the bring-up notes. The exact old 0.0.3 payload was not
tracked, so that equivalence is inferred; inspect the existing package
manifest before upgrading on the phone.

Build with `makepkg -Csf` on a native aarch64 Arch Linux ARM host. The
descriptor and firmware map are data files; no device or firmware is needed
to build the package.
