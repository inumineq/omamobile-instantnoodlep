<!-- SPDX-License-Identifier: MIT -->
# Restore runbook: how stock comes back on IN2023

Goal: never need it. These paths are verified and on disk BEFORE any
experiment starts.

Hard rule: the port's tooling never writes `super` (or any logical
partition inside it) or any `_a` partition (AGENTS.md rule 3). Paths 1 and
2 below are the owner's own recovery with OnePlus's images, outside that
tooling. Sources marked "scouting §n" are sections of
`docs/research/restore-assets-scouting.md`.

## Path 0: reboot to slot A (first line of defence)

Slot A keeps stock as long as only slot B images and `userdata` have been
written.

- Under M1a (RAM-only `fastboot boot`, nothing written) the active slot
  never changes, so path 0 is a plain reboot and `set_active` is not
  needed.
- Only use `fastboot set_active a` after an M1b slot switch (a persistent
  slot-B install that made B active), or let the bootloader fall back if
  slot B fails to boot. Record the slot flags before and after
  (`fastboot getvar all` filtered as in stage-0 B2). [I] In the generic
  Qualcomm reference ABL, `set_active a` also clears slot A's successful
  bit and may swap partition GUIDs and the boot LUN; this is unverified on
  OnePlus's ABL (behaviour from `linux-msm/qbootctl` and the Qualcomm
  reference ABL, described only; detail in
  `docs/research/gpt-exception-prep.md`, which lands later).
- Note: after `userdata` was written, slot A boots but Android data is gone;
  stock may require a factory reset (this is expected and not a brick).

## Path 1: fastbootd + full OTA payload (owner's own recovery, outside the port's tooling)

Use only after path 0 has failed. The images in step 2 include `system`,
`vendor`, `product`, `odm` and the Oplus `my_*` partitions, which are
logical partitions inside `super` [I: stage-0 B3 shows `is-logical`]. So
path 1 writes inside `super`. That is exactly why it is not part of the
port's tooling: it is the owner's last-resort recovery with OnePlus's own
images, run by hand. This follows the precedent upstream set for the
OnePlus 6 (upstream #432, recorded in `device/instantnoodlep/NOTES.md`,
2026-11-15 evening): the port writes nothing beyond what has been agreed,
and slot-flag writes count as writes.

1. `fastboot reboot fastboot` (fastbootd, userspace)
2. Flash the full-OTA payload images for IN2023 in order
   (system, vendor, boot, dtbo, vbmeta and the rest of the slot's images).
   Never flash an `xbl*` image without checking `ro.boot.ddr_type`
   (0 = DDR4 uses `xbl`/`xbl_config`, 1 = DDR5 uses `xbl_lp5`/
   `xbl_config_lp5`); the wrong one bricks the phone [V LineageOS
   template, scouting §1.5].
3. `fastboot reboot`

If path 1 is ever used, record it in `device/instantnoodlep/NOTES.md`:
the slot flags before and after (filtered `getvar`, as in stage-0 B2),
every partition flashed, and the image it came from (OTA build id and the
zip's SHA-256 from restore-assets R3).

Requirement: the OTA zip with `payload.bin` for IN2023, downloaded and
checksum-verified during stage 0 (docs/STAGE-0.md step 4;
`docs/runbooks/RESTORE-ASSETS.md` R2-R3).

## Path 2: MSM Download Tool via EDL (last resort)

The OnePlus service package (MSM Download Tool) that circulates for this
model (IN2023, EU code `IN11BA`) revives the phone even from a hard brick
via Qualcomm EDL mode. It is the owner's private recovery copy, never
committed or linked (AGENTS.md rule 5).

- Windows only, on a native USB port (USB 2.0 recommended); a VM with USB
  passthrough is not recommended [I, scouting §3.1]. Run as administrator
  [I].
- Use the `MsmDownloadTool V4.0_Win7.exe` variant; it is required for
  OxygenOS 11 firmware [V scouting §3.1].
- **Never pick "SMT Download" mode: it erases the IMEI and the Widevine
  certificate** [V scouting §3.1].
- **It wipes everything and relocks the bootloader.** Take this path only
  after paths 0-1 are exhausted.
- EU MSM packages exist only up to OxygenOS 11.0.4.4 [V scouting §3.1].
  Path 2 therefore ends on **locked OxygenOS 11**, not on the current
  build. Getting back to OxygenOS 13 means a chain of full OTAs through
  the stock updater [I].
- Keep the package on a local disk already today; forum links disappear.

## Never do

- The port's tooling never writes `super` or any `_a` partition. Path 1 is
  the owner's own recovery outside that tooling, and is recorded if used.
- Never flash a payload or image built for another IN20xx regional variant.
- Never run MSM for a different model (IN2020/IN2021/IN2025) or for the
  OnePlus 8 (region codes `IN21xx`).
- Never pick "SMT Download" in the MSM tool.
