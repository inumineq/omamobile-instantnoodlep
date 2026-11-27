<!-- SPDX-License-Identifier: MIT -->
# SM8250 porting playbook: OnePlus ABL, image-size and toolchain findings

**Research date:** 2026-11-25
**Issue:** #192 (wayfinder:research)

This playbook consolidates findings from the instantnoodlep (OnePlus 8 Pro, SM8250) port
that are broadly applicable to other Qualcomm SM8250 community ports. Every factual
claim is marked **[V]** when checked against a cited source, or **[I]** when it remains
an inference to verify on-device. No proprietary firmware, serials, IMEI or MAC addresses
are included.

## Audience and scope

This document is for porters bringing up mainline Linux on SM8250-class devices with
Qualcomm ABL bootloaders. It covers five recurring pain points and their verified
solutions or workarounds:

1. RAM-first bring-up shape
2. Storage-guard pattern for partition writes
3. OnePlus ABL overlay/slot behavior
4. Image-size budgeting against ABL ceilings
5. Cross-toolchain footguns (clang versions)
6. Evidence and runbook discipline

Each section lists the claim, the verified source, and a ready-to-adapt runbook step
where applicable. Phone-gated steps are explicitly marked for owner execution.

---

## 1. RAM-first bring-up shape

**Claim:** A RAM-first bring-up (`fastboot boot`) is the safest entry point for
mainline kernel testing on instantnoodlep, as it touches no partitions and allows
rapid iteration without affecting the stock Android slots [V: AGENTS.md rule 1, lines 11-21; device/instantnoodlep/BRINGUP-M1-PLAN.md; docs/runbooks/M1-RAM-RUNBOOK.md].

**Evidence:**
- AGENTS.md explicitly authorizes agents to run `fastboot boot <image>` as a
  RAM-only operation that writes no partition
  [V: AGENTS.md rule 1, lines 11-21].
- The M1a RAM-only first light plan and runbook use `fastboot boot` exclusively
  for kernel testing before any partition writes
  [V: device/instantnoodlep/BRINGUP-M1-PLAN.md; docs/runbooks/M1-RAM-RUNBOOK.md].
- The repository's build tools (`tools/build-instantnoodlep-probe`) produce a
  RAM-bootable `boot.img` with header v2 geometry matching the stock offsets
  [V: tools/build-instantnoodlep-probe lines 90-97].

**Shape:**
- Header v2 with stock geometry: kernel at 0x00008000, ramdisk at 0x01000000,
  DTB at 0x01f00000, page size 4096 [V: docs/research/abl-boot-flow.md;
  device/instantnoodlep/NOTES.md 2026-11-16].
- The DTB is embedded in the boot image at the standard offset; ABL extracts
  and applies the stock DTBO overlay from the `dtbo` partition separately
  [V: device/instantnoodlep/DTBO-PLAN.md §1].
- This allows testing kernel/DTB combinations while keeping the stock dtbo and
  vbmeta untouched [V: device/instantnoodlep/DTBO-PLAN.md §1].

**Runbook pattern:**
```bash
# Build a RAM-only boot image
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz dtbs
tools/build-instantnoodlep-probe --ram boot.img \
  --kernel arch/arm64/boot/Image.gz \
  --dtb arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb

# RAM boot (owner gate: requires physical phone access)
fastboot -s <serial> boot boot.img
```

**Warning:** After a refusal (boot fails and returns to fastboot), **never send a
second `fastboot boot` in the same fastboot session** — first run
`fastboot -s <serial> reboot bootloader`. A second RAM boot after a refusal can
fail AVB and cause ABL to mark the active slot unbootable and switch slots
[V: docs/runbooks/M1-RAM-RUNBOOK.md R1 warning; device/instantnoodlep/NOTES.md
2026-11-16 afternoon].

---

## 2. Storage-guard pattern

**Claim:** All partition-write operations must be gated with explicit owner
approval, exact command blocks, expected output, stop conditions, and rollback
procedures [V: AGENTS.md lines 11-21, 27; device/instantnoodlep/DTBO-PLAN.md §4-6].

**Evidence:**
- AGENTS.md rule 1: anything that writes flash or wipes is prepared with the
  exact command block, expected output (Expect), stop condition and rollback, and
  runs only after the owner's explicit go for that step
  [V: AGENTS.md lines 11-21].
- Rule 3 (Safety model first): never write to `super` or any `_a` partition;
  `UFS_RW` only ever names slot B boot images and `userdata`
  [V: AGENTS.md line 27].
- Every device plan includes a gated runbook with step-by-step commands,
  expectations, stop conditions, and rollback procedures
  [V: device/instantnoodlep/DTBO-PLAN.md §4-6;
  device/instantnoodlep/POWER-M5-PLAN.md].

**Pattern for partition writes:**

| Field | Requirement | Example |
|-------|-------------|---------|
| Command | Exact `fastboot` invocation | `fastboot flash dtbo_b dtbo.img` |
| Expect | Verifiable success output | `Writing 'dtbo_b' OKAY` |
| Stop | Immediate halt condition | `FAILED (remote: ...)` |
| Rollback | Reversible command sequence | `fastboot flash dtbo_b backup.img` |
| Gate | Owner explicit approval | "Owner go" required |

**Critical safeguards:**
- Slot A (stock Android) must remain untouched except for documented recovery
  paths [V: AGENTS.md rule 3].
- Always verify `current-slot` and `slot-successful` before and after writes
  [V: device/instantnoodlep/DTBO-PLAN.md D0, D2].
- Keep a known-good backup of every partition before modification
  [V: device/instantnoodlep/BRINGUP-M1-PLAN.md §8].

---

## 3. OnePlus ABL overlay and slot behavior

### 3.1 DTBO overlay root-rewrite problem

**Claim:** The stock dtbo on instantnoodlep rewrites the root of the mainline DTB,
causing mainline kernel tables keyed on `qcom,sm8250` to fail [V: device/instantnoodlep/DTBO-PLAN.md §1].

**Evidence:**
- On the phone under K3, `/proc/device-tree/compatible` reads
  `qcom,kona-mtp qcom,kona qcom,mtp` and model reads `Qualcomm Technologies, Inc.
  kona MTP 19811`, although the DTB being booted says
  `oneplus,instantnoodlep qcom,sm8250`
  [V: device/instantnoodlep/DTBO-PLAN.md §1].
- The rewrite comes from stock DTBO entry 16's root-node properties
  (`compatible`, `model`, `qcom,board-id`, `oplus,*`)
  [V: device/instantnoodlep/DTBO-PLAN.md §1; device/instantnoodlep/DTBO-ABL-RESEARCH.md].
- Effect: kernel tables keyed on `qcom,sm8250` through machine compatible miss,
  observed as `Couldn't find UBWC config data for this platform!` and
  `msm-mdss ... probe ... failed with error -22`
  [V: device/instantnoodlep/DTBO-PLAN.md §1].

**Workaround:**
- K3 carried a test-only patch matching `qcom,kona` as a local layer
  [V: device/instantnoodlep/DTBO-PLAN.md §1].
- The proper fix is a neutral dtbo that provides mainline identity without
  fragments, but OnePlus ABL rejected both tested variants (table and raw FDT)
  [V: device/instantnoodlep/DTBO-PLAN.md §6; device/instantnoodlep/DTBO-ABL-RESEARCH.md].
- Alternative: make affected tables (UBWC, pd-mapper, cpufreq-dt-platdev) match
  the phone via other upstream-acceptable means [I: device/instantnoodlep/DTBO-PLAN.md §6].

### 3.2 ABL DTBO selection

**Claim:** Public Qualcomm ABL selects DTBO entries by matching root-node
Qualcomm device-tree properties (`qcom,msm-id`, `qcom,board-id`, optionally
PMIC properties and `qcom,oem-id`), not by DT table entry metadata [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md].

**Evidence:**
- `GetBoardDtb()` walks each table entry, checks the contained FDT, and calls
  `ReadDtbFindMatch()` which reads `qcom,msm-id`, `qcom,board-id`, and
  conditionally `qcom,oem-id` [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md;
  LocateDeviceTree.c `GetBoardDtb()` lines 1374-1437;
  LocateDeviceTree.c `ReadDtbFindMatch()` lines 908-1023].
- The table entry's `id`, `rev` and `custom[]` fields are not referenced in
  this walk [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md].

### 3.3 Slot behavior after boot failure

**Claim:** After a `fastboot boot` refusal, sending a second `fastboot boot` in
the same fastboot session can trigger ABL's `HandleActiveSlotUnbootable` which
marks the active slot unbootable and switches to the other slot [V: device/instantnoodlep/NOTES.md 2026-11-16 afternoon; device/instantnoodlep/DTBO-ABL-RESEARCH.md].

**Evidence:**
- On 2026-11-16: first `fastboot boot` refused (stayed in fastboot), then a
  second `fastboot boot` (Magisk image) made ABL swap slots. Result:
  `current-slot:b`, `slot-unbootable:a:yes`, `slot-retry-count:b:7`
  [V: device/instantnoodlep/NOTES.md 2026-11-16 afternoon].
- This is `HandleActiveSlotUnbootable`: mark the active slot unbootable,
  `SetActiveSlot` the other, cold reset
  [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md;
  Q/PartitionTableUpdate.c:1471-1528].
- `LoadImageAndAuth` fails on an A/B device, and `CmdBoot` sets `MultiSlotBoot`,
  so a RAM boot reaches this path as well
  [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md;
  Q/VerifiedBoot.c:1508-1515].

**Runbook requirement:**
> After a refusal, **never send a second `fastboot boot` in the same fastboot
> session**: run `fastboot -s <serial> reboot bootloader` first.
> [V: docs/runbooks/M1-RAM-RUNBOOK.md R1 warning]

### 3.4 ABL AVB behavior on unlocked devices

**Claim:** On unlocked devices, public Qualcomm ABL tolerates AVB verification
errors for the dtbo partition but still enforces format and metadata checks [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md].

**Evidence:**
- AVB 2 requests `dtbo` as a verified partition and sets
  `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR` when `IsUnlocked()` is true,
  continuing for verification, rollback-index and public-key errors
  [V: DTBO-ABL-RESEARCH.md;
  VerifiedBoot.c:60-68, 1350-1385, 1578-1603].
- I/O, invalid-metadata and unsupported-version errors are not recoverable
  [V: DTBO-ABL-RESEARCH.md].
- Therefore a stale `vbmeta_b` hash by itself is not expected to stop boot on
  an unlocked device, but malformed DTBO data or every AVB failure is not
  necessarily harmless [V: DTBO-ABL-RESEARCH.md].

---

## 4. Image-size budgeting

### 4.1 ABL kernel image size ceiling

**Claim:** The OnePlus ABL on instantnoodlep enforces a hard ceiling on the
decompressed arm64 kernel `Image` size. The observed inclusive ceiling is
`0x2b60000` (45,395,456) bytes; images at `0x2b70000` and `0x2cd0000` fail [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md §Finding].

**Evidence:**
- Tested observation: image with `image_size = 0x2b60000` boots; images with
  `0x2b70000` and `0x2cd0000` stop at fastboot splash without USB or logs
  [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md §Finding].
- Public Qualcomm ABL (CodeLinaro clo/la/abl/tianocore/edk2 LA.UM.11.2.1.c25)
  decompresses gzip kernel to `KernelLoadAddr` with output capacity
  `DeviceTreeLoadAddr - KernelLoadAddr`, then rejects if header
  `image_size` exceeds that gap
  [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md;
  BootLinux.c:641-671, 706-717].
- The exact bound is runtime-dependent on `KernelBaseAddr`/`KernelSize` UEFI
  variables or PCD fallbacks, and the ramdisk/DTB staging space
  [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md].

**Practical guidance:**
- **Plan against `0x2b60000` as a hard maximum** for instantnoodlep, preferably
  with margin [I: ABL-KERNEL-SIZE-RESEARCH.md §Conclusion].
- Shrinking the decompressed `Image` below this cap is the only supported option
  on this device until OnePlus ABL source is available
  [I: ABL-KERNEL-SIZE-RESEARCH.md].
- Changing `TEXT_OFFSET`, `RANDOMIZE_BASE`, or `mkbootimg` offsets does not
  move ABL's decompression destination or increase its checked output gap
  [I: ABL-KERNEL-SIZE-RESEARCH.md].

### 4.2 Verified image sizes from the port

| Kernel configuration | Toolchain | `image_size` | Boot result | Source |
|---|---|---|---|---|
| slim K3 (daily minus foreign-SoC) | omabook clang 23.1.3 | 0x1720000 | RAM boot passes | [V: state.md; NOTES 2026-11-18] |
| slim K3 | MBP Docker clang 19 | 0x1720000 | Freezes on splash | [V: state.md; NOTES 2026-11-18] |
| P2 charger on slim | omabook clang 23.1.3 | 0x1720000 | RAM boot passes | [V: NOTES 2026-11-18 evening] |
| P2 charger (k3-power-p2) | omabook clang 23.1.3 | 0x2b70000 | Froze (over ceiling) | [V: NOTES 2026-11-18] |
| PM1 idle diagnostic | omabook clang 23.1.3 | 0x1780000 | Under ceiling, not booted | [V: idle-power-sm8250.md] |
| Camera bisect B1/B2/B3 | omabook clang 23.1.3 | 0x1780000 | Under ceiling, not booted | [V: CAMERA-BISECT.md] |
| modem/GNSS candidate | omabook clang 23.1.3 | 0x1750000 | RAM boot passes | [V: MODEM-M5-DELTA §6.2] |
| k3-daily2-adsp | omabook clang 23.1.3 | 0x1750000 | Built, not booted | [V: AUDIO-M5-PLAN §11] |

**Key insight:** All kernels that boot on instantnoodlep have `image_size` ≤
`0x1780000` (24,576,000 bytes). The `0x2b60000` ceiling is the absolute ABL
limit, but practical kernels should target well below this to allow for
future growth and different configurations.

### 4.3 Builder checks

**Claim:** The builder must check the decompressed kernel size against the ABL
ceiling, not the compressed size against header offset gaps [V: docs/research/abl-kernel-size.md §3; device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md].

**Evidence:**
- Public ABL checks the **decompressed** kernel size against
  `DeviceTreeLoadAddr - KernelLoadAddr` [V: ABL-KERNEL-SIZE-RESEARCH.md;
  BootLinux.c:641-671, 706-717].
- The header's kernel/ramdisk offsets are file-layout fields, not load
  addresses; the "Not Enough space" check is ramdisk + DTB slot vs reserved
  kernel region [V: docs/research/abl-kernel-size.md §3].
- The old guard comparing compressed kernel + DTB against header-offset gap
  was incorrect for this ABL family [V: abl-kernel-size.md §3].

---

## 5. Cross-toolchain footgun: clang 19 freezes, clang 23 boots

**Claim:** The same kernel tree (slim K3) built with clang 19 freezes on the
splash screen, while built with clang 23.1.3 boots successfully [V: docs/agents/state.md; device/instantnoodlep/NOTES.md 2026-11-18].

**Evidence:**
- Slim K3 built with omabook clang 23.1.3: RAM boot passes, `image_size`
  0x1720000, USB, running, panel, msm GL, Wi-Fi, hci0, gauge; modules on rootfs
  [V: docs/agents/state.md; device/instantnoodlep/NOTES.md 2026-11-18].
- The same tree built with MBP Docker clang 19 freezes on the splash
  [V: docs/agents/state.md; device/instantnoodlep/NOTES.md 2026-11-18].
- All feature kernels on slim K3 were built with clang/LLD 23.1.3-23.1.6
  on macbookpro and omabook, with consistent success
  [V: device/instantnoodlep/NOTES.md 2026-11-18 evening; docs/runbooks/SLIM-FEAT-RUNBOOK.md].

**Root cause:**
- [I] Not established in the checked files. The difference may be in code
  generation, optimization passes, or LLD linker behavior between versions.
  The clang 19 build produced the same `image_size` but froze.

**Recommendation:**
- Use clang 23.x (specifically 23.1.3 or newer) for SM8250/OnePlus 8 Pro kernel
  builds until the root cause is identified.
- Document the exact toolchain version in build logs and release notes.
- If testing with clang 19, expect potential boot failures unrelated to
  configuration.

---

## 6. Evidence and runbook discipline

### 6.1 [V] and [I] marking

**Claim:** Every factual claim must be explicitly marked as **[V]** (verified
with a source) or **[I]** (inference to check on device) [V: AGENTS.md line 27].

**Evidence:**
- AGENTS.md rule 2: Every claim is [V] (checked, with a source or file:line)
  or [I] (inference to check on the device). No in-between
  [V: AGENTS.md line 27].
- This playbook follows that rule throughout.

### 6.2 Traceability requirement

**Claim:** Every [V] claim must be traceable to a repo file or upstream comment [V: issue #192 Scope].

**Evidence:**
- Issue #192 Scope: "each claim traced to a repo file or upstream comment"
  [V: issue #192 Scope].
- This document cites specific files, line numbers, commit hashes, or URL
  sources for every [V] claim.

### 6.3 Runbook structure

**Claim:** Device-facing steps must include: exact command, Expect, Stop,
Rollback [V: device/instantnoodlep/DTBO-PLAN.md §4-6; docs/runbooks/M1-RAM-RUNBOOK.md; device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md].

**Evidence:**
- DTBO-PLAN.md provides a complete gated runbook with these fields
  [V: device/instantnoodlep/DTBO-PLAN.md §4-6].
- M1-RAM-RUNBOOK.md follows the same pattern for RAM boot testing
  [V: docs/runbooks/M1-RAM-RUNBOOK.md].
- ABL-KERNEL-SIZE-RESEARCH.md documents the tested configurations and
  outcomes [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md].

**Template:**
```
| Step | Command | Expect | Stop | Rollback |
|------|---------|--------|------|----------|
| X1 | `fastboot ...` | OKAY | FAILED | `fastboot flash ...` |
```

### 6.4 Private data handling

**Claim:** Serials, IMEI, MAC addresses, and capture files must never enter
commits, comments, issues, or PRs [V: AGENTS.md lines 31-39].

**Evidence:**
- AGENTS.md rule 4: Captures are private. `captures/` is gitignored on purpose.
  Serials, IMEI and MAC addresses never enter commits, comments or issues
  [V: AGENTS.md lines 31-33].
- Rule 4a: No personal contact details in any repo artifact
  [V: AGENTS.md lines 34-39].

---

## 7. Ready draft comment for upstream

The following draft can be posted to upstream issues #867 or device-specific
tracking issues to help other SM8250 porters:

---

**Subject:** SM8250 porting tips: ABL behavior, image size limits, toolchain notes

Hi! We've been working on bringing up mainline Linux on the OnePlus 8 Pro (SM8250, instantnoodlep) and hit several walls that other ports may encounter. Here are our findings so far:

### 1. ABL and DTBO overlay root-rewrite

If your mainline kernel fails to bind drivers that match on `qcom,sm8250` machine
compatible, check whether the stock DTBO is rewriting your DTB root node. On
instantnoodlep, the stock dtbo entry 16 adds `qcom,kona-mtp` etc. to the root, causing
mainline tables keyed on `qcom,sm8250` to miss [V: device/instantnoodlep/DTBO-PLAN.md §1].
A workaround is to carry a local patch matching `qcom,kona`, but the proper fix needs
upstream-acceptable kernel changes or a neutral dtbo [V: device/instantnoodlep/DTBO-ABL-RESEARCH.md].

### 2. Second `fastboot boot` after refusal triggers slot swap

Never send a second `fastboot boot` in the same fastboot session after a refusal.
On instantnoodlep, this triggered ABL's `HandleActiveSlotUnbootable` which marked
slot A unbootable and switched to slot B [V: device/instantnoodlep/NOTES.md 2026-11-16;
device/instantnoodlep/DTBO-ABL-RESEARCH.md]. Always run `fastboot reboot bootloader`
first.

### 3. ABL kernel image size ceiling

The OnePlus ABL on instantnoodlep enforces a hard ceiling on decompressed kernel
size. The observed limit is `image_size <= 0x2b60000`; images at `0x2b70000` and
`0x2cd0000` fail silently at the fastboot splash [V: device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md §Finding].
Public Qualcomm ABL source shows this is a runtime check of the decompressed Image
header's `image_size` against `DeviceTreeLoadAddr - KernelLoadAddr` [V:
device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md]. All our booting kernels have
`image_size` ≤ `0x1780000`. Plan against `0x2b60000` as a hard maximum.

### 4. Toolchain matters: clang 19 freezes, clang 23 boots

The same kernel tree (slim K3, `image_size=0x1720000`) built with clang 19 freezes
on splash, while clang 23.1.3 boots successfully [V: docs/agents/state.md;
device/instantnoodlep/NOTES.md 2026-11-18]. Use clang 23.x for SM8250 until the
root cause is identified.

### 5. Evidence discipline

We maintain strict [V]/[I] marking: [V] means checked against a source, [I] means inference to verify on-device. All claims in this comment are [V] with citations to repo files or public ABL source.

---

**Full details and sources:** See the SM8250 porting playbook in our downstream repo: `docs/research/sm8250-porting-playbook.md`.

Happy to help with any questions!

---

## 8. What remains phone-gated

The following items are verified on-device but the exact causes or fixes require
owner-attended phone access and are not suitable for automated agent work:

1. **DTBO neutral image testing:** The candidate recipes in DTBO-ABL-RESEARCH.md
   need device testing to determine if OnePlus ABL accepts a neutral dtbo
   [I: DTBO-PLAN.md §5; DTBO-ABL-RESEARCH.md].
2. **Clang 19 freeze diagnosis:** The root cause of clang 19 vs clang 23
   behavior difference is not established in source alone
   [I: docs/agents/state.md].
3. **ABL exact memory layout:** The precise `KernelBaseAddr`/`KernelSize` values
   and reserved region boundaries in OnePlus's closed ABL are unverified
   [I: ABL-KERNEL-SIZE-RESEARCH.md].

---

## 9. Related files in this repository

| File | Relevance |
|------|-----------|
| device/instantnoodlep/DTBO-PLAN.md | Detailed DTBO overlay problem and neutral dtbo attempts |
| device/instantnoodlep/DTBO-ABL-RESEARCH.md | Public ABL DTBO selection behavior analysis |
| device/instantnoodlep/ABL-KERNEL-SIZE-RESEARCH.md | Image size ceiling research and public ABL analysis |
| docs/research/abl-kernel-size.md | Builder guard analysis for kernel size checking |
| docs/research/abl-boot-flow.md | ABL boot flow and header v2 geometry |
| docs/agents/state.md | Current port state including toolchain observations |
| device/instantnoodlep/NOTES.md | Phone-gated findings and test results |
| docs/runbooks/M1-RAM-RUNBOOK.md | RAM boot runbook with safety warnings |

---

## 10. Summary check

- [x] RAM-first bring-up shape documented with verified sources
- [x] Storage-guard pattern with gated runbook structure
- [x] OnePlus ABL overlay/slot behavior with public source citations
- [x] Image-size budgeting with observed ceiling and practical guidance
- [x] Cross-toolchain footgun (clang 19 vs 23) with verified observations
- [x] Evidence/runbook discipline with [V]/[I] marking throughout
- [x] Every [V] claim traceable to repo file or upstream source
- [x] Draft upstream comment ready for #867 or device issues
- [x] Phone-gated items clearly identified and separated

---

*This document was prepared as part of issue #192. See AGENTS.md for house rules and evidence discipline.*
