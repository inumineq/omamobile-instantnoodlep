<!-- SPDX-License-Identifier: MIT -->
# Restore assets runbook: full OTA and MSM package for IN2023

Ticket: "Secure restore assets on local disk (full OTA + MSM package for
IN2023)". Mostly laptop work. The phone is touched to read the build id
(stage-0 runbook step A3) and, in R2, to download the full OTA in Oxygen
Updater and copy it off with `adb pull` (ordinary app data in `userdata`,
no partition write). The assets back `docs/RESTORE-RUNBOOK.md` paths 1 and
2 and must be on the laptop **before** the unlock (stage-0 gate G1): the
unlock wipes the phone, including any zip still stored on it.

Sources marked "scouting §n" are sections of
`docs/research/restore-assets-scouting.md`.

Storage, outside the repo (the patterns are gitignored anyway, but keep
them out of the tree):

```sh
R=~/android/reference/instantnoodlep; mkdir -p "$R"/{ota,images,msm}
```

Every step has **Expect**, **Stop** and **Rollback**. Paste back the
outputs marked "paste". They hold no identifiers: checksums of public
OnePlus files identify a build, not a phone.

---

### R1. Pin the exact installed build

From stage-0 step A3 (`captures/<date>/build-boot-props.txt`):

```sh
grep -E 'ro\.build\.(fingerprint|display\.id|date\.utc|version\.(ota|incremental))' captures/*/build-boot-props.txt
```

- **Expect:** a fingerprint of the form
  `OnePlus/OnePlus8Pro_EEA/OnePlus8Pro:<android>/<build>/<incremental>:user/release-keys`
  [I: the EEA product name] and a build id in one of two formats: OxygenOS
  13.0 `IN2023_11.F.xx` (some sources write `IN2023_11_F.xx`) or OxygenOS
  13.1 `IN2023_13.1.0.58x(EX01)` [V: 13.1 format, scouting §1.1; I: which
  of the two properties carries it]. Accept either. Paste.
- **Stop:** A3 shows `ro.boot.slot_suffix=_b`, or the running build is
  older than the final EEA build. Follow the decision tree in stage-0 step
  A3b first. R2 may download the final build's full zip before the slot
  move, because that zip is the input of the move; the build pinned here
  and R2's `post-build` check then use the A3 rerun that shows `_a`.
- **Stop:** product or model is not the EU/EEA IN2023. Other regional
  packages must never be flashed (RESTORE-RUNBOOK "Never do").
- **Rollback:** n/a.

### R2. Download the full OTA for exactly that build

Source: OnePlus's own servers, reached through the phone. A laptop `curl`
on an official OTA link gets `403 Access Denied`: OnePlus/OPPO have
blocked direct OTA downloads since 2024-09-02 [V scouting §1.2]. Do not
work around that with mirrors that repackage the zip.

On the phone, **before the unlock**: install Oxygen Updater (now named OS
Updater) from Google Play or its GitHub releases only [V scouting §1.3],
pick IN2023 / EU, and download the **full** (not incremental) package for
the build R1 pinned. OnePlus's own Local Update / System update screen is
an alternative [I: whether it offers the full package]. Oxygen Updater
shows and verifies the zip's MD5 [V scouting §1.4]; write that MD5 down for
R3. Known official hosts for IN2023 are `otafsg1.h2os.com`,
`otafsg-cost-az.coloros.com` and
`gauss-componentotacostmanual-{eu,sg}.allawnofs.com` [V scouting §1.2].
Allawnofs file names are hashes [I], so give the zip a local name such as
`IN2023_<build>_full.zip` (no parentheses).

```sh
adb shell 'find /sdcard -maxdepth 4 -name "*.zip" 2>/dev/null'
cd "$R/ota" && adb pull '/sdcard/<path from find>.zip' <ota>.zip
unzip -p <ota>.zip META-INF/com/android/metadata | grep -E '^(ota-type|post-build|post-build-incremental|pre-build|pre-device|post-timestamp)='
unzip -l <ota>.zip | grep -E 'payload\.bin|payload_properties\.txt'
```

- **Expect:** `find` lists the downloaded zip [I: where Oxygen Updater
  stores it varies by version; use the path the app shows if `find` misses
  it]. `ota-type=AB`; `pre-device=OnePlus8Pro` [I]; `post-build=`
  **byte-identical** to R1's `ro.build.fingerprint`; **no** `pre-build=`
  line (a `pre-build` line means incremental, which is useless for
  restore); `payload.bin` and `payload_properties.txt` are listed. Paste
  the `grep` lines.
- **Fallback [I, scouting §1.5]:** on Oplus builds the running fingerprint
  may be composed from region partitions. If `post-build` differs from
  R1's fingerprint **only** in a region or product segment, compare
  `post-build-incremental` with `ro.build.version.incremental` and
  `post-timestamp` with `ro.build.date.utc`. Both equal: accept the zip and
  say so in the paste. Either one different: wrong build.
- **Stop:** `post-build` differs and the fallback fails, or a `pre-build`
  line exists. Keep looking; do not unlock (ticket stop condition). If the
  exact build cannot be found at all, say so in the ticket and in #808.
- **Stop:** the zip is still only on the phone. Phase C (the unlock) waits
  until `adb pull` has finished and R3 passes on the laptop copy.
- **Rollback:** delete the zip (on the laptop and, if wanted, in Oxygen
  Updater on the phone).

### R3. Checksums

```sh
cd "$R/ota"
md5sum <ota>.zip            # compare with the MD5 Oxygen Updater showed (OnePlus publishes none)
sha256sum <ota>.zip | tee -a SHA256SUMS
unzip -p <ota>.zip payload_properties.txt | grep -E 'FILE_HASH|FILE_SIZE'
unzip -o <ota>.zip payload.bin payload_properties.txt -d .
stat -c '%s %n' payload.bin && sha256sum payload.bin | tee -a SHA256SUMS
python3 -c 'import base64,hashlib,sys;print(base64.b64encode(hashlib.sha256(open(sys.argv[1],"rb").read()).digest()).decode())' payload.bin
```

- **Expect:** the MD5 matches the value Oxygen Updater showed. OnePlus
  publishes no checksum next to its links; the MD5 is Oxygen Updater's
  database value [V scouting §1.4; I: harvested from OnePlus metadata].
  `FILE_SIZE` equals the `stat` size of `payload.bin`. The last command's
  base64 output equals
  `FILE_HASH` (the OTA's own integrity field is the base64 SHA-256 of
  `payload.bin` [V AOSP update_engine
  `payload_generator/payload_properties.cc:108-111`, SHA-256 via
  `HashCalculator`]). FILE_HASH proves the extraction is intact, **not**
  where the file came from. Provenance rests on three things together: the
  official CDN host, the Oxygen Updater MD5 and the payload `FILE_HASH`.
  Paste the comparison results: match or mismatch.
- **Stop:** any mismatch. Re-download; never use a payload that fails
  these checks.
- **Rollback:** delete and re-download.

### R4. Extract the slot images and answer stage-0 questions offline

Tools [I: names and packaging; any equivalent is fine]: `payload-dumper-go`
(AUR, or a GitHub release binary), and the AOSP Python tools from the
laptop setup's `SRC_DIR` (see `docs/research/laptop-build-setup.md`; set
it first, e.g. `export SRC_DIR=~/aosp-tools`) (`system/tools/mkbootimg/unpack_bootimg.py`,
`external/avb/avbtool.py`, `system/libufdt/utils/src/mkdtboimg.py`).

```sh
test -n "$SRC_DIR" && test -d "$SRC_DIR/system/tools/mkbootimg" || echo "SRC_DIR not set or wrong"
cd "$R" && payload-dumper-go -l ota/payload.bin | tee images/partition-list.txt
payload-dumper-go -p boot,dtbo,vbmeta,vbmeta_system -o images ota/payload.bin
sha256sum images/*.img | tee images/SHA256SUMS
python3 "$SRC_DIR/system/tools/mkbootimg/unpack_bootimg.py" --boot_img images/boot.img --out "$R/images/boot-unpacked" --format=info
python3 "$SRC_DIR/external/avb/avbtool.py" info_image --image images/vbmeta.img
python3 "$SRC_DIR/system/libufdt/utils/src/mkdtboimg.py" dump images/dtbo.img | grep -E 'dt_table|entry|id|rev|custom' | head -60
```

- **Expect:**
  - The partition list is a full image set: `boot`, `dtbo`, `vbmeta`,
    `system`, `vendor`, `product`, `odm`, plus firmware such as `abl`,
    `xbl`, `xbl_config`, `modem` [I]. Also expected, so that a correct EU
    package does not look wrong: the Oplus logical partitions `my_product`,
    `my_heytap`, `my_bigball`, `my_stock`, `my_region`, `my_manifest`,
    `my_engineering`, `my_carrier` and similar [I: seen on other Oplus
    models, scouting §1.5], and the DDR5 variants `xbl_lp5` and
    `xbl_config_lp5` [V LineageOS template, scouting §1.5]. [I] No
    `init_boot` and no `vendor_boot`.
  - Warning for any later restore: never flash an `xbl*` image without
    checking `ro.boot.ddr_type` (A3; 0 = DDR4, 1 = DDR5). The wrong XBL
    for the DDR type bricks the phone [V LineageOS template, scouting
    §1.5].
  - `unpack_bootimg`: `boot header version: 2` and `page size: 4096`
    (checks `docs/research/abl-boot-flow.md` §4), a non-empty `dtb` size,
    the kernel/ramdisk/second/tags offsets, and the stock `cmdline`.
  - `avbtool info_image`: the `Flags` value. `0` means verification is on
    in stock vbmeta. It also shows whether `boot` and `dtbo` are Hash
    descriptors inside `vbmeta` or chained partitions with their own keys.
    That is the main input for the ticket "vbmeta/AVB handling on an
    unlocked Qualcomm ABL".
  - `mkdtboimg dump`: the number of dtbo entries and their `id`/`rev`/
    `custom` fields. These are the board/msm ids ABL matches. Compare them
    with `qcom,msm-id`/`qcom,board-id` in `docs/research/abl-boot-flow.md`
    review item 5.
  - Paste all of it. None of it is device-unique.
- **Stop:** `boot header version` is not 2. Several research conclusions
  change; report before continuing.
- **Rollback:** delete `images/`.

### R5. MSM Download Tool package (last-resort restore)

The package for the EU model circulates on forums (XDA). It is the
owner's private recovery copy. It is **never** committed, linked from this
repo or mentioned in upstream issues as a download (AGENTS.md rule 5).

```sh
cd "$R/msm" && ls -la
7z t <package>.7z || unzip -t <package>.zip
7z l <package>.7z | grep -iE '\.ops|\.exe|IN11|IN2023|instantnoodlep|EU' | head
sha256sum <package>.* | tee SHA256SUMS
```

- **Expect:** the archive tests clean. The package (folder or archive)
  name carries the EU region code `IN11BA` or `EU`/`IN2023` [V: 8 Pro EU
  is `IN11BA`, scouting §3.1]; that name, not the `.ops` name, proves the
  region. The listing contains an `.ops` firmware file
  [I: expect `instantnoodlep_<n>_<letter>.<nn>_<YYMMDD>.ops`] and
  `MsmDownloadTool V4.0.exe` plus `MsmDownloadTool V4.0_Win7.exe`; the Win7
  variant is required for OxygenOS 11 firmware [V scouting §3.1]. EU MSM
  packages exist only for OxygenOS 10.5.4 up to 11.0.4.4 [V scouting
  §3.1], so path 2 ends on **locked OxygenOS 11**, not on the current
  build. Paste the file names and the version number. Hash lookup only:
  you may look the SHA-256 up on VirusTotal by hash without uploading the
  file.
- **Stop:** any name contains `IN21xx` (`IN21AA`/`IN21BA`/`IN21DA`). That
  is the OnePlus 8 (non-Pro), the wrong phone [V scouting §3.1].
- **Stop:** the package names another model (IN2020/IN2021/IN2025, the
  8 or 8T) or a non-EU region (`IN11AA` global, `IN11DA` India). Never
  keep the wrong one around under a misleading name.
- **Stop (decision):** no Windows machine with a native USB port is
  available. EDL through a VM often fails [I: no successful report found,
  scouting §3.1]. Path 2 is then unproven; record that and let the owner
  decide whether paths 0 and 1 are enough to go on.
- **Rollback:** delete the folder.

### R6. Record existence, never contents

Append to `device/instantnoodlep/NOTES.md` (newest first), English:

```
- Restore assets on local disk (<date>): full OTA for build <display id>,
  post-build fingerprint matches the running build (or: incremental and
  build date match, fallback used), Oxygen Updater MD5 and payload
  FILE_HASH verified, SHA-256 <first 12 hex>...; MSM package version
  <version> (IN11BA, OxygenOS 11) for IN2023 EU, archive tested.
  Location: owner's local disk (outside the repo).
```

- **Expect:** a one-entry diff to NOTES.md that the coordinator commits.
- Resolution of the restore-assets ticket: R2-R5 passed and R6 is
  committed. The resolution comment repeats R6's text.
