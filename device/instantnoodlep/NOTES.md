<!-- SPDX-License-Identifier: MIT -->
# NOTES: instantnoodlep (OnePlus 8 Pro, IN2023)

Newest first. Findings that matter beyond one subsystem go here; subsystem
detail lives in the *-PLAN.md files.

## 2026-11-17 (night, latest): K3 RAM boots: touch and panel bind, dtbo root rewrite

- [V] K3 = K2 + touch (s6sy761 @0x48 on i2c13) + AMS678UW01 panel
  driver and DSI/MDSS enablement, kernel `7.3.0-rc6-instantnoodlep-k3`,
  RAM-booted only (`fastboot boot`, after `systemctl reboot
  --reboot-argument=bootloader`; no flash write). Every display/touch
  driver is built in because the K2 rootfs modules do not match K3.
- [V] Touch: `input: s6sy761 as .../i2c-13/13-0048/input/input0`; first
  input device on this phone. Taps not yet tested (needs a finger).
  The stock overlay lists both `s6sy791_19811@48` and `synaptics_20828@4B`;
  the 8 Pro part is the Samsung one (1440x3168, project 19811).
- [V] Panel: `panel-samsung-ams678uw01 ae94000.dsi.0: using mode
  1440x3168@120`, msm 1.13.0 bound, `card1-DSI-1` connected 1440x3168,
  backlight `ae94000.dsi.0` max 2047, Hyprland runs on DSI-1 (scale 3) with
  no "pp done" timeouts. Whether the picture is correct needs eyes on it.
- [V] Needed built in beyond the plan: `REGULATOR_QCOM_REFGEN` (DSI waits
  for the `refgen` supply) and `INTERCONNECT_QCOM_OSM_L3` (qcom-cpufreq-hw
  waits for icc paths; with it cpufreq runs).
- [V] The stock dtbo rewrites the DTB root: under `fastboot boot` the live
  root compatible is `qcom,kona-mtp qcom,kona qcom,mtp`, so tables keyed
  on `qcom,sm8250` miss (UBWC: msm-mdss -EINVAL; also pd-mapper, cpufreq-dt
  blocklist). K3 carries a test-only `qcom,kona` patch; the fix is a
  neutral `dtbo_b`, see DTBO-PLAN.md (needs an owner go).
- [V] Phone `dtbo_b` is byte-identical to the OTA `dtbo.img` (full
  partition), so the rollback image is on disk.
- Screen kept off (DPMS) between tests to spare the AMOLED.

## 2026-11-17 (night, earlier): network, time, device package 0.0.3, screen

- [V] Network without sudo on the laptop: NetworkManager "shared" mode
  needs `dnsmasq` (not installed) and ufw drops forwarding, so instead a
  reverse SSH SOCKS tunnel: `ssh -N -R 127.0.0.1:1080 root@172.16.42.1`
  gives the phone `socks5h://127.0.0.1:1080` (curl to archlinux.org: 200
  in 0.24 s). No UDP, so no NTP: the clock is set over SSH with
  `date -u -s @$(date -u +%s)`. The RTC came up at 1970/2026-01-02, so
  time is lost on every boot until NTP or an RTC fix.
- [V] The two failed firstboot steps are Windows-on-ARM laptop steps
  (`hardware/qualcomm/dtb-uki.sh`: a UKI with X1/sc8280xp DTBs;
  `firmware.sh`: firmware from a Windows partition), gated only on
  `omarchy-hw-aarch64-qualcomm`. They must not run on a phone; not re-run.
  Upstream note: omamobile-firstboot does not skip them on Qualcomm phones
  (dodge would hit this too).
- [V] Pacman on the phone refused the local repository DB ("key
  653B6B58... is unknown"): the image is built `--channel local` but the
  local build key is not in its keyring. Fixed on the phone with
  `pacman-key --add` + `--lsign-key` of `keys/instantnoodlep/public.asc`.
  `omamobile-device-instantnoodlep` 0.0.3 (usb0 network files, the
  `systemd-firstboot` mask) then installed with `pacman -U` and owns those
  files. No `-Syu` against upstream's channel (it would mix their packages
  into our local build).
- [V] Screen: `simpledrm` provides `card0`/`fb0`; SDDM autologged in and
  started Hyprland (uwsm), but the panel stays black. The earlier console
  text came from tty0 on the same framebuffer. Cause open (Hyprland on
  simpledrm, or the panel sleeping once the bootloader image is replaced):
  M3.
- [V] Stock DTBO entry 16, applied by the bootloader on every boot, rewrites
  the live root compatible to `qcom,kona-mtp`, `qcom,kona`, `qcom,mtp`.
  This was observed in the live DT on 2026-11-17; the M1a overlay experiment
  already recorded the merged root-compatible behavior (see the 2026-11-16
  P3/P4 entry below). It makes root-machine tables keyed on `qcom,sm8250`
  miss: `drivers/soc/qcom/ubwc_config.c` machine matching causes `msm-mdss`
  probe to fail with `-EINVAL`; source inspection confirms the same match
  issue in `qcom_pd_mapper.c` and the SM8250 entry in
  `cpufreq-dt-platdev.c`. Use a neutral DTBO on `dtbo_b` before M3/M5 RAM
  boots; the image must be prepared under the existing owner-gated slot-B
  write rules. The public Nura package builds and installs its own empty
  `dtbo.img` (`device/testing/device-oneplus-instantnoodlep/APKBUILD`,
  `kernel_mainline()`), corroborating the approach.

## 2026-11-17 (night, later): M1b B4-B5 — slot B marked, M1b complete

- [V] B4: `systemctl reboot --reboot-argument=bootloader` reaches
  fastboot in 6 s. Retry count after the first Linux boot: 7 -> 6; a
  fastboot visit costs none; the next Linux boot came up unattended (SSH
  at 15 s, `running`, no failed units).
- [V] B5 (owner go; local exception to house rule 3, not covered by
  upstream CONTRIBUTING §3.1): `tools/instantnoodlep-slot-b-mark` built
  the four sectors from a fresh read (attributes 0x002f... -> 0x006f...;
  1 byte per array sector, 8 per header). Pre-check disk == originals,
  one-off `blockdev --setrw /dev/sde`, four `dd ... oflag=direct`
  writes, `--setro`, all four read-backs match. A re-read of both copies
  parses with valid CRCs and reads as already marked.
- [V] After B5: `slot-successful:b: yes`, `slot-unbootable:b: no`,
  `current-slot: b`, slot A unchanged. A further Linux boot left
  `slot-retry-count:b` at 5, so ABL no longer counts down and will not
  fall back to stock on its own.
- From here: a broken `boot_b` means fastboot by `reboot bootloader` or
  buttons, never a silent fallback. Every `boot_b` flash clears the mark
  (Q/FastbootCmds.c:1024-1049), so B5 runs again after each kernel
  install. The original sectors and the reads are kept privately in
  `captures/2026-11-17/m1b/b5/`.
- M1b is complete: Omarchy boots from slot B by default with the Arch root
  on `userdata`. Open: display/touch (M3), network and time, the two
  Qualcomm firstboot steps (keyring), pushing the device-package fixes
  (0.0.2 usb0, 0.0.3 systemd-firstboot mask) into a rebuilt rootfs.

## 2026-11-17 (night): M1b B0-B4 — Omarchy boots from slot B

- [V] B0: slot A active, both slots successful and bootable, unlocked.
- [V] B1: the `boot_b` image (tethered image + PON `mode-bootloader = 2`,
  `mode-recovery = 1` + `systemd.debug_shell=ttyGS0`, PR #50) RAM-booted.
  `reboot(2)` with RESTART2 "bootloader" from the initramfs reached
  fastboot in about 4 s without passing through stock. So the PON magic
  0x2 is this ABL's fastboot mode.
- [V] B2 (owner go): `flash boot_b`, `flash userdata`, `set_active b` in
  one session, all OKAY. Flashing `boot_b` cleared
  `slot-successful:b` (yes -> no) as Q/ predicts. With threaded flashing,
  `set_active` does not wait for the userdata thread (only erase and
  reboot do, Q/FastbootCmds.c:2001,3423-3432), so we waited 3 min before
  it. Read-back: `current-slot: b`, b not successful, bootable, retry 7;
  slot A unchanged.
- [V] B3: `fastboot reboot` booted Linux from flash; the initramfs handed
  over to Arch on `sda23` and the panel showed a console. Boot then
  stopped at `systemd-firstboot`'s console prompt (locale, timezone, root
  password), which is Before=sysinit and needs a keyboard. That is also
  why T4's Arch never started sshd. Masked from the debug shell on
  `/dev/ttyACM0`; the boot went on (sshd, networkd, usb0 172.16.42.1).
  dodge masks it in its device package for the same reason; ours does
  from 0.0.3.
- [V] Arch: PID 1 systemd, K2, root ext4 rw (the initramfs grew it to
  217 GiB), `RuntimeWatchdogUSec=20s`, about 10 GiB RAM free, SDDM active.
- [V] B4: firstboot ran from `/etc/omamobile/firstboot.conf`, written over
  SSH by a laptop script that hashes the password locally (no secret in
  any image or on the laptop). It created the user, set hostname and
  timezone, deleted the conf. Three Omarchy steps failed: `vulkan.sh` (no
  GPU driver yet) and two `hardware/qualcomm/*` steps that run pacman,
  because the phone's keyring lacks the local build key and there is no
  network. The RTC reads 2026-10-26 (no time sync yet).
- Host: a udev rule (`TAG+="uaccess"` for `1d6b:0104`) gives the owner
  `/dev/ttyACM0` across reconnects.
- Slot B now runs on retries (started at 7; one boot used). Next: settle
  with one planned reboot (`reboot bootloader` path), then decide B5, the
  GPT success mark.

## 2026-11-16 (night): M2 T3/T4 — a stock boot erases the Arch root

- [V] T3 done on the owner's go: the personalized rootfs copy (only public
  SSH keys added, plus the usb0 networkd/NetworkManager files from
  `omamobile-device-instantnoodlep` 0.0.2) went to `userdata` as a 12-part
  sparse image, all OKAY. "Writing OKAY 0.001s" per part is normal: ABL
  writes userdata in a background thread and the next command waits for it
  (Q/FastbootCmds.c `SparseImgFlashThread`, `WaitForFlashFinished`); the
  following `fastboot reboot bootloader` took 118 s for that reason.
- [I] T4 first tethered boot reached Arch: usb0 kept 172.16.42.1 and
  answered ping for hours, but port 22 refused and the initramfs getty on
  ttyGS0 was dead (both killed by `kill -9 -1` before `switch_root`).
  Why sshd never listened is open; a debug image with
  `systemd.debug_shell=ttyGS0` is built for the next attempt.
- [V] The owner then force-rebooted. Stock Android started from slot A
  (logo), failed on userdata and stopped in OnePlus recovery (language
  picker). Only "reboot" was chosen, no wipe. Afterwards `blkid` on
  sda23 reads `TYPE="f2fs"` (magic 0xF2F52010 at 0x400): the ext4 root
  is gone. So one stock boot reformats an ext4 userdata on its own; the
  earlier [I] that AOSP formats only a wiped-looking partition is wrong
  for this build.
- Consequence: tethered M2 on `userdata` is fragile. Every unplanned
  reboot (watchdog bite, `panic=10`, flat battery, buttons) boots slot A
  and erases the root. Recommendation (owner follows recommendations):
  move to M1b, Linux as the default boot on slot B, before writing
  userdata again. It needs its own plan (rule 6) and owner gates for
  `boot_b` and `set_active b`.
- [V] Button gotcha: Volume Up + Volume Down held with the cable in while
  the phone starts lands in EDL (`05c6:9008`, nine 15 s cycles seen on
  the host), not fastboot. Nothing talked to it; it is harmless. The owner
  reached fastboot by holding Volume Up + Volume Down from recovery's
  "reboot".
- [V] Host gotcha: the NCM interface name follows the USB port
  (`enp0s13f0u1` vs `u2`); the `omamobile` NetworkManager connection no
  longer pins an interface name.
- [V] The K2 DT's PMIC `pon@800` nodes carry no `mode-bootloader`/
  `mode-recovery`, so Linux cannot `reboot bootloader`; [I] adding
  `mode-bootloader = <0x2>` (QC ABL's FASTBOOT_MODE) gives a way back to
  fastboot that skips Android.

## 2026-11-16 (evening): restore assets R5, MSM package on disk

- [V] Restore assets on local disk (2026-11-16): MSM package version
  OxygenOS 11.0.4.4 (`IN11BA`, EU) for IN2023, archive tested
  (`unzip -t`: no errors). The region shows in the package's marker file
  (`..._Oxygen-OS-11.0.4.4.IN11BA`) and in its `build_path.txt`
  (`SM8250/19811_R/.../OXYGEN_EU`; 19811 is our project). The `.ops`
  MD5 matches the package's own `md5sum_pack.md5`. Archive SHA-256
  d9f5c6c54247... Location: owner's local disk, outside the repo.
- [V] The package ships `MsmDownloadTool V4.0.exe` and `MsmDownloadTool
  V4.0_factory.exe`, not the `_Win7.exe` variant RESTORE-ASSETS R5
  expected. [I] Use `V4.0.exe` (it ships with this `.ops`); never the
  `_factory` tool or "SMT Download" (they can erase IMEI/Widevine).
- The owner has a native Windows partition for EDL (no VM). Not yet
  dry-run: seeing "Qualcomm HS-USB QDLoader 9008" in Device Manager
  without flashing is the optional next check.
- With R2-R5 passed, ticket #4 (restore assets) can close.

## 2026-11-16 (evening): R7, K2 passes R1-R5; M1a complete

- [V] K2 built offline: `~/src/l` branch `instantnoodlep-k2` @
  `a28aaf1a09db` (linux-omarchy-mobile `317d87dc2db0` + our four DTS
  commits), arm64 defconfig + upstream `kernel/configs/omamobile.config` +
  `device/instantnoodlep/kernel.config` with `LOCALVERSION=-instantnoodlep-k2`,
  `LLVM=1`. kernelrelease `7.3.0-rc6-instantnoodlep-k2-ga28aaf1a09db`,
  `Image.gz` 15,573,890 bytes. Images built with the PR #44 builder
  (`--stock-overlay` entry 16, `--ufdt-apply` check, probe key).
- [V] R1/R2 (UFS off): `Booting OKAY`, SSH after ~6 s, 8 CPUs, MemTotal
  11688880 kB, only `loop*` block devices, watchdog fed. R3: UFS node
  `disabled`. dmesg is cleaner than K1: no `qcom-pon` -EEXIST and no
  deferred dwc3/cpufreq; only the misaligned-image and PSCI PC-mode
  firmware notes, the `aux_bridge` -ENODEV and the expected `qcom_wdt`
  modprobe failure (K2 builds it in, so the module is absent).
- [V] R4 (UFS on): 121 of 122 `ro` flags read 1, the one 0 is
  `/sys/block/sda/ro` (node removed by design), `/dev/sda` absent, no UFS
  errors. R5: stock `.591` from `_a`, slot flags identical to the K2 P5
  capture.
- M1a (RAM-only first light, both kernels) is done. Next per the plan:
  the persistent M1b install, gated on R5 (MSM package) and the owner's
  writes to slot B.

## 2026-11-16 (afternoon, later): M1a first light; R2-R5

- [V] Owner ran `fastboot set_active a` (gated). Stock `.591` booted from
  `_a`; after one boot the flags read `slot-successful:a:yes`,
  `unbootable:no`. `abl_log` is no help: it holds only locked, green boots.
- [V] **The DTB recipe that ABL accepts** (one change per boot, each
  boot from a fresh fastboot session):
  - boot3 = boot1 + an "overlay sink": a hand-written `__symbols__` that
    points all 156 labels the stock dtbo entry 16 needs at disabled
    dummy nodes under `/__ovl_sink__` (no `compatible`, explicit
    `phandle`s). libufdt applies entry 16 offline, and the result has
    zero diff outside the sink. ABL still refused (same silent fallback
    to fastboot).
  - boot4 = boot3 + `oplus,dtsi_no = <0x4d63>` and `oplus,pcb_range =
    <0 0x38>` in `/`. **ABL booted it**: USB CDC NCM + ACM on the laptop
    after 8 s. [I] OnePlus's ABL needs `oplus,dtsi_no` to pick the base
    DTB (R4 note §3), and the overlay must apply.
  - The sink holds 90 downstream compatibles (none `fixed-clock`, irqchip
    or timer, so no `OF_DECLARE` scan picks them up); mainline does not
    populate children of a root node without `compatible`.
  - ABL merges the overlay's root properties: the live `/compatible`
    becomes `qcom,kona-mtp qcom,kona qcom,mtp` and `qcom,board-id`
    `<0x10008 0>`. [I] Matters for anything keyed on the machine
    compatible.
- [V] SSH needs a key without a passphrase (no agent in the agent's
  shell): boot5/boot6 add `~/.ssh/omamobile_probe.pub` to
  `authorized_keys`. Host side: NetworkManager connection `omamobile`,
  `172.16.42.2/24` on the NCM interface. dropbear makes a new host key
  each boot, so use `UserKnownHostsFile=/dev/null`.
- [V] **R2 (boot5, UFS off):** `7.2.0-instantnoodlep-k1-g3c5440e9dd3c`,
  8 CPUs, MemTotal 11689748 kB, only `loop*` block devices, the busybox
  watchdog feeder runs on `/dev/watchdog0`. The cmdline ABL passed has
  `androidboot.dtbo_idx=16`, `androidboot.dtb_idx=0`, `slot_suffix=_a`.
  dmesg: `qcom-pon` on `pmic@a` fails with -EEXIST, dwc3 at `a800000`
  (second USB) and cpufreq-hw defer on interconnect, `qcom_wdt` module
  load fails (watchdog0 still present).
- [V] **R3:** `/sys/firmware/fdt` saved; UFS node `disabled` as built.
- [V] **R4 (boot6 = boot5 with UFS on):** the init logged "no allowlist
  ... every partition read-only", removed `/dev/sda`, and set every other
  disk and all partitions `ro=1` (121 of 122 `ro` files). The one `ro=0`
  is `/sys/block/sda/ro`, the whole-disk flag of the LUN whose node the
  guard deletes by design (plan goal 3: partitions are guarded one by one
  so `userdata` can later be allowlisted). No UFS errors. This matches the
  plan but not the runbook's literal Expect ("every disk ro=1"), so R4 was
  stopped there and the runbook Expect is now corrected.
- [V] **R5:** stock `.591` from `_a`; slot flags equal before and after.
- [V] USB gotcha: after a `reboot -f` from the probe, stock once came up
  in USB MIDI mode (`18d1:4ee8`, no adb); the owner switched the USB mode
  on screen.
- Next: fold the sink + `oplus,*` recipe and the probe key into
  `tools/build-instantnoodlep-probe`, then R7 (K2 kernel).

## 2026-11-16 (afternoon): stage-0 D4/D5, M1a R1, an ABL slot swap

- [V] D4 ran read-only with temp root (`/debug_ramdisk/su`; the `su` on
  `PATH` is Oplus's own `/product/bin/su` and refuses). Radio backup of
  `persist`, `modemst1`, `modemst2`, `fsg`, `fsc` and `param` (no `ocdt`
  on this unit); every file size equals `blockdev --getsize64`. The images
  stay in the private captures folder. All 19 slotted bootloader
  partitions read `same` across `_a`/`_b`.
- [V] D5 from the captures: stock cmdline has `androidboot.dtbo_idx=16`
  and `androidboot.dtb_idx=3`. Boot DTB 3 is "kona v2.1 SoC 19811":
  `qcom,msm-id = <0x164 0x20001>`, `qcom,board-id = <0 0>`,
  `oplus,dtsi_no = <0x4d63>`, `oplus,pcb_range = <0 0x38>`, no
  `qcom,pmic-id` (no stock boot DTB carries one). An exact match that skips
  the dtbo needs every bit in `ALL_BITS_SET`, i.e. the PMIC model at all 16
  indices, foundry and soft-SKU [Q/LocateDeviceTree.h:141-151,
  LocateDeviceTree.c:550-620,1032-1036]. socinfo only gives index 0
  (`pmic_model` 0x1001E), and the boot-time revid lines had rolled out of
  dmesg and pstore, so the exact-match variant was dropped for the sink
  variant below. The live DT lists PM8150 x2, PM8150B x2, PM8150L x2,
  PM8009 x2 and PMX55 (`pmxprairie`) on SPMI. `boot_b` and `dtbo_b` live
  on LUN 4 (`sde`), `userdata` on LUN 0 (`sda`).
- [V] P5 passed (`current-slot:a`, unlocked, flags as C3).
- [V] **R1:** `fastboot boot boot1.img` answered `Booting OKAY`, yet the
  phone stayed in fastboot and kept answering `getvar`; no USB NCM device
  came up. The slot flags afterwards equalled P5. In `Q/`, `CmdBoot`
  replies OKAY after `LoadImageAndAuth` and before `BootLinux`
  [Q/FastbootCmds.c:2869-2894], so AVB passed and `BootLinux` refused
  (DTB selection or overlay) and fell back to fastboot. This is P4
  outcome (a), a clean refusal; the on-screen reason was not captured.
- [V] **Then a second `fastboot boot` (the Magisk image, same fastboot
  session) made ABL swap slots.** The transfer ended in `Status read
  failed (No such device)`, stock came up from `_b` with
  `ro.boot.bootreason=bootloader`, and fastboot then showed
  `current-slot:b`, `slot-unbootable:a:yes`, `slot-retry-count:b:7`.
  That is `HandleActiveSlotUnbootable`: mark the active slot unbootable,
  `SetActiveSlot` the other, cold reset [Q/PartitionTableUpdate.c:1471-1528].
  `Q/` calls it when `LoadImageAndAuth` fails on an A/B device, and
  `CmdBoot` sets `MultiSlotBoot`, so a RAM boot reaches it as well
  [Q/QcomModulePkg/Library/avb/VerifiedBoot.c:1508-1515 at `6922a8a066a6`].
  [I] The likely trigger is `KeyMasterSetRotAndBootState`
  [VerifiedBoot.c:1492], which keymaster accepts once per power cycle;
  R1 had already called it. Nothing on `boot`/`dtbo`/`vbmeta` was written;
  the GPT attribute write was ABL's own.
- Consequences:
  - Plan 5.4 ("ABL writes nothing on a RAM boot") is wrong in one case:
    a failed `fastboot boot` can mark the active slot unbootable and swap
    slots. **After any refused RAM boot, cold-reboot to the bootloader
    (`fastboot reboot bootloader`) before the next `fastboot boot`.** The
    M1 runbook now says so.
  - While stock runs from `_b`, house rule 3 forbids writing `boot_b`.
    Back to `_a` needs `fastboot set_active a` (owner-gated write).
    `SetActiveSlot` clears the unbootable bit and switches the UFS boot
    LUN [Q/PartitionTableUpdate.c:1379-1466]; both LUNs carry identical
    bootloaders (D4), so this is the same move as the stage-0 slot move.

## 2026-11-16 (night, omabook): M1a P2 offline probe builds (K1), K2 D1 baseline, K2 push gate

Part 1 — M1a runbook P2, offline (no phone was touched):

- [V] `OMAMOBILE=~/src/omarchy-mobile MKBOOTIMG=~/aosp-tools/system/tools/mkbootimg/mkbootimg.py python3 tests/instantnoodlep-probe`
  exited 0; all five parts ok, `0 skipped part(s)` (CLI refusals; identity/
  watchdog/size guards; initramfs; AOSP v2 read-back; both happy paths).
- [V] `python3 tools/build-instantnoodlep-probe --help`, then the builder with
  `--boot 1 --out ~/android/build/probe/boot1.img` and `--boot 2 --out
  ~/android/build/probe/boot2.img`, `--kernel
  ~/android/build/k1/arch/arm64/boot/Image.gz` (kernelrelease
  `7.2.0-instantnoodlep-k1-g3c5440e9dd3c`), `--dtb
  ~/android/build/k1/arch/arm64/boot/dts/qcom/sm8250-oneplus-instantnoodlep.dtb`,
  `--initramfs-root ~/android/build/initramfs-root`, `--omarchy-mobile
  ~/src/omarchy-mobile` @ 6c11752ae4c3, `--mkbootimg
  ~/aosp-tools/system/tools/mkbootimg/mkbootimg.py`, `--ssh-key
  ~/.ssh/id_ed25519.pub`: both exited 0 ("Built and read back ..."). The PR
  #37 decompressed-kernel guard passes: `gzip -dc Image.gz | wc -c` =
  42,072,576 bytes against the 89,128,960-byte (0x05600000-0x00080000)
  reserved kernel region.
- Builder commit: `git log -1 -- tools/build-instantnoodlep-probe` =
  21fff4bdf58267547efee6b0ca7b2c9c70e53442 (#37); worktree head
  adfe244bee1809e75d24b4fb1d1603e964c7de8a.
- Images (tool SHA256SUMS, outputs in ~/android/build/probe, outside git):
  boot1.img 23,314,432 bytes sha256
  92f2b76c28f3161bc2aa0c8dd435c1914b9554283a02123099ad2b02803d003c; boot2.img
  23,314,432 bytes sha256
  4712a16d753617f38e7c3ea2b2dc2635ff2a3c9e5da49486076a226a3eccce02; probe DTBs
  126,816 / 126,812 bytes (de816c9c..., 33eda1d8...); initramfs identical for
  both boots, 7,867,485 bytes sha256
  f0775df9affd0ee08ae2df83f27fd4ac212c15134983d7a7aa94dfa53a16e366.
- Manifest key fields (both boots): device instantnoodlep, boot 1/2, header
  v2, page 4096, kernel 0x00008000, ramdisk 0x01000000, tags 0x00000100, dtb
  0x01f00000, kernel_size 15,314,546, ramdisk size 7,867,485,
  boot_image_limit 67,108,864 with [I] evidence, hardware_boot_tested=false,
  shared_init_sha256 93d7d9d214ed9c9f6747ad8b8b7c27e26e6daa0f68e1d3635c40e0609c7d9c45,
  mkbootimg_sha256 37d84b3d162e0bc62e36c1f4e1c63c85ea0caa9f29be023eb2f8efe006ad948c.
- [V] `fdtget` on the probe DTBs: compatible `oneplus,instantnoodlep
  qcom,sm8250`, msm-id `164 10000 164 20001`, board-id `8 0 0 0` (exactly as
  5.2); UFS status `disabled` (boot 1) / `okay` (boot 2);
  `etc/omamobile-ufs-rw` absent from the cpio (grep count 0).
- The builder's last stdout line is a `fastboot -s <serial> boot ...`
  template; it was not run (house rule 1).

Part 2 — K2 D1 baseline (DTS-PORT-PLAN gate D1), offline in ~/src/l with a
`git worktree add` of base 317d87dc2db0 (worktree removed afterwards; no K2
commit changed, head still a28aaf1a09db8889ed156212286e942e411dbe93). venv
~/android/build/venv-dt (dtschema 2026.9) active, `nice -n 19`, ARCH=arm64,
separate O= dirs ~/android/build/k2-d1/{base,head}, logs in
~/android/build/k2-d1/logs:

- [V] `make dt_binding_check` (full): base EXIT=0, head EXIT=0; 0 warning and
  0 error lines in both logs; the normalized diagnostic lines are identical
  between base and head (10 each, pre-existing dtschema hints only), so the
  new `oneplus,instantnoodlep` entry in arm/qcom.yaml passes with no new
  schema error.
- [V] `make dtbs_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom.yaml`
  (the schema file the plan names at DTS-PORT-PLAN.md:342; the instantnoodlep
  DTB is named at :334/:343): first attempt EXIT=2 on both trees because
  `dtbs_check` needs a `.config` (`make ARCH=arm64 defconfig` in each O dir
  first, EXIT=0; CONFIG_ARCH_QCOM=y gates the DTB). Then base EXIT=0 with
  1926 schema-checked DTBs (`[C]` lines), head EXIT=0 with 1927 — the extra
  one is `qcom/sm8250-oneplus-instantnoodlep.dtb` (head log line 2082), with
  no diagnostic output. 0 warnings and 0 errors in both logs; no head-only
  warnings. Gate D1 passes.

Part 3 — K2 fork push gate: STOPPED at the email check. [V] `git log
--format='%an <%ae> | %cn <%ce>' 317d87dc2db0..instantnoodlep-k2` in ~/src/l:
all four commits (b184aa0e0, 5567bd380, f18746472, a28aaf1a0) are authored
and committed with the owner's personal email address,
not a `@users.noreply.github.com` address. Per the gate, Part 3 stopped
there: nothing was rewritten, no remote was added, and nothing was pushed to
any remote (derekross included). No fork head exists to record. [I] whether
the owner wants a noreply-identified fork is an owner decision, not mine.

## 2026-11-16 (late morning): B4 fails — snapshot still live, merge stalled

- [V] B4: `snapshot-update-status: none`, `-cow` count **15**, about ten
  hours and at least three boots after the `.591` install.
- [V] `/dev/block/mapper/` in the running Android lists every `<name>_a`
  next to a mapped `<name>_a-cow`, so first-stage init still maps the
  snapshot. [I] The merge has stalled; the boot HAL's `none` does not
  reflect it on this Oplus build.
- [V] Props: `ro.virtual_ab.enabled=true`, `init.svc.update_engine=running`,
  `sys.oplus.update_engine.log=0`. Logcat holds no update_engine,
  snapuserd or libsnapshot lines; `update_engine_client --follow` from
  `adb shell` fails to bind. Softwareopdatering shows nothing pending.
- [V] A6 socinfo: SM8250, `soc_id` 356, revision 2.1, `hw_platform` MTP,
  `platform_version` 0x10000 (major 1), `platform_subtype_id` 0,
  `foundry_id` 1, `pmic_model` 0x1001E (PMIC 0 = model 0x1E, PM8150
  [I]), `pmic_die_revision` 0x30000. For an exact DTB match (M1a option
  2) the DTB needs `qcom,msm-id = <0x10164 0x20001>` (foundry 1 in bits
  16-23, `Q/LocateDeviceTree.c` foundry check) and a `qcom,pmic-id`
  matching every PMIC slot; socinfo exposes only PMIC 0, so the rest
  comes from D4 (`dmesg` under temporary root) or a guess that costs one
  safe boot.
- [V] 11:10: `ps -A` shows no `snapuserd`, and `update_engine` at 0 s CPU
  time since boot, unchanged over 60 s. `update_engine_client --merge`
  (the stock `cleanupSuccessfulUpdate` call) fails from `adb shell` with
  `EX_TRANSACTION_FAILED`. `/proc/diskstats` and `ls -l
  /dev/block/mapper` came back empty (denied). [I] The merge was never
  started rather than running slowly, so waiting a night is dropped.
- Decision (owner follows the recommendation): R5 (MSM package) and
  backups, then a stock factory reset from Settings while locked (AOSP
  recovery finishes pending merges before wiping, or refuses), then the
  mapper `-cow` count and B4. Unlock stays blocked until B4 shows `0`.
- [V] Factory reset from Settings, still locked (owner, 2026-11-16 ~11:30):
  after setup the phone boots `_a`, `.591`, and the mapper `-cow` count
  is still **15**. Oplus recovery wiped data without finishing the merge,
  and boot is unaffected.
- [V] `Q/DeviceInfo.c`: on unlock, ABL writes `recovery --wipe_data` to
  `misc`, so the unlock wipe runs the same recovery path the reset just
  ran. [I] OnePlus's ABL does the same.
- **Decision (owner follows the recommendation):** B4 is satisfied by
  evidence instead of a `0` count: a data wipe with the stalled snapshot
  live is proven harmless on this phone. Restore-assets R5 (MSM) moves
  from G1 to a gate before M1b, the first step that writes a partition;
  phases C/D and M1a write nothing MSM would be needed for.
- Open for M1b [I]: with the snapshot still live, `--set-active b` and
  the GPT slot marks need a fresh look (AOSP fastbootd warns that a slot
  change with a snapshot applied may cancel the update).

## 2026-11-16 (morning): M1a P3 offline dtbo check — the stock overlay cannot apply

Laptop only, no phone. Inputs: the stock `dtbo.img` from the verified
`.591` OTA (R4), the P2 probe DTBs `boot1.probe.dtb`/`boot2.probe.dtb`
(sha256 `de816c9c…`/`33eda1d8…`), libufdt's overlay code built from
`system/libufdt` `657f54c72d9e` and dtc 1.8.1 `fdtoverlay`. Outputs stay
in `~/android/build/p3/`, outside git.

- [V] Which entry: `Q/` chooses the dtbo entry from the board data alone
  (`GetBoardDtb` → `ReadDtbFindMatch(..., VARIANT_MATCH)` over the dtbo
  entries); our DTB plays no part. Stock boots with `ro.boot.dtbo_idx =
  16` (A3), i.e. entry 16, "kona MTP 19811", `qcom,board-id = <0x10008 0>`
  (variant 8, major 1), `oplus,dtsi_no = 0x4d63`. [I] OnePlus's ABL picks
  the same entry for a RAM boot, since the board has not changed.
- [V] Entry 16 has 101 fragments, all `target = <&label>` (no
  `target-path`), and 156 distinct `__fixups__` labels.
- [V] **Applying it to either probe DTB fails** in both tools: libufdt
  "No node __symbols__ in main dtb", `fdtoverlay` `FDT_ERR_BADOFFSET`.
  The probe DTBs are built without `-@`.
- [V] `Q/` returns "Error: Dtb overlay failed" when `ApplyOverlay` fails
  (`Q/BootLinux.c`, after `GetBoardDtb`) and does not boot. Exact-match
  skip is not in play: our DTB has no `qcom,pmic-id`, so `CheckAllBitsSet`
  cannot pass. **Prediction for R1: outcome (a), a clean refusal in
  fastboot, nothing written** [I until the phone shows it; OnePlus's ABL
  is a closed fork].
- [V] Label-stub variant, sized: the same DTS compiled with `-@` (606
  symbols) resolves only 12 of the 156 labels (`soc`, `tlmm`,
  `spmi_bus`, `mdss_mdp`, `mdss_dsi0/1`, `sdhc_2`, `intc`, `pdc`,
  `tsens0`, `bt_en_sleep`, `ts_int_active`); libufdt then stops at
  `clock_rpmh`. Stubbing the other 144 would make it apply, but 60
  fragments target real mainline nodes (`soc` 14, `tlmm` 8, `spmi_bus` 5,
  `mdss_mdp` 32, `sdhc_2` 1) and would graft downstream nodes into them.
  [I] That is outcome (c) by construction, so the stub variant is not a
  safe M1a option.
- [V] Exact-match variant, corrected input: no stock base DTB carries
  `qcom,pmic-id` (R4, all 21 checked), so the plan's "PMIC ids from the
  stock live DT" cannot work. The match needs the board's platform type,
  subtype, foundry id and every PMIC model from SoC info. STAGE-0-RUNBOOK
  has a new read-only step A6 (`/sys/devices/soc0`, never
  `serial_number`). [I] Downstream socinfo may expose only the first
  PMIC; a full list may need D4 with root.
- For the owner (P4), in order of risk: (1) accept outcome (a) as the
  first finding and boot `boot1.img` unchanged, since a refusal writes
  nothing; (2) prepare the exact-match variant after A6; (3) no stub
  variant. Option (1) costs one boot and tests the prediction.
- **P4 decision (owner, 2026-11-16): option (1).** The owner follows the
  recommendation: R1 boots `boot1.img` unchanged and records whether ABL
  refuses (outcome a) or boots. If it refuses, the exact-match variant
  (option 2) is next, built from the A6 socinfo capture. No stub variant.

## 2026-11-16: stage 0 phases A-B, stock moved to slot A

- [V] A3b case (c) applied and worked. Stock ran
  `IN2023_13.1.0.591(EX01)` from `_b`; the owner local-installed the same
  `.591` full zip, and the A3 rerun shows `ro.boot.slot_suffix` = `_a`,
  the same fingerprint, `flash.locked` = `1`, `green`. **The Oplus updater
  accepts a same-version full zip**, so `a3b-contingency.md` is no longer
  needed.
- [V] B2 (ABL fastboot, locked): `current-slot:a`, `unlocked:no`,
  `secure:yes`. Slot flags: a and b both `successful:yes`,
  `unbootable:no`, `retry-count:6`. Slot b is still marked good after
  stock left it; that is the baseline for the ticket "Slot-B bootable
  marking on Qualcomm: the named GPT-attribute exception".
- [V] No `init_boot` or `vendor_boot` partitions. `boot`, `dtbo`,
  `vbmeta`, `vbmeta_system` are raw and slotted (`_a`/`_b`
  `partition-type` lines). This ABL reports `has-slot` only for `boot`,
  `modem` and `system` (`no`). `version-bootloader` is empty.
  `max-download-size` is 805306368 (768 MiB).
- [V] B3: fastbootd is reachable (`is-userspace: yes`), so restore path 1
  is proven. `super-partition-name:super`. Logical partitions in `super`:
  `system`, `system_ext`, `vendor`, `product`, `odm` and ten `my_*`
  (Oplus) partitions, all `_a` in the current-slot metadata.
  `userdata` is not logical and is 0x36F3453000 bytes (about 236 GB).
- [V] **Virtual A/B.** Every logical partition had an `_a-cow` twin right
  after the install (`system_a-cow` 0x2B65C000 bytes against `system_a`
  0x2B3A7000), yet both ABL and fastbootd reported
  `snapshot-update-status:none`. [I] Either the merge had finished and
  cleanup was still pending, or this boot HAL does not report the merge
  state; the status variable alone cannot tell them apart. AOSP fastbootd
  refuses to erase `userdata`/`metadata`/`misc` mid-merge; whether ABL's
  `oem unlock` does is unknown. The runbook now has B4 (status `none`
  **and** no `-cow` partitions) as a hard gate before C2. Pending: the
  owner's B4 result.
- [V] Restore-assets R4 ran offline on the laptop
  (`docs/research/r4-stock-images.md`): boot header v2, page size 4096;
  `boot` and `dtbo` are **chained** in stock vbmeta (`Flags: 0`), so ticket
  #10 lands in the chain case (option B, a test-key footer on `boot_b`).
  All 19 dtbo table entries have id/rev/custom 0; overlays and base DTBs
  are matched on `qcom,msm-id`/`qcom,board-id` plus the Oplus property
  `oplus,dtsi_no` (0x4d63 = our project 19811).
- Consequence for later milestones [I]: `super` is Virtual A/B, so a
  future stock OTA would use snapshots too. The port never writes `super`
  (AGENTS.md rule 3), so nothing changes in the safety model, but the
  M1b `--set-active` step must also be preceded by a `none` merge status
  (AOSP fastbootd refuses slot changes while `merging` [V: AOSP
  `fastboot/device/commands.cpp` `SetActiveHandler`]).

## 2026-11-15 (late): M1 split, RAM-only plan

- The owner chose to split M1 on the wayfinder map. **M1a** is a RAM-only
  first light (`fastboot boot`, nothing written, slot A stock and active);
  `BRINGUP-M1-PLAN.md` now plans it, with kernel K1 (SM8250 community
  kernel) before K2 (`omamobile` + ported DTS). **M1b** is the persistent
  slot-B install (`boot_b`/`dtbo_b`, `--set-active`), gated on the tickets
  "Slot-B bootable marking on Qualcomm: the named GPT-attribute exception"
  and "vbmeta/AVB handling on an unlocked Qualcomm ABL". **M2** stays
  "Arch root on userdata".
- [I] There is no public evidence yet that this phone RAM-boots a mainline
  image. Lineage and the community port document flashing only
  (`lineage_wiki` `install_method: fastboot_nexus`; Nura README "Flash"),
  and a TWRP-era guide flashes recovery rather than booting it.
  wiki.nura.eco and XDA could not be checked (bot protection / 403).
  Stage-0 Q11 decides at STAGE-0-RUNBOOK D3 whether this ABL RAM-boots at
  all (a Magisk-patched stock image); the first mainline image is M1a
  step R1.
- [I] Main risk: on a RAM boot the stock `dtbo_a` overlay is still read
  from flash and applied to our DTB. The Qualcomm reference ABL then
  either refuses the image or applies the overlay; a partial graft would
  leave the kernel on a contaminated DT. The plan has an offline overlay
  check (P3) and a live-DT diff (R3) for it.
- Disputed: the fastboot button combo. `device.conf` says Volume Down +
  Power; Lineage's device data and the Nura README say Volume Up + Volume
  Down + Power. Stage 0 settles it; until then, `adb reboot bootloader`.

## 2026-11-15 (evening): research landed, upstream precedents

- Research notes from the four research tickets are in `docs/research/`,
  each with a coordinator review of corrections: boot header v2 (not v3),
  root compatible `"oneplus,instantnoodlep", "qcom,sm8250"`, a 1080x2376
  bootloader framebuffer, `serial0` = the Bluetooth UART, Adreno 650 (not
  Mali) and SDX55 over MHI firmware rows.
- Watch: upstream #808 has not changed (open, 0 comments, 0 labels).
  instantnoodlep is not on the DEVICES.md Wanted list [V: GitHub API,
  2026-11-15 ~20:10 UTC].
- Precedents in upstream DEVICES.md (status 2026-11-14) [V]:
  - OnePlus 6 (enchilada, SDM845, upstream #432): first light was a
    **RAM-only `fastboot boot`**, with nothing written. It stays RAM-only
    "until the slot-B install and its CONTRIBUTING.md §3.1 entry are
    agreed". Pixel 4 (flame) and Xiaomi Mi 8 (dipper) also merged
    RAM-only first-light probes. [I] Our M1 first light could do the
    same; then the GPT-attribute exception would gate only the persistent
    slot-B install. This is an owner decision.
  - enchilada: `boot_b` sits on LUN `sde`, not on `sda` with `userdata`.
    The guard needs `UFS_RW_LUNS` (upstream #530). That is a device.conf
    key our draft lacks; stage-0 question 10 covers it.
  - enchilada: ABL appends `root=PARTUUID=<system_a> skip_initramfs ro
    init=/init` even on `fastboot boot`. The shared init copes.
  - enchilada erased `dtbo_b`, because downstream overlays do not apply to a
    mainline DTB. This matches our [I] on dtbo.
  - enchilada: `--set-active` writes the GPT slot flags, and upstream
    treats it as a slot-flag write.
  - Pixel 4 XL (coral, SM8150): "§3.1 entry still to land". No Qualcomm
    GPT-attribute exception exists upstream yet.
  - OnePlus 13 (dodge): the `qcom-abl` boot method (a header-v4
    chainloader) was merged in upstream #111. It is not our path, but it is
    the precedent for adding a Qualcomm `BOOT_METHOD`.
  - POCO F3 (alioth, SM8250): upstream #25 was closed 2026-11-11 and can
    be reopened. It is the closest SoC sibling.
- HITL runbooks written: `docs/runbooks/STAGE-0-RUNBOOK.md`,
  `docs/runbooks/RESTORE-ASSETS.md`.

## 2026-11-15

- Support request posted upstream:
  [derekross/omarchy-mobile#808](https://github.com/derekross/omarchy-mobile/issues/808).
  No maintainer reply yet.
- Workspace bootstrapped: device.conf draft (values marked TODO/I), stage-0
  checklist and collect script, restore runbook, BRINGUP-M1 plan skeleton.
- Mainline status of this hardware, demonstrated by the unofficial Nura
  image (kernel 7.2, Oct-Nov 2026 releases) on an IN2023 EU unit: display
  1440x3168@120 Hz, GPU, speakers/mics, Wi-Fi, Bluetooth, modem/SIM/data/SMS,
  GPS, NFC, sensors, all five cameras via libcamera. Voice calls (VoLTE) NOT
  verified. That image overwrites `super`; our model never does.
- Restore assets still to secure locally: full OTA (payload.bin) for IN2023,
  MSM Download Tool package for IN2023 (Windows, last resort, wipes+relocks).
