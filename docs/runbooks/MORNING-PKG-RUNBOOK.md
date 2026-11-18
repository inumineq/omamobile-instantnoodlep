<!-- SPDX-License-Identifier: MIT -->
# MORNING-PKG-RUNBOOK: install the 2026-11-18 unsigned package set

Built 2026-11-18 on macbookpro in the Arch Linux ARM aarch64 container
`k3arch` (`alarm-aarch64:20260805-42a4eeaa`), `makepkg` as the non-root
`builder` user, sources shipped over ssh into `/w/pkgs`. No phone was
accessed, nothing was installed on the phone, no partition was written.
Roles per AGENTS.md rule 1: the coordinator runs every non-writing step over
the existing USB SSH session (`root@172.16.42.1`); every package transaction
is a rootfs write and runs only after the owner's explicit go for that step
(**OWNER GO**); steps that need the screen are the owner's. No flash, no
reboot, no slot marking is part of this runbook.

The archives are **unsigned**; the owner's signing key and the signed local
repository come later per PR #111 (`device/instantnoodlep/LOCAL-REPO-PLAN.md`).
The allowlist `tools/omamobile-localrepo-packages.tsv` already carries these
exact versions, so the later `tools/omamobile-localrepo add` accepts them.

## Artefacts (on omabook: `~/android/build/arm-pkgs-20261118/`)

| Package | Version | Arch | Bytes | sha256 |
| --- | --- | --- | ---: | --- |
| `omamobile-device-instantnoodlep` | `0.0.6-1` | aarch64 | 19680 | `80011661c6f8ee4d00394544c679647b08d13a43c79fff8fed6bec92d2ecc3f9` |
| `omamobile-shell` | `0.2.133-1.2` | any | 529181 | `3171cdccfa21e8c0cf369662a5f34c3f3bc49899fd1207839212db49fdb25c68` |
| `omamobile-settings` | `0.1.3-1` | aarch64 | 91168 | `2a53b67ac2b5290dd8702bfa88eeef02873f8b7be204bd9da7e19eb74e52ed2f` |

`SHA256SUMS` sits next to them; `sha256sum -c SHA256SUMS` passes [V: run on
omabook after the scp from macbookpro]. Sources: device package = this
repo's `main` (`version` 0.0.6); shell = upstream `derekross/omarchy-mobile`
`c4623572be1c141d602cf99a83ae0bf9e3eea09c` with `patches/0001`-`0004` applied
in order and `pkgrel=1.2` (the PR #79 route plus 0004, per
`SHELL-UX-PLAN.md` "Safe-inset follow-up" step 2); settings = the same
upstream pin with `patches/omamobile-settings/0001-settings-security-page.patch`
(version 0.1.3). Each package's own `check()` ran inside `makepkg` and passed
[V: `makepkg` finished and emitted each archive — device `test/all` with
ShellCheck 0.10.0, shell `test/all` 335+ checks, settings `test/all` incl.
QtTest CoreTests 11 passed 0 failed and the single-instance D-Bus test].

## What each package changes

1. **`omamobile-device-instantnoodlep` 0.0.6-1** — device policy only, no
   firmware, kernel image or per-device identifier: descriptor
   `/usr/share/omamobile/device.conf`, names-only `firmware.map`, the
   `/etc/pacman.d/omamobile-mirrorlist` backup file (install script adds the
   `[omamobile]` repo section once), USB0 gadget network file, masks
   `systemd-firstboot.service` and `systemd-vconsole-setup.service`
   (`/dev/null` symlinks), uwsm graphics env, `environment.d` back-gesture
   and sleep settings plus the `s2idle` sleep drop-in, the Bluetooth
   public-address udev rule/unit/binary (state stays on the phone in
   `/var/lib/omamobile/bt-public-addr`), and the two per-user profiles:
   Chromium/mobile-app (`omamobile-instantnoodlep-mobile-profile.service`)
   and scaling/foot/Hyprland dialogs
   (`omamobile-instantnoodlep-scaling.service`), both wanted by
   `graphical-session-pre.target`.
2. **`omamobile-shell` 0.2.133-1.2** — patched phone shell: Back edge/inset
   from environment (0001), Wi-Fi picker registered with Back plus its test
   (0002/0003), and the new `omamobile.safeinsets` plugin (0004) feeding the
   bar, Back strips, launcher, quick settings and keyboard from
   `/usr/share/omamobile/device-ui.conf` (not installed by the device
   package yet — absent means zeros and the old defaults). `post_upgrade`
   reloads every running Hyprland.
3. **`omamobile-settings` 0.1.3-1** — adds the Security page (lock PIN,
   account password, keypad, opt-in separate lock PIN) with a narrow
   `pkexec` helper and a lock-screen PAM branch that stays disabled unless
   opted in. No account or PAM change happens at install time; removal is
   refused while the separate-PIN roster exists.

Install order: device, shell, settings (the shell reads the device package's
files at runtime; settings is independent).

## P: prepare and install (phone steps; P2-P4 are OWNER GO)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| P0.1 | Read only, `root@172.16.42.1`: `pacman -Q omamobile-device-instantnoodlep omamobile-shell omamobile-settings; pacman -Qu; pacman-conf LocalFileSigLevel` | record the three installed versions (baseline for rollback); `LocalFileSigLevel` unset/Optional so unsigned `pacman -U` archives are accepted | any of the three absent (then its rollback is `pacman -R`, see R2); `LocalFileSigLevel` Required | none (reads) |
| P0.2 | `install -d -m 700 /root/morning-pkg-rollback`; for each installed name: `v=$(pacman -Q $name | awk '{print $2}'); a=$(pacman -Qi $name | awk -F': ' '$1=="Architecture"{print $2}'); cp -p /var/cache/pacman/pkg/$name-$v-$a.pkg.tar.zst /root/morning-pkg-rollback/`; `sha256sum /root/morning-pkg-rollback/*.pkg.tar.zst` | one cached archive per installed package, hashes recorded | a cache archive is missing (then `pacman -R` is the only rollback for that package — note it and stop for the owner's decision) | none yet |
| P0.3 | Laptop: `adb push ~/android/build/arm-pkgs-20261118 /root/arm-pkgs-20261118` (or scp over the USB SSH); phone: `cd /root/arm-pkgs-20261118 && sha256sum -c SHA256SUMS` | all three `OK` against the table above | any mismatch | delete `/root/arm-pkgs-20261118`, re-push |
| P1 | **OWNER GO** — `pacman -U /root/arm-pkgs-20261118/omamobile-device-instantnoodlep-0.0.6-1-aarch64.pkg.tar.zst` | transaction completes; `pacman -Q omamobile-device-instantnoodlep` = `0.0.6-1`; post_upgrade prints the `[omamobile]` repository note; `pacman -Dk` clean | dependency error, another version, any prompt answered no | R1 |
| P2 | Announce the shell restart to the owner, then **OWNER GO** — `pacman -U /root/arm-pkgs-20261118/omamobile-shell-0.2.133-1.2-any.pkg.tar.zst` | `pacman -Q omamobile-shell` = `0.2.133-1.2`; post_upgrade reloads running Hyprland instances; `pacman -Dk` clean | dependency error, session/lock trouble during reload | R1, then `omarchy-restart-shell` (owner) |
| P3 | As the phone user: `omarchy-restart-shell` (announced; the shell is Hyprland's child, not a systemd unit) | shell restarts, home screen back | shell does not come back | owner reboots the session; package rollback R1 if the shell is broken |
| P4 | **OWNER GO** — `pacman -U /root/arm-pkgs-20261118/omamobile-settings-0.1.3-1-aarch64.pkg.tar.zst` | `pacman -Q omamobile-settings` = `0.1.3-1`; no PAM/account output; `pacman -Dk` clean | dependency error, any unexpected PAM prompt | R1 |

Do not run `pacman -Syu` in this session for these packages: the installed
local versions are greater than the `[omamobile]` baselines
(`0.2.133-1`, `0.1.2-1`, none), so no downgrade is proposed [V:
`LOCAL-REPO-PLAN.md` §1 repo-priority rules].

## V: verify (read only unless stated)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| V1 | `pacman -Q omamobile-device-instantnoodlep omamobile-shell omamobile-settings`; `test -f /usr/share/omamobile/device.conf && head -3 /usr/share/omamobile/device.conf` | `0.0.6-1`, `0.2.133-1.2`, `0.1.3-1`; descriptor CODENAME `instantnoodlep` | any other version | R1 |
| V2 | Safe insets: as the phone user, `omarchy-shell shell call omamobile.back state ''` | JSON with `"edge":14,"inset":0` — defaults preserved because `/usr/share/omamobile/device-ui.conf` is not installed yet [V: patch 0004 falls back when the file is absent] | command absent (shell not restarted, P3) | `omarchy-restart-shell` |
| V2b | Owner-attended optional: write the provisional `/usr/share/omamobile/device-ui.conf` from `device/instantnoodlep/device-ui.conf` (144,0,144,0 px; gesture 96 px), `omarchy-restart-shell`, re-run V2 | `"edge":32` at scale 3 (96/3) and side insets 48 logical px; the bar sits clear of the curved top corners | blocked taps, unexpected Back behavior, lock/session trouble | remove the file, `omarchy-restart-shell` [V: SHELL-UX-PLAN "Safe-inset follow-up" step 3 rollback]; do not keep the provisional values until calibration is reviewed |
| V3 | Chromium profile: as the phone user, `systemctl --user is-active omamobile-instantnoodlep-mobile-profile.service`; `grep -qxF -- '--force-device-scale-factor=0.83' ~/.config/chromium-flags.conf`; `grep -q -- '--user-agent=.*Android 13; OnePlus 8 Pro' ~/.config/chromium-flags.conf`; `test -f ~/.local/state/omamobile/instantnoodlep-mobile-profile/chromium-flags.original` | `active`; both flag lines present; original flags backed up | service failed or flags missing | `omamobile-instantnoodlep-mobile-profile reset` as that user [V: package README]; package rollback R1 |
| V4 | Foot/scaling profile: as the phone user, `systemctl --user is-active omamobile-instantnoodlep-scaling.service`; `grep -qx 'multiplier=2.0' ~/.config/foot/foot.ini`; `grep -qx 'pad=4x4' ~/.config/foot/foot.ini` | `active`; both lines present | service failed or foot.ini untouched | `systemctl --user restart omamobile-instantnoodlep-scaling.service`; package rollback R1 |
| V5 | Settings Security page: `omamobile-settings --version`; `omamobile-settings --check`; `test ! -e /etc/omamobile/lock-pin-users`; open Settings on screen (owner) | `omamobile-settings 0.1.3`; `{"errors":[],"ok":true}`; no lock-pin roster (separate PIN off, PAM untouched); the Security page is listed and opens | wrong version, check not ok, roster present | R1 |

## R: rollback (OWNER GO for the transaction)

| # | Step | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| R1 | `pacman -U /root/morning-pkg-rollback/*.pkg.tar.zst` (the exact previous archives captured in P0.2) | `pacman -Q` shows the P0.1 baseline versions again | any hash/version mismatch | stop; do not substitute another archive; the cache in `/var/cache/pacman/pkg` is the source of truth |
| R2 | For any of the three that was **not** installed before P1-P4 (recorded in P0.1): `pacman -R <name>` | package gone, `pacman -Q <name>` errors | dependencies block removal | `pacman -Rns <name>` only if the owner approves; otherwise leave installed and note it |
| R3 | If V2b wrote `device-ui.conf`: remove it; `omarchy-restart-shell` (owner-attended) | back to `"edge":14` defaults | — | — |
| R4 | `pacman -Dk`; `pacman -Q omamobile-device-instantnoodlep omamobile-shell omamobile-settings` | clean; baseline versions | dependency damage | restore from `/var/cache/pacman/pkg` by hand per LOCAL-REPO-PLAN §4.5 |

No reboot is needed for any step; the shell restart (P3) is the only session
change. Captures go to `captures/2026-11-18/morning-pkgs/` (gitignored); no
serial, IMEI, MAC or BD address in pasted output.
