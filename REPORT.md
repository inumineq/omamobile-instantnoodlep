<!-- SPDX-License-Identifier: MIT -->
# REPORT: USB Type-C + DisplayPort alt mode on slim K3 (branch `instantnoodlep-k3-slim-typec`)

Date: 2026-11-18. English per task. Kernel work GPL-2.0; repo docs MIT.
No phone was accessed; nothing was flashed (AGENTS.md rule 1).

## What was done

1. **Port** onto slim K3 (`78f38a2acc99`, new worktree `~/src/l-k3-typec`,
   branch `instantnoodlep-k3-slim-typec`, pushed to
   `inumineq/linux-omarchy-mobile`), 5 commits:
   - `fdfc068f9` PM8150B Type-C port + PD PHY + `usb-c-connector`
     (dual role, stock sink PDOs 5 V/3 A, 9 V/3 A, 12 V/2.25 A, 5 V/3 A
     dual-role source), FSA4480 `typec-mux@42` on `i2c15` with SBU graph,
     `pm8150b_vbus` enabled (VBUS sourcing only).
   - `5b56c4ba4` dwc3 `dr_mode = "otg"` + `usb-role-switch` +
     **`role-switch-default-mode = "peripheral"`** (default role stays
     device/gadget; laptop attach still yields device via Type-C),
     HS endpoint to connector, QMP combo PHY `mode-switch` + SS endpoint.
   - `0e37c9004` port of Nura **0095** (authorship/Signed-off-by kept):
     `mdss_dp` on, 4 DP lanes to `usb_1_qmpphy_dp_in`, DP altmode
     `svid 0xff01 / vdo 0x1c46` on the connector.
   - `3f2e6c56f` port of Nura **0138** (kept): `link-frequencies` up to
     HBR3 (8.1 Gbps/lane) on `mdss_dp_out`.
   - `8930ae7af` port of Nura **0088** (kept): fsa4480 keeps USB2 routed
     in 4-lane DP so a dock hub works.
   - Nura **0060** was ported as part of commit 1 (FSA4480 node + SBU
     endpoint only; the WCD938x codec port and `accessory-mode-audio`
     were dropped — audio is another subsystem). Reviewed and **not**
     ported: charger/boost patches (0068, 0073, 0082-0087, 0096, 0099,
     0165-0167 — P2b owner gate; **no charge limit is touched**, no
     charger driver is bound), audio patches, and the 0089-0094/0097/0098
     race fixes (written against Nura's older base; this 7.3.0-rc6 tree
     already carries the upstream typec/qmp rework). Full table in
     `device/instantnoodlep/TYPEC-DP-PLAN.md` §2.
2. **Config** (`device/instantnoodlep/kernel-slim-typec.config`, merged
   on `~/android/build/k3-slim/.config`): `TYPEC_TCPM`, `TYPEC_QCOM_PMIC`,
   `TYPEC_MUX_FSA4480`, `TYPEC_DP_ALTMODE` built **in** (=y) so the gadget
   role is known at boot before any module loads; `LOCALVERSION
   -instantnoodlep-k3-slim-typec`.
3. **Tool**: `tools/build-instantnoodlep-probe --typec` keeps the real
   Type-C graph in the probe DTB (default behavior unchanged) and verifies
   it; host test extended, all pass (0 skipped).
4. **Plan + gated runbook**: `device/instantnoodlep/TYPEC-DP-PLAN.md`
   (rule 6) with T1 (RAM boot keeps USB networking to the laptop),
   T2 (typec sysfs partner/role), T3 (owner: USB keyboard via OTG
   adapter, host role), T4 (owner: USB-C monitor/dock, DP), each with
   Expect/Stop/Rollback; rollback = Power+VolUp 10-30 s → daily K3 on
   `boot_b`. No flashing anywhere.

## Build (omabook, clang/LLD 23.1.3, `nice -n 5`, `-j8`, `LLVM=1`, `O=~/android/build/k3-slim-typec`)

- `make ... Image.gz dtbs modules` → **rc=0, 0 errors**; checkpatch on the
  series: 0 errors 0 warnings; `dtbs_check` on
  `sm8250-oneplus-instantnoodlep.dtb`: **clean** (two schema adaptations
  vs Nura's older base: no `mode-switch` on dwc3, `data-lanes` on
  `mdss_dp_out` not on the connector endpoint — RB5 shape).
- **image_size = 0x1730000** (slim was 0x1720000; ceiling 0x2b60000,
  target ≤ 0x2560000) — passes with ~14 MB margin. Image file 23,638,528 B,
  Image.gz 9,233,622 B. Release
  `7.3.0-rc6-instantnoodlep-k3-slim-typec-g8930ae7af4b6`.
- Modules tarball:
  `~/android/build/k3-slim-typec/modules-7.3.0-rc6-instantnoodlep-k3-slim-typec-g8930ae7af4b6.tar.zst`
  (187 MB; typec/tcpm/fsa4480 are built-in, listed in `modules.builtin`).
- **RAM image** (boot-daily manifest flags + `--typec`):
  `~/android/build/k3-slim-typec-ram/boot-typec.img` (17,252,352 B),
  `sha256sum -c boot-typec.SHA256SUMS` OK, builder read-back OK, stock
  overlay apply checked (156 labels). Probe DTB verified to carry
  `dr_mode otg`, `usb-role-switch`, `role-switch-default-mode peripheral`,
  `typec@1500` okay + `usb-c-connector`, `mdss_dp` okay with
  `data-lanes <0 1 2 3>` + HBR3 `link-frequencies`, `typec-mux@42`.

## Not done / gates still closed

- No RAM boot was run (no phone access in this session): T1-T4 in
  TYPEC-DP-PLAN §6 are prepared, owner/coordinator-gated, RAM-only.
- Charger stays out: no charger driver, no charge-limit change, no
  external-boost VBUS path (0096/0099 not ported). PD sink PDOs are
  stock advertisements only.
- `trail-lite lint`: ok (28 files).

## Artifacts

| Artifact | Path |
| --- | --- |
| Kernel branch (pushed) | `inumineq/linux-omarchy-mobile` `instantnoodlep-k3-slim-typec` @ `8930ae7af` |
| Build dir | `~/android/build/k3-slim-typec` |
| RAM image + manifest + sums | `~/android/build/k3-slim-typec-ram/boot-typec.*` |
| Modules tarball | `~/android/build/k3-slim-typec/modules-7.3.0-rc6-...-g8930ae7af4b6.tar.zst` |
| Plan/runbook | `device/instantnoodlep/TYPEC-DP-PLAN.md` |
| Config fragment | `device/instantnoodlep/kernel-slim-typec.config` |
| Nura reference clone | `~/src/nura-ref/nura` @ `498f7698` |
