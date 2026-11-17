<!-- SPDX-License-Identifier: MIT -->
# Qualcomm ABL DTBO selection on SM8250 / OnePlus 8 Pro

Research date: 2026-11-17. This records public source behavior and a ranked
diagnosis of the failed one-entry `dtbo_b` test. It does not establish which
exact ABL revision is installed on this OnePlus 8 Pro; public ABL source is a
reference implementation, not the phone's binary.

## Findings

- **[V]** In the public Qualcomm ABL source examined here, DTBO selection is
  based on root-node Qualcomm device-tree properties, not the DT table
  entry's `id`, `rev` or `custom[]`. `GetBoardDtb()` walks each table entry by
  its offset, checks the contained FDT, and calls `ReadDtbFindMatch()`; that
  matcher reads `qcom,msm-id`, `qcom,board-id`, optional PMIC properties, and
  conditionally `qcom,oem-id`. The table entry's matching metadata is not
  referenced in this walk. [V: [LocateDeviceTree.c
  `GetBoardDtb()`](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c#L1374-L1437),
  [LocateDeviceTree.c `ReadDtbFindMatch()`](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c#L908-L1023)]
- **[V]** In this implementation, a DTBO with no `qcom,msm-id` is not
  automatically rejected: the matcher logs that the property is absent and
  proceeds to board matching. A root `qcom,board-id` must still match for the
  candidate to win. `model` is read for diagnostics; `compatible` is not part
  of this match path. [V: [LocateDeviceTree.c
  `ReadDtbFindMatch()`](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c#L908-L1023),
  [LocateDeviceTree.c `GetBoardMatchDtb()`](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c#L760-L849)]
- **[V]** If the table is valid but no DTBO entry matches, this ABL code
  returns no board DTBO; its caller reports `Board Dtbo blob not found` and
  returns `EFI_NOT_FOUND`. If an entry does match, the selected FDT is passed
  to `ApplyOverlay()`, which calls `ufdt_apply_multi_overlay()`; the source
  does not gate selection on the presence of fragments or document what the
  applier returns for a zero-fragment FDT. **[V]** The assigned device report
  says stock DTBO entry 16 is root-properties-only and ABL applied its root
  properties on this phone, so the absence of fragments alone is unlikely to
  explain the new test's failure. [V: assigned device report, 2026-11-17]
  [V: [BootLinux.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/BootLinux.c#L491-L549),
  [BootLinux.c DTBO selection](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/BootLinux.c#L771-L788),
  [LocateDeviceTree.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c#L1374-L1437)]
- **[V]** AVB 2 in this public ABL requests `dtbo` as a verified partition.
  It sets `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR` when `IsUnlocked()`
  is true and continues for verification, rollback-index and public-key
  errors; I/O, invalid-metadata and unsupported-version errors are not
  recoverable in the shown code. Therefore a stale `vbmeta_b` hash by itself
  is not expected to stop boot on an unlocked device using this behavior, but
  unlocked state does not make malformed DTBO data or every AVB failure
  harmless. [V: [VerifiedBoot.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/avb/VerifiedBoot.c#L60-L68),
  [VerifiedBoot.c AVB flags](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/avb/VerifiedBoot.c#L1350-L1385),
  [VerifiedBoot.c result handling](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/avb/VerifiedBoot.c#L1578-L1603)]
- **[V]** The public ABL validates the DTBO table magic, table and entry sizes,
  entry count/offset bounds and a maximum loaded-image size; the examined
  source defines that maximum as 128 MiB. A 24 MiB partition-sized buffer is
  under that limit in this source version. The file also shows that the
  table's `total_size` must be nonzero and within the limit. [V:
  [PartitionTableUpdate.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/PartitionTableUpdate.c#L1992-L2080),
  [LocateDeviceTree.h](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Include/Library/LocateDeviceTree.h#L93-L103)]
- **[V]** Android's documented DTBO table format defines `id`, `rev` and
  `custom[4]` as optional identifiers that a bootloader may inspect before or
  in addition to parsing the DTB/DTBO. This describes a possible bootloader
  implementation; the Qualcomm `GetBoardDtb()` path above uses FDT root
  properties instead. [V: [AOSP: DTB and DTBO partitions, “Data structures”
  and “Sample code”](https://source.android.com/docs/core/architecture/dto/partitions)]
- **[V]** Public OnePlus 8 Pro packaging evidence has a second format example:
  the device's mainline `APKBUILD` runs `dtc -O dtb` directly on
  `sm8250-oneplus-instantnoodlep-empty.dts` and installs that raw FDT as
  `dtbo.img`; the DTS has root `qcom,msm-id = <356 0x10000>` and
  `qcom,board-id = <8 0>`, with no fragment nodes or `/plugin/` directive.
  This is evidence of how that public package builds the file, not proof that
  the OnePlus production ABL accepts a raw FDT in place of the standard
  `dt_table` container. [V: [pmaports empty DTS](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/device-oneplus-instantnoodlep/sm8250-oneplus-instantnoodlep-empty.dts#L1-L10),
  [pmaports APKBUILD](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/device-oneplus-instantnoodlep/APKBUILD#L42-L48)]
- **[V]** LineageOS's public SM8250 common board config sets a 4096-byte
  kernel page size and a 25,165,824-byte DTBO partition size. This corroborates
  the partition geometry in the test report; it does not specify ABL's
  matching algorithm. [V: [BoardConfigCommon.mk](https://github.com/LineageOS/android_device_oneplus_sm8250-common/blob/lineage-22.2/BoardConfigCommon.mk#L89-L107)]

## Applied to the failed test

**[V]** The 2026-11-17 test used one standard `mkdtboimg.py` entry, table
metadata `id/rev/custom = 0`, a 4096-byte page size, a zero-padded
25,165,824-byte image and no AVB footer. Its root properties copied stock
entry 16's `qcom,board-id = <0x10008 0>`, `oplus,dtsi_no` and
`oplus,pcb_range`; it did not include `qcom,msm-id`. The unchanged boot image
boots with stock DTBO, but after the test ABL marked slot B unbootable and
switched to A. [V: assigned experiment report, 2026-11-17; build assumptions
and intended image in `device/instantnoodlep/DTBO-PLAN.md:31-42`; existing
source properties in `device/instantnoodlep/dtbo/neutral.dts:8-17`]

### Ranked causes [I]

These are hypotheses to distinguish with the next owner-gated device test;
the public code examined is not confirmed to be the phone's exact ABL build.

1. **OnePlus-specific selection or bootloader behavior differs from the
   public matcher.** This is the highest-ranked cause because the tested
   root `qcom,board-id` and Oplus values are reported identical to stock entry
   16, while the public generic matcher should be able to select that board
   property even without `qcom,msm-id`. The unexplained failure therefore
   points first to a target-specific extension or a different ABL revision.
   The public generic matcher does not inspect `oplus,dtsi_no` or
   `oplus,pcb_range`, and no public OnePlus ABL source confirming those
   properties was found. **Test:** add the public same-device
   `qcom,msm-id = <356 0x10000>` value and handset property, keep all stock
   board/Oplus properties unchanged, and use the standard table.
2. **The entry is rejected or overlay application fails in this ABL build.**
   A valid table with no property match is a hard `EFI_NOT_FOUND` path in
   the public source. An entry that matches is then sent to the overlay
   applier. The experiment's root-only entry matches the observed stock
   entry's shape, so “no fragments” alone ranks below a phone-specific
   matcher or an error applying the FDT. `dtbo.img` must have the expected
   table magic and internally consistent header/offsets; the generic source
   checks those fields, and `mkdtboimg.py` is the format-matched builder.
3. **The stale `vbmeta_b` DTBO hash or footer-less image triggers a target
   AVB failure.** This is possible if OnePlus ABL treats the relevant result
   as fatal or the AVB result is an I/O/metadata error, but a plain hash
   mismatch is lower-ranked: the public ABL explicitly tolerates verification
   errors when unlocked, and its requested-partition list includes `dtbo`.
   Do not infer from “unlocked” alone that all verification failures are
   ignored.
4. **`id/rev/custom = 0` or the absence of `qcom,msm-id` alone.** These are
   low-ranked causes. Stock entry 16 reportedly has zero table metadata and
   no `qcom,msm-id`; in the public ABL code table metadata is ignored for
   board matching and a missing `qcom,msm-id` does not block its subsequent
   `qcom,board-id` check. The recipe below nevertheless adds the public
   OnePlus mainline `qcom,msm-id` value as a controlled compatibility probe.

## Candidate recipe to test

This is a diagnostic candidate, not a verified repair. It preserves the
reported stock board and Oplus identifiers, adds the OnePlus mainline SoC ID
used by the public device DTS, and packages the FDT in the standard Android
DTBO table. The Qualcomm ABL source's entry-selection path parses properties
from the FDT, so the table's optional identifier fields remain zero, matching
the reported stock entries. [V: cited matcher and table format above; [pmaports
empty DTS](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/device-oneplus-instantnoodlep/sm8250-oneplus-instantnoodlep-empty.dts#L3-L10)]

Scratch DTS (`$WORK/instantnoodlep-neutral-v2.dts`):

```dts
/dts-v1/;

/ {
	model = "OnePlus 8 Pro";
	compatible = "oneplus,instantnoodlep", "qcom,sm8250";
	chassis-type = "handset";

	qcom,msm-id = <356 0x10000>;
	qcom,board-id = <0x10008 0>;
	oplus,dtsi_no = <0x4d63>;
	oplus,pcb_range = <0 0x38>;
};
```

Build on the host, substituting the existing AOSP/Lineage toolchain paths;
these commands do not contact or write to the phone:

```sh
WORK="$HOME/android/build/dtbo-neutral-v2"
DTC="$HOME/android/kernel-build-tools/linux-x86/bin/dtc"
MKDTBOIMG="$HOME/android/system/libufdt/utils/src/mkdtboimg.py"
mkdir -p "$WORK"
cat > "$WORK/instantnoodlep-neutral-v2.dts" <<'EOF'
/dts-v1/;

/ {
	model = "OnePlus 8 Pro";
	compatible = "oneplus,instantnoodlep", "qcom,sm8250";
	chassis-type = "handset";

	qcom,msm-id = <356 0x10000>;
	qcom,board-id = <0x10008 0>;
	oplus,dtsi_no = <0x4d63>;
	oplus,pcb_range = <0 0x38>;
};
EOF

"$DTC" -q -I dts -O dtb \
  -o "$WORK/instantnoodlep-neutral-v2.dtbo" \
  "$WORK/instantnoodlep-neutral-v2.dts"
python3 -I "$MKDTBOIMG" create "$WORK/dtbo.img" \
  --page_size=4096 \
  --id=0 --rev=0 --custom0=0 --custom1=0 --custom2=0 --custom3=0 \
  "$WORK/instantnoodlep-neutral-v2.dtbo"
truncate -s 25165824 "$WORK/dtbo.img"

python3 -I "$MKDTBOIMG" dump "$WORK/dtbo.img"
fdtget -t x "$WORK/instantnoodlep-neutral-v2.dtbo" / qcom,msm-id
fdtget -t x "$WORK/instantnoodlep-neutral-v2.dtbo" / qcom,board-id
stat -c '%s bytes' "$WORK/dtbo.img"
```

Expected offline checks: one entry; `page_size = 4096`; entry `id`, `rev`
and each `custom` word zero; `fdtget -t x` shows `164 10000` (356 decimal)
and `10008 0` for the two properties;
file size is 25,165,824 bytes. Then follow only the already owner-gated
write/recovery sequence in `device/instantnoodlep/DTBO-PLAN.md:63-77` for a
device trial. **Do not flash this image without the owner's explicit go for
that step.**

## Can ABL test this without a partition write?

**[V]** The workspace allows `fastboot boot <image>` as a RAM-only operation
(`AGENTS.md:11-21`), and the device plan already uses a RAM boot to test a
kernel against the installed stock DTBO (`DTBO-PLAN.md:70-72`). This can test
the candidate mainline DTB and kernel behavior while the stock DTBO remains
installed. **[I]** No public standard `fastboot boot` path was found that
passes a separate candidate `dtbo.img` into ABL's DTBO loader: the examined
ABL code loads the `dtbo` partition separately. Therefore this is a useful
partial, non-writing test, but not a test of candidate DTBO matching or
application. The actual end-to-end test still requires the existing gated
`dtbo_b` write-and-rollback runbook.

## Sources and scope

- Qualcomm ABL public source snapshot (GitHub mirror of EDK2/QcomModulePkg):
  [LocateDeviceTree.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/LocateDeviceTree.c),
  [BootLinux.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/BootLinux.c),
  [PartitionTableUpdate.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/BootLib/PartitionTableUpdate.c),
  [VerifiedBoot.c](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Library/avb/VerifiedBoot.c),
  [LocateDeviceTree.h](https://github.com/TheGammaSqueeze/edk2/blob/uefi.lnx.5.0.r13-rel/QcomModulePkg/Include/Library/LocateDeviceTree.h).
  The corresponding public CodeLinaro ABL tree is
  [here](https://git.codelinaro.org/clo/la/abl/tianocore/edk2/-/tree/KERNEL.PLATFORM.2.0.r1-17200-kernel.0/QcomModulePkg/Library/BootLib?ref_type=tags).
- Android Open Source Project, [DTB and DTBO partitions](https://source.android.com/docs/core/architecture/dto/partitions)
  (table layout, optional entry metadata and `mkdtimg`).
- Public OnePlus 8 Pro packaging source: [empty DTS](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/device-oneplus-instantnoodlep/sm8250-oneplus-instantnoodlep-empty.dts)
  and [APKBUILD](https://gitlab.com/postmarketOS/pmaports/-/blob/master/device/testing/device-oneplus-instantnoodlep/APKBUILD).
- **Scope limitation [V]:** no public OnePlus-specific ABL source was found
  that can identify the exact shipping ABL behavior. The generic ABL findings
  above are checked against the cited source snapshot; extrapolation to the
  installed OnePlus binary remains [I] pending the gated device test.
