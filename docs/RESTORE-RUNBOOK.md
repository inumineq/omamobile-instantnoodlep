<!-- SPDX-License-Identifier: MIT -->
# Restore runbook: how stock comes back on IN2023

Goal: never need it. These paths are verified and on disk BEFORE any
experiment starts.

## Path 0: reboot to slot A (first line of defence)

Slot A keeps stock as long as only slot B images and `userdata` have been
written. In fastboot: `fastboot set_active a` (or let the bootloader fall
back if slot B fails to boot). Stock boots again.

- Note: after `userdata` was written, slot A boots but Android data is gone;
  stock may require a factory reset (this is expected and not a brick).

## Path 1: fastbootd + full OTA payload (normal repair)

1. `fastboot reboot fastboot` (fastbootd, userspace)
2. Flash the full-OTA payload images for IN2023 in order
   (system, vendor, boot, dtbo, vbmeta and the rest of the slot's images)
3. `fastboot reboot`

Requirement: the OTA zip with `payload.bin` for IN2023, downloaded and
checksum-verified during stage 0 (docs/STAGE-0.md step 4).

## Path 2: MSM Download Tool via EDL (last resort)

The leaked/circulating MSM service package for the EU model (IN2023)
revives the phone even from a hard brick via Qualcomm EDL mode.

- Windows only; run as administrator; USB 2.0 port recommended.
- **It wipes everything and relocks the bootloader.** Take this path only
  after paths 0-1 are exhausted.
- Keep the package on a local disk already today; forum links disappear.

## Never do

- Never flash anything to `super` or to a `_a` partition.
- Never flash a payload or image built for another IN20xx regional variant.
- Never run MSM for a different model (IN2020/IN2021/IN2025).
