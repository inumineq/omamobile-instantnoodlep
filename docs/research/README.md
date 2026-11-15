<!-- SPDX-License-Identifier: MIT -->
# Research notes

Findings from the map's research tickets, landed 2026-11-15. Each file is
the research worker's note as written, with a dated **coordinator review**
block at the top. The review records corrections from an independent check.
`[V]` marks a claim checked against a cited source; `[I]` marks an
inference that the device (stage 0) still has to confirm.

| File | Ticket | One-line result |
| --- | --- | --- |
| [dts-gap.md](dts-gap.md) | SM8250 DTS gap: community fork vs linux-omarchy-mobile omamobile branch | `omamobile` has the generic SM8250 drivers and nodes. The gap is the whole phone DTS (board IDs, reserved memory, PMIC rails, UFS/USB wiring, panel, QCA6390), plus the `a051db6a` Wi-Fi/BT fix as one change |
| [abl-boot-flow.md](abl-boot-flow.md) | Qualcomm ABL boot flow on instantnoodlep | Boot header **v2** (DTB in boot.img) plus a separate dtbo. Slot flags most likely in GPT attributes. Unlock does not prove AVB is skipped. Earlycon candidate is `uart12` @ `0xa90000` |
| [firmware-mapping.md](firmware-mapping.md) | Firmware extraction mapping from the IN2023 factory image | Wi-Fi is QCA6390 (`ath11k/QCA6390/hw2.0`). The modem is SDX55 over PCIe/MHI. The GPU (Adreno 650) needs the phone's own zap shader. Remoteproc mappings are still to add |
| [laptop-setup.md](laptop-setup.md) | Laptop build setup for a Qualcomm boot-v3 device | The upstream laptop setup carries over. A new `BOOT_METHOD` is needed for header v2 plus dtbo. The draft `device.conf` must drop `vbmeta` |

No file here contains unit identifiers or firmware bytes.
