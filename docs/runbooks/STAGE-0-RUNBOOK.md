<!-- SPDX-License-Identifier: MIT -->
# Stage-0 runbook: stock capture on the owner's IN2023

Ticket: "Stage-0 capture on the owner's phone (IN2023)". This runbook turns
`docs/STAGE-0.md` into steps the owner runs by hand (AGENTS.md rule 1).
Every step has a command block, **Expect**, **Stop** and **Rollback**. Paste
the output (redacted, see §6) back into the coordinator chat after each
phase. Do not batch the phases.

What this runbook writes to the phone: **one thing only**, the unlock in
phase C, which wipes user data and changes the lock state. Nothing is ever
flashed. `fastboot boot` in phase D loads an image into RAM and does not write
it to flash.

Ground rules for the whole runbook:

- Run everything from the repo root (`scripts/stage0-collect.sh` writes to
  `captures/<date>/` relative to the current directory). `captures/` is
  gitignored. Never `git add -f` it.
- **Never type `fastboot flash`, `fastboot erase`, `fastboot set_active`,
  `fastboot --set-active` or `fastboot flashing lock`/`oem lock` during
  stage 0.** None of them appear below. If a guide, a forum post or a tool
  suggests one, stop and ask.
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
  `bootdevice.txt`, `cpuinfo.txt`, `meminfo.txt` (plus `cmdline.txt` and
  `modules.txt`, which may be empty). The script itself says it writes
  nothing to the phone.
- [I] `by-name.txt` and `cmdline.txt` may say `Permission denied` on a
  locked, unrooted phone (SELinux). **This is not a stop:** phase D repeats
  both with root.
- **Stop:** the script exits non-zero before `getprop-all.txt` exists.
- **Rollback:** n/a.

### A3. Build identity and boot properties

```sh
adb shell getprop | grep -E 'ro\.build\.(fingerprint|display\.id|version\.(release|security_patch|incremental|ota))|ro\.product\.(device|name|model)|ro\.boot\.(slot_suffix|dtbo_idx|verifiedbootstate|vbmeta\.device_state|flash\.locked|hardware\.revision|project_name|prjname)' \
  | tee "captures/$D/build-boot-props.txt"
```

- **Expect:** `ro.product.model` = `IN2023`; a `ro.build.fingerprint` with
  an EEA/EU product name [I: e.g. `OnePlus8Pro_EEA`]; `ro.boot.slot_suffix`
  = `_a`; `ro.boot.flash.locked` = `1`; `ro.boot.verifiedbootstate` =
  `green`. `ro.boot.dtbo_idx` is present if ABL applies a dtbo (stage-0
  question 4).
- **Stop, important:** `ro.boot.slot_suffix` is `_b`. Stock is then
  running from slot B, which reverses the safety model (slot A for stock,
  slot B for us). Report it and do nothing else. The fix (an official OTA
  so stock lands on A, or swapping the roles) is a decision, not a step.
- **Stop:** model is not `IN2023`.
- **Rollback:** n/a.
- These lines contain **no** serial. Paste them back as they are, with
  `ro.build.fingerprint`. R1 needs it to pick the exact OTA.

### A4. Wi-Fi silicon (read-only, may need root)

```sh
adb shell 'for d in /sys/bus/pci/devices/*; do echo "$d $(cat $d/vendor) $(cat $d/device)"; done' | tee "captures/$D/pci.txt"
```

- **Expect:** a device `0x17cb 0x1101` (QCA6390) [I]. A permission error is
  fine; D4 repeats it with root.
- **Stop / Rollback:** none / n/a.

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
  exception"). `has-slot:boot/dtbo/vbmeta: yes`; [I] no
  `init_boot`/`vendor_boot` lines.
- **Stop:** `current-slot: b` (same reason as A3); `unlocked: yes` when you
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
  boots stock.
- **Stop:** `fastboot reboot fastboot` is rejected or the phone never shows
  fastbootd. Then restore path 1 is unproven: report it before phase C.
- **Rollback:** if the phone sits in fastbootd: choose "Reboot system now"
  with the volume keys and Power, or `fastboot reboot`.

### Gate G1 (owner decides, before phase C)

All must be true:

1. The restore-assets ticket is resolved: the OTA matches A3's fingerprint
   exactly and its checksum is verified; the MSM package is on disk.
2. Phases A and B are pasted back, and the coordinator has confirmed
   `current-slot: a` and `IN2023`.
3. Everything on the phone is backed up off the phone (photos, 2FA apps,
   Signal/WhatsApp backups, eSIM if any). **The unlock wipes everything.**
4. [I] The owner accepts the side effects of an unlocked bootloader on
   stock Android: hardware-backed Play Integrity fails, so banking and
   ID apps (MitID, MobilePay) may refuse to run. The orange-state warning
   shows at every boot.

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
ls -l ~/android/reference/instantnoodlep/images/boot.img
```

- **Expect:** the file exists (extracted in R4).
- **Stop:** the OTA does not match A3's fingerprint. A boot.img from
  another build may not boot and gives wrong facts.

### D2. Patch with Magisk (on the phone; patching is a file operation)

```sh
adb install Magisk-v<version>.apk        # official release from github.com/topjohnwu/Magisk
adb push ~/android/reference/instantnoodlep/images/boot.img /sdcard/Download/
```

In the Magisk app: Install → **Select and Patch a File** → pick
`Download/boot.img`. Then:

```sh
adb shell ls /sdcard/Download/ | grep magisk_patched
adb pull /sdcard/Download/magisk_patched-<id>.img "captures/$D/"
```

- **Expect:** a `magisk_patched-<id>.img` about the size of `boot.img`.
- **Stop:** the app only offers "Direct Install". That writes `boot_a`.
  Never choose it, now or later.
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
  reboot or install. Decline. That path writes the boot partition.
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
ls -la "captures/$D"
```

- Every command reads only. `dd` reads **from** the block device
  (`if=`) into a file on the laptop. There is no `of=` on the phone.
  Before you run the loop, check that no line contains `of=/dev`.
- **Expect:**
  - `id` → `uid=0(root)`.
  - `live.dtb` is non-empty and `dtc` turns it into `live.dts`. Warnings
    are normal.
  - `by-name-root.txt` maps each name to `/dev/block/sdXN`. That gives the
    LUN of `boot_b`/`dtbo_b` versus `userdata` (upstream's
    `UFS_RW_LUNS`, see NOTES.md).
  - `luns.txt` lists `sda`-`sdf` [I] with sizes and a logical block size
    of 4096 [I].
  - Six `gpt-head-sd?.bin` files of 24576 bytes (LBA 0 to 5: protective
    MBR, GPT header, first entries).
- **Stop:** anything prompts for a write, or `su` is denied (redo D3).
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
b = open(sys.argv[1], 'rb').read(); bs = 4096
h = b[bs:bs + 92]
if h[:8] != b'EFI PART': sys.exit('no GPT header at LBA 1 (block size not 4096?)')
lba, n, sz = struct.unpack_from('<QII', h, 72)
for i in range(n):
    o = lba * bs + i * sz
    if o + sz > len(b): break
    e = b[o:o + sz]
    if e[:16] == bytes(16): continue
    name = e[56:128].decode('utf-16le').split('\0')[0]
    attr = struct.unpack_from('<Q', e, 48)[0]
    if name.rsplit('_', 1)[0] in ('boot', 'dtbo', 'vbmeta', 'vbmeta_system'):
        print(f"{name:16} attrs=0x{attr:016x} bits48-55=0x{(attr >> 48) & 0xff:02x}")
EOF
done
```

- **Expect:** the LUN holding `boot_a`/`boot_b` prints both, with
  non-zero bits 48-55 on `boot_a` at least. Decode those bits with
  `linux-msm/qbootctl` `gpt-utils.h` (priority, active, retry count,
  successful, unbootable) [V source, I on unit] and compare them with the
  B2 `getvar` slot flags. If they agree, stage-0 question 2 is answered
  (slot flags live in GPT attributes) without writing anything. Other LUNs
  print nothing or `no GPT header`; both are fine.
- **Stop:** none. The parser only reads laptop files.
- **Rollback:** n/a.

### D6. Leave temp root

```sh
adb reboot
```

- **Expect:** stock boots from flash with no root. The Magisk app shows
  "Installed: N/A".
- **Rollback:** n/a.

---

## 6. What to paste back, and what goes to #808

Paste into the coordinator chat (no serials, IMEI or MACs; check before
pasting):

```sh
grep -RniE 'serialno|imei|meid|iccid|androidboot\.serial|wifimacaddr|btmacaddr|([0-9a-f]{2}:){5}[0-9a-f]{2}' "captures/$D" | cut -c1-120 | head -40
```

That `grep` shows **where** identifiers sit. Use it to check that nothing
you paste contains a match. Paste the filtered outputs from A3, B2, B3, C3,
D5, `luns.txt` and `pci-root.txt`. Do **not** paste `live.dts`, `dmesg`,
`getvar-all*.txt`, `getprop-all.txt` or any `.bin` file.

The coordinator drafts the #808 comment (English) from those facts,
answering `docs/STAGE-0.md` §5 plus the extra questions there. The owner
posts it, because agents have no write access upstream.

Resolution of the stage-0 ticket: the #808 comment is posted, and the
ticket records the date and the capture path (path only, never contents).
