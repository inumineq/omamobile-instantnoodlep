<!-- SPDX-License-Identifier: MIT -->
# CAMERA-PLAN: raw cameras on instantnoodlep (OnePlus 8 Pro IN2023)

Status: M-CAM1 offline candidate in preparation; no phone test has run. The target is the IN2023 / SM8250 camera path, starting with a
single raw Bayer frame from the fixed-focus front camera. All phone commands
below are for the owner/coordinator; this worker had no phone access.

- Date: 2026-11-17. Candidate branches: `instantnoodlep-k3-camera` (combo
  base, 2026-11-17, clang 19) and `instantnoodlep-k3-slim-cam` (slim K3 base
  `78f38a2acc99`, 2026-11-18, clang 23 — the current candidate, §9.5).
- Reading order: `AGENTS.md`, `DTS-PORT-PLAN.md`, `DTBO-PLAN.md`,
  `FIRMWARE-PLAN.md` and `firmware.map`, `DISPLAY-M3-PLAN.md`,
  `AUDIO-M5-PLAN.md`, `NOTES.md`, and `M5-REVIEW.md`.
- This file uses `[V]` for a checked fact with its public source and `[I]`
  for a device- or implementation-level inference still to check.
- No binaries, register tables, calibration data, tuning blobs or firmware
  are copied into this repository. Public vendor-tree facts are summarized
  as hardware facts only (AGENTS.md rules 4, 5 and 8).

## 1. Decision and scope

- [V] SM8250 has a mainline Qualcomm CAMSS driver, a VFE480 raw/RDI path,
  CSID support and CSIPHY support; the generic binding describes the six
  CSIPHY blocks, CSID blocks, VFE blocks, clocks, power domains, interconnects
  and PHY supplies (`torvalds/linux`, tag `v7.3-rc6`,
  `drivers/media/platform/qcom/camss/`,
  `Documentation/devicetree/bindings/media/qcom,sm8250-camss.yaml`).
- [V] The upstream SM8250 CSIPHY table in `camss-csiphy-3ph-1-0.c` has the
  SM8250 D-PHY lane setup. The three-C-PHY-trio support used by the main and
  ultrawide sensors is in the public community series, not the pinned upstream
  source: community kernel patches 0033-0041 add PHY-type handling, C-PHY lane
  programming, CSID mode selection and link-frequency calculation
  (`darknagel/oneplus-instantnoodlep-nura-unofficial`,
  `docs/patches.md`, “C-PHY on SM8250 CAMSS”; pmaports patch 0022).
- [V] Mainline V4L2 sensor drivers exist for Sony IMX471 and Samsung S5K3M5
  (`v7.3-rc6`, `drivers/media/i2c/Kconfig`, `imx471.c`, `s5k3m5.c`). The
  upstream Kconfig/Makefile has no IMX689, IMX586 or GC5035 sensor driver.
  `libcamera` support for all five device modules is not in an unmodified
  upstream stack: the public community port carries S5K3M5 support, and extra
  libcamera work for IMX586, IMX689 and GC5035, with a soft-ISP pipeline
  (`Nura docs/patches.md`, camera rows; pmaports patches 0008, 0023 and 0034).
- [V] The present device tree intentionally does not enable camera hardware;
  the K2 DTS scope in `DTS-PORT-PLAN.md` leaves camera work for a later plan
  (§2.1 reserved memory and §2.3). A complete board camera graph is not
  inherited merely by enabling the SoC CAMSS node.
- [I] This is substantial new upstream camera work: board CAMSS/CCI/power
  integration, C-PHY support for two sensors, three new sensor drivers, focus
  and OIS support, media graph validation, userspace tuning and per-camera
  pipeline work. No claim is made that all five modules are supported by
  mainline or by Omarchy Mobile today.
- [V] There is a blocking common boot prerequisite. The stock DTBO changes
  the live root compatible to `qcom,kona-mtp qcom,kona qcom,mtp`, and both
  neutral-DTBO images tried to date were rejected by ABL; `dtbo_b` stays stock
  (`DTBO-PLAN.md` §1 and §6; `.trail/learnings/2026-11-17-the-stock-dtbo-rewrites-the-root-claude.md`,
  `.trail/learnings/2026-11-17-abl-rejects-a-neutral-single-entry-claude.md`).
  Upstreamable camera releases remain blocked until a separate, owner-approved
  resolution is in place. The coordinator explicitly authorized the combo
  kernel workaround for the RAM-only candidate in §9; do not retry either
  rejected DTBO.

## 2. Source pins and evidence boundary

- `L/` = upstream Linux `torvalds/linux` tag `v7.3-rc6`; relevant paths are
  linked in §1 and the table below. Tree:
  <https://github.com/torvalds/linux/tree/v7.3-rc6>. This is the
  driver-status baseline for this plan, not a claim about a later kernel
  revision.
- `G/` = public OnePlusOSS GPL kernel sources for SM8250,
  <https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250>.
- `D/` = public OnePlus 8 Pro device sources,
  <https://github.com/LineageOS/android_device_oneplus_instantnoodlep>.
- `C/` = public SM8250 community kernel / board support at tag `7.2.0-dev`,
  <https://gitlab.nura.eco/soc/qualcomm-sm8250/linux>.
- `N/` = public Nura device port. The checked camera facts are in
  <https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial/blob/main/docs/patches.md>
  and its GPL camera patches: kernel patch 0009 (tele), 0012 (front), 0015
  (tele focus), and pmaports patch 0022 (main/ultrawide/colour-filter C-PHY
  integration), with follow-on camera patch notes in that file.
- [V] OnePlus official camera specifications:
  <https://www.oneplus.com/hk_en/8-pro/specs>.
- [V] Nura reports five cameras operational on tested IN2023 EU phones, and
  documents specific working modes and remaining limitations in
  `N/docs/patches.md`; this is evidence of that community image, not of this
  kernel or this unit.
- [I] The owner's exact camera modules, revisions, EEPROM contents, focus
  modules, enabled rails, and physical interconnects still require a safe
  live-DT/driver probe. The private stock overlay and captures are not inputs
  to this plan.

## 3. Module inventory

The CCI bus and endpoint details in this table are the public community DTS
configuration. They are candidate board facts to compare with the source
device's current mainline base and then with the owner's live DT before use;
they are not permission to copy the downstream tree wholesale.

| Camera | Module / sensor | Control bus and address | CSI receiver and link | Board power / clock facts | Focus, OIS, flash | Mainline sensor status |
| --- | --- | --- | --- | --- | --- | --- |
| Rear main (wide) | Sony IMX689, 48 MP [V: OnePlus official 8 Pro specs; N/docs/patches.md, main camera] | CCI0 master 0 / `cci0_i2c0`, `0x1a` [V: N/pmaports patch 0022, CAMSS integration] | CSIPHY0; three C-PHY trios, endpoint lanes `<1 2 3>`, 422.4 MHz link [V: N/pmaports patch 0022] | MCLK0 19.2 MHz; reset TLMM 145; AVDD 2.8 V from BOB-fed switch GPIO156; AVDD2 1.8 V switched GPIO26 / S5A; DVDD PM8009 L1F 1.104 V; DOVDD PM8009 L7F 1.8 V [V: N/pmaports patch 0022] | AK7377 VCM at `0x0c` (community binds the compatible through the AK7375 driver); main OIS is Onsemi LC898128 at `0x24`; no module flash [V: N/docs/patches.md, camera and OIS notes; N/pmaports patch 0022] | **No upstream IMX689 driver** in L/ `drivers/media/i2c/Kconfig` [V]. Needs a new, reviewed sensor driver and mode work. |
| Rear ultrawide | Sony IMX586, 48 MP [V: OnePlus official specs; N/docs/patches.md] | CCI0 master 1 / `cci0_i2c1`, `0x10` [V: N/pmaports patch 0022] | CSIPHY1; three C-PHY trios, endpoint lanes `<1 2 3>`, 421.2 MHz link [V: N/pmaports patch 0022] | MCLK1 19.2 MHz; reset TLMM 144; AVDD 2.8 V from PM8009 GPIO1; AVDD2 1.8 V switched GPIO159 / S5A; DVDD PM8009 L2F 1.104 V; DOVDD PM8009 L7F 1.8 V [V: N/pmaports patch 0022] | AK7377 VCM at `0x0f` (public community DT binds the AK7375 compatible); no OIS or module flash [V: N/docs/patches.md and pmaports patch 0022] | **No upstream IMX586 driver** in L/ `drivers/media/i2c/Kconfig` [V]. Community adds a new driver and libcamera helper. |
| Rear telephoto | Samsung S5K3M5, marketed 8 MP [V: OnePlus official specs; N/docs/patches.md] | CCI1 master 0 / `cci1_i2c0`, `0x2d` [V: N/kernel patch 0009] | CSIPHY2; four D-PHY data lanes [V: N/kernel patch 0009] | MCLK2 is 24 MHz in the community mainline DTS to meet the upstream S5K3M5 driver's clock requirement; vendor setup is 19.2 MHz [V: N/kernel patch 0009]. Reset TLMM 90; AVDD 2.8 V switched GPIO139; VDDD PM8009 L4F 1.056 V; VDDIO PM8009 L7F 1.8 V. AFVDD and all per-module rail sequencing require a fresh power audit [V: N/kernel patch 0009 and N/docs/patches.md; I: exact unit check] | LC898217XC focus actuator at `0x74`, switched power GPIO140 and PM8009 L6F; LC898128 OIS device at `0x24` [V: N/kernel patch 0015 and N/docs/patches.md]. No flash [V: community inventory] | **Upstream S5K3M5 driver exists** in L/ `drivers/media/i2c/s5k3m5.c`; four-lane D-PHY and timing/power integration still need board validation [V]. |
| Rear colour-filter | GalaxyCore GC5035, 5 MP; also receives near-IR [V: OnePlus official specs; N/docs/patches.md and pmaports patch 0022] | CCI0 master 1 / `cci0_i2c1`, `0x37` [V: N/pmaports patch 0022] | CSIPHY4; two D-PHY data lanes [V: N/pmaports patch 0022] | MCLK4 19.2 MHz; reset TLMM 92; AVDD 2.8 V from PM8150L GPIO1; DVDD 1.2 V switched TLMM 74; DOVDD PM8009 L7F 1.8 V [V: N/pmaports patch 0022] | Fixed focus; no OIS/flash [V: N/docs/patches.md] | **No upstream GC5035 driver** in L/ `drivers/media/i2c/Kconfig` [V]. Community adds a new sensor and libcamera helper. |
| Front | Sony IMX471, 16 MP, fixed focus [V: OnePlus official specs; N/docs/patches.md] | CCI1 master 1 / `cci1_i2c1`, `0x10` [V: N/kernel patch 0012] | CSIPHY3; four D-PHY data lanes [V: N/kernel patch 0012] | MCLK3 19.2 MHz; reset TLMM 78; AVDD 2.8 V from BOB-fed switch GPIO24; DVDD PM8009 L3F 1.056 V; DOVDD PM8009 L7F 1.8 V [V: N/kernel patch 0012] | Fixed focus, no OIS/flash [V: N/docs/patches.md] | **Upstream IMX471 driver exists** in L/ `drivers/media/i2c/imx471.c`; upstream's checked driver has one 1928×1088 RAW10 mode and requires four D-PHY lanes [V: L/ `imx471.c`, `VIDEO_IMX471` Kconfig]. This is the proposed first sensor. |

### 3.1 Shared camera controller and camera-specific support

- [V] CAMSS is a V4L2 media-controller pipeline: CSIPHY receives CSI-2,
  CSID decodes packets, and the SM8250 VFE480 driver exposes raw-interface
  output. Its mainline VFE implementation configures MIPI-RAW output and
  buffer queues (`L/drivers/media/platform/qcom/camss/camss-vfe-480.c`).
- [V] The mainline binding expects the board to provide CAMSS resources,
  clocks, regulators (`vdda-phy` / `vdda-pll`), power domains, interconnects,
  interrupts, IOMMU streams and media graph endpoints (`L/Documentation/devicetree/bindings/media/qcom,sm8250-camss.yaml`).
  Mainline's generic SM8250 DTS does not provide this handset's entire camera
  board graph; the community port explicitly enables CAMSS and both CCI
  controllers (N/kernel patch 0009 and pmaports patch 0022).
- [V] The main and ultrawide need C-PHY. Public community patch 0022 carries
  C-PHY patches 0033-0041, including the SM8250 Gen2 v1.2.1 three-trio lane
  setup; those patches precede the two camera integrations. The tele, front
  and colour-filter candidates use D-PHY in the community DT (N/kernel patches
  0009, 0012 and pmaports patch 0022).
- [V] The pinned `VIDEO_IMX471` driver lacks DT matching/binding and has
  only the ACPI `vana` rail; §9 adds those prerequisites explicitly.
- [V] Upstream `VIDEO_IMX471` and `VIDEO_S5K3M5` are V4L2 subdevice sensor
  drivers, not complete board camera support: correct clocks, regulators,
  reset, CSI graph, sensor modes, CAMSS VFE/CSID/CSIPHY operation and userspace
  format negotiation remain necessary (`L/drivers/media/i2c/imx471.c`,
  `s5k3m5.c`; N/docs/patches.md explains the device-level additions).
- [V] Public Nura status reports all five cameras under its patched libcamera
  stack, with known constraints: IMX689 main at 4000×3000/30, IMX586 ultra at
  4000×3000/30, S5K3M5 tele at 4208×3120/30 or 2104×1184/60, and front
  IMX471 modes described in `N/docs/patches.md`. It reports its own build,
  tuning and implementation, not an upstream Linux result.
- [V] No camera sensor firmware file is required by the listed upstream
  IMX471 or S5K3M5 drivers [V: L/ `imx471.c` and `s5k3m5.c` request no firmware].
  [I] The new IMX689/IMX586/GC5035 drivers and main/tele OIS may have
  per-module code or firmware requirements; prove them from licensed sources
  and filenames during implementation. Never add vendor blobs, camera tuning,
  OIS firmware or per-unit calibration to Git; first raw capture deliberately
  avoids those features.

### 3.2 Libcamera and userspace scope

- [V] A raw frame can be checked with V4L2 tools against the media graph;
  it does not require the ISP tuning and image-processing pipeline. The public
  community port uses V4L2 media graph tools and libcamera; its libcamera
  series carries helpers/tuning for the unsupported sensors (N/docs/patches.md,
  camera section).
- [I] Omarchy Mobile's current libcamera package and a camera app are not
  known to include an IN2023 pipeline configuration, tuning or IMX689/586/
  GC5035 helpers. Treat this as a later userspace project, separate from
  getting the first Bayer frame.
- [I] A future per-device camera package will need a permission model for
  `/dev/media*` and `/dev/video*`, a libcamera pipeline/configuration, and
  shell/application integration. No package or user permission changes are
  part of this plan.

## 4. First milestone and order

**M-CAM1: one fixed-focus front sensor, one raw frame.** [I: chosen as the
smallest candidate after the source audit; test this assumption at the owner
gate.] The upstream IMX471 driver is present, the community board graph uses
ordinary four-lane D-PHY on CSIPHY3, and the module has no focus motor or OIS.
It avoids the currently unmerged C-PHY work and leaves camera tuning, flash,
autofocus, OIS and the other four sensors out of the first experiment.

| Order | Result | Work boundary |
| --- | --- | --- |
| 0 | Resolve camera prerequisites | Upstreamable root-compatible work stays separate; §9 records the coordinator-approved combo-only RAM test exception. No rejected DTBO retries. |
| 1 | Board graph (front enabled only in the §9 RAM candidate) | Audit mainline CAMSS/CCI/PMIC definitions and bindings; add the CAMSS resources, front CCI node, sensor endpoint, rails, reset and clocks only in the kernel project. Do not import vendor DTS code. |
| 2 | V4L2 sensor subdevice | Enable upstream IMX471 + CCI/IMX/media config. Build/schema-check the board and inspect the graph offline. |
| 3 | First raw frame (RAM boot) | With a separately reviewed overlay or equivalent one-boot enablement, stream one small RAW10 frame to `/tmp` and read it back. No camera preview, flash or persistent capture. |
| 4 | Remaining cameras | Add S5K3M5 D-PHY, then the two C-PHY high-resolution modules and GC5035; stage by stage add their sensor drivers, CCI graph, lens/OIS devices, userspace and camera firmware policy. |
| 5 | Device camera application | Only after reliable raw streams, implement/port libcamera support, safe tuning provenance, camera naming and app integration. |

[V] Rows 1-2 are implemented offline as the three-commit kernel series and
verified per §9.4 (combo base) and §9.5 (slim base, current candidate); row 3
is the coordinator's C1-C5 gates in §9.1. Row 0 is
covered for this RAM candidate only by the combo kernel's test-only Kona
match (§9); the upstreamable replacement is separate work.

- [I] M-CAM1 being front-first depends on the existing IMX471 driver's
  supported mode being sufficient and on its rails/CCI wiring matching this
  unit. If either fails, stop and replan from a reviewed public board source;
  do not substitute a different sensor in the same boot.
- [V] A camera carve-out already exists in the K2 memory plan as `camera_mem`
  (5 MiB in the public community DTS inventory, `DTS-PORT-PLAN.md` §2.1).
  [I] It may be too small for future full-resolution CMA/buffer needs; the
  first 1928×1088 frame and all buffer sizing need offline and runtime checks.

## 5. Offline gates

Use the then-current `linux-omarchy-mobile` branch and private build directory;
do not build from or copy a community kernel tree. The actual camera DTS/code
belongs in the kernel repository; this file plans it only.

| Gate | Check | Pass | Stop / rollback |
| --- | --- | --- | --- |
| O0, common prerequisites | Review M1b/M3 state, current `DTBO-PLAN.md` resolution, live root-compatible mitigation, FIRMWARE-PLAN and owner restore baseline. | Owner has accepted a supported boot path; no unresolved root rewrite or rejected-DTBO experiment. | Any prerequisite missing: no phone boot; return to the owning blocker. |
| O1, source/config audit | Re-read the current upstream CAMSS, CCI, camera sensor and PMIC bindings/drivers; audit the chosen IMX471 compatible, data-lane endpoint, clocks and supplies; check device fragment for `VIDEO_QCOM_CAMSS`, `VIDEO_IMX471`, `V4L2_CCI_I2C`, `I2C_QCOM_CCI`, `VIDEO_V4L2_SUBDEV_API`, QCOM camera clocks/interconnects/PMIC. | Every node has a matching binding/driver; no unrelated sensor, flash or lens is enabled. | Missing binding/driver/config or a public-source contradiction: stop and split a separately planned kernel task. |
| O2, build / schema | Build `qcom/sm8250-oneplus-instantnoodlep.dtb` and the configured kernel; run `dt_binding_check` and relevant `dtbs_check` schemas against the candidate. | Clean build; no new schema warnings; every change is limited to camera dependencies and M-CAM1. | Any new error or unexplained warning: drop the candidate output and fix one logical change. |
| O3, DT review | `fdtget`/`dtc` the candidate, compare with the clean K2 DT and the public source facts in §3. Confirm live root compatible is not the stock Kona/MTP rewrite. | CAMSS/CCI and one front IMX471 graph only; other sensors, flash, OIS and focus devices remain disabled; no unexplained regulator or reserved-memory change. | Extra node, wrong lane/bus/rail or live identity mismatch: no image release. |
| O4, image / artifact audit | Hash the RAM-boot image and modules; check package and firmware maps. Ensure no raw captures, vendor blobs, IMEI/serial/MAC, calibration or camera tuning entered Git. | Names-only firmware map; no camera firmware is assumed for upstream IMX471; all generated captures remain private. | Any protected data or proprietary bytes: remove the artifact and stop before release. |
| O5, owner release gate | Review O0-O4 evidence, camera safety and boot rollback with the coordinator/owner. | Written go for one RAM-only camera test; no flash/erase/slot change. | No approval or an [I] described as a fact: do not boot. |

## 6. Gated runbook (owner/coordinator only)

No phone command in this section has been run by this worker. RAM boot only;
no `fastboot flash`, `erase`, `set_active`, `super`, `_a`, `persist`, firmware
partition, or userdata write. This is subject to AGENTS.md rules 1 and 3 and
the current DTBO blocker in §1.

| Step | Command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R0 — read-only inventory (first phone step) | From the existing K3 SSH session, run `ssh root@172.16.42.1 'cat /sys/firmware/devicetree/base/compatible; uname -r; ls /sys/bus/platform/devices; ls /dev/media* /dev/video* 2>/dev/null || true'`. Redact any identifying values before sharing. | K3 responds over SSH; root compatible and CAMSS/CCI binding state are recorded as facts; no camera is activated. | SSH unavailable, or any command would power/stream a sensor: stop and record; do not reboot to investigate. | No changes; leave the current boot as-is. |
| R1 — read-only boot gate | In fastboot, run `fastboot -s {{SERIAL}} getvar current-slot; fastboot -s {{SERIAL}} getvar slot-successful:b; fastboot -s {{SERIAL}} getvar slot-unbootable:b; fastboot -s {{SERIAL}} getvar slot-retry-count:b`. Never run while a placeholder remains. | Slot B is active, successful and bootable; values agree with the latest NOTES baseline. | Any value differs, or phone identity is not the owner's expected device. | No changes; stop and reconcile via the existing slot plan. |
| R2 — gate | Confirm O0-O5 and written owner go; verify the known-good slot-B recovery image and the approved ABL/DTBO resolution. | Exact image hash and boot path approved; stock `dtbo_b` untouched unless a separate approved plan changes it. | DTBO/root-compatible issue remains open, or the only path is a combo/test-only `qcom,kona` patch: stop. | No changes. |
| R3 — RAM boot | Owner runs the exact approved `fastboot -s {{SERIAL}} boot {{KCAM1_IMG}}` command from the reviewed release block. | ABL reports `Booting OKAY`, SSH returns, live root compatible matches approved target, and no new slot/boot state changes. | ABL refuses, SSH fails within 2 minutes, wrong live root, kernel/USB hang, or slot flags differ. | On refused RAM boot, cold-reboot to bootloader before any next `fastboot boot` (NOTES.md 2026-11-16 R1). Use the owner's known-good slot-B recovery image; do not boot slot A or flash. |
| R4 — enumerate without streaming | Run `ssh root@172.16.42.1 'dmesg; media-ctl -p; for p in /sys/class/video4linux/*/name; do if test -e "$p"; then printf "%s: " "$p"; cat "$p"; fi; done; for p in /dev/media* /dev/video*; do if test -e "$p"; then printf "%s\n" "$p"; fi; done'`. Redact identifiers before sharing. | CAMSS, CCI and one IMX471 sensor bind; media graph is connected through CSIPHY3 / CSID / VFE RDI; a four-lane D-PHY endpoint is reported. | Probe defers/errors, any unexpected camera binds, power/thermal warning or graph mismatch. | Stop capture tests; reboot to known-good slot B; fix one offline DTS/config item. |
| R5 — one raw frame | With the owner aware that the camera is active and after checking the lens is unobstructed, use the reviewed graph and the exact values enumerated by R4: `v4l2-ctl -d {{VIDEO_NODE}} --set-fmt-video=width=1928,height=1088,pixelformat={{RAW10_FOURCC}} --stream-mmap=3 --stream-count=1 --stream-to=/tmp/instantnoodlep-front.raw`. Never run while a placeholder remains. Inspect byte count and Bayer frame locally; do not upload or commit it. | One non-empty frame at the upstream IMX471 driver's declared mode, no VFE/CSID overflow or CCI timeout. | No frame, repeated timeout, surprise sensor/module, unexpected image content capture, or data would be written outside `/tmp`. | Stop streaming, delete the temporary file, record redacted log lines, reboot to known-good slot B. |
| R6 — unchanged boot state | In fastboot after the approved return path, run `fastboot -s {{SERIAL}} getvar current-slot; fastboot -s {{SERIAL}} getvar slot-successful:b; fastboot -s {{SERIAL}} getvar slot-unbootable:b; fastboot -s {{SERIAL}} getvar slot-retry-count:b`. | Flags match R1; no persistent image or partition was written. | Any flag differs or the phone fell back to stock/recovery. | Stop, preserve current slot; owner uses the existing recovery plan before another boot. |

Never use `i2cdetect`, raw CCI transfers, register dumps, actuator movement,
flash or torch during M-CAM1. These can power hardware or move a lens; they are
later, separate, explicitly gated steps.

## 7. Open [I]s

| ID | Inference / unknown | Resolution gate |
| --- | --- | --- |
| I-CAM-1 | The exact camera modules, CCI route and electrical population on the owner's IN2023 are the public community configuration. | R0 read-only live-DT inventory, then compare with a licensed public GPL source and owner-gated driver binding. |
| I-CAM-2 | Front IMX471 M-CAM1 is the lowest-risk useful first sensor and its only upstream mode fits the test. | O1/O3 support-mode audit; R3/R4 if approved. |
| I-CAM-3 | CAMSS D-PHY, IOMMU, camera clocks/interconnect, runtime PM and current K3 memory map are sufficient for one raw frame. | O2/O3, then R3/R4 with no unrelated node enables. |
| I-CAM-4 | Main/ultrawide C-PHY and the community CCI/rail choices can be upstreamed without new proprietary dependencies. | Fresh upstream source review and board-schema validation before camera stages 4-5. |
| I-CAM-5 | Sensor EEPROM/module data, proprietary tuning, OIS firmware and camera calibration can be omitted for basic raw capture. | Keep them excluded for M-CAM1; separately audit filenames/licensing before any later feature. |
| I-CAM-6 | A stable approved solution to the live root-compatible/DTBO problem will allow a clean upstream camera kernel to boot. | Separate owner-approved DTBO/root-compatible work; this plan does not select a fix. |

## 8. Definition of done

M-CAM1 is done only when O0-O5 and R0-R5 pass, one IMX471 RAW10 frame is
captured from a RAM-booted image with no protected partition changes, the
camera graph and kernel release are recorded in a dated NOTES entry, and all
unresolved [I] items remain identified. This document alone does not claim a
camera works on the owner's phone.

## 9. M-CAM1 implementation split (2026-11-17)

- [V] Coordinator approved the combo kernel's existing test-only Kona match
  for this RAM candidate only; row 0 and R2 do not block this explicitly
  authorized experiment. Stock DTBO remains untouched; no upstream release
  may include that match patch (learning `l-f28ff139`).
- [V] Audit of combo `aa996bae0`, `drivers/media/i2c/imx471.c`, found only
  ACPI matching, one `vana` supply, no DT binding, and a single four-lane
  1928x1088 mode advertising 200 MHz link frequency. The existing clock
  check requires 19.2 MHz (`IMX471_EXT_CLK`), which agrees with the public
  board's MCLK3 rate (N/kernel patch 0012). No mode/PLL change is planned.
- [V] Coordinator authorized separate GPL kernel commits before the board:
  (1) `sony,imx471` YAML with external clock, reset, three supplies and CSI
  endpoint; (2) OF/I2C matching and three-supply bulk control, preserving
  ACPI `vana`; (3) front-only board graph and config. Validate the binding,
  run strict checkpatch, build and schema-check before release.
- [I] Keep the upstream power sequence (rails, clock, release reset, wait
  10–15 ms) for the DT path. Public N/kernel patch 0012 identifies the three
  rail routes and a 2 ms AVDD regulator startup delay, but does not prove
  this unit's complete electrical sequencing. Driver probe and one frame
  remain coordinator-only gates; a chip-ID failure stops the experiment.
- [V] Public community link frequencies (748.8/400 MHz) describe its modified
  driver, not this pinned driver's 200 MHz mode. Use 200 MHz at both ends
  and retain all existing mode register values; successful streaming is [I].

### 9.1 Coordinator RAM-test gates (supersedes R2/R4/R5 for this candidate)

[V] This is the expressly authorized combo-based experiment, not an
upstreamable root-compatible fix. No worker phone access occurred. The
coordinator must preserve stock `dtbo_b`, slot B and the known-good daily
boot; no flash, slot switch or partition write is part of these gates.

1. **C0 — offline preparation.** Check the artifact SHA256SUMS, kernel release
   and source base. Install the candidate modules into the existing rootfs
   under their unique release (extract the `lib/modules/<release>` tree;
   keep the old release). Ensure `media-ctl`, `v4l2-ctl`, `timeout` and
   `sha256sum` are available before the RAM boot. This is a coordinator
   rootfs operation, not a partition-flash command. Expect all hashes to
   match and no existing release overwritten; stop on a mismatch or missing
   tools; rollback by removing only this new module release.
2. **C1 — RAM boot.** Run R0/R1 first, review C0 and the builder manifest,
   then `fastboot boot "$CAMERA_IMAGE"` with the coordinator's actual new
   image path, after written owner go. Expect `Booting OKAY` and SSH within
   two minutes. Stop for rejection, hang, root mismatch outside the known
   Kona test exception or changed slot flags. Rollback: owner returns to
   bootloader, then reboots the already successful known-good slot B;
   cold-reboot to bootloader after an ABL rejection before another RAM boot.
3. **C2 — enumerate (no stream).** Run `uname -r`,
   `dmesg | grep -Ei 'camss|cci|imx471|csiphy|csid|vfe|regulator|iommu'`,
   `media-ctl -p -d /dev/media0`, and `v4l2-ctl --list-devices` in the SSH
   session. Expect exactly one IMX471 subdevice connected to `msm_csiphy3`,
   plus the CAMSS CSID/VFE graph; compare the release with C0. If CAMSS is
   on another media device, inspect its graph before selecting it. Stop for
   chip-ID failure, deferred probe, rail/clock error, IOMMU fault or extra
   sensor. Rollback: no streaming; return to known-good slot B.
4. **C3 — graph and format negotiation.** Use the block below only after
   C2 confirms every named entity and pad. The sensor's I2C bus number is
   dynamic: set SENSOR to the exact `imx471 ...-0010` entity from C2, and
   MEDIA to the CAMSS media device. Expect all entities to accept
   `SRGGB10_1X10/1928x1088`; `--get-fmt-video` must report packed `pRAA`,
   1928x1088, 2416 bytes/line and 2628608 bytes/image for this RDI path.
   These sizes follow 1928*10/8=2410 rounded to 16-byte VFE alignment,
   times 1088 [V: `camss-video.c:57-65`, `camss-vfe.c:vfe_bpl_align_rdi`].
   Stop on any mismatch, missing route or busy link; do not guess another
   graph or FourCC. Rollback: reboot the known-good slot B.

```sh
# Coordinator's dedicated phone SSH shell; substitute C2 values first.
set -eu
MEDIA=/dev/media0
SENSOR='REPLACE_WITH_EXACT_IMX471_ENTITY_FROM_C2'
test "$SENSOR" != REPLACE_WITH_EXACT_IMX471_ENTITY_FROM_C2 || exit 1
media-ctl -d "$MEDIA" -l '"msm_csiphy3":1 -> "msm_csid0":0 [1]'
media-ctl -d "$MEDIA" -l '"msm_csid0":1 -> "msm_vfe0_rdi0":0 [1]'
media-ctl -d "$MEDIA" -V "\"$SENSOR\":0 [fmt:SRGGB10_1X10/1928x1088 field:none]"
media-ctl -d "$MEDIA" -V '"msm_csiphy3":0 [fmt:SRGGB10_1X10/1928x1088 field:none]'
media-ctl -d "$MEDIA" -V '"msm_csiphy3":1 [fmt:SRGGB10_1X10/1928x1088 field:none]'
media-ctl -d "$MEDIA" -V '"msm_csid0":0 [fmt:SRGGB10_1X10/1928x1088 field:none]'
media-ctl -d "$MEDIA" -V '"msm_csid0":1 [fmt:SRGGB10_1X10/1928x1088 field:none]'
media-ctl -d "$MEDIA" -V '"msm_vfe0_rdi0":0 [fmt:SRGGB10_1X10/1928x1088 field:none]'
media-ctl -d "$MEDIA" -V '"msm_vfe0_rdi0":1 [fmt:SRGGB10_1X10/1928x1088 field:none]'
VIDEO=$(media-ctl -d "$MEDIA" -e 'msm_vfe0_video0')
test -c "$VIDEO" || exit 1
v4l2-ctl -d "$VIDEO" --list-formats-ext
v4l2-ctl -d "$VIDEO" --set-fmt-video=width=1928,height=1088,pixelformat=pRAA
v4l2-ctl -d "$VIDEO" --get-fmt-video
```

[I] C3 route names/pads follow the pinned CAMSS sources, but the live graph
must confirm them; no fallback CSID/VFE route is authorized by this block.
Run each command with failure stopping the sequence (`set -e` in a dedicated
shell); do not continue after a failed link or format operation.

5. **C4 — capture one frame, then stop.** Owner explicitly agrees the front
   camera will activate; frame a non-sensitive scene. In the same dedicated
   shell, run the block below. Expect a single frame within 15 seconds,
   exactly the negotiated size, and no CCI/CSID/VFE/IOMMU error. Stop on
   timeout, empty/short frame, overflow, thermal/power warning or any
   unexpected behavior. Rollback: kill the capture if needed, remove the
   `/tmp` raw file, and return to the known-good slot B. Do not retry a
   capture in the same boot after an error.

```sh
timeout --signal=TERM --kill-after=2s 15s v4l2-ctl -d "$VIDEO" \
  --stream-mmap=3 --stream-count=1 --stream-to=/tmp/instantnoodlep-front.raw
stat -c %s /tmp/instantnoodlep-front.raw
sha256sum /tmp/instantnoodlep-front.raw
dmesg | tail -100
```

6. **C5 — private read-back and return.** Coordinator runs
   `scp root@172.16.42.1:/tmp/instantnoodlep-front.raw /tmp/instantnoodlep-front.raw`
   on the laptop, checks `sha256sum /tmp/instantnoodlep-front.raw` against
   C4, and locally checks for a plausible Bayer frame without uploading it.
   Expect matching hashes and a non-empty plausible frame; [I] image
   validity is not established merely by matching size/hash. Stop on mismatch
   or invalid data. Remove both `/tmp` files when done, reboot to the
   known-good slot B and perform R6. Rollback: delete only these temporary
   files; retain the baseline boot and modules. Record redacted results in
   NOTES, never the frame or identifying values in Git.

### 9.2 Matching module staging (coordinator only)

[V] After SCP of the delivered module tarball to `/tmp/camera-modules.tar.gz`,
run this in a dedicated phone SSH shell before C1. Expect a new directory
for only this release and successful depmod. Stop if the directory already
exists, extraction fails or the archive contains a different release.
Rollback (after returning to the baseline): remove only
`/usr/lib/modules/7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa` and the
`/tmp` staging directory/archive. The baseline module directory is retained.

[V] The slim rebuild (§9.5) carries the whole camera stack as modules
(`qcom-camss.ko`, `camcc-sm8250.ko`, `i2c-qcom-cci.ko`, `v4l2-cci.ko`,
`imx471.ko`), so staging this tarball is what makes the C2 enumeration
possible; udev loads them by modalias (platform `qcom,sm8250-camss` /
`qcom,sm8250-cci`, i2c `sony,imx471`). No manual module load is part of
C2; if the graph is empty after staging, stop and record it as a finding.

```sh
set -eu
CAMERA_RELEASE=7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa
test ! -e "/usr/lib/modules/$CAMERA_RELEASE"
CAMERA_STAGE=$(mktemp -d /tmp/camera-modules.XXXXXX)
tar -xzf /tmp/camera-modules.tar.gz -C "$CAMERA_STAGE"
test -d "$CAMERA_STAGE/lib/modules/$CAMERA_RELEASE"
cp -a "$CAMERA_STAGE/lib/modules/$CAMERA_RELEASE" /usr/lib/modules/
depmod "$CAMERA_RELEASE"
```

### 9.3 Laptop probe-builder command

[V] 2026-11-18 update (slim rebuild, §9.5): the candidate is built and the
RAM image already exists on omabook — no Mac transfer anymore. The release
block for C1 is `~/android/build/k3-slim-cam-ram/boot-slim-cam.img`
(sha256 in `~/android/build/k3-slim-cam-ram/SHA256SUMS`, manifest
`boot-slim-cam.manifest.json`, flags identical to
`~/android/build/k3-daily-ram/boot-daily.manifest.json`: `--boot 2 --root
userdata --debug-shell`). The builder inputs live in
`~/android/build/k3-slim-cam/` (`Image.gz`, the board DTB,
`modules-<release>.tar.gz`, `.config`). The 2026-11-17 macbookpro transfer
below (scp from `~/build/instantnoodlep-k3-camera-70d0761d1/`, ssh key
`id_ed25519.pub`) is superseded: that clang 19 build froze and was over the
image_size ceiling (learning `l-e03ff7fe`; KERNEL-SIZE §1). Stop if
`STOCK_OVERLAY`/`UFDT_APPLY` are unset or do not match the known-good K3
builder inputs (`~/android/build/p3/entry16.dtbo`,
`~/android/build/ufdt/ufdt_apply_overlay`). Expect a new image, read-back
validation and matching manifest hashes; rollback by deleting only the fresh
output directory. Never reuse an existing `--out`, and do not boot if the
builder fails.

[V] Superseded 2026-11-17 transfer step, kept for the record (macbookpro
clang 19 build; do not reuse):

```sh
# Laptop, from the Mac (paths as delivered in §9.4).
mkdir -p "$HOME/android/build/k3-camera-artifacts"
scp macbookpro:'~/build/instantnoodlep-k3-camera-70d0761d1/{Image.gz,sm8250-oneplus-instantnoodlep.dtb,camera-modules.tar.gz,kernel.config,SHA256SUMS}' \
  "$HOME/android/build/k3-camera-artifacts/"
cd "$HOME/android/build/k3-camera-artifacts" && sha256sum -c SHA256SUMS
```

```sh
# Laptop (omabook), from this port repo. Use a fresh directory for every attempt.
set -eu
: "${STOCK_OVERLAY:?set the verified private entry-16 overlay path}"
: "${UFDT_APPLY:?set the verified ufdt_apply_overlay executable path}"
CAMERA_ARTIFACTS="$HOME/android/build/k3-slim-cam"
CAMERA_BOOT_DIR=$(mktemp -d "$HOME/android/build/k3-slim-cam-ram.XXXXXX")
python3 tools/build-instantnoodlep-probe \
  --kernel "$CAMERA_ARTIFACTS/arch/arm64/boot/Image.gz" \
  --dtb "$CAMERA_ARTIFACTS/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb" \
  --ssh-key "$HOME/.ssh/omamobile_probe.pub" \
  --mkbootimg "$HOME/aosp-tools/system/tools/mkbootimg/mkbootimg.py" \
  --omarchy-mobile "$HOME/src/omarchy-mobile" \
  --initramfs-root "$HOME/android/build/initramfs-root" \
  --stock-overlay "$STOCK_OVERLAY" --ufdt-apply "$UFDT_APPLY" \
  --boot 2 --root userdata --debug-shell --out "$CAMERA_BOOT_DIR/boot.img"
```

[V] The watchdog, USB and storage path are built in (config fragment), so
this candidate has no `qcom_wdt.ko` to copy. Verify that the prepared shared
init's watchdog load tolerates built-in drivers (the existing K3 path);
do not inject an older-release module to satisfy a missing module file.
Any optional module loaded by the initramfs must match the new release.

### 9.4 Offline verification results (2026-11-17, macbookpro)

[V] The three-commit series (`2f48a3273` binding, `56a734ca4` driver,
`70d0761d1` board) is on branch `instantnoodlep-k3-camera`, based directly on
combo `aa996bae0`. The series contains no Kona workaround; the base does.
No worker touched the phone.

[V] Build: `make -j8 O=/w/out ARCH=arm64 LLVM=1
LOCALVERSION=-camera-g70d0761d1 Image.gz
qcom/sm8250-oneplus-instantnoodlep.dtb modules` in the `k3camera` container
(Debian trixie arm64, clang/lld 19.1.7) finished with no error. The only
compiler warnings in the log are two pre-existing `-Wformat` warnings in
`drivers/soc/google/aoc/alsa/aoc_alsa_compr.c`, untouched by this series.
Release: `7.3.0-rc6-instantnoodlep-k3-camera-g70d0761d1` (from
`include/config/kernel.release` and the `Image` version string).

[V] `scripts/checkpatch.pl --strict --no-signoff` on each patch: 0 errors,
0 warnings, 0 checks. `dt_binding_check` with
`DT_SCHEMA_FILES=media/i2c/sony,imx471.yaml`: clean (CHKDT/LINT/STYLE/DTEX/
DTC, no diagnostics). `dtbs_check` (`CHECK_DTBS=y`) on the board DTB: clean.

[V] Decompiled candidate DTB (`dtc -I dtb -O dts`): `camss@ac6a000` is
`okay` with `vdda-phy`/`vdda-pll` supplies and one `port@3` endpoint
(`clock-lanes = <7>`, `data-lanes = <0 1 2 3>`); `cci@ac50000` is `okay`
with `i2c-bus@0` disabled; exactly one `camera@10` with
`compatible = "sony,imx471"`, `reg = <0x10>`, three supplies, `reset-gpios`,
MCLK3 at 19.2 MHz, sensor-side `data-lanes = <1 2 3 4>` and
`link-frequencies = <200000000>`. No other sensor, flash, OIS or focus node
is enabled. The decompile also prints pre-existing base-DTS warnings
(geniqup i2c/spi duplicate unit-address, dsi `#address-cells`); none is
introduced by this series and none appears in the build or schema logs.

[V] Release config: `VIDEO_IMX471`, `VIDEO_QCOM_CAMSS`, `I2C_QCOM_CCI`,
`V4L2_CCI`, `V4L2_CCI_I2C`, `SM_CAMCC_8250`, `MEDIA_CONTROLLER` and
`VIDEO_V4L2_SUBDEV_API` are all `=y`, so the whole camera path is built in
and needs no module from the tarball. The tarball carries the other 1777
modules for the same release.

[V] Names the C2/C3 gates must match, from the pinned sources:
`msm_csiphy%d` (`camss-csiphy.c:794`), `msm_csid%d` (`camss-csid.c:1370`),
`msm_vfe%d_rdi%d` (`camss-vfe.c:2077-2080`) and the video entity
`msm_vfe%d_video%d` (`camss-vfe.c:2122`). RDI bytes-per-line alignment is 16
for `CAMSS_8250` (`camss-vfe.c:2001-2024`), so 1928x1088 RAW10 is
2416 bytes/line and 2628608 bytes/frame. `cam_mclk3_default` is GPIO97 with
function `cam_mclk` (`sm8250.dtsi:5185`); CCI1 bus 1 uses GPIO107/108
(`sm8250.dtsi:5242`).

[V] Artefacts on macbookpro, `~/build/instantnoodlep-k3-camera-70d0761d1/`
(`SHA256SUMS` in the same directory):

| File | SHA256 |
| --- | --- |
| `Image.gz` | `5ed65c5a193aee8e7128675294445c81dae81d9072e4fdd09e646309c5167a97` |
| `sm8250-oneplus-instantnoodlep.dtb` | `7074172c94df407ce43fa36b631c5f58c11d13dc4bf34e97ef364b2fab100bb9` |
| `camera-modules.tar.gz` | `68ee7091dc09a4fac4bad54df3763edcd8302b4c9b553e3cb065f8ae052f4894` |
| `kernel.config` | `c4aac462b08ac79a5d3e1579e28d15d6400f39314820ce598143f5d707ee2b7a` |

[I] Still unproven and left to the coordinator gates: chip ID over CCI, rail
ordering and module electrical timing, 200 MHz streaming through CSIPHY3/
CSID0/VFE0 RDI0, and the `orientation`/`rotation` values, which are inherited
from the public board patch and not measured on this unit. A chip-ID failure
in C2 stops the experiment; do not retry with a different mode or graph.

### 9.5 Offline verification results (2026-11-18, omabook, clang 23.1.3, slim K3 base)

[V] The three-commit camera series was re-based onto the slim K3 tip
`78f38a2acc99` (branch `instantnoodlep-k3-slim-cam`, tip `d53d0fd6baaa` in
`~/src/l-k3-slim`, fetched from macbookpro `instantnoodlep-k3-camera` via git
bundle; commits 1-2 cherry-pick identically, the board DTS commit was
merge-resolved against the daily tip's Wi-Fi/BT/gauge DTS additions —
camera and Wi-Fi/BT nodes are siblings, nothing dropped). Release:
`7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa`.

[V] Config: the slim `.config` (`~/android/build/k3-slim/.config`) merged with
a two-line camera fragment (`CONFIG_VIDEO_IMX471=m`,
`CONFIG_LOCALVERSION="-instantnoodlep-k3-slim-cam"`) + `olddefconfig`; the
diff against the slim `.config` is exactly those two lines. The whole camera
stack stays **modules** — `VIDEO_QCOM_CAMSS=m`, `SM_CAMCC_8250=m`,
`I2C_QCOM_CCI=m`, `V4L2_CCI=m`, `V4L2_CCI_I2C=m` as in slim — so a camera
probe hang cannot block boot; the modules ship in the tarball
(`qcom-camss.ko`, `camcc-sm8250.ko`, `i2c-qcom-cci.ko`, `v4l2-cci.ko`,
`imx471.ko`, 1125 modules total, `INSTALL_MOD_STRIP=1`).

[V] Build: `nice -n 5 make O=~/android/build/k3-slim-cam ARCH=arm64 LLVM=1 -j8
Image.gz qcom/sm8250-oneplus-instantnoodlep.dtb modules` with clang/lld
23.1.3 on omabook, RC=0. `image_size` (`od -An -tx8 -j16 -N8 Image`) =
**0x1720000**, identical to slim (the camera adds no built-in code) and far
under the ABL ceiling 0x2b60000 (KERNEL-SIZE §1) — unlike the 2026-11-17
clang 19 build (0x2cd0000, froze). `CHECK_DTBS=y` (dtschema venv): clean.

[V] Decompiled DTB: `camss@ac6a000` okay with `vdda-phy`/`vdda-pll`; exactly
one `camera@10` (`sony,imx471`, `reg = <0x10>`) on `cci@ac50000` `i2c-bus@1`,
MCLK 19.2 MHz (0x124f800), `reset-gpios` TLMM 78, three supplies, sensor
`data-lanes = <1 2 3 4>`, `link-frequencies = <200000000>`, remote-endpoint
into `camss` `port@3`; `i2c-bus@0` disabled; `qca6390-pmu` and
`regulator-cam-front-avdd` are separate root nodes (a misplacement of the
latter inside the former was caught by `dtbs_check` and fixed before
release).

[V] RAM image: `tools/build-instantnoodlep-probe` with exactly the daily
manifest flags (`--boot 2 --root userdata --debug-shell`, omabook probe key,
mkbootimg, omarchy-mobile, initramfs-root, entry-16 stock overlay,
ufdt_apply_overlay) produced
`~/android/build/k3-slim-cam-ram/boot-slim-cam.img` with read-back pass and
manifest `boot-slim-cam.manifest.json`. Artefacts and sha256
(`~/android/build/k3-slim-cam-ram/SHA256SUMS`):

| File | SHA256 |
| --- | --- |
| `~/android/build/k3-slim-cam/arch/arm64/boot/Image.gz` | `22d0ccf284003abde18f80715ecc84705e07ea5d6afcf9dd7ddbbd100956b574` |
| `.../arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb` | `7f04a8fd5d17794ce9fc0bcdc0f04d74e7f62b223c3ffb95346811699568f3ad` |
| `~/android/build/k3-slim-cam/modules-7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa.tar.gz` | `87ec8cc7577357c094a91bb8b7d6d767e7aa37da457e51c0582158e5d7d605b9` |
| `~/android/build/k3-slim-cam/.config` | `a70b8d804d317316fd9ee3f0c45f56167893fc6ff774b8f7f79137555bbfd574` |
| `~/android/build/k3-slim-cam-ram/boot-slim-cam.img` | `1704fd45d9c70c50d5eabd3e0a27c4a8b63c63cd649a3e3fa4b6d5a331d8516f` |

[I] Not done: no phone access, no RAM boot, no frame. C0-C5 remain the
coordinator gates, now against this release; the module staging in §9.2
carries the camera stack as modules. The §9.4 macbookpro artefacts stay as
the historical clang 19 reference.
