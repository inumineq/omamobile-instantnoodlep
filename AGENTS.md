<!-- SPDX-License-Identifier: MIT -->
# AGENTS.md: rules for AI coding agents in this workspace

This workspace prepares a port to upstream
[derekross/omarchy-mobile](https://github.com/derekross/omarchy-mobile).
Before contributing upstream, read THEIR `AGENTS.md` and `CONTRIBUTING.md`
first; their rules win over anything written here.

House rules for work in this repository:

1. **Hardware access goes through the owner.** No agent has hands on the
   phone. Every command that touches the device is prepared with: the exact
   command block, the expected output (Expect), a stop condition, and a
   rollback. The owner runs it and pastes the output back.
2. **Evidence discipline.** Every claim is [V] (checked, with a source or
   file:line) or [I] (inference to check on the device). No in-between.
3. **Safety model first.** Never write to `super` or any `_a` partition;
   `UFS_RW` only ever names slot B boot images and `userdata`.
4. **Captures are private.** `captures/` is gitignored on purpose. Serials,
   IMEI and MAC addresses never enter commits, comments or issues. Quote
   the fact, not the file.
5. **Licences.** MIT with SPDX headers here; GPL-2.0 for kernel/DTS work.
   No leaked or decompiled proprietary code; describe protocols instead.
6. **Plans before code.** A subsystem is not touched until its
   `device/instantnoodlep/*-PLAN.md` exists with a gated runbook.
7. **English upstream, work notes may be Danish.** Comments in this repo
   are English so they can be PR'd without rewriting.
8. **No proprietary firmware in git.** Vendor firmware comes from the
   owner's own factory image at install time, per upstream rule.
