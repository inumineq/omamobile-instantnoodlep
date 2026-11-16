<!-- SPDX-License-Identifier: MIT -->
# BRINGUP-M1b-PLAN: Linux on slot B as the default boot

Plan for milestone M1b: the phone boots our kernel from `boot_b` by
default, with stock Android kept on slot A. This is the house-rule-6 gate
for the persistent slot-B install. It is a plan, not code. Every command
that writes flash or switches slots appears only in a runbook block below,
with Expect, Stop and Rollback, and runs only after the owner's explicit
go for that step (AGENTS.md rule 1).

- Date: 2026-11-17. Branch: `plan/m1b`.
- Inputs: `BRINGUP-M1-PLAN.md` (M1a, done), `STORAGE-M2-PLAN.md` (M2 and
  its tethered amendment §3a), NOTES 2026-11-16 (night).
- Owner decision 2026-11-17: follow the recommendation (M1b now, ahead of
  the maintainer's answer on #808). The GPT success mark (B5) is a
  separate decision, see §5.

Abbreviations as in BRINGUP-M1-PLAN §3. `Q/` is QRD-Development/abl
`6922a8a066a6`. [V] on `Q/` describes Qualcomm's reference ABL; whether
OnePlus's fork does the same is [I] until seen on the phone.

## 1. Why M1b now

- [V] A single stock boot erases an ext4 `userdata` without anyone
  choosing anything: after the M2 T3 write, stock started from slot A,
  stopped in recovery, the owner chose only "reboot", and `userdata` read
  f2fs afterwards (NOTES 2026-11-16 night). Upstream saw the same on the
  Pixel 9a ("a fallback to slot A costs the Linux root",
  U/AGENTS.md:131).
- So tethered M2 (slot A active, every Linux boot by `fastboot boot`)
  loses the root on any unplanned reboot: watchdog bite, `panic=10`,
  flat battery, buttons. With slot B active and Linux on `boot_b`, a
  reboot boots Linux again, and stock runs only if we choose slot A or
  ABL falls back (§3).

## 2. What is on the phone now

- [V 2026-11-17, read from the guarded RAM initramfs] `boot_b`,
  `dtbo_b` and `vbmeta_b` are byte-identical to `boot_a`, `dtbo_a` and
  `vbmeta_a` (sha256 prefixes e8e1a036..., 8b2bc24a..., dbe60c8f...).
  So `dtbo_b` is the stock DTBO table, and its entry 16 is the overlay
  the probe DTB's sink was built against (PR #44).
- [V 2026-11-17] GPT on `sde` (LUN 4, 4096-byte sectors, last LBA
  655359): 96 entries of 128 bytes, primary array at LBA 2-4, backup
  array at LBA 655355-655357, backup header at 655359. Both header CRCs
  and both array CRCs check.
  - `boot_a` = index 10 (`sde11`): attributes 0x0077000000000000
    (priority 3, active, retry 6, successful, bootable).
  - `boot_b` = index 34 (`sde35`): attributes 0x007a000000000000
    (priority 2, not active, retry 7, successful, bootable). Its
    attribute bytes sit at offset 304 of LBA 3 (backup: LBA 655356);
    bit 54 (successful) is byte 310, mask 0x40. This matches
    `SLOT_B_MARK="sde boot_b 1 3 655356 655359"` in the draft
    `device.conf`.
  - Copies of LBA 0-7 and 655352-655359 are in `captures/2026-11-17/m1b/`
    (private, with SHA256SUMS): the rollback for a corrupted GPT.
- [V] `userdata` (`sda23`) is f2fs (stock's reformat). Slot A is active.

## 3. How ABL picks a slot (Q/)

- [V] At boot, `FindBootableSlot` takes the active slot. Bootable and
  successful: boot it. Bootable, not successful, retries left: decrement
  the retry count (written to the GPT) and boot it. Otherwise
  `HandleActiveSlotUnbootable`: switch to the other slot
  [Q/PartitionTableUpdate.c:1625-1690].
- [V] The count is not decremented when booting into fastboot or
  recovery, at the charging screen, or for a dev image
  [Q/LinuxLoader.c:107-122; Q/PartitionTableUpdate.c:1663-1666].
- [V] `fastboot flash boot_b` (and `erase boot_b`) resets slot B: clears
  successful and unbootable, sets priority and retry to the maximum
  [Q/FastbootCmds.c:1024-1049,1115-1119,2082-2085]. `set_active b` does
  the same to slot B and makes it active [Q/FastbootCmds.c:2170-2190].
  [I] The maximum is 7 (the value `boot_b` reads today).
- [V] A failed image load swaps slots and cold-resets
  [Q/VerifiedBoot.c:1508-1515] (seen on the phone, BRINGUP-M1 §5.4).
- Consequence: after B2, slot B has about 7 Linux boots. Each normal
  boot uses one. When they run out, ABL boots stock, and stock erases
  `userdata`. Re-flashing `boot_b` from fastboot resets the count. The
  success mark (B5) stops the countdown for good.

## 4. Design

- **Images.** Only `boot_b` is written. `dtbo_b` stays stock: the probe
  DTB's overlay sink already makes stock entry 16 apply (PR #44, M1a R2-R5
  on K2). `vbmeta_b` stays stock. The unlocked ABL booted our RAM images
  against stock `vbmeta_a` [V: M1a], so [I] it boots `boot_b` against
  stock `vbmeta_b` the same way (orange state).
- **The `boot_b` image** is the tethered image (K2, `--boot 2 --root
  userdata`, allowlist `userdata`, label check `omamobile-root`) with two
  additions:
  - `systemd.debug_shell=ttyGS0` on the cmdline (a root shell on the USB
    serial port), kept until the first boot reaches sshd. The cause of
    T4's missing sshd is still open.
  - `mode-bootloader = <0x2>` and `mode-recovery = <0x1>` on the PMIC
    `pon@800` node, so `reboot bootloader` from Linux lands in fastboot
    and never passes through stock. [V] The K2 DT has no `mode-*`
    properties today (live DT, 2026-11-17); [I] 0x2 is ABL's fastboot
    mode, as in mainline `pm8998.dtsi`. Done in the probe builder now,
    as a K2 DTS commit later.
- **The storage guard allowlist stays `userdata`.** Linux needs no
  write to `boot_b` in M1b: new kernels go in from fastboot. So
  `UFS_RW="boot_b dtbo_b userdata"` stays parked for the release path.
- **Order: everything in one fastboot session.** `flash boot_b`, then
  `flash userdata`, then `set_active b`, then `reboot`. Nothing boots
  stock between the `userdata` write and the slot switch. If any step
  fails, nothing reboots until the owner has decided (Rollback per step).
- **The way back to stock** is `fastboot set_active a` (owner gate). It
  costs the Arch root, since stock then reformats `userdata`. Stock on
  slot A is untouched throughout. The last resort stays the MSM package
  (RESTORE-RUNBOOK), never `MsmDownloadTool V4.0_factory.exe` or "SMT
  Download".
- **Buttons.** [V 2026-11-16] Volume Up + Volume Down held while the
  phone cold-starts with the cable in leads to EDL, not fastboot (NOTES).
  The owner reached fastboot by holding Volume Up + Volume Down from
  recovery's "reboot". Settling the cold-start fastboot combo is B0.3.

## 5. The success mark (B5): a separate decision

- Without it, slot B runs on about 7 boots per `boot_b` flash. That is
  enough for development if every reboot is planned and new kernels go in
  from fastboot (which renews the count).
- The mark itself: set bit 54 of `boot_b`'s attributes in both GPT copies
  and fix the CRCs. Exactly four 4096-byte sectors change on `sde`: LBA 1
  (primary header: array CRC, header CRC), LBA 3 (primary array, byte
  310), LBA 655356 (backup array, byte 310) and LBA 655359 (backup
  header). Upstream allows this only as a named per-device exception in
  CONTRIBUTING §3.1, run by hand, once per `boot_b` install, never from a
  service [U/CONTRIBUTING.md:60; U/AGENTS.md:14]. No device has an entry.
- So B5 waits until (a) M1b B4 has passed (done 2026-11-17) and (b) the
  owner decides it locally, recording the deviation from upstream (or the
  maintainer adds an entry). Runbook: §7 B5. The sectors are built on the
  laptop by `tools/instantnoodlep-slot-b-mark`, which proves only those
  four differ; the write runs from Arch with a one-off
  `blockdev --setrw /dev/sde` that B5 names and undoes.

## 6. Risks

| Risk | Effect | Guard |
| --- | --- | --- |
| ABL refuses `boot_b` | swaps back to slot A, which boots stock and erases `userdata` | B1 RAM-boots the exact `boot_b` image first; B2 flashes the same bytes |
| Retries run out unnoticed | stock boots, `userdata` lost | count boots; reboot only on purpose; re-flash `boot_b` from fastboot after 5 boots; B5 later |
| Linux hangs with no SSH (as T4) | no shell | `systemd.debug_shell=ttyGS0`; `reboot bootloader` via the pon mode; buttons |
| Watchdog bite or panic | a reboot | lands in Linux again on slot B (uses a retry) |
| OnePlus ABL differs from Q/ | unknown slot behaviour | B0 records `getvar all` before; B3 and B4 compare after |
| `pon` mode value wrong | `reboot bootloader` boots Linux or recovery instead | tested in RAM (B1) before it matters; recovery never wipes on its own [V: owner chose reboot] |

## 7. Gated runbook

The phone is attached to the owner's laptop. Agent-run steps follow
AGENTS.md rule 1; steps marked **owner go** run only after the owner's
explicit go for that step.

### B0. Before (agent; reads only)

1. `fastboot getvar all` into `captures/<date>/m1b/b0-getvar.txt`.
   Expect `current-slot: a`, `slot-successful:a: yes`,
   `slot-unbootable:a: no`, `slot-unbootable:b: no`, `unlocked: yes`.
   Stop on anything else.
2. GPT copies as in §2 (done 2026-11-17; repeat if anything has flashed
   since).
3. Owner, screen step: from power-off with the cable **out**, hold Power
   + Volume Down; record whether fastboot appears. Then plug in.

### B1. RAM test of the `boot_b` image (agent)

```sh
fastboot reboot bootloader        # cold, fresh session (BRINGUP-M1 §5.4)
fastboot boot <boot_b.img>
```

- Expect: `Booting OKAY`; USB gadget; initramfs SSH;
  "arch: userdata is not an ext4 root" (userdata is f2fs now); the live
  DT has `mode-bootloader` on `pon@800`.
- Then from the initramfs shell: `reboot bootloader` (via a tiny
  `reboot(2)` call with `LINUX_REBOOT_CMD_RESTART2`, "bootloader").
  Expect fastboot within 30 s. Stop if it boots stock: note it, B2 then
  relies on buttons.
- Rollback: none needed (RAM only).

### B2. Install (owner go, one fastboot session)

```sh
fastboot getvar current-slot                       # a
sha256sum -c boot_b.img.sha256 userdata.simg.sha256
fastboot flash boot_b <boot_b.img>                 # owner go 1
fastboot flash userdata <userdata.simg>            # owner go 2
fastboot set_active b                              # owner go 3
fastboot getvar all                                # read back
fastboot reboot                                    # agent
```

- Expect: each OKAY. After go 3: `current-slot: b`,
  `slot-successful:b: no`, `slot-unbootable:b: no`,
  `slot-retry-count:b: 7`; slot A unchanged (`successful yes`).
- Stop: any FAILED; any slot-A value changed; `current-slot` not `b`.
  Don't reboot; the owner decides.
- Rollback: before go 3, nothing to undo (slot A still active and
  stock; but don't let stock boot after go 2: power off from fastboot or
  re-run `fastboot boot` instead). After go 3: `fastboot set_active a`
  (owner go) gives stock back and costs `userdata`.

### B3. First boot from flash (agent)

- Expect: no `fastboot boot` needed; initramfs; "arch: switching to Arch
  Linux on /dev/sda23"; the debug shell on `/dev/ttyACM0`; later
  `ssh root@172.16.42.1`. `slot-retry-count:b` is now 6 [I].
- If sshd does not come up: diagnose from the debug shell
  (`systemctl list-jobs`, `systemctl --failed`, `journalctl -b`).
- To fastboot: `reboot bootloader` from Linux (B1), else buttons.

### B4. Settle (agent)

- `fastboot getvar all` after one planned reboot: `current-slot: b`,
  retry count one lower, slot A unchanged.
- Then firstboot: the owner gives username, password and the rest; the
  agent writes `/etc/omamobile/firstboot.conf` over SSH and starts
  `omamobile-firstboot` (no secret ever lands in an image file).
- Record in NOTES; close the tethered amendment (STORAGE-M2 §3a) as
  superseded.

### B5. Success mark (amendment 2026-11-17; owner go, once per `boot_b` install)

Not covered by upstream: CONTRIBUTING §3.1 has no Qualcomm entry, and our
house rule 3 limits writes to slot-B boot images and `userdata`. Running
B5 is a local owner decision that records this one exception. The entry
it would need upstream: device instantnoodlep, LUN `sde` (LUN 4, 4096-byte
sectors), LBAs 1, 3, 655356 and 655359, attribute bit 54 of entry 34
(`boot_b`), the header CRC and the array CRC of both copies.

1. Agent, reads only: fresh reads of `sde` LBA 0-7 and 655352-655359
   from Arch (`dd iflag=direct`), then
   `tools/instantnoodlep-slot-b-mark --primary ... --backup ... --out ...`.
   Expect exactly LBAs 1, 3, 655356, 655359; attributes before = bootable,
   not successful; after = the same plus bit 54. 1 byte changed in each
   array sector, 8 in each header (two CRCs). The original four sectors
   are kept beside the new ones (private, SHA256SUMS). Stop on any
   refusal.
2. Owner go, then agent over SSH as root (files pushed to `/tmp` first,
   sha256 checked on the phone):
   ```sh
   blockdev --setrw /dev/sde
   for l in 1 3 655356 655359; do
     dd if=/tmp/b5/sde-lba$l.bin of=/dev/sde bs=4096 seek=$l count=1 \
        conv=notrunc,fsync oflag=direct
   done
   blockdev --setro /dev/sde
   for l in 1 3 655356 655359; do
     dd if=/dev/sde bs=4096 skip=$l count=1 iflag=direct 2>/dev/null | sha256sum
   done
   ```
   - Expect: each read-back sha256 equals the manifest's; `ro` 1 again.
   - Stop: any mismatch. Then write the four `orig/` sectors back the same
     way and read them back (Rollback), before any reboot.
3. Agent: `systemctl reboot --reboot-argument=bootloader`, then
   `fastboot getvar all`. Expect `slot-successful:b: yes`,
   `slot-unbootable:b: no`, `current-slot: b`, slot A unchanged. Then
   `fastboot reboot` and SSH.

- Rollback after a reboot: ABL falls back to the backup GPT if the
  primary is bad [I]; the `orig/` sectors restore the state before B5;
  last resort RESTORE-RUNBOOK (MSM package).
- After B5, a broken `boot_b` no longer falls back to stock: fastboot by
  `reboot bootloader` or buttons, then flash a known-good `boot_b`
  (which clears the mark: B5 runs again after each `boot_b` install).

## 8. Open [I]s and what answers each

| [I] | Answered by |
| --- | --- |
| OnePlus ABL keeps Q/'s slot logic and max retry 7 | B2/B4 `getvar all` |
| ABL boots `boot_b` against stock `vbmeta_b` | B3 |
| `mode-bootloader = <0x2>` reaches fastboot | B1 |
| Cold-start fastboot buttons | B0.3 |
| Why T4's Arch had no sshd | B3 debug shell |
