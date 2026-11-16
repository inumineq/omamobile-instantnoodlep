<!-- SPDX-License-Identifier: MIT -->
# M1a runbook: RAM-only first light on instantnoodlep (IN2023)

Plan: `device/instantnoodlep/BRINGUP-M1-PLAN.md`. Its §8 is the gate
summary; this file is the gated runbook it points at, written before first
use. Read plan §5.2-5.5 first: the boot image (header v2, stock geometry),
the dtbo risk, the storage guard and the watchdog. Last-resort recovery is
`docs/RESTORE-RUNBOOK.md`.

The owner runs every step that touches the phone and pastes the output
back (AGENTS.md rule 1). Steps P1-P4 are laptop, offline, and say so in
their headings. Run everything from the repo root.

## Hard rules

- **Never `fastboot flash`, `fastboot erase`, `fastboot set_active`,
  `fastboot --set-active`, `fastboot flashing lock` or `fastboot oem lock`
  in M1a.** None of them appear below. Any step that seems to need one is
  a stop (plan §8). If a guide, a forum post or a tool suggests one, stop
  and ask.
- **One change per boot.** If a boot fails, change one thing and boot
  again.
- A `FAILED (remote: ...)` from `fastboot boot` writes nothing. Paste it
  and stay in fastboot; the next move is P4, never a flash.
- Every fastboot command that targets the phone is `fastboot -s <serial>`.
  Replace `<serial>` with the pinned serial (plan 5.7). It is private and
  is never pasted.
- Captures go to `captures/<date>/m1/` (gitignored, AGENTS.md rule 4).
  Serials, IMEI and MAC addresses never leave the laptop; "What to paste
  back" at the end says what is safe.

## Placeholders

`{{NAME}}` marks a value the plan leaves open. The step that fills it is
named with each. Never run a block with a `{{...}}` still in it.

- `{{FASTBOOT_BUTTONS}}` — how to reach fastboot from power-off. Filled by
  the stage-0 finding (plan §8, note under the table). Until filled:
  `adb reboot bootloader`.
- `{{K1_KERNEL}}`, `{{K1_DTB}}` — the K1 kernel image and its original DTB
  (plan 5.5-5.6). Chosen in P2. The builder writes `out/boot.probe.dtb` for
  boot 1 and derives the boot-2 DTB name from `{{BOOT2_IMG}}`.
- `{{SSH_KEY}}` — the owner's local ssh key for the USB gadget link (plan
  goal 2). Chosen in P2.
- `{{MKBOOTIMG}}` — the `mkbootimg` tool, from the laptop tools setup
  (RESTORE-ASSETS R4). Filled before P2.
- `{{UFDT_APPLY_OVERLAY}}` — libufdt's `ufdt_apply_overlay`, from the
  laptop tools setup (RESTORE-ASSETS R4). Filled before P3.
- `{{DTBO_ENTRY}}` — the stock dtbo entry ABL picks on this board:
  entry 16 ("kona MTP 19811", `qcom,board-id = <0x10008 0>`), because
  stock boots with `ro.boot.dtbo_idx = 16` (stage-0 A3) and `Q/` picks the
  entry from board data only, not from our DTB [V: Q/LocateDeviceTree.c
  `GetBoardDtb`]. Filled 2026-11-16; result in NOTES.md.
- `{{BOOT2_IMG}}` — path of the boot-2 image (UFS on). Filled by the
  build at the top of R4.
- `{{M1_BACKUP_DIR}}` — a directory outside the repo for the R6 backups.
  Chosen by the owner before R6.

`$R` and `$SRC_DIR` are as in `docs/runbooks/RESTORE-ASSETS.md` (header
and R4): the reference directory and the AOSP tools checkout.

```sh
D=$(date +%Y-%m-%d); export D; mkdir -p "captures/$D/m1"
```

---

### P0. Gate: stage 0 complete

All must be true:

1. STAGE-0-RUNBOOK D3 passed: it printed `Booting OKAY` and stock came up
   with temporary root.
2. Stage-0 questions Q4, Q7, Q9 and Q11 are answered
   (`docs/STAGE-0.md` §5).
3. The answers are posted on upstream issue #808.

- **Stop:** D3 failed, or any of Q4/Q7/Q9/Q11 is still open. The rest of
  this runbook waits.
- **Rollback:** n/a.

### P1. Unpack the stock boot.img (laptop, offline)

```sh
test -n "$SRC_DIR" && test -d "$SRC_DIR/system/tools/mkbootimg" || echo "SRC_DIR not set or wrong"
ls -l "$R/images/boot.img"
python3 "$SRC_DIR/system/tools/mkbootimg/unpack_bootimg.py" --boot_img "$R/images/boot.img" --out "$R/images/boot-unpacked-m1" --format=info | tee "captures/$D/m1/p1-bootimg-info.txt"
file "$R/images/boot-unpacked-m1/kernel"
stat -c '%s %n' "$R/images/boot-unpacked-m1"/{kernel,ramdisk,second,dtb}
fdtget -t x "$R/images/boot-unpacked-m1/dtb" / qcom,msm-id
fdtget -t x "$R/images/boot-unpacked-m1/dtb" / qcom,board-id
fdtget -t x "$R/images/boot-unpacked-m1/dtb" / qcom,pmic-id || echo "no qcom,pmic-id"
```

- **Expect:** header version 2, page size 4096; offsets as
  `PM/deviceinfo` (plan 5.2: base `0x00000000`, kernel `0x00008000`,
  ramdisk `0x01000000`, second `0x00000000`, tags `0x00000100`, dtb
  `0x01f00000`); a non-empty dtb size; the kernel compression `file`
  reports is recorded; os_version/patch level recorded; msm-id cells
  contain `0x164`; board-id contains 8 [I]; any `qcom,pmic-id` recorded
  (plan 5.3 uses it for the exact-match variant).
- **Stop:** any value differs from plan 5.2. Update 5.2 first (the stock
  image wins where they differ, plan 5.2's dipper rule); do not build on
  a mismatch.
- **Rollback:** n/a (laptop only).

### P2. Build the K1 image (laptop, offline)

Kernel K1 is the SM8250 community kernel (plan 5.6). The probe DTB is the
builder-made copy of the kernel's DTB with USB `dr_mode = "peripheral"`,
remote processors disabled and, for boot 1, the UFS host disabled (plan
5.5). The initramfs ships without `/etc/omamobile-ufs-rw`: no allowlist
at all (plan 5.5). The command uses an existing upstream checkout and an
offline aarch64 Alpine root prepared as described by the builder's `--help`;
adjust those two local paths if needed.

```sh
tools/build-instantnoodlep-probe --omarchy-mobile "$HOME/omarchy-mobile" --initramfs-root "$HOME/instantnoodlep-initramfs-root" --boot 1 --kernel {{K1_KERNEL}} --dtb {{K1_DTB}} --ssh-key {{SSH_KEY}} --mkbootimg {{MKBOOTIMG}} --out out/boot.img
fdtget -t x out/boot.probe.dtb / qcom,msm-id
fdtget -t x out/boot.probe.dtb / qcom,board-id
fdtget -t s out/boot.probe.dtb / compatible
stat -c '%s %n' {{K1_KERNEL}} out/boot.probe.dtb out/boot.img | tee "captures/$D/m1/p2-sizes.txt"
sha256sum out/boot.img | tee "captures/$D/m1/p2-sha256.txt"
```

- **Expect:** the builder exits 0; the DTB values are exactly plan 5.2's
  (`qcom,msm-id = <0x164 0x10000>, <0x164 0x20001>`;
  `qcom,board-id = <0x08 0x00>, <0x00 0x00>`; compatible
  `"oneplus,instantnoodlep", "qcom,sm8250"`); the builder's re-read shows
  no `/etc/omamobile-ufs-rw` in the cpio. Sizes and sha256 are recorded.
- **Stop:** the builder refuses, a value differs, or the image exceeds
  the size the builder allows.
- **Rollback:** fix the inputs; delete the output.

### P3. Offline dtbo check (laptop, offline)

The main design risk (plan 5.3): a RAM boot still reads stock `dtbo_a`
from flash, and ABL may apply its board entry to our DTB. Try it on the
laptop first.

```sh
python3 "$SRC_DIR/system/libufdt/utils/src/mkdtboimg.py" dump "$R/images/dtbo.img" | tee "captures/$D/m1/p3-dtbo-dump.txt"
# From the dump, take the entry whose id matches board-id 8 ({{DTBO_ENTRY}}).
# If no entry matches, record "no matching entry" and go to P4.
{{UFDT_APPLY_OVERLAY}} out/boot.probe.dtb {{DTBO_ENTRY}} "captures/$D/m1/p3-applied-ufdt.dtb"
fdtoverlay -i out/boot.probe.dtb -o "captures/$D/m1/p3-applied-fdtoverlay.dtb" {{DTBO_ENTRY}}
```

- **Expect:** a result is recorded either way: applies, fails, or no
  matching entry. [I] This predicts ABL; it does not prove it (plan 5.3).
- **Stop:** cannot extract or parse `dtbo.img`.
- **Rollback:** n/a (laptop only).

### P4. Owner decision on the P3 result (laptop, offline)

If the overlay fails, the owner chooses one RAM-only variant (plan 5.3):
a DTB that gives an exact match (PMIC ids from the stock live DT, P1) or
empty label stubs the stock overlay can resolve — or accepts outcome (a),
a clean refusal, as the first finding. Each variant is one boot (one
change per boot).

- **Expect:** the written choice in `device/instantnoodlep/NOTES.md`.
- **Stop:** no decision. Nothing boots without one.
- **Rollback:** n/a.

### P5. Phone in fastboot, slot flags before (phone)

Enter fastboot with `adb reboot bootloader`, or from power-off with
{{FASTBOOT_BUTTONS}}.

```sh
adb reboot bootloader
fastboot devices
fastboot -s <serial> getvar all 2>&1 | tee "captures/$D/m1/p5-getvar-all.txt"
```

- **Expect:** `fastboot devices` shows exactly one device. In the getvar:
  `current-slot: a`, `unlocked: yes`, `slot-unbootable:a: no`, and
  `slot-successful`/`slot-unbootable`/`slot-retry-count` for both slots
  equal to the stage-0 capture (stage-0 B2/C3). This is the precondition
  for plan 5.4: with `slot-unbootable:a = no`, ABL should write nothing
  on a RAM boot.
- **Stop:** the slot is not `a`, the phone is locked,
  `slot-unbootable:a: yes`, or more than one device is listed.
- **Rollback:** `fastboot -s <serial> reboot`; stock boots.

### R1. K1 boot 1, UFS disabled (phone)

Boot 1 uses the P2 image (UFS host disabled, plan 5.5).

```sh
fastboot -s <serial> boot out/boot.img
```

- **Expect:** `Sending 'boot.img' ... OKAY`, `Booting OKAY`; the
  orange-state screen, then a Linux console on the phone display; a USB
  NCM device on the laptop within about 60 s. That `ssh
  root@172.16.42.1` works is checked by R2's first command.
- **Stop:** `FAILED (remote: ...)`: paste it, stay in fastboot, go to P4.
  A refusal writes nothing (hard rules). **Do not fall back to any
  flash.** Also stop: no console and no USB after 2 min, or anything asks
  to flash.
- **Rollback:** on a hang, hold Power + Volume Up for 10-30 s; stock
  boots from slot A. If it lands in fastboot: `fastboot -s <serial>
  reboot`. **After a refusal, never send a second `fastboot boot` in the
  same fastboot session:** run `fastboot -s <serial> reboot bootloader`
  first. [V 2026-11-16] A second RAM boot after a refused one failed AVB
  and ABL marked slot A unbootable and switched to slot B
  (`HandleActiveSlotUnbootable`, NOTES 2026-11-16 afternoon). Left alone, the no-host crash plus `panic=10` does the same by
  itself in about 75 s (plan 5.5).

### R2. Read-only checks over SSH, boot 1 (phone)

Accept the host key on the first connect.

```sh
ssh root@172.16.42.1 'uname -r'
ssh root@172.16.42.1 'cat /proc/cmdline' | tee "captures/$D/m1/r2-cmdline.txt"
ssh root@172.16.42.1 'ls /sys/block'
ssh root@172.16.42.1 'dmesg' | tee "captures/$D/m1/r2-dmesg.txt"
ssh root@172.16.42.1 'ps | grep -i watchdog'
ssh root@172.16.42.1 'grep -iE "reserved|System RAM" /proc/iomem' | tee "captures/$D/m1/r2-iomem.txt"
```

- **Expect:** the first command answers, which is also R1's ssh check;
  the expected K1 kernel release; **no `sd*` devices at all** (UFS was
  meant to be off); the watchdog feeder running; dmesg shows the USB
  gadget and the watchdog. The `/proc/cmdline` record is evidence in its
  own right (plan 5.2) and feeds R3. [I] ABL appends
  `androidboot.serialno=` to the command line, so `r2-cmdline.txt` is
  private; only the fields named in "What to paste back" leave the laptop.
- **Stop:** any `sd*` present, or the watchdog is not fed.
- **Rollback:** `ssh root@172.16.42.1 'reboot -f'`; stock boots from
  slot A. If ssh itself hangs, the R1 rollback.

### R3. Device tree and cmdline evidence (phone, then laptop diff)

```sh
ssh root@172.16.42.1 'dtc -I fs /proc/device-tree' > "captures/$D/m1/r3-live.dts"
dtc -I dtb -O dts -o "captures/$D/m1/r3-probe.dts" out/boot.probe.dtb
diff -u "captures/$D/m1/r3-probe.dts" "captures/$D/m1/r3-live.dts" | tee "captures/$D/m1/r3-dt.diff"
grep -oE 'androidboot\.dtbo_idx=[^ ]*|root=[^ ]*|skip_initramfs' "captures/$D/m1/r2-cmdline.txt"
```

- **Expect:** no grafted downstream nodes in the live tree, and a record
  of whether ABL took the overlay path (`androidboot.dtbo_idx`, plan
  5.2). Phandle and ordering noise in the diff is normal; the check is
  for nodes that exist only in the live tree. [I] ABL may add a
  `serial-number` property and other per-unit values to the live tree:
  `r3-live.dts` and `r3-dt.diff` stay private.
- **Stop:** nodes in the live tree that are not in our DTB. That is
  outcome (c) of plan 5.3, a contaminated DT: stop all bring-up and
  analyse offline.
- **Rollback:** `ssh root@172.16.42.1 'reboot -f'`; stock boots.

### R4. K1 boot 2, UFS on, guard with no allowlist (phone)

Build the boot-2 image as in P2, one change: the probe DTB keeps the UFS
host enabled (plan 5.5). Record its path as `{{BOOT2_IMG}}`. This build is
laptop/offline:

```sh
tools/build-instantnoodlep-probe --omarchy-mobile "$HOME/omarchy-mobile" --initramfs-root "$HOME/instantnoodlep-initramfs-root" --boot 2 --kernel {{K1_KERNEL}} --dtb {{K1_DTB}} --ssh-key {{SSH_KEY}} --mkbootimg {{MKBOOTIMG}} --out {{BOOT2_IMG}}
```

Then (phone):

```sh
fastboot -s <serial> boot {{BOOT2_IMG}}
```

and once ssh works (the R2 commands repeat as needed):

```sh
ssh root@172.16.42.1 'for f in /sys/block/sd*/ro /sys/block/sd*/*/ro; do echo "$f $(cat "$f")"; done'
ssh root@172.16.42.1 'dmesg | grep ufs-ro'
ssh root@172.16.42.1 'ls /dev/sda'
```

- **Expect:** every partition and every disk except `sda` reads `ro=1`;
  `/sys/block/sda/ro` reads 0 by design, because the guard deletes the
  `/dev/sda` node instead (partitions are guarded one by one); `/dev/sda` is
  absent (the guard removed the main LUN's whole-disk node, plan goal 3);
  the init logs "no allowlist ... every partition read-only"; no UFS
  errors in dmesg.
- **Stop:** any `ro=0` other than `/sys/block/sda/ro`; `/dev/sda` present and writable; UFS errors.
- **Rollback:** `ssh root@172.16.42.1 'reboot -f'`, or the R1 rollback if
  hung. Stock boots from slot A.

### R5. Back to stock, slot flags after (phone)

```sh
ssh root@172.16.42.1 'reboot -f'
# let stock boot fully, then:
adb reboot bootloader
fastboot -s <serial> getvar all 2>&1 | tee "captures/$D/m1/r5-getvar-all.txt"
```

- **Expect:** stock Android boots from slot A; the slot flags equal P5's
  record. That is the check of plan 5.4: `fastboot boot` made no GPT
  write.
- **Stop:** stock does not boot, or any slot flag changed.
- **Rollback:** stock does not boot: stop; the owner's last-resort
  recovery per `docs/RESTORE-RUNBOOK.md` (outside the port's tooling,
  recorded if used). Changed flags: record them, stop, and ask on #808
  before any further boot.

### R6. Optional radio/calibration backup (phone; only after R4 passes)

Read-only, off-repo `dd` from the guarded RAM init (plan goal 6), 4 MiB
chunks as flame did (plan §8 R6). Nothing is mounted. These images hold
IMEI-related and calibration data unique to the unit: they and their
hashes stay private, exactly as in stage-0 D4.

```sh
mkdir -p "{{M1_BACKUP_DIR}}"
for p in persist modemst1 modemst2 fsg fsc devinfo boot_a dtbo_a; do
  ssh root@172.16.42.1 "dd if=/dev/block/by-name/$p bs=4M" > "{{M1_BACKUP_DIR}}/$p.img" || break
done
for p in persist modemst1 modemst2 fsg fsc devinfo boot_a dtbo_a; do ssh root@172.16.42.1 "sha256sum /dev/block/by-name/$p"; done
( cd "{{M1_BACKUP_DIR}}" && sha256sum persist.img modemst1.img modemst2.img fsg.img fsc.img devinfo.img boot_a.img dtbo_a.img )
```

Every command reads only: `dd` reads **from** the block device (`if=`)
into a file on the laptop. There is no `of=` on the phone.

- **Expect:** every phone hash matches its laptop hash; nothing mounted.
- **Stop:** any read error or hash mismatch, or USB drops mid-transfer.
  Also stop if `/dev/block/by-name/` does not exist in the RAM init: ask
  the coordinator, do not guess `sdX` nodes.
- **Rollback:** discard the partial copy; `ssh root@172.16.42.1
  'reboot -f'`; stock boots.

### R7. K2: the linux-omarchy-mobile kernel (phone)

Repeat P2 with the linux-omarchy-mobile `omamobile` kernel and the ported
DTS as the only change (plan 5.6), then repeat R1-R5 verbatim with that
image. One change per boot still applies: if K2 fails where K1 passed,
the difference is the kernel and DTS, nothing else.

- **Expect:** as R1-R5.
- **Stop:** as R1-R5.
- **Rollback:** as R1-R5.

---

## What to paste back

First check that nothing you paste contains an identifier (the stage-0
grep, §6 of `docs/runbooks/STAGE-0-RUNBOOK.md`):

```sh
grep -RniE 'serial|imei|meid|iccid|imsi|msisdn|macaddr|mac_addr|bdaddr|([0-9a-f]{2}[:-]){5}[0-9a-f]{2}' "captures/$D" | cut -c1-120 | head -60
```

Paste, per step:

- P1: the `--format=info` header fields (header version, page size,
  offsets, os_version/patch level), the dtb size, the `file` result for
  the kernel, and the three fdtget values.
- P2: the builder name and its exit, the fdtget values, the sizes and the
  image sha256.
- P3: the mkdtboimg dump and the overlay outcome (applies / fails / no
  matching entry).
- P4: the decision as written in NOTES.md.
- P5 and R5: the filtered getvar lines only, never `getvar all` itself
  (it contains the serial):

  ```sh
  grep -E 'current-slot|slot-(successful|unbootable|retry-count)|unlocked' "captures/$D/m1/p5-getvar-all.txt"
  grep -E 'current-slot|slot-(successful|unbootable|retry-count)|unlocked' "captures/$D/m1/r5-getvar-all.txt"
  ```

- R1: the fastboot output lines, and what appeared on the screen and on
  USB.
- R2: `uname -r`, `ls /sys/block`, the feeder line, the reserved/System
  RAM iomem lines, and only these command-line fields (never the whole
  `/proc/cmdline`, which holds the serial):

  ```sh
  grep -oE 'androidboot\.(slot_suffix|dtbo_idx|verifiedbootstate|mode)=[^ ]*|msm_drm\.dsi_display0=[^ ]*|root=[^ ]*|console=[^ ]*|panic=[^ ]*|skip_initramfs' "captures/$D/m1/r2-cmdline.txt"
  ```

- R3: whether the live DT matches, as a list of node **names** that
  exist only in the live tree (never `r3-live.dts` or the raw diff, and
  never property values such as `serial-number`), and the cmdline fields
  `androidboot.dtbo_idx`, `root=`, `skip_initramfs`.
- R4: every `ro` value, the `ufs-ro` dmesg lines, the `ls /dev/sda`
  result.
- R6: per partition, `match` or `mismatch`. Never the images or the
  hashes (stage-0 D4 rule).
- R7: as R1-R5.

Results then go into plan §9 with the date and the kernel release: the
image sha256, `uname -r`, every `ro` flag, the reserved `/proc/iomem`
lines, the bound watchdog and the USB/SSH outcome (plan 5.7).
