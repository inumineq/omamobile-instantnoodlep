<!-- SPDX-License-Identifier: MIT -->
# WAYDROID-PLAN: Android apps (banking/e-ID) in a Waydroid container on instantnoodlep

House-rule-6 gate for the **Waydroid** subsystem (issue #195). Date:
2026-11-25. Branch: `inumineq/w1-waydroid`. Status: **plan + kernel fragment
written and compile-checked offline; no phone was accessed, nothing is
flashed, no owner gate has run.** Every phone command below is a gated
runbook step for the owner (AGENTS.md rule 1): exact command, Expect, Stop,
Rollback.

Evidence labels per AGENTS.md: **[V]** checked with a source (file:line or
URL), **[I]** inference still to confirm on the device or in a build.

Reading order: `AGENTS.md`, `docs/agents/state.md`,
`KERNEL-SIZE.md`, `kernel-slim.config`, `kernel-slim-typec.config`,
`docs/runbooks/SLIM-FEAT-RUNBOOK.md`, upstream
`device/cheetah/WAYDROID-PLAN.md` and `packages/omamobile-waydroid`.

## 1. Problem and current state

- Banking, national-ID and authenticator apps are the hardest leave-Android
  blockers (issue #195). Upstream ships Waydroid on cheetah and passed its
  W2-W5 gates there; `MULTI_WINDOWS=false` is the working mitigation for the
  SurfaceFlinger crash storms of upstream #767 [V: upstream issue #767,
  2026-11-14 and follow-up comment].
- Nothing existed for instantnoodlep before this plan: zero `waydroid`
  mentions under `device/` and `docs/` (issue #195, re-checked 2026-11-25),
  and no `ANDROID`/`BINDER`/`ASHMEM` lines in the pre-existing fragments
  `kernel.config`/`kernel-slim.config` (only `~/android/build` path
  comments) [V: `grep -n -i 'binder\|ashmem\|android'
  device/instantnoodlep/kernel.config device/instantnoodlep/kernel-slim.config`,
  2026-11-25]. The merged `.config` state is resolved by the offline
  compile-check in §2.4 [V: `tests/instantnoodlep-waydroid` output].
- The booting base is slim K3 (`image_size` 0x1720000, ceiling 0x2b60000)
  [V: `docs/agents/state.md` slim K3 row; `KERNEL-SIZE.md` §1]. Daily K3
  is on `boot_b` [V: `docs/agents/state.md` "The phone right now"].

## 2. Kernel: binder/binderfs as a new fragment (the W1 candidate)

### 2.1 Why a new fragment file

`kernel-slim.config` is owned by the daily-kernel line and is not edited
here (issue #195 scope). Feature deltas live in their own files on top of
the slim `.config` — the `kernel-slim-typec.config` pattern — and the
candidate is built in the PR #108 pattern: slim base + one fragment, as a
RAM-boot candidate with modules on the rootfs [V:
`docs/runbooks/SLIM-FEAT-RUNBOOK.md` header and candidate table].

### 2.2 The fragment: `device/instantnoodlep/kernel-slim-waydroid.config`

Contents and why:

- **Binder + binderfs, built in.** `ANDROID_BINDER_IPC` and
  `ANDROID_BINDERFS` are **bool** in the 7.3.0-rc6 tree (depend on `MMU &&
  NET`), so they cannot be modules and must be `=y` [V:
  `drivers/android/Kconfig:4-42` in the omamobile 7.3.0-rc6 tree]. Devices
  string stays at the default `binder,hwbinder,vndbinder`; the Rust binder
  stays off [V: same file; upstream `kernel/configs/omamobile.config:23-27`].
- **ashmem is gone from mainline.** No `ASHMEM` symbol exists anywhere in
  the 7.3.0-rc6 tree [V: `grep -rn ASHMEM --include='Kconfig*'
  --include=Makefile` over the tree, 2026-11-25]. Android 13 falls back to
  memfd when `/dev/ashmem` is missing, so the fragment sets
  `MEMFD_CREATE=y` instead [V: upstream WAYDROID-PLAN §1 table].
- **PSI=y** — lmkd needs `/proc/pressure/memory` or Android's init reboots
  the container [V: upstream WAYDROID-PLAN §1].
- **`IKCONFIG`/`IKCONFIG_PROC=y`** so the W0/W2 check can read
  `/proc/config.gz` [V: upstream `packages/omamobile-waydroid` check lib;
  `kernel/configs/omamobile.config:33-34`].
- **`SYNC_FILE=y`** for Android's HWC; `SW_SYNC` stays off (Waydroid binds
  `/dev/sw_sync` only if it exists) [V: upstream WAYDROID-PLAN §1.1].
- **Container prerequisites pinned as modules** so the base cannot drop
  them: `BRIDGE=m`, `VETH=m`, `TUN=m`, `OVERLAY_FS=m`, `FUSE_FS=m`.
- **Android netd's legacy iptables set**, mirroring upstream's W1 block:
  routing options and `NETFILTER_XTABLES_LEGACY` built in (they change
  `struct net`), the filter/mangle/raw/nat tables, matches and targets as
  `=m` [V: upstream `kernel/configs/omamobile.config` "Waydroid
  (device/cheetah/WAYDROID-PLAN.md W1)" block]. The host keeps using
  nf_tables only; `iptables-legacy` is never run on the host [V: upstream
  WAYDROID-PLAN §1.1]. `NET_SCHED=y` + `NET_CLS_ACT=y` are re-enabled
  because slim turns `NET_SCHED` off and the BPF classifier/action symbols
  sit inside `if NET_SCHED` [V: `net/sched/Kconfig:44-966`;
  `kernel-slim.config` "Unused network extras"]; the classifiers themselves
  stay `=m`.
- Left off, as upstream: `SW_SYNC`, `UHID`, `USERFAULTFD`, `CGROUP_NS`,
  Rust binder [V: upstream WAYDROID-PLAN §1.1].

### 2.3 Size vs the ABL ceiling

Only `=y` symbols grow the arm64 header `image_size` that ABL checks;
`=m` objects stay modules [V: `kernel-slim.config` header;
`KERNEL-SIZE.md` §1]. The ceiling is **0x2b60000** (0x2b70000 hangs in ABL),
target ≤ 0x2560000; slim K3 boots at **0x1720000** [V: `KERNEL-SIZE.md` §1,
`docs/agents/state.md` slim K3 row], so the headroom is about
**0x1440000 (~20 MiB)**. The fragment's built-ins (binder core, PSI, memfd,
routing options, legacy xtables core, `NET_SCHED` gate, IKCONFIG) are far
inside that; the exact merged `image_size` is measured at build time before
any RAM boot — hard stop above 0x2b60000 [V: `KERNEL-SIZE.md`].

### 2.4 Offline compile-check (done in this PR, x86, no phone)

`tests/instantnoodlep-waydroid` runs, on the omamobile 7.3.0-rc6 tree:

1. `make ARCH=arm64 O=<tmp> defconfig`, then
   `scripts/kconfig/merge_config.sh -m` with `kernel.config` +
   `kernel-slim.config` + `kernel-slim-waydroid.config` (in that order),
   then `make olddefconfig`;
2. asserts **every line of the fragment resolves in the merged `.config`
   as written** (76/76 on 2026-11-25) [V: test run, this PR];
3. compiles the new built-in code: `make ARCH=arm64 LLVM=1
   drivers/android/` with clang 23.1.3 — `binder.o`, `binderfs.o`,
   `binder_alloc.o`, `binder_netlink.o`, rc=0 [V: test run, this PR].

The merged `image_size` is **not** measured here (no full `Image` build on
this host) [I]; the build step in §2.5 measures it.

### 2.5 Candidate build recipe (owner/coordinator, offline first)

Mirror the PR #108 candidates [V: `docs/runbooks/SLIM-FEAT-RUNBOOK.md`]: branch
`instantnoodlep-k3-slim-waydroid` on the slim base `78f38a2acc99` in
`inumineq/linux-omarchy-mobile`, config = slim `.config` (from
`~/android/build/k3-slim/.config`) + the fragment + `olddefconfig` with
`O=~/android/build/k3-slim-waydroid`, built with clang 23 only (Debian
clang 19 freezes on the splash — learning `l-e03ff7fe` [V:
`docs/runbooks/SLIM-FEAT-RUNBOOK.md` header]), `make ARCH=arm64 LLVM=1
Image.gz dtbs modules`, `LOCALVERSION` pinned to
`-instantnoodlep-k3-slim-waydroid`, `image_size` read with
`od -An -tx8 -j16 -N8 Image` and checked against 0x2b60000, RAM image built
with `tools/build-instantnoodlep-probe` with the daily-manifest flags, plus
a modules tarball (`INSTALL_MOD_STRIP=1`) and `SHA256SUMS` beside the image.

## 3. Images (W3): VANILLA system + vendor from the owner's own device

- instantnoodlep (OnePlus 8 Pro) is LineageOS-supported, models **IN2023 and
  IN2025** [V: https://wiki.lineageos.org/devices/instantnoodlep, fetched
  2026-11-25].
- Waydroid's OTA channels are **arch-generic** (`waydroid_arm64`), not
  per-device [V: `waydroid/ota` repo layout:
  `system/lineage/waydroid_arm64/{VANILLA,FOSS,GAPPS}.json`,
  `vendor/waydroid_arm64/MAINLINE.json`, …]. This resolves the issue's
  "[I: ota.waydro.id images for instantnoodlep]": no instantnoodlep-specific
  images exist; the arm64 VANILLA system image is the right one for any
  arm64 mainline device.
- **Pinned system image (name + sha256 only; the image itself never enters
  git):** `lineage-20.0-20260927-VANILLA-waydroid_arm64-system.zip`,
  sha256 `5fb8179ed4455f45919c5a2bfbfdd1591619295994ad321217f03bb1dcfc53a7`,
  912,267,974 bytes, channel datetime 1790477549 [V:
  `waydroid/ota` `system/lineage/waydroid_arm64/VANILLA.json`, newest entry,
  fetched 2026-11-25; the same image is the newest VANILLA on ota.waydro.id
  in upstream #767, 2026-11-14].
- **Vendor image: from the owner's own device** (AGENTS.md rule 8 — no
  proprietary blobs in git): extracted at install time from the owner's own
  LineageOS instantnoodlep build or his own factory image, placed as
  `vendor.img` under `/var/lib/waydroid/images`; its name and sha256 are
  recorded in the runbook at W3, never committed. Fallback, pinned the same
  way: the generic MAINLINE vendor `lineage-20.0-20261022-MAINLINE-waydroid_arm64-vendor.zip`,
  sha256 `89d5fb9a5c977adcc9fc7755483d3762c397b9c8579524f9d1df052b51c83fb3`
  [V: `waydroid/ota` `vendor/waydroid_arm64/MAINLINE.json`, newest entry,
  fetched 2026-11-25; same image as upstream #767] — but the owner's-device
  vendor is preferred because it matches this phone's HALs [I].
- **VANILLA only** (no GAPPS; upstream decision 2026-11-24) [V: upstream
  WAYDROID-PLAN §2]. About 1 GB on `userdata`; `df -h /var` first
  [V: upstream WAYDROID-PLAN §2]. Waydroid verifies the download against
  the channel's sha256 itself [V: waydroid `tools/helpers/images.py`].
- Known VANILLA gap from upstream #767: missing modern root CAs (e.g.
  GlobalSign Root E46) break TLS logins (net_error -202); fix is a
  `/var/lib/waydroid/overlay/system/etc/security/cacerts/` overlay [V:
  upstream #767 follow-up comment]. Optional W6 step.

## 4. GPU: rootfs freedreno Mesa + the vendor image's driver on renderD128

- Host side already works: msm DRM binds, the Adreno 650 reports
  `gpu-initialized: 1`, `/dev/dri/renderD128` exists, and Hyprland runs on
  the GPU [V: `docs/agents/state.md` M3 row; `docs/STATUS.md` GPU row]. The
  rootfs carries **Mesa 26.2.4-1.5 with freedreno + Turnip** from
  `inumineq/gpu-mesa-freedreno` (rollback files on the phone) [V:
  `docs/agents/state.md` "The phone right now"].
- Waydroid binds `/dev/dri/renderD128` into the container and Android
  renders with the **vendor image's** gbm gralloc + Gallium driver on that
  same render node [V: upstream WAYDROID-PLAN §3]. The a650 row is standard
  upstream freedreno, so a LineageOS vendor Mesa should have it [I — verify
  at W5 via `waydroid shell dumpsys SurfaceFlinger | grep GLES`; expect an
  FD650/Adreno string, not llvmpipe]. If the row is missing, apply the
  upstream §3 overlay pattern: patch the product-ID row in the image's
  `libgallium_dri.so` (via debugfs) and write it to
  `/var/lib/waydroid/overlay/vendor/{lib64,lib}/`, redo after every vendor
  update [V: upstream WAYDROID-PLAN §3].
- **Vulkan inside Android: GLES only.** Waydroid's kernel-driver→ICD map
  has no `msm`/kgsl entry [I, pattern V: upstream WAYDROID-PLAN §3 panthor
  note]. Fine for banking/e-ID apps.
- Dependency: any **upstream-installable** GPU story (freedreno in the
  omamobile Mesa package) waits on backlog item B-16 / the
  `inumineq/gpu-mesa-freedreno` upstream PR [V: `docs/agents/state.md` Next
  step 1]. Until that lands, the local rootfs Mesa is what Hyprland uses;
  Waydroid's GPU path does not depend on it (it uses the vendor image's
  Mesa on the kernel render node).

## 5. Networking, ufw and hardening (adapted from upstream §4-§5)

- `waydroid-net.sh` makes bridge `waydroid0` (192.168.240.1/24), runs
  dnsmasq, enables `ip_forward`, masquerades out of the default route (Wi-Fi
  now) using nft (`LXC_USE_NFT="true"`) [V: upstream WAYDROID-PLAN §4]. No
  conflict with USB networking 172.16.42.0/24 [V: upstream §4; this repo's
  runbooks ssh to `root@172.16.42.1`].
- ufw stays on with DROP forward; add the three rules (`allow in on
  waydroid0` ports 67/53, `ufw route allow in on waydroid0`) under a
  dead-man switch so SSH over usb0 survives [V: upstream WAYDROID-PLAN §4
  and W3]. Nothing is opened towards Android from outside.
- **Hardening must be in place before W4** (port of upstream
  `packages/omamobile-waydroid`; until the package is ported, run its steps
  by hand): strip the debugfs, `/dev/video*` and `/dev/fb*` binds from
  Waydroid's `lxc.py`/`container_manager.py` via the pacman hook; drop such
  lines from the generated `config_nodes`; append
  `lxc.include = .../lxc-omamobile.conf` last; the include allows the
  standard character nodes and the binderfs nodes by path and denies every
  block device (`lxc.cgroup2.devices.deny = b *:* rwm`); `verify` refuses a
  container start if any hand-written device allow line exists [V: upstream
  WAYDROID-PLAN §5]. On instantnoodlep this is not paranoia: `/dev/video*`
  are the camera CSIS/sensor nodes [V: `CAMERA-PLAN.md`], and the storage
  guard (never write `super`/`_a`, AGENTS.md rule 3) must stay unreachable
  from a privileged container [V: upstream WAYDROID-PLAN §5 item 3].
- Watch item: with no LSM implementing `secid_to_secctx`, binder may log
  "failed to get security context"; LineageOS-for-Waydroid images boot
  without SELinux/AppArmor, so the service manager evidently does not
  depend on it [V: upstream WAYDROID-PLAN §6.3].
- Sound reaches Android only through PipeWire's PulseAudio socket (no
  `/dev/snd` bound); sensors are stubbed (no `waydroid-sensord`) [V:
  upstream WAYDROID-PLAN §5].

## 6. Owner-gated RAM-first runbook (upstream W2-W5 + #767, adapted)

RAM-first order, unlike upstream's push-then-boot: the kernel candidate is
**RAM-booted first** (`fastboot boot`, nothing written to flash), and only
a passing W1-W5 candidate may later be considered for `boot_b` — and only
after the power note in §7. Roles per AGENTS.md rule 1: the owner runs or
explicitly approves every phone step; `fastboot boot` is RAM-only and
allowed, anything that writes flash is not in this plan at all. Phone access
in this repo is `ssh root@172.16.42.1` over USB NCM and `fastboot` from the
laptop [V: `docs/runbooks/DAILY-K3-RUNBOOK.md` Part R]. Before every step,
record `uname -r` [V: upstream WAYDROID-PLAN §8].

### W0 — read-only kernel check on the current daily kernel (coordinator may run; risk none)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W0 | Phone: `zgrep -E 'ANDROID_BINDER_IPC|ANDROID_BINDERFS|MEMFD_CREATE|PSI|NETFILTER_XTABLES_LEGACY' /proc/config.gz` | all `n`/absent — the daily base has none of the fragment [V: §2.4 compile-check] | any of them `=y`/`=m` (different kernel than expected) | none (read-only) |

### W1 — first owner gate: RAM boot of the slim+waydroid candidate (specified, NOT run)

Build per §2.5 first (offline): rc=0, `image_size` ≤ 0x2560000 target and
hard stop > 0x2b60000 [V: `KERNEL-SIZE.md`], `CHECK_DTBS=y` clean, config
diff vs the slim `.config` shows only the fragment's symbols.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W1.0 | Laptop: `sha256sum -c` on the candidate image dir; push the modules tarball, on the phone `tar --zstd -xf ... -C /usr/lib/modules && depmod $REL`, pin the release in `/usr/lib/modules/.omamobile-pinned` | hashes OK; new modules dir only; pinned [V: DAILY-K3-RUNBOOK R0.1-R0.2b] | any mismatch; tar lists a path outside `$REL/` | `rm -rf /usr/lib/modules/$REL` |
| W1.1 | Owner: `systemctl reboot --reboot-argument=bootloader`; laptop: `fastboot getvar current-slot slot-successful:b slot-unbootable:b slot-retry-count:b`; record | `b`, `yes`, `no`, retry count recorded [V: DAILY-K3-RUNBOOK R0.4] | anything else | `fastboot reboot` |
| W1.2 | Laptop: `fastboot boot ~/android/build/k3-slim-waydroid-ram/boot-slim-waydroid.img` (RAM only); SSH within 2 min; `uname -r`; `systemctl is-system-running` | `Booting OKAY`; `uname -r` = `7.3.0-rc6-instantnoodlep-k3-slim-waydroid...`; `running` | `FAILED`; no SSH after 2 min; `degraded` with a unit the daily does not fail | owner holds Power+VolUp 10-30 s; daily K3 boots from `boot_b` [V: DAILY-K3-RUNBOOK R1] |
| W1.3 | Phone (read-only): `zgrep -E 'ANDROID_BINDER_IPC|ANDROID_BINDERFS|MEMFD_CREATE|PSI|NETFILTER_XTABLES_LEGACY|IP_NF_IPTABLES_LEGACY' /proc/config.gz`; `dmesg \| grep -i binder \| tail`; `ls /sys/fs/binderfs 2>/dev/null`; run DAILY-K3-RUNBOOK Part R checks R2-R8 (panel, touch, GPU GL on renderD128 with `drm-driver: msm`, Wi-Fi, BT, gauge, regression diff) | binder/binderfs/memfd/PSI/legacy `=y`, `IP_NF_IPTABLES_LEGACY=m`; binder in dmesg without errors; all Part R checks pass exactly as on slim/daily | any oops; any `ufshcd_err_handler`; binder errors repeating; any Part R check fails | `reboot` (back to daily from `boot_b`) |
| W1.4 | Owner: `systemctl reboot --reboot-argument=bootloader`; the four slot vars; `fastboot reboot` | fastboot reached; vars equal to W1.1 | slot vars changed | stop, record, ask the owner |

**Pass condition for W1 (not yet run):** W1.0-W1.4 all pass. This is the
first owner gate; it is specified here but deliberately not executed in this
PR.

### W2 — install (owner gate; risk low)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W2 | Phone: `pacman -S --needed waydroid lxc nftables dnsmasq e2fsprogs` (Arch Linux ARM extra; `waydroid 1.6.3-1` is `any` arch so ALARM builds it as is [V: upstream WAYDROID-PLAN §1]); install the ported `omamobile-waydroid` package (port is later work; until then run its hardening steps by hand per §5); `omamobile-waydroid check`; `systemctl is-enabled waydroid-container` | check passes its kernel part now (W1 ran) and says Waydroid isn't initialized; service `disabled` — if Arch enables it, `systemctl disable --now waydroid-container` | the hardening hook reports "expected text not found" (a Waydroid newer than 1.6.3) | `pacman -R omamobile-waydroid waydroid` [V: upstream W2] |

### W3 — images and hardening (owner gate; risk low; ~1 GB over Wi-Fi)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W3.1 | Phone: `df -h /var` | ≥ 4 GB free | less | stop |
| W3.2 | Phone: `omamobile-waydroid init` (or `waydroid init -s VANILLA`), which downloads the pinned system image of §3 and verifies its sha256 against the channel [V: waydroid `tools/helpers/images.py`]; then place the owner's-device `vendor.img` per §3 (record name+sha256 locally, never in git) | images verify; `/var/lib/waydroid/images` holds system+vendor | hash mismatch; wrong vendor source | `rm -rf /var/lib/waydroid` (images and config only) [V: upstream W3] |
| W3.3 | Phone: `grep -E 'video\|fb[0-9]\|kernel/debug' /var/lib/waydroid/lxc/waydroid/config_nodes`; `tail -1 /var/lib/waydroid/lxc/waydroid/config` | grep prints nothing; last line is the `lxc.include` of `lxc-omamobile.conf` [V: upstream W3] | any bind line survives | fix hardening before W4; never start the container |
| W3.4 | Firewall under a dead-man switch: `systemd-run --unit=x-deadman --on-active=90 /usr/bin/ufw disable && omamobile-waydroid firewall on && ufw status`; from a fresh SSH login `systemctl stop x-deadman.timer` | ufw shows the three waydroid0 rules; SSH over usb0 still up; `sysctl net.ipv4.ip_forward` = 1 | SSH dies and the dead-man fires | `ufw disable` from the fresh login; rollback = previous ufw rules [V: upstream W3] |

### W4 — the container, no Android UI yet (owner gate; risk medium)

Stream the kernel log first: `dmesg -w | tee` on the laptop [V: upstream W4].

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W4.1 | Phone: `systemctl start waydroid-container; sleep 5; systemctl --no-pager status waydroid-container \| head -5; ls -l /dev/binderfs; waydroid status` | service active (its `ExecStartPre` check/harden/verify passed); `binder`, `vndbinder`, `hwbinder` in `/dev/binderfs` | service fails; binderfs nodes missing | `systemctl stop waydroid-container` |
| W4.2 | Phone, inside the container (`lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh -c "export PATH=/system/bin:$PATH; ..."`): `toybox mknod /dev/omtest b 7 0; echo rc=$?; toybox rm -f /dev/omtest` and `toybox mknod /dev/omtest2 c 1 1; echo rc=$?; toybox rm -f /dev/omtest2`; `toybox ls /sys/kernel/debug /dev \| toybox head` | both mknod lines print `Operation not permitted` (that line is the pass condition); `/sys/kernel/debug` empty or missing; no `video*`/`fb*` in the container's `/dev` [V: upstream W4] | **either mknod succeeds**: stop the container at once, fix the device rule, never read/open the node (major 1 minor 1 is /dev/mem; reading it could crash the phone) | `systemctl stop waydroid-container` |
| W4.3 | Phone: `dmesg \| grep -iE 'oops\|ufshcd_err_handler\|binder.*(err|security context)' \| tail` | nothing repeating | any oops; ufshcd error; binder errors repeating | `systemctl stop waydroid-container` |

### W5 — Android boots, GPU and network (owner gate; risk medium)

Announce: the Android UI appears in a window on the phone's screen.

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| W5.1 | Phone, as the session user: `XDG_RUNTIME_DIR=/run/user/<uid> WAYLAND_DISPLAY=wayland-1 waydroid session start &`; `sleep 90; waydroid shell getprop sys.boot_completed` | `1` within about two minutes | not `1` after 3 min | `waydroid session stop; systemctl stop waydroid-container` |
| W5.2 | `waydroid shell dumpsys SurfaceFlinger \| grep -m2 -E 'GLES|llvmpipe'` | an FD650/Adreno GLES string, **not** llvmpipe (§4) | llvmpipe → the vendor Mesa row is missing; apply the §4 overlay, else the software fallback `ro.hardware.gralloc=default`/`ro.hardware.egl=swiftshader` to separate GPU from the rest [V: upstream §3] | session restart |
| W5.3 | `waydroid shell ping -c 3 1.1.1.1; waydroid shell ping -c 1 example.com` | both answer (netd path of §2.2 works) | no route: `waydroid shell dumpsys connectivity \| grep 'Active default network'` says `none` [V: upstream §4/#767] | session restart; check the W1 legacy modules loaded |
| W5.4 | `dmesg \| grep -iE 'adreno.*(fault\|timeout)\|oops\|binder.*security context' \| tail` | clean | GPU faults or oops repeating | session stop, container stop |

### W5b — the #767 mitigation, adapted (decide at W5/W6, record which)

- Upstream #767: SurfaceFlinger SIGSEGV ~6/hour, every crash closes all
  Android windows and can kill Android's network until a session restart;
  crashes line up with window open/move/maximize (display hotplug storms)
  [V: upstream #767]. `MULTI_WINDOWS=false` stopped the crashes there [V:
  upstream #767], **but** the follow-up found single-window mode breaks
  touch for every Android window but the first [V: upstream #767 comment
  2026-11-14]. Switching modes needs all four places to agree:
  `/etc/omamobile/waydroid.conf` + `omamobile-waydroid props` (regenerates
  `waydroid_base.prop`) + `[properties]` in
  `/var/lib/waydroid/waydroid.cfg` + `waydroid prop set` [V: upstream #767
  comment].
- Decision for instantnoodlep: start with `MULTI_WINDOWS=true` (default
  [V: upstream `etc/omamobile/waydroid.conf`]); if W6 shows SurfaceFlinger
  crashes, apply the four-place switch to `false` and re-test touch; also
  never tile two Android windows on one workspace and give each its own
  (`omamobile-launch own-screen`) — two tiled windows shrink `wm size` for
  every app [V: upstream #767]. Shell rules for `waydroid.*` windows,
  KEY_BACK from the back gesture, and the keyboard bridge are W8
  integration work [V: upstream WAYDROID-PLAN §6].

### W6-W8 (later, owner/coordinator; summarized)

- **W6 apps as phone apps:** F-Droid via signed APK [V: upstream W6], then
  the banking/e-ID/authenticator apps; launcher entries appear as
  `waydroid.<package>` with `X-WayDroid-App` [V: upstream §6.1]; optional
  CA overlay (§3). Stop: Android restarting more than once in ten minutes.
- **W7 power:** drain measurement with and without a session — see §7.
- **W8 integration:** back gesture sends `KEY_BACK` (hold ~80 ms) to
  `waydroid.*` windows; each Android window on its own workspace;
  keyboard bridge; quick-settings container switch [V: upstream §6, W8].

## 7. Power note: Waydroid's battery cost before anything reaches `boot_b`

- Waydroid freezes the container when no Android window is visible
  (`suspend_action=freeze`, keep the default for now) [V: upstream
  WAYDROID-PLAN §6.3], and Android's alarms cannot wake the phone from the
  container [V: same]. The cost of a running session on this phone is
  **unmeasured** [I].
- Screen-off draw today is 360 mA — the SoC never reaches deep idle yet
  [V: `docs/STATUS.md` Suspend row]. Gate: before any Waydroid-enabled
  kernel is flashed to `boot_b`, the power program's measurements (its own
  track — this plan only declares the dependency, no work inside it) must
  include a Waydroid session alongside the screen-off floor, and W7 must
  have recorded drain with no Waydroid / frozen container / active session
  [V: upstream WAYDROID-PLAN W7 shape]. Until then Waydroid stays a
  RAM-boot-only candidate.

## 8. Done-when mapping (issue #195)

1. Plan with pinned image names (names/hashes only), fragment, gated
   runbook — this file: §3 (pins), §2.2 (fragment), §6 (runbook). Done in
   this PR.
2. Fragment compile-checks against slim K3 offline — `tests/instantnoodlep-waydroid`:
   merge + `olddefconfig` on 7.3.0-rc6 resolves all 76 fragment lines as
   written, and `drivers/android/` compiles with clang 23.1.3 rc=0 [V: test
   run 2026-11-25, this PR]. The merged `image_size` itself is measured at
   the W1 build (§2.5) [I].
3. First owner gate specified but not run — W1 in §6. Done in this PR.

## 9. Results

None. No phone was accessed; nothing was flashed; no gate ran.

## 10. Dependencies and out of scope

- B-16 (upstream-installable freedreno Mesa) for the host GPU packaging
  story; Waydroid itself uses the vendor image's Mesa on the kernel render
  node (§4) [V: issue #195; `docs/agents/state.md` Next step 1].
- The power program track owns battery measurements; §7 only adds a
  Waydroid-session case to its gate.
- Porting `packages/omamobile-waydroid` (hardening, check, mesa overlay,
  props, firewall) to this repo is a separate later task; until then §5
  runs its steps by hand [V: upstream package layout].
- Camera inside Android (v4l2loopback/PipeWire bridge) is later work; the
  camera nodes stay hidden from the container [V: upstream WAYDROID-PLAN
  §6.3; `CAMERA-PLAN.md`].
