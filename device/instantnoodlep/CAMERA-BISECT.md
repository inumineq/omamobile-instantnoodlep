<!-- SPDX-License-Identifier: MIT -->
# Camera boot-hang bisect candidates

Status: offline preparation from `instantnoodlep-k3-slim-all`; no phone was
accessed. The coordinator performs the owner-gated RAM boots after checking
each candidate's hashes and staging its matching modules.

- **[V: coordinator report, 2026-11-18]** With the front camera enabled,
  qcom_camss / IMX471 / CCI / CAMCC hangs before root; with the camera off the
  kernel boots. Blacklisting modules did not fix the hang.

This runbook isolates the front-camera boot hang by adding one probeable
hardware group at a time. Do not use `fastboot flash`, change slots, or alter
the stock DTBO. The bisect is inconclusive if candidates differ in anything
besides the listed camera config and DTS changes.

## Candidate ladder

Each candidate is based on the same `instantnoodlep-k3-slim-all` source and
`slim-all.config` (SHA256 prefix `8a7b72e0de22f85d`). Preserve every other
config option, DTS node and existing working device feature. The candidate
branches and build outputs are:

| Candidate | Branch | Build output | Camera pieces enabled |
| --- | --- | --- | --- |
| B1 | `instantnoodlep-k3-cam-bisect` @ `b7274db8c79b` | `~/android/build/k3-cam-b1/` | CAMCC only |
| B2 | `instantnoodlep-k3-cam-bisect` @ `350441f7b9fe` | `~/android/build/k3-cam-b2/` | CAMCC + CCI; IMX471 client explicitly off |
| B3 | `instantnoodlep-k3-cam-bisect` @ `67edb008df3e` | `~/android/build/k3-cam-b3/` | Full front-camera path: CAMCC + CCI + CAMSS + IMX471 |

Each rung builds the newly enabled driver(s) in (`=y`), not as modules. Later
camera drivers stay at their base values until their rung; this avoids the
ineffective module-blacklist test for the group under test and makes a boot
failure during DT-probed initialization attributable to the step being added.
The exact per-candidate Kconfig and DTS diff is recorded below.

| Step | Exact delta from prior candidate | Expected result |
| --- | --- | --- |
| B1 | Enable only the SM8250 camera-clock controller node and driver. | The kernel reaches the existing root/userspace and SSH. If it hangs before root, CAMCC enablement is sufficient to trigger the failure. |
| B2 | Keep B1 and enable only the CCI controller(s) and CCI support needed by the board. | Boots if CAMCC+CCI are safe. A hang here implicates the newly enabled CCI layer or its prerequisites. |
| B3 | Keep B2 and enable the front-only CAMSS / IMX471 path. | Boots if the full camera probe path is safe. A hang first appearing here implicates CAMSS, IMX471, their front-camera graph, or their interaction. |

“Boots” means reaching the known root filesystem and regaining SSH within two
minutes, with no unexpected slot-state change. A missing SSH response is a
failed candidate even if the boot logo remains visible. One candidate per
boot; do not try to load or unload camera modules by hand.

## Candidate source deltas

The kernel branch is `instantnoodlep-k3-cam-bisect` in
`~/src/l-k3-cam-bisect-edit`. Each artifact is built at the exact cumulative
commit in the tables; B1 is the first camera-only commit, B2 adds CCI, and B3
adds the remaining camera path. The generated `.config` and `config.diff` in
each artifact directory are the final build evidence.

| Candidate | Kconfig changes vs `slim-all.config` | DTS changes vs `slim-all` | Kernel commit |
| --- | --- | --- | --- |
| B1 | `CONFIG_SM_CAMCC_8250: m → y`; all CCI/CAMSS/IMX471 symbols remain at base values. Fragment: `arch/arm64/configs/instantnoodlep-k3-cam-b1.config`. | None. The SoC CAMCC node has no disabled status in `sm8250.dtsi:4671-4684`; the board camera endpoints and consumers remain disabled by the base DTS (`sm8250-oneplus-instantnoodlep.dts:508-559`). | `b7274db8c79b` |
| B2 | B1 plus `CONFIG_I2C_QCOM_CCI: m → y`; V4L2 CCI helpers and IMX471 stay at their baseline module values. Fragment: `arch/arm64/configs/instantnoodlep-k3-cam-b2.config`. | Enable only `&cci1`; explicitly set the `camera@10` client to `status = "disabled"` so the empty CCI bus/controller probes without starting IMX471. `&camss` stays disabled. | `350441f7b9fe` |
| B3 | B2 plus `CONFIG_MEDIA_SUPPORT=m → y`, `CONFIG_VIDEO_DEV=m → y`, `CONFIG_VIDEO_QCOM_CAMSS: m → y`, `CONFIG_VIDEO_IMX471: m → y`, and Kconfig's built-in dependency closure: `I2C_MUX`, `V4L2_ASYNC`, `V4L2_CCI`, `V4L2_CCI_I2C`, `V4L2_FWNODE`, `VIDEOBUF2_CORE`, `VIDEOBUF2_DMA_SG`, `VIDEOBUF2_MEMOPS`, and `VIDEOBUF2_V4L2`. The fragment disables unrelated analog-TV, digital-TV, radio and SDR categories; generated config also drops DVB/tuner/SDR modules as a dependency of `MEDIA_SUPPORT=y`. Kconfig dependency closure was checked against the generated `.config` and is captured in `config.diff`. Fragment: `arch/arm64/configs/instantnoodlep-k3-cam-b3.config`. | Enable `&camss` and `camera@10`; preserve the base front-only graph, rails, reset, clock, endpoint and link frequency unchanged. | `67edb008df3e` |

Each fragment pins a distinct `CONFIG_LOCALVERSION`; `CONFIG_LOCALVERSION_AUTO=y`
adds that rung's source commit. The three rungs are cumulative on the same
branch, so the source commits and generated config diffs identify exactly
which probe group was added. Per-rung release, header size and hashes are
recorded below; generated `kernel.config` files are included in each artifact
directory.

## Artifact checklist

Each output directory contains:

```text
Image.gz
sm8250-oneplus-instantnoodlep.dtb
modules-<kernel.release>.tar.zst
kernel.release
image_size.txt
kernel.config
config.diff
SHA256SUMS
```

### Build records

All three candidates were built with clang/LLD `23.1.3`,
`ARCH=arm64 LLVM=1`, and `-j12`. Raw image header values are below the
`0x2b60000` ABL ceiling. Each artifact directory contains `Image.gz`, the
board DTB, a stripped modules tarball, `kernel.release`, `image_size.txt`,
`kernel.config`, and `SHA256SUMS`.

| Candidate | Release | Raw Image size | Artifact directory |
| --- | --- | --- | --- |
| B1 | `7.3.0-rc6-instantnoodlep-k3-cam-b1-gb7274db8c79b` | `0x1780000` | `~/android/build/k3-cam-b1/` |
| B2 | `7.3.0-rc6-instantnoodlep-k3-cam-b2-g350441f7b9fe` | `0x1780000` | `~/android/build/k3-cam-b2/` |
| B3 | `7.3.0-rc6-instantnoodlep-k3-cam-b3-g67edb008df3e` | `0x1860000` | `~/android/build/k3-cam-b3/` |

**[V] B1 hashes:** `Image.gz` `393715706ec9eb70d5a9e6a1494554b9f19db36494cb7f7572cc982303f5926e`;
DTB `daffe04b12104c0ebb90cae837735ec1e0f35ced5c51ee9ed2a05eafbe2c7f7f`;
modules `ca94eb6d5201513bbba792618aa62755325fbc2da30ff226a5d8384519da0bbb`;
manifest `4abb29d3a08fe239dfed64a38938b5995aaac3778992cab577586b5fb74ca539`.

**[V] B2 hashes:** `Image.gz` `a0ee6b11ac71e8e622fafa931b497f533db1de159aea9b52328172b1c9b78afa`;
DTB `98c2a616570e0462c6ebd48c34ffba6d12e96d332adccad015b34016a2d967ae`;
modules `3f961406f62f1836bb7f474a0ab11444954c1e6c6e0d3fb63dd537ef56735079`;
manifest `cc8026fe937721f891ced0d3af90d9ec9d0d3ed1d936e4cc649e479e46bd29ea`.

**[V] B3 hashes:** `Image.gz` `9b11907892e303ecd93f6e03d20eadad89274934d1d76f817e5f50d1db88a8e3`;
DTB `e177815f385c4b81d83102115cdd0663c5ca44eb014f73211105dc6bec5341ec`;
modules `e78b8d6f87a8d12ea00140415fbc7e025abcc60eac0b1e48e43f5a4c76b2057f`;
manifest `87738a38d830f613a50f4be5842b7fa46b34b0e18bb18637517bc9ee7b32ddec`.
Each candidate's manifest contains the `kernel.release`, `image_size.txt`
and `.config` hashes too; verify it with `(cd <candidate-dir> && sha256sum -c SHA256SUMS)`.

### B1 build record

- **[V]** Release: `7.3.0-rc6-instantnoodlep-k3-cam-b1-gb7274db8c79b`;
  source commit `b7274db8c79b`; raw `Image` header `image_size=0x1780000`
  (ABL ceiling `0x2b60000`); clang/LLD `23.1.3`.
- **[V]** Output directory: `~/android/build/k3-cam-b1/`.
- **[V]** `SHA256SUMS` file SHA256:
  `4abb29d3a08fe239dfed64a38938b5995aaac3778992cab577586b5fb74ca539`.
  It verifies:

  ```text
  393715706ec9eb70d5a9e6a1494554b9f19db36494cb7f7572cc982303f5926e  Image.gz
  daffe04b12104c0ebb90cae837735ec1e0f35ced5c51ee9ed2a05eafbe2c7f7f  sm8250-oneplus-instantnoodlep.dtb
  ca94eb6d5201513bbba792618aa62755325fbc2da30ff226a5d8384519da0bbb  modules-7.3.0-rc6-instantnoodlep-k3-cam-b1-gb7274db8c79b.tar.zst
  58e38b6b8fd713ba684fb97f5bba18d207f80203ae8e0f1454cc3d2d8754a0e0  kernel.release
  0d9495f8c5de0241c703e3925cf391d8cbc686152b4fe5f1e9b0c683ff1e7e79  image_size.txt
  8018bbcfedae4df8e997962f7fe314389ea5b048cab2c26edd0a289d2f56f3fd  kernel.config
  8fb8a9bf7c41bd8db4313d81e384983be662839fde91a79d9c378d16aea9a202  config.diff
  ```

Use clang/LLD 23.1.3 with
`make O="$KBUILD_OUT" ARCH=arm64 LLVM=1 -j12 Image.gz modules dtbs`; print the
compiler version in the release report. With out-of-tree build directory
`KBUILD_OUT`, verify the raw arm64 `Image` header with:

```sh
od -An -tx8 -j16 -N8 "$KBUILD_OUT/arch/arm64/boot/Image"
```

The value must be no greater than `0x2b60000`. Build modules with
`INSTALL_MOD_STRIP=1`, stage `modules_install` into a fresh directory, and
archive only `lib/modules/<kernel.release>` as zstd. Do not reuse a release
directory or overwrite artifacts from another candidate.

## Owner/coordinator RAM-boot gates

1. Verify candidate `SHA256SUMS`, kernel release and `image_size.txt`.
   Stop on any mismatch or size over `0x2b60000`.
2. Stage that candidate's matching module tree in the rootfs without
   replacing the currently installed release. Stop if the release directory
   already exists or the archive contains a different release.
3. With the owner present and after the coordinator's fastboot/slot checks,
   RAM boot only:

   ```sh
   fastboot boot "$CAM_B1_BOOT_IMG"
   fastboot boot "$CAM_B2_BOOT_IMG"
   fastboot boot "$CAM_B3_BOOT_IMG"
   ```

   Substitute and run one command at a time; do not leave placeholders in a
   command. Expect `Booting OKAY`, then SSH within two minutes. Stop at the
   first hang, root/USB failure, kernel warning, or changed slot state. After
   an ABL refusal, cold-reboot to the bootloader before another RAM boot.
4. Return to the known-good slot-B daily kernel by rebooting normally; no
   partition write or slot change is part of this test. Remove only the
   just-staged candidate module directory after the coordinator confirms the
   candidate is no longer running.

The first failing rung narrows the cause; it does not prove an individual
driver defect because the newly enabled DTS nodes and their dependencies are
also part of that rung. Capture the last available boot log before drawing a
conclusion. Never commit device identifiers, camera frames, calibration or
firmware.

## B2 follow-up after the 2026-11-18/19 phone bisect

- [V] The owner/coordinator observed B1 boot and shut down cleanly. B2
  (`7.3.0-rc6-instantnoodlep-k3-cam-b2-g350441f7b9fe`) hung before root,
  with no journal or pstore (coordinator report, 2026-11-18/19).
- [V] The verified omabook copies show CCI `=m` and `cci1` disabled in B1,
  versus CCI `=y` and `cci1` okay in B2 (`kernel.config`, DTB
  `/soc@0/cci@ac50000/status`, and `SHA256SUMS` in
  `k3-cam-b{1,2}-omaserver`). B2 leaves `i2c-bus@0`, `camera@10` and
  CAMSS disabled (B2 DTB and board DTS lines 509–559).

### Ranked causes

Kernel source references below are at [B2 commit 350441f7b9fe](https://github.com/inumineq/linux-omarchy-mobile/commit/350441f7b9fe41e66d0e8b63923bfcb4fbd2b132).
DTS paths are relative to `arch/arm64/boot/dts/qcom/`.

1. **Reset uses an uninitialized completion.** [V] Probe initializes each
   master's completion inside the loop over available DT children.
   Controller reset always uses master 0, and the ISR completes master 0
   on reset ACK (`drivers/i2c/busses/i2c-qcom-cci.c:133–146,271–286,523–563`).
   `reinit_completion()` only clears `done`. `init_completion()` also
   initializes the wait queue, whose list is used to enqueue a waiter
   (`include/linux/completion.h:84–100`, `kernel/sched/swait.c:85–90`).
   [I] With only master 1 enabled, the reset waiter or ACK handler can hit
   the invalid queue before the nominal 100 ms reset timeout. Enabling
   empty master 0 or initializing all hardware masters in the driver
   should remove that fault.
2. **CCI MMIO path lacks a usable clock or powered domain.** [V] CCI0 and
   CCI1 each declare five CAMCC clocks and `TITAN_TOP_GDSC`, with their
   respective CCI branch and source; their MMIO bases are `0xac4f000` and
   `0xac50000` (`sm8250.dtsi:4407–4486`). Platform probing requests
   domain power-on (`drivers/base/platform.c:1501`,
   `drivers/pmdomain/core.c:3413,3461`). CCI bulk-enables the declared
   clocks before registering the IRQ and reading `CCI_HW_VERSION`
   (`i2c-qcom-cci.c:464–466,565–600`). Titan Top polls the GDSC status
   (`drivers/clk/qcom/camcc-sm8250.c:2259–2266`).
   [I] An inaccessible branch, missing upstream bus clock, or incorrectly
   reported GDSC state could stall the first MMIO access. A normal
   clock-enable error returns from probe. If both completion tests fail
   and the controller-off control boots, trace domain attach, each clock
   enable, and the first version read in that order.
3. **Camera configuration interconnect vote is missing at CCI probe.**
   [V] CAMSS declares the path from `MASTER_AMPSS_M0` to
   `SLAVE_CAMERA_CFG`; the CCI nodes declare no interconnect and CCI probe
   takes no vote (`sm8250.dtsi:4407–4486,4632`,
   `i2c-qcom-cci.c:505–620`). [I] B2 could depend on a firmware vote for
   CPU-to-camera register access that is absent when CAMSS is disabled.
   Investigate a specific configuration-path vote if power and clocks
   succeed and the first MMIO access stalls. A property alone would
   leave this driver's vote behavior unchanged.
4. **CCI functional source runs at an unsuitable rate.** [V] CAMCC supports
   19.2 MHz from XO and 37.5 MHz from PLL0 for both CCI sources; the CCI1
   DT node has no assigned rate. Its bus `clock-frequency` selects a
   timing table, which is programmed after reset
   (`camcc-sm8250.c:439–473`, `sm8250.dtsi:4448–4486`,
   `i2c-qcom-cci.c:228–288,553–560`). [I] A bad parent or inherited
   rate could prevent reset ACK. Test a supported source rate only after
   completion initialization, with evidence that register access works.
5. **Pinctrl conflict.** [V] CCI1 selects only GPIO107/108 in B2
   (`sm8250-oneplus-instantnoodlep.dts:525–533`,
   `sm8250.dtsi:5232–5267`). Driver core binds pinctrl before probe
   (`drivers/base/dd.c:684`). The B2 camera node supplies AVDD from a
   GPIO24-gated 2.8 V regulator, DVDD from LDO3 at 1.056 V, and DOVDD from
   LDO7 at 1.8 V. Its reset is GPIO78 and its MCLK3 is 19.2 MHz
   (`sm8250-oneplus-instantnoodlep.dts:207–218,490–502,535–559`).
   [I] A second consumer of GPIO107/108 could make binding fail or
   disrupt that consumer when the mux switches. The disabled sensor and
   empty adapter make sensor rail sequencing and I²C wire speed poor
   explanations for the B2 probe hang. Leave the sensor disabled.

### Console feasibility

[V] B2 sets `stdout-path` to `framebuffer0`, a `simple-framebuffer`
(`sm8250-oneplus-instantnoodlep.dts:98–113`). Earlier builds showed
`tty0` text via simpledrm ([NOTES.md](NOTES.md), 2026-11-17 night).
This path uses the simpledrm platform driver at device initcall time
(`drivers/gpu/drm/sysfb/simpledrm.c`, platform driver registration).
Stock's `earlycon=msm_geni_serial,0xa90000` describes a serial console
([r4-stock-images.md §2](../../docs/research/r4-stock-images.md#2-bootimg-header)).
The B2 earlycon OF table lacks a `simple-framebuffer` match
(`git grep EARLYCON_DECLARE` at the B2 commit). The requested diagnostic
image is skipped because the panel path depends on the DRM console.
[I] Whether `tty0` can display the final CCI initcall is unverified.

### Ranked owner-attended RAM tests

[V] The DT-only variants use the original clang/LLD 23.1.3 B2 `Image.gz`,
release and modules from `~/android/build/k3-cam-b2-omaserver/` on
omabook. The original manifest verified, and `image_size=0x1780000`.
Sorted DTB decompiles show one changed property per variant (`dtb.diff`
in each output directory). The stock overlay check, boot-image read-back,
and boot manifest hashes all passed (`pack.log` and
`boot-cam-b2-*.SHA256SUMS`). Outputs are under
`~/android/build/k3-cam-b2-followup/` on omabook.

| Rank | Variant | Single change | Expected observation |
| --- | --- | --- | --- |
| 1 | B2-master0 | Change `/soc@0/cci@ac50000/i2c-bus@0/status` from disabled to okay. The empty adapter has no clients and still no master-0 pinmux selection. | [I] SSH within two minutes and two Qualcomm-CCI adapters parented by `ac50000.cci` support the reset-completion hypothesis. An SSH pass with no adapter shows only that the fatal symptom cleared. |
| 2 | B2-completion | Initialize all hardware-master completions before parsing DT children. Use the original B2 board DTB, with only master 1 enabled. | [I] SSH and one Qualcomm-CCI adapter without a reset timeout would show that the empty master-0 adapter is unnecessary when the completion is initialized. |
| 3 | B2-off | Change `/soc@0/cci@ac50000/status` from okay to disabled; keep the same built-in driver. Use if the first tests hang or fail to bind. | [I] SSH with zero Qualcomm-CCI adapters implicates the live CCI1 device path. A repeat hang with CCI1 disabled redirects the bisect away from that live probe. |

[V] DT-only boot and input DTB hashes (SHA-256):

| File under `k3-cam-b2-followup/` | SHA-256 |
| --- | --- |
| `master0/boot-cam-b2-master0.img` | `3a6bb7d82979d653269010cc7657d87457b03220b94da9887f7aad104b7f508a` |
| `master0/sm8250-oneplus-instantnoodlep.dtb` | `c91a3dc0da9eb57cb74575eab2594ba40416ddb96c85e8d9bf614788023c4a2a` |
| `off/boot-cam-b2-off.img` | `2cdad83beeb3231649f88b3118e37d7d9b2ac714a4014c8788c0c1b267352b87` |
| `off/sm8250-oneplus-instantnoodlep.dtb` | `1bb2abecaf231570c91c83d333674db5f9ecd0c618756248997bb8aedbf72b5e` |

[I] Use the owner/coordinator RAM gates above, including matching modules
and slot checks. With the owner present, run the appropriate command
individually from omabook:

```sh
fastboot boot ~/android/build/k3-cam-b2-followup/master0/boot-cam-b2-master0.img
fastboot boot ~/android/build/k3-cam-b2-followup/completion/boot-cam-b2-completion.img
fastboot boot ~/android/build/k3-cam-b2-followup/off/boot-cam-b2-off.img
```

[I] Expect `Booting OKAY`, then SSH within two minutes. On the candidate
over SSH, read:

```sh
uname -r
findmnt -no SOURCE,FSTYPE /
sudo journalctl -k -b --no-pager -g 'CCI|ac50000|pinctrl|Unable to handle|BUG:|WARNING:'
for adapter in /sys/bus/i2c/devices/i2c-*; do
    [ "$(cat "$adapter/name" 2>/dev/null)" = Qualcomm-CCI ] || continue
    readlink -f "$adapter"
done
```

[I] Expect the candidate release, the normal root, and the adapter count
from the table. Preserve any failure excerpt locally and redact device
identifiers before reporting. Stop on a hash or slot mismatch, fastboot
refusal, SSH timeout, CCI reset error or kernel warning. Have the owner
recover to the installed daily on slot B before deliberately opening
another gate. B3 stays parked until B2-completion reaches root and
enumerates its CCI adapter.
