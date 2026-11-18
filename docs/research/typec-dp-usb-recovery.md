<!-- SPDX-License-Identifier: MIT -->
# Type-C DisplayPort and USB recovery on instantnoodlep

Date: 2026-11-18. Base: `instantnoodlep-k3-slim-all` at
`c30e3f696707`. Kernel version: Linux 7.3-rc6. The slim-all config is
`~/android/configs/slim-all.config`, SHA-256
`8a7b72e0de22f85d9ea18b4f6d0899c26b2e73ae8414feb8d92deb93290b8e6c`.
`K/` refers to `inumineq/linux-omarchy-mobile` at that base commit.
`K/board` is `arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts`.
`K/qmp` is `drivers/phy/qualcomm/phy-qcom-qmp-combo.c`.
`K/fsa` is `drivers/usb/typec/mux/fsa4480.c`.
`K/dwc3-legacy` is `drivers/usb/dwc3/dwc3-qcom-legacy.c`.
`K/drd` is `drivers/usb/dwc3/drd.c`.

## Findings

- [V: owner report, 2026-11-18] The Dell U3219Q enters DisplayPort Alt
  Mode and shows a picture. Its USB2 hub does not enumerate reliably;
  xHCI reports `connect-debounce failed`. After the monitor is removed,
  the USB gadget does not return on a laptop cable. Logs include a QMP
  PHY timeout and DWC3 `ep0out` errors. A plain laptop-cable replug works
  before DP.
- [V: `K/board:645-649, 774-805`] The board
  enables the DP controller, describes four DP lanes, advertises DP Alt
  Mode VDO `0x00001c46`, and connects the PM8150B high-speed port to
  DWC3, the SuperSpeed port to QMP, and SBU to FSA4480.
- [V: `K/board:951-978`] DWC3 is `otg`, has a
  USB role switch, and defaults to `peripheral`. QMP has `mode-switch`.
  The default role is already set for gadget-first boot. Repeating that
  DTS setting is not a candidate fix.
- [V: `ed709a578aa7..c30e3f696707`, scoped to QMP, DWC3, Type-C
  and the board DTS] The two port branches have the same drivers in these
  paths. The relevant board change in slim-all adds
  `op-sink-microwatt = <10000000>`; the role switch and DP lane wiring
  were already in slim-typec.
- [V: `K/qmp:4776-4800`] QMP ignores orientation `none` and
  reinitializes the common block and the active paths on a changed
  physical orientation. [I] A same-orientation replug removes the
  orientation reinitialization as a variable in the recovery test.
- [V: `K/qmp:4810-4848`] QMP selects `DP_ONLY` for DP
  pin assignments C/E, `USB3DP` for D/F, and `USB3_ONLY` without a DP
  SVID. If DP is still powered, a mode change returns early. The driver
  does not save the requested mode for later.
- [V: `K/qmp:4201-4214`] DP power-off only powers down
  the DP PHY and clears `dp_powered_on`. It does not retry a mode change
  that returned early. [V: `K/drivers/usb/typec/tcpm/tcpm.c:5147-5205`,
  `K/drivers/usb/typec/class.c:2499-2506`] TCPM detach unregisters the
  partner altmodes and requests SAFE with role and orientation set to
  none. The connector mode notification carries no altmode pointer,
  which QMP maps to USB-only.
  [I] If that notification reaches the mux before DP power-off, QMP
  can retain the previous mode during role restoration.
- [V: `K/qmp:4044-4049, 4074-4099`] The combo-PHY
  common init keeps the pipe clock enabled in DP-only mode for USB2.
  It leaves the USB3 PCS in reset in `DP_ONLY`. This behavior is already
  in the base via mainline commit `f546912bcac6`, tested upstream with a
  BenQ monitor in four-lane DP with USB2 and two-lane DP with USB3.
  [Mainline patch and test description](https://github.com/torvalds/linux/commit/f546912bcac6)
  [Original submission](https://lore.kernel.org/all/20260304190827.176988-1-val@packett.cool/)
- [V: `K/fsa:88-105`] The current driver enables the FSA4480 USB
  path in DP states C, D, E, and F. The USB2 routing fix is already in
  slim-all. [I] A failed mux update or a hardware routing issue still
  needs a phone check.
  [Nura patch 0088](https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/kernel-patches/0088-usb-typec-fsa4480-retain-USB2-routing-in-four-lane-D.patch)
- [V: `K/dwc3-legacy:787-795`] `qcom,select-utmi-as-pipe-clk`
  is read once during glue probe. It switches the controller to UTMI
  for its pipe clock. The driver comment limits this to systems without
  a SuperSpeed PHY.
- [V: `K/arch/arm64/boot/dts/qcom/sm8250-samsung-common.dtsi:166-179`] Mainline uses that property
  on a Samsung SM8250 port that is explicitly limited to high-speed
  USB and has its USB3 PHY removed. The property applies for the
  lifetime of the controller probe.
- [V: `K/drd:450-473, 504-529`] DWC3's role-switch callback calls
  `dwc3_pre_set_role()` before `dwc3_set_mode()`. Registration first
  applies the configured default role. The instantnoodlep DTS already
  requests peripheral mode before registration. [V: `K/drivers/usb/typec/tcpm/tcpm.c:1224-1234`,
  `K/drivers/usb/dwc3/core.c:290-301`] TCPM sets orientation, requests
  the USB role, then sets the connector mode. DWC3 queues role work
  asynchronously. The callback order alone does not serialize the
  worker against QMP lane-mode reconfiguration.
- [V: `arch/arm64/boot/dts/qcom/sm8350-hdk.dts:485-491`] Mainline describes two lanes on an
  SM8350 DP output. [V: `sc8280xp-microsoft-blackrock.dts:591-610`]
  Mainline uses two-lane DP on two ports and four-lane DP on another.
  These endpoint properties describe board lane wiring. They do not
  replace the DisplayPort Alt Mode pin-assignment negotiation. [V: `K/drivers/usb/typec/altmodes/displayport.c:112-157`]
  The DP Alt Mode driver intersects supported pin assignments and uses
  the partner's multifunction preference to select a shared USB/DP assignment
  when available. The MSM DP driver separately caps link lanes from the
  endpoint property (`K/drivers/gpu/drm/msm/dp/dp_panel.c:192-194`).
- [V: mainline `sm8550.dtsi:4482-4545,4595-4633`] SM8550 has separate
  USB2 and QMP USB3 PHY references for DWC3. Its QMP node declares
  `mode-switch` and a separate DP input. This is a comparable graph
  with a different USB2 PHY. [Linux SM8550 DTS](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/arch/arm64/boot/dts/qcom/sm8550.dtsi)
- [V: owner-provided U3219Q specification and mainline USB2/DP test,
  `f546912bcac6`] The monitor's USB-C prioritization controls the DP
  and USB bandwidth split. Four-lane DP occupies the SuperSpeed pairs,
  while USB2 still uses D+/D-. [I] Compare the U3219Q's High Resolution
  and High Data Speed settings and verify the negotiated assignment in
  each run. The official user guide returned HTTP 403 on this host.
  [Dell U3219Q documentation](https://www.dell.com/support/product-details/en-us/product/dell-u3219q-monitor/docs)

## Mainline changes after the base

[V] Mainline and the `next-20261118` QMP source retain the same DP-powered
early return and clear-only DP shutdown on this path. Direct lore
requests returned HTTP 403. The original mailing-list messages were
available through a public mirror. [Linux-next QMP source](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/phy/qualcomm/phy-qcom-qmp-combo.c?h=next-20261118)

- [V: Linux commit
  <https://github.com/torvalds/linux/commit/89563a152973900e63a7ee0e4885292a7127b3e6>]
  adds preliminary USB4 support and refactors the common mode switch.
  That refactor keeps the USB init reference in DP-only mode and gates
  USB3 power-on on the new mode. It still drops a request while DP is
  powered and leaves the USB init timeout path in DP-only mode.
- [V: Linux commit
  <https://github.com/torvalds/linux/commit/63cfcae23b2b4ca43994d507f5f04cba0306dd5a>]
  moves QMP register bit helpers to a common header. It does not change
  the mode-switch sequence.
- [V: Linux commit
  <https://github.com/torvalds/linux/commit/bb0417288ea40a5f57676529cae95f3c20bd697c>]
  adds USB3 plus DP support for the Nord PHY. It adds new PHY data, not
  an SM8250 reinitialization fix.
- [V: Linux commit
  <https://github.com/torvalds/linux/commit/4dd10fbbeb9c33709edc89916e19c03c780a0751>]
  converts `devm_kmalloc()` callers. It does not affect Type-C behavior.
- [V: `master` QMP source,
  <https://github.com/torvalds/linux/blob/master/drivers/phy/qualcomm/phy-qcom-qmp-combo.c#L5103-L5175>]
  still returns early when DP is powered. It still does not queue the
  requested mode for `dp_power_off()`. Mainline has factored reinit into
  a helper, but the deferred-switch gap remains.
- [V: `master` DWC3 sources,
  <https://github.com/torvalds/linux/blob/master/drivers/usb/dwc3/drd.c#L450-L529>]
  retain the role ordering described above. I found no post-v7.3-rc6
  DWC3 role-switch change that resolves this phone's detach failure.
- [V: Linux commit `89aaaa26f698`] The post-base mainline FSA4480
  change keeps USB2 enabled in pin assignments C/E. Slim-all already
  carries that behavior through Nura 0088, so the mainline commit adds
  no missing routing behavior here.
  [Mainline FSA4480 fix](https://github.com/torvalds/linux/commit/89aaaa26f6985d55676fc5c90440f279733fa132)
- [V: linux-usb, 2026-11-12] Joonhoe Kim's v3 UTMI series moves the
  DWC3 glue to UTMI during DP-only operation, then restores PIPE on
  return to USB mode. The Kaanapali tests in the cover letter include
  four-lane DP with a working USB2 hub and SuperSpeed after detach.
  The proposal changes the current `dwc3-qcom.c`, while SM8250 on this
  board uses `dwc3-qcom-legacy.c`. Linux-next still selects UTMI only
  at probe in both drivers.
  [UTMI v3 cover letter](https://lore-kernel.gnuweeb.org/linux-usb/20261112113838.506-1-26rote@gmail.com/)
  [Linux-next DWC3 source](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/tree/drivers/usb/dwc3/dwc3-qcom.c?h=next-20261118)
- [V: linux-phy, 2026-11-03, `K/qmp:4293-4333`] The related QMP
  v3 patch skips USB PCS programming in DP-only mode. The base still
  attempts USB PCS init when DWC3 calls `phy_init()` in that mode.
  The proposal was tested against a Kaanapali suspend/resume timeout,
  and its DP-only guards are absent in the current linux-next source.
  The author calls out that adapting it to this base requires different
  USB init-count handling because the USB4 refactor is absent.
  [USB PCS v3 patch](https://lore-kernel.gnuweeb.org/all/20261103135051.1668-1-26rote@gmail.com/)
- [V: Nura patch 0090,
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/kernel-patches/0090-phy-qcom-qmp-combo-let-the-USB-controller-guard-reco.patch>]
  reports a different but closely related failure: QMP can reset while
  the DWC3 role worker resets the controller or while SUSPHY is set.
  It adds callbacks to let the controller guard QMP reconfiguration.
  That patch is not in v7.3-rc6 or current mainline.
- [V: Nura patch 0092,
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/kernel-patches/0092-usb-dwc3-qcom-legacy-retain-the-USB2-clock-during-fo.patch>]
  reports loss of the host microframe clock in four-lane DP and selects
  UTMI during DP-only operation. It depends on the QMP/DWC3 reconfigure
  guard from patch 0090. It is not in mainline.
- [V: postmarketOS package
  <https://gitlab.com/postmarketOS/pmaports/-/tree/master/device/testing/linux-postmarketos-qcom-sm8250>]
  pins the SM8250 v6.11 fork. Its OnePlus 8 Pro DTS already selects
  UTMI statically for USB1, sets DWC3 to high-speed peripheral and
  provides only the USB2 PHY there. It has no DP Alt Mode graph on
  this port. That is direct board precedent for the clock source
  in USB2 peripheral mode.
  [postmarketOS OnePlus 8 Pro DTS, lines 785–797](https://gitlab.com/sm8250-mainline/linux/-/blob/sm8250-6.11.0/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dts#L785)
- [V: Nura DP notes,
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/displayport.md>]
  report USB2 hub use with four-lane DP on the same phone family. This
  supports preserving USB2 while DP takes all SuperSpeed lanes; it does
  not prove the U3219Q path.

## Ranked hypotheses and candidates

1. **[I, strongest for gadget recovery] QMP drops a requested USB mode
   transition while DP is powered.** Candidate 1 stores the requested
   QMP mode and applies it when DP powers off. The test must still check
   the DWC3/QMP race described by Nura patch 0090. If candidate 1 still
   logs `phy initialization timed-out`, the next change should serialize
   reconfiguration with the controller or address QMP clock
   ownership, depending on when the timeout occurs.
   [V: `K/qmp:4044-4049, 4130, 4259-4271`] Common init enables
   the pipe clock, but both the USB PCS timeout path and common exit disable
   it. [I] An entry timeout can therefore contribute to the reported
   `gcc_usb3_prim_phy_pipe_clk already disabled` warning and leave the
   USB2 clock path broken even with the deferred transition fixed.
2. **[I, strongest for the dock's USB2 host port] DWC3 loses or fails to
   select its UTMI pipe clock in four-lane DP.** Candidate 2 adds the
   existing `qcom,select-utmi-as-pipe-clk` property. The experiment
   applies UTMI statically and leaves the board's SuperSpeed lane graph
   intact. Nura 0092 selects UTMI dynamically during DP-only operation.
   [I] SuperSpeed may regress outside DP, so measure the laptop link speed
   before and after each candidate.
3. **[I, lower] The FSA4480 did not apply the expected USB2 route on the
   U3219Q.** The driver already enables USB in all four DP states, so
   capture the DP state and switch register before changing the driver.
4. **[I, low] Two-lane DP will fix the hub.** Two-lane DP can free the
   SuperSpeed pairs, but USB2 should remain available in four-lane mode.
   Do not use `data-lanes = <0 1>` as a substitute for Type-C pin
   assignment negotiation. Candidate 2 tests the USB2 clock instead.

## Candidate branches and artifacts

Both branches start at `c30e3f696707` and contain one commit.

| Candidate | Change | Hypothesis | Build output |
| --- | --- | --- | --- |
| `instantnoodlep-k3-typec-fix1` | Queue a QMP mode request made while DP is powered; apply it after DP power-off. Commit `d3b1dfc5c376`. | A discarded DP-exit mode request leaves QMP in a stale state and the gadget does not return. | `~/android/build/k3-typec-fix1/` |
| `instantnoodlep-k3-typec-fix2` | Add `qcom,select-utmi-as-pipe-clk` to the SM8250 USB wrapper. Commit `255b48e80`. | DWC3's USB2 root port needs UTMI as the pipe clock while the combo PHY is in DP-only mode. | `~/android/build/k3-typec-fix2/` |

[V: build and packaging logs on macbookpro] Both candidates built with
`make ARCH=arm64 LLVM=-23` for `Image.gz dtbs modules`. The LLVM suffix
selects the Debian LLVM 23 binaries explicitly inside the build container.
`CONFIG_LOCALVERSION_AUTO=n` and an empty make environment `LOCALVERSION`
produce the exact release strings. The build configs differ from each other
only in `CONFIG_LOCALVERSION`. Relative to slim-all, the other differences
are toolchain probes and disabling automatic SCM versioning.

```text
$ clang --version
Debian clang version 23.1.6 (++20261116014037+5b10d2d74929-1~exp1~20261116134151.96)
Target: aarch64-unknown-linux-gnu
Thread model: posix
InstalledDir: /usr/lib/llvm-23/bin
$ ld.lld --version
Debian LLD 23.1.6 (compatible with GNU linkers)
```

[V: decompressed arm64 image headers, DTB decompilation and package checks]
Both images report header `image_size=0x1780000`, below the
`0x2b60000` ceiling. The DTBs differ only by the boolean
`qcom,select-utmi-as-pipe-clk` on fix2's USB wrapper. Each archive
contains 1,109 modules stripped by `modules_install INSTALL_MOD_STRIP=1`.
All artifact checksums and module vermagic strings match.

### Fix1

[V] macbookpro directory `/Users/inumineq/android/build/k3-typec-fix1`.
Release `7.3.0-rc6-instantnoodlep-k3-typec-fix1`.
`SHA256SUMS` in that directory contains the following entries.

```text
eb7f0e81c2d3c3db326b65fe3be5d3ed89d3eef9b4870e9c3edff89111154198  Image.gz
daffe04b12104c0ebb90cae837735ec1e0f35ced5c51ee9ed2a05eafbe2c7f7f  sm8250-oneplus-instantnoodlep.dtb
53d36efcfae63798ae1b2968a7dafd0a05c82e37c09a8f876d70fd7f45fe7335  modules-7.3.0-rc6-instantnoodlep-k3-typec-fix1.tar.zst
6e4eb8723b36f0158f2196aab35a781b9e84c6ff68ce15876d4b71537508f790  kernel.release
c75e871fc475fa21fe32184a6b5ef3a0b9edc7595ef573de7d967918d71ed5d2  image_size.txt
```

### Fix2

[V] macbookpro directory `/Users/inumineq/android/build/k3-typec-fix2`.
Release `7.3.0-rc6-instantnoodlep-k3-typec-fix2`.
`SHA256SUMS` in that directory contains the following entries.

```text
05f3e0128893c5b80bf44eeb097030541e560be90e4d0100d59e03c87a83d7b0  Image.gz
d93b8339f2cd4fb85f83290b95857458f18e4eb56c723e2120186df10d475645  sm8250-oneplus-instantnoodlep.dtb
570e1307ac347f4715f1c6b3dba9172e0d1b42e89127679049eb60da771029ae  modules-7.3.0-rc6-instantnoodlep-k3-typec-fix2.tar.zst
0148b943d221c7167b05e2b4a61111480bf4f3908154876dab03b2c24b60296e  kernel.release
c75e871fc475fa21fe32184a6b5ef3a0b9edc7595ef573de7d967918d71ed5d2  image_size.txt
```

## Test gates

Use the T6 and T7 RAM-boot steps in
[`device/instantnoodlep/TYPEC-DP-PLAN.md`](../../device/instantnoodlep/TYPEC-DP-PLAN.md).
The owner connects the U3219Q and laptop. Do not flash a partition.
