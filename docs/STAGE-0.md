<!-- SPDX-License-Identifier: MIT -->
# STAGE-0: stock facts for instantnoodlep (IN2023)

Read-only collection from the stock phone, in this order. Nothing here
modifies the device. Results go into `captures/<date>/` (gitignored) and
are summarised, redacted, into issue
[derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808).

`scripts/stage0-collect.sh` performs steps 1-2 automatically.

**To run it, use the gated runbooks** (command, Expect, Stop, Rollback per
step): `docs/runbooks/STAGE-0-RUNBOOK.md` for the phone and
`docs/runbooks/RESTORE-ASSETS.md` for the OTA and MSM package. The tables
below are the summary; where they differ, the runbooks win.

## 1. Before unlocking (phone on stock, booted)

| # | Command | Expect |
| --- | --- | --- |
| 1 | `adb shell getprop \| grep -Ei "model\|slot\|dtbo"` | `IN2023`, current slot (usually `a`), dtbo index if any |
| 2 | `adb shell ls -l /dev/block/by-name/` | full partition list: `_a`/`_b` slots, `super`, physical `userdata`, LUN layout |
| 3 | `adb shell getprop ro.boot.bootdevice` | UFS LUN paths, confirms dynamic partitions |
| 4 | Download the full stock OTA (payload.bin) for IN2023 and verify its checksum | restore path exists before anything is changed |

## 2. In fastboot

| # | Command | Expect |
| --- | --- | --- |
| 5 | `fastboot getvar all` | bootloader versions for both slots, partition sizes, current slot, unlock state |

## 3. Unlock (first write; wipes data)

| # | Command | Expect / stop condition |
| --- | --- | --- |
| 6 | Back up everything on the phone first | The unlock wipes all data |
| 7 | `fastboot oem unlock` | confirmation prompt on screen; no token, no waiting period |

## 4. Temporary root (nothing flashed)

| # | Command | Expect |
| --- | --- | --- |
| 8 | Extract stock `boot.img` from the OTA, patch it with Magisk, `fastboot boot magisk_patched.img` | stock boots with temporary root; nothing written to flash |
| 9 | `su -c dmesg > captures/<date>/dmesg.txt` | full stock dmesg |
| 10 | `su -c "tar -cf - /proc/device-tree" > captures/<date>/devicetree.tar` then `dtc -I dtb -O dts` | the live device tree the bootloader handed the kernel |
| 11 | `su -c cat /proc/iomem`, `/proc/interrupts`, `/proc/modules` | reserved-memory map (check every stock reserved-memory node), device usage |

## 5. Questions stage 0 must answer

1. Which boot images exist? (expected: `boot`, `dtbo`, `vbmeta`, maybe
   `vbmeta_system`; expected NOT: `init_boot`, `vendor_boot`,
   `vendor_kernel_boot`) [I]
2. Where do the slot flags live: GPT attributes or `devinfo`? [I]
3. Exact GPT/LUN layout around `super` and `userdata`? [I]
4. Does the stock bootloader apply a board dtbo (ro.boot.dtbo_idx)? [I]
5. What does the live device tree name the panel node and its compatible? [I]
6. UART base address for earlycon, from the live DT? [I]
7. Boot image header version, page size, offsets and stock cmdline, from
   `unpack_bootimg` on the OTA's `boot.img` (offline)? [I: v2, 4096, see
   `docs/research/abl-boot-flow.md`]
8. Does stock `vbmeta` carry `boot`/`dtbo` as hash descriptors or chained
   partitions, and with which flags (`avbtool info_image`, offline)? [I]
9. Which dtbo entries (id/rev/custom) does stock `dtbo.img` hold, and which
   does ABL pick (`androidboot.dtbo_idx`)? [I]
10. Which UFS LUN holds `boot_b`/`dtbo_b`, and which holds `userdata`
    (upstream `UFS_RW_LUNS`)? [I]
11. Does this ABL accept `fastboot boot` (RAM boot)? Proven by the Magisk
    step. [I]
12. Wi-Fi PCI id (expected `17cb:1101`, QCA6390) and the bootloader
    framebuffer geometry in `/chosen` (community DTS: 1080x2376)? [I]

## 6. Post

Redact (no serials, IMEI, MAC addresses) and post the answers as a comment
in issue #808, then ask for the phone to be added to the Wanted list in
upstream `docs/DEVICES.md`.
