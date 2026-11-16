<!-- SPDX-License-Identifier: MIT -->
# NOTES: instantnoodlep (OnePlus 8 Pro, IN2023)

Newest first. Findings that matter beyond one subsystem go here; subsystem
detail lives in the *-PLAN.md files.

## 2026-11-16 (afternoon): stage-0 D4/D5, M1a R1, an ABL slot swap

- [V] D4 ran read-only with temp root (`/debug_ramdisk/su`; the `su` on
  `PATH` is Oplus's own `/product/bin/su` and refuses). Radio backup of
  `persist`, `modemst1`, `modemst2`, `fsg`, `fsc` and `param` (no `ocdt`
  on this unit); every file size equals `blockdev --getsize64`. The images
  stay in the private captures folder. All 19 slotted bootloader
  partitions read `same` across `_a`/`_b`.
- [V] D5 from the captures: stock cmdline has `androidboot.dtbo_idx=16`
  and `androidboot.dtb_idx=3`. Boot DTB 3 is "kona v2.1 SoC 19811":
  `qcom,msm-id = <0x164 0x20001>`, `qcom,board-id = <0 0>`,
  `oplus,dtsi_no = <0x4d63>`, **no `qcom,pmic-id`**; no stock boot DTB
  carries one. So the exact-match variant from P4 needs neither foundry
  bits nor a PMIC list: stock ABL already picks a DTB with exactly those
  three properties. The live DT lists PM8150 x2, PM8150B x2, PM8150L x2,
  PM8009 x2 and PMX55 (`pmxprairie`) on SPMI. `boot_b` and `dtbo_b` live
  on LUN 4 (`sde`), `userdata` on LUN 0 (`sda`).
- [V] P5 passed (`current-slot:a`, unlocked, flags as C3).
- [V] **R1:** `fastboot boot boot1.img` answered `Booting OKAY`, yet the
  phone stayed in fastboot and kept answering `getvar`; no USB NCM device
  came up. The slot flags afterwards equalled P5. In `Q/`, `CmdBoot`
  replies OKAY after `LoadImageAndAuth` and before `BootLinux`
  [Q/FastbootCmds.c:2869-2894], so AVB passed and `BootLinux` refused
  (DTB selection or overlay) and fell back to fastboot. This is P4
  outcome (a), a clean refusal; the on-screen reason was not captured.
- [V] **Then a second `fastboot boot` (the Magisk image, same fastboot
  session) made ABL swap slots.** The transfer ended in `Status read
  failed (No such device)`, stock came up from `_b` with
  `ro.boot.bootreason=bootloader`, and fastboot then showed
  `current-slot:b`, `slot-unbootable:a:yes`, `slot-retry-count:b:7`.
  That is `HandleActiveSlotUnbootable`: mark the active slot unbootable,
  `SetActiveSlot` the other, cold reset [Q/PartitionTableUpdate.c:1471-1528].
  `Q/` calls it when `LoadImageAndAuth` fails on an A/B device, and
  `CmdBoot` sets `MultiSlotBoot`, so a RAM boot reaches it as well
  [Q/QcomModulePkg/Library/avb/VerifiedBoot.c:1508-1515 at `6922a8a066a6`].
  [I] The likely trigger is `KeyMasterSetRotAndBootState`
  [VerifiedBoot.c:1492], which keymaster accepts once per power cycle;
  R1 had already called it. Nothing on `boot`/`dtbo`/`vbmeta` was written;
  the GPT attribute write was ABL's own.
- Consequences:
  - Plan 5.4 ("ABL writes nothing on a RAM boot") is wrong in one case:
    a failed `fastboot boot` can mark the active slot unbootable and swap
    slots. **After any refused RAM boot, cold-reboot to the bootloader
    (`fastboot reboot bootloader`) before the next `fastboot boot`.** The
    M1 runbook now says so.
  - While stock runs from `_b`, house rule 3 forbids writing `boot_b`.
    Back to `_a` needs `fastboot set_active a` (owner-gated write).
    `SetActiveSlot` clears the unbootable bit and switches the UFS boot
    LUN [Q/PartitionTableUpdate.c:1379-1466]; both LUNs carry identical
    bootloaders (D4), so this is the same move as the stage-0 slot move.

## 2026-11-16 (night, omabook): M1a P2 offline probe builds (K1), K2 D1 baseline, K2 push gate

Part 1 — M1a runbook P2, offline (no phone was touched):

- [V] `OMAMOBILE=~/src/omarchy-mobile MKBOOTIMG=~/aosp-tools/system/tools/mkbootimg/mkbootimg.py python3 tests/instantnoodlep-probe`
  exited 0; all five parts ok, `0 skipped part(s)` (CLI refusals; identity/
  watchdog/size guards; initramfs; AOSP v2 read-back; both happy paths).
- [V] `python3 tools/build-instantnoodlep-probe --help`, then the builder with
  `--boot 1 --out ~/android/build/probe/boot1.img` and `--boot 2 --out
  ~/android/build/probe/boot2.img`, `--kernel
  ~/android/build/k1/arch/arm64/boot/Image.gz` (kernelrelease
  `7.2.0-instantnoodlep-k1-g3c5440e9dd3c`), `--dtb
  ~/android/build/k1/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb`,
  `--initramfs-root ~/android/build/initramfs-root`, `--omarchy-mobile
  ~/src/omarchy-mobile` @ 6c11752ae4c3, `--mkbootimg
  ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py`, `--ssh-key
  ~/.ssh/id_ed25519.pub`: both exited 0 ("Built and read back ..."). The PR
  #37 decompressed-kernel guard passes: `gzip -dc Image.gz | wc -c` =
  42,072,576 bytes against the 89,128,960-byte (0x05600000-0x00080000)
  reserved kernel region.
- Builder commit: `git log -1 -- tools/build-instantnoodlep-probe` =
  21fff4bdf58267547efee6b0ca7b2c9c70e53442 (#37); worktree head
  adfe244bee1809e75d24b4fb1d1603e964c7de8a.
- Images (tool SHA256SUMS, outputs in ~/android/build/probe, outside git):
  boot1.img 23,314,432 bytes sha256
  92f2b76c28f3161bc2aa0c8dd435c1914b9554283a02123099ad2b02803d003c; boot2.img
  23,314,432 bytes sha256
  4712a16d753617f38e7c3ea2b2dc2635ff2a3c9e5da49486076a226a3eccce02; probe DTBs
  126,816 / 126,812 bytes (de816c9c..., 33eda1d8...); initramfs identical for
  both boots, 7,867,485 bytes sha256
  f0775df9affd0ee08ae2df83f27fd4ac212c15134983d7a7aa94dfa53a16e366.
- Manifest key fields (both boots): device instantnoodlep, boot 1/2, header
  v2, page 4096, kernel 0x00008000, ramdisk 0x01000000, tags 0x00000100, dtb
  0x01f00000, kernel_size 15,314,546, ramdisk size 7,867,485,
  boot_image_limit 67,108,864 with [I] evidence, hardware_boot_tested=false,
  shared_init_sha256 93d7d9d214ed9c9f6747ad8b8b7c27e26e6daa0f68e1d3635c40e0609c7d9c45,
  mkbootimg_sha256 37d84b3d162e0bc62e36c1f4e1c63c85ea0caa9f29be023eb2f8efe006ad948c.
- [V] `fdtget` on the probe DTBs: compatible `oneplus,instantnoodlep
  qcom,sm8250`, msm-id `164 10000 164 20001`, board-id `8 0 0 0` (exactly as
  5.2); UFS status `disabled` (boot 1) / `okay` (boot 2);
  `etc/omamobile-ufs-rw` absent from the cpio (grep count 0).
- The builder's last stdout line is a `fastboot -s <serial> boot ...`
  template; it was not run (house rule 1).

Part 2 — K2 D1 baseline (DTS-PORT-PLAN gate D1), offline in ~/src/l with a
`git worktree add` of base 317d87dc2db0 (worktree removed afterwards; no K2
commit changed, head still a28aaf1a09db8889ed156212286e942e411dbe93). venv
~/android/build/venv-dt (dtschema 2026.9) active, `nice -n 19`, ARCH=arm64,
separate O= dirs ~/android/build/k2-d1/{base,head}, logs in
~/android/build/k2-d1/logs:

- [V] `make dt_binding_check` (full): base EXIT=0, head EXIT=0; 0 warning and
  0 error lines in both logs; the normalized diagnostic lines are identical
  between base and head (10 each, pre-existing dtschema hints only), so the
  new `oneplus,instantnoodlep` entry in arm/qcom.yaml passes with no new
  schema error.
- [V] `make dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom.yaml`
  (the schema file the plan names at DTS-PORT-PLAN.md:342; the instantnoodlep
  DTB is named at :334/:343): first attempt EXIT=2 on both trees because
  `dtbs_check` needs a `.config` (`make ARCH=arm64 defconfig` in each O dir
  first, EXIT=0; CONFIG_ARCH_QCOM=y gates the DTB). Then base EXIT=0 with
  1926 schema-checked DTBs (`[C]` lines), head EXIT=0 with 1927 — the extra
  one is `qcom/sm8250-oneplus-instantnoodlep.dtb` (head log line 2082), with
  no diagnostic output. 0 warnings and 0 errors in both logs; no head-only
  warnings. Gate D1 passes.

Part 3 — K2 fork push gate: STOPPED at the email check. [V] `git log
--format='%an <%ae> | %cn <%ce>' 317d87dc2db0..instantnoodlep-k2` in ~/src/l:
all four commits (b184aa0e0, 5567bd380, f18746472, a28aaf1a0) are authored
and committed with the owner's personal email address,
not a `@users.noreply.github.com` address. Per the gate, Part 3 stopped
there: nothing was rewritten, no remote was added, and nothing was pushed to
any remote (derekross included). No fork head exists to record. [I] whether
the owner wants a noreply-identified fork is an owner decision, not mine.

## 2026-11-16: stage 0 phases A-B, stock moved to slot A

- [V] A3b case (c) applied and worked. Stock ran
  `IN2023_13.1.0.591(EX01)` from `_b`; the owner local-installed the same
  `.591` full zip, and the A3 rerun shows `ro.boot.slot_suffix` = `_a`,
  the same fingerprint, `flash.locked` = `1`, `green`. **The Oplus updater
  accepts a same-version full zip**, so `a3b-contingency.md` is no longer
  needed.
- [V] B2 (ABL fastboot, locked): `current-slot:a`, `unlocked:no`,
  `secure:yes`. Slot flags: a and b both `successful:yes`,
  `unbootable:no`, `retry-count:6`. Slot b is still marked good after
  stock left it; that is the baseline for the ticket "Slot-B bootable
  marking on Qualcomm: the named GPT-attribute exception".
- [V] No `init_boot` or `vendor_boot` partitions. `boot`, `dtbo`,
  `vbmeta`, `vbmeta_system` are raw and slotted (`_a`/`_b`
  `partition-type` lines). This ABL reports `has-slot` only for `boot`,
  `modem` and `system` (`no`). `version-bootloader` is empty.
  `max-download-size` is 805306368 (768 MiB).
- [V] B3: fastbootd is reachable (`is-userspace: yes`), so restore path 1
  is proven. `super-partition-name:super`. Logical partitions in `super`:
  `system`, `system_ext`, `vendor`, `product`, `odm` and ten `my_*`
  (Oplus) partitions, all `_a` in the current-slot metadata.
  `userdata` is not logical and is 0x36F3453000 bytes (about 236 GB).
- [V] **Virtual A/B.** Every logical partition had an `_a-cow` twin right
  after the install (`system_a-cow` 0x2B65C000 bytes against `system_a`
  0x2B3A7000), yet both ABL and fastbootd reported
  `snapshot-update-status:none`. [I] Either the merge had finished and
  cleanup was still pending, or this boot HAL does not report the merge
  state; the status variable alone cannot tell them apart. AOSP fastbootd
  refuses to erase `userdata`/`metadata`/`misc` mid-merge; whether ABL's
  `oem unlock` does is unknown. The runbook now has B4 (status `none`
  **and** no `-cow` partitions) as a hard gate before C2. Pending: the
  owner's B4 result.
- [V] Restore-assets R4 ran offline on the laptop
  (`docs/research/r4-stock-images.md`): boot header v2, page size 4096;
  `boot` and `dtbo` are **chained** in stock vbmeta (`Flags: 0`), so ticket
  #10 lands in the chain case (option B, a test-key footer on `boot_b`).
  All 19 dtbo table entries have id/rev/custom 0; overlays and base DTBs
  are matched on `qcom,msm-id`/`qcom,board-id` plus the Oplus property
  `oplus,dtsi_no` (0x4d63 = our project 19811).
- Consequence for later milestones [I]: `super` is Virtual A/B, so a
  future stock OTA would use snapshots too. The port never writes `super`
  (AGENTS.md rule 3), so nothing changes in the safety model, but the
  M1b `--set-active` step must also be preceded by a `none` merge status
  (AOSP fastbootd refuses slot changes while `merging` [V: AOSP
  `fastboot/device/commands.cpp` `SetActiveHandler`]).

## 2026-11-15 (late): M1 split, RAM-only plan

- The owner chose to split M1 on the wayfinder map. **M1a** is a RAM-only
  first light (`fastboot boot`, nothing written, slot A stock and active);
  `BRINGUP-M1-PLAN.md` now plans it, with kernel K1 (SM8250 community
  kernel) before K2 (`omamobile` + ported DTS). **M1b** is the persistent
  slot-B install (`boot_b`/`dtbo_b`, `--set-active`), gated on the tickets
  "Slot-B bootable marking on Qualcomm: the named GPT-attribute exception"
  and "vbmeta/AVB handling on an unlocked Qualcomm ABL". **M2** stays
  "Arch root on userdata".
- [I] There is no public evidence yet that this phone RAM-boots a mainline
  image. Lineage and the community port document flashing only
  (`lineage_wiki` `install_method: fastboot_nexus`; Nura README "Flash"),
  and a TWRP-era guide flashes recovery rather than booting it.
  wiki.nura.eco and XDA could not be checked (bot protection / 403).
  Stage-0 Q11 decides at STAGE-0-RUNBOOK D3 whether this ABL RAM-boots at
  all (a Magisk-patched stock image); the first mainline image is M1a
  step R1.
- [I] Main risk: on a RAM boot the stock `dtbo_a` overlay is still read
  from flash and applied to our DTB. The Qualcomm reference ABL then
  either refuses the image or applies the overlay; a partial graft would
  leave the kernel on a contaminated DT. The plan has an offline overlay
  check (P3) and a live-DT diff (R3) for it.
- Disputed: the fastboot button combo. `device.conf` says Volume Down +
  Power; Lineage's device data and the Nura README say Volume Up + Volume
  Down + Power. Stage 0 settles it; until then, `adb reboot bootloader`.

## 2026-11-15 (evening): research landed, upstream precedents

- Research notes from the four research tickets are in `docs/research/`,
  each with a coordinator review of corrections: boot header v2 (not v3),
  root compatible `"oneplus,instantnoodlep", "qcom,sm8250"`, a 1080x2376
  bootloader framebuffer, `serial0` = the Bluetooth UART, Adreno 650 (not
  Mali) and SDX55 over MHI firmware rows.
- Watch: upstream #808 has not changed (open, 0 comments, 0 labels).
  instantnoodlep is not on the DEVICES.md Wanted list [V: GitHub API,
  2026-11-15 ~20:10 UTC].
- Precedents in upstream DEVICES.md (status 2026-11-14) [V]:
  - OnePlus 6 (enchilada, SDM845, upstream #432): first light was a
    **RAM-only `fastboot boot`**, with nothing written. It stays RAM-only
    "until the slot-B install and its CONTRIBUTING.md §3.1 entry are
    agreed". Pixel 4 (flame) and Xiaomi Mi 8 (dipper) also merged
    RAM-only first-light probes. [I] Our M1 first light could do the
    same; then the GPT-attribute exception would gate only the persistent
    slot-B install. This is an owner decision.
  - enchilada: `boot_b` sits on LUN `sde`, not on `sda` with `userdata`.
    The guard needs `UFS_RW_LUNS` (upstream #530). That is a device.conf
    key our draft lacks; stage-0 question 10 covers it.
  - enchilada: ABL appends `root=PARTUUID=<system_a> skip_initramfs ro
    init=/init` even on `fastboot boot`. The shared init copes.
  - enchilada erased `dtbo_b`, because downstream overlays do not apply to a
    mainline DTB. This matches our [I] on dtbo.
  - enchilada: `--set-active` writes the GPT slot flags, and upstream
    treats it as a slot-flag write.
  - Pixel 4 XL (coral, SM8150): "§3.1 entry still to land". No Qualcomm
    GPT-attribute exception exists upstream yet.
  - OnePlus 13 (dodge): the `qcom-abl` boot method (a header-v4
    chainloader) was merged in upstream #111. It is not our path, but it is
    the precedent for adding a Qualcomm `BOOT_METHOD`.
  - POCO F3 (alioth, SM8250): upstream #25 was closed 2026-11-11 and can
    be reopened. It is the closest SoC sibling.
- HITL runbooks written: `docs/runbooks/STAGE-0-RUNBOOK.md`,
  `docs/runbooks/RESTORE-ASSETS.md`.

## 2026-11-15

- Support request posted upstream:
  [derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808).
  No maintainer reply yet.
- Workspace bootstrapped: device.conf draft (values marked TODO/I), stage-0
  checklist and collect script, restore runbook, BRINGUP-M1 plan skeleton.
- Mainline status of this hardware, demonstrated by the unofficial Nura
  image (kernel 7.2, Oct-Nov 2026 releases) on an IN2023 EU unit: display
  1440x3168@120 Hz, GPU, speakers/mics, Wi-Fi, Bluetooth, modem/SIM/data/SMS,
  GPS, NFC, sensors, all five cameras via libcamera. Voice calls (VoLTE) NOT
  verified. That image overwrites `super`; our model never does.
- Restore assets still to secure locally: full OTA (payload.bin) for IN2023,
  MSM Download Tool package for IN2023 (Windows, last resort, wipes+relocks).
