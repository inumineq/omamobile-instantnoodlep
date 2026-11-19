<!-- SPDX-License-Identifier: MIT -->
# PM kernel series: GMU fw_devlink sync_state

[V] Apply `0001-drm-msm-adreno-bind-the-GMU-device-so-fw_devlink-sy.patch` on
top of kernel branch `instantnoodlep-k3-daily2-qce` (`c5e256242`), giving
branch `instantnoodlep-k3-daily2-qce-gmu` (`bd566b604`) in
`inumineq/linux-omarchy-mobile`. The patch is commit `bd566b604`; regenerate
with `git format-patch -1 bd566b604` from `~/src/l-k3-daily2-qce` on omaserver.

[V] Why: the GMU DT node (`gmu@3d6a000`, child of `soc@0` in
`arch/arm64/boot/dts/qcom/sm8250.dtsi:3012`) becomes a platform device at boot,
but no driver ever binds to it — the Adreno GPU driver only looks it up with
`of_find_device_by_node()` (`drivers/gpu/drm/msm/adreno/a6xx_gmu.c:2284`) and
programs it directly. Under fw_devlink strict sync_state the GMU's managed
consumer links (clocks/power-domains/iommus) therefore never become
`DL_STATE_ACTIVE`, so `gcc-sm8250` and `sm8250-gpucc` never receive
`sync_state()` (`drivers/base/core.c:1208-1214,1374-1470,1858-1860`) and
report `sync_state() pending due to 3d6a000.gmu`. The patch binds a no-op
platform driver to the GMU device so `device_links_driver_bound()` marks its
supplier links ACTIVE. Full analysis with file:line citations: PM-PLAN §4.5.

[V] The patch touches only `drivers/gpu/drm/msm/adreno/a6xx_gmu.c` (+41 lines);
`a6xx_gmu.o` compiles clean with clang 23.1.3 (`LLVM=1`) in the
`k3-daily2-qce-gmu` build. It is GPL-2.0 like the rest of the DRM/MSM driver.
No DT change is needed or made: the GMU device needs its `clocks`,
`power-domains` and `iommus` phandles at runtime
(`a6xx_gmu_clocks_probe()` does `devm_clk_bulk_get_all(gmu->dev, ...)`), so
stripping them in DT would break the GPU.

[I] On-device effect is unverified until the phone gate in PM-PLAN §4.5 runs:
no `sync_state() pending due to 3d6a000.gmu` lines, `/sys/bus/platform/devices/
3d6a000.gmu/driver` resolves to `adreno-gmu`, USB gadget still attaches, and
`/sys/kernel/debug/qcom_stats` counters advance with screen off and cable out.
