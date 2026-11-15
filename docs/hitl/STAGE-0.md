<!-- SPDX-License-Identifier: MIT -->
# HITL runbook: stage-0 capture on the owner's IN2023

For the ticket "Stage-0 capture on the owner's phone (IN2023)". **The owner
runs everything; agents prepare and read the redacted output.** This
expands `docs/STAGE-0.md` into exact commands, each with Expect, a stop
condition and a rollback (repo AGENTS.md rule 1).

What this runbook writes to the phone: **only the bootloader unlock**
(Part D, which also wipes user data). It flashes no partition. The
temporary root in Part E is RAM-only (`fastboot boot`). Every other step
is read-only.

Conventions:

- Run from the repo root. `D=captures/$(date +%F)` is the private capture
  folder (gitignored; contains serials, IMEI, MACs; never commit, attach
  or paste it).
- `REF=~/android/reference/instantnoodlep` comes from
  `docs/hitl/RESTORE-ASSETS.md`.
- Paste back only what each step says to paste, **after** the Part F
  redaction check.
- Only `dd if=<device>` appears in this runbook. Never type a command with
  `of=/dev/...` or `fastboot flash`. If an instruction from anywhere seems
  to need one, stop and ask.

## Gate (all must hold before Part B)

| Check | Pass |
| --- | --- |
| Restore-assets ticket resolved (`docs/hitl/RESTORE-ASSETS.md` Parts A-E) | OTA matches the installed build, images extracted, MSM stored |
| Phone charged | at least 50 % |
| Laptop tools | `command -v adb fastboot dtc python3 xxd` prints five paths |

## Part B: stock, booted, adb (read-only)

```sh
D=captures/$(date +%F); mkdir -p "$D"
sh scripts/stage0-collect.sh
for p in ro.build.fingerprint ro.product.device ro.boot.slot_suffix ro.boot.dtbo_idx \
         ro.boot.verifiedbootstate ro.boot.vbmeta.device_state ro.boot.flash.locked \
         ro.boot.hardware.revision ro.boot.dynamic_partitions; do
  printf '%s=' "$p"; adb shell getprop "$p"
done | tee "$D/getprop-boot.txt"
```

- **Expect:** the script writes `getprop-*.txt`, `by-name.txt`,
  `cpuinfo.txt`, `meminfo.txt`, `modules.txt`. `cmdline.txt` may be empty
  or say permission denied (a normal user build), and Part E reads it
  with root. In `getprop-boot.txt`: `slot_suffix=_a`,
  `verifiedbootstate=green`, `vbmeta.device_state=locked`,
  `dynamic_partitions=true`, and `dtbo_idx` set or empty [I].
- **Stop if:** `slot_suffix=_b`. Stock then runs on slot B, and our model
  (stock on A, ours on B, never write `_a`) does not fit. Do not
  continue; report it in the ticket.
- **Rollback:** none (read-only).

Paste: `getprop-boot.txt` and the partition **names** from `by-name.txt`
(`awk '{print $(NF-2), $NF}' "$D/by-name.txt"` gives name and target
device, with no identifiers).

## Part C: fastboot, still locked (read-only)

```sh
adb reboot bootloader
fastboot getvar all 2>&1 | tee "$D/getvar-all-locked.txt"
fastboot reboot
```

- **Expect:** `unlocked:no`, `current-slot:a`, per-slot
  `slot-successful`/`slot-unbootable`/`slot-retry-count` lines, and
  `partition-size:`/`partition-type:` lines for both slots [I].
- **Stop if:** `current-slot:b` (see Part B), or fastboot does not see the
  phone. In that case check the cable, and on Linux the udev rules from
  android-tools. Do not try other fastboot commands.
- **Rollback:** `fastboot reboot`, or hold Power about 30 s.

Paste: every line except `serialno` (Part F filters it).

## Part D: unlock (first write; wipes all user data)

**Decision point for the owner. Nothing after this is undone by a
command.**

Preconditions: gate passed; Parts B-C pasted; everything on the phone
backed up; Settings → Developer options → **OEM unlocking** switched on.

```sh
adb reboot bootloader
fastboot oem unlock
```

- **Expect:** the phone shows an unlock confirmation. Choose unlock with
  the volume keys and confirm with Power. The phone wipes and reboots into
  first-time setup, showing the unlocked-bootloader warning at boot
  [I: OnePlus 8-series behaviour, as in the Lineage install guide].
- **Stop if:** fastboot returns an error. Do **not** try
  `fastboot flashing unlock` or any other variant on your own. Paste the
  error in the ticket.
- **Rollback:** none for the wipe; restore your data from backup after
  setup. **Do not relock.** Relocking is only safe on fully stock images.
  It is a separate decision and never part of this runbook.

After setup: enable Developer options and USB debugging again, then:

```sh
adb reboot bootloader
fastboot getvar all 2>&1 | tee "$D/getvar-all-unlocked.txt"
fastboot reboot
adb wait-for-device; adb shell getprop ro.boot.verifiedbootstate | tee "$D/vbstate-unlocked.txt"
```

- **Expect:** `unlocked:yes`, `current-slot:a`, and
  `verifiedbootstate=orange` [I].
- Paste both, filtered by Part F. They are evidence for the vbmeta
  grilling ticket.

## Part E: temporary root in RAM only (nothing flashed)

1. **Patch the stock boot image for exactly the installed build** (from
   `$REF/images/boot.img`). Install the Magisk app from its official
   GitHub release, push the image, and patch it in the app with
   *Install → Select and Patch a File*:

   ```sh
   adb push "$REF/images/boot.img" /sdcard/Download/stock-boot.img
   # patch in the Magisk app, then:
   adb pull /sdcard/Download/ "$REF/magisk/"      # keep magisk_patched-*.img only
   ```

   **Never** tap *Direct Install* or *Install to Inactive Slot* in Magisk.
   The first writes `boot_a`; the second writes slot B and changes the
   active slot. Both are forbidden here.

2. **Boot it once from RAM:**

   ```sh
   adb reboot bootloader
   fastboot boot "$REF"/magisk/magisk_patched-*.img
   ```

   - **Expect:** `Sending 'boot.img'… OKAY`, `Booting… OKAY`, and stock
     Android boots with Magisk active. The Magisk app may ask for
     "additional setup"; **decline** it (it would write to flash).
   - **Stop if:** fastboot answers `unknown command`, `not allowed`, or
     any FAILED. **Do not fall back to `fastboot flash boot`**: that
     writes `boot_a`, the slot stock runs from, which the safety model
     forbids. Paste the error; the coordinator replans.
   - **Rollback:** `adb reboot` (or hold Power). The phone comes back as
     unrooted stock, because nothing was written.

3. **Grant shell root and check that the OTA matches what is installed**
   (read-only):

   ```sh
   adb shell su -c id            # approve the Magisk prompt on the phone once
   S=$(stat -c %s "$REF/images/boot.img")
   adb exec-out "su -c 'head -c $S /dev/block/by-name/boot_a'" | sha256sum
   sha256sum "$REF/images/boot.img"
   ```

   - **Expect:** `uid=0(root)`, and the two hashes are equal.
   - **Stop if:** the hashes differ. Then the OTA on disk is not the
     installed build and the restore path is unproven. Reboot and go back
     to the restore-assets runbook.

4. **Capture with root** (all read-only; output only to the laptop):

   ```sh
   adb exec-out "su -c 'dmesg'"                 > "$D/dmesg.txt"
   adb exec-out "su -c 'cat /proc/cmdline'"     > "$D/cmdline-root.txt"
   adb exec-out "su -c 'cat /sys/firmware/fdt'" > "$D/live.dtb"
   dtc -I dtb -O dts -o "$D/live.dts" "$D/live.dtb" 2> "$D/dtc-warnings.txt"
   for f in iomem interrupts modules; do adb exec-out "su -c 'cat /proc/$f'" > "$D/$f.txt"; done
   adb exec-out "su -c 'ls -l /dev/block/by-name/'" > "$D/by-name-root.txt"
   for l in a b c d e f; do
     adb exec-out "su -c 'cat /sys/block/sd$l/queue/logical_block_size /sys/block/sd$l/size 2>/dev/null'" > "$D/sd$l-geometry.txt"
     adb exec-out "su -c 'dd if=/dev/block/sd$l bs=4096 count=6 2>/dev/null'" > "$D/gpt-sd$l.bin"
     python3 -I scripts/gpt-attrs.py "$D/gpt-sd$l.bin" > "$D/gpt-sd$l.txt" 2>&1
   done
   adb exec-out "su -c 'test -e /dev/block/by-name/devinfo && dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null'" > "$D/devinfo-head.bin"
   xxd "$D/devinfo-head.bin" | head -16 > "$D/devinfo-head.txt"
   ```

   - **Expect:** `live.dts` is a full device tree (it is fine if
     `/sys/firmware/fdt` is missing; then use STAGE-0 step 10's
     `/proc/device-tree` tar). `sd?-geometry.txt` shows `4096` as block
     size for the LUNs that exist. Each `gpt-sd?.txt` shows `crc:
     header=ok entries=ok`. LUNs that do not exist produce an empty
     file and an error, which is expected. `boot_a` should show `act 1`
     and `succ 1`, `boot_b` `act 0` [I: GPT model, `abl-boot-flow.md` §3].
     `devinfo-head.txt` is a short binary header; if `devinfo` does not
     exist, the file is empty.
   - **Stop if:** any CRC is `BAD` on a LUN that exists. The dump is then
     incomplete; rerun that LUN only. No other failure here is dangerous.
   - **Rollback:** `adb reboot`. Root is gone, and nothing was written.

5. `adb reboot`. Root is gone after the reboot.

## Part F: answer the six questions, redact, post

Extraction helpers (laptop only):

```sh
grep -E '^(name|boot|dtbo|vbmeta|super|userdata)' "$D"/gpt-sd?.txt   # Q1, Q3: which LUN holds what
grep -E 'slot-(successful|unbootable|retry-count)|current-slot' "$D/getvar-all-unlocked.txt"   # Q2
grep -E 'boot_[ab]|dtbo_[ab]' "$D"/gpt-sd?.txt                         # Q2: act/succ/unboot bits
cat "$D/devinfo-head.txt"                                              # Q2: devinfo role
cat "$D/getprop-boot.txt" | grep dtbo_idx                              # Q4
tr ' ' '\n' < "$D/cmdline-root.txt" | grep -Ei 'dsi|panel|console|earlycon|dtbo|androidboot.(slot|verified|mode)'   # Q4-Q6
grep -nE 'stdout-path|serial@|geni-debug|qcom,msm-geni' "$D/live.dts" | head -20               # Q6
grep -nE 'qcom,mdss_dsi_.*panel|panel-name|qcom,dsi-display' "$D/live.dts" | head -20          # Q5
```

Write the answers into a draft `"$D/808-draft.md"` (template below), then
run the **redaction check**. It must print nothing:

```sh
SER=$(grep -i 'serialno' "$D/getvar-all-locked.txt" | awk '{print $NF}')
grep -nEi 'serialno|imei|meid|wlan.*mac|bt.*addr|local-mac-address|([0-9a-f]{2}:){5}[0-9a-f]{2}|\b[0-9]{15}\b' "$D/808-draft.md"
[ -n "$SER" ] && grep -nF "$SER" "$D/808-draft.md"
```

- **Stop if:** anything prints. Remove it and rerun.

Then the owner posts the draft as a comment in
derekross/omarchy-mobile#808 (agents have no write access upstream), and
pastes the comment link into the stage-0 ticket.

### Draft template (English, upstream-bound)

```markdown
## Stage 0: stock facts from an IN2023 (EU), build <build string>

Captured read-only (temporary root via `fastboot boot`, nothing flashed). Raw captures stay private.

1. **Boot images:** <list from payload + by-name>; no init_boot/vendor_boot/vendor_kernel_boot: <yes/no>. Stock boot.img header v<N>, page size <N>, DTB in boot.img: <yes/no>.
2. **Slot flags:** GPT attributes on LUN <X>: boot_a byte6=<0x..> (active/successful), boot_b byte6=<0x..>; devinfo: <what it holds / absent>.
3. **GPT/LUN layout:** boot_a/boot_b/dtbo_b on LUN <X>, super on LUN <X>, userdata on LUN <X> (logical block size 4096; primary entries span LBA <a..b>, backup header at LBA <n>).
4. **Board dtbo:** ro.boot.dtbo_idx=<value>; stock dtbo.img has <N> entries (id/rev <...>).
5. **Panel:** <panel node / compatible from live DT or cmdline>.
6. **UART:** stdout-path <...> → <node>@<reg>; console/earlycon on stock cmdline: <...>.

Bootloader: unlocked via `fastboot oem unlock`; verified boot state after unlock: <orange/...>.

Could instantnoodlep be listed under Wanted in docs/DEVICES.md, pointing at this issue?
```

**Resolved when:** the #808 comment is posted, and the stage-0 ticket has
its link plus the capture **path** (never the contents).
