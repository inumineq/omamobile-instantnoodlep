<!-- SPDX-License-Identifier: MIT -->
# Kona root-compatible rewrite: upstream kernel design

**[V]** Research snapshot: 2026-11-17; kernel references are pinned to
upstream Linux `v7.3-rc6` ([tag](https://github.com/torvalds/linux/tree/v7.3-rc6)).
**[V]** This is a design note only: no kernel code, device access, or flash
procedure is included.

## Decision

**[I] Recommended kernel direction:** stop using the root `compatible` as a
proxy for SoC identity where the selected data is inherently SoC-wide. Use
the Qualcomm SMEM SoC ID for UBWC and PD-mapper tables, and make the
cpufreq-dt exclusion depend on the presence of the QCOM cpufreq-hw DT node
rather than the root match. This addresses the three identified consumers
without inventing `qcom,kona` as a mainline root compatible or introducing
a second, private root identity property. The early cpufreq init ordering
is a design constraint, not yet a verified implementation detail.

**[V]** ABL's stock DTBO rewrites the live root compatible to
`qcom,kona-mtp`, `qcom,kona`, `qcom,mtp` on every boot, and both attempted
replacement DTBO formats were rejected; `dtbo_b` is back to stock
([DTBO-PLAN §1 and §6](DTBO-PLAN.md#1-problem-v),
[DTBO-ABL-RESEARCH.md](DTBO-ABL-RESEARCH.md)). **[V]** UBWC lookup then
fails with `-EINVAL` on the phone ([DTBO-PLAN §1](DTBO-PLAN.md#1-problem-v)).

## 1. Root-compatible consumers in Linux v7.3-rc6

`of_machine_get_match()` and `of_machine_get_match_data()` match against
the root node; `of_machine_device_match()` is the corresponding boolean
machine-table lookup. [V: [`drivers/of/base.c:488-519`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/of/base.c#L488-L519)]
**[V]** The audited `qcom,sm8250` root-table consumers relevant to this
device are:

| Consumer | Exact lookup | Effect of this root rewrite | Phone relevance |
|---|---|---|---|
| UBWC data selector | `qcom_ubwc_configs` maps `qcom,sm8250` to UBWC 4.0 / HBB16; the getter calls `of_machine_get_match_data()` and returns `-EINVAL` if there is no match. [V: [`ubwc_config.c:160-162,192-196`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/ubwc_config.c#L160-L196)] | `qcom,sm8250` is absent from the live compatible list, so this table cannot select the SM8250 data. | **[V]** This is the observed UBWC failure and `msm-mdss` probe failure recorded in the device plan. |
| Qualcomm PD mapper | `qcom_pdm_domains` maps `qcom,sm8250` to `sm8250_domains`; `qcom_pdm_start()` calls `of_machine_get_match()` and returns `-ENODEV` when no platform matches. [V: [`qcom_pd_mapper.c:650-662,681-692`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/qcom_pd_mapper.c#L650-L692)] | The SM8250 domain list is not selected; the driver logs that the platform is unsupported and does not start its domain service. | **[I]** This is material to the planned audio, sensors, and modem stack; device use of the mapper has not been tested without the local kernel patch. |
| `cpufreq-dt-platdev` | Its blocklist includes `qcom,sm8250`; with a CPU OPP-v2 table, it skips creating the generic `cpufreq-dt` device only if that root match succeeds. [V: [`cpufreq-dt-platdev.c:180-187,219-249`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/cpufreq/cpufreq-dt-platdev.c#L180-L249)] | The OPP-v2 condition is true in the SM8250 DTS, but the blocklist lookup will miss after the rewrite and can register `cpufreq-dt`. [V: [`sm8250.dtsi:98-112`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L98-L112)] | **[I]** This may compete with the intended QCOM hardware cpufreq driver; the SM8250 DTS has a `qcom,sm8250-cpufreq-epss` hardware node, and the upstream blocklist was added because SM8250 uses `qcom-cpufreq-hw`. [V: [`sm8250.dtsi:6296-6312`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L6296-L6312), [blocklist commit](https://github.com/torvalds/linux/commit/5e79d6d9ea00c273f3efbced841212de85a384d1)] |

**[V]** The arm64 setup path scans the supplied FDT and reads its machine
model; it does not call the ARM `of_flat_dt_match_machine()` board table.
[`of_flat_dt_match_machine()` is a generic early-FDT helper](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/of/fdt.c#L703-L765),
while [`arch/arm64/kernel/setup.c:176-205`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/kernel/setup.c#L176-L205)
calls `early_init_dt_scan()` and then logs `of_flat_dt_get_machine_name()`.
**[V]** The source scan covered `of_machine_is_compatible()`,
`of_machine_get_match_data()`, `of_machine_get_match()`,
`of_machine_device_match()`, `of_flat_dt_match()`/`of_flat_dt_match_machine()`,
and `soc_device_match()`, searching the root keys `qcom,sm8250` and
`qcom,kona`; it found the three root-table consumers above. Device-node
matches such as `qcom,sm8250-*` are separate peripheral matches and are not
affected by the root rewrite.

### SoC-info is a separate identity path

**[V]** `qcom,msm-id` is documented in the ARM/QCOM binding as bootloader
DT-selection metadata, is deprecated, and says the bootloader is responsible
for passing the correct DT to the kernel. [V: [`qcom.yaml:1258-1281`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/arm/qcom.yaml#L1258-L1281);
[2022 binding discussion](https://lore.kernel.org/linux-arm-msm/20220830065744.161163-1-krzysztof.kozlowski@linaro.org/T/)]
**[V]** The in-kernel Qualcomm `socinfo` driver instead reads
`SMEM_HW_SW_BUILD_ID`, maps the numeric ID to a machine name, and publishes
`family`, `machine`, `soc_id`, and `revision` through the SoC bus; the
SM8250 ID is 356. [V: [`socinfo.c:434-435`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/socinfo.c#L434-L435),
[machine-name mapping](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/socinfo.c#L562-L574),
[socinfo probe](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/soc/qcom/socinfo.c#L901-L933),
[`qcom,ids.h:193`](https://github.com/torvalds/linux/blob/v7.3-rc6/include/dt-bindings/arm/qcom,ids.h#L193)]
**[I]** Consumers matching those SoC-bus attributes are insulated from this
particular DTBO rewrite; `soc_device_match()` is not a root-compatible
matcher. A new SMEM-ID path must not assume `socinfo`'s platform driver has
already probed at `core_initcall` time.

## 2. Precedents and constraints

### DTBO and root identity

- **[V]** The Android DTBO specification requires a `dt_table_header` even
  for a one-entry image and says optional table identifiers and additional
  FDT properties may be inspected by the bootloader. It describes loader
  selection, not a kernel mechanism for pinning or restoring root
  `compatible`. [V: [AOSP “DTB and DTBO partitions”, Data structures and Sample code](https://source.android.com/docs/core/architecture/dto/partitions)]
- **[V]** The mainline QCOM root binding uses a board-specific compatible
  followed by the SoC compatible; its SM8250 list includes RB5, HDK, MTP,
  Samsung, Sony, and Xiaomi entries, but no OnePlus 8 Pro or `qcom,kona`.
  [V: [`qcom.yaml:1099-1112`](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/arm/qcom.yaml#L1099-L1112)]
- **[V]** Mainline Sony Xperia 5 II and Xiaomi Elish board DTS files retain
  their board-first / `qcom,sm8250` root compatible. [V:
  [`sm8250-sony-xperia-edo-pdx206.dts:10-13`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250-sony-xperia-edo-pdx206.dts#L10-L13),
  [`sm8250-xiaomi-elish-boe.dts:10-13`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250-xiaomi-elish-boe.dts#L10-L13)]
  **[I]** These are examples of the upstream identity convention, not
  evidence that those phones have the same OnePlus root-property merge.
- **[V]** A mainline Sony Xperia XZ2/XZ2C/XZ3 support change records that
  those devices needed an erased or empty DTBO to avoid the vendor bootloader
  applying incompatible Android overlays; the workaround was in boot-image
  setup, not a generic Linux root-identity fix. [V: [upstream commit 30a7f99](https://github.com/torvalds/linux/commit/30a7f99befc655cb3eacdd3a0f2394a5209a492f)]
- **[V]** A public OnePlus 6/6T mainline bring-up guide says the stock DTBO
  must be erased to avoid the bootloader injecting Android DT content. [V:
  [SDM845 OnePlus 6/6T build notes](https://gitlab.com/sdm845-mainline/pmtools/-/blob/main/Building.md)]
  **[V]** That is not a viable fix here: neutral table and raw-FDT `dtbo_b`
  experiments were rejected, and the stock image was restored
  ([DTBO-PLAN §6](DTBO-PLAN.md#6-result-2026-11-17-both-images-rejected-plan-parked-v)).
- **[V]** A downstream SM8250 OnePlus 8 Pro patch adds `qcom,kona`
  between the board and `qcom,sm8250` in the DTS. [V: [Armbian patch](https://github.com/armbian/build/blob/main/patch/kernel/archive/sm8250-6.19/0008-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Add-dev.patch#L62-L66)]
  **[I]** This corroborates the workaround's practical appeal, not its
  upstream acceptance; the string is absent from the upstream QCOM root
  binding and the patch is not a mainline precedent.
- **[I]** The OnePlus 7 material located was not a mainline root-fix
  proposal, and no lore thread proposing a generic kernel-side
  root-compatible pinning property was found in searches for `qcom,kona`,
  `root compatible`, and `DTBO`; this is a bounded search result, not proof
  no discussion exists.

**[V]** Mainline's early `/chosen` scan consumes boot parameters such as
`bootargs`, initrd addresses, and the RNG seed; it does not define a
standard `/chosen` property for restoring the root machine compatible.
[V: [`drivers/of/fdt.c:1082-1116`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/of/fdt.c#L1082-L1116)]
**[I]** A bootloader-preserved `/chosen` marker could be made to drive an
early fixup, but that would be a new binding and an additional identity
authority rather than an existing kernel convention.

### Bootloader / kernel contract

**[V]** The arm64 boot protocol requires the bootloader to set up the DTB
and pass its address in `x0`; it does not define a Linux facility for
undoing bootloader DT mutations. [V: [Linux arm64 boot protocol, “Setup the device tree” and “Call the kernel image”](https://docs.kernel.org/arch/arm64/booting.html)]
**[I]** Therefore correcting ABL's output is architecturally the cleanest
system-level fix, but OnePlus's production ABL is not an available patch
surface for this task.

## 3. Ranked options

**[I]** Ranking is for a maintainable upstream Linux answer first; the
bootloader option is included as the cleanest end-to-end answer.

### 1. Select SoC-only data from SMEM; detect cpufreq-hw structurally — recommended kernel path

**[I] Outline:**

- `drivers/soc/qcom/ubwc_config.c`: select the existing SM8250 UBWC entry
  using the Qualcomm SoC ID from SMEM, retaining the existing SMEM HBB
  override and error handling.
- `drivers/soc/qcom/qcom_pd_mapper.c`: select `sm8250_domains` by the same
  SoC ID, preserving the current unsupported-platform/userspace fallback.
- `drivers/cpufreq/cpufreq-dt-platdev.c`: replace the SM8250 root
  `qcom,sm8250` blocklist dependency with a node-level test for an enabled
  QCOM cpufreq-hw implementation, retaining unrelated blocklist entries.
  SM8250 already describes CPU clocks/frequency domains and an EPSS cpufreq
  node in its SoC DTS. [V:
  [`sm8250.dtsi:98-112`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L98-L112),
  [`sm8250.dtsi:6296-6312`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/boot/dts/qcom/sm8250.dtsi#L6296-L6312)]
- Keep the root compatible as the board's DT identity; do not add a second
  identity property.

**[I] Affected files:** the three consumer files above; if SMEM ID handling
is shared, a small helper/header under `include/linux/soc/qcom/` and
`drivers/soc/qcom/`. The cpufreq portion should not call
`soc_device_match()` at `core_initcall`: it must either inspect the DT
hardware node directly or prove SMEM readiness at that init level.

**[I] Risk:** medium. It is a real refactor of SoC data selection, and the
SMEM helper's readiness/error contract must be explicit; unknown IDs must
fail safely. The cpufreq change must prove that detection of the active
hardware driver does not suppress generic cpufreq on other systems.

**[I] Maintainer expectations:** strongest kernel rationale because UBWC
format and PD service-domain inventories are SoC properties, while
cpufreq-hw is represented by an explicit hardware node. Preserve the
existing behavior for all known SoC IDs, test the enabled and unknown-ID
paths, and build/test the three subsystems. A QCOM reviewer may still ask
why the bootloader's root mutation is not fixed instead.

### 2. Fix the boot chain or have a later bootloader pass the original DTB

**[I] Outline:** have firmware stop overwriting the kernel DT root
compatible, or chainload a Linux-capable bootloader that loads the intended
mainline DTB and passes a correct tree. Upstream U-Boot documents Qualcomm
phone support and a phone-oriented boot flow; the SoC list and per-device
readiness change over time. [V: [U-Boot Qualcomm phone guide](https://docs.u-boot.org/en/latest/board/qualcomm/phones.html)]
Public Qualcomm-phone work also uses chainloaded U-Boot for a unified SDM845
image, including OnePlus 6, but that is not evidence of a tested SM8250
OnePlus 8 Pro chain. [V: [public SDM845 generic-port record](https://git.mrlokop.dev/MRLokop/pmaports/compare/plasma-mobile-nightly..sdm845/generic-device)]
**[V]** A lightweight secondary-LK pattern also exists: `lk2nd` can run
from an Android boot image and hand off a selected kernel and DTB. [V:
[lk2nd README](https://github.com/msm8916-mainline/lk2nd#lk2nd),
[boot process](https://github.com/msm8916-mainline/lk2nd/blob/main/Documentation/boot.md)]
**[I]** This documents a pattern, not SM8250 OnePlus 8 Pro support; the
device-specific chain must be established before preferring it to the
kernel-table refactor. A userspace-only fix is also unreliable because the
cpufreq machine-table decision is made at `core_initcall`. [V:
[`cpufreq-dt-platdev.c:249`](https://github.com/torvalds/linux/blob/v7.3-rc6/drivers/cpufreq/cpufreq-dt-platdev.c#L249)]

**[I] Affected files:** bootloader/device boot setup, not Linux kernel
tables. **[I] Risk:** high integration cost and device-specific recovery;
OnePlus ABL is proprietary and the SM8250 chainload path is unverified.
**[I] Maintainer expectation:** best architectural result and no kernel
quirk, but outside a Linux-only upstream patch.

### 3. Early kernel fixup from a preserved identity marker

**[I] Outline:** add an explicitly bound root property containing the
intended board/SoC compatible, then restore `/compatible` in the flat FDT
before normal OF scans and machine-table users. A possible insertion point
would be the arm64 setup path before `early_init_dt_scan()`. [V: [`setup.c:176-205`](https://github.com/torvalds/linux/blob/v7.3-rc6/arch/arm64/kernel/setup.c#L176-L205)]

**[I] Affected files:** new property binding, the OnePlus DTS, and
`arch/arm64/kernel/setup.c` or common OF code. **[I] Risk:** high: this
creates two authorities for root identity and requires careful early FDT
mutation before architecture and driver matching. A private marker may
also be copied or changed by future bootloader overlays.
**[I] Maintainer expectation:** likely difficult to justify as a generic
kernel facility for one bootloader unless other devices demonstrate the
same stable marker and a generic binding/use case.

### 4. Add `qcom,kona` aliases to the three tables

**[I] Outline:** add the Kona alias to UBWC (SM8250 data), PD mapper
(`sm8250_domains`), and cpufreq-dt blocklist tables. **[I] Affected files:**
`drivers/soc/qcom/ubwc_config.c`, `drivers/soc/qcom/qcom_pd_mapper.c`, and
`drivers/cpufreq/cpufreq-dt-platdev.c`.

**[I] Risk:** low implementation cost, medium-to-high semantic risk: it
matches an undocumented bootloader string, not an upstream board or SoC
compatible. **[V]** `qcom,kona` is not present in the v7.3-rc6 QCOM root
binding. **[I] Maintainer expectation:** likely to be challenged as a
device-specific workaround and could encourage more vendor-codename
aliases in generic tables. If used downstream temporarily, document and
keep it out of the upstream series.

### 5. Match these tables directly on `qcom,msm-id`

**[I] Outline:** read the root property and use ID 356 to select SM8250
data. **[V]** The property is deprecated and specified as bootloader
metadata; Linux's `socinfo` path reads the SoC ID from SMEM instead
([binding](https://github.com/torvalds/linux/blob/v7.3-rc6/Documentation/devicetree/bindings/arm/qcom.yaml#L1258-L1281),
[`QCOM_ID_SM8250`](https://github.com/torvalds/linux/blob/v7.3-rc6/include/dt-bindings/arm/qcom,ids.h#L193)).
**[I] Affected files:** the three machine-table consumers and the device
DTS if it must add the deprecated root property.
**[I] Risk/expectation:** poor choice: the property may be absent, is not a
kernel hardware-discovery API, and continues coupling data selection to
bootloader DT conventions. Do not recommend.

## 4. Follow-up gates before any kernel patch

1. **[I] Source gate:** verify SMEM availability for UBWC and PD-mapper at
   their actual call sites; make the cpufreq decision without depending on
   the later `socinfo` platform-driver probe.
2. **[I] Build gate:** build with `W=1`, run `checkpatch --strict`, and
   exercise table selection for SM8250 and every existing table entry;
   verify the cpufreq hardware-node path and unknown-node path.
3. **[I] Hardware gate:** test on an SM8250 handset with stock DTBO and
   confirm UBWC, PD-mapper domains, and QCOM cpufreq-hw behavior with the
   upstream kernel patch. This note does not authorize any phone operation;
   a later device plan must give the owner-gated commands, expectations,
   stop conditions, and rollback before any write or reboot.
4. **[I] Compatibility gate:** show that the existing Pixel 7 Pro path and
   other QCOM SoCs retain their current matching results.

## Sources

- **[V] Device evidence:** [`DTBO-PLAN.md` §1 and §6](DTBO-PLAN.md),
  [`DTBO-ABL-RESEARCH.md`](DTBO-ABL-RESEARCH.md), and learning
  [`l-f28ff139`](../../.trail/learnings/2026-11-17-the-stock-dtbo-rewrites-the-root-claude.md).
- **[V] Upstream scope:** [Linux `v7.3-rc6` source](https://github.com/torvalds/linux/tree/v7.3-rc6),
  [AOSP DTBO format](https://source.android.com/docs/core/architecture/dto/partitions),
  [QCOM `qcom,msm-id` binding discussion](https://lore.kernel.org/linux-arm-msm/20220830065744.161163-1-krzysztof.kozlowski@linaro.org/T/),
  and the cited Sony/Xiaomi/OnePlus/U-Boot references above.
