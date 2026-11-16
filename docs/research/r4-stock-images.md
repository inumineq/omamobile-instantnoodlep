<!-- SPDX-License-Identifier: MIT -->
# R4: stock boot, dtbo and vbmeta of `IN2023_13.1.0.591(EX01)`, read offline

- Origin: restore-assets R4 (`docs/runbooks/RESTORE-ASSETS.md`), run on the
  laptop on 2026-11-16 against the owner's verified full OTA (R2/R3 passed
  on ticket #4). No phone was touched. Images and raw tool output stay in
  `~/android/reference/instantnoodlep/images/`, outside git (AGENTS.md
  rule 8). Nothing quoted here is unique to the owner's unit.
- Tools: `payload-dumper-go`, `avbtool 1.4.0` (`external/avb`
  `3328b7b60ae3`), `unpack_bootimg.py` (`system/tools/mkbootimg`
  `d2bb0af5ba6d`), `mkdtboimg.py` (`system/libufdt` `657f54c72d9e`),
  `dtc`/`fdtget`.

Legend: **[V]** = read from the extracted image with the named tool.
**[I]** = inference; check it on the device or in the code.

## Extracted images (SHA-256)

```
e8e1a0363883a4ea1f01bd282770d00fe59ae1adbf7b47e53bcbafa6c1278b47  boot.img           100663296 bytes
8b2bc24ace85517b40bd7da5676732f06ff2561b7089c904d278475acd01ddaf  dtbo.img            25165824 bytes
e48c51be59cb623f2ad65c97de22b4b9277ca0ab3712642d33a1166aac2cedd7  vbmeta.img              8192 bytes
6c1baf89bc11403ca9da162347c3f10794b098a6b29eb0c07f13389dc3ae3f47  vbmeta_system.img       4096 bytes
```

## 1. Partition list (payload)

[V] Full set, 44 partitions: `system`, `system_ext`, `product`, `vendor`,
`odm`, ten `my_*` (Oplus), `boot`, `recovery`, `dtbo`, `vbmeta`,
`vbmeta_system`, firmware (`abl`, `xbl`, `xbl_config`, `xbl_lp5`,
`xbl_config_lp5`, `aop`, `tz`, `hyp`, `devcfg`, `keymaster`, `cmnlib`,
`cmnlib64`, `storsec`, `qupfw`, `dsp`, `modem`, `bluetooth`, `imagefv`,
`uefisecapp`, `featenabler`, `multiimgoem`, `logo`) and two non-slotted
ones, `spunvm` and `mdm_oem_stanvbk`. No `init_boot`, no `vendor_boot`.
This matches the B2/B3 partition table on the phone.

- Restore warning stays: the payload carries both DDR4 (`xbl`,
  `xbl_config`) and DDR5 (`xbl_lp5`, `xbl_config_lp5`) loaders. Never flash
  an `xbl*` image by hand without `ro.boot.ddr_type` (scouting §1.5).
- [I] `spunvm` and `mdm_oem_stanvbk` show no `_a`/`_b` pair in B3's
  `getvar all`, yet the A/B payload names them. How update_engine writes a
  non-slotted partition is not our concern (the port never writes them),
  but it is worth knowing before any restore.

## 2. boot.img header

[V] `unpack_bootimg --format=info`:

- `boot image header version: 2`, `page size: 4096`. **R4 passes**; this
  confirms `docs/research/abl-boot-flow.md` §4 (header v2, not v3).
- kernel 45099024 bytes at `0x00008000`; ramdisk 1522741 bytes at
  `0x01000000`; no second stage; tags at `0x00000100`; DTB 11028247 bytes
  at `0x01f00000`; header size 1660; recovery dtbo size 0.
- `os version: 12.0.0`, `os patch level: 2024-06`. The kernel side reports
  Android 12, although the system runs Android 13.
- Stock cmdline:
  `console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xa90000
  androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1
  lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000
  msm_rtb.filter=0x237 service_locator.enable=1
  androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 loop.max_part=7
  cgroup.memory=nokmem,nosocket reboot=panic_warm kpti=off
  buildvariant=user`
  - [V] The debug UART is the GENI serial at `0xa90000`
    (`earlycon=msm_geni_serial,0xa90000`). The USB controller is
    `a600000.dwc3`.

## 3. Boot DTB (appended to boot.img)

[V] 21 concatenated DTBs with properties, plus one fragment without
`model`/`compatible` (only `qcom,rtic-id` and `MP_DATA`). Each of the seven
Oplus projects (19805, 19811, 19821, 19855, 20809, 20828 and a generic one)
appears three times, once per SoC revision:

| SoC rev | `qcom,msm-id` |
| --- | --- |
| v1 | `<0x164 0x10000>` |
| v2 | `<0x164 0x20000>` |
| v2.1 | `<0x164 0x20001>` |

- [V] All of them have `qcom,board-id = <0 0>` and `compatible = "qcom,kona"`.
- [V] Our unit's `ro.boot.prjname` is 19811 (stage-0 A3). Its DTBs carry
  `oplus,dtsi_no = <0x4d63>` (= 19811) and `oplus,pcb_range = <0 0x38>`.
- [I] So OnePlus's ABL picks the base DTB by msm-id plus `oplus,dtsi_no`
  against the project number, not by board-id alone. The generic
  Qualcomm ABL code does not know `oplus,dtsi_no`; this is an Oplus
  extension.

## 4. dtbo.img

[V] `mkdtboimg dump`: 19 entries, page size 4096. **Every table entry has
`id`, `rev` and `custom[0..3]` = 0**, so ABL cannot match on the dtbo
table fields. Each overlay carries its own `qcom,board-id` and
`oplus,dtsi_no` instead:

- Entry 16, `model = "Qualcomm Technologies, Inc. kona MTP 19811"`:
  `qcom,board-id = <0x10008 0>`, `oplus,dtsi_no = <0x4d63>`,
  `compatible = "qcom,kona-mtp", "qcom,kona", "qcom,mtp"`. [I] This is the
  overlay ABL applies on our unit.
- Sibling projects 19805/19821/20809/20828 use the same board-id
  `0x10008`. Entry 14 (20809, codename `kebabt`) also carries
  `oem,project-id` and `oem,hw-id`.
- The other entries are Qualcomm reference boards (MTP, CDP, QRD, HDK, XR,
  RUMI) with their usual board-ids.

Consequences [I]:

- `abl-boot-flow.md` item 5 assumed the community DTS's
  `qcom,board-id = <0x08 0x00>, <0x00 0x00>` reflects what ABL matches.
  Stock pairs base `board-id <0 0>` with an overlay `board-id <0x10008 0>`
  plus `oplus,dtsi_no`. Our DTB for a RAM boot (M1a) has to make ABL pick
  a base DTB, and then either match no stock overlay or one we have
  checked. The M1a plan's P3 overlay check should test with these exact
  properties: `msm-id 0x164/0x20001`, `board-id <0 0>`,
  `oplus,dtsi_no 0x4d63`.
- For M1b (`dtbo_b`), an empty or erased dtbo removes the overlay question
  altogether (the enchilada precedent, NOTES 2026-11-15).

## 5. AVB: vbmeta, boot and dtbo

[V] `avbtool info_image vbmeta.img`:

- `Algorithm: SHA256_RSA4096`, **`Flags: 0`** (verification on in stock
  vbmeta), rollback index 0.
- **`boot` and `dtbo` are Chain Partition descriptors**, not hash
  descriptors: `boot` at rollback index location 4, `dtbo` at location 3,
  `recovery` at location 1, `vbmeta_system` at location 2. The chain key
  for all of them is the same OnePlus key as the top-level vbmeta (public
  key sha1 `dcd6a215…a045`).
- `odm` and `vendor` are hashtree descriptors inside `vbmeta`.

[V] The chained images carry their own AVB footers (footer version 1.0):

| image | partition size | original image size | footer rollback index | props |
| --- | --- | --- | --- | --- |
| `boot` | 100663296 (96 MiB) | 57659392 | 0 | `os_version` 12, `security_patch` 2024-06-05 |
| `dtbo` | 25165824 (24 MiB) | 6894505 | 0 | fingerprint only |

Consequence for ticket #10, per the decision table in
`docs/research/vbmeta-avb.md` §5: **the chain case**. [V vbmeta-avb.md
§2.2] libavb follows the chain into `boot_b`; a `boot_b` without a valid
footer is invalid metadata and fatal even when unlocked. [I] Candidate
design: **option B** (§4.2), upstream's test-key `add_hash_footer` protocol
(`AVB_FOOTERS`), with the stock values it needs from this note: partition
size 100663296, rollback index 0, `com.android.build.boot.os_version` 12,
`security_patch` 2024-06-05. Option C (§4.3) stays a secondary experiment. The
same reasoning applies to `dtbo_b` (chained at location 3) if M1b writes
it rather than leaving it stock or erasing it. [I] Whether "erased" is
valid for a chained `dtbo` needs its own check, since an empty partition
has no footer either.

For M1a (RAM-only `fastboot boot`), `vbmeta-avb.md` §1 already notes [V]
that generic ABL skips the hash of a RAM-loaded boot image; the chain
result matters for the persistent M1b install.
