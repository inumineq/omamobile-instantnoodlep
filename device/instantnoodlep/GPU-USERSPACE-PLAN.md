<!-- SPDX-License-Identifier: MIT -->
# GPU-USERSPACE-PLAN: freedreno and Turnip in Omarchy Mobile's Mesa

House-rule-6 gate for GPU userspace on instantnoodlep (OnePlus 8 Pro,
SM8250, Adreno 650). Date: 2026-11-17. Scope: the `mesa` package and the
uwsm session environment. No kernel, DTS or firmware change; nothing here
touches the phone.

## 1. Problem [V]

- The kernel side works: under K3 (mainline 7.3-rc6) msm DRM binds, the
  a650 reports `gpu-initialized: 1`, revision 650, the zap loads and
  `/dev/dri/renderD128` exists [V: NOTES.md 2026-11-17 "keys, modules, GPU
  renders"].
- ALARM's stock Mesa 26.2.7, unpacked to /tmp on the phone, rendered with
  `OpenGL renderer: FD650`, OpenGL 4.6, OpenGL ES 3.2 [V: same NOTES entry].
- Hyprland still runs on llvmpipe, for two independent reasons:
  1. Upstream's `packages/mesa/PKGBUILD` builds Gallium
     `panfrost,llvmpipe,softpipe,zink` and Vulkan `panfrost` only
     [V: upstream `packages/mesa/PKGBUILD:168` and `:180`, upstream
     `c4623572`]. Without `freedreno` there is no `msm_dri.so`, so the
     loader cannot match the msm render node.
  2. `~/.config/uwsm/env-hyprland` on the phone exports
     `LIBGL_ALWAYS_SOFTWARE=1` [V: task brief; set during bring-up, not by
     any upstream file: `grep -rn env-hyprland` in upstream finds nothing].
- `rootfs/packages.omamobile` installs `mesa` and `vulkan-panfrost` from
  `[omamobile]` on every device [V: upstream `rootfs/packages.omamobile:34-35`].
  So every Qualcomm phone that takes the Omarchy Mobile rootfs gets a Mesa
  without freedreno. coral and flame reached FD640 with Arch's own Mesa
  (`26.2.5-arch1.1`), not with the omamobile build
  [V: upstream `device/flame/GPU-PLAN.md:4-5`, `device/coral/NOTES.md:27`].

## 2. Design: Mesa

Goal: freedreno for aarch64 with the smallest change for the Mali phones.

- Add `freedreno` to `gallium-drivers` and `freedreno` (Turnip) to
  `vulkan-drivers`. Set `freedreno-kmds=msm` explicitly; it is Mesa's
  default, and pinning it keeps kgsl and virtio out of the build.
- New split package `vulkan-freedreno`, the same shape as
  `vulkan-panfrost` (same `depends`, `provides=(vulkan-driver)`, depends
  on `vulkan-mesa-implicit-layers`). Its name matches Arch and ALARM's
  `vulkan-freedreno`, so `[omamobile]` listed ahead of `[extra]` replaces
  it the same way it replaces `vulkan-panfrost`.
- The Gallium driver lands in the shared `mesa` package (in
  `libgallium-*.so`, plus the loader names `msm_dri.so` and `kgsl_dri.so`,
  see §5). This is the only cost the Mali phones pay: a `mesa` package
  0.8 MB larger (2.3 MB installed). They do not install `vulkan-freedreno`.
- `vulkan-freedreno` goes into instantnoodlep's `ROOTFS_PACKAGES`
  (`device/instantnoodlep/device.conf`), not into `rootfs/packages.omamobile`.
  Other Qualcomm devices (coral, flame, enchilada, dipper) can opt in the
  same way.
- `pkgrel` 1.4 -> 1.5 and the VERSION marker `omamobile4` -> `omamobile5`,
  so Chromium drops its GPU cache and the build is distinguishable in
  `GL_VERSION`. Source checksums are unchanged: no new source or patch.
- No freedreno patches. Mesa 26.2.4 supports the a650 in both drivers
  [I: ALARM's 26.2.7 rendered FD650; 26.2.4 to be confirmed on the phone,
  §7 step 4].

Follow-ups the PKGBUILD patch leaves to the upstream PR (not in this repo,
house rule: only `device/instantnoodlep/` is edited here):

- `packages/mesa/README.md`: driver list, split packages, `pkgrel`, install
  command (`vulkan-freedreno-1:26.2.4-1.5-aarch64.pkg.tar.zst`), and the
  `IgnorePkg` line gains `vulkan-freedreno`.
- `packages/mesa/.SRCINFO`: regenerate with `makepkg --printsrcinfo`.
- `pkgdesc` of `mesa` names "Adreno 6xx"; widen it if a 5xx/7xx phone
  joins.

## 3. Proposed PKGBUILD diff

Exact file: [`patches/mesa-freedreno.patch`](patches/mesa-freedreno.patch),
against upstream `packages/mesa/PKGBUILD` at `c4623572`. `git apply --check`
passes there [V]. Apply from the upstream root:

```sh
git apply device/instantnoodlep/patches/mesa-freedreno.patch
```

The functional hunks:

```diff
 pkgname=(
   mesa
   vulkan-panfrost
+  vulkan-freedreno
   vulkan-mesa-implicit-layers
 )
-pkgrel=1.4
-_omamobile=omamobile4
+pkgrel=1.5
+_omamobile=omamobile5
@@ build()
-    -D gallium-drivers=panfrost,llvmpipe,softpipe,zink
+    -D freedreno-kmds=msm
+    -D gallium-drivers=panfrost,freedreno,llvmpipe,softpipe,zink
@@
-    -D vulkan-drivers=panfrost
+    -D vulkan-drivers=panfrost,freedreno
@@ package_mesa()
+    _pick vkfdreno $libdir/libvulkan_freedreno.so
+    _pick vkfdreno usr/share/vulkan/icd.d/freedreno_icd.json
@@
+package_vulkan-freedreno() {
+  pkgdesc="Open-source Vulkan driver for Adreno GPUs (Omarchy Mobile: Turnip)"
+  depends=( ...same list as vulkan-panfrost... )
+  optdepends=("vulkan-mesa-layers: additional vulkan layers")
+  provides=(vulkan-driver)
+  mv vkfdreno/* "$pkgdir"
+  install -Dm644 mesa-$_pkgver/docs/license.rst -t "$pkgdir/usr/share/licenses/$pkgname"
+}
```

The rest of the patch updates the header comment and `pkgdesc`.

## 4. Design: session environment (uwsm env.d)

File: [`uwsm/env.d/90-omamobile-instantnoodlep-graphics`](uwsm/env.d/90-omamobile-instantnoodlep-graphics),
installed by the future `omamobile-device-instantnoodlep` package to
`/usr/share/uwsm/env.d/` (as tegu's `install` does, upstream
`packages/omamobile-device-tegu/install:25`).

- Hardware GL when all three hold:
  1. `/dev/dri/renderD128` is a character device;
  2. its sysfs driver (`readlink /sys/class/drm/renderD128/device/driver`)
     is one of `msm`, `msm-mdss`, `msm_mdss`, `msm_dpu`, `adreno`;
  3. `/usr/lib/dri/msm_dri.so` exists, so the installed Mesa has freedreno.
  Then `LIBGL_ALWAYS_SOFTWARE=0`, `GALLIUM_DRIVER` and `QT_QUICK_BACKEND`
  unset, `QSG_RHI_BACKEND=opengl` (tegu's hardware branch).
- Otherwise llvmpipe: `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`,
  `QT_QUICK_BACKEND=software` (tegu's and bluejay's software branch).
- Why a sysfs check and not a ready file: tegu and bluejay wait for a
  guarded GPU start service that writes `/run/...-gpu-ready*`. msm on this
  phone needs no such service: the a650 came up on its own under K3
  [V: NOTES 2026-11-17]. Whether msm still registers `renderD128` when the
  GPU fails to load its firmware is not checked [I]; if it does, Mesa
  fails at context creation and the manual fallback in §6 applies. Check 3 covers the transition period while the
  phone still runs the panfrost-only Mesa, which has no `msm_dri.so`
  [V: §5 baseline]. Tested on the Mac against a fake root: msm-mdss with
  `msm_dri.so` gives hardware; without `msm_dri.so`, or with another
  driver, it gives llvmpipe [V]. `sh -n` and `dash -n` pass.
- Why several driver names: on mainline the msm DRM device is created by
  the MDSS platform device, so the render node's `device/driver` is the
  MDSS driver, not literally `msm` [I: from `drivers/gpu/drm/msm/msm_mdss.c`;
  the exact name on K3 is open question 1]. With `msm.separate_gpu_kms=1`
  the render node hangs off the GPU device (`adreno`).
- Load order [V: ALARM `uwsm-0.27.2-1-any`, `/usr/lib/uwsm/prepare-env.sh:74-91`
  and `:101-117`]: for every directory in
  `XDG_CONFIG_HOME:XDG_CONFIG_DIRS:XDG_DATA_DIRS`, walked in increasing
  priority (so `/usr/share` first, `~/.config` last), uwsm sources
  `uwsm/env`, then each file in `uwsm/env.d/`, then `uwsm/env-<desktop>`
  and `uwsm/env-<desktop>.d/`. The phone's own
  `~/.config/uwsm/env-hyprland` line `LIBGL_ALWAYS_SOFTWARE=1` therefore
  overrides this file and must go (§7 step 6). It also stays the manual
  fallback.
- Not set here: `AQ_DRM_DEVICES`. Hyprland already finds `card1-DSI-1`
  [V: NOTES 2026-11-17 "K3 RAM boots"]; pinning the card is a separate
  display decision.

## 5. Build proof [V]

Built on 2026-11-17 on the owner's Apple Silicon Mac (Docker Desktop
29.9.2, linux/arm64 natively, 10 CPUs, 8 GB VM). Not with
`tools/build-packages`: that also builds the signing and Omarchy keyring
image, which a one-package proof does not need. The container starts from
the same root tarball upstream's `tools/lib/alarm.sh` uses.

**Container image** [V]:

- `ArchLinuxARM-aarch64-latest.tar.gz` from `os.archlinuxarm.org/os/`,
  829367415 bytes, sha256
  `42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`,
  MD5 matches the `.md5` file, `gpg --verify` good signature by
  `68B3537F39A313B3E574D06777193F152BDBE6A6` (Arch Linux ARM Build System,
  the key upstream pins), signed 2026-08-05.
- `docker import --platform linux/arm64 ArchLinuxARM-aarch64-latest.tar.gz alarm-aarch64:20260805-42a4eeaa`
  -> image `sha256:3f62d3a93a2a…fd730`.
- Toolchain after `pacman -Syu` in the container: llvm/clang 23.1.5-1.2,
  meson 1.12.1-2, glslang and spirv-tools 1.4.363.0-1, libdrm 2.4.134-1.

**Command** [V]. In-container script:
[`tools/mesa-build-in-alarm.sh`](tools/mesa-build-in-alarm.sh) (keyrings,
full upgrade, makedepends from `.SRCINFO`, Mesa signers' keys,
`makepkg -f --nodeps --nocheck` as an unprivileged user; byte-identical
to `$B/build-in-container.sh` below). `work/mesa` is a
copy of upstream `packages/mesa` with the patch applied:

```sh
B=~/orca/build-out/mesa-freedreno
docker run --rm --platform linux/arm64 \
  -v $B/work:/work -v $B/out:/out -v $B/src:/srcdest \
  -v $B/build-in-container.sh:/build.sh:ro \
  alarm-aarch64:20260805-42a4eeaa bash /build.sh
```

**Result** [V: log `~/orca/build-out/mesa-freedreno/logs/build-20261117T102211.log`]:

- Source sha256 and b2 sums passed; `mesa-26.2.4.tar.xz` PGP signature
  passed; all ten panfrost patches applied with `--fuzz=0` (offsets only).
- meson summary: Gallium `panfrost freedreno llvmpipe softpipe zink`,
  Vulkan `panfrost freedreno`, `freedreno-kmds: msm`; 2435 ninja steps.
- Time: 6 min 51 s for the whole container run, of which makepkg
  (download, build, package) 4 min 52 s (09:24:08-09:29:00 UTC).
- `mesa` now ships `usr/lib/dri/msm_dri.so` (and `kgsl_dri.so`, both
  symlinks to `libdril_dri.so`); the strings `FD650` are in
  `libgallium-26.2.4-arch1.1.5.omamobile5.so` and `libvulkan_freedreno.so`.
  `freedreno_icd.json` names `libvulkan_freedreno.so`, API 1.4.354.

| Package (in `~/orca/build-out/mesa-freedreno/out/`) | File size | Installed size |
|---|---|---|
| `mesa-1:26.2.4-1.5-aarch64.pkg.tar.zst` | 7165472 | 28040958 |
| `vulkan-freedreno-1:26.2.4-1.5-aarch64.pkg.tar.zst` | 2618899 | 14694925 |
| `vulkan-panfrost-1:26.2.4-1.5-aarch64.pkg.tar.zst` | 2700902 | 16625148 |
| `vulkan-mesa-implicit-layers-1:26.2.4-1.5-aarch64.pkg.tar.zst` | 55846 | 204260 |

**Baseline** (unpatched upstream PKGBUILD, same image and script)
[V: log `~/orca/build-out/mesa-freedreno/logs/baseline-20261117T102916.log`,
packages in `out-baseline/`]: `mesa-1:26.2.4-1.4` is 6320589 bytes,
installed 25728446; makepkg 3 min 49 s; it has no `msm_dri.so`.

**Cost for a Mali phone**: `mesa` grows by 844883 bytes compressed
(+13.4 %) and 2312512 bytes installed (+9.0 %), nearly all of it in
`libgallium` (24425496 -> 26726504). `vulkan-panfrost` is unchanged in
content (111 bytes difference in the archive). The build takes about one
minute longer.

The first attempt (`logs/build-20261117T101953.log`) failed before
makepkg: `chown: invalid spec: 'builder:'`, because uid 1000 belongs to the
tarball's `alarm` user. The script now deletes that user first, as
upstream's `tools/lib/alarm-setup` does.

Not covered by this proof: running anything on an Adreno. That is §7
steps 4-6.

## 6. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Bigger `mesa` for every phone | freedreno's Gallium code is linked into the shared `libgallium-*.so` | Measured in §5; Mali phones pay only that delta |
| Mali regression | Same source, same patches, only extra drivers. A build-system change could still touch shared code | All ten panfrost patches still apply with `--fuzz=0` in the build [V: §5]; one Mali smoke test (G710 or G715) before release |
| Longer build | Turnip and freedreno's compiler (ir3) | Build time in §5 |
| Adreno 650 on 26.2.4 | ALARM proof was 26.2.7 | §7 step 4: `eglinfo`/`vulkaninfo` before the session switch |
| Hyprland GPU faults | flame's FD640 rendered EGL but Hyprland faulted on CCU [V: upstream `device/flame/GPU-PLAN.md:36-41`] | env.d has a manual fallback: `LIBGL_ALWAYS_SOFTWARE=1` in `~/.config/uwsm/env-hyprland`, as today |
| Wrong driver name in env.d | Hardware never selected; desktop stays on llvmpipe (safe direction) | Open question 1 |
| ALARM `vulkan-freedreno` drift | ALARM's version wins if `[omamobile]` is not first | Same as `vulkan-panfrost` today: repo order and `IgnorePkg` |

## 7. Runbook (phone steps are the owner's; none write a partition)

1. Upstream PR (owner decision): the PKGBUILD patch plus the README and
   `.SRCINFO` follow-ups from §2.
2. Build in the ALARM container (§5) or with `tools/build-packages`.
3. `adb push` `mesa`, `vulkan-freedreno` and `vulkan-mesa-implicit-layers`
   (1.5) to the phone; `sudo pacman -U` them. Rollback: `sudo pacman -U` the 1.4
   packages from the pacman cache.
   Expect: `pacman -Q mesa` = `1:26.2.4-1.5`; `ls /usr/lib/dri/msm_dri.so`.
4. Offscreen check before touching the session:
   `eglinfo -B` (GBM platform) and `vulkaninfo --summary`.
   Expect: renderer `FD650`, Vulkan device `Turnip Adreno (TM) 650`
   [I: from the `Turnip Adreno (TM) %s%s` format string in the build].
   Stop: anything else, or a GPU fault in `dmesg`.
5. `readlink /sys/class/drm/renderD128/device/driver`. Expect one of the
   names in §4; otherwise fix the case list before step 6.
6. Install the env.d file to `/usr/share/uwsm/env.d/`, remove the
   `LIBGL_ALWAYS_SOFTWARE=1` line from `~/.config/uwsm/env-hyprland`,
   restart the session (announce it: the screen goes black).
   Expect: Hyprland's log names `FD650`; `hyprctl systeminfo` likewise.
   Stop: compositor abort or msm hang in `dmesg`. Rollback: put the line
   back and restart the session.

## 8. Open questions

1. The exact sysfs driver name behind `renderD128` on K3 (step 5).
2. Does Mesa 26.2.4 render FD650 as 26.2.7 did? (step 4)
3. Upstream: one `mesa` for all phones (this plan) or a separate Qualcomm
   build? This plan assumes one, on the size delta in §5.
4. Should coral and flame move from Arch's Mesa to the omamobile build
   once freedreno is in it? Their maintainers decide.
