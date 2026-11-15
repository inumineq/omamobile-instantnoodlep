<!-- SPDX-License-Identifier: MIT -->
# Research: firmware extraction mapping from the IN2023 factory image

- Ticket: "Firmware extraction mapping from the IN2023 factory image
  (ath11k + modem)" (closed, research).
- Origin: research worker note, 2026-11-15, landed unchanged below the
  review; worker commit `07ef581` on the local `research-firmware-2` branch.
- Names and paths only. No firmware bytes in this repository, ever
  (AGENTS.md rule 8).

## Coordinator review (2026-11-15): two rows are wrong

1. **GPU row is wrong for this SoC.** It describes Panthor/Mali, which is
   the Pixel (Tensor) GPU. SM8250 has an **Adreno 650**, driven by
   `drm/msm`. That catalog entry (chip id `0x06050002`) requests
   `a650_sqe.fw` and `a650_gmu.bin`, both from linux-firmware `qcom/`, and
   the zap shader `a650_zap.mdt` [V `drivers/gpu/drm/msm/adreno/a6xx_catalog.c`,
   torvalds/linux master fetched 2026-11-15, lines 1052-1064]. [I] The zap
   shader is vendor-signed and specific to the device, so unlike the
   other two it *is* an extraction candidate; boards usually point
   `zap-shader/firmware-name` at a vendor path. M1 does not need it: the
   community DTS disables `&gpu`.
2. **Modem row is probably the wrong loader.** On SM8250 phones the SDX55
   is an external modem on PCIe. Mainline drives it with MHI
   `pci_generic`, which requests `qcom/sdx55m/sbl1.mbn` and
   `qcom/sdx55m/edl.mbn` [V `drivers/bus/mhi/host/pci_generic.c:408-411`,
   master fetched 2026-11-15]. The `qcom_q6v5_pas` `modem.mdt` path in the
   table is for Linux running *on* the SDX55. [I] Not applicable here
   until shown otherwise. Whether the rest of the `qcom/sdx55m/*` set is
   loaded from the host is [I]: check what the Nura image packages.
   [V] Supporting this, the community DTS enables `&pcie1` and `&pcie2`
   with PHY supplies but no child node (lines 708-726), while `&pcie0`
   carries the Wi-Fi child (681-704). That fits an external SDX55 on
   pcie1 or pcie2; which one is [I].
3. [V] The QCA6390 identification is stronger than the note says: the
   community DTS uses `qca6390-pmu`, `qcom,qca6390-bt` and the PCI child
   `pci17cb,1101` (see `sm8250-dts-gap.md`). The "WCN6851" in the ticket
   text was wrong. The owner's unit silicon is still [I] until stage 0.
4. [I] Gap: the community DTS enables ADSP, CDSP, SLPI and Venus with
   firmware names (community DTS: ADSP 577-580, CDSP 582-585, SLPI 675-678,
   Venus 949-952, see `sm8250-dts-gap.md`). None of these are mapped here. They are needed for audio, sensors and video (M5), not
   for M1.
5. Policy, unchanged: per-device calibration and identity data (`efs*`,
   modem NV) is never extracted into packages.

---


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

## Safe validation runbook (owner runs; laptop only, no phone access)

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
