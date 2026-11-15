<!-- SPDX-License-Identifier: MIT -->
# Research notes

Findings from the wayfinder map's research tickets, with [V]/[I] marks
kept. Each note opens with a coordinator review that lists corrections
found by reading the notes against each other. Read that review first:
where it disagrees with the body, the review wins.

| Note | Ticket | Headline |
| --- | --- | --- |
| [abl-boot-flow.md](abl-boot-flow.md) | Qualcomm ABL boot flow on instantnoodlep | Boot header v2 with the DTB in `boot.img` and a separate dtbo; slot flags in GPT attributes; unlocking does not prove AVB is off |
| [sm8250-dts-gap.md](sm8250-dts-gap.md) | SM8250 DTS gap: community fork vs omamobile | `omamobile` has the generic SM8250 drivers; what M1 is missing is the board DTS |
| [firmware-extraction.md](firmware-extraction.md) | Firmware extraction mapping from the IN2023 factory image | ath11k QCA6390 mapping; the GPU and modem rows are corrected in the review |
| [laptop-build-setup.md](laptop-build-setup.md) | Laptop build setup for a Qualcomm boot-v3 device | Base checklist holds; the v3 assumption is replaced by v2 |

None of these notes authorises a command on the phone. Device steps live
in `docs/STAGE-0.md` and in the gated runbooks in `device/instantnoodlep/`.
