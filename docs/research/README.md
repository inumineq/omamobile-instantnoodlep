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
| [restore-assets-scouting.md](restore-assets-scouting.md) | Secure restore assets on local disk (full OTA + MSM package for IN2023) | Direct OTA downloads get 403, so the full OTA comes from Oxygen Updater on the phone; EU MSM packages stop at OxygenOS 11; corrections 9 and 12 are replaced in the review |
| [gpt-exception-prep.md](gpt-exception-prep.md) | Slot-B bootable marking on Qualcomm: the named GPT-attribute exception | Prepares (does not resolve) the M1b ticket: upstream rule, precedents, what a mark and `--set-active` write, draft entry text, recording plan, rollback, and nine questions for #808 |
| [vbmeta-avb.md](vbmeta-avb.md) | vbmeta/AVB handling on an unlocked Qualcomm ABL | Prepares ticket #10: generic ABL skips the RAM boot hash, direct hash failures are orange-state boots when unlocked, chained images need a footer; R4 chooses between no footer and a test-key footer without writing vbmeta |
| [a3b-contingency.md](a3b-contingency.md) | Stage-0 A3b decision (slot move B→A on the owner's IN2023) | If the same-version local install is refused, only MSM plus an even number of OTA installs reliably lands stock on slot A; downgrade zips are refused and rollback packages wipe |

None of these notes authorises a command on the phone. Device steps live
in `docs/STAGE-0.md` and in the gated runbooks in `device/instantnoodlep/`.
