<!-- SPDX-License-Identifier: MIT -->
# Draft: stage-0 results comment for derekross/omarchy-mobile#808

Status: **DRAFT. Nothing here is posted upstream.** The coordinator fills
every `{{...}}` once the stage-0 facts are in, following
`docs/runbooks/STAGE-0-RUNBOOK.md` §6 (what may be pasted: no serials,
IMEI or MAC addresses) and `docs/runbooks/RESTORE-ASSETS.md`. The owner
then posts the filled comment on
[derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808);
agents have no write access upstream.

Each `{{...}}` names the runbook step whose output fills it. The "Known
facts so far" section is already filled from ticket #3's comments
(inumineq/omamobile-instantnoodlep#3, owner-run stage-0 phases A1-A5);
check those lines once more against the final captures before posting.
Tone follows upstream's CONTRIBUTING.md at `6c11752ae4c3`: plain
sentences, evidence over guesses, no promises, no device-PR content.

Everything between the `---` markers is the comment text.

---

Stage-0 facts for the OnePlus 8 Pro (IN2023, `instantnoodlep`, SM8250),
collected from my unit as promised in the issue body. Nothing was flashed
at any point. The only write in the whole process was the bootloader
unlock itself (`fastboot oem unlock`, which wiped userdata as expected).
The temporary-root session ran entirely from RAM: `fastboot boot` of a
Magisk-patched stock `boot.img` taken from the verified full OTA of the
running build. Slot A holds untouched stock again, and every later step
that could write is gated separately.

I would like first light to be **RAM-only**: a `fastboot boot` probe that
writes nothing, the same shape as enchilada's, flame's and dipper's first
lights. The persistent slot-B install would come later and is gated on
the GPT-attribute exception conversation in the questions below.

## Answers to the stage-0 questions

1. **Boot images present:** `boot`, `dtbo`, `vbmeta` and `vbmeta_system`,
   all slotted raw partitions (`partition-type:boot_a:raw` and friends).
   No `init_boot`, `vendor_boot` or `vendor_kernel_boot`, neither in
   `getvar all` nor in the OTA payload (44 partitions). Note this ABL
   prints `has-slot:` only for `boot`, `modem` and `system` (`no`); the
   `_a`/`_b` `partition-type:` lines are what show `dtbo`/`vbmeta` are
   slotted.
2. **Where the slot flags live:** {{Q2 — STAGE-0-RUNBOOK D5 (GPT
   attribute parser on the `boot_a`/`boot_b` entries) compared with B2
   (`getvar` slot flags). If they agree: GPT attributes, shown without
   writing anything.}}
3. **GPT/LUN layout around `super` and `userdata`:** fastbootd is
   reachable (`is-userspace:yes`); `super-partition-name:super`. `system`,
   `system_ext`, `vendor`, `product`, `odm` and ten Oplus `my_*`
   partitions are logical on slot A; `userdata` is physical
   (`is-logical:userdata:no`, `partition-size:userdata:0x36F3453000`,
   about 236 GB). No `partition-size:super` line is printed. Virtual A/B:
   right after the slot move every logical partition still had its `_a-cow`
   twin while `snapshot-update-status` already read `none`.
   {{Q3 — LUN of `boot_b`/`dtbo_b` vs `userdata`: STAGE-0-RUNBOOK D4
   (`by-name-root.txt`, `luns.txt`).}}
4. **Does the stock bootloader apply a board dtbo:** yes —
   `ro.boot.dtbo_idx=16`, re-confirmed on the A3 rerun after the slot move
   (that rerun differs from the pre-move capture only in
   `ro.boot.slot_suffix`). {{Q4 — `androidboot.dtbo_idx` in
   `/proc/cmdline`: STAGE-0-RUNBOOK D5.}}
5. **Panel node and its compatible in the live device tree:** {{Q5 —
   STAGE-0-RUNBOOK D4 (`live.dts`).}}
6. **UART base address for earlycon:** {{Q6 — STAGE-0-RUNBOOK D5
   (`stdout-path`/`serial@` greps of `live.dts`). Note: `serial0` in the
   community DTS is the Bluetooth UART, so this may be "none usable".}}
7. **Boot image header version, page size, offsets, stock cmdline:**
   header **v2**, page size **4096**, read offline from the stock `boot.img`
   of the verified `.591` OTA (R4, 2026-11-16).
   {{Q7 — offsets and stock cmdline: RESTORE-ASSETS R4, full
   `unpack_bootimg --format=info` output on the OTA's `boot.img`.}}
8. **Stock `vbmeta`: hash descriptors or chained partitions, which
   flags:** {{Q8 — RESTORE-ASSETS R4 (`avbtool info_image` on
   `vbmeta.img`).}}
9. **dtbo entries and which one ABL picks:** {{Q9 — RESTORE-ASSETS R4
   (`mkdtboimg.py dump`: entry count and `id`/`rev`/`custom`) mapped to
   `androidboot.dtbo_idx=16` (STAGE-0-RUNBOOK A3 and D5).}}
10. **Which UFS LUN holds `boot_b`/`dtbo_b`, which holds `userdata`:**
    {{Q10 — STAGE-0-RUNBOOK D4 (`by-name-root.txt`, `luns.txt`). This is
    the `UFS_RW_LUNS` input (#530).}}
11. **Does this ABL accept `fastboot boot`:** {{Q11 — STAGE-0-RUNBOOK D3
    (the Magisk-patched image booted from RAM, or the refusal).}}
12. **Wi-Fi PCI id and bootloader framebuffer geometry:** {{Q12 —
    STAGE-0-RUNBOOK A4/D4 (`pci-root.txt`; expected `17cb:1101`,
    QCA6390) and D4 (`/chosen` in `live.dts`; community DTS says
    1080x2376).}}

## Known facts so far

Collected from the locked, stock phone in the first read-only phase,
before the slot move and the unlock:

- Build: `IN2023_13.1.0.591(EX01)` (EEA), build date 2025-10-11. Public
  sources call `.590` final; this unit received `.591` over the air, so
  it is treated as the final EEA build here.
- Widevine security level **L1** on the locked stock build (the baseline
  for the after-unlock comparison).
- `ro.boot.dtbo_idx=16`: the stock bootloader applies a board dtbo
  (answers question 4).
- Slot situation: stock was found **running from slot B**
  (`ro.boot.slot_suffix=_b`). It was moved back to slot A by the stock
  updater's own local install of the final build's full zip (an A/B
  install writes the inactive slot; the zip was verified on the laptop
  first). The Oplus updater accepts a same-version local install: the A3
  rerun shows `ro.boot.slot_suffix=_a` on `IN2023_13.1.0.591(EX01)`, same
  fingerprint, still `flash.locked=1`, `vbmeta.device_state=locked`,
  `verifiedbootstate=green`.

## Questions for the maintainer

1. **Process.** Same path as enchilada? We supply the measured numbers
   in our NOTES plus a gated plan, you write the instantnoodlep §3.1
   entry in your own change, and the device lines (`UFS_RW_LUNS`,
   `SLOT_B_MARK`, install path) follow after it. And once #651 lands,
   does instantnoodlep reuse `tools/mark-slot-b` unchanged?
2. **Rule shape.** Since "LBAs 1, 2, last-1 and last" is being reworded,
   is the `SLOT_B_MARK` form (LUN + `boot_b` + P_HDR, P_ENT, B_ENT,
   B_HDR) what our entry should state?
3. **RAM-only first.** May first light be a RAM-only `fastboot boot`
   (precedents: enchilada, flame, dipper in DEVICES.md), so the entry
   gates only the persistent slot-B install?
4. **What `--set-active=b` writes on this ABL.** The generic Qualcomm
   ABL source swaps the type GUIDs of every `_a`/`_b` pair, sets or
   clears the active bit on every slotted partition, writes both GPT
   copies on every LUN that changed, and moves the UFS boot LUN to
   `xbl_b`. Should the plan record a before/after GPT of every LUN and
   the boot-LUN state around the first `--set-active=b`, and should the
   entry or plan name that write, not only the mark?
5. **Bootloader slots.** Is a read-only SHA-256 comparison of
   `abl/xbl/tz/...` `_a` vs `_b` from temporary root acceptable evidence
   for the matching-bootloader rule in CONTRIBUTING §3.1? If they
   differ, is "sideload the full OTA from stock" the only accepted
   remedy?
6. **Way back.** Slot A will hold stock. Is that form enough, or do you
   also want the owner's written EDL acceptance (as on #432), since a
   doubly broken table on the `abl` LUN bypasses slot A?
7. **`vbmeta_b`.** `vbmeta` is on the never-flash list. If stock
   `vbmeta_b` refuses our `boot_b` on an unlocked OnePlus ABL, what
   route do you accept: an unsigned AVB footer on `boot_b` (as coral
   did), a no-op `dtbo_b`, or nothing? (Answer 8 above records which
   descriptor stock `vbmeta` carries, from `avbtool info_image` on the
   stock image.)
8. **No-USB panic.** On this ABL an unmarked slot B spends a retry per
   boot, and the initramfs USB panic would spend them fast. Should the
   plan gate the mark on a boot with no laptop attached, as you asked
   of enchilada?
9. **Who may run the rollback.** Is "the owner runs `mark-slot-b` again
   (finish or restore)" the whole rollback, with a hand `dd` from the
   saved sectors explicitly not allowed without your word?

One data point that may matter for #828 (`install-phone` now stops unless
`current-slot` is exactly `a` or `b`): on this phone
`fastboot getvar current-slot` prints exactly `a` (no underscore), so
`install-phone`'s `a`/`b` check passes unchanged; nothing to report on
#828.

If the answers above look right, I would still be glad to see the phone
on the Wanted list in DEVICES.md, and I can collect further read-only
data on request.

---

Fill checklist for the coordinator (delete before posting):

- [ ] Every `{{...}}` replaced from the named runbook step's pasted
      output; none left.
- [ ] Redaction grep from STAGE-0-RUNBOOK §6 run on the final text.
- [ ] "Known facts so far" checked against the final captures (they were
      drafted from ticket #3's comments before the A3b move). If the
      same-version local install was refused, the slot bullet names the
      route that was taken from `docs/research/a3b-contingency.md`
      (PR #28), and the `current-slot` note below reflects the B2 rerun.
- [ ] No promises and no device-PR content; questions only.
