<!-- SPDX-License-Identifier: MIT -->
# BRINGUP-M1a: RAM-only first light on instantnoodlep

Plan for M1a, the first boot of our kernel: loaded into RAM with
`fastboot boot`, nothing written to flash, stock untouched and active on
slot A. The persistent slot-B install is M1b and gets its own plan.
Modelled on cheetah's BRINGUP-M1.md (upstream) and on the RAM-only probes
of enchilada, flame and dipper. Write and gate before any code runs on the
phone.

## 1. Status

- Date: 2026-11-15
- Branch/worktree: none yet (to be created in linux-omarchy-mobile, based on `omamobile`)
- Built: nothing. Ran on the phone: stock only.
- Stage-0 facts: pending (docs/STAGE-0.md); this plan's [I] items resolve there.
- Milestones (owner decision, wayfinder map): **M1a** = this plan, RAM-only
  first light. **M1b** = the persistent slot-B install (`boot_b`/`dtbo_b`,
  `--set-active`), with its own plan, gated on the tickets "Slot-B bootable
  marking on Qualcomm: the named GPT-attribute exception" and "vbmeta/AVB
  handling on an unlocked Qualcomm ABL". **M2** = Arch root on `userdata`.
  Inside M1a, kernel **K1** (SM8250 community kernel, steps R1-R6) comes
  before kernel **K2** (linux-omarchy-mobile `omamobile` + ported DTS,
  step R7).

## 2. Goal

M1a is a **RAM-only first light**. The kernel is loaded with
`fastboot boot`, runs entirely from RAM and writes nothing to flash. Slot A
stays stock and active throughout, and no `--set-active` is sent. In order
of value:

1. A mainline kernel starts from a header-v2 `boot.img` sent with
   `fastboot boot`, and the bootloader framebuffer shows its console.
2. USB gadget networking comes up and `ssh root@172.16.42.1` works with a
   local key.
3. Storage is proven harmless. Boot 1 has UFS disabled. From boot 2 on, UFS
   is on, but the shared init's guard runs with no allowlist, so every UFS
   disk and partition reads `ro=1` and the main LUN's whole-disk node is gone.
4. Watchdog handled and `panic=10` set. Any failure ends in a reboot into
   stock on slot A.
5. Afterwards stock boots from slot A, and `fastboot getvar all` shows the
   same slot flags as the stage-0 capture.
6. Optional, after goal 3 passes: read-only, off-repo backups of the
   radio/calibration partitions, taken from the guarded RAM init.

Out of scope here:

- **M1b**: any write to `boot_b` or `dtbo_b` and any `--set-active`. It is
  gated on the tickets "Slot-B bootable marking on Qualcomm: the named
  GPT-attribute exception" and "vbmeta/AVB handling on an unlocked
  Qualcomm ABL". It needs a Qualcomm GPT-attribute entry in upstream
  CONTRIBUTING.md §3.1, and none exists ("No device has an entry yet")
  [V: U/CONTRIBUTING.md:60, U/AGENTS.md:14].
- **M2**: any write to `userdata`, and the Arch root on `userdata`.

Why the goal changed:

- The owner chose the M1a/M1b split on the wayfinder map (NOTES.md,
  2026-11-15 late).
- [V] Upstream lets every non-Tensor port take its first light from RAM.
  OnePlus 6 (`enchilada`) did a RAM-only `fastboot boot` of a header-v0
  image [U/device/enchilada/NOTES.md:169-189]. Pixel 4 (`flame`) booted
  RAM-only through a temporary U-Boot stage
  [U/device/flame/BRINGUP-M1.md:4,95-98]. Xiaomi Mi 8 (`dipper`) used a
  RAM-only `fastboot boot` [U/device/dipper/BRINGUP-M1.md:18-21].
  DEVICES.md calls the flame and dipper probes "merged"
  [U/docs/DEVICES.md:80,82].
- [V] `bin/omamobile` accepts only `android-v4`, `android-v0` and
  `qcom-abl` [U/bin/omamobile:125-128]. Its `fastboot`, `flash` and `push`
  refuse `android-v0` and `qcom-abl` [U/bin/omamobile:1179-1182,1216-1220,
  1256-1259]. A `ram-only` descriptor "marks a probe with no persistent
  install support" [U/docs/RELEASES.md:80]. There is no in-tree path for a
  header-v2 Qualcomm A/B phone to persist anything today.
- [V] Our slot A holds stock. That is the fallback enchilada and flame no
  longer have [U/device/enchilada/NOTES.md:30-38;
  U/device/flame/BRINGUP-M1.md:21-35]. A RAM-only M1a keeps that intact.

## 3. Path abbreviations

- `G/` = OnePlus GPL kernel (android_kernel_oneplus_sm8250) as register/clock reference
- `R/` = our stock captures (private, `captures/<date>/`)
- `L/` = linux-omarchy-mobile branch `omamobile`
- `P/` = the SM8250 community fork (postmarketOS/Nura)

Source pins, so the line numbers in this plan stay valid:

- `U/` = derekross/omarchy-mobile at `6c11752ae4c3` (main, 2026-11-15 19:28 UTC)
- `Q/` = the Qualcomm reference ABL (edk2 `QcomModulePkg`), as mirrored at
  github.com/QRD-Development/abl `6922a8a066a6`. This is **not** OnePlus's
  ABL. OnePlus ships a closed fork, so anything we infer from `Q/` about the
  phone stays [I] until the phone shows it. This plan only describes `Q/`'s
  behaviour; no code is copied (AGENTS.md rule 5).
- `PM/` = the SM8250 community device package,
  gitlab.postmarketos.org/postmarketOS/pmaports `main`,
  `device/testing/device-oneplus-instantnoodlep/` (adopted 2026-06-29, `a809c15c`)
- `C/` = the community instantnoodlep DTS, tag `7.2.0-dev`
  (see `docs/research/sm8250-dts-gap.md`)

Step ids P0-P5 and R1-R7 in section 8 are local to this plan. They are not
the R1-R6 steps of `docs/runbooks/RESTORE-ASSETS.md`.

## 4. Facts (each [V] with source or file:line, or [I] to check)

- [V] Upstream Linux carries SM8250 OnePlus bindings, common DTS, panel and
  Synaptics TCM touch drivers (LWN 979482).
- [V] `P/` carries `sm8250-oneplus-instantnoodlep.dts` and a Wi-Fi/BT DTS
  fix from around v6.11.
- [V] Nura image (kernel 7.2) shows display 1440x3168@120, GPU, audio,
  Wi-Fi, BT, modem/SMS/data, GPS, NFC, sensors, 5 cameras on this hardware.
- [V] Boot images on this device use header **v2**, page size 4096, with
  the DTB inside `boot.img` and a separate `dtbo` [V: abl-boot-flow.md §4;
  PM/deviceinfo `deviceinfo_header_version="2"`]. [I] The installed
  partition set is `boot`, `dtbo`, `vbmeta` (no `init_boot`/`vendor_boot`)
  until stage-0 Q1 and Q7 confirm it on the unit.
- [V: Q/] Qualcomm ABL picks the DTB by `qcom,msm-id`/`qcom,board-id`, not
  by /soc_id (unlike Pixel) [Q/BootLinux.c:554-563; abl-boot-flow.md
  review item 5]. [I: OnePlus] The OnePlus fork does the same.
- [V: Q/] A RAM boot still loads `dtbo` from flash and applies the matching
  board entry to our DTB unless the DTB is an exact match; a valid DTBO
  table that fails to match or apply fails the boot; a partition without
  the DTBO magic sends ABL down the no-overlay path [Q/BootLinux.c:508,
  565-571,626-631; Q/PartitionTableUpdate.c:1771-1804;
  Q/LocateDeviceTree.c:1029-1037]. [I: OnePlus] The OnePlus fork behaves
  the same, and the partition read on a RAM boot is the current slot's,
  so stock `dtbo_a` (section 5.3).
- [I] This ABL accepts `fastboot boot` (RAM boot) at all: stage-0 Q11,
  decided by STAGE-0-RUNBOOK step D3. Whether it takes a mainline image is
  then step R1.
- [I] Kernel cmdline reaches the kernel via the boot image; upstream prefers
  /chosen/bootargs in the DTB. Decide after stage 0.
- [I] earlycon UART base from the live stock DT (R/devicetree).
- [I] Slot flags live in GPT attributes or `devinfo` (stage 0 Q2).

## 5. Design and options

### 5.1 Options considered

| Option | What it writes | Verdict |
| --- | --- | --- |
| A. `fastboot boot` of a header-v2 image with the stock geometry | nothing [I: see 5.4 for the one conditional GPT write ABL may make] | **chosen** |
| B. Flash `boot_b`/`dtbo_b`, then `--set-active=b` (the old plan) | slot-B images plus a GPT slot-flag write | deferred to M1b; gated on the GPT-attribute and vbmeta/AVB tickets, and needs a §3.1 entry that does not exist [V: U/CONTRIBUTING.md:60] |
| C. Temporary U-Boot stage sent with `fastboot boot`, then Linux from U-Boot's fastboot (flame) | nothing | fallback if ABL rejects every direct mainline image (flame's ABL did [V: U/device/flame/BRINGUP-M1.md:190-191]); U-Boot support for this board is [I] |
| D. Header-v4 kernel-only chainloader, `BOOT_METHOD=qcom-abl` (dodge) | n/a | does not apply: that ABL refuses header v2 under `fastboot boot` [V: U/device/dodge/device.conf:13-17]. Ours is a v2 device [V: PM/deviceinfo `deviceinfo_header_version="2"`] |

### 5.2 Boot image (header v2, stock geometry)

- [V] `PM/deviceinfo`: header v2, page size 4096, base `0x00000000`,
  kernel `0x00008000`, ramdisk `0x01000000`, second `0x00000000`, tags
  `0x00000100`, dtb `0x01f00000`. It also matches the Lineage
  BoardConfig in `abl-boot-flow.md` §4. [I] These must still be confirmed
  against `unpack_bootimg` of the IN2023 OTA's `boot.img` (stage-0 Q7).
  The stock image wins where they differ (the dipper rule: "the same
  geometry as the one it already boots" [V: U/tools/dipper/build-boot.py:5-9]).
- [V] The DTB goes in the header-v2 `dtb` section, not appended to the
  kernel. `Q/` reads it at the page after kernel, ramdisk, second and
  recovery_dtbo [Q/QcomModulePkg/Library/BootLib/BootLinux.c:487-494].
- [V] The DTB must carry `qcom,msm-id = <0x164 0x10000>, <0x164 0x20001>`
  and `qcom,board-id = <0x08 0x00>, <0x00 0x00>` [C lines 38-39]. `Q/`
  picks the SoC DTB from the boot image by these properties
  [Q/BootLinux.c:554-563]. A mismatch fails silently: dipper's ABL
  "silently refuses the whole boot image" over a wrong board-id, with no
  kernel output [V: U/device/dipper/NOTES.md:267-270]. The builder refuses
  a DTB without exactly these values (`fdtget`).
- [V] Root compatible `"oneplus,instantnoodlep", "qcom,sm8250"` [C line 35].
  The draft `device.conf` value `qcom,sm8250-oneplus-instantnoodlep` is
  wrong (sm8250-dts-gap.md review item 1; see 5.9).
- Kernel payload: use the compression that stock's `boot.img` uses (Q7).
  [V] `Q/` handles a gzip kernel [Q/BootLinux.c:255-257,660-670] and, for an
  uncompressed `Image`, honours the header's `text_offset`
  [Q/BootLinux.c:160-165]. [I] OnePlus's fork may differ. Google's SM8150
  fork rejected `text_offset=0` and legacy LZ4 under `fastboot boot`, so a
  patched `text_offset=0x80000` is a separate fallback variant, never the
  first try [V: U/device/coral/BRINGUP-M1.md:224-249].
- Size: [V] `Q/` puts the DTB 2 MiB plus one page below the ramdisk, at the
  top of the kernel region. It fails with "Not Enough space left to load
  kernel image" when they overlap [Q/BootLinux.c:198-214]. [V] Dipper's
  ABL refused a kernel above a measured limit, saying only "Failed to
  load/authenticate boot image" [U/tools/dipper/build-boot.py:17-37]. [I]
  So: keep the kernel lean and the initramfs small, record both sizes, and
  treat that error as "too big" before anything else.
- Note (2026-11-16, [docs/research/abl-kernel-size.md](../../docs/research/abl-kernel-size.md)): in `Q/` the header offsets are file-layout fields, not load addresses, and the kernel-size check is on the decompressed image against the reserved region [Q/BootLinux.c:200-215,652-671,720-726], so the builder's guard now checks that quantity (and the DTB's own 2 MiB + page slot), not the 16 MiB header gap.
- Cmdline (in the header): `console=tty0 panic=10 omamobile.initramfs
  clk_ignore_unused pd_ignore_unused printk.devkmsg=on`. `clk_ignore_unused`
  and `pd_ignore_unused` [V: PM/kernel-cmdline.conf]. `omamobile.initramfs`
  keeps the shared init in RAM and mounts nothing [V:
  U/device/enchilada/device.conf:44-45]. No `earlycon=`: `serial0` in `C/`
  is the Bluetooth UART (abl-boot-flow.md review item 2).
- [I] ABL appends its own arguments. `Q/` adds `root=` and `init=` for an A/B
  boot, adds `skip_initramfs` only without dynamic partitions, and adds
  `androidboot.dtbo_idx` when it applied an overlay
  [Q/UpdateCmdLine.c:506-530]. On enchilada it appended `root=PARTUUID=…
  skip_initramfs ro init=/init` even on `fastboot boot`, and the shared init
  still ran as PID 1 [V: U/device/enchilada/NOTES.md:187-189]. The
  `/proc/cmdline` record is evidence in its own right (step R3).

### 5.3 The dtbo problem (the main design risk)

- [V] In `Q/`, a RAM boot still loads `dtbo` from flash. When that `dtbo`
  is a valid DTBO table, ABL takes the overlay path. It finds the board
  entry by board-id and applies it to our DTB, and the boot fails if either
  step fails ("Board Dtbo blob not found", "Dtb overlay failed")
  [Q/BootLinux.c:508,565-571,626-631;
  Q/PartitionTableUpdate.c:1771-1804]. [I] The partition read is the
  current slot's, so `dtbo_a`, which is stock.
- [V] `Q/` skips the dtbo only on an "exact DTB match". That needs SoC,
  variant, subtype, foundry and PMIC model matches
  [Q/LocateDeviceTree.c:1029-1037; Q/Include/Library/LocateDeviceTree.h,
  the all-fields match mask]. [I] `C/` carries no `qcom,pmic-id`, so expect
  no exact match.
- [V] The community port neutralises the dtbo instead. It flashes a
  "dtbo.img" that is a plain FDT compiled with `dtc`, not a DTBO table
  [PM/APKBUILD `build()`, PM/sm8250-oneplus-instantnoodlep-empty.dts]. A
  plain FDT fails `Q/`'s DTBO magic check, which sends ABL to the
  no-overlay path [Q/PartitionTableUpdate.c:1799-1804]. That is a flash,
  and M1a cannot do it.
- [V] Counter-evidence: dipper booted a mainline image by RAM "with the stock
  `dtbo` untouched" [U/device/dipper/BRINGUP-M1.md:79]. Enchilada erased
  `dtbo_b` because downstream overlays "would not apply to a mainline DTB"
  [U/device/enchilada/NOTES.md:44].
- [I] So with stock `dtbo_a` in place, there are three possible outcomes.
  (a) ABL refuses the image with an overlay error: safe, nothing written,
  phone stays in fastboot. (b) The OnePlus fork tolerates the failure and
  boots our DTB bare. (c) The stock overlay partly applies and grafts
  downstream nodes onto our DT: the phone boots, but on a contaminated DT.
  Outcome (c) is why R3 diffs `/proc/device-tree` against our DTB.
- Offline gate before any boot (step P3): dump the stock `dtbo.img` entries
  from the OTA and try applying the board-id-8 entry to our DTB on the
  laptop. Use AOSP's `mkdtboimg.py dump`, then libufdt's
  `ufdt_apply_overlay`, with dtc's `fdtoverlay` as a second opinion. [I]
  This predicts ABL; it does not prove it.
- If outcome (a) holds: the RAM-only fixes are a DTB that gives an exact
  match (PMIC ids from the stock live DT) or empty label stubs that the
  stock overlay can resolve. That is the same idea as cheetah's dpm stubs
  [V: U/CONTRIBUTING.md §5.3 "build with -@ and add the label stubs it
  targets"]. Each is one variant, one boot. If none works, M1a cannot stay
  RAM-only on this ABL. Neutralising `dtbo_b` and booting slot B is then an
  M1b decision for the owner and the maintainer, never an improvised step.

### 5.4 One conditional GPT write by ABL itself

- [V] In `Q/`, `fastboot boot` on an A/B phone first clears the
  *unbootable* bit of the active slot's `boot` entry
  [Q/FastbootCmds.c:2861-2866; Q/PartitionTableUpdate.c:1538-1558]. It
  writes the GPT only if that changed anything
  [Q/PartitionTableUpdate.c:194-199,258-260]. [I] With
  `slot-unbootable:a = no`, OnePlus's ABL should write nothing. Step P5
  makes that a precondition, and R5 compares the slot flags afterwards.
- [V 2026-11-16] Exception: when `LoadImageAndAuth` fails during a
  `fastboot boot`, ABL marks the active slot unbootable, makes the other
  slot active and cold-resets [Q/VerifiedBoot.c:1508-1515]. Seen on the
  phone after a second RAM boot in one fastboot session. Rule: cold-reboot
  to the bootloader between RAM boots (NOTES 2026-11-16 afternoon).

### 5.5 Initramfs, storage guard and watchdog

- Reuse the shared `initramfs/init` unmodified where we can. The init leaves
  every UFS partition read-only when the image has no
  `/etc/omamobile-ufs-rw` [V: U/initramfs/init:66-75]. The M1a image ships
  without one, so it has no writable exception at all. That is stricter
  than house rule 3, and the same boundary flame and dipper used [V:
  U/device/flame/device.conf:10-11; U/device/dipper/device.conf:9-10].
- With no USB host the init crashes after about 45 s plus 20 s, and
  `panic=10` reboots [V: U/initramfs/init:395-417]. With slot A active, ABL
  then starts stock [V: same behaviour on enchilada, U/device/enchilada/NOTES.md:100-102].
- Watchdog: [V] `sm8250.dtsi` has the APSS watchdog (sm8250-dts-gap.md,
  watchdog 6142-6147). Dipper adds `modprobe qcom_wdt` and a busybox feeder,
  `watchdog -t 5 -T 30`, by patching a copy of the init
  [V: U/tests/dipper-probe, `patch-init.py` assertions]. [I] Whether this
  ABL leaves the watchdog running is unknown. Arm the feeder anyway.
- The probe DTB is a builder-made copy of the kernel's DTB, as flame did
  [V: U/device/flame/BRINGUP-M1.md:121-123,139-141]:
  - USB `dr_mode = "peripheral"` with no role switch. `C/` has OTG plus a
    role switch [V: sm8250-dts-gap.md:179], and flame did not enumerate
    without this change [V: flame:139-141].
  - Remote processors disabled.
  - **Boot 1 only:** UFS host disabled.

  Kernel or DTS changes still belong in linux-omarchy-mobile [V:
  U/CONTRIBUTING.md §6.1]. The copy is probe-only and never merged.
- [I] Display: simple-framebuffer at `0x9c000000`, 1080x2376 [C lines
  45-58]. If ABL leaves the panel lit, that is the console.

### 5.6 Kernels for M1a: K1, then K2

- **K1** (steps R1-R6): the SM8250 community kernel tree (the 7.2 series
  behind the Nura image), built from source with the shared config fragment
  plus a probe fragment. This isolates the one new question, whether ABL
  takes a mainline image by RAM, on a kernel and DT already known to drive
  this hardware [V: NOTES.md 2026-11-15 Nura status]. Precedent: enchilada
  booted from the sdm845-mainline tree, and flame from the community SM8150
  kernel package [V: U/device/enchilada/NOTES.md:13-24;
  U/device/flame/BRINGUP-M1.md:5-9].
- **K2** (step R7): linux-omarchy-mobile `omamobile` with our ported DTS.
  Same image builder and gates, one change: the kernel.

### 5.7 What upstream expects the probe to look like (for the eventual PR)

- [V] A `ram-only` descriptor with empty `BOOT_IMAGES` and `UFS_RW`, which
  every generic tool refuses [U/device/flame/device.conf:1-12;
  U/device/dipper/device.conf:1-11; U/bin/omamobile:125-128]. The proposed
  values are in 5.9; this plan does not edit `device.conf`.
- [V] Its own builder, which never contacts a phone and prints
  `fastboot -s <serial> boot boot.img`. Examples are `tools/build-flame-probe`
  and `tools/dipper/build` with `build-boot.py`. A host test sits in
  `tests/<codename>-probe` [U/tests/dipper-probe asserts the
  `fastboot -s <serial> boot boot.img` string; U/tests/flame-probe exercises
  the guard]. Proposed: `tools/build-instantnoodlep-probe`
  (`--kernel --dtb --ssh-key --mkbootimg --out`). It checks the DTB's root
  compatible, msm-id and board-id, the size limits and the header v2 fields,
  re-reads what it wrote, and records each output's sha256.
- [I] Header-v2 packing inside `bin/omamobile images` (a new method; coral's
  descriptor already uses the name `android-v2` as a refusal marker
  [V: U/device/coral/device.conf:3-11]) is a later tooling PR. It needs the
  maintainer's yes and coordination with the coral port. Not M1a.
- [V] An upstream `device/instantnoodlep/BRINGUP-M1.md` with a status line,
  Goal, Sources and facts, Design, a "Gates and rollback" table (Step |
  Expect/pass | Stop condition | Rollback | Risk), and Results. Results
  record the image sha256, `uname -r`, every `ro` flag, the reserved
  `/proc/iomem` lines, the bound watchdog and USB/SSH
  [U/device/flame/BRINGUP-M1.md:161-180;
  U/device/dipper/BRINGUP-M1.md:57-78; U/CONTRIBUTING.md:269]. NOTES entries
  say how each boot was made and where its root was
  [U/device/enchilada/NOTES.md:11-13]. A DEVICES.md row claims only what
  was verified [U/CONTRIBUTING.md §6.4].
- [V] The human runs every boot [U/AGENTS.md:10]. The fastboot serial is
  pinned [U/device/dipper/BRINGUP-M1.md:40-47]. No key, image, capture or
  firmware goes into git [U/device/flame/BRINGUP-M1.md:118-119].

### 5.8 Kept from the earlier design

- Port `P/`'s DTS into `L/` in upstream style (bindings, then driver, then
  DTS; one commit per logical change) for K2 and later, rather than
  regenerating from scratch.
- `SIMPLEFB_TRIG_CON` and `BRINGUP_PROBE` stay unset: no register writes
  in M1a (upstream rule: never another phone's address).
- Storage guard: M1a ships with no allowlist at all (5.5). The limit of
  slot-B images plus `userdata` applies from M1b (slot B) and M2
  (`userdata`).

### 5.9 Inputs for the device.conf ticket

This plan does not edit `device/instantnoodlep/device.conf`. The edit
happens when the ticket "Lock device.conf values once stage-0 answers
exist" resolves. Inputs from this plan for that ticket:

- Proposed M1a descriptor, following the flame and dipper `ram-only`
  descriptors [V: U/device/flame/device.conf:1-12;
  U/device/dipper/device.conf:1-11]:
  ```
  CODENAME=instantnoodlep
  NAME="OnePlus 8 Pro"
  SOC=sm8250
  COMPATIBLE="oneplus,instantnoodlep"
  BOOT_METHOD=ram-only
  BOOT_IMAGES=""
  UFS_RW=""
  PANEL_SIZE=1440x3168
  ```
- `COMPATIBLE` changes from the draft `qcom,sm8250-oneplus-instantnoodlep`
  to `oneplus,instantnoodlep` [V: C line 35; sm8250-dts-gap.md review
  item 1].
- Parked for M1b, not deleted: the draft slot-B values `BOOT_IMAGES="boot
  dtbo vbmeta"`, `UFS_RW="boot_b dtbo_b vbmeta_b userdata"`, the
  `DTBO_*` keys and the `VENDOR_*` keys. Whether `vbmeta`/`vbmeta_b` stay is
  for the ticket "vbmeta/AVB handling on an unlocked Qualcomm ABL"
  (laptop-build-setup.md review item 4 says drop them); `userdata` belongs
  to M2.
- `INSTALL_KEYS_FASTBOOT` waits for the button finding from stage 0 (note
  under the section 8 table).

## 6. What was built

| Where | Change |
| --- | --- |
| `tools/build-instantnoodlep-probe`; `tests/instantnoodlep-probe` | [V: those files] Offline boot-1/boot-2 builder with probe-DTB identity and edit gates, no UFS write allowlist, the qcom watchdog feeder, header-v2 stock geometry, AOSP read-back checks and per-output sha256 records. Its 64 MiB image cap is [I] until stage 0 records the stock boot partition size; the generated-DTB host cases await the laptop's dtc (2026-11-15). |

## 7. Risks

- Wrong reserved-memory nodes let firmware corrupt RAM silently; check every
  stock reserved-memory node against R/iomem before first boot.
- Stock `dtbo_a` overlay applied to our DTB on a RAM boot (5.3): either ABL
  refuses the image (safe) or, worse, the overlay partly applies and the
  kernel runs on a contaminated DT. R3 diffs the live DT against our DTB.
- ABL load-size limit (5.2): a kernel or initramfs that is too large fails
  with a generic load error. Keep both lean and record their sizes.
- The UFS allowlist risk moves to the M1b plan (and to M2 for `userdata`),
  because the M1a allowlist is empty. When it returns, a wrong allowlist is
  the worst possible failure mode; the build refuses anything not slot B +
  userdata, keep it that way.
- Panel variants: our EU unit has AMS678UW01 (as the Nura image was tested
  with); other units may need separate DT work.

## 8. Gated runbook

The owner runs every step that touches the phone and pastes the output back
(house rule 1). Each phone step gets its full command block, Expect, Stop
and Rollback in `docs/runbooks/M1-RAM-RUNBOOK.md`, written before first
use. The table is the gate summary. One change per boot: if a boot fails,
change one thing and boot again. Never `fastboot flash`, `erase` or
`--set-active` in M1a: any step that seems to need one is a stop.

| # | Step | Expect | Risk | Stop condition | Rollback |
| --- | --- | --- | --- | --- | --- |
| P0 | Stage 0 complete: Magisk RAM boot passed (STAGE-0-RUNBOOK D3), Q4, Q7, Q9 and Q11 answered, answers posted on #808 | D3 printed `Booting OKAY` and stock came up with temporary root | 0 | D3 failed, or any of Q4/Q7/Q9/Q11 open | n/a |
| P1 | Offline: `unpack_bootimg` of the OTA `boot.img`; record header version, page size, offsets, kernel compression, os_version/patch level, dtb size; read the stock DTB's `qcom,msm-id`, `qcom,board-id` and any `qcom,pmic-id` | v2, 4096, offsets as `PM/deviceinfo`; msm-id `0x164`; board-id 8 [I] | 0 | any value differs from 5.2: update 5.2 first | n/a |
| P2 | Build K1: kernel, probe DTB copy (5.5), initramfs without allowlist, `boot.img` via the probe builder; `fdtget` the msm-id, board-id and compatible; record sizes and sha256 | builder exits 0; DTB values exactly as 5.2; no `/etc/omamobile-ufs-rw` in the cpio | 0 | builder refuses, a value differs, or the image exceeds the size the builder allows | fix inputs; delete the output |
| P3 | Offline dtbo check: `mkdtboimg.py dump` of the stock `dtbo.img`; apply the board-id-8 entry to the probe DTB with `ufdt_apply_overlay` (and `fdtoverlay`) | a result is recorded either way: applies, fails, or no matching entry | 0 | cannot extract or parse `dtbo.img` | n/a |
| P4 | Owner decision on P3: if the overlay fails, choose one RAM-only variant (exact-match PMIC ids, or label stubs) or accept outcome (a) as the first finding | written choice in NOTES.md | 0 | no decision | n/a |
| P5 | Phone in fastboot (buttons per the note below the table, or `adb reboot bootloader`): `fastboot devices` (exactly one), `fastboot -s <serial> getvar all`; record `current-slot`, `unlocked`, and `slot-successful`/`slot-unbootable`/`slot-retry-count` for both slots | `current-slot: a`, `unlocked: yes`, `slot-unbootable:a: no`, flags equal to the stage-0 capture | 0 | slot is not `a`, phone locked, `slot-unbootable:a: yes`, or more than one device | `fastboot -s <serial> reboot`; stock boots |
| R1 | K1 boot 1 (UFS disabled): `fastboot -s <serial> boot out/boot.img` | `Booting OKAY`; orange-state screen, then a Linux console; a USB NCM device within about 60 s; fresh `ssh root@172.16.42.1` works | medium | `FAILED (remote: ...)`: paste it, stay in fastboot, go to P4 (a refusal writes nothing). No console and no USB after 2 min. Anything asks to flash | hang: hold Power + Volume Up 10-30 s, stock boots from slot A; if it lands in fastboot, `fastboot -s <serial> reboot`. The no-host crash plus `panic=10` does the same by itself in about 75 s |
| R2 | Read-only checks over SSH, boot 1: `uname -r`, `cat /proc/cmdline`, `ls /sys/block`, `dmesg` (USB, watchdog), watchdog feeder running, `grep -iE 'reserved\|System RAM' /proc/iomem` | expected kernel release; no `sd*` devices at all; feeder running | low | any `sd*` present (UFS was meant to be off); watchdog not fed | `reboot -f` over SSH, stock boots from slot A |
| R3 | DT and cmdline evidence: `dtc -I fs /proc/device-tree` diffed against the probe DTB; check `/proc/cmdline` for `androidboot.dtbo_idx`, `root=`, `skip_initramfs` | no grafted downstream nodes; record whether ABL took the overlay path | low | nodes not in our DTB: outcome (c), stop all bring-up and analyse offline | `reboot -f`, stock boots |
| R4 | K1 boot 2 (UFS on, guard, no allowlist): one change against R1. Same command as R1 with the boot-2 image. Then for every `/sys/block/sd*` and partition, `cat .../ro`; `dmesg \| grep ufs-ro`; `ls /dev/sda` | every disk and partition `ro=1`; `/dev/sda` absent; the init logs "no allowlist ... every partition read-only"; no UFS errors | medium | any `ro=0`; `/dev/sda` present and writable; UFS errors | `reboot -f`, or the R1 rollback if hung |
| R5 | Back to stock: `reboot -f` over SSH, let stock boot fully, then `adb reboot bootloader`, then `fastboot -s <serial> getvar all` | stock Android boots from slot A; slot flags equal to P5 (no GPT write by `fastboot boot`, 5.4) | low | stock does not boot; any slot flag changed | stock does not boot: stop; the owner's last-resort recovery per docs/RESTORE-RUNBOOK.md (outside the port's tooling, recorded if used). Changed flags: record, stop, ask on #808 before any further boot |
| R6 | Optional, only after R4 passes: read-only, off-repo `dd` of `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, `devinfo`, `boot_a`, `dtbo_a` from the guarded RAM init, hashed on the phone and on the laptop | every hash matches both ways; nothing mounted | low | any read error or hash mismatch; USB drops mid-transfer (use 4 MiB chunks, as flame did [V: U/device/flame/BRINGUP-M1.md:197-201]) | discard the partial copy; `reboot -f`, stock boots |
| R7 | K2: R1 to R5 again with the linux-omarchy-mobile kernel and ported DTS (the only change) | same as R1-R5 | medium | as R1-R5 | as R1-R5 |

Fastboot buttons, to settle in stage 0: the draft `device.conf:79-81` says
Volume Down + Power, but [V] Lineage's device data and the Nura README both
say Volume Up + Volume Down + Power
(github.com/LineageOS/lineage_wiki `_data/devices/instantnoodlep.yml`
`download_boot`; github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial
README "Flash" step 2). The runbook's recovery lines use whichever the
phone proves.

## 9. Results

(none yet; append with dates and the kernel release that produced them)

Open questions: the [I] items above, tracked in docs/STAGE-0.md section 5.
