<!-- SPDX-License-Identifier: MIT -->
# M-CAM1 kernel series

[V] Apply these three patches in filename order to the combo kernel base
`aa996bae0695` (full base resolved in the release manifest). Kernel commits:
`2f48a3273` (binding), `56a734ca4` (driver), `70d0761d1` (board).
The series itself contains no Kona match workaround; its base does.
Never submit that base's test-only Kona patch upstream. No vendor mode
register table, firmware, calibration or private capture is included.

[V] The pinned upstream IMX471 driver is ACPI-only. The first two patches
supply the missing DT contract and enumeration/power handling; ACPI retains
its single `vana` supply. Existing 19.2 MHz xclk, 200 MHz link frequency,
1928x1088 RAW10 mode, PLL registers, reset handling and 10–15 ms power-up
recovery are retained. The external clock is acquired once and validated.

[I] Bulk regulator control does not establish a guaranteed rail ordering.
Electrical sequencing on the owner's module and actual 200 MHz streaming
must pass CAMERA-PLAN §9.1; the public board patch proves wiring only.

[V] Board wiring source: public GPL Nura front-camera patch 0012, commit
`05bdc4b733771ce93b5d3680e24a125ef3798e2b`, linked in CAMERA-PLAN §2.
CAMSS register/clock/IRQ/IOMMU/interconnect resources and MCLK3/CCI pinmux
are inherited from combo `arch/arm64/boot/dts/qcom/sm8250.dtsi`.
Only CCI1 master 1 and the front endpoint are enabled; the other master is
explicitly disabled. CAMSS PHY supplies use existing PM8150 L5A/L9A;
front rails add only PM8009 L3F/L7F and the GPIO24 BOB-fed 2.8 V regulator.

## Reproduction

[V] The Mac worktree is `~/src/l-k3-camera`, branch
`instantnoodlep-k3-camera`. It was created directly from combo `aa996bae0`.
The macOS case-insensitive checkout reports unrelated case-collision files;
none is staged or included in this series. Build from `git archive HEAD`
inside a dedicated case-sensitive Docker volume, never from an rsync copy
of that checkout. The archive preserves both case-colliding names.

[V] Build environment: Debian trixie arm64, clang/lld 19.1.7, LLVM=1,
Docker image `k3build:audio-base`; source `/w/src`, output `/w/out`, volume
`k3camera-src`, container `k3camera`. The image is only a toolchain carrier;
its existing `/out` objects and source were not used. Configure by merging
the original combo `.config` (delivered as `combo-base.config`) with this
repo's `device/instantnoodlep/kernel.config`, then run `olddefconfig`.
The release config is delivered alongside the images as `kernel.config`.

```sh
# Run inside the build container after git archive extraction and patches.
cd /w/src
KCONFIG_CONFIG=/w/out/.config scripts/kconfig/merge_config.sh -m -O /w/out \
  /w/combo.config /w/camera.config
make O=/w/out ARCH=arm64 LLVM=1 olddefconfig
make -j8 O=/w/out ARCH=arm64 LLVM=1 LOCALVERSION=-camera-g70d0761d1 \
  Image.gz qcom/sm8250-oneplus-instantnoodlep.dtb modules
make O=/w/out ARCH=arm64 LLVM=1 LOCALVERSION=-camera-g70d0761d1 \
  INSTALL_MOD_PATH=/w/modules INSTALL_MOD_STRIP=1 modules_install
```

[V] Schema validation uses a separate `/w/check` output directory with the
same configuration. `CHECK_DTBS=y <board>.dtb` runs the same validation path
as `dtbs_check` while limiting it to this board (Linux Makefile:1681–1689).
Schemas: `media/i2c/sony,imx471.yaml`, `media/qcom,sm8250-camss.yaml`,
`i2c/qcom,i2c-cci.yaml`, `regulator/qcom,rpmh-regulator.yaml`, and
`regulator/fixed-regulator.yaml`. Also run `dt_binding_check` with
`DT_SCHEMA_FILES=media/i2c/sony,imx471.yaml` and `checkpatch.pl --strict`
separately on each patch. Results and artifact hashes are in CAMERA-PLAN.
