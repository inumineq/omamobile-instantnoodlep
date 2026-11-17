<!-- SPDX-License-Identifier: MIT -->
# Modem kernel series (MODEM-M5-DELTA)

The kernel side of `device/instantnoodlep/MODEM-M5-DELTA.md`: the flashless
SDX55 endpoint binding, the bounded Sahara loader, the board DTS and the
PCIe `msi-parent` schema allowance. GPL-2.0-only, as kernel code must be;
the patches carry their own commit messages and credits.

Base: `aa996bae0` (`instantnoodlep-k3-combo`, release
`7.3.0-rc6-instantnoodlep-k3-gaa996bae0695`). Apply in order:

```sh
git checkout -b instantnoodlep-k3-modem aa996bae0
git am patches/instantnoodlep/kernel-modem/000*.patch
```

The series is also a branch in the owner's kernel tree
(`instantnoodlep-k3-modem`); these files are the transferable copy, because
the kernel trees on the three hosts share no remote.

## What it does and does not do

- [V] Enables `pcie2`/`pcie2_phy` on the existing PM8150 L5A/L9A rails,
  routes MSI to the GICv3 MBI range and describes `pci17cb,306` with
  `qcom,flashless`.
- [V] Serves only the non-private `qcom/sdx55m/` images over the SBL Sahara
  channels, with bounded commands, image size, served bytes and TX batch
  waits.
- [I] It does **not** make the modem boot. EFS/NV, per-unit DDR training
  state and the runtime sync lifecycle are refused by design and remain
  blocked on an approved private-state policy (delta §1, §5).
- [I] No image here is flashed. The candidate is a RAM-boot experiment for
  the coordinator, gated by delta §6 A-C.

## Known review points before upstream

- [V] `checkpatch --strict` reports `Missing Signed-off-by`. The DCO
  sign-off is the owner's to add; the commits carry `Assisted-by:` only.
- [V] `checkpatch --strict` warns "DT binding docs and includes should be a
  separate patch" twice. The bindings are separate patches already; the
  warning fires on the DTS patch that consumes them.
- [I] The Sahara loader has no DMA/lifecycle test, only the host-side
  parser test in `tests/modem-sahara/`.
