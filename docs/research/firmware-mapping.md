<!-- SPDX-License-Identifier: MIT -->
# Research: IN2023 firmware extraction mapping

> **Coordinator review, 2026-11-15.** Worker notes for the research ticket
> "Firmware extraction mapping from the IN2023 factory image (ath11k +
> modem)", landed as written apart from this block. **Three corrections; read
> them before using the table below.**
>
> 1. [V] **The GPU is Adreno 650, not Mali, so the "Panthor GPU" row does not
>    apply.** That row comes from the Pixel (Tensor/Mali) path. SM8250's GPU
>    is Adreno 650/GMU (`dts-gap.md`; upstream `sm8250.dtsi`). [I] msm/adreno
>    requests the generic `qcom/a650_sqe.fw` and `qcom/a650_gmu.bin` from
>    linux-firmware, plus a **device-signed zap shader**, which must come from
>    the owner's own image. Upstream precedent: the OnePlus 6 matrix row says
>    "needs the phone's own zap shader" (upstream `docs/DEVICES.md`). The
>    community DTS disables `&gpu` (lines 607-609), so the zap path is not in
>    that file.
> 2. [V] **The SDX55 modem is external over PCIe/MHI, so the
>    `qcom_q6v5_pas` `modem.mdt` mapping is the wrong model.** The `sdx55`
>    PAS entry is for the SDX55 running as the application SoC. For a
>    PCIe-attached SDX55, mainline `drivers/bus/mhi/host/pci_generic.c:408-411`
>    requests `qcom/sdx55m/sbl1.mbn` (and `qcom/sdx55m/edl.mbn` for EDL).
>    [I] The community DTS enables `&pcie2` (line 718), which fits an MHI
>    modem there. Which further images the modem pulls from the host, and
>    from which stock partition, stays open. The worker's conclusion stands:
>    keep modem provisioning out of `extract-vendor-firmware` until the
>    maintainer decides.
> 3. [V] **Missing rows: the remoteprocs.** The community DTS loads
>    `adsp.mbn`, `cdsp.mbn`, `slpi.mbn` and `venus.mbn` (lines 578, 583, 676,
>    950; under a distro prefix there). They cover audio, compute, sensors
>    and video. [I] They come from the stock modem/vendor firmware images and
>    need mapping lines once the OTA member paths are known (restore-assets
>    ticket, offline extraction).
>
> - [V] QCA6390 over WCN6851 is now strong: the community DTS uses
>   `qcom,qca6390-bt` and the PCI child `pci17cb,1101` (`dts-gap.md`). The
>   ticket's "WCN6851" label was wrong.

Status: 2026-11-15. This is an offline mapping only. No factory image was
opened and no firmware bytes are included.

## Evidence and scope

- [V] Omarchy's contributor rule says proprietary firmware is never committed
  or redistributed; the extraction tool takes it from the user's own factory
  image, and a new device adds mappings rather than files. Source:
  `CONTRIBUTING.md`, section 7, upstream
  <https://raw.githubusercontent.com/derekross/omarchy-mobile/main/CONTRIBUTING.md>.
- [V] Upstream `extract-vendor-firmware` currently maps Google vendor paths
  (`vendor/firmware/fw_bcmdhd.bin`, `BCM.hcd`, Cirrus and AoC files) and its
  default is Pixel/Google-specific. Source: upstream script
  <https://raw.githubusercontent.com/derekross/omarchy-mobile/main/tools/extract-vendor-firmware>.
- [V] The IN2023 unofficial mainline port identifies the phone as Snapdragon
  865 and reports Wi-Fi, Bluetooth, modem, GPU and display working. Source:
  <https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial>.

## Mapping table

The `OTA member` column names the location to inspect after extracting
`vendor.img`, `odm.img`, and any modem/firmware payload partitions from
`payload.bin`. `I` means the exact member must be confirmed against the
owner's particular build before enabling a strict extractor.

| Driver/function | Mainline requested path | IN2023 OTA member | Proposed extractor mapping |
| --- | --- | --- | --- |
| ath11k Wi-Fi (QCA6390/WCN685x family; verify exact silicon) | `ath11k/QCA6390/hw2.0/amss.bin` | [I] `/vendor/firmware/wlan/amss.bin` or the corresponding WLAN firmware directory in the vendor image | `"firmware/wlan/amss.bin|ath11k/QCA6390/hw2.0/amss.bin"` |
| ath11k Wi-Fi board data | `ath11k/QCA6390/hw2.0/board-2.bin` | [I] `/vendor/firmware/wlan/board-2.json` (encode with `ath11k-bdencoder`), or a pre-encoded `board-2.bin` if present | `"firmware/wlan/board-2.bin|ath11k/QCA6390/hw2.0/board-2.bin"` only if already encoded; otherwise extractor needs an explicit conversion step |
| ath11k Wi-Fi M3 | `ath11k/QCA6390/hw2.0/m3.bin` | [I] `/vendor/firmware/wlan/m3.bin` | `"firmware/wlan/m3.bin|ath11k/QCA6390/hw2.0/m3.bin"` |
| QCOM PAS SDX55 modem (MPSS) | `modem.mdt`, with split `modem.b##` members as referenced by the MDT | [I] `/vendor/firmware/modem.mdt` and sibling `modem.b##`, or a modem payload image rather than vendor.img | `"firmware/modem.mdt|qcom/sdx55m/modem.mdt"` plus one mapping per referenced `modem.b##` |
| SDX55 modem runtime files used by the MHI/IPA stack | `qcom/sdx55m/{acdb.mbn,aop.mbn,apdp.mbn,apps.mbn,devcfg.mbn,hyp.mbn,mdmddr.mbn,multi_image*.mbn,qdsp6sw.mbn,sbl1.mbn,sec.elf,tz.mbn,xbl_cfg.elf,modemr.jsn}`; calibration `efs*.bin` is per-device | [I] modem firmware partition/image, not necessarily vendor.img; package evidence lists these exact names under `qcom/sdx55m` | Do not add to `extract-vendor-firmware` until source partition and ownership are settled; likely a separate modem extractor |
| Panthor GPU | `arm/mali/arch10.8/mali_csffw.bin` | [V] not an IN2023 vendor mapping: linux-firmware supplies this generic CSF firmware; Google's vendor `mali_csffw-r54p3.bin` is not a Panthor substitute. Source: upstream Panthor `panthor_fw.c`, <https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/panthor/panthor_fw.c>. | No line. Maintainer should keep this in the normal linux-firmware dependency, not extract proprietary GPU bytes |
| Mainline display / DSI / DRM | none | No firmware requested by the mainline display path; panel initialization is driver data/commands | No line |

### Diff sketch against the current script

The following is intentionally a sketch, not a ready patch. It shows the
new device branch and names only; it does not add blobs:

```diff
 case "$DEVICE_OPT" in
   ...
+  instantnoodlep)
+    # OnePlus IN2023: Qualcomm WLAN plus SDX55 modem. Exact vendor paths
+    # and silicon name must be confirmed from the owner's OTA first.
+    DEVICE="instantnoodlep"
+    MAP=(
+      "firmware/wlan/amss.bin|ath11k/QCA6390/hw2.0/amss.bin"
+      "firmware/wlan/m3.bin|ath11k/QCA6390/hw2.0/m3.bin"
+      "firmware/wlan/board-2.bin|ath11k/QCA6390/hw2.0/board-2.bin"
+      "firmware/modem.mdt|qcom/sdx55m/modem.mdt"
+      # Add modem.b## members only after parsing modem.mdt.
+    )
+    ;;
 esac
```

## Important decisions before implementation

1. [V] The unofficial port's published firmware APK recipe uses
   `ath11k/QCA6390/hw2.0` and source names `amss.bin`, `m3.bin`, and a
   generated `board-2.bin`; this is stronger evidence for QCA6390 than for
   WCN6851. Source snapshot in the search result:
   <https://git.mrlokop.dev/MRLokop/pmaports/commit/372287e23c799ce0d8485dcb8302303533cfe69c.patch>.
2. [I] The ticket's “WCN6851” label may be a hardware identification error.
   Confirm the PCI/QMI chip and board IDs from the owner's stock capture before
   selecting QCA6390 versus WCN6855 naming.
3. [I] `board-2.json` is not itself a runtime ath11k file. The unofficial
   recipe runs `ath11k-bdencoder -c board-2.json`; an extractor must either
   perform that conversion in a temporary workspace or require a pre-encoded
   `board-2.bin` in the OTA.
4. [V] The upstream SDX55 PAS data uses `modem.mdt` as the firmware name;
   the Q6v5 loader can request split `modem.b##` segments. Sources:
   <https://raw.githubusercontent.com/torvalds/linux/master/drivers/remoteproc/qcom_q6v5_pas.c>
   and
   <https://raw.githubusercontent.com/torvalds/linux/master/drivers/remoteproc/qcom_q6v5_mss.c>.
5. [I] Modem files and per-device `efs*.bin` may be in modem/vendor firmware
   partitions rather than `vendor.img`. Do not silently copy identity or
   calibration data. Maintainer must decide whether modem extraction belongs
   in this script or a separate owner-only provisioner.
6. [V] GPU and display need no IN2023 proprietary mapping in this script:
   Panthor requests the generic linux-firmware CSF path, while the display
   drivers request no firmware. Source for Panthor is cited in the table.

## Safe validation runbook (owner runs, no hardware access by this worker)

1. Extract only `payload.bin` images to a private directory; never mount or
   write a phone partition. Record image names and paths, not serials or
   identity data.
2. List names only: `debugfs -R 'ls -p /vendor/firmware/wlan' vendor.img`
   and equivalent modem paths, or use the EROFS extractor without publishing
   output. Expect names matching the table. Stop if the image is not for
   IN2023 or if a path contains identity/calibration data.
3. Parse `modem.mdt` metadata and enumerate its referenced `modem.b##`
   segments before writing mappings. Rollback is deletion of the private
   extraction directory; no phone write is involved.
