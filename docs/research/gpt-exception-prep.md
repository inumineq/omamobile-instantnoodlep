<!-- SPDX-License-Identifier: MIT -->
# GPT-attribute exception: preparation for instantnoodlep

Ticket: "Slot-B bootable marking on Qualcomm: the named GPT-attribute
exception" (blocked). This note **prepares** the ticket. It does not
resolve it, and it authorises no command on the phone. It matters only for
M1b (the persistent slot-B install); M1a is RAM-only and writes no GPT
(`device/instantnoodlep/BRINGUP-M1-PLAN.md`). Nothing here has run on the phone. Every value in `{{...}}`
comes from stage 0 or from later gated steps.

Evidence marks: [V] = checked, with a URL or file:line. [I] = inference,
to be checked on the device or with the maintainer. Upstream citations are
pinned to `derekross/omarchy-mobile` main at `6c11752` (2026-11-15 19:28
UTC) unless a PR head is named.

Short names used below:

- `UP` = https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4
- `QB` = https://github.com/linux-msm/qbootctl/blob/39a6e6daaf029fb0a083777679a15ea2c18f72de
- `ABL` = https://github.com/Project-Aloha/mu_aloha_platforms/blob/cf5dcae4d15ee9e01faae69e03a2a279bf97e832/Platforms/QcomModulePkg
  (a public copy of Qualcomm's BSD-3 `QcomModulePkg`, Linux Foundation
  copyright. It is the generic Qualcomm ABL. OnePlus ships its own build,
  so every ABL behaviour below is [V] for the generic source and [I] for
  this phone.)
- `M651` = https://github.com/matthewjaybarr-png/omarchy-mobile/blob/bb532d35c540754f4f876b775b00ddd91e8a18ff
  (head of upstream PR #651, open)

---

## 0. Process first: who writes the entry

- [V] The entry belongs to the maintainer and lands in its own change. A
  device PR never writes its own exception. Sources: the maintainer on
  #432, "exceptions go to me first"
  (https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6669705246),
  and "send it as its own pull request rather than inside the device PR"
  (https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6709637591).
  The maintainer's review of #616 (2026-11-11 00:11 UTC) went further:
  "The entry has to come from me, in its own change ... Please take the
  `AGENTS.md` and `CONTRIBUTING.md` changes out; I'll use your numbers"
  (https://github.com/derekross/omarchy-mobile/pull/616).
- [V] The model that worked for enchilada: the port supplies the numbers
  in its NOTES, plus a tool and a gated runbook. The maintainer then writes
  the rule and the entry
  (https://github.com/derekross/omarchy-mobile/pull/651, maintainer
  comments of 11-11, 11-12 and 11-13).
- [I] So the deliverable for upstream is **not** a PR that edits
  CONTRIBUTING §3.1. It is: (a) the numbers and the plan in
  `device/instantnoodlep/` (NOTES plus a `*-PLAN.md`); (b) the text in §5
  below, offered in #808 as a suggestion the maintainer may reuse. House
  rule 6 (AGENTS.md:24-25) also asks for the plan before any code.

## 1. The upstream rule, exactly

[V] `UP/CONTRIBUTING.md#L60`:

> Qualcomm A/B phones (Pixel 4 family) store the slot flags in the
> partition table (GPT attributes), and flashing `boot_b` clears
> `slot-successful:b`. Marking slot B bootable means writing four GPT
> sectors on the boot LUN, which the storage guard can't block. It is
> allowed only as a narrow, per-device exception, written into this section
> before it is used: the device, the LUN, the sectors (LBAs 1, 2, last-1
> and last), the attribute bit and the CRCs it rewrites. The device's plan
> records the slot flags before and after, the rollback for a corrupted
> GPT, and the way back (stock restored on slot A first, or the owner's
> written acceptance of buttons-only recovery). It runs by hand, once per
> install of slot B's boot image, never from a service or at boot. No
> device has an entry yet.

[V] `UP/AGENTS.md#L14` repeats it with the same required items: the LUN,
the four sectors, the attribute bit, the CRCs; then in the plan the slot
flags before/after, the GPT rollback, and the way back.

So the **entry** must name: (1) the device, (2) the LUN, (3) the four
sectors, (4) the attribute bit, (5) the CRCs it rewrites. The **plan**
must hold: (6) slot flags before and after, (7) rollback for a corrupted
GPT, (8) the way back. (9) By hand, once per install of `boot_b`, never
from a service or at boot.

Existing entries: **none**. [V] The text still says "No device has an
entry yet" (`UP/CONTRIBUTING.md#L60`, fetched 2026-11-15). The table under
"Phones without A/B slots" (`UP/CONTRIBUTING.md#L77-L81`, dipper) is a
different exception type and is no template for a GPT write.

Pending rewording: [V] the maintainer wrote on #651 (2026-11-12) that
enchilada's numbers "will go into it as they are (LBA 1, 3, 786428 and
786431 on `sde`), which also means my rule's 'LBAs 1, 2, last-1 and last'
needs rewording, since it describes another phone's table." [I] Expect
the rule to become "primary header, the primary entry sector holding slot
B's boot partition, the matching backup entry sector, and the backup
header". That is the shape of `SLOT_B_MARK` (§3.4).

## 2. Precedents

| Device (SoC) | Where | What it shows |
| --- | --- | --- |
| Pixel 4 `flame` (SM8150) | PR #58 (open, held), `device/flame/BOOT-PLAN.md` at `wirelessjoe/omarchy-mobile@1950c72`, lines 68-117 | [V] This created the rule (#60, merged 2026-10-26). A four-sector SG_IO write, backup first, of the success bit and two CRCs. Measured layout: 4096-byte sectors, 15 entries, `boot_b` = entry 6, so all entries fit in LBA 2. That is where "LBAs 1, 2, last-1 and last" comes from. Maintainer's conditions (https://github.com/derekross/omarchy-mobile/pull/58, 2026-10-26 23:43): GPT rollback and who runs it, the way back, slot flags before/after. No entry landed. Stale since 11-07. |
| Pixel 4 XL `coral` (SM8150) | `UP/device/coral/BRINGUP-M1.md#L134-L189` | [V] An earlier hand write of bit 54 on `boot_a`, with `sfdisk --part-attrs`, 18 runs. It is marked "historical, do not repeat". The policy note lists what coral's own entry must name and says "`coral` cannot inherit `flame`'s pending entry". No §3.1 text drafted. |
| OnePlus 6 `enchilada` (SDM845) | #432, #616 (closed), #651 (open), `UP/device/enchilada/NOTES.md#L28-L102`, `M651/device/enchilada/NOTES.md#L104-L164` | [V] The closest model, and the first Qualcomm phone with numbers. LUN `sde` (UFS LUN 4); 4096-byte sectors, last LBA 786431; 96 entries; primary entries LBA 2-4; backup entries LBA 786427-786429; `boot_b` = entry 38, byte 768 of LBA 3 and of LBA 786428. Proposed `SLOT_B_MARK="sde boot_b 1 3 786428 786431"`. `abl_a`/`abl_b` are on `sde`, so a doubly broken table means EDL only. The entry is still waiting on the maintainer. |
| POCO F3 `alioth` (SM8250) | PR #25 (closed 2026-11-12), `bc-abe/omarchy-mobile@2a9b1cd` | [V] No GPT write at all. `tools/alioth/install.py:55-66`: `erase dtbo_b`, `flash boot_b`, `--set-active=b`, `reboot`. It refuses unless `current-slot` is `a` (`install.py:166-167`). Descriptor: `BOOT_IMAGES="boot"`, `UFS_RW="userdata"` (boot_b is not even guard-writable). No LUN handling. FLASH-RUNBOOK lines 211-214: "Automatic Xiaomi A/B boot-success marking is not implemented. Avoid repeated failed boots; if the bootloader changes slots, use physical FASTBOOT and reselect B." The maintainer ruled that the installer must be a branch of `tools/install-phone`, not a second installer with its own exception (PR #25, 2026-10-27 14:25). |

[I] Lesson for instantnoodlep: we need the same numbers as enchilada
(measured, not assumed), the same tool (#651's `tools/mark-slot-b`, once
merged), and our own entry. Nothing is inherited. "Other devices get their
own entry once they've measured their own layout" (#58, 2026-10-26).

## 3. Mechanics: what a "mark" writes, and what else writes the GPT

### 3.1 GPT layout and how the four LBAs follow from it

- [V] Entry fields: type GUID at offset 0, unique GUID at 16, first/last
  LBA at 32/40, attributes at 48, name at 56; entries are 128 bytes
  (`QB/gpt-utils.h#L53-L61`). Header fields: header size at 12, header CRC
  at 16, my LBA at 24, alternate LBA at 32, entry-array LBA at 72, entry
  count at 80, entry size at 84, entry-array CRC at 88
  (`QB/gpt-utils.h#L41-L51`).
- [V] Slot bits live in attribute byte 6 (`AB_FLAG_OFFSET = 48 + 6`):
  active = `1<<2` (bit 50), successful = `1<<6` (bit 54), unbootable =
  `1<<7` (bit 55) (`QB/gpt-utils.h#L63-L69`). qbootctl does not define
  priority or retry. The generic ABL does: priority = bits 48-49, active =
  50, retry count = bits 51-53, successful = 54, unbootable = 55,
  `MAX_PRIORITY 3`, `MAX_RETRY_COUNT 7`, `MAX_NUM_PARTITIONS 128`
  (`ABL/Include/Library/PartitionTableUpdate.h#L108-L121`). The enchilada
  readings agree with this layout
  (https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6716747930).
- [V] The generic ABL rewrites a fixed area for each copy: one header
  block plus `MAX_NUM_PARTITIONS*128/BlkSz` entry blocks. It writes from
  LBA 1 for the primary and from `last+1 - (1 + 16384/BlkSz)` for the
  backup, so the backup entries start at `last - 4` on a 4096-byte disk
  (`ABL/Library/BootLib/PartitionTableUpdate.c#L297-L328`). [I] That
  matches enchilada: entries at 786427 = last-4, and LBA 786430 unused. So
  **"last-1" is generally not the backup entry sector** on these phones.
- Formulas (with `SS` = logical sector size, `IDX` = index of `boot_b`,
  `PENT` = primary entry-array LBA from the primary header, `BENT` =
  backup entry-array LBA from the backup header, `LAST` = last LBA):
  - `P_HDR = 1`, `B_HDR = LAST` (the primary header's alternate-LBA field)
  - `P_ENT = PENT + floor(IDX*128 / SS)`
  - `B_ENT = BENT + floor(IDX*128 / SS)`
  - byte of bit 54 inside that sector = `(IDX*128 mod SS) + 54`, mask
    `0x40`
  - `LAST = size512*512/SS - 1`. `/sys/block/sdX/size` is in 512-byte
    units (the stage-0 runbook, `docs/runbooks/STAGE-0-RUNBOOK.md` D4 Expect).
- What the CRCs are: the entry-array CRC is a CRC-32 over `count*128`
  bytes, stored at header offset 88 in **both** headers. Each header CRC is
  a CRC-32 over `header_size` (92) bytes with its own CRC field zeroed,
  stored at offset 16 (`QB/gpt-utils.c#L709-L736`,
  `ABL/Library/BootLib/PartitionTableUpdate.c#L412-L433`). It is the
  standard reflected CRC-32 (`QB/crc32.c#L130-L145`), the same as Python's
  `zlib.crc32`. One mark therefore changes 8 attribute bytes in each entry
  sector, 4+4 bytes in each header, and nothing else. [V] #651's tool
  checks exactly this (`M651/tools/mark-slot-b#L185-L190`).

### 3.2 How qbootctl rewrites the GPT (the reference asked for), and why we must not use it

- [V] Resolving the disk: `/dev/disk/by-partlabel/<name>` → realpath →
  trailing digits stripped → the whole-disk node `/dev/sdX`
  (`QB/gpt-utils.c#L294-L323`). It opens that **whole-disk node** `O_RDWR`
  (`QB/gpt-utils.c#L755`).
- [V] Reading: the primary header at byte `block_size` (LBA 1). The backup
  header at `lseek(SEEK_END) - block_size` (the last LBA)
  (`QB/gpt-utils.c#L418-L440`). Each entry array is read from its own
  header's entry-LBA field, `count*entry_size` bytes
  (`QB/gpt-utils.c#L456-L495`). [V] On read it checks **neither the
  signature nor either CRC**. `gpt_disk_get_disk_info` computes header
  CRCs without zeroing the CRC field ("FIXME") and never compares them
  (`QB/gpt-utils.c#L631-L673`). It does not compare the two arrays either.
- [V] Changing: `mark_boot_successful` → `update_slot_attribute(...,
  ATTR_BOOT_SUCCESSFUL)` sets bit 6 of byte 6 in the primary **and** backup
  entry of **every slot-suffixed partition in `g_all_ptns`** that has both
  `_a` and `_b` (abl, aop, apdp, cmnlib*, devcfg, dtbo, hyp, keymaster,
  msadp, qupfw, storsec, tz, vbmeta*, boot, system, vendor, modem,
  system_ext, product). It commits each disk in turn, so **several LUNs**
  are written (`QB/bootctrl_impl.c#L171-L263`, list at
  `QB/gpt-utils.h#L80-L88`). If the slot is unbootable, it first flips the
  unbootable bit (`QB/bootctrl_impl.c#L420-L425`).
- [V] Committing (`gpt_disk_commit`, `QB/gpt-utils.c#L741-L800`):
  1. `gpt_disk_update_crc` recomputes both entry-array CRCs, writes them at
     offset 88 of both headers, zeroes offset 16, and recomputes each header
     CRC over `header_size` (`QB/gpt-utils.c#L698-L738`);
  2. it writes the primary header (one block at LBA 1)
     (`QB/gpt-utils.c#L365-L375`);
  3. it writes the **whole** primary entry array (`count*128` bytes, e.g. 3
     blocks for 96 entries, not one sector) (`QB/gpt-utils.c#L497-L528`);
  4. it writes the backup header (one block at the last LBA);
  5. it writes the whole backup entry array at the backup header's
     entry-LBA field.

  Each `write()` is followed by `fsync()` (`QB/gpt-utils.c#L148-L177`).
  Within each copy the header goes before the array, so during steps 2-3
  (and 4-5) that copy is invalid. The other copy is still intact then.
- [V] `set_active_boot_slot` does more than flip attributes. It rewrites
  the type GUIDs and attribute byte 6 of every `g_all_ptns` pair
  (`UPDATE_SLOT`: the active slot's byte 6 becomes `0x0F`)
  (`QB/bootctrl_impl.c#L74-L82`, `#L454-L568`). Then it switches the UFS
  boot LUN (bBootLunEn, the XBL A/B choice) through BSG
  (`QB/bootctrl_impl.c#L601-L613`, `QB/gpt-utils.c#L236-L287`).
- [I] Conclusion: qbootctl is a good reference for bit meanings and the
  CRC arithmetic. Its write scope is **far outside** a narrow exception:
  many partitions, several LUNs, whole arrays, no validation, whole-disk
  `O_RDWR`. The plan must say "qbootctl is never run on this phone" and the
  device package must not ship it. For the reader's slot state, it reads
  only `boot_a`/`boot_b` (`QB/bootctrl_impl.c#L320-L332`). The generic ABL
  likewise reads successful/unbootable/retry only from the boot entry
  (`ABL/Library/BootLib/PartitionTableUpdate.c#L1619-L1633`). So marking
  **only `boot_b`** should be enough for ABL [I on the OnePlus build;
  proven only by `getvar slot-successful:b` = `yes` after the write].

### 3.3 What ABL itself writes to the GPT (outside our control)

All [V] for the generic source and [I] for the OnePlus build:

- **`fastboot flash boot_b` / `erase boot_b`**: `FastbootUpdateAttr` clears
  successful and unbootable on `boot_b`, sets priority 3 and retry 7, and
  writes the GPT (`ABL/Library/FastbootLib/FastbootCmds.c#L1024-L1049`,
  called at `#L1116-L1119` and `#L2084`). This is the "flashing `boot_b`
  clears `slot-successful:b`" of `UP/CONTRIBUTING.md#L60`.
- **`fastboot --set-active=<s>`** → `CmdSetActive` → `SetActiveSlot(&s,
  TRUE)` (`FastbootCmds.c#L2096-L2196`). On `boot_<s>`: priority 3, active,
  retry 7, unbootable cleared, **successful cleared** (ResetSuccessBit is
  TRUE). On the other slot's boot entry: active cleared, priority 2
  (`PartitionTableUpdate.c#L1390-L1414`). When the slot actually changes,
  it also calls `SwitchPtnSlots`, which **swaps the type GUIDs of every
  `_a`/`_b` pair** and **switches bBootLunEn** between UFS LUN 1 and 2,
  i.e. `xbl_a` ↔ `xbl_b` (`#L539-L619`). `MarkPtnActive` then sets or
  clears bit 50 on **every** partition by suffix (`#L463-L476`).
  `UpdatePartitionAttributes` writes both copies on **every LUN** whose
  entries changed (`#L262-L450`). The fastboot handler then writes again
  (`PARTITION_ALL`, `FastbootCmds.c#L2194`).
- Even `--set-active=a` with A already current clears A's successful bit
  and writes (`PartitionTableUpdate.c#L1390-L1399`, `#L1415-L1440`). [I]
  Stock Android normally sets it again after a good boot through its
  boot-control HAL.
- **Every boot of an unmarked slot**: `FindBootableSlot` decrements retry
  and writes the GPT. At retry 0, or when unbootable, it goes to
  `HandleActiveSlotUnbootable` and the other slot
  (`PartitionTableUpdate.c#L1635-L1656`). It calls `MarkPtnActive` on every
  boot (`#L1663`).
- `fastboot flash partition:<lun>` (a whole GPT image) exists only with
  `ENABLE_UPDATE_PARTITIONS_CMDS` and is a "critical" partition
  (`FastbootCmds.c#L130-L135`, `#L1808-L1838`). [I] It is neither available
  nor allowed for us. It is listed only so that the rollback section can
  rule it out.

### 3.4 The tool upstream expects: `tools/mark-slot-b` (PR #651, open)

[V] Everything in this subsection is from `M651/tools/mark-slot-b` and the
#651 thread.

- Descriptor key `SLOT_B_MARK="LUN PART P_HDR P_ENT B_ENT B_HDR"`. It is
  documented in the PR's `docs/RELEASES.md` as set only once the device
  has its §3.1 entry. It is **not on main yet**. `UFS_RW_LUNS` is on main
  (#530, merged 2026-11-09; `UP/docs/RELEASES.md#L85`).
- Before any node is made, it checks: the first `compatible` string equals
  `COMPATIBLE`; the LUN is in `UFS_RW_LUNS`; `/sys/block/<lun>/ro` is 0;
  the sector size and last LBA match `B_HDR`; the phone booted slot B
  (`androidboot.slot_suffix=_b`) (`#L290-L308`).
- It reads both copies through a private node under
  `/run/omamobile-mark-slot-b` (a whole-disk node for that LUN), with
  `iflag=direct` (`#L56-L58`, `#L104-L109`). It validates both headers
  (signature, size 92, CRC, my-LBA, 128-byte entries), checks that the
  headers describe each other, that the arrays are identical, that the
  array CRC is right, that `PART` is found exactly once, and that it sits
  in the named LBAs (`#L122-L191`). It requires `PART` active and not
  unbootable (`#L338-L339`).
- It sets bit 54 only. It recomputes the entry-array CRC and both header
  CRCs and asserts that only those bytes change (`#L139-L145`,
  `#L174-L190`). Dry run by default; `--write` needs the typed `mark
  boot_b`.
- It saves the four old and four new sectors, with `SHA256SUMS`, under
  `~/android/reference/<device>/mark-slot-b-<lun>/` and keeps earlier sets
  under a dated name (`#L218-L243`). It re-reads the four sectors right
  before writing (`#L250-L251`).
- Write order: primary entry sector, primary header, read-back; then
  backup entry sector, backup header, read-back. A torn copy goes first
  (the maintainer's sort), so from a table with one valid copy, one valid
  copy remains after every single write (`#L246-L263`). Each sector is
  copied to a file on the phone, its SHA-256 checked, then `dd ...
  conv=notrunc,fsync` (`#L111-L119`).
- After an interrupted `--write`, the next run recognises the mix of old
  and new sectors and offers `mark boot_b` or `restore boot_b` under the
  typed confirmation (`#L312-L326`).

[I] Unlike qbootctl, this touches exactly four sectors on one LUN. That
is why the rule counts sectors.

## 4. Does `fastboot --set-active=b` count as a GPT write under upstream's reading?

Short answer: **yes, as a slot-flag write that ABL makes in the GPT.
Upstream gates it behind the same per-device entry. But the entry's
"four sectors" name only our mark, not set-active.**

- [V] The maintainer on #432: "Qualcomm keeps the slot flags in the
  partition table. As on the Pixel 4 ..., `--set-active=b` hands the slot
  to ABL, and marking slot B successful means writing GPT sectors ...
  That's allowed only as a named, per-device entry in CONTRIBUTING, and no
  device has one yet. So step 3 of your plan needs that conversation
  first." Step 3 was "Arch root on `userdata` + `boot_b`, `--set-active=b`"
  (https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6669705246).
- [V] The enchilada porter's commitment, which the maintainer accepted:
  "I won't touch slot flags again until there is a CONTRIBUTING entry for
  this phone" (#432 comment 6670371656) and "`--set-active=b` still waits
  for a CONTRIBUTING entry" (#432 comment 6670746000). Enchilada NOTES on
  main: "`--set-active`, which writes the GPT slot flags"
  (`UP/device/enchilada/NOTES.md#L55`); "No slot flag is written again
  until this phone has a per-device entry" (`#L70-L72`).
- [V] The maintainer's #616 review asks the runbook for "both slots' flags
  from `getvar` after `--set-active=b` and before the first boot". So
  set-active is part of the recorded, gated sequence
  (https://github.com/derekross/omarchy-mobile/pull/616, 2026-11-11 00:11).
- [V] In general, `UP/CONTRIBUTING.md#L64` and `UP/AGENTS.md#L13` treat
  `--set-active` as a write to "the bootloader's own storage" (`devinfo`
  on Pixels; the GPT on Qualcomm). The installer may make it in named
  cases only. `omamobile-install`'s device list is one "which no Qualcomm
  phone is on" (`UP/AGENTS.md#L13`).
- [V] The enchilada acceptance describes set-active as changing "slot A's
  active/priority flags, and nothing else on A"
  (https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6758389898).
- [I, with V source] The generic ABL source says set-active does **more**:
  it swaps type GUIDs of all `_a`/`_b` pairs, sets/clears bit 50 on every
  slotted partition, writes both GPT copies on every LUN that changed, and
  moves bBootLunEn to LUN 2, so the next cold boot runs `xbl_b`/`abl_b`
  (§3.3). If OnePlus's ABL does the same, "nothing else" understates it,
  and slot B's **bootloader firmware** must match slot A's before the first
  `--set-active=b` (`UP/CONTRIBUTING.md#L63`). This goes to the maintainer
  as an open question (§8, Q4/Q5), and stage 0 can partly measure it
  (§6.1).
- [V] In this repo, `docs/RESTORE-RUNBOOK.md` Path 0 is a plain reboot
  under M1a and allows `fastboot set_active a` only after an M1b slot
  switch, with slot flags recorded before and after.
  `device/instantnoodlep/BRINGUP-M1-PLAN.md` sends no `--set-active` in
  M1a. Stage 0 forbids it outright (`docs/runbooks/STAGE-0-RUNBOOK.md`,
  hard rules at the top). Under this reading it is an ABL slot-flag write,
  never a silent "no write" rollback.

## 5. Draft entry text (for the maintainer to reuse; not a PR)

Style follows `UP/CONTRIBUTING.md#L60` and the enchilada numbers. [I] The
shape assumes the maintainer's coming rewording (§1). `{{...}}` =
placeholder, filled per §7.

> - **OnePlus 8 Pro (`instantnoodlep`, SM8250), slot-B mark.** On this
>   phone the slot flags are GPT attributes of `boot_a`/`boot_b` on LUN
>   `{{LUN}}` (UFS LUN `{{UFS_LUN_ID}}`), a {{SS}}-byte-sector disk whose
>   last LBA is {{LAST}}, with {{N_ENT}} entries of 128 bytes; `boot_b` is
>   entry {{IDX}}. Marking slot B successful is allowed only with
>   `tools/mark-slot-b --device instantnoodlep`, by hand, once per install
>   of `boot_b`, from a boot of slot B, after its dry run. It sets
>   attribute bit 54 (successful) of `boot_b` and nothing else, and it
>   rewrites the entry-array CRC (header offset 88) and the header CRC
>   (offset 16) of both headers. It writes four sectors of `{{LUN}}`: LBA 1
>   (primary header), {{P_ENT}} (the primary entry sector holding
>   `boot_b`), {{B_ENT}} (the backup entry sector holding `boot_b`) and
>   {{LAST}} (backup header), the primary pair first and each pair read
>   back. Descriptor: `SLOT_B_MARK="{{LUN}} boot_b 1 {{P_ENT}} {{B_ENT}} {{LAST}}"`,
>   `UFS_RW_LUNS={{LUN}}` (omit if `{{LUN}}` is `sda`). The write goes
>   through a private whole-disk node for `{{LUN}}`, which also reaches
>   {{LUN_PARTS_SUMMARY}}; `abl_a`/`abl_b` are on `{{ABL_LUN}}`, `xbl_a`/`xbl_b`
>   on `{{XBL_LUNS}}`. Slot A holds stock OxygenOS {{STOCK_BUILD}}. The plan
>   is `device/instantnoodlep/{{PLAN_FILE}}`; it records the slot flags
>   before and after, the rollback for a corrupted table, and the way back.

Descriptor lines (in the device PR that comes after the entry, per the
#616 split):

```
UFS_RW="boot_b dtbo_b userdata"        # {{VBMETA_B?}} see Q7
UFS_RW_LUNS={{LUN}}                    # only if boot_b is not on sda
SLOT_B_MARK="{{LUN}} boot_b 1 {{P_ENT}} {{B_ENT}} {{LAST}}"
```

[V] Upstream's never-flash list includes `vbmeta` (`UP/CONTRIBUTING.md#L59`).
Our draft `device.conf:69` has `UFS_RW="boot_b dtbo_b vbmeta_b userdata"`
and `BOOT_IMAGES="boot dtbo vbmeta"`. `vbmeta_b` needs the maintainer's
word (Q7) before it goes anywhere near an entry.

## 6. The plan's required parts (to become `device/instantnoodlep/{{PLAN_FILE}}`)

### 6.1 Before/after recording procedure

Each row is a separate owner step, with Expect/Stop/Rollback as in the
stage-0 runbook (house rule 1). Read-only rows marked RO.

| # | When | What is recorded | How |
| --- | --- | --- | --- |
| R0 | stage 0, locked (B2) | both slots' `slot-successful/unbootable/retry-count`, `current-slot` | already in `STAGE-0-RUNBOOK.md` B2 (RO) |
| R1 | stage 0, unlocked (C3) | same | `STAGE-0-RUNBOOK.md` C3 (RO) |
| R2 | stage 0, temp root (D4/D5) | GPT head+tail of `sda`-`sdf`, LUN sizes, by-name map; `boot_a`/`boot_b` attributes | already in `STAGE-0-RUNBOOK.md` D4/D5 (RO). **Add, laptop only:** the parser in §6.4 for the LUN holding `boot_b`, giving `IDX`, `P_ENT`, `B_ENT`, `LAST` and the three CRCs. |
| R2b | stage 0, temp root | UFS LUN ids, bBootLunEn, `xbl`/`abl` LUNs; firmware equality across slots | **Now in `STAGE-0-RUNBOOK.md` D4 (RO), each `[I]` until run:** `ufs-luns.txt` (UFS boot LUN id per SCSI LUN and `boot_lun_enabled`) and `bootloader-ab.txt` (pairwise SHA-256 of the `_a`/`_b` firmware partitions, as enchilada did, #432 comment 6670371656). Only the comparison yes/no leaves the laptop. |
| R3 | install, after `flash boot_b`/`dtbo_b`, before set-active | both slots' flags | `fastboot getvar all` filtered (RO). Expect `slot-successful:b: no`, `retry-count:b: 7` [I, §3.3]. |
| R4 | after `--set-active=b`, **before** the first boot | both slots' flags; `current-slot: b` | as R3 (maintainer's #616 ask). Expect B: active, prio 3, retry 7, not successful; A: not active, prio 2, successful unchanged [I, §3.3]. |
| R5 | first boot of B, from the Arch root | `/proc/cmdline` slot suffix; `ls -l /dev/{{LUN}}`; `cat /sys/block/{{LUN}}/ro` and each partition's `ro`; `findmnt -no OPTIONS /run`; SHA-256 of `boot_b` vs the local image; GPT head+tail of `{{LUN}}` again | RO. Compare with R2: what did set-active change (attributes only, or type GUIDs on every pair too; other LUNs)? This answers Q4. All of these are #616/#651 review asks. |
| R6 | `tools/mark-slot-b --device instantnoodlep` (dry run) | its full output | posted for the maintainer's go before `--write` (#616 review) |
| R7 | `--write` | its output; the saved-sector path (path only) | by hand, once |
| R8 | after `--write`, in fastboot | `getvar slot-successful:b` = `yes`, then both slots' flags | proves bit 54 means "successful" to this ABL (#616 review) |
| R9 | next boot of B, then fastboot | `retry-count:b` unchanged | shows that a marked boot spends no try |
| R10 | one boot of B with no laptop attached, before (R4-R5) **and** after (R8) the mark | what happens (USB panic → reboot → retries → slot A?) | asked of enchilada on 11-05 and in the #616 review |

The NOTES table follows enchilada's form (`UP/device/enchilada/NOTES.md#L74-L84`):
read, `current-slot`, A s/u/r, B s/u/r, plus a column for `boot_b` attrs
and CRCs, filled from R0-R9.

### 6.2 Rollback for a corrupted GPT

| State on `{{LUN}}` after a failure | What still works [I] | Rollback, who runs it |
| --- | --- | --- |
| Write refused before any `dd` (any check failed) | everything | nothing to undo. Paste the output and stop. |
| One copy torn, the other valid (cut at the 2nd/3rd/4th sector) | ABL boots from the valid copy [I: not verified that OnePlus ABL falls back to the backup]; fastboot reachable | **Don't restart the phone.** The owner runs `tools/mark-slot-b --device instantnoodlep` again. It recognises the mix against the saved set and offers `mark boot_b` (finish) or `restore boot_b` (old sectors), typed (`M651/tools/mark-slot-b#L312-L326`). Prefer `restore` unless the maintainer says otherwise. |
| Both copies valid but different | as above | same tool, same choice. |
| Read-back mismatch (a write that didn't land) | as above | same tool. Tested in #651 (`DROP_AT`). |
| Saved sectors fail their `SHA256SUMS` | n/a | tool refuses. Stop and ask the maintainer. A hand `dd` is **not** a planned step. |
| Both copies invalid | If `abl_a`/`abl_b` are on `{{LUN}}`: no ABL, no fastboot, no `fastboot boot`, buttons useless; PBL still loads `xbl_{{a/b}}` from LUN {{XBL_LUNS}} | **EDL only** (Qualcomm 9008). The owner runs OnePlus's own recovery tool for IN2023, which rewrites the whole phone, wipes `userdata`, and (per `docs/RESTORE-RUNBOOK.md` Path 2) relocks. The two read-only copies of `{{LUN}}`'s GPT from R2 (and the tool's saved sectors) are kept off the repository. They are evidence, not a restore path we can run. Owner's written acceptance needed (§6.3). If `abl` is **not** on `{{LUN}}`: fastboot still starts, but the boot partitions on `{{LUN}}` are gone; still EDL or the maintainer's call. |

[V] The maintainer rejected "boot the rescue by the buttons" as a rollback
for "both invalid" when `abl` shares the LUN, and asked that the notes "say
what it would really mean" (#616 review). [V] On enchilada, `abl_a`/`abl_b`
were on `sde` with `boot_*`, and `xbl` was on LUNs 1/2
(https://github.com/derekross/omarchy-mobile/issues/432#issuecomment-6898302484).
[I] Typical Qualcomm UFS layouts put `abl` with `boot` on LUN 4, so expect
the EDL case to apply to us too, until R2/R2b says otherwise.

Not rollback tools, ever: qbootctl (§3.2), `sfdisk`/`sgdisk` on the
whole disk, `fastboot flash partition:*` (§3.3), MSM for another model
(`docs/RESTORE-RUNBOOK.md` Path 2 and "Never do").

### 6.3 The way back

- [V] Upstream allows two forms: stock restored on slot A first, or the
  owner's written acceptance of buttons-only recovery
  (`UP/CONTRIBUTING.md#L60`). [V] For enchilada, slot A was not stock, so
  the maintainer required written acceptance "saying what slot A holds"
  (#432 comment 6709637591). The porter added the EDL case after the #616
  review (#432 comments 6758389898 and 6786088654).
- [I] Our case differs. Slot A **is** stock (stage 0 Stop rules make sure
  `current-slot: a`), so form 1 is the natural way back: buttons → fastboot
  → `fastboot --set-active=a` (itself an ABL slot-flag write, §4) → stock
  boots. Because `userdata` then holds the Arch root, stock will ask for a
  factory reset (`docs/RESTORE-RUNBOOK.md` Path 0). Declining keeps the
  Arch root; accepting wipes it. Path 1 (fastbootd + full OTA, the owner's own recovery,
  `docs/RESTORE-RUNBOOK.md` Path 1) repairs stock's own partitions.
- [I] The doubly-invalid-GPT case bypasses both forms (EDL only), so the
  owner should still write the EDL acceptance in the plan, as enchilada
  did. Draft for the owner (owner's words, not an agent's):

  > I accept that if both copies of `{{LUN}}`'s partition table are ever
  > broken, the phone cannot load its bootloader, and the only way back is
  > Qualcomm's emergency download mode with OnePlus's own recovery tool
  > for IN2023. That wipes the whole phone, Arch root included, and may
  > relock the bootloader. Recovering that way is my job, outside the
  > project. Slot A holds stock OxygenOS {{STOCK_BUILD}}, untouched by the
  > project.

### 6.4 Offline parser for R2 (laptop only, reads two files)

Tested 2026-11-15 against a synthetic 4096-byte-sector GPT with an
ABL-style backup layout. Its LBAs and all three new CRCs agree byte for
byte with #651's `plan()`. A corrupted backup array and a wrong LUN size
both print `NO` and no `SLOT_B_MARK` line. Run as
`python3 -I gpt-mark-numbers.py captures/$D/gpt-head-sdX.bin captures/$D/gpt-tail-sdX.bin <size from luns.txt>`.
It prints no GUIDs.

```python
# SPDX-License-Identifier: MIT
# Offline, laptop only: reads two stage-0 dump files, writes nothing.
# usage: python3 -I gpt-mark-numbers.py gpt-head-sdX.bin gpt-tail-sdX.bin SIZE512 [boot_b]
import re, struct, sys, zlib
head, tail = (open(p, 'rb').read() for p in sys.argv[1:3])
size512, part = int(sys.argv[3]), (sys.argv[4] if len(sys.argv) > 4 else 'boot_b')
lun = (re.search(r'(sd[a-z])\.bin$', sys.argv[1]) or [None, '?'])[1]
def hdr(buf, off):
    h = buf[off:off + 512]
    if len(h) < 92 or h[:8] != b'EFI PART':
        return None
    size, crc = struct.unpack_from('<II', h, 12)
    my, alt = struct.unpack_from('<QQ', h, 24)
    ent, num, esz, ecrc = struct.unpack_from('<QIII', h, 72)
    ok = 92 <= size <= 512 and zlib.crc32(h[:16] + bytes(4) + h[20:size]) == crc
    return dict(ok=ok, crc=crc, size=size, my=my, alt=alt, ent=ent, num=num, esz=esz, ecrc=ecrc, raw=h)
for ss in (4096, 512):
    p = hdr(head, ss)
    if p:
        break
else:
    sys.exit('no primary GPT header at LBA 1')
last = size512 * 512 // ss - 1
first_tail = last - (len(tail) // ss - 1)
b = hdr(tail, (last - first_tail) * ss)
if not b:
    sys.exit('no backup GPT header at the last LBA %d (tail dump assumes %d-byte sectors)' % (last, ss))
n = p['num'] * p['esz']
po, bo = p['ent'] * ss, (b['ent'] - first_tail) * ss
if po + n > len(head) or bo < 0 or bo + n > len(tail):
    sys.exit('an entry array lies outside the dumps; dump more sectors')
pa, ba = head[po:po + n], tail[bo:bo + n]
checks = {
    'primary header CRC valid': p['ok'], 'backup header CRC valid': b['ok'],
    'primary at LBA 1, backup at last LBA': (p['my'], p['alt'], b['my'], b['alt']) == (1, last, last, 1),
    'entry count/size/CRC equal in both headers': (p['num'], p['esz'], p['ecrc']) == (b['num'], b['esz'], b['ecrc']),
    'primary entry-array CRC valid': zlib.crc32(pa) == p['ecrc'],
    'backup entry-array CRC valid': zlib.crc32(ba) == b['ecrc'],
    'entry arrays identical': pa == ba,
}
def name(i):
    return pa[i * p['esz'] + 56:i * p['esz'] + 128].decode('utf-16-le', 'replace').split('\0')[0]
def flags(a):
    return 'prio %d active %d retry %d successful %d unbootable %d' % (
        a >> 48 & 3, a >> 50 & 1, a >> 51 & 7, a >> 54 & 1, a >> 55 & 1)
hits = [i for i in range(p['num']) if name(i) == part]
checks['%s found exactly once' % part] = len(hits) == 1
print('LUN %s: %d-byte sectors, last LBA %d, %d entries of %d bytes' % (lun, ss, last, p['num'], p['esz']))
print('primary entries LBA %d-%d; backup entries LBA %d-%d; backup header LBA %d' % (
    p['ent'], p['ent'] + -(-n // ss) - 1, b['ent'], b['ent'] + -(-n // ss) - 1, last))
for k, v in checks.items():
    print('%-48s %s' % (k, 'yes' if v else 'NO'))
for i in range(p['num']):
    if name(i).rsplit('_', 1)[0] == part.rsplit('_', 1)[0]:
        a = struct.unpack_from('<Q', pa, i * p['esz'] + 48)[0]
        print('%-10s entry %3d attrs 0x%016x (%s)' % (name(i), i, a, flags(a)))
if len(hits) == 1 and all(checks.values()):
    i = hits[0]; off = i * p['esz']; sec = off // ss
    a = struct.unpack_from('<Q', pa, off + 48)[0]
    new = bytearray(pa); struct.pack_into('<Q', new, off + 48, a | 1 << 54)
    necrc = zlib.crc32(bytes(new))
    def hcrc(h):
        h = bytearray(h[:h and struct.unpack_from('<I', h, 12)[0]])
        struct.pack_into('<I', h, 88, necrc); struct.pack_into('<I', h, 16, 0)
        return zlib.crc32(bytes(h))
    print('%s: entry %d, byte %d of its entry sector; bit 54 = byte %d, mask 0x40' % (part, i, off % ss, off % ss + 54))
    print('four LBAs: P_HDR 1, P_ENT %d, B_ENT %d, B_HDR %d' % (p['ent'] + sec, b['ent'] + sec, last))
    print('CRCs as dumped: entries 0x%08x, primary header 0x%08x, backup header 0x%08x' % (p['ecrc'], p['crc'], b['crc']))
    print('if bit 54 were set on this dump: entries 0x%08x, primary 0x%08x, backup 0x%08x' % (necrc, hcrc(p['raw']), hcrc(b['raw'])))
    print('SLOT_B_MARK="%s %s 1 %d %d %d"' % (lun, part, p['ent'] + sec, b['ent'] + sec, last))
```

[I] The stage-0 dumps cover 6 sectors at each end
(`STAGE-0-RUNBOOK.md` D4). That is enough for up to 128 entries at
4096 bytes (primary LBA 2-5; backup last-4 to last-1). If `lbs` is 512,
the tail loop is wrong (D4 says so in its Expect). The parser
then exits with "no backup GPT header".

[I] The CRC values at stage 0 are a **baseline only**. `flash boot_b`
and `--set-active=b` rewrite the table (§3.3). Enchilada's NOTES say the
same: "`set-active b` rewrites all three, so the tool checks the live
values, not these" (`M651/device/enchilada/NOTES.md#L120-L124`). The
entry names **which** CRCs are rewritten. The values at the time of the
write come from the R6 dry run.

## 7. Placeholders and the step that fills each

| Placeholder | Meaning | Filled by |
| --- | --- | --- |
| `{{LUN}}` | disk holding `boot_b` (e.g. `sde`) | R2: `by-name-root.txt` (D4) + D5 grep; stage-0 Q10 (`docs/STAGE-0.md`) |
| `{{UFS_LUN_ID}}` | UFS LUN number of `{{LUN}}` | R2b |
| `{{SS}}`, `{{LAST}}` | sector size; last LBA = size/8-1 at 4096 | R2: `luns.txt` + parser |
| `{{N_ENT}}`, `{{IDX}}` | entry count; `boot_b` index | R2 parser |
| `{{P_ENT}}`, `{{B_ENT}}` | entry sectors holding `boot_b` | R2 parser; re-checked by R6 dry run |
| `{{ATTR_B_BEFORE}}` / `{{ATTR_B_AFTER}}` | `boot_b` attrs before the mark / after (= before \| `1<<54`) | R6 / R8 (baseline from R2, R4) |
| `{{ATTR_A_*}}` | `boot_a` attrs at R2, R4, R8 | R2, R5 dump, R8 |
| `{{ECRC_BEFORE/AFTER}}`, `{{PHCRC_*}}`, `{{BHCRC_*}}` | entry-array and header CRCs | R6 dry run (live); R2 baseline |
| slot-flag table rows | `current-slot`, A/B s/u/r | R0, R1, R3, R4, R8, R9 |
| `{{LUN_PARTS_SUMMARY}}` | partition names on `{{LUN}}` (names only) | R2 `by-name-root.txt` |
| `{{ABL_LUN}}`, `{{XBL_LUNS}}`, bBootLunEn | where `abl_*`/`xbl_*` live; current boot LUN | R2/R2b |
| `{{STOCK_BUILD}}` | stock build on slot A | A3 (`STAGE-0-RUNBOOK.md` A3) |
| `{{PLAN_FILE}}` | e.g. `SLOT-B-INSTALL-PLAN.md` | house rule 6 |

## 8. Open questions for the maintainer (#808)

Post these only after the stage-0 facts are in, as one comment drafted by
the coordinator and posted by the owner (`STAGE-0-RUNBOOK.md` §6).

1. **Process.** Same path as enchilada? We supply the numbers in NOTES and
   a gated plan, you write the instantnoodlep entry in your own change,
   and the device lines (`UFS_RW_LUNS`, `SLOT_B_MARK`, install path) follow
   in a PR after it. Does instantnoodlep reuse `tools/mark-slot-b` from #651
   unchanged once #651 lands?
2. **Rule shape.** Since "LBAs 1, 2, last-1 and last" is being reworded,
   is "LUN + `boot_b` + P_HDR, P_ENT, B_ENT, B_HDR" (the `SLOT_B_MARK`
   form) what our entry should state?
3. **RAM-only first.** May first light be a RAM-only `fastboot boot`
   (precedents: enchilada, flame, dipper in DEVICES.md), so that the entry
   gates only the persistent slot-B install?
4. **What `--set-active=b` writes on this ABL.** The generic Qualcomm ABL
   source swaps the type GUIDs of every `_a`/`_b` pair, sets or clears bit
   50 on every slotted partition, writes both copies on every LUN that
   changed, and moves the UFS boot LUN to `xbl_b` (§3.3). Should the plan
   record a before/after GPT of every LUN and bBootLunEn around the first
   `--set-active=b`, and should the entry or plan name that write, not only
   the mark?
5. **Bootloader slots.** `getvar` may report only the current slot's
   bootloader version. Is a read-only SHA-256 comparison of `abl/xbl/tz/...
   _a` vs `_b` from temporary root acceptable evidence for
   `UP/CONTRIBUTING.md#L63`? If they differ, is "sideload the full OTA from
   stock" the only accepted remedy, as written there?
6. **Way back.** Slot A will hold stock. Is form 1 enough, or do you want
   the owner's written EDL acceptance as well (as on #432), since a
   doubly broken table on the `abl` LUN bypasses slot A?
7. **`vbmeta_b`.** Our draft allowlist has `vbmeta_b`, and `vbmeta` is on
   the never-flash list. If stock `vbmeta_b` refuses our `boot_b` on an
   unlocked OnePlus ABL, what route do you accept (an unsigned AVB footer
   on `boot_b`, as coral did; a no-op `dtbo_b`; nothing)?
8. **No-USB panic.** On this ABL an unmarked B spends a try per boot (§3.3),
   and the initramfs USB panic spends them fast. Should the plan make
   R10 (a boot with no laptop) a gate before the mark, as you asked for
   enchilada?
9. **Who may run the rollback.** Is "the owner runs `mark-slot-b` again
   (finish/restore)" the whole rollback, with a hand `dd` from the saved
   sectors explicitly **not** allowed without your word?

## 9. Things found in our own tree while preparing this

Status on 2026-11-15, after #17 and #18:

- **Open** (ticket "device.conf"): [V] `device.conf:74` says "devinfo
  holds the slot flags" and `device.conf:76` puts `devinfo` in
  `NV_BACKUP_EXTRA`. Slot flags are GPT attributes and `devinfo` stays out
  of any write list (`docs/research/abl-boot-flow.md`, coordinator review
  and body). `vbmeta_b` in `UFS_RW` waits on Q7.
- **Fixed:** `set_active a` as a no-cost rollback. See §4.
- **Fixed:** the restore runbook no longer calls the EDL package
  "leaked"; Path 2 names OnePlus's own MSM Download Tool for IN2023.
- **Fixed:** `STAGE-0-RUNBOOK.md` D4 now records the R2b reads (UFS boot
  LUN ids, `boot_lun_enabled`, firmware comparison across slots), which
  saves a second root session.

## 10. Sources read

- Local: `AGENTS.md`; `device/instantnoodlep/NOTES.md`, `device.conf`,
  `BRINGUP-M1-PLAN.md`; `docs/runbooks/STAGE-0-RUNBOOK.md` (phases B2, C3,
  D4, D5, §6); `docs/STAGE-0.md` §5; `docs/RESTORE-RUNBOOK.md`;
  `docs/research/abl-boot-flow.md`.
- Upstream main `6c11752`: `CONTRIBUTING.md` (§3.1 L55-L81, §3.2
  L83-L93), `AGENTS.md` (L10-L14, L131), `docs/RELEASES.md` L85,
  `device/enchilada/NOTES.md`, `device/coral/BRINGUP-M1.md`,
  `device/coral/NOTES.md`, `device/flame/BRINGUP-M1.md`.
- Upstream issues/PRs: #432 (body and 13 comments), #616, #651 (head
  `bb532d3`: `tools/mark-slot-b`, `tests/mark-slot-b`, NOTES,
  RELEASES), #58 (head `1950c72`: `device/flame/BOOT-PLAN.md`), #17/#55/#56
  (metadata), #25 (head `2a9b1cd`: `tools/alioth/install.py`,
  `device/alioth/FLASH-RUNBOOK.md`, `BRINGUP-M1.md`, `device.conf`), #639
  (landed via #783), #530, #808 (open, 0 comments, 0 labels at 2026-11-15).
- linux-msm/qbootctl `39a6e6d`: `gpt-utils.h`, `gpt-utils.c`,
  `bootctrl_impl.c`, `crc32.c`, `qbootctl.c`.
- Generic Qualcomm ABL (Project-Aloha copy, `cf5dcae`):
  `Library/BootLib/PartitionTableUpdate.c`,
  `Include/Library/PartitionTableUpdate.h`,
  `Library/FastbootLib/FastbootCmds.c`. Read to describe the protocol
  only; no code copied (house rule 5).
