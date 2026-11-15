<!-- SPDX-License-Identifier: MIT -->
# Restore assets runbook: full OTA and MSM package for IN2023

Ticket: "Secure restore assets on local disk (full OTA + MSM package for
IN2023)". Laptop work. The phone is touched only to read the build id
(stage-0 runbook step A3). The assets back `docs/RESTORE-RUNBOOK.md` paths 1
and 2 and must be on disk **before** the unlock (stage-0 gate G1).

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
grep -E 'ro\.build\.(fingerprint|display\.id|version\.ota)' captures/*/build-boot-props.txt
```

- **Expect:** a fingerprint of the form
  `OnePlus/OnePlus8Pro_EEA/OnePlus8Pro:<android>/<build>/<incremental>:user/release-keys`
  [I: the EEA product name] and a display id such as `IN2023_11_<build>`
  [I]. Paste.
- **Stop:** product or model is not the EU/EEA IN2023. Other regional
  packages must never be flashed (RESTORE-RUNBOOK "Never do").
- **Rollback:** n/a.

### R2. Download the full OTA for exactly that build

Source: OnePlus's own servers. The usual way to get the official link to
the **full** (not incremental) package for a given build is the Oxygen
Updater app or the OnePlus community ROM thread for the 8 Pro. Either way,
the download host must be a OnePlus/OPPO CDN [I: e.g. `oxygenos.oneplus.net`
or an `allawnofs.com` host]. Do not use mirrors that repackage the zip.

```sh
cd "$R/ota" && curl -fLO '<official full-OTA URL>'
unzip -p <ota>.zip META-INF/com/android/metadata | grep -E '^(ota-type|post-build|pre-build|pre-device|post-timestamp)='
unzip -l <ota>.zip | grep -E 'payload\.bin|payload_properties\.txt'
```

- **Expect:** `ota-type=AB`; `pre-device=OnePlus8Pro` [I]; `post-build=`
  **byte-identical** to R1's `ro.build.fingerprint`; **no** `pre-build=`
  line (a `pre-build` line means incremental, which is useless for
  restore); `payload.bin` and `payload_properties.txt` are listed. Paste
  the `grep` lines.
- **Stop:** `post-build` differs from the running build, or a `pre-build`
  line exists. Keep looking; do not unlock (ticket stop condition). If the
  exact build cannot be found at all, say so in the ticket and in #808.
- **Rollback:** delete the zip.

### R3. Checksums

```sh
cd "$R/ota"
md5sum <ota>.zip            # compare with the MD5 published next to the download link
sha256sum <ota>.zip | tee -a SHA256SUMS
unzip -p <ota>.zip payload_properties.txt | grep -E 'FILE_HASH|FILE_SIZE'
unzip -o <ota>.zip payload.bin payload_properties.txt -d .
stat -c '%s %n' payload.bin && sha256sum payload.bin | tee -a SHA256SUMS
python3 -c 'import base64,hashlib,sys;print(base64.b64encode(hashlib.sha256(open(sys.argv[1],"rb").read()).digest()).decode())' payload.bin
```

- **Expect:** the MD5 matches the published value. `FILE_SIZE` equals the
  `stat` size of `payload.bin`. The last command's base64 output equals
  `FILE_HASH` (the OTA's own integrity field is the base64 SHA-256 of
  `payload.bin` [I: AOSP update_engine `payload_properties.txt` format]). Paste the comparison results: match or mismatch.
- **Stop:** any mismatch. Re-download; never use a payload that fails
  these checks.
- **Rollback:** delete and re-download.

### R4. Extract the slot images and answer stage-0 questions offline

Tools [I: names and packaging; any equivalent is fine]: `payload-dumper-go`
(AUR, or a GitHub release binary), and the AOSP Python tools from the
laptop setup's `SRC_DIR` (`system/tools/mkbootimg/unpack_bootimg.py`,
`external/avb/avbtool.py`, `system/libufdt/utils/src/mkdtboimg.py`).

```sh
cd "$R" && payload-dumper-go -l ota/payload.bin | tee images/partition-list.txt
payload-dumper-go -p boot,dtbo,vbmeta,vbmeta_system -o images ota/payload.bin
sha256sum images/*.img | tee images/SHA256SUMS
python3 "$SRC_DIR/system/tools/mkbootimg/unpack_bootimg.py" --boot_img images/boot.img --out "$TMPDIR/boot-unpacked" --format=info
python3 "$SRC_DIR/external/avb/avbtool.py" info_image --image images/vbmeta.img
python3 "$SRC_DIR/system/libufdt/utils/src/mkdtboimg.py" dump images/dtbo.img | grep -E 'dt_table|entry|id|rev|custom' | head -60
```

- **Expect:**
  - The partition list is a full image set: `boot`, `dtbo`, `vbmeta`,
    `system`, `vendor`, `product`, `odm`, plus firmware such as `abl`,
    `xbl`, `modem` [I]. [I] No `init_boot` and no `vendor_boot`.
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
7z l <package>.7z | grep -iE '\.ops|\.exe|instantnoodlep|IN21|EEA|EU' | head
sha256sum <package>.* | tee SHA256SUMS
```

- **Expect:** the archive tests clean. The listing contains an `.ops`
  firmware file whose name points at instantnoodlep and the EU/EEA model
  [I: naming varies, e.g. `instantnoodlep_..._EEA_...`] and an
  `MsmDownloadTool*.exe`. Paste the file names and the version number.
  Hash lookup only: you may look the SHA-256 up on VirusTotal by hash
  without uploading the file.
- **Stop:** the package names another model (IN2020/IN2021/IN2025, the
  8 or 8T) or a non-EU region. Never keep the wrong one around under a
  misleading name.
- **Stop (decision):** no Windows machine with a native USB port is
  available. EDL through a VM often fails. Path 2 is then unproven; record
  that and let the owner decide whether paths 0 and 1 are enough to go on.
- **Rollback:** delete the folder.

### R6. Record existence, never contents

Append to `device/instantnoodlep/NOTES.md` (newest first), English:

```
- Restore assets on local disk (<date>): full OTA for build <display id>,
  post-build fingerprint matches the running build, MD5 and payload
  FILE_HASH verified, SHA-256 <first 12 hex>...; MSM package version
  <version> for IN2023 EU, archive tested. Location: owner's local disk
  (outside the repo).
```

- **Expect:** a one-entry diff to NOTES.md that the coordinator commits.
- Resolution of the restore-assets ticket: R2-R5 passed and R6 is
  committed. The resolution comment repeats R6's text.
