<!-- SPDX-License-Identifier: MIT -->
# Restore-asset scouting: OnePlus 8 Pro IN2023 (EU/EEA, instantnoodlep)

- Origin: read-only web research, 2026-11-15; landed below the review
  without changes to its findings.
- Ticket: "Secure restore assets on local disk (full OTA + MSM package for
  IN2023)".

## Coordinator review (2026-11-15): how the corrections were applied

The "Runbook corrections" list at the end cites line numbers at `8a1752e`
(a local review branch). The runbook text there is identical to `78b4b1d`
on main [V: `git diff 78b4b1d 8a1752e -- docs/runbooks docs/RESTORE-RUNBOOK.md`
is empty]. Where this review disagrees with the body, the review wins.

1. Corrections 1-8, 10 and 11 are applied to
   `docs/runbooks/RESTORE-ASSETS.md`, `docs/runbooks/STAGE-0-RUNBOOK.md`
   and `docs/RESTORE-RUNBOOK.md`. Correction 10 became a decision tree,
   stage-0 step A3b.
2. **Correction 9 is not applied as written.** No EDL step was added. The
   radio partitions (`persist`, `modemst1`, `modemst2`, `fsg`, `fsc`) are
   read with `dd` in the existing temporary-root session (stage-0 D4).
   `bkerler/edl` stays an optional, [I], owner-decision alternative.
3. **Correction 12 is not applied as written.** The hard rule is not
   loosened. The port's tooling never writes `super` or any `_a`
   partition. Restore path 1 is reworded as the owner's own recovery with
   OnePlus's images, outside that tooling, and is recorded if used.
4. Widevine: the advice to record the DRM Info level before the unlock
   (section 4) is now stage-0 step A5 and part of gate G1.

---

Read-only web research for `docs/runbooks/RESTORE-ASSETS.md` and
`docs/RESTORE-RUNBOOK.md`. Date of research: 2026-11-15. Nothing was
downloaded except public text (READMEs, release notes, wiki YAML). No file
mirrors are linked here.

Legend: **[V]** = checked against the cited page (fetched, or read from
source). **[I]** = inference, search snippet I could not open, or forum
anecdote. Check it on the device or in the file. Several XDA,
AndroidAuthority and PhoneArena pages returned HTTP 403 to the fetcher.
Claims that rest only on them are marked [I], with the URL as a pointer.

---

## 1. Full OTA: builds, hosts, how to get the link, checksums, format

### 1.1 Build history for IN2023 (EU, region code `IN11BA` / `EX01`)

| Era | Version / build id format | SPL / date | Tag |
|---|---|---|---|
| OOS 10.5 / 11 | `10.5.x.IN11BA`, `11.0.x.x.IN11BA` (last listed: `11.0.11.11.IN11BA`, SPL 2022-02) | 2020-03 .. 2022-02 | [V] https://www.thecustomdroid.com/download-oneplus-8-pro-oxygenos-ota-updates |
| OOS 12 | `C.15`, `C.16`, `C.20`, `C.21`, `C.33`, `C.35`, `C.36` | SPL 2022-03 .. 2022-10 | [V] same page |
| OOS 13 | `F.13` (SPL 2022-10), `F.15` (SPL 2022-12). The full string seen is `IN2023_11.F.13`, `IN2023_11.F.15` | Nov 2022 onward | [V] same page; F.13 as `IN2023_11.F.13`: [I] https://www.notebookcheck.com/OnePlus-8-Pro-8T-und-weitere-Modelle-bekommen-das-grosse-Update-auf-OxygenOS-13-und-Android-13.668688.0.html |
| OOS 13 | `IN2023_11.F.62`/`F.63` (Mar 2023), `F.64` (Apr 2023, NA example only) | 2023-03/04 | [I] https://www.theupdatebox.com/?p=1950, https://techibee.in/oneplus-8-and-8-pro-grabbed-oxygenos-13-f-64-update-with-april-2023-security-patch/ |
| OOS 13.1 | `IN2023_13.1.0.582(EX01)`, EU, Aug 2023 SPL (India first, 2023-08-29) | 2023-08/09 | [V] https://techibee.in/oneplus-8-8-pro-and-9r-pick-oxygenos-13-1-0-582-update/ |
| OOS 13.1 | `13.1.0.586` (Feb 2024 SPL, India: `IN2021_13.1.0.586(EX01)`) | 2024-02 | [I] https://thetechoutlook.com/news/os/oneplus-8-and-8-pro-receive-the-oxygenos-13-1-0-586-update-in-india-february-2024-android-security-patch |
| OOS 13.1 | `13.1.0.587`, April 2024 SPL, announced as the "last scheduled update". India first, "other regions soon" | 2024-04 | [I] https://www.tuttoandroid.net/news/2024/04/25/oneplus-8-pro-ultimo-aggiornamento-1040937/ (AndroidAuthority 403) |
| OOS 13.1 | `13.1.0.590`, **India only** (`IN2021_13.1.0.590(EX01)`), no new SPL | 2024-06-12 | [V] https://www.thetechoutlook.com/news/os/oneplus-8-8-pro-gets-its-final-oxygenos-13-1-0-590-update-a-final-goodbye-from-oneplus/ |

Findings:

- [I] OxygenOS 13 is the last major OS for the 8 series. Android 14 never
  shipped (Android Central, linked from the search; 13.1 builds are the
  last ones in all sources above).
- [I] **The latest EEA build is most likely `IN2023_13.1.0.587(EX01)`
  (or 586).** I found no source naming an EU 587 or 590 build. 590 was
  India-only [V above]. The owner's own A3 output decides this. Do not
  assume.
- [I] **The display id format changed between 13.0 and 13.1:**
  `IN2023_11_F.xx` (13.0) versus `IN2023_13.1.0.5xx(EX01)` (13.1). Which of
  these appears in `ro.build.display.id` and which in `ro.build.version.ota`
  on the device has to come from A3. The runbook's `IN2023_11_<build>`
  matches only the 13.0 era.
- [V] The device is end-of-life: no further OTAs. This matters for slot
  moving, see section 2.

### 1.2 Official hosts (CDN hostnames)

- [V] Historic full-OTA links for IN2023, per the build table above:
  - `otafsg1.h2os.com` (OOS 10.5 to 11.0.8)
  - `otafsg-cost-az.coloros.com` (11.0.9 to C.16)
  - `gauss-componentotacostmanual-sg.allawnofs.com` and
    `gauss-componentotacostmanual-eu.allawnofs.com` (C.20 to F.15)

  Source: https://www.thecustomdroid.com/download-oneplus-8-pro-oxygenos-ota-updates.
  [I] `oxygenos.oneplus.net` did not appear for this device in any source.
- [I] Other allawnofs hosts also appear in the wild:
  `gauss-otacostmanual-in.allawnofs.com` and
  `gauss-opexcostmanual-sg.allawnofs.com`, with paths like
  `/remove-<hash>/component-ota/<date>/<hash>.zip`. The file names are
  hashes, not build names (seen in Telegram and doc listings from search
  results; not opened).
- [V] **Gotcha: since 2024-09-02, OnePlus/OPPO block direct OTA zip
  downloads.** Links on the IN, SG and EU servers returned
  `403 Access Denied`. Oxygen Updater worked around it in v6.4.0 by
  sending the platform-default HTTP user agent (commit `347926af`).
  Sources:
  https://github.com/oxygen-updater/oxygen-updater/releases/tag/v6.4.0 and
  https://github.com/oxygen-updater/oxygen-updater/commit/347926af24553b3b7f72b4f569143c74c318919c.
  [I] Consequence: a plain laptop `curl -fLO` may get 403. The simplest
  route is to download inside Oxygen Updater (now named "OS Updater",
  v7.0.0, 2026-04 [V release notes]) on the phone and copy the zip off.
- [V] Oxygen Updater v6.8.0 added auto-refresh of *expiring* "dynamic"
  download URLs, but for OxygenOS/ColorOS 16+ only. [I] OOS 13 links for
  this device are probably static, but a copied link can still go stale.

### 1.3 How people get the official link

- [V] LineageOS's own firmware-update instructions for this device class
  tell users to "Download the latest Android 13 full stock ROM update from
  Oxygen Updater" and extract it with payload-dumper-go:
  https://github.com/LineageOS/lineage_wiki/blob/main/_includes/templates/device_specific/firmware_update_oplus_sm8250.md
  (instantnoodlep uses `firmware_update: firmware_update_oplus_sm8250` and
  `before_install: needs_specific_android_fw, version '13'`:
  https://github.com/LineageOS/lineage_wiki/blob/main/_data/devices/instantnoodlep.yml).
- [V] Oxygen Updater is open source. It publishes only via Google Play and
  GitHub releases ("all others should not be trusted"):
  https://github.com/oxygen-updater/oxygen-updater
- [I] Third-party guides say Oxygen Updater offers the *same* full build the
  phone already runs, which suits the "exact build" requirement:
  https://droidwin.com/?p=58149
- [I] The OnePlus Community "ROM" threads for the 8 series are referenced
  by news sites; I found no fetchable official OnePlus page that lists 8
  Pro full-OTA links. OnePlus's own software download pages do not carry
  this device's OOS 13 zips (not confirmed; the support page rendered
  empty).

### 1.4 MD5 / SHA

- [V] OnePlus does not publish checksums next to the links in any source I
  could read. The CustomDroid table has none.
- [V] Oxygen Updater shows the MD5 of the update zip in the app (v4.0.0)
  and verifies the MD5 after download (v6.2.0 mentions "after MD5
  verification"). On a mismatch it shows the download link (v4.2.0).
  https://github.com/oxygen-updater/oxygen-updater/releases
- [I] So the "published MD5" is Oxygen Updater's database value (third
  party, harvested from OnePlus metadata), not a OnePlus publication.
  Provenance therefore rests on: official CDN host + Oxygen Updater MD5 +
  the zip's own signature/`FILE_HASH`.

### 1.5 Format gotchas (OOS 12/13 on the 8 series)

- [V] AOSP: `META-INF/com/android/metadata` carries `pre-device` (from
  `ro.product.device`) and `pre-build`/`post-build` (from
  `ro.build.fingerprint`). https://source.android.com/docs/core/ota/tools
- [I] `ro.product.device` should be `OnePlus8Pro` (iFixit names the
  "Android build name OnePlus8Pro" for IN2023; LineageOS codename
  instantnoodlep is the *tree* name, not the OTA device name).
- [I] OOS 12+ for the 8 series moved to the OPPO/ColorOS base. The full OTA
  is still an A/B `payload.bin` zip (LineageOS extracts it with
  payload-dumper-go [V template above]). Expect extra OPPO logical
  partitions (`my_product`, `my_heytap`, `my_bigball`, `my_stock`,
  `my_region`, `my_manifest`, `my_engineering`, `my_carrier`, ...) in the
  payload, beside `system`/`vendor`/`product`/`odm`. These are reported for
  other Oplus models (https://www.daxiaamu.com/8657/,
  https://droidwin.com/?p=22666). Not confirmed for instantnoodlep.
- [V] The full OTA's firmware image set for SM8250 Oplus (per the LineageOS
  template) includes: `abl aop bluetooth cmnlib64 cmnlib devcfg dsp
  featenabler hyp imagefv keymaster logo mdm_oem_stanvbk modem multiimgoem
  qupfw spunvm storsec tz uefisecapp xbl xbl_config` **plus DDR5 variants
  `xbl_lp5` and `xbl_config_lp5`**. The template warns that flashing the
  wrong XBL for the DDR type bricks the phone (`ro.boot.ddr_type` 0=DDR4,
  1=DDR5).
- [V] The 8 Pro has a dedicated `recovery` partition
  (`recovery_partition_name: recovery`) and LineageOS treats `dtbo` and
  `vbmeta` as the boot stack. This is consistent with the runbook's
  "no `vendor_boot`/`init_boot`" [I] expectation.
- [I] On Oplus builds, `ro.build.fingerprint` may be composed at runtime
  from region partitions (`my_manifest`/`my_region`). A strict
  byte-for-byte match of OTA `post-build` against the running fingerprint
  could then fail falsely. If it does, compare
  `ro.build.version.incremental`/`ro.build.version.ota` and the build
  date before concluding "wrong build".

---

## 2. Local upgrade on OxygenOS 13, and moving stock from slot B to A

- [V] A/B mechanics: update_engine "will update the raw blocks on the
  currently unused partition", then "the unused slot is marked as active by
  calling `setActiveBootSlot()`", then `markBootSuccessful()` after boot.
  https://source.android.com/docs/core/ota/ab
  So any successful OTA install, full or incremental, local or over the
  air, while running on `_b` writes slot A and makes A active.
- [V] On OOS 13 the "Local install" entry is hidden by default. Oxygen
  Updater documents that enabling Developer options makes "Local install"
  visible again, and offers an APK "provided by OnePlus" that appears as
  "System update" when the menu stays hidden.
  https://oxygenupdater.com/article/367/ (written for the 10T on OOS 13;
  [I] the same applies to the 8 Pro on OOS 13).
- [I] Path per guides: Settings → About device → (OxygenOS/version card) →
  ⋮ → Local install. Needs about 5 GB free. Rooted or modified devices need
  a full (not incremental) zip.
- [I] **End-of-life consequence:** if the phone already runs the final EEA
  build, no "next official OTA" will ever arrive. The only stock-updater
  route to flip B→A is a **local install of the same full build**. Whether
  the Oplus updater accepts a same-version package is not documented. Some
  guides suggest it does (they offer the same build for local install), but
  it must be tested. If the phone is one build behind, the official OTA
  flips slots by itself.
- [V, stage-0 on the owner's IN2023, 2026-11-16] **The Oplus updater
  accepts a same-version full zip.** A local install of the `.591` full
  zip while stock ran `.591` from `_b` booted with `ro.boot.slot_suffix`
  = `_a`, the same fingerprint, still locked and `green`. The phone is
  Virtual A/B: the install left `*_a-cow` snapshot partitions in `super`
  that must merge before any wipe (STAGE-0-RUNBOOK B4).
- [I] A downgrade via local install is normally refused by the Oplus
  updater (rollback packages are special "rollback" builds that wipe data).
  Do not use a rollback package for slot moving.

---

## 3. MSM Download Tool (IN2023 EU) and bkerler/edl

### 3.1 MSM packages

- [V] Packages are "decrypted OxygenOS" bundles (MsmDownloadTool `.exe` +
  `.ops` image). For the 8 Pro EU (IN2023) they are `IN11BA` builds
  **10.5.4 through 11.0.4.4 only (Android 10/11)**. The same goes for
  Global `IN11AA` and India `IN11DA`. The OnePlus 8 (non-Pro) uses
  `IN21AA/BA/DA`. Tool names: `MsmDownloadTool V4.0.exe`;
  `MsmDownloadTool V4.0_Win7.exe` is required for the OOS 11 firmware.
  https://www.thecustomdroid.com/oneplus-8-pro-unbrick-guide/
- [I] No public Android 12/13 EU MSM package for the 8 Pro turned up
  (techibee's collection tops out at `OnePlus_8_Pro_EU_OxygenOS_11.0.4.4`).
  An MSM restore therefore lands on locked **OOS 11**. Getting back to OOS
  13 means a chain of full OTAs (11 → 12 → 13/13.1) through the stock
  updater, and LineageOS later needs Android 13 firmware.
- [I] `.ops` naming pattern from the sister device:
  `instantnoodle_15_O.20_200716.ops` (OP8). For the 8 Pro expect
  `instantnoodlep_<n>_<letter>.<nn>_<YYMMDD>.ops`. The letter/number encode
  the build and region, so the name alone does not prove EU. Confirm via
  the package's folder/zip name (`IN11BA`/`EU`/`IN2023`) and the thread
  listing. The original publisher on XDA is "Some_Random_Username", thread
  "[OP8PRO][OOS 11AA/BA/DA] Unbrick tool to restore your device to
  OxygenOS" (forum id 4084953; returned 403 to the fetcher).
- [I] Newer MSM builds have a "Target" selector (O2/India/EU). Pick EU for
  the European package (XDA post on the Nord thread, search snippet).
- [V] Windows requirements and pitfalls (CustomDroid guide):
  - Windows only.
  - The phone must enumerate as "Qualcomm HS-USB QDLoader 9008". If it
    shows as `QUSB_BULK`, install the Qualcomm driver.
  - For "Sahara Communication Failed", use a USB 2.0 port.
  - Some antivirus tools flag the tool (VMProtect).
  - User type "Other", then Start.
  - EDL entry: phone off, hold Vol+ and Vol− while plugging in USB.
    Alternatives are `adb reboot edl` and `fastboot oem edl`.
  - **Never use "SMT Download" mode: it erases the IMEI and the Widevine
    certificate.**
  - The tool relocks the bootloader.
- [V] The XDA news piece confirms that the tool wipes the phone and
  relocks the bootloader. It also recommends backing up `persist` first,
  because cross-flashing can cause fingerprint enrollment errors.
  https://www.xda-developers.com/oneplus-8-pro-unbrick-tool-now-available/
- [I] Admin rights are generally recommended for driver install. No
  primary source confirms they are needed for the tool itself.
- [I] **VM with USB passthrough: not recommended.** I found no successful
  report. One USB-redirection report fails at the Sahara stage
  (https://www.virtualhere.com/node/4807). The device re-enumerates
  between Sahara and Firehose, and passthrough filters often lose it. A
  native Windows install (or a Windows-To-Go stick) on a USB 2.0 port is
  the reliable option. This matches the runbook's R5 stop.

### 3.2 bkerler/edl (open source, GPLv3)

- [V] OnePlus auth is implemented: `edlclient/Library/Modules/oneplus.py`
  lists `"19811": version=2 ... # OP8 Pro, instantnoodlep` (along with OP8
  `19821`, OP8T `19805`). It runs the `demacia` / `setprojmodel` handshake
  automatically.
  https://github.com/bkerler/edl/blob/master/edlclient/Library/Modules/oneplus.py
- [V] The README lists the OnePlus 8/8T among the "Tested with" devices,
  annotated "(Read-Only)". Read commands for UFS:
  `edl rl dumps --memory=ufs --genxml` (all LUNs) and
  `edl rl dumps --memory=ufs --lun=0 --skip=userdata,...`;
  `edl gpt . --genxml --memory=ufs`; `edl printgpt`.
  https://github.com/bkerler/edl/blob/master/README.md (lines ~213–246, 322)
- [V] A loader is needed. The bkerler/Loaders repo holds
  `oneplus/000c30e100514d6d_..._fhprg_op8_op8tmo_op8t_op8ttmo.bin`
  (SM8250 HWID `000c30e1`). The 8 Pro is not named in it.
  https://github.com/bkerler/Loaders/tree/main/oneplus
  [I] It probably works for the 8 Pro (same SoC/OEM key), or use the
  firehose from the owner's own MSM package via `--loader`. Both are
  proprietary OnePlus binaries: describe them, do not commit them
  (AGENTS.md rules 5/8).
- [V] Windows needs the Qualcomm 9008 driver plus UsbDk. Linux needs the
  udev rules script from the repo. Linux works natively, so no VM is
  needed.
- [I] **A read-only EDL backup is the most valuable extra restore asset.**
  `persist`, `modemst1/2`, `fsg`, `ocdt` and `param` are device-unique and
  are in no OTA or MSM package. They hold IMEI/calibration data, so they
  belong under `captures/` rules (never committed). EDL reads leave the
  bootloader locked. Test it first with `edl printgpt`.

---

## 4. Unlock side effects specific to the OnePlus 8 Pro

- **Data:** [V] The unlock wipes userdata (all unlock guides; e.g.
  https://digistatement.com/oneplus-8-and-8-pro-unlock-bootloader-guide).
- **Widevine:** [I] Mixed reports. One recent XDA guide says Qualcomm
  OnePlus devices drop L1→L3 on unlock (attestation workaround reported
  working on the 8T/9 Pro). Older 8 Pro threads report some units keeping
  L1 while unlocked and others not. Relocking with stock images restores
  L1. Pointers (403 to the fetcher):
  https://xdaforums.com/t/fix-widevine-l1-unlocked-bootloader.4731374/,
  https://xdaforums.com/t/widevine-security-level-after-unlocking-bootloader-root.4180619/,
  https://xdaforums.com/t/bootloader-widevine-l1.4092027/.
  [I] A separate, unrelated L3 bug on locked phones came with OOS 10.5.5
  and was fixed in 10.5.11
  (https://piunikaweb.com/2020/05/11/oneplus-8-pro-widevine-l1-reportedly-downgraded-to-l3-after-recent-update-for-some/,
  per search results). **Plan for L3 after unlock.** Record the DRM Info
  level before the unlock as a baseline.
- **Widevine keybox / IMEI:** [V] They are lost only by MSM "SMT" mode
  (see 3.1), not by the unlock itself. [I] A corrupted `persist` breaks
  the fingerprint sensor, so back it up (3.2).
- **Camera:** [I] No source reports camera loss from unlocking on stock
  OOS for the 8 Pro (unlike Sony DRM keys). The 5 MP colour-filter camera
  was software-limited by OnePlus in 2020 regardless.
- **Play Integrity / banking:** [V] On Android 13+, `MEETS_DEVICE_INTEGRITY`
  requires "hardware-backed proof that the device bootloader is locked and
  the loaded Android OS is a certified device manufacturer image".
  `MEETS_STRONG_INTEGRITY` on Android 13+ also needs security updates in
  the last year for all partitions.
  https://developer.android.com/google/play/integrity/verdicts
  [I] Hence, after unlocking on OOS 13, only `MEETS_BASIC_INTEGRITY` is
  realistic, and many banking/payment apps (Google Wallet tap-to-pay) stop
  working. Even locked, `STRONG` already fails today: the last EEA SPL is
  around April 2024, more than a year ago. Relocking requires full stock
  restore first.

---

## Runbook corrections

Line references are to the files as of HEAD `8a1752e`.

1. **RESTORE-ASSETS.md:32–33**: the display-id example `IN2023_11_<build>`
   fits only OOS 13.0 (`IN2023_11_F.xx`). On 13.1 (the likely current state)
   builds are named `IN2023_13.1.0.58x(EX01)` [V techibee]. Accept either.
2. **RESTORE-ASSETS.md:45–47**: hosts. Replace
   `oxygenos.oneplus.net` with the hosts actually seen for IN2023:
   `otafsg1.h2os.com`, `otafsg-cost-az.coloros.com` and
   `gauss-componentotacostmanual-{eu,sg}.allawnofs.com` [V CustomDroid].
3. **RESTORE-ASSETS.md:50**: `curl -fLO '<official URL>'` will likely
   return **403**. OnePlus has blocked external OTA downloads since
   2024-09-02 [V Oxygen Updater v6.4.0]. Prefer downloading inside
   Oxygen Updater / OS Updater on the phone and pulling the zip with
   `adb pull`, or expect to need a device-like user agent. Allawnofs file
   names are hashes [I], so `<ota>.zip` must be renamed locally.
4. **RESTORE-ASSETS.md:69, 77, 83–84**: "the MD5 published next to the
   download link". OnePlus publishes no MD5 [V for the pages read]. The
   MD5 comes from Oxygen Updater, which displays and verifies it [V release
   notes]. Reword the provenance as: official CDN host + Oxygen Updater MD5
   + `FILE_HASH`.
5. **RESTORE-ASSETS.md:55–56**: `post-build` "byte-identical" is the right
   goal, but add a fallback [I]. If it differs only in a region or product
   segment, compare `ro.build.version.incremental` and the build date
   before declaring a wrong build. Oplus region partitions may rewrite the
   runtime fingerprint.
6. **RESTORE-ASSETS.md:108–110**: the expected partition list should also
   name the Oplus `my_*` logical partitions [I] and the DDR5 variants
   `xbl_lp5`/`xbl_config_lp5` [V LineageOS template]. Without that, a
   correct EU package can look "wrong". Add a warning: never flash
   `xbl*` without checking `ro.boot.ddr_type`.
7. **RESTORE-ASSETS.md:137**: the grep pattern `IN21` matches **OnePlus 8
   (non-Pro)** region codes (`IN21AA/BA/DA`). The 8 Pro EU code is
   **`IN11BA`** [V CustomDroid]. Use `IN11|IN2023|instantnoodlep|EU`. Also
   add a stop: an `IN21xx` package is the wrong phone.
8. **RESTORE-ASSETS.md:141–144**: state that EU MSM packages exist **only
   up to OOS 11.0.4.4 (Android 11)** [V]. They need the
   `MsmDownloadTool V4.0_Win7.exe` variant for OOS 11 firmware [V]. Path 2
   therefore ends on locked OOS 11, not on the current build. Expect the
   `.ops` name to be `instantnoodlep_..._<build>_<date>.ops` [I]. The
   region is proven by the package name (`IN11BA`/`EU`), not by the
   `.ops` name.
9. **RESTORE-ASSETS.md:128–153 (missing step)**: add an optional R5b,
   a read-only `bkerler/edl` backup (`edl printgpt`, then
   `edl rl ... --memory=ufs --skip=userdata`, or at least `persist`,
   `modemst1`, `modemst2`, `fsg`, `ocdt`). The tool supports the 8 Pro's
   OnePlus auth (projid 19811) [V], it works on Linux without a VM [V],
   and these partitions are the only irreplaceable ones [I]. The output is
   private (`captures/` rules).
10. **RESTORE-ASSETS.md:34–36 together with STAGE-0-RUNBOOK.md:120–124**:
    "install the next official OTA" may be impossible. The device is EOL
    and the last EEA build was around April 2024 [V/I]. If the phone
    already runs the final build, the only B→A route is a **local install
    of the same full zip**. This needs "Local install" unlocked via
    Developer options or the OnePlus Local Update APK [V Oxygen Updater
    article 367]. Same-version acceptance is unproven [I]. A/B always
    writes the inactive slot and activates it on success [V AOSP]. This
    also means R2 can (and should) download the full zip *before* the slot
    move. The zip is the input of that move, and the build stays the same.
11. **RESTORE-RUNBOOK.md:31**: add "Never pick SMT Download mode (erases
    IMEI and Widevine)" [V] and the Win7-variant note [V]. Admin rights
    are [I].
12. **RESTORE-RUNBOOK.md:18–20 versus :38** (consistency, [I]): path 1
    flashes `system`, `vendor` and the `my_*` partitions in fastbootd.
    These are logical partitions inside `super`, so path 1 writes into
    `super` (slot-B extents). That contradicts "Never flash anything to
    `super`" unless the rule is reworded to "never flash the `super`
    image/partition directly; logical `_b` partitions via fastbootd are
    allowed".
