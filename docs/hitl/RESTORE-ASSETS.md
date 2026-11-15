<!-- SPDX-License-Identifier: MIT -->
# HITL runbook: secure the restore assets (IN2023)

For the ticket "Secure restore assets on local disk (full OTA + MSM package
for IN2023)". **The owner runs everything here; agents prepare it and read
the pasted output.** Every block lists Expect, a stop condition and a
rollback (repo AGENTS.md rule 1).

Nothing in this runbook writes to the phone. Part A reads two properties
over adb. Everything else happens on the laptop.

Conventions:

- `REF=~/android/reference/instantnoodlep` is the private asset folder
  (outside the repo, never committed; upstream keeps captures in
  `~/android/reference`).
- Paste output back into the ticket **only after redaction**: drop serial
  numbers, the IMEI and MAC addresses. The build fingerprint and OTA
  checksums are public and may be pasted.
- `[V]` = checked against a source. `[I]` = expected; your output decides.

## Gate

| Check | Pass |
| --- | --- |
| Laptop has `adb`, `fastboot`, `unzip`, `sha256sum`, `python3`, `openssl` | `command -v adb fastboot unzip sha256sum python3 openssl` prints six paths |
| Free disk space for OTA + extracted images | `df -h ~` shows at least 15 GB free (an OTA is several GB; images double it) [I] |

## Part A: identify the exact installed build (phone booted, stock, USB debugging on)

```sh
mkdir -p "$REF" && cd "$REF"
adb shell getprop ro.build.fingerprint | tee build-fingerprint.txt
adb shell getprop ro.build.display.id  | tee build-display-id.txt
adb shell getprop ro.product.device
```

- **Expect:** a OnePlus fingerprint for the OnePlus 8 Pro, a build string
  that names the IN2023/EU line, and a device name that identifies the 8 Pro
  [I: exact strings unknown until you run it].
- **Stop if:** the device name is not the OnePlus 8 Pro, or the build is not
  the EU/IN2023 line. Every later step depends on matching this build.
- **Rollback:** none needed (read-only).

## Part B: the full OTA for exactly that build

1. Download the **full** OTA zip (not an incremental) for the build string
   from Part A. Use a source that publishes OnePlus's own download links
   together with a checksum. Keep the published checksum. Save it to
   `$REF/ota/`.

2. Check that it is the right package:

   ```sh
   cd "$REF/ota"
   sha256sum *.zip | tee SHA256SUMS
   md5sum *.zip                       # compare with the published MD5 if that is what the site gives
   unzip -l *.zip | grep -E 'payload.bin|payload_properties.txt|META-INF/com/android/metadata'
   unzip -p *.zip META-INF/com/android/metadata | grep -E '^(ota-type|pre-device|pre-build|post-build)='
   ```

   - **Expect:** the published checksum matches. The zip contains
     `payload.bin`, `payload_properties.txt` and the metadata file.
     `ota-type=AB`. `post-build=` equals `build-fingerprint.txt` from
     Part A. **No `pre-build=` line**, because a full OTA has no source
     build [I: AOSP OTA metadata convention].
   - **Stop if:** the checksum differs, a `pre-build=` line is present
     (incremental), or `post-build` does not match the phone. Do not
     unlock with a non-matching OTA (ticket stop condition).
   - **Rollback:** delete the zip and download again.

3. Check payload integrity with the hash shipped inside the OTA:

   ```sh
   unzip -p *.zip payload_properties.txt | grep FILE_HASH
   unzip -p *.zip payload.bin | openssl dgst -sha256 -binary | base64
   ```

   - **Expect:** the two base64 strings are identical [I: `FILE_HASH` is the
     base64 SHA-256 of `payload.bin` in AOSP's payload tooling].
   - **Stop if:** they differ.

4. Extract the images to a private folder. `payload-dumper-go` is one
   extractor; check its `--help` for exact flags [I]:

   ```sh
   mkdir -p "$REF/images" && cd "$REF/images"
   unzip -p ../ota/*.zip payload.bin > payload.bin
   payload-dumper-go -l payload.bin | tee ../payload-partitions.txt      # list only
   payload-dumper-go -o . payload.bin                                    # extract all
   sha256sum *.img | tee SHA256SUMS
   ```

   - **Expect:** the partition list contains `boot`, `dtbo`, `vbmeta`,
     probably `vbmeta_system`, plus `system`, `vendor`, `product`, `odm`,
     `modem` and the firmware partitions. It contains **no** `init_boot`,
     `vendor_boot` or `vendor_kernel_boot` [I: `docs/research/abl-boot-flow.md` §4].
   - **Stop if:** extraction fails or reports a hash error.
   - **Rollback:** delete `$REF/images` and extract again.

## Part C: offline analysis of the stock boot chain (laptop only)

These steps answer part of stage 0 before the phone is touched. They need
AOSP `mkbootimg` tools (`unpack_bootimg.py`, `mkdtboimg.py`), `avbtool.py`
and `dtc`. Install paths per `docs/research/laptop-setup.md`.

```sh
cd "$REF/images"
python3 "$MKBOOTIMG_DIR/unpack_bootimg.py" --boot_img boot.img --out ../boot-unpacked | tee ../boot-header.txt
python3 "$MKDTBOIMG" dump dtbo.img | tee ../dtbo-dump.txt
python3 "$AVBTOOL" info_image --image vbmeta.img | tee ../vbmeta-info.txt
test -f vbmeta_system.img && python3 "$AVBTOOL" info_image --image vbmeta_system.img | tee ../vbmeta_system-info.txt
```

- **Expect:**
  - `boot-header.txt`: `header version: 2`, page size `4096`, a non-empty
    `dtb` section, and the stock command line. These answer the header
    question [I: `abl-boot-flow.md` §4 predicts v2].
  - `dtbo-dump.txt`: a list of overlay entries with `id`/`rev` values. That
    is the stock board-overlay format the bootloader picks from [I].
  - `vbmeta-info.txt`: the flags, rollback index, and which images are
    covered by hash descriptors versus chain partitions (look for `boot`,
    `dtbo`, `vbmeta_system`). This is evidence for the vbmeta grilling
    ticket.
- **Stop if:** header version is not 2. Post it in the ticket first, because
  the layout research then needs revisiting.
- **Rollback:** none (files only).

Paste `boot-header.txt` (it holds the stock cmdline; remove any
`androidboot.serialno=` value if present), `dtbo-dump.txt` and
`vbmeta-info.txt` into the ticket. None of them should contain unit
identifiers. Check anyway with the redaction grep in
`docs/hitl/STAGE-0.md` Part F.

## Part D: MSM Download Tool package (last resort, store only)

**Do not run it.** It wipes the phone and relocks the bootloader
(`docs/RESTORE-RUNBOOK.md` Path 2). This part only gets it onto local disk
while links still exist.

1. Get the MSM package for **IN2023 / EU** from a source you trust. It is a
   circulating vendor service tool. It stays on your disk only: never in
   this repo and never linked from upstream issues.
2. Store it under `$REF/msm/`, then:

   ```sh
   cd "$REF/msm" && sha256sum * | tee SHA256SUMS
   ```

3. Note the target model and region the package states (file name or
   readme). Note that it needs Windows, administrator rights, the Qualcomm
   HS-USB QDLoader 9008 driver, and preferably a USB 2.0 port.

- **Expect:** the package names IN2023 / EU (or the EU carrier line).
- **Stop if:** it names another variant (IN2020/IN2021/IN2025). Using the
  wrong MSM package is on the runbook's "never do" list.
- **Rollback:** delete it.

## Part E: record existence (not contents)

Add a dated entry to `device/instantnoodlep/NOTES.md`, or send it to the
coordinator to add:

- OTA: build string, file name, SHA-256 (public values), location as
  `~/android/reference/instantnoodlep/ota/`.
- Images extracted: yes, partition list (from `payload-partitions.txt`).
- MSM package: present, stated target model, SHA-256, Windows prerequisites
  noted.

**Resolved when:** Parts A-E pass. Part C's outputs are pasted in the
ticket, and both assets are recorded as present. Stage 0's unlock step stays
gated on this ticket.
