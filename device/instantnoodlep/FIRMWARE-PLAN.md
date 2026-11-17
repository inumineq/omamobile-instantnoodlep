<!-- SPDX-License-Identifier: MIT -->
# FIRMWARE-PLAN: firmware for instantnoodlep (OnePlus 8 Pro IN2023, SM8250)

House-rule-6 gate for the firmware subsystem: nothing in this subsystem is
touched before this plan exists with a gated runbook. This file is a plan
only. It carries names and paths, never firmware bytes (AGENTS.md rule 8),
and no code beyond short command lines.

- Date: 2026-11-15. Branch: `inumineq/mistral-firmware-plan`.
- Inputs: `docs/research/firmware-extraction.md` (its coordinator review
  wins over the body: Adreno 650, not Panthor; SDX55 over MHI, not the
  q6v5 `modem.mdt` loader), `device/instantnoodlep/BRINGUP-M1-PLAN.md`,
  `device/instantnoodlep/device.conf` (draft), `NOTES.md`,
  `docs/runbooks/RESTORE-ASSETS.md` R4, and upstream
  derekross/omarchy-mobile (pinned below).
- Milestones (wayfinder map, issue #1): **M1a** RAM-only first light,
  **M1b** persistent slot-B install, **M2** Arch root on `userdata`,
  **M3** usable desk phone (touch, GPU/Hyprland, display with brightness
  and 120 Hz), **M4** accepted upstream, **M5** Wi-Fi, mobile data/SMS,
  sensors, cameras.

## 1. Source pins

- `U/` = derekross/omarchy-mobile @ `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`
  (main, 2026-11-15 19:28 UTC). Line numbers below are from that commit.
- `L/` = torvalds/linux master @ `a9daf327f3ff90625204876981f88cfe2b6f6fff`,
  fetched 2026-11-15 22:31 UTC.
- `LF/` = linux-firmware main @ `2b2c1f39d7ae274bfe56d829e62d3993249e3a82`,
  tree listings fetched 2026-11-15 from git.kernel.org.
- `C/` = community DTS, gitlab.nura.eco soc/qualcomm-sm8250/linux tag
  `7.2.0-dev`, `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`
  (976 lines, fetched 2026-11-15).
- `D/` = public Nura/OnePlus 8 Pro repository
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial>;
  its README and firmware/sensors docs and script were checked for source
  paths, never copied as proprietary binaries.

## 2. What the port needs, and when

M1a and M1b need **no firmware files at all**: the probe DTB disables the
remote processors [V: BRINGUP-M1-PLAN.md §5.5], the community DTS disables
`&gpu` [V: C lines 607-609], the first-light display is a bootloader
simple-framebuffer which requests no firmware, and USB gadget networking
needs none. The first firmware need is **M3** (the vendor-signed GPU zap
shader once `&gpu` is enabled); everything else lands at **M5** (Wi-Fi,
BT, modem, audio/sensors/video remoteprocs). Rows sourced from
linux-firmware need no extraction at all: the `linux-firmware` package in
the M2 rootfs carries them.

## 3. Firmware table

One row per file. "OTA member" is the path to inspect inside the image
extracted from the owner's verified OTA `payload.bin` (RESTORE-ASSETS
R1-R4); every member path is [I] until runbook step F2 confirms it.
Target paths are what the drivers request; on Arch `/lib` is a symlink to
`usr/lib`, so these are the same tree as upstream's
`/usr/lib/firmware/updates` convention [V: U/tools/extract-vendor-firmware:108-109,135].

| File | Used by (driver) | Source | Target under /lib/firmware | Vendor-signed | First milestone |
| --- | --- | --- | --- | --- | --- |
| `a650_sqe.fw` | Adreno 650 SQE, `drm/msm` a6xx [V: L/a6xx_catalog.c:1052-1057] | linux-firmware `qcom/a650_sqe.fw` [V: LF/ qcom/ listing] | `/lib/firmware/qcom/a650_sqe.fw` (driver tries `qcom/` prefix first [V: L/adreno_gpu.c:536-554]) | no | M3 |
| `a650_gmu.bin` | Adreno 650 GMU, a6xx [V: L/a6xx_catalog.c:1057] | linux-firmware `qcom/a650_gmu.bin` [V: LF/ qcom/ listing] | `/lib/firmware/qcom/a650_gmu.bin` | no | M3 |
| `a650_zap.mdt` (device zap shader) | a6xx zap, loaded signed when the DT `zap-shader` node sets `firmware-name` [V: L/adreno_gpu.c:82-85,140-141; catalog name `a650_zap.mdt` L/a6xx_catalog.c:1064] | OTA vendor image (vendor.img or odm), member [I], e.g. under `/firmware/image/` | `/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/a650_zap.mbn` — the exact path must match the ported DTS and `firmware.map` [V: firmware.map:19; M3 D patch 0004] | **yes** | M3 |
| `adsp.mbn` | ADSP remoteproc, `qcom_q6v5_pas` (audio) [V: L/q6v5pas.c:1181-1183; default bare `adsp.mdt`, overridden by DT `firmware-name` L/q6v5pas.c:923-925] | linux-firmware `qcom/sm8250/adsp.mbn` [V: LF/ qcom/sm8250/ listing]; OTA vendor copy for a per-device build [I member] | `/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/adsp.mbn` (matches `firmware.map` and the planned DTS `firmware-name`; community DTS uses a different override `postmarketos/adsp.mbn` [V: C line 578]) | yes (PAS-authenticated at load) | M5 |
| `cdsp.mbn` | CDSP remoteproc (audio/DSP) | linux-firmware `qcom/sm8250/cdsp.mbn` [V: LF/ qcom/sm8250/ listing]; OTA vendor copy [I] | `/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/cdsp.mbn` (matches `firmware.map` destination) | yes | M5 |
| `slpi.mbn` | SLPI remoteproc (sensors) [V: L/q6v5pas.c:1515-1517,2060] | **not in linux-firmware** (no slpi file under `qcom/sm8250/` [V: LF/ listing]); the public Nura service reads `modem_<slot>/image/slpi.mdt` and joins its segments with pil-squasher [V: D/firmware/dsp-firmware.sh, `need_fw`]; sensor DSP libraries are a separate `dsp_<slot>/sdsp` source [V: same script, `need_libs`]. The OTA image/member and segment names remain [I], to be checked by names only in modem/dsp images. | `/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn` (matches `firmware.map`) | yes | M5 |
| `venus.mbn` | venus video codec [V: L/venus_core.c:1084-1112, sm8250 default fwname `qcom/vpu-1.0/venus.mbn`; loaded via `qcom_mdt_load` L/venus_fw.c:102,128,228] | OTA (LF ships `qcom/vpu/` and `qcom/venus-*` but no `qcom/vpu-1.0/` [V: LF/ listing]), member [I] | `/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/venus.mbn` (matches `firmware.map`; DTS must override the driver's default firmware name) | yes | M5 |
| `sbl1.mbn` | SDX55 modem boot over MHI, `pci_generic` [V: L/pci_generic.c:409-411] | **not in linux-firmware** (only `qcom/sdx35`, `qcom/sdx61` exist [V: LF/ qcom/ listing]) → OTA `modem` image from payload.bin, member [I] | `/lib/firmware/qcom/sdx55m/sbl1.mbn` | yes | M5 |
| `edl.mbn` | SDX55 emergency-download image, MHI [V: L/pci_generic.c:410-411] | OTA `modem` image, member [I] | `/lib/firmware/qcom/sdx55m/edl.mbn` | yes | M5 |
| rest of `qcom/sdx55m/*` (`acdb`, `aop`, `apps`, `devcfg`, `hyp`, `tz`, `xbl_cfg`, …) | MHI/IPA runtime on the host [I: whether the host loads these beyond sbl1/edl — check what the Nura image packages] | OTA `modem` image, members [I] | `/lib/firmware/qcom/sdx55m/` | yes | M5 |
| `amss.bin` | ath11k PCIe Wi-Fi, QCA6390 hw2.0 [V: L/ath11k/core.c:219-222, dir `QCA6390/hw2.0`; PCI child `pci17cb,1101` V: C lines 681-704] | linux-firmware `ath11k/QCA6390/hw2.0/amss.bin` [V: LF/ listing]; OTA vendor `/firmware/wlan/amss.bin` [I member in vendor.img] | `/lib/firmware/ath11k/QCA6390/hw2.0/amss.bin` | no | M5 |
| `m3.bin` | ath11k QCA6390 | linux-firmware [V: LF/ listing]; OTA `/firmware/wlan/m3.bin` [I] | `/lib/firmware/ath11k/QCA6390/hw2.0/m3.bin` | no | M5 |
| `board-2.bin` | ath11k board data (device calibration/regulatory) | linux-firmware generic copy [V: LF/ listing]; device-specific copy from OTA `/firmware/wlan/board-2.json` encoded with `ath11k-bdencoder`, or a pre-encoded `board-2.bin` if present [I] | `/lib/firmware/ath11k/QCA6390/hw2.0/board-2.bin` | no | M5 |
| `htbtfw20.tlv`, `htnv20.bin` (QCA6390 ROM 0x0200) | BT over UART6, `hci_qca` for `qcom,qca6390-bt` [V: L/hci_qca.c:2788; C lines 955-968] | QCA6390 selects `qca/htbtfw%02x.tlv` and `qca/htnv%02x.bin` from its ROM version [V: L/btqca.c:756-782, 886-889]; the public instantnoodlep fix logs ROM `0x0200` and requests `htbtfw20.tlv`/`htnv20.bin` [V: <https://gitlab.com/sm8250-mainline/linux/-/merge_requests/8>, test log]. The owner's ROM and OTA member paths still require R2/F2. `hp*` is for other QCA SoCs, not QCA6390. | `/lib/firmware/qca/…` | no | M5 |
| touch / panel | none requested: `s6sy761` touch driver has no `request_firmware` [V: L/s6sy761.c, 554 lines checked; node `samsung,s6sy761` C lines 653-668]; the mainline DSI/DRM path requests no firmware [V: docs/research/firmware-extraction.md, display row] | n/a | n/a | n/a | n/a (M3 needs no firmware file) |

Policy row, not a file: per-device calibration and identity data (`efs*`,
modem NV, `modemr.jsn`-class per-unit files) is **never** extracted into
packages or committed [V: docs/research/firmware-extraction.md, review
item 5; AGENTS.md rule 4].

## 4. Where extraction runs, and how upstream expects it wired in

- **Where:** on the owner's laptop, at install time, from the verified
  OTA secured by RESTORE-ASSETS R1-R4 — full zip (Oxygen Updater MD5 plus
  the payload `FILE_HASH`) → `payload.bin` → `payload-dumper-go` →
  `images/*.img` (R4). For a OnePlus the verified full OTA is the
  equivalent of the Pixel factory image that upstream requires "for
  exactly the build on your phone" [V: U/CONTRIBUTING.md:36]; R1-R3 pin
  it to the running build.
- **Upstream rule:** proprietary firmware is never committed, attached or
  redistributed; the scripts take it from the user's own image on the
  user's own machine [V: U/CONTRIBUTING.md:352-353; U/AGENTS.md:29;
  U/docs/RELEASES.md:11], and "a new device adds its own mapping to these
  scripts, not the files" [V: U/CONTRIBUTING.md:356]. Our repo adds the
  same rule at AGENTS.md rule 8; `.gitignore` already covers `*.img`,
  `*.mbn`, `*.elf`, `payload.bin`, `*.zip` and `captures/`.
- **Wiring upstream expects:** a per-device map beside the descriptor —
  `FIRMWARE_MAP` pointing at a `firmware.map` file of
  `source-in-vendor|destination` lines [V: U/docs/RELEASES.md:166] — used
  at install time: the installer "asks for the user's factory zip, checks
  its `board=`, and runs the device's firmware and chroot extraction on
  the laptop" [V: U/docs/RELEASES.md:386], then writes the extracted
  firmware into a local copy of the root image with `debugfs -w`;
  "nothing extracted leaves the laptop except into the user's own phone"
  [V: U/docs/RELEASES.md:387]. `tools/phone-provision` runs the extraction
  on the laptop and pushes the tree over SSH
  [V: U/tools/phone-provision:28-30,435].
- `tools/extract-vendor-firmware` already accepts a raw or sparse
  `vendor.img` as SOURCE [V: U/tools/extract-vendor-firmware:160-161] and
  notes "an OTA's vendor.img (from its payload.bin) works as SOURCE"
  [V: U/tools/extract-vendor-firmware:105-106]. For us SOURCE is the
  `vendor.img`/`modem` image extracted from `payload.bin`. The
  `android-info.txt` `board=` device check is Pixel-specific and needs a
  OnePlus equivalent (compare against the pinned `post-build` fingerprint
  from R1/R2 instead) [I].
- **dodge precedent** (the only non-Pixel device with vendor firmware
  upstream today): OnePlus 13 takes its MPSS firmware from the owner's
  own OxygenOS image under `/lib/firmware/qcom/sm8750/OnePlus/`, "not in
  git", and "`tools/phone-provision` and the Pixel extract scripts only
  know Pixel factory images — do not use them for dodge firmware"
  [V: U/device/dodge/modem/README.md:46-50]; its Wi-Fi firmware is "taken
  from the owner's own image. No firmware is shipped or committed here"
  [V: U/device/dodge/wifi/install:11-16]. So the instantnoodlep port adds
  an `instantnoodlep` case plus `firmware.map` upstream — mappings only.
- **Reaching the phone:** only through the later install plan (M2): baked
  into the root image on `userdata` at install time, or pushed over SSH at
  provision time. Never through a firmware/modem partition write (house
  rule 3; [V: U/device/dodge/device.conf:11] "Never flash
  xbl/abl/vbmeta/modem from an image"). This plan has no phone steps.

## 5. Gated runbook — offline only, owner's laptop

Storage: `R=~/android/reference/instantnoodlep` (RESTORE-ASSETS); scratch
in `$R/firmware-scratch`, outside the repo, deleted at the end. Record
names and hashes only — no serials, IMEI, MAC, and no `efs*`/NV content
(AGENTS.md rule 4). No step touches the phone.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| F0 | Gate: RESTORE-ASSETS R1-R4 resolved; `ota/payload.bin` `FILE_HASH` verified; `images/partition-list.txt` exists | all present | any R-step unpassed: do not open any image for firmware mapping | n/a |
| F1 | Extract the firmware-bearing images: `payload-dumper-go -p vendor,odm,modem,dsp,bluetooth -o images ota/payload.bin` [I: verify exact partition names in the OTA list, especially `dsp` and `bluetooth`], then hash only images that exist | every expected image named in the verified OTA partition list is dumped and hashed | any required image is absent or the partition list differs from the expected manifest; do not substitute a flashed partition or another build | delete the new images |
| F2 | List names only inside each extracted image: vendor `/firmware`, modem/dsp roots plus `/image`, and bluetooth `/image` where those members exist; use read-only filesystem tools selected from each image's filesystem type | names matching the table's [I] candidates (`wlan`, `bt`/`qca`, sdx55m, SLPI and DSP-library members) | any path holding `efs`/NV/identity/per-unit calibration data: do not list or dump it; record and skip | n/a (read-only) |
| F3 | Dump only the mapped candidates, one per table row: `debugfs -R 'dump /firmware/wlan/amss.bin "$R/firmware-scratch/amss.bin"' images/vendor.img` [I: member path] | each mapped file dumps with non-zero size | a member is missing: mark [I] and continue; an identity file appears: stop that row | delete the scratch dir |
| F4 | Checksum: `cd "$R/firmware-scratch" && sha256sum * | tee SHA256SUMS` (private, never committed) | every dumped file hashed | n/a | delete the scratch dir |
| F5 | Compare with linux-firmware: shallow-clone LF at `2b2c1f39…` into `$TMPDIR` (never into this repo); `sha256sum` the same relative paths in the clone; diff against F4 | `a650_sqe.fw`, `a650_gmu.bin`, ath11k `amss.bin`/`m3.bin` match LF [I: expected]; `board-2.bin` differs (device data) [I]; `qcom/sdx55m/*` absent in LF, so all modem files are OTA-only; `qcom/sm8250/adsp.mbn`/`cdsp.mbn` present in LF, compare with the OTA copies | LF cannot be fetched, or a signed file the kernel must authenticate (zap, `*.mbn`) mismatches its expected source | delete the clone |
| F6 | Draft `device/instantnoodlep/firmware.map` (names only, `source-in-image|target` lines per U/docs/RELEASES.md:166), including the SDX55 EDL file if present; then `git check-ignore` on `*.mbn *.img payload.bin *.zip` and grep the map for serial/IMEI/MAC patterns | map lists names only; every blob pattern ignored | any row needs identity data, or a blob pattern is not ignored | delete the draft map |

## 6. Risks

- Wrong `board-2.bin`: linux-firmware's copy is generic; without the
  device's board data, Wi-Fi may probe but with wrong regulatory/calibration
  data [I]. F5 records the difference; the extractor must run
  `ath11k-bdencoder` on the OTA's `board-2.json` or take a pre-encoded
  `board-2.bin` [I].
- The zap shader is the one GPU file that must be vendor-signed and
  device-specific [V: docs/research/firmware-extraction.md, review item 1].
  linux-firmware's `qcom/sm8250/a650_zap.mbn` is a different name and
  unsigned for our purpose; the driver asks `a650_zap.mdt` unless the DT
  overrides [V: L/adreno_gpu.c:82-90, L/a6xx_catalog.c:1064]. If the ported
  DTS forgets `zap-shader/firmware-name`, GPU probe fails at M3.
- Modem files from the wrong build break the modem: take them only from
  the OTA pinned by R1 (the running build), never from a forum package.
- EROFS vs ext4 vendor image changes the list/extract tool [I]; install
  `erofs-utils` alongside `debugfs` [V: U/CONTRIBUTING.md:43 lists both].
- A partial extraction (missing `slpi.mbn` or part of `qcom/sdx55m/*`)
  fails late and silently at M5, not at install. F2/F3 existence checks
  are the mitigation.
- The Pixel `board=` check in `extract-vendor-firmware` does not apply to
  an OnePlus OTA source; using `-f` blindly would skip the provenance
  check [I]. Wire the R1 fingerprint comparison instead.
- Never extract `efs*`/NV/modem identity data even when present in the
  modem image (F2 stop); the modem's per-phone data path is a separate
  modem plan, dodge-style read-only copies, not firmware.

## 7. Open [I] items

1. Exact OTA members per row: wlan dir in vendor.img (`/firmware/wlan/…`),
   zap member, slpi/venus members, `modem` image name and the sdx55m
   member paths inside it.
2. vendor.img / modem image filesystem type (ext4 vs EROFS) → which list
   and dump tool F2/F3 use.
3. Whether the host loads more of `qcom/sdx55m/*` than `sbl1.mbn`/`edl.mbn`
   (compare with what the Nura image packages).
4. `board-2.json` → `board-2.bin` conversion (`ath11k-bdencoder`) vs a
   pre-encoded `board-2.bin` in the image.
5. QCA6390 silicon on the owner's unit (DTS has `pci17cb,1101` [V: C lines
   681-704]; unit silicon [I until stage 0]). Same firmware set either
   way; board data may differ.
6. Which PCIe controller (pcie1/pcie2) carries the SDX55 [V: C lines
   708-726 enable both; which one is I]. Does not change the file set.
7. DT `firmware-name` values in our ported DTS: table paths
   (`qcom/sm8250/…`, `qcom/vpu-1.0/venus.mbn`) vs the community's
   `postmarketos/*` [V: C lines 578,583,676,950]. Decide at DTS port time;
   the extractor targets must match.
8. Whether the OTA's `a650_sqe.fw`/`a650_gmu.bin` differ from LF's, and
   which to prefer if they do (F5).
9. Whether an unsigned zap (`qcom/sm8250/a650_zap.mbn` in LF) would load
   on this production unit [I: expect no; vendor-signed zap is the M3
   path].
10. Owner's QCA6390 ROM version and exact OTA member paths for
    `htbtfw%02x.tlv`/`htnv%02x.bin` [V: L/btqca.c:756-782, 886-889; public
    instantnoodlep test logs ROM 0x0200 and `ht*20` [V: GitLab MR 8]; owner
    value/member paths still require R2/F2]. `hp*` names are not this chip's
    QCA6390 firmware names.
11. OnePlus equivalent of the `android-info.txt board=` provenance check
    for an OTA-sourced extractor (use the R1-pinned `post-build`
    fingerprint).
12. Panel variants other than AMS678UW01 on other IN2023 units [I]; none
    of them request firmware in mainline today [V: §3 last row].
13. Sensor DSP library member names under the `dsp` image's `sdsp/` tree
    [I until F2]; only platform libraries may be considered for install-time
    mapping. Per-unit proximity calibration under `persist` remains excluded
    (AGENTS.md rule 4; see SENSORS-M5-PLAN).
