---
title: "Modem kernel candidate: root-port PERST, no MBI symbol, patches in git"
author: agent on macbookpro
date: 2026-11-17
branch: inumineq/modem-kernel
id: l-eb7bb96c
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/MODEM-M5-DELTA.md
  - device/instantnoodlep/kernel.config
  - patches/instantnoodlep/kernel-modem
  - tests/modem-sahara
---

## Decided
- [V: dtschema `pci/pci-bus-common.yaml:141-147`; L `qcom,pcie-common.yaml:81-93`] PERST# and WAKE# belong on the PCI root port as `reset-gpios`/`wake-gpios`; the host-node `perst-gpios`/`wake-gpios` are deprecated. The delta's §2 claim is confirmed by the schema, and `dtbs_check` passes with the root-port form.
- [V: L `drivers/irqchip/Makefile:35`] There is no `CONFIG_ARM_GIC_V3_MBI` symbol: `ARM_GIC_V3` builds `irq-gic-v3-mbi.o` directly. The delta's fragment listed it and Kconfig dropped it silently, which is the failed gate §3 warns about.
- [V: L `drivers/net/wwan/Kconfig:9`] `WWAN` is `depends on GNSS || GNSS = n`, so the modem fragment must set `# CONFIG_GNSS is not set` or WWAN stays a module and the transport is not built in.
- [V] The series is exported to `patches/instantnoodlep/kernel-modem/` because the kernel trees on the three hosts share no remote; git in this repo is the only channel between them.
## Tried and ruled out
- [I] Serving the Sahara images from a userspace server: the SBL Sahara channels exist before MHI is up, so there is no MHI device for userspace to talk to. The loader has to be in the kernel.
- [I] Applying the reference debug series wholesale (AP2MDM GPIO hogs, EFS/DDR dump paths): unverified assertion order and private state, so out of the candidate.
## Watch out
- [V] `checkpatch --strict` reports `Missing Signed-off-by` on the series; the DCO sign-off is the owner's to add.
- [I] The Sahara loader is only tested host-side (`tests/modem-sahara`); no DMA or lifecycle test exists and nothing has run on the phone.
