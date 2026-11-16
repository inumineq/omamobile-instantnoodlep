<!-- SPDX-License-Identifier: MIT -->
# Stage-0 runbook: stock capture on the owner's IN2023

Ticket: "Stage-0 capture on the owner's phone (IN2023)". This runbook turns
`docs/STAGE-0.md` into steps the owner runs by hand (AGENTS.md rule 1).
Every step has a command block, **Expect**, **Stop** and **Rollback**. Paste
the output (redacted, see §6) back into the coordinator chat after each
phase. Do not batch the phases.

What this runbook writes to the phone: **one partition-level write**, the
unlock in phase C, which wipes user data and changes the lock state. The
rest are ordinary Android data writes to `userdata` (Oxygen Updater and
DRM Info from Google Play, the OTA download in restore-assets R2, setup in
C3, `adb install`/`adb push`, Magisk's `/data/adb`), and the unlock wipes
those anyway. Nothing is ever flashed. `fastboot boot` in phase D loads an
image into RAM and does not write it to flash. The one exception is
outside this runbook's tooling: if the A3b decision tree calls for it and
the owner decides so, the **stock updater** installs an OTA, which writes
the inactive slot like any OTA.

Sources marked "scouting §n" are sections of
`docs/research/restore-assets-scouting.md`.

Ground rules for the whole runbook:

- Run everything from the repo root (`scripts/stage0-collect.sh` writes to
  `captures/<date>/` relative to the current directory). `captures/` is
  gitignored. Never `git add -f` it.
- **Never type `fastboot flash`, `fastboot erase`, `fastboot set_active`,
  `fastboot --set-active` or `fastboot flashing lock`/`oem lock` during
  stage 0.** None of them appear below. If a guide, a forum post or a tool
  suggests one, stop and ask.
- **In the Magisk app, touch nothing under Install or Uninstall except
  "Select and Patch a File".** "Direct Install" writes the current slot's
  boot partition. "Install to Inactive Slot (After OTA)" writes `boot_b`.
  "Uninstall Magisk" → "Restore Images" / "Complete Uninstall" writes the
  current slot's boot partition. Under temporary root all of them are live.
- Captures contain serials, the IMEI and MAC addresses. Never paste raw
  `getprop`, `getvar all`, `dmesg` or the device tree into GitHub. §6 says
  what to paste.

```sh
D=$(date +%Y-%m-%d); export D; mkdir -p "captures/$D"
```

---

## Phase L: laptop preflight (no phone)

### L1. Tools present

```sh
for t in adb fastboot dtc sha256sum unzip python3; do printf '%-12s ' "$t"; command -v "$t" || echo MISSING; done
adb version | head -1; fastboot --version | head -1
git check-ignore -v captures/test && echo "captures/ is ignored"
```

- **Expect:** every tool resolves; adb/fastboot from platform-tools 35 or
  newer [I: any recent android-tools works]; the last line prints
  `captures/ is ignored`.
- **Stop:** `captures/` is not ignored. Fix `.gitignore` before anything
  else.
- **Rollback:** n/a (laptop only).
- Notes: on Arch, `sudo pacman -S android-tools dtc` [I: package names]. The
  offline image tools (`payload-dumper-go`, `unpack_bootimg.py`,
  `avbtool.py`, `mkdtboimg.py`) are covered in
  `docs/runbooks/RESTORE-ASSETS.md` step R4.

### L2. Restore assets gate

The ticket "Secure restore assets on local disk (full OTA + MSM package for
IN2023)" must be **resolved** before phase C. Phases A and B are read-only
and may run first; in fact R1 needs the build id from phase A.
**R2 follows the A3b decision.** Where A3b moves the slot, the full zip of
the final build is downloaded first (it is the input of the move), and
R2's `post-build` check is made against the A3 rerun that shows `_a`. The
zip must be on the laptop before phase C: the unlock wipes the phone's
copy.

---

## Phase A: stock Android, still locked (read-only, adb)

### A1. Connect

On the phone: Settings → About device → tap the build number 7 times →
Developer options → USB debugging ON. Plug in and accept the RSA prompt.

```sh
adb devices -l
```

- **Expect:** exactly one line ending in `device` (not `unauthorized`).
- **Stop:** `unauthorized` or no device. Re-plug, accept the prompt, check
  the cable or USB port.
- **Rollback:** USB debugging can be switched off again; nothing changed.

### A2. Automatic capture

```sh
sh scripts/stage0-collect.sh
ls -la "captures/$D"
```

- **Expect:** `getprop-all.txt`, `getprop-interesting.txt`, `by-name.txt`,
  `bootdevice.txt`, `block-devs.txt`, `cpuinfo.txt`, `meminfo.txt` (plus
  `cmdline.txt` and `modules.txt`, which may be empty). The script itself
  says it writes nothing to the phone.
- [I] `by-name.txt` and `cmdline.txt` may say `Permission denied` on a
  locked, unrooted phone (SELinux). **This is not a stop:** phase D repeats
  both with root.
- **Stop:** the script exits non-zero before `getprop-all.txt` exists.
- **Rollback:** n/a.

### A3. Build identity and boot properties

```sh
adb shell getprop | grep -E 'ro\.build\.(fingerprint|display\.id|date\.utc|version\.(release|security_patch|incremental|ota))|ro\.product\.(device|name|model)|ro\.boot\.(slot_suffix|dtbo_idx|ddr_type|verifiedbootstate|vbmeta\.device_state|flash\.locked|hardware\.revision|project_name|prjname)' \
  | tee "captures/$D/build-boot-props.txt"
```

- **Expect:** `ro.product.model` = `IN2023`; a `ro.build.fingerprint` with
  an EEA/EU product name [I: e.g. `OnePlus8Pro_EEA`]; `ro.boot.slot_suffix`
  = `_a`; `ro.boot.flash.locked` = `1`; `ro.boot.verifiedbootstate` =
  `green`. `ro.boot.dtbo_idx` is present if ABL applies a dtbo (stage-0
  question 4). `ro.boot.ddr_type` is `0` (DDR4) or `1` (DDR5) [I: present
  on this build]; restore needs it before any `xbl*` image is touched.
- **Stop, important:** `ro.boot.slot_suffix` is `_b`. A/B OTAs alternate
  slots, so on a phone that has taken several updates this is roughly a
  coin flip, not an edge case. Stock is then running from slot B, the slot
  we would write. Report it and go to the A3b decision tree; do nothing
  else. Writing `_a` partitions to swap roles is **not** an option
  (AGENTS.md rule 3).
- **Stop:** model is not `IN2023`.
- **Rollback:** n/a.
- These lines contain **no** serial. Paste them back as they are, with
  `ro.build.fingerprint`. R1 needs it to pick the exact OTA.

### A3b. Slot and build decision (owner decides)

The device is end-of-life: no further OTAs will come [V scouting §1.1].
The "final build" is the newest EEA build that Oxygen Updater offers for
IN2023 [I: most likely `IN2023_13.1.0.587(EX01)` or `.586`, scouting
§1.1]. Any successful A/B install, full or incremental, local or over the
air, writes the **inactive** slot and makes it active [V AOSP A/B, scouting
§2]. Decide from A3's slot and build:

- **(a) `_a` and on the final build:** nothing moves. Restore-assets R2
  downloads the full OTA of the running build. Go on to A4.
- **(b) `_a` on an older build:** two options.
  - (b1) Find the full OTA of the running, older build and keep stock as it
    is. Preferred, because nothing is written. [I] Oxygen Updater may offer
    only the newest build.
  - (b2) Let the stock updater install the update (it writes `_b` and moves
    stock to B), then local-install the **same** final full zip (it writes
    `_a` and moves stock back to A). The second install is a same-version
    install, [I] as in (c). If it is refused, stock is left on `_b` with no
    stock route back to A; that is why (b1) comes first.
- **(c) `_b`:** local-install the full zip of the final build. It writes
  `_a` and moves stock to A. If `_b` runs an older build, this is a normal
  upgrade. If `_b` already runs the final build, it is a same-version
  install. [V 2026-11-16, owner's IN2023] The Oplus updater accepts it
  (scouting §2).

Both (b2) and (c) are writes by the stock updater, not by this runbook, so
each one is the owner's decision. For either, download the final build's
full zip first (restore-assets R2) and verify the laptop copy (R3) before
installing it. Local install on OxygenOS 13 is hidden until Developer
options are on (A1 did that), or via the OnePlus Local Update APK [V
Oxygen Updater article 367 for the 10T; I for the 8 Pro, scouting §2].
Path [I]: Settings → About device → version card → ⋮ → Local install; it
needs about 5 GB free. Never use a "rollback" package: those are special
builds that wipe data [I, scouting §2].

After an install has booted, keep the old A3 output and rerun A3:

```sh
mv "captures/$D/build-boot-props.txt" "captures/$D/build-boot-props-before-move.txt"
# then run the A3 command again
```

- **Expect:** case (a): no install. Cases (b2)/(c): after the install and
  its reboot, the A3 rerun shows `ro.boot.slot_suffix` = `_a` and the
  final build. Paste the rerun.
- **Stop:** "Local install" cannot be made visible, the updater refuses
  the zip, or the rerun still shows `_b`. Report it and do nothing else.
  Writing `_a` partitions with fastboot stays off the table (AGENTS.md
  rule 3). The owner decides whether to go on with stock on `_b`.
- **Rollback:** none from this runbook. [I] An A/B update that fails to
  boot falls back to the old slot by itself, because the new slot is only
  marked successful after a good boot (scouting §2).

### A4. Wi-Fi silicon (read-only, may need root)

```sh
adb shell 'for d in /sys/bus/pci/devices/*; do echo "$d $(cat $d/vendor) $(cat $d/device)"; done' | tee "captures/$D/pci.txt"
```

- **Expect:** a device `0x17cb 0x1101` (QCA6390) [I]. A permission error is
  fine; D4 repeats it with root.
- **Stop / Rollback:** none / n/a.

### A5. Widevine baseline (read-only; gate G1)

On the phone: install DRM Info from Google Play ([I] any app that reads
the Widevine `MediaDrm` properties is an equivalent), open it and read
Widevine → **Security level**. Record what it shows:

```sh
printf 'widevine-security-level: %s\n' 'L1' | tee "captures/$D/widevine.txt"   # replace L1 with the level DRM Info shows
```

- **Expect:** `L1` on a locked stock phone [I]. Reports for unlocked
  Qualcomm OnePlus phones are mixed; plan for `L3` after the unlock [I,
  scouting §4]. This value is the baseline for that comparison.
- **Stop:** no level could be read. Gate G1 waits until one is recorded.
- **Rollback:** uninstall the app.
- Paste the security level only. Do not paste ID fields the app may show.

---

## Phase B: bootloader fastboot, still locked (read-only)

### B1. Reboot to the bootloader

```sh
adb reboot bootloader
fastboot devices
```

- **Expect:** the fastboot screen on the phone; one serial line from
  `fastboot devices` (private, do not paste it).
- **Stop:** no device after 30 s. Check the cable. On Linux, check the udev
  rules from android-tools / `android-udev`.
- **Rollback:** `fastboot reboot`, or hold Power for about 10 s; stock boots.

### B2. getvar all

```sh
fastboot getvar all 2>&1 | tee "captures/$D/getvar-all.txt"
grep -E 'current-slot|slot-(successful|unbootable|retry-count)|unlocked|secure|has-slot|partition-type:(boot|dtbo|vbmeta|init_boot|vendor_boot)|version-bootloader|max-download-size' "captures/$D/getvar-all.txt"
```

- **Expect:** `current-slot: a`; `unlocked: no`; for slot a
  `slot-successful: yes`, `slot-unbootable: no` and a retry count. Slot b
  values are recorded as they are (they are the baseline for the ticket
  "Slot-B bootable marking on Qualcomm: the named GPT-attribute
  exception"). `has-slot:boot: yes`; `partition-type:` lines for
  `boot_a/_b`, `dtbo_a/_b` and `vbmeta_a/_b`; no `init_boot`/`vendor_boot`
  lines. [V 2026-11-16] This ABL prints `has-slot` only for `boot`,
  `modem` and `system` (`no`), not for `dtbo`/`vbmeta`; the `_a`/`_b`
  `partition-type` lines are what show those are slotted.
  `version-bootloader` comes back empty on this ABL [V 2026-11-16].
- **Stop:** `current-slot: b` (same reason as A3; see the A3b decision tree); `unlocked: yes` when you
  never unlocked; `getvar all` fails.
- **Rollback:** n/a (read-only).
- Paste back the **filtered `grep` output only**. `getvar all` itself
  contains the serial.

### B3. fastbootd entry check (read-only; proves restore path 1 is reachable)

```sh
fastboot reboot fastboot
fastboot getvar is-userspace
fastboot getvar all 2>&1 | tee "captures/$D/getvar-all-fastbootd.txt" | grep -E 'is-logical|super-partition-name|partition-size:(super|userdata)'
fastboot reboot
```

- **Expect:** the phone shows fastbootd (a recovery-style screen);
  `is-userspace: yes`; `is-logical:system_a: yes` and friends (dynamic
  partitions inside `super`); `is-logical:userdata: no`. The last command
  boots stock. [V 2026-11-16] fastbootd prints no `partition-size:super`
  line; that is fine.
- **Note:** `is-logical:<name>_a-cow: yes` lines are libsnapshot COW
  partitions [V: AOSP `fs_mgr/libsnapshot/snapshot.cpp` `GetCowName`
  appends `-cow`]. They mean this is a Virtual A/B device with an update
  snapshot still present, which is expected right after an A3b install.
  Not a stop here; B4 checks that the merge has finished.
- **Stop:** `fastboot reboot fastboot` is rejected or the phone never shows
  fastbootd. Then restore path 1 is unproven: report it before phase C.
- **Rollback:** if the phone sits in fastbootd: choose **only** "Reboot
  system now" with the volume keys and Power, or run `fastboot reboot`.
  Never choose a wipe or format entry from that menu.

### B4. Snapshot merge finished (read-only; required before phase C)

After any OTA or local install (A3b), Virtual A/B merges the update
snapshot in the background after the first good boot. Until it finishes,
the active slot still reads through the snapshot. Leave the phone booted
in Android (on the charger, 15-30 min), then:

```sh
adb reboot fastboot
fastboot getvar snapshot-update-status
fastboot reboot
```

- **Expect:** `snapshot-update-status: none`. [V: AOSP
  `fastboot/device/variables.cpp` `GetSnapshotUpdateStatus` returns
  `snapshotted`, `merging` or `none` from the boot control HAL.]
- **Stop:** `merging` or `snapshotted`: boot stock (`fastboot reboot`),
  wait 30 min more and repeat. Still not `none` after a few hours: report
  it and do nothing else. **Never** run `fastboot snapshot-update cancel`
  or `fastboot snapshot-update merge`, and pick nothing from the fastbootd
  menu except "Reboot system now".
- **Why it gates C2:** AOSP fastbootd refuses to erase or flash
  `userdata`, `metadata` or `misc` while the status is `snapshotted` or
  `merging` [V: AOSP `fastboot/device/commands.cpp`
  `IsProtectedPartitionDuringMerge`], because wiping them mid-merge can
  leave the active slot unbootable. `fastboot oem unlock` runs in ABL, not
  fastbootd, and wipes `userdata`; whether this ABL applies the same guard
  is [I]. Do not rely on it.
- **Rollback:** `fastboot reboot`. [I] A reboot during a merge is safe;
  libsnapshot resumes the merge on the next boot.

### Gate G1 (owner decides, before phase C)

All must be true:

1. The restore-assets ticket is resolved: the OTA matches A3's fingerprint
   exactly (or passes the R2 incremental-and-date fallback) and R3 passes;
   the zip is on the laptop, not only on the phone; the MSM package is on
   disk.
2. Phases A and B are pasted back, and the coordinator has confirmed
   `current-slot: a`, `IN2023` and which A3b case applied.
3. The Widevine security level is recorded (A5).
4. B4 shows `snapshot-update-status: none`, checked after the last
   install and on the same day as C2.
5. Everything on the phone is backed up off the phone (photos, 2FA apps,
   Signal/WhatsApp backups, eSIM if any). **The unlock wipes everything.**
6. [I] The owner accepts the side effects of an unlocked bootloader on
   stock Android: hardware-backed Play Integrity fails, so banking and
   ID apps (MitID, MobilePay) may refuse to run. Widevine may drop to L3
   (scouting §4). The orange-state warning shows at every boot.

---

## Phase C: unlock (first and only write in stage 0)

### C1. Allow OEM unlocking

Settings → System → Developer options → **OEM unlocking** ON (the phone
may need to be online once).

- **Expect:** the toggle stays on.
- **Stop:** the toggle is greyed out. Report it; carrier-locked or
  region-locked units need a different path.
- **Rollback:** toggle it off again.

### C2. Unlock

```sh
adb reboot bootloader
fastboot oem unlock
```

- **Expect:** the phone shows an unlock confirmation screen. Select
  "UNLOCK THE BOOTLOADER" with the volume keys and confirm with Power. The
  phone wipes data and reboots into first-time setup. [V: LineageOS install
  guide for instantnoodlep uses `fastboot oem unlock`.]
- **Stop:** `FAILED (remote: ... not allowed)` means C1 did not stick: go
  back to C1. Any other error: stop and paste it.
- **Rollback:** none needed. The lock state can be reverted with
  `fastboot oem lock` **only while every partition is still stock**, which
  is true at this point; it wipes again. Do not relock later in the project
  without asking. Relocking with non-stock images can brick the phone.

### C3. Re-enable and re-capture

Do a minimal Android setup (skip accounts), then turn Developer options
and USB debugging on again as in A1.

```sh
adb reboot bootloader
fastboot getvar all 2>&1 | tee "captures/$D/getvar-all-unlocked.txt" | grep -E 'unlocked|current-slot|slot-(successful|unbootable|retry-count)'
fastboot reboot
```

- **Expect:** `unlocked: yes`; `current-slot: a`; slot flags as in B2. Any
  change is itself a finding: paste it.
- **Stop:** `current-slot` changed to `b`.
- **Rollback:** n/a.

---

## Phase D: temporary root in RAM (nothing flashed)

### D1. Stock boot.img from the verified OTA (laptop)

The boot image must come from the OTA that matches the running build
(restore-assets step R2). The offline inspection (header version, cmdline,
vbmeta chain, dtbo ids) is restore-assets step R4.

```sh
R=~/android/reference/instantnoodlep   # same R as the fetch script and restore-assets
ls -l "$R/images/boot.img"
```

- **Expect:** the file exists (extracted in R4).
- **Stop:** the OTA does not match A3's fingerprint (and fails the R2
  incremental-and-date fallback). A boot.img from
  another build may not boot and gives wrong facts.

### D2. Patch with Magisk (on the phone; patching is a file operation)

```sh
adb install "$R/tools/Magisk-v<version>.apk"   # official release from github.com/topjohnwu/Magisk
adb push "$R/images/boot.img" /sdcard/Download/
```

In the Magisk app: Install → **Select and Patch a File** → pick
`Download/boot.img`. Then:

```sh
adb shell ls /sdcard/Download/ | grep magisk_patched
adb pull /sdcard/Download/magisk_patched-<id>.img "captures/$D/"
```

- **Expect:** a `magisk_patched-<id>.img` about the size of `boot.img`.
- **Stop:** the app offers only "Direct Install" or "Install to Inactive
  Slot". Choose neither: they write `boot_a` and `boot_b`. Use only
  "Select and Patch a File" (ground rules above).
- **Rollback:** uninstall the Magisk app.

### D3. Boot it from RAM

```sh
adb reboot bootloader
fastboot boot "captures/$D/magisk_patched-<id>.img"
```

- **Expect:** `Sending 'boot.img' ... OKAY`, `Booting OKAY`; stock Android
  starts. The Magisk app then shows Magisk as installed (temporary, RAM
  only). A successful `fastboot boot` is a finding in its own right: it
  makes a RAM-only first light possible (see NOTES.md, 2026-11-15).
- **Stop:** `FAILED (remote: 'unknown command')` or similar, meaning this ABL
  refuses `fastboot boot`. **Do not fall back to `fastboot flash boot`.**
  Paste the error. Root steps then wait for a different plan.
- **Stop:** the Magisk app asks for "additional setup" and wants to
  reboot or install. Decline. That path writes the boot partition. In the
  app, touch nothing under Install or Uninstall.
- **Rollback:** a hang or bootloop writes nothing. Hold Power + Volume Up
  for about 10-30 s until it restarts; it boots stock from flash. If it
  keeps landing in fastboot: `fastboot reboot`.

### D4. Captures with root (read-only)

Approve the root prompt on the phone the first time.

```sh
adb shell su -c id
adb exec-out su -c 'cat /sys/firmware/fdt'           > "captures/$D/live.dtb"
dtc -I dtb -O dts -o "captures/$D/live.dts" "captures/$D/live.dtb" 2>"captures/$D/dtc-warnings.txt"
adb exec-out su -c 'dmesg'                            > "captures/$D/dmesg.txt"
adb exec-out su -c 'cat /proc/cmdline'                > "captures/$D/cmdline-root.txt"
adb exec-out su -c 'cat /proc/iomem'                  > "captures/$D/iomem.txt"
adb exec-out su -c 'cat /proc/interrupts'             > "captures/$D/interrupts.txt"
adb exec-out su -c 'cat /proc/modules'                > "captures/$D/modules-root.txt"
adb exec-out su -c 'ls -l /dev/block/by-name/'        > "captures/$D/by-name-root.txt"
adb exec-out su -c 'for d in /sys/block/sd?; do echo "$d size=$(cat $d/size) lbs=$(cat $d/queue/logical_block_size)"; done' > "captures/$D/luns.txt"
adb exec-out su -c 'for d in /sys/bus/pci/devices/*; do echo "$d $(cat $d/vendor) $(cat $d/device)"; done' > "captures/$D/pci-root.txt"
for l in a b c d e f; do adb exec-out su -c "dd if=/dev/block/sd$l bs=4096 count=6 2>/dev/null" > "captures/$D/gpt-head-sd$l.bin"; done
for l in a b c d e f; do adb exec-out su -c "n=\$(cat /sys/block/sd$l/size); dd if=/dev/block/sd$l bs=4096 skip=\$((n/8-6)) count=6 2>/dev/null" > "captures/$D/gpt-tail-sd$l.bin"; done
ls -la "captures/$D"
```

Radio partition backup (private: these images hold IMEI-related and
calibration data that is unique to the unit and in no OTA or MSM package
[I, scouting §3.2]). This is the first point where root exists, so it
follows the unlock; [I] the unlock does not touch these partitions
(scouting §4).

```sh
mkdir -p "captures/$D/radio"
for p in persist modemst1 modemst2 fsg fsc; do adb exec-out su -c "dd if=/dev/block/by-name/$p 2>/dev/null" > "captures/$D/radio/$p.img"; done
for p in persist modemst1 modemst2 fsg fsc; do echo "$p $(adb exec-out su -c "blockdev --getsize64 /dev/block/by-name/$p") $(stat -c %s "captures/$D/radio/$p.img")"; done
(cd "captures/$D/radio" && sha256sum *.img | tee SHA256SUMS)
```

Two optional radio-adjacent partitions, if present [I: names unverified
on this unit]. A missing name prints `missing` and is fine.

```sh
for p in ocdt param; do if adb exec-out su -c "test -e /dev/block/by-name/$p && echo y" | grep -q y; then adb exec-out su -c "dd if=/dev/block/by-name/$p 2>/dev/null" > "captures/$D/radio/$p.img"; echo "$p $(stat -c %s "captures/$D/radio/$p.img")"; else echo "$p missing"; fi; done
(cd "captures/$D/radio" && sha256sum *.img > SHA256SUMS)
```

Boot-LUN facts and bootloader firmware across slots (read-only; for the
GPT-exception ticket, R2b in `docs/research/gpt-exception-prep.md` §6.1).
The paths follow the Linux UFS sysfs ABI [I on this vendor kernel]; empty
output is not an error.

```sh
adb exec-out su -c 'for d in /sys/class/scsi_device/*/device; do echo "$d boot_lun_id=$(cat $d/unit_descriptor/boot_lun_id 2>/dev/null)"; done; for f in /sys/bus/platform/devices/*ufshc*/attributes/boot_lun_enabled; do echo "$f $(cat $f 2>/dev/null)"; done' > "captures/$D/ufs-luns.txt"
for p in abl aop bluetooth cmnlib cmnlib64 devcfg dsp featenabler hyp imagefv keymaster modem multiimgoem qupfw storsec tz uefisecapp xbl xbl_config; do
  a=$(adb exec-out su -c "sha256sum /dev/block/by-name/${p}_a 2>/dev/null" | cut -d' ' -f1)
  b=$(adb exec-out su -c "sha256sum /dev/block/by-name/${p}_b 2>/dev/null" | cut -d' ' -f1)
  if [ -z "$a" ] || [ -z "$b" ]; then r=missing; elif [ "$a" = "$b" ]; then r=same; else r=DIFFERENT; fi
  echo "$p $r"
done | tee "captures/$D/bootloader-ab.txt"
```

An alternative is a read-only `bkerler/edl` dump in EDL mode, which
supports this phone's OnePlus auth [V scouting §3.2]; it is [I] on this
unit, needs a proprietary loader, and is the owner's decision. This
runbook does not use it.

- Every command reads only. `dd` reads **from** the block device
  (`if=`) into a file on the laptop. There is no `of=` on the phone.
  Before you run the loops, check that no line contains `of=`.
- **Expect:**
  - `id` → `uid=0(root)`.
  - `live.dtb` is non-empty and `dtc` turns it into `live.dts`. Warnings
    are normal.
  - `by-name-root.txt` maps each name to `/dev/block/sdXN`. That gives the
    LUN of `boot_b`/`dtbo_b` versus `userdata` (upstream's
    `UFS_RW_LUNS`, see NOTES.md).
  - `luns.txt` lists `sda`-`sdf` [I] with sizes and a logical block size
    of 4096 [I]. **`/sys/block/sdX/size` is always in 512-byte units**,
    whatever the logical block size [V: Linux source (torvalds master,
    fetched 2026-11-15) — `block/genhd.c` registers the `size` attribute
    with `part_size_show`, which prints `bdev_nr_sectors`; those are
    `SECTOR_SHIFT 9` (512-byte) units, per `include/linux/blk_types.h:31`
    and `bdev_nr_bytes` = `bdev_nr_sectors << SECTOR_SHIFT`
    (`include/linux/blkdev.h:854-856`)]. At 4096 the last LBA is
    `size/8 - 1`. Use that in the GPT-exception ticket, not `size - 1`
    (which is 8x too high). The tail loop assumes 4096; if `lbs` is 512,
    tell the coordinator before relying on the tail dumps.
  - Six `gpt-head-sd?.bin` files of 24576 bytes (LBA 0 to 5: protective
    MBR, GPT header, first entries).
  - Six `gpt-tail-sd?.bin` files of 24576 bytes (LBA last-5 to last: the
    backup entries and the backup GPT header). The ticket "Slot-B bootable
    marking on Qualcomm: the named GPT-attribute exception" needs them,
    and dumping them now saves a second root session.
  - `ufs-luns.txt`: one line per SCSI LUN with its `boot_lun_id`, and a
    `boot_lun_enabled` value [I: 1 or 2, meaning boot LUN A or B]. Empty
    values are not an error; tell the coordinator.
  - `bootloader-ab.txt`: one line per partition, `same`, `DIFFERENT` or
    `missing` (only the words leave the laptop, never the hashes). All
    `same` means slot B's firmware matches slot A's. Any `DIFFERENT` is no
    stop here: it is input for the A3b decision and the GPT-exception
    ticket (upstream wants matching bootloader slots before a slot-B
    install).
  - Five non-empty `radio/*.img` files from the main loop, plus `ocdt`
    and `param` if they exist. Each line of the size loop shows
    two equal numbers (partition size and file size). Keep the images and
    `SHA256SUMS` private: never commit, paste or upload them or their
    hashes, and keep a second copy on the owner's private storage.
- **Stop:** anything prompts for a write, or `su` is denied (redo D3).
- **Stop:** a radio image is 0 bytes or the two sizes differ. Check the
  exact name in `by-name-root.txt` (for example a slot suffix) and tell
  the coordinator; do not guess names.
- **Stop:** on the LUN that holds `boot_b` (from `by-name-root.txt`),
  any `gpt-head-sd?.bin` or `gpt-tail-sd?.bin` that is not 24576 bytes.
  A failed `dd` (missing LUN, denied `su`, bad arithmetic) is silent: the
  device-side `2>/dev/null` leaves a 0-byte file. Re-run that one line
  and tell the coordinator.
- **Rollback:** n/a (read-only).

### D5. Answers from the captures (laptop, offline)

```sh
grep -nE 'stdout-path|bootargs' "captures/$D/live.dts"
grep -nE 'serial@a90000|serial@998000|geni-debug-uart' "captures/$D/live.dts"
grep -nE 'compatible = "qcom,(sm8250|kona)|qcom,msm-id|qcom,board-id' "captures/$D/live.dts" | head
grep -oE 'msm_drm\.dsi_display0=[^ ]*|androidboot\.dtbo_idx=[^ ]*|androidboot\.slot_suffix=[^ ]*' "captures/$D/cmdline-root.txt"
grep -E 'boot_[ab]|dtbo_[ab]|vbmeta|userdata|super|devinfo' "captures/$D/by-name-root.txt" | awk '{print $(NF-2), $(NF-1), $NF}'
```

GPT slot attributes from the dumps (laptop, offline; reads the files only):

```sh
for l in a b c d e f; do echo "== sd$l"; python3 -I - "captures/$D/gpt-head-sd$l.bin" <<'EOF'
import struct, sys
b = open(sys.argv[1], 'rb').read()
for bs in (4096, 512):
    h = b[bs:bs + 92]
    if h[:8] == b'EFI PART': break
else:
    sys.exit('no GPT header at LBA 1 (tried 4096 and 512)')
lba, n, sz = struct.unpack_from('<QII', h, 72)
print(f"lbs={bs} entries={n} entry_size={sz}")
for i in range(n):
    o = lba * bs + i * sz
    if o + sz > len(b):
        print(f"WARNING: dump ends at entry {i} of {n}; later entries not shown"); break
    e = b[o:o + sz]
    if e[:16] == bytes(16): continue
    name = e[56:128].decode('utf-16le').split('\0')[0]
    attr = struct.unpack_from('<Q', e, 48)[0]
    if name.rsplit('_', 1)[0] in ('boot', 'dtbo', 'vbmeta', 'vbmeta_system'):
        f = (attr >> 48) & 0xff
        print(f"{name:16} attrs=0x{attr:016x} byte6=0x{f:02x} "
              f"active={f >> 2 & 1} successful={f >> 6 & 1} unbootable={f >> 7 & 1} "
              f"other_bits=0x{f & 0x3b:02x}")
EOF
done
```

- **Expect:** the LUN holding `boot_a`/`boot_b` prints both. Decoding of
  attribute byte 6 (bits 48-55): active = bit 50, successful = bit 54,
  unbootable = bit 55 [V `linux-msm/qbootctl` `gpt-utils.h:65-69`,
  `AB_FLAG_OFFSET` = attribute byte 6; I on the unit]. Where priority and
  retry count sit inside the remaining bits (`other_bits`) is **not**
  defined in that header [I]. Compare with the B2 `getvar` slot flags.
  If active/successful/unbootable agree, stage-0 question 2 is answered
  (slot flags live in GPT attributes) without writing anything. Other LUNs
  print nothing or `no GPT header`; both are fine. On the LUN holding
  `boot_b`, `no GPT header` or empty output is an error, not fine: the
  dump itself failed (D4's 24576-byte Stop).
- **Stop:** none. The parser only reads laptop files.
- **Rollback:** n/a.

### D6. Leave temp root

```sh
adb reboot
```

- **Expect:** stock boots from flash with no root. The Magisk app shows
  "Installed: N/A".
- **Stop:** never use "Uninstall Magisk" to leave temp root. It restores
  images, which writes the boot partition. A plain reboot is all it takes;
  uninstalling the **app** afterwards is fine.
- **Rollback:** n/a.

---

## 6. What to paste back, and what goes to #808

Paste into the coordinator chat (no serials, IMEI or MACs; check before
pasting):

```sh
grep -RniE 'serial|imei|meid|iccid|imsi|msisdn|macaddr|mac_addr|bdaddr|([0-9a-f]{2}[:-]){5}[0-9a-f]{2}' "captures/$D" | cut -c1-120 | head -60
```

That `grep` shows **where** identifiers sit. Use it to check that nothing
you paste contains a match. Device-tree node names and aliases such as
`serial@a90000` or `serial0 = &uart6` match the `serial` pattern but are
not identifiers; values such as `androidboot.serialno=` or a
`serial-number` property are. Paste D5 only after checking that every
match in it is a node name. Paste the filtered outputs from A3, B2, B3, B4, C3,
D5, `luns.txt`, `pci-root.txt`, `ufs-luns.txt` (paths and numbers only),
`bootloader-ab.txt` and the A5 Widevine level. Do **not** paste
`live.dts`, `dmesg`, `getvar-all*.txt`, `getprop-all.txt`, any `.bin` file
or anything under `radio/`. The `.bin` dumps hold disk and partition GUIDs,
which are unique to the unit; the `radio/` images hold IMEI-related data.

The coordinator drafts the #808 comment (English) from those facts,
answering `docs/STAGE-0.md` §5 plus the extra questions there. The owner
posts it, because agents have no write access upstream.

Resolution of the stage-0 ticket: the #808 comment is posted, and the
ticket records the date and the capture path (path only, never contents).
