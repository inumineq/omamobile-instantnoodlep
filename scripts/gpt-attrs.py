#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Decode a primary-GPT dump taken read-only from a phone LUN (stage 0).

Input: a file holding the first sectors of one UFS LUN, for example
captures/<date>/gpt-sda.bin from

    adb exec-out "su -c 'dd if=/dev/block/sda bs=4096 count=6 2>/dev/null'"

This script reads that FILE only. It never opens a block device and never
writes anything. It prints the GPT header geometry (needed to name the four
sectors of a slot-flag change: LBA 1, entries, last-1, last) and, for every
A/B partition, the Qualcomm slot bits held in attribute bits 48-55.

Qualcomm layout of attribute byte 6 (bits 48-55), per linux-msm/qbootctl
gpt-utils.h: bit 50 = active, bit 54 = boot successful, bit 55 = unbootable
[V]; bits 48-49 = priority and bits 51-53 = retry count [I, AOSP convention].

Disk and partition GUIDs are unique per unit and are NOT printed.
"""

import argparse
import struct
import sys
import zlib


def die(msg):
    print(f"gpt-attrs: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dump", help="file with LBA 0.. of one LUN (read-only copy)")
    ap.add_argument("--sector-size", type=int, default=4096,
                    help="logical block size of the LUN (UFS: 4096)")
    ap.add_argument("--all", action="store_true",
                    help="list every partition, not only _a/_b ones")
    args = ap.parse_args()

    ss = args.sector_size
    with open(args.dump, "rb") as f:
        data = f.read()
    if len(data) < 2 * ss:
        die(f"{args.dump}: shorter than two sectors of {ss} bytes")

    hdr = data[ss:2 * ss]
    if hdr[0:8] != b"EFI PART":
        die("no 'EFI PART' signature at LBA 1; wrong --sector-size or not a GPT LUN")
    (hdr_size,) = struct.unpack_from("<I", hdr, 12)
    (hdr_crc,) = struct.unpack_from("<I", hdr, 16)
    my_lba, alt_lba, first_use, last_use = struct.unpack_from("<QQQQ", hdr, 24)
    ent_lba, = struct.unpack_from("<Q", hdr, 72)
    n_ent, ent_size, ent_crc = struct.unpack_from("<III", hdr, 80)

    check = bytearray(hdr[:hdr_size])
    check[16:20] = b"\0\0\0\0"
    hdr_ok = (zlib.crc32(check) & 0xFFFFFFFF) == hdr_crc

    ent_bytes = n_ent * ent_size
    start = ent_lba * ss
    if len(data) < start + ent_bytes:
        die(f"dump too short for the entry array: need {start + ent_bytes} bytes,"
            f" have {len(data)}; dump more sectors")
    table = data[start:start + ent_bytes]
    ent_ok = (zlib.crc32(table) & 0xFFFFFFFF) == ent_crc

    ent_sectors = (ent_bytes + ss - 1) // ss
    print(f"header: my_lba={my_lba} alternate_lba={alt_lba} "
          f"usable={first_use}..{last_use}")
    print(f"entries: lba={ent_lba} count={n_ent} size={ent_size} "
          f"(spans LBA {ent_lba}..{ent_lba + ent_sectors - 1})")
    print(f"crc: header={'ok' if hdr_ok else 'BAD'} entries={'ok' if ent_ok else 'BAD'}")
    print(f"backup GPT: entries end at LBA {alt_lba - 1}, header at LBA {alt_lba}")
    print()
    print(f"{'name':<24} {'first':>10} {'last':>10}  byte6  prio act retry succ unboot")

    for i in range(n_ent):
        e = table[i * ent_size:(i + 1) * ent_size]
        if e[0:16] == b"\0" * 16:
            continue
        first, last, attrs = struct.unpack_from("<QQQ", e, 32)
        name = e[56:128].decode("utf-16-le", "replace").split("\0", 1)[0]
        if not args.all and not (name.endswith("_a") or name.endswith("_b")):
            continue
        b6 = (attrs >> 48) & 0xFF
        prio = b6 & 0x3
        act = (b6 >> 2) & 0x1
        retry = (b6 >> 3) & 0x7
        succ = (b6 >> 6) & 0x1
        unb = (b6 >> 7) & 0x1
        print(f"{name:<24} {first:>10} {last:>10}  0x{b6:02x}  {prio:>4} {act:>3} "
              f"{retry:>5} {succ:>4} {unb:>6}")

    if not (hdr_ok and ent_ok):
        die("CRC mismatch: the dump is incomplete or the sector size is wrong")


if __name__ == "__main__":
    main()
