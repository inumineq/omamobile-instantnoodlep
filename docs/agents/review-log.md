<!-- SPDX-License-Identifier: MIT -->
# review-log: quiet continuous code review, five areas + open PRs

Worker: review-log (obsidian), 2026-11-17/18. Read-only against the phone; kernel
reads only in `~/src/l-k3` (combo aa996bae0) via `git show`/`grep`; no builds; no
upstream posts. Findings are [V] (file:line or executed check) or [I]. Fixes went
to `review/privacy` (this PR); defects are issues #88-#91 (label `review`);
per-PR findings were commented on PRs #69 #76 #77 #79 #81 #82 #83 #84.

## Area 1 — kernel patches vs combo aa996bae0 (camera, modem/Sahara)

- All 7 patches + the firmware.map patch apply cleanly to aa996bae0
  [V: `patch --dry-run` against `git show HEAD:<file>` copies in a scratch dir].
- Camera 0002 context matches the base driver exactly [V: imx471.c:119-120 `vana`,
  293-297, 523-547, 766-780, 836, 935-949]; `IMX471_EXT_CLK=19200000` [V: :64],
  single link freq 200 MHz [V: :63,261-263]; MAINTAINERS hunk context [V: :25613-17].
- Camera 0003: PM8009 L3F 1.056 V and L7F 1.8 V are exactly on the PM8009 VRM grids
  [V: qcom-rpmh-regulator.c:913-917 nldo 320000+92*8000=1056000; :910-917 pldo_lv
  1504000+37*8000=1800000]; camss port@3/csiphy3, cci1_i2c1, cam_mclk3 (gpio97),
  CAM_CC_MCLK3_CLK=79, orientation/rotation parsed by v4l2-fwnode.c:832,849 [V];
  gpio24/78 outside reserved ranges <28 4>,<40 4> [V board dts].
- Modem series: root-port reset-gpios supported by pcie-qcom
  [V: pcie-qcom.c:1957-2030 recurses children, GPIOD_OUT_HIGH]; host perst/wake
  deprecated per schema [V: qcom,pcie-common.yaml:81-93]; msi-parent honoured by
  dwc [V: pcie-designware-host.c:592]; gic-v3 mbi-ranges<->msi-controller
  dependency satisfied (both added) [V: arm,gic-v3.yaml:115-135,181-182];
  mbi-alias 0x17a10000 sits right after GICD 0x17a00000+0x10000 [V sm8250.dtsi:6132-6140];
  PCI_DEVICE_SUB(0x0306, QCOM, 0x010c) -> foxconn info, overridden by qcom,flashless
  [V: pci_generic.c:968-979]; MHI API signatures match [V: mhi.h:616,750,776,
  mhi_result:506-511, MHI_EOT/CHAIN:59-60]; MHI_FW_LOAD_CAPABLE excludes SBL so no
  BHI download conflicts with the Sahara loader [V: internal.h:78].
- Sahara loader host test PASSES against the real patched sahara.c under
  ASan/UBSan [V: `tests/modem-sahara/check <tree>` -> "PASS: actual Sahara
  parser/allowlist, bounds, batching, ring/queue/completion failures"].
- [I] wake-gpios on the root port has no in-kernel consumer in this tree (only the
  endpoint-node wake gpio is read, drivers/pci/of.c:649; the patch puts it on
  pcie@0) — inert but schema-placed, matches the cited reference. WAKE# polarity
  changes ACTIVE_HIGH (deprecated host node) -> ACTIVE_LOW (root port) per the
  reference; on-device gate will confirm.
- No defects. Camera/modem series ready for their coordinator gates as written.

## Area 2 — DTS fragments and kernel.config

- All 79 symbols in device/instantnoodlep/kernel.config resolve in l-k3 Kconfig
  [V: extraction vs 21523 defined symbols]; only CONFIG_MHI_BUS_SAHARA is
  patch-provided (0002 adds it) and the config says so [V: kernel.config comment].
- Dependency spot-checks: WWAN=y with `# CONFIG_GNSS is not set` [V: WWAN depends
  on GNSS || GNSS=n]; PCIE_QCOM=y needs PCI_MSI=y [V set]; DRM_MSM=y selects
  DRM_MIPI_DSI [V: msm/Kconfig:136] so PANEL_AMS678UW01=y is valid; IOMMU_DMA is
  def_bool ARM64 [V: iommu/Kconfig:153-154] so VIDEO_QCOM_CAMSS=y is valid;
  SCSI_UFSHCD_PLATFORM=y, DRM=y, MFD_SPMI_PMIC=y, QCOM_GENI_SE=y, QCOM_SMEM=y come
  from defconfig/omamobile.config [V: arch/arm64/configs/defconfig,
  ~/src/omarchy-mobile@6c11752 kernel/configs/omamobile.config].
- dtbo/neutral.dts ids match DTBO-PLAN stock entry 16 [V: DTBO-PLAN.md:33-34 vs
  neutral.dts qcom,board-id 0x10008, oplus,dtsi_no 0x4d63, pcb_range <0 0x38>].
- device.conf UFS_RW="boot_b dtbo_b vbmeta_b userdata", BOOT_IMAGES="boot dtbo
  vbmeta" — slot-B-only + userdata [V vs AGENTS.md rule 3]. (PR #77 tightens this
  further; reviewed there.)
- No wrong symbols, no silently dropped lines found. No defects.

## Area 3 — tools/ and scripts/ shell safety

- No `fastboot flash/erase/oem/set_active`, no `dd of=/dev`, no `eval`, no
  pipe-to-shell anywhere in tools/ scripts/ tests/ [V: grep]. `sudo` appears only
  for laptop package installs in omabook-fetch-tools.sh, with a no-terminal
  fallback that hands the line to the owner [V: :47-65].
- `rm -rf` only on mktemp dirs (quoted) and on $OUT/lib/modules/$RELEASE where
  RELEASE is validated against [A-Za-z0-9._+-] first [V: prepare-initramfs-root.sh:158,265-268,279,313].
- build-instantnoodlep-probe: never runs fastboot (prints the RAM-boot template
  only) [V: :730], fresh --out enforced [V: :633-635], --root none asserts no
  /etc/omamobile-ufs-rw in the written initramfs, --root userdata asserts exactly
  "userdata" [V: assert_allowlist], input DTB never modified (copy first) [V:
  make_probe_dtb]. slot-b-mark is pure computation on private reads, refuses
  anything but the 4 expected sectors [V: build()]. stage0-collect.sh is read-only
  adb/getvar with a privacy warning [V: header].
- Host tests all pass [V: tests/instantnoodlep-probe 6/6 groups 0 skipped;
  tests/instantnoodlep-slot-b-mark ok; tests/trail-lite ok].
- No defects.

## Area 4 — plans/runbooks vs the AGENTS.md safety model

- Every gate table in device/instantnoodlep/*.md and docs/ has Command/Expect/
  Stop/Rollback columns [V: table headers checked programmatically].
- Write steps individually verified: M1b B2 (flash boot_b/userdata, set_active b,
  owner go 1-3, stop/rollback incl. set_active a) [V: BRINGUP-M1b-PLAN.md:181-201];
  B5 dd to /dev/sde LBAs 1,3,655356,655359 with expect/stop/rollback via orig
  sectors, documented as the hand-only exception [V: :225-260]; STORAGE-M2 T3
  [V: :320-340]; DTBO-PLAN D1 [V: :68]; STAGE-0-RUNBOOK C2 oem unlock with screen
  confirm + brick warning [V: :405-420].
- No super/_a writes in any port tooling; RESTORE-RUNBOOK path 1 (fastbootd full
  OTA, writes super) is explicitly the owner's own last-resort recovery outside
  the port's tooling, recorded if used [V: RESTORE-RUNBOOK.md:33-63 + Never-do].
- UFS_RW values across the repo name only slot-B boot images + userdata [V: grep].
- No defects.

## Area 5 — privacy (tracked files + git history)

- Scanned all tracked files and all 139 commits (rev-list --all) for MAC, 15-digit
  IMEI-shaped, serial-keyword and email patterns. No real device serial/IMEI/MAC
  anywhere [V].
- [V] tests/trail-lite:34 carried synthetic literals 'aa:bb:cc:dd:ee:ff',
  '356938035643809', 'serialno: 1a2b3c4d' in the tracked file and in 75 history
  revisions since 98e6db2 (#61). Fixed in this PR: all four fixtures are now
  assembled at runtime like the existing email fixture; tests/trail-lite still
  passes and the lint still catches the assembled values [V: ran]. History purge
  is the owner's call -> issue #90.
- [V] Emails present by design: patch From/Signed-off-by/Assisted-by (DCO),
  MAINTAINERS context inside patches, one lore Message-Id in
  KONA-ROOT-DESIGN.md:59,264. Scoping question filed as issue #91.
- "serial" hits in history are false positives (998000.serial node name,
  {{SERIAL}} placeholder, prose) [V].

## Open PRs #69 #76 #77 #79 #81 #82 #83 #84 (diffs reviewed, comments posted)

- #69 power: clean [V: gates, watch script single write, config symbols; SMB5
  symbol is branch-provided like MHI_BUS_SAHARA]. [I] watch limits 4.44 V/2.1 A are
  above the driver's 4.435 V/2 A, so "stricter than the driver" is inaccurate for
  V/I — backstop only, harmless.
- #76 bt-addr: clean [V: tests 7/7 pass on the branch; hci_uart_qca verified
  hci_qca.c:2829; address never printed; §5.5 gated].
- #77 device-pkg: TWO defects -> issues #88 (test/all regex fails on own
  firmware.map, rc=1 [V]) and #89 (package firmware.map:37 maps mdmddr.mbn vs the
  merged exclusion patch [V]). device.conf tightening is correct [V].
- #79 shell-pkg: clean [V: container-only build, gated runbook, test-only patch].
- #81 sensors: clean [V: patches apply, slpi label/firmware-name match firmware.map,
  all fragment symbols resolve].
- #82 audio: clean [V: --enable-adsp keeps other remoteprocs disabled and is
  test-covered; branch tests pass; ADSP node/compatible verified sm8250.dtsi:6008;
  symbols resolve; WCD9385 is covered by SND_SOC_WCD938X].
- #83 misc-hw: clean [V: series applies in order; haptics/torch/i2c11 disabled by
  default; labels exist; gpio118/72 outside reserved ranges].
- #84 kona-root: clean [V: patches apply; qcom_smem_get_soc_id smem.h:15,
  QCOM_ID_SM8250=356 ids.h:193 matches board msm-id 0x164].
