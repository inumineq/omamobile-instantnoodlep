<!-- SPDX-License-Identifier: MIT -->
# STORAGE-M2-PLAN: Arch root on `userdata` via UFS, storage guard active

Plan for milestone M2: "Arch root boots from `userdata` via UFS with the
storage guard active". This is the house-rule-6 gate for the storage/root
subsystem: it is a plan, not code, and it authorises nothing on the phone.
Every command that touches the device appears only inside a runbook block
below, for the owner to run by hand, with Expect, Stop and Rollback
(AGENTS.md rule 1).

- Date: 2026-11-15. Branch: `plan/storage-m2`.
- Inputs: `AGENTS.md`; `device/instantnoodlep/BRINGUP-M1-PLAN.md` (M1a
  RAM-only, M1b slot-B install); `device/instantnoodlep/device.conf`
  (draft); `device/instantnoodlep/DTS-PORT-PLAN.md` (UFS node, gates);
  `device/instantnoodlep/FIRMWARE-PLAN.md`;
  `docs/research/gpt-exception-prep.md`; `docs/research/vbmeta-avb.md`;
  `docs/RESTORE-RUNBOOK.md`; `docs/runbooks/STAGE-0-RUNBOOK.md`;
  `docs/STAGE-0.md`; upstream derekross/omarchy-mobile (pinned below).
- Milestones (wayfinder map, issue #1): M1a RAM-only first light, M1b
  persistent slot-B install, **M2 = this plan**, M3 usable desk phone,
  M4 accepted upstream, M5 radio/wireless. M2 runs only after M1b is
  complete and recorded.

## Source pins

- `U/` = derekross/omarchy-mobile at `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (main, 2026-11-15 19:28 UTC). Every `U/` citation below is at that commit.
- `T/` = torvalds/linux at `fa2933aac170dd19c6a7f0d7b81a8f537e40915c`
  (Kconfig pins for the kernel section).
- `L/`, `C/`, `P/`, `PM/`, `G/`, `R/`, `Q/` are as defined in
  `device/instantnoodlep/BRINGUP-M1-PLAN.md` §3 (linux-omarchy-mobile
  `omamobile`, community instantnoodlep DTS, community kernel, pmaports,
  OnePlus GPL kernel, private captures, Qualcomm reference ABL).

## 1. What M2 means on this device

### 1.1 Which LUN and partition `userdata` is

Unknown until stage 0. The plan carries placeholders, filled only from
the owner's captures (`captures/<date>/`, gitignored):

| Placeholder | Meaning | Filled by |
| --- | --- | --- |
| `{{USERDATA_DISK}}` | whole-disk node holding `userdata` (expected `sda`: Qualcomm puts LUN 0's table with `userdata` there [I]; enchilada had `userdata` = `sda17` [V: U/device/enchilada/NOTES.md:202]) | stage-0 D4 `by-name-root.txt` + `luns.txt` + `block-devs.txt` (`docs/runbooks/STAGE-0-RUNBOOK.md` D4; `scripts/stage0-collect.sh:39`), stage-0 Q10 (`docs/STAGE-0.md:73`) |
| `{{USERDATA_PART}}` | partition node, e.g. `sda<N>` | same |
| `{{USERDATA_SIZE}}` | bytes, from `partition-size:userdata` | stage-0 B2/C3 filtered `getvar all` |
| `{{BOOT_DISK}}` | LUN holding `boot_b`/`dtbo_b` (enchilada: `sde` [V: U/device/enchilada/NOTES.md:184,202]) | stage-0 D4 `by-name-root.txt`, `ufs-luns.txt` |
| `{{SS}}`, `{{LAST}}` | sector size, last LBA of `{{BOOT_DISK}}` | stage-0 D4 `luns.txt` + `gpt-head/tail-{{BOOT_DISK}}.bin` |
| `{{MAX_DL}}` | `max-download-size` | stage-0 B2 |

Upstream's init looks for `userdata` **only under `sda`**
(`for s in /sys/block/sda/sda*` [V: U/initramfs/init:505]), and upstream
defines `MAIN_LUN` as "the UFS LUN holding the partition table with slot B
and `userdata` (`sda`)" [V: U/docs/RELEASES.md:165], a quirk whose step 2
"changes what boots, so it gets its own runbook" [V: U/docs/RELEASES.md:247].
If stage 0 shows `userdata` on another LUN, this plan is amended first;
nothing is improvised at install time. [I]

### 1.2 The root filesystem layout (upstream's choice)

- The Arch root is a **raw ext4 image labelled `omamobile-root`**,
  zstd-compressed for transfer: `out/omamobile-rootfs-<device>-<version>-aarch64.img.zst   ext4, label omamobile-root`
  [V: U/tools/build-rootfs:4]. It carries no user, keys or per-phone data
  [V: U/tools/build-rootfs:35-40].
- It is flashed whole-partition: `fastboot flash userdata <root image>`
  [V: U/tools/install-phone:13,1098; U/docs/RELEASES.md:389]. This erases
  `userdata`; the installer says so on screen before the writes
  [V: U/tools/install-phone:1102-1104].
- On first boot the shared init grows the file system to fill the
  partition (`grow_root`: label check, `resize2fs`, skipped by
  `omamobile.noresize`) [V: U/initramfs/init:429-452; U/docs/RELEASES.md:347],
  mounts it ext4 rw, requires `/usr/lib/systemd/systemd`, runs one final
  guard pass, then `switch_root` [V: U/initramfs/init:534-576].
- Optional stricter policy: `INITRAMFS_ROOT_LABEL=omamobile-root` makes
  the init verify the label read-only before repair/mount and allow only
  `e2fsck -p` statuses 0/1 [V: U/docs/RELEASES.md:87; U/bin/omamobile:524-526,554];
  `INITRAMFS_ROOT_MODE=persistent-development` skips growth and writes a
  boot-pending marker [V: U/docs/RELEASES.md:88; U/bin/omamobile:528-532,557].
  M2 proposes `INITRAMFS_ROOT_LABEL=omamobile-root` only; the mode stays
  unset until an SSH-ready service exists to clear the marker.
- Precedent for root on `userdata`: enchilada flashed an Arch root to
  `userdata` with `fastboot flash userdata` and booted it from `boot_b`,
  guard allowlist `boot_b userdata` [V: U/device/enchilada/NOTES.md:43,46,
  111-116, 178-179]. The Pixel line does the same on `sda`
  [V: U/device/cheetah/device.conf:78-79]. flame and dipper never wrote
  `userdata`: their `ram-only` descriptors carry empty `BOOT_IMAGES` and
  `UFS_RW` [V: U/device/flame/device.conf:9-11; U/device/dipper/device.conf:8-10;
  U/docs/RELEASES.md:105-109], and their roots were the initramfs itself
  or an NFS root (`boot_nfs`, `omamobile-nfsroot` [V: U/initramfs/init:458-495]).
  That RAM-only shape is exactly M1a; M2 is the enchilada/cheetah shape.

### 1.3 What the guard allows, and how it is enforced

The guard allows **slot B's boot images and `userdata`, nothing else**:

- `UFS_RW_ALLOWED="boot_b init_boot_b vendor_boot_b vendor_kernel_boot_b dtbo_b userdata"`
  [V: U/bin/omamobile:102-105]. The descriptor check refuses any other
  name, duplicates, and a list without `userdata` [V: U/bin/omamobile:135-144];
  `UFS_RW_LUNS` may hold only disk names `sd[b-z]` [V: U/bin/omamobile:147-148].
- For instantnoodlep the M2 values are `BOOT_IMAGES="boot dtbo"` and
  `UFS_RW="boot_b dtbo_b userdata"` — `vbmeta`/`vbmeta_b` are removed per
  the vbmeta ticket's decision input 1 [V: `docs/research/vbmeta-avb.md` §"Decision
  inputs" item 1; draft at `device/instantnoodlep/device.conf:64-69` is superseded],
  plus `UFS_RW_LUNS={{BOOT_DISK}}` only if `{{BOOT_DISK}}` is not `sda`
  (enchilada's `UFS_RW_LUNS=sde` came with upstream #530 [V: U/docs/RELEASES.md:85;
  U/docs/DEVICES.md:85]).

Enforcement is layered:

1. **Descriptor validation at build time** — `bin/omamobile` refuses a
   `UFS_RW` outside the six names (see above) [V: U/bin/omamobile:135-144].
2. **Pack time** — the allowlist is packed into that device's initramfs as
   `/etc/omamobile-ufs-rw`, and the LUN list as `/etc/omamobile-ufs-rw-luns`
   [V: U/bin/omamobile:589-593]. The shipped initramfs must pack exactly the
   descriptor's `UFS_RW` [V: U/docs/RELEASES.md:319].
3. **Kernel cmdline selects the boot path** — the boot image's `CMDLINE`
   is fixed at build time [V: U/bin/omamobile:911,1060]. With
   `omamobile.initramfs` on it (the M1a probes) PID 1 stays in RAM and
   mounts nothing [V: U/initramfs/init:503,580-592; U/device/enchilada/device.conf:45].
   The installed slot-B image is built without it, so `boot_arch` runs and
   hands off to Arch on `userdata` [V: U/initramfs/init:502-576]. ABL may
   append its own `root=`/`init=` args; the shared init still runs as PID 1
   [V: U/device/enchilada/NOTES.md:187-189]. `omamobile.ufs-probe` on the
   cmdline adds a read-only disk report [V: U/initramfs/init:367-394].
4. **Runtime, fail closed** — `ufs_rw_load` reads the packed file; missing,
   empty, malformed, or naming anything outside the six names leaves every
   partition read-only [V: U/initramfs/init:68-116, the name check at :91].
   The guard loop then marks every disk/partitions: on an allowlisted LUN
   (`sda` always, plus `UFS_RW_LUNS`) the whole-disk node `/dev/sdX` is
   **removed** and partitions are guarded individually by `PARTNAME`;
   allowlisted partitions stay writable; everything else gets
   `blockdev --setro` [V: U/initramfs/init:122-163, whole-disk removal :142,
   PARTNAME match :146-149, setro :156]. LUNs not named in `UFS_RW_LUNS`
   stay read-only at the disk level [V: U/initramfs/init:100-116;
   U/docs/RELEASES.md:85]. A watcher re-runs the pass for the life of PID 1
   [V: U/initramfs/init:181-187]; nothing runs mdev/udev [V: U/initramfs/init:47-48].
5. **Before `switch_root`** — one last pass plus `ufs_unguarded`: anything
   writable outside the allowlist stops the boot in the initramfs with
   nothing mounted rw [V: U/initramfs/init:553-559; ufs_unguarded :166-179].
6. **Fastboot side** — `install-phone`'s `flash()` refuses any partition
   that is not a slot-B boot image or `userdata` on `UFS_RW`
   [V: U/tools/install-phone:1073-1079], re-checks the same at :255-263,
   the bundle manifest's write list must be exactly slot-B images +
   `userdata` [V: U/tools/install-phone:410-417], and the script "has no
   code path for any other partition, no `-w`, no `--slot`, no `flashing`"
   [V: U/tools/install-phone:16-17; U/docs/RELEASES.md:389].

The guard's own doc lines: "The initramfs storage guard runs before
anything else, and its allowlist works by GPT name" [V: U/docs/RELEASES.md:10];
`initramfs/init` is the storage guard [V: U/AGENTS.md:236]; host tests in
`U/tests/storage-guard` cover pack-time refusal and runtime fail-closed
behaviour [V: U/tests/storage-guard:4-9].

## 2. Kernel needs

- **UFS host and PHY nodes** — already K2: `&ufs_mem_hc` (`ufshc@1d84000`)
  and `&ufs_mem_phy` enabled with C's supplies [V:
  `device/instantnoodlep/DTS-PORT-PLAN.md` §3.2 item 9, D4 fdtget list;
  C:884-898; generic nodes U/L `sm8250.dtsi` S:2510-2557, 2582-2606 as cited
  there].
- **Config fragment** — upstream's shared fragment pins
  `CONFIG_SCSI_UFSHCD=y`, `CONFIG_SCSI_UFSHCD_PLATFORM=y`,
  `CONFIG_BLK_INLINE_ENCRYPTION=y`, `CONFIG_SCSI_UFS_CRYPTO=y`,
  `CONFIG_EFI_PARTITION=y`, with the comment "Inline crypto stays on: the
  host driver then sets the FMP descriptor type through EL3 exactly as
  stock does" [V: U/kernel/configs/omamobile.config:72-83]. Its Exynos
  host/PHY lines (:79, :82) do not apply to SM8250.
- **What M2/K2 add over M1a's config**:
  - `CONFIG_SCSI_UFS_QCOM=y` — Qualcomm UFS host hooks; it
    `select QCOM_INLINE_CRYPTO_ENGINE if SCSI_UFS_CRYPTO`
    [V: T/drivers/ufs/host/Kconfig:57-62].
  - `CONFIG_PHY_QCOM_QMP_UFS=y` — the QMP UFS PHY [V:
    T/drivers/phy/qualcomm/Kconfig:115-121].
  - ICE: the SM8250 UFS host has an inline crypto engine, driven by
    `drivers/soc/qcom/ice.c` under `CONFIG_QCOM_INLINE_CRYPTO_ENGINE`
    [V: T/drivers/soc/qcom/Kconfig:296; T/drivers/soc/qcom/ice.c:1-11].
    Keeping `SCSI_UFS_CRYPTO=y` (upstream's choice, above) pulls it in. No
    ICE firmware file is needed [I: confirm against the L tree at port
    time; upstream's fragment needs none, U/kernel/configs/omamobile.config:72-83].
    M2 wipes `userdata`, so no Android FBE keys are ever needed; ICE stays
    on for stock parity and is unused by the ext4 root.
  - `CONFIG_EXT4_FS=y` built in — the root is ext4
    [V: U/tools/build-rootfs:4] and is grown with `resize2fs` by the init
    [V: U/initramfs/init:429-452]. Upstream relies on defconfig for ext4;
    the fragment does not pin it [V: U/kernel/configs/omamobile.config, no
    EXT4 line], so K2 pins it explicitly.
  - f2fs: upstream ships `CONFIG_F2FS_FS=m` only because the modem NV
    partitions are f2fs [V: U/kernel/configs/omamobile.config:289-291].
    Stock `userdata` on this phone is expected f2fs+fscrypt [I: stage-0
    B3/D4]. M2 does not need f2fs — `userdata` is reformatted to ext4 — but
    K1/K2 keep `F2FS_FS=m` so a stock data partition could still be mounted
    read-only if ever needed. btrfs is used nowhere upstream [V: no btrfs
    line in U/kernel/configs/omamobile.config].
  - `CONFIG_EFI_PARTITION=y` for the GPT (already pinned upstream,
    U/kernel/configs/omamobile.config:83).
- **Descriptor/initramfs deltas over M1a**: M1a shipped no allowlist file,
  so every partition was read-only [V: U/initramfs/init:72-74;
  `device/instantnoodlep/BRINGUP-M1-PLAN.md` §5.5]. M2's images pack
  `UFS_RW="boot_b dtbo_b userdata"` (+`UFS_RW_LUNS` if `{{BOOT_DISK}}` ≠
  `sda`) and `INITRAMFS_ROOT_LABEL=omamobile-root`; `device.conf` itself is
  edited only by the "Lock device.conf values" ticket, as in the M1 plan
  §5.9.

## 3. Risks

- **Wrong LUN.** Writing the wrong disk is the worst failure mode (M1 plan
  §7). Mitigations: the guard matches by `PARTNAME`, not numbers
  [V: U/initramfs/init:146-149]; fastboot writes by name; §1.1's placeholders
  come only from captures; R1/R4 below record `ro` flags and the missing
  whole-disk node as evidence. Stop on any mismatch.
- **Writing the wrong partition.** Mitigations: the installer's `flash()`
  refusal [V: U/tools/install-phone:1073-1079], the manifest write-list
  check [V: U/tools/install-phone:410-417], the dry-run comparison (R2),
  and the typed codename confirmation [V: U/tools/install-phone:1106].
  M2 writes only `boot_b`, `dtbo_b` and `userdata`. Never `_a`, `super`,
  `vbmeta*`, `devinfo`, `persist`, `efs*`, `modem*`, or any
  bootloader/radio partition — upstream's never-flash list [V:
  U/CONTRIBUTING.md:59-60] plus house rule 3.
- **Encrypted `userdata` (FBE) and what wiping it costs.** Stock Android
  encrypts `userdata` file-based; the keys live in the TEE and in no
  partition we back up. Flashing the root image destroys Android's data
  and its encryption metadata permanently — that is the point of M2, and
  the cost is accepted before the write: the stage-0 unlock already wiped
  data (C2) and gate G1 requires everything backed up off the phone
  [V: `docs/runbooks/STAGE-0-RUNBOOK.md` C2, G1 item 4]. Stock `userdata`
  is expected f2fs [I: stage-0 B3 shows `is-logical:userdata: no`, i.e. a
  physical partition; fs type from D4; enchilada precedent
  U/device/enchilada/NOTES.md:202]. After M2, booting stock slot A shows a
  factory-reset prompt — expected, not a brick; declining keeps the Arch
  root, accepting wipes it [V: `docs/RESTORE-RUNBOOK.md` Path 0 note].
- **The GPT backup copy.** The guard cannot block raw whole-disk writes:
  "writing four GPT sectors on the boot LUN ... the storage guard can't
  block" [V: U/CONTRIBUTING.md:60], and whole-disk tools open the disk
  `O_RDWR` (qbootctl, described in `docs/research/gpt-exception-prep.md` §3.2).
  So M2 runs no whole-disk tool on the phone, ever: in the booted system the
  guard removes `/dev/sda`'s whole-disk node [V: U/initramfs/init:142], and
  the only GPT write in the whole project is the M1b `SLOT_B_MARK` four
  sectors under its own CONTRIBUTING §3.1 entry, never an M2 step. qbootctl,
  `sfdisk`/`sgdisk` on the whole disk, hand `dd`, and
  `fastboot flash partition:<lun>` are not rollback tools and never run
  here [V: `docs/research/gpt-exception-prep.md` §6.2].
- **UFS write booster / provisioning: never touched.** Nothing in M2
  issues UFS or SCSI management commands — no write-booster, no
  provisioning, no LUN-descriptor or RPMB access. fastboot writes partition
  contents through the block layer; the initramfs only calls
  `blockdev --setro` on `/dev` nodes and removes whole-disk nodes
  [V: U/initramfs/init:142,156]; no mdev/udev runs [V: U/initramfs/init:47-48].
  The UFS RPMB is reachable via SCSI generic [V: U/kernel/configs/omamobile.config:202
  comment]; no M2 code path opens it. [I: verified by review of the tools
  above; no runtime probe is planned for it.]
- **Wrong allowlist** is the worst guard failure (M1 plan §7): the build
  refuses anything outside slot B + `userdata` [V: U/bin/omamobile:135-148]
  and the init fails closed [V: U/initramfs/init:68-116]; host test
  [V: U/tests/storage-guard]. Keep it that way.
- **On-phone boot-image writer looks only on `sda`** [V: U/docs/RELEASES.md:85]:
  if `{{BOOT_DISK}}` ≠ `sda` (enchilada's case), the pacman hook cannot
  update `boot_b`; updates then go through the laptop's fastboot
  (`bin/omamobile push`), recorded in NOTES. [I until §1.1 is filled]

## 3a. Amendment 2026-11-16: tethered M2 before M1b

Owner decision (2026-11-16, owner follows the recommendation): run M2
**tethered** now, and do M1b afterwards. M1b waits on the GPT-attribute
exception (#808, questions posted 2026-11-16) and AVB on `boot_b` (#10).
Tethered M2 needs neither, because it writes no slot-B image and no GPT
attribute.

What changes against sections 1-4:

- **Boot path:** every boot is a RAM-only `fastboot boot` from the laptop
  (proven by M1a with K1 and K2, NOTES 2026-11-16). The image is the M1a
  builder's output with two differences:
  - the cmdline has no `omamobile.initramfs`, so `boot_arch` hands off to
    Arch on `userdata`;
  - the packed allowlist is `/etc/omamobile-ufs-rw` = `userdata` and
    nothing else.

  `UFS_RW_LUNS` stays empty: `userdata` is `sda23` on `sda`, the always
  allowlisted main LUN [V: captures by-name-root; U/initramfs/init:100-116].
  The DTB keeps the overlay sink and `oplus,*` selectors (PR #44).
- **One write, owner-gated:** `fastboot flash userdata <rootfs image>`
  from ABL fastboot. There is no `boot_b`/`dtbo_b` flash, no
  `--set-active` and no mark. G0's M1b/GPT items are waived for this
  variant only; the restore-asset item stays (MSM package R5).
- **Stock after the write:** slot A still boots stock if the phone starts
  without the laptop. Its `/data` entry is f2fs with `formattable`
  [V: stock `/vendor/etc/fstab.qcom`]. [I] AOSP `fs_mgr` formats a
  `formattable` partition only when it looks wiped (no ext4/f2fs
  superblock). Our root is ext4, so stock should stop at recovery's
  "Cannot load Android system" instead of formatting it. **Never choose
  "Factory data reset" there**: that reformats `userdata` and erases the
  Arch root. Choose "Reboot"/power off and boot tethered. Check on the
  first stock boot after T3, if one happens.
- **Way back to Android:** recovery "Factory data reset" (stock on slot A
  reformats `userdata` as f2fs). Nothing else changed.

### Tethered runbook (T)

Agent-run steps are non-writing (AGENTS rule 1); T3 is the owner's write.

**T0 — offline builds (laptop, agent).** The rootfs image comes from
upstream's contributor flow (`tools/fetch-published`, `build-packages
--local instantnoodlep`, `build-rootfs --local instantnoodlep`) with the
K2 kernel's modules. The tethered boot image comes from
`tools/build-instantnoodlep-probe` in a `--root userdata` mode (to be
added; plan item above). Expect: the rootfs `.img.zst` + `.sha256` +
MANIFEST, a boot image whose read-back cmdline lacks
`omamobile.initramfs` and whose initramfs holds exactly `userdata` in
`/etc/omamobile-ufs-rw`. Stop: anything else in the allowlist; build
failures. Rollback: n/a.

**T1 — preflight (phone, agent, read-only).** `adb reboot bootloader`;
`fastboot getvar all`: `current-slot:a`, `unlocked:yes`,
`partition-size:userdata` equal to the stage-0 value,
`max-download-size`. Stop: anything else. Rollback: `fastboot reboot`.

**T2 — RAM test boot of the tethered image *before* the write (agent).**
With `userdata` still f2fs, the init finds no `omamobile-root` and must
stop in the initramfs without mounting anything rw. That proves the
guard path on this phone before the write exists. Expect: SSH up, `dmesg`
shows the allowlist `userdata` loaded, `/sys/block/sda/sda23/ro` = 0,
every other partition `ro=1`, and the init's "no root" message. Stop: any
other partition writable; any mount of `sda23`. Rollback: `reboot -f`.

**T3 — the write (owner, gated).**

```sh
unzstd -k out/<rootfs>.img.zst
sha256sum -c out/<rootfs>.img.zst.sha256
fastboot getvar current-slot          # a
fastboot flash userdata out/<rootfs>.img
```

- Expect: `Sending sparse 'userdata' n/m ... OKAY`, `Writing 'userdata'
  OKAY` for every chunk.
- Stop: any `FAILED`. Stay in fastboot. Slot A is untouched.
- Rollback: the way back above (factory reset from stock recovery).

**T4 — first tethered boot (agent).** `fastboot boot <tethered image>`.
Expect: the init grows the file system, logs `omamobile: arch: switching
to Arch Linux on /dev/sda23`, and systemd starts. The phone's own
first-boot flow follows per upstream. Stop: the init stays in the
initramfs (read its message over the ACM console/SSH), or a guard
violation. Rollback: `reboot -f`, or Power+Vol Up; stock slot A starts,
see "Stock after the write".

**T5 — record.** NOTES entry with the image hashes, the first-boot log
lines and the read-only state of every non-allowlisted partition.

## 4. Gated runbook

Offline first (G0-G4, laptop only, no phone), then owner gates (R1-R6,
every one after M1b is complete and recorded). Any step that writes has a
dry-run step before it (R2 before R3). The owner runs every phone step and
pastes redacted output back (house rule 1; `docs/runbooks/STAGE-0-RUNBOOK.md`
§6 says what may be pasted — no serials, IMEI, MACs, no raw `.bin`).

Never in any step: a write to `super` or any `_a` partition, `vbmeta*`,
`devinfo`, `persist`, `efs*`, `modem*`, bootloader or radio partitions;
no `fastboot erase`, no `-w`, no `--slot`, no `flashing`, no whole-disk
tool, no hand `dd`. The only M2 writes are `flash boot_b`, `flash dtbo_b`,
`flash userdata`.

### Offline gates (G)

**G0 — entry gate (review, no commands).** All true before G1: M1b
complete per its own plan, with slot flags before/after and the
`SLOT_B_MARK` record; the ticket "Slot-B bootable marking on Qualcomm:
the named GPT-attribute exception" decided and recorded, because R3's
`--set-active=b` (when R1 shows `current-slot: a`) and the `--set-active=a`
way back are slot-flag writes that only that decision can allow; stage-0 ticket resolved and #808 posted; restore
assets resolved (OTA + MSM on disk, `docs/runbooks/RESTORE-ASSETS.md`);
`captures/<date>/` holds D4's `by-name-root.txt`, `luns.txt`,
`ufs-luns.txt`, `gpt-head/tail-sd?.bin`, `block-devs.txt` and the filtered
`getvar-all-unlocked.txt`.
- Expect: every item present and reviewed.
- Stop: any item missing, M1b unresolved, or the slot-B marking ticket
  undecided or decided against a slot-flag write.
- Rollback: n/a (nothing done).

**G1 — fill the placeholders from the captures (laptop, reads files only).**

```sh
D=<stage-0 date>
grep -E 'userdata|boot_[ab]|dtbo_[ab]|vbmeta' "captures/$D/by-name-root.txt"
cat "captures/$D/luns.txt" "captures/$D/ufs-luns.txt"
cat "captures/$D/block-devs.txt"
grep -E 'partition-size:(userdata|boot_b|dtbo_b)|max-download-size|current-slot|unlocked' "captures/$D/getvar-all-unlocked.txt"
```

- Expect: `userdata` maps to `/dev/block/{{USERDATA_DISK}}{{N}}` with size
  `{{USERDATA_SIZE}}`; `boot_b`/`dtbo_b` map to `{{BOOT_DISK}}`; sector size
  and last LBA computable from `luns.txt` (`/sys/block/sdX/size` is in
  512-byte units [V: `docs/runbooks/STAGE-0-RUNBOOK.md` D4 Expect]).
- Stop: `userdata` is not on `sda` — `boot_arch` scans only `sda`
  [V: U/initramfs/init:505]; amend this plan (MAIN_LUN, U/docs/RELEASES.md:165,247)
  with the coordinator before anything else. Any capture missing.
- Rollback: n/a.

**G2 — build and verify the root image (laptop/container, no phone).**

```sh
bash tools/build-rootfs --device instantnoodlep --version <ver>   # in the upstream-style checkout
ls -l out/omamobile-rootfs-instantnoodlep-<ver>-aarch64.img.zst*
zstd -q -d --sparse -f out/omamobile-rootfs-instantnoodlep-<ver>-aarch64.img.zst -o "$SCRATCH/rootfs.img"
dumpe2fs -h "$SCRATCH/rootfs.img" | grep -E 'Filesystem volume name|Block count|Block size'
stat -c %s "$SCRATCH/rootfs.img"    # must be <= {{USERDATA_SIZE}} from G1
sha256sum out/omamobile-rootfs-instantnoodlep-<ver>-aarch64.img.zst | tee "$SCRATCH/SHA256SUMS"
```

- Expect: volume name `omamobile-root` [V: U/tools/build-rootfs:4]; image
  fits `{{USERDATA_SIZE}}`; sha256 recorded; the MANIFEST names the device.
- Stop: label missing, image larger than the partition, or the build
  fails. Keep the raw image in `$SCRATCH` (private), never in the repo.
- Rollback: delete `$SCRATCH` and the `out/` files; fix the build inputs.

**G3 — descriptor values, guard packing, boot images (laptop).**

```sh
# device.conf edit happens in its own ticket; here we verify the values:
#   BOOT_IMAGES="boot dtbo"   UFS_RW="boot_b dtbo_b userdata"
#   UFS_RW_LUNS={{BOOT_DISK}} only if {{BOOT_DISK}} != sda
#   INITRAMFS_ROOT_LABEL=omamobile-root
DEVICE=instantnoodlep bin/omamobile initramfs-config "$SCRATCH/etc"
cat "$SCRATCH/etc/omamobile-ufs-rw" "$SCRATCH/etc/omamobile-ufs-rw-luns" "$SCRATCH/etc/omamobile-root-label" 2>&1
bash tests/storage-guard
DEVICE=instantnoodlep bin/omamobile images    # boot.img / dtbo.img carrying the M2 initramfs
sha256sum out/boot.img out/dtbo.img | tee "$SCRATCH/BOOT-SHA256SUMS"
```

- Expect: `omamobile-ufs-rw` is exactly `boot_b dtbo_b userdata`; the luns
  file exists only when `{{BOOT_DISK}}` ≠ `sda` and holds only that disk;
  `omamobile-root-label` is `omamobile-root`; `tests/storage-guard` passes;
  the builder refuses any `UFS_RW` outside slot B + `userdata`
  [V: U/bin/omamobile:135-148,589-593].
- Stop: any mismatch, any builder refusal, any extra file packed.
- Rollback: delete the outputs; the descriptor is unchanged until its
  ticket resolves.

**G4 — write-list audit (laptop, reads this plan).**

```sh
grep -nE 'flash |erase|set-active|--slot|-w |flashing|dd ' device/instantnoodlep/STORAGE-M2-PLAN.md
grep -nE '\b(super|devinfo|persist|efs[a-z_*]*|modem[a-z_*]*|vbmeta|bootloader|radio|abl|xbl|tz)_?[ab]?\b' device/instantnoodlep/STORAGE-M2-PLAN.md
```

- Expect: the first grep shows write commands naming only `boot_b`,
  `dtbo_b`, `userdata` (plus read-only `getvar`/`dd if=` reads in R steps,
  which have no `of=` on the phone); the second grep hits only the
  never-write list and citations, never a command.
- Stop: any write command naming anything else. Fix the plan first.
- Rollback: n/a.

### Owner gates (R) — all after M1b; phone steps run by the owner

**R1 — preflight, read-only.**

```sh
adb reboot bootloader
fastboot devices                                   # exactly one line; the serial stays private
fastboot -s <serial> getvar all 2>&1 | tee "captures/$D/m2-getvar-all.txt" | grep -E '^(product|current-slot|unlocked|max-download-size)|slot-(successful|unbootable|retry-count)|partition-size:(boot_b|dtbo_b|userdata)'
```

- Expect: `product` matches the descriptor's phone; `unlocked: yes`;
  `current-slot: b` (post-M1b) with `slot-successful:b: yes` if the mark
  ran; sizes equal to G1's captures.
- Stop: locked, product mismatch, more than one device, slot flags
  different from the M1b record, or no `partition-size:userdata`.
- Rollback: `fastboot -s <serial> reboot` — boots the active slot; nothing
  was written.

**R2 — dry run (read-only on the phone; writes nothing). This is the
mandatory dry run before R3.**

```sh
bash tools/install-phone --dry-run --device instantnoodlep \
  --rootfs out/omamobile-rootfs-instantnoodlep-<ver>-aarch64.img.zst 2>&1 | tee "captures/$D/m2-dry-run.txt"
```

- Expect: after the read-only `getvar` reads and the image-copy
  preparation, it prints `would run:` lines for exactly `flash boot_b`,
  `flash dtbo_b`, `flash userdata`, then `--set-active=b` only if R1 showed
  `current-slot: a`, then `reboot` [V: U/tools/install-phone:50-57,1096-1100,1112-1116];
  and the printed plan matches G4's audit.
- Stop: any `would run:` line naming another partition, or containing
  `erase`, `-w`, `--slot`, `flashing`, or an unsuffixed partition name.
  Paste the output; do not proceed.
- Rollback: n/a — the dry run writes nothing [V: U/tools/install-phone:1112-1116].

**R3 — the write (only after R2's output matches).**

```sh
bash tools/install-phone --device instantnoodlep \
  --rootfs out/omamobile-rootfs-instantnoodlep-<ver>-aarch64.img.zst
# answer the prompts, read the printed plan, then type: instantnoodlep
```

- Expect: the notice that `userdata` will be ERASED [V:
  U/tools/install-phone:1102-1104]; each `fastboot flash ... OKAY`; the
  typed-codename gate [V: U/tools/install-phone:1106]; "Done. The phone
  boots slot B".
- Stop: any `FAILED (remote: ...)`. The phone stays in fastboot and slot A
  is untouched [V: U/tools/install-phone:1086]. Paste the output; do not
  retry blindly.
- Rollback: slot A still holds stock. Boot it with
  `fastboot -s <serial> reboot` if slot A is still active, else
  `fastboot -s <serial> --set-active=a` — itself a slot-flag write, run
  only as the way back, with both slots' flags recorded before and after
  [V: `docs/research/gpt-exception-prep.md` §4; `docs/RESTORE-RUNBOOK.md`
  Path 0]. Stock then boots and may ask for a factory reset because
  `userdata` changed — expected [V: `docs/RESTORE-RUNBOOK.md` Path 0 note].
  A partially flashed `userdata` is not bootable as Arch; R4 decides.

**R4 — first boot of slot B; guard evidence over SSH.**

```sh
# watch the console: expect "omamobile: arch: switching to Arch Linux on /dev/{{USERDATA_PART}}"
ssh root@172.16.42.1
for d in /sys/block/sd* /sys/block/sd*/sd*; do echo "$d ro=$(cat $d/ro) $(sed -n 's/^PARTNAME=//p' $d/uevent 2>/dev/null)"; done
ls -l /dev/sda /dev/{{BOOT_DISK}} 2>&1
findmnt -no FSTYPE,OPTIONS / ; lsblk -o NAME,RO,SIZE,FSTYPE,LABEL
```

- Expect: console shows the handover [V: U/initramfs/init:567,576]; every
  partition `ro=1` except `userdata` (and `boot_b`/`dtbo_b` on
  `{{BOOT_DISK}}`) [V: U/initramfs/init:146-156]; `/dev/sda` (and
  `/dev/{{BOOT_DISK}}`) absent [V: U/initramfs/init:142]; `/` is ext4 rw
  from `/dev/{{USERDATA_PART}}`, grown to `{{USERDATA_SIZE}}`
  [V: U/initramfs/init:429-452,534].
- Stop: console shows "arch: userdata is read-only" or "writable outside
  the allowlist" — the init stays in the initramfs and mounts nothing rw
  [V: U/initramfs/init:509,553-559]. Record `dmesg`, paste it.
- Rollback: `reboot -f` over SSH; follow the M1b plan's fallback (slot
  retries, then slot A stock). Nothing else was writable.

**R5 — post-boot records (read-only).**

```sh
ssh root@172.16.42.1 'uname -r; cat /proc/cmdline; dmesg | grep -iE "ufs|sd[a-z]" | tail -30'
bash tools/nv-backup "captures/$D/m2-nv-backup"     # read-only radio backup
bash tools/nv-backup --check "captures/$D/radio"   # compare with stage 0 [V: U/docs/INSTALL.md:194-198]
adb reboot bootloader
fastboot -s <serial> getvar all 2>&1 | grep -E 'current-slot|slot-(successful|unbootable|retry-count)'
```

- Expect: no UFS errors in dmesg; `nv-backup --check` prints SAME for every
  stage-0 radio partition; slot flags equal to R1 except the expected
  changes from the writes.
- Stop: any UFS error, any nv-backup difference, unexpected slot flags.
  Record and stop; ask on #808 before any further boot.
- Rollback: n/a (read-only).

**R6 — the way back (owner decision, recorded).**

```sh
# from Arch: reboot; or from fastboot: fastboot -s <serial> --set-active=a   (slot-flag write, flags recorded)
adb reboot bootloader && fastboot -s <serial> getvar current-slot
```

- Expect: slot A boots stock and shows the factory-reset prompt because
  `userdata` holds the Arch root [V: `docs/RESTORE-RUNBOOK.md` Path 0
  note]. Declining keeps the Arch root; accepting wipes it. Record which.
- Stop: stock does not boot → `docs/RESTORE-RUNBOOK.md` Path 1/2, the
  owner's own recovery, recorded if used.
- Rollback: this step is the way back.

## 5. Open [I]s and what answers each

| ID | Open question | Answered by |
| --- | --- | --- |
| I1 | `{{USERDATA_DISK}}`/`{{USERDATA_PART}}` on this unit (expected `sda`) | stage-0 D4 `by-name-root.txt`/`luns.txt`/`block-devs.txt`; Q10 (`docs/STAGE-0.md:73`) → G1 |
| I2 | `{{BOOT_DISK}}`, hence whether `UFS_RW_LUNS` is needed | stage-0 D4 `by-name-root.txt`, `ufs-luns.txt` → G1/G3 |
| I3 | `{{USERDATA_SIZE}}`, `{{SS}}`, `{{LAST}}`, `{{MAX_DL}}` | stage-0 B2/C3 `getvar` + D4 `luns.txt` → G1 |
| I4 | stock `userdata` fs type and FBE state (cost of the wipe) | stage-0 B3 `is-logical:userdata: no` + D4; enchilada precedent f2fs [V: U/device/enchilada/NOTES.md:202] |
| I5 | `userdata` on `sda` as `boot_arch` assumes, or a MAIN_LUN plan amendment | I1; U/initramfs/init:505; U/docs/RELEASES.md:165,247 |
| I6 | ABL's appended cmdline on a persistent slot-B boot (`root=`, `skip_initramfs`) | M1a R3 `/proc/cmdline` record; M1b first boot; enchilada precedent [V: U/device/enchilada/NOTES.md:187-189] |
| I7 | ICE present and driven with `SCSI_UFS_QCOM`+`SCSI_UFS_CRYPTO`, no firmware | K2 build + M1a R4 dmesg (no UFS errors) + L-tree audit at port time |
| I8 | stock `vbmeta_b` descriptor type (direct hash vs chain) — decides the `boot_b` footer, not any `userdata` write | RESTORE-ASSETS R4 `avbtool info_image` [V: `docs/research/vbmeta-avb.md` §5] |
| I9 | which LUNs hold `abl_*`/`xbl_*` (the EDL risk if a GPT copy breaks) | stage-0 D4 `ufs-luns.txt`, `bootloader-ab.txt` (`docs/research/gpt-exception-prep.md` R2b) |
| I10 | whether the on-phone boot-update hook can reach `boot_b` (it looks only on `sda`) | I2; U/docs/RELEASES.md:85 — else updates via laptop fastboot |
