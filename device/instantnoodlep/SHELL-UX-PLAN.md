<!-- SPDX-License-Identifier: MIT -->
# Shell UI: offline proposals and attended verification

Status: 2026-11-17, shell-ux branch on obsidian; the patched package for step 3
was built offline by the shell-pkg worker on macbookpro. [V] No phone commands
run. Upstream source is pinned to
`c4623572be1c141d602cf99a83ae0bf9e3eea09c`.

## Scope and evidence

[V] The three issue drafts in `docs/upstream/` cite the pinned source.
[I] Corner taps in NOTES do not measure the touchable boundary: the proposed
48 logical pixel inset and 32 logical pixel strip require an attended test.
[V] This plan covers shell QML proposals only; no kernel, firmware, partitions,
credential changes or device installation is part of this worker's work.

## Design

[I] Preserve the default edge geometry; allow device environment overrides.
Keep input restricted to the configured strip and make its window large enough.
[I] Register Wi-Fi with the existing BackLink surface tier, retaining keyboard
priority and Escape fallback. Do not grant Wi-Fi or Back above-lock input.
[V] The instantnoodlep environment file in patch 1 is a packaging proposal;
there is no complete upstream instantnoodlep package to install it yet.

## Gated coordinator runbook

Every phone step belongs to the coordinator, attended by the owner. Announce
shell/session changes before running them; obtain the owner's go for each such
step. No reboot, flash or partition write is required. Stop if the source or
installed layout differs from the pinned version. Kernel release is recorded
by step 1; this task builds no kernel or boot image.

1. Read-only baseline, in the existing phone shell:
   `uname -r; OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell call omamobile.back state ''`
   Expect: record kernel release and JSON containing `"edge":14,"inset":0`. Stop:
   command absent or unexpected shell version. Rollback: none (reads).
2. Offline, on a disposable clone of the pinned upstream source:
   `git apply --check /path/to/patches/0001-back-gesture-device-edge-geometry.patch`
   then `git apply /path/to/patches/0001-back-gesture-device-edge-geometry.patch`;
   repeat for patches 2 and 3. Expect: all three apply without errors. Stop: any
   mismatch. Rollback: discard the disposable clone. Risk: local source files only.
3. Integration gate: the coordinator installs the patched package and restarts
   the shell. [V] The installed package is `omamobile-shell 0.2.133-1`
   (`arch=any`), built from upstream `c4623572be1c141d602cf99a83ae0bf9e3eea09c`:
   `packages/omamobile-shell/version` reads `0.2.133` there, set in `49d7abe`
   and unchanged through `c462357`, the tip of upstream `main`. [V] The shell is
   not a systemd user unit: `omamobile-shell` 0.2.133-1 ships none that runs it,
   and `omarchy` 4.5.0-3 (the version `rootfs/packages.pinned` holds) has no
   shell unit either; `omarchy-restart-shell` kills the
   `quickshell -p /usr/share/omarchy/shell` instance and re-spawns
   `omarchy-launch-shell` through `hyprctl dispatch 'hl.dsp.exec_cmd(...)'`, so
   the shell inherits Hyprland's environment, not the systemd user manager's.

   a. Artefact, built offline on macbookpro in `~/vibe-runs/shellpkg/out/`:
      `omamobile-shell-0.2.133-1.1-any.pkg.tar.zst`, 528031 bytes, sha256
      `4ab37382bfc2d5fd324c6ca532b64b84ef402d3195c84ed3a22545f0114ec955`.
      Source: upstream `c462357` plus
      `patches/0001-back-gesture-device-edge-geometry.patch`,
      `patches/0002-wifi-picker-register-back-link.patch` and
      `patches/0003-back-surfaces-test-wifi-picker.patch` (test-only: without it
      the package's own `check()` fails with "WifiPanel.qml registers with Back
      but isn't tested here"), `pkgrel` 1.1 and a `pkgdesc` note. Rebuild with
      `device/instantnoodlep/tools/shellpkg-build-in-alarm.sh`; its header has
      the `docker run` line. [V] `test/all` passes on the patched tree in that
      container (335 checks, 0 failures). Expect: the same sha256. Stop: a
      different sha256 or a failed check.
   b. Install, as root over the existing remote terminal. The file is on
      macbookpro: copy it to the phone's `/root` first, or rebuild it on omabook
      and check the sha256. Then
      `pacman -U /root/omamobile-shell-0.2.133-1.1-any.pkg.tar.zst`
      Expect: `pacman -Q omamobile-shell` reads `0.2.133-1.1`, the post_upgrade
      message, and `hyprctl reload` ran. Stop: a dependency error or another
      version. Rollback: step 3e.
   c. Geometry for the session, as the phone user, unlocked:
      `hyprctl eval 'hl.env("OMAMOBILE_BACK_EDGE_INSET", "48")'`
      `hyprctl eval 'hl.env("OMAMOBILE_BACK_EDGE_WIDTH", "32")'`
      [I] `hl.env` is Hyprland 0.57's `setenv` for the compositor and the shell
      is its child; if the call is refused nothing changes and the defaults
      (edge 14, inset 0) stay.
   d. Restart the shell: `omarchy-restart-shell` (announce it: the screen
      redraws). It refuses while the session is locked, so unlock first.
      Expect: `OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell ping` answers
      and `... shell call omamobile.back state ''` shows `"edge":32,"inset":48`.
      Stop: no answer after 60 s, QML errors in `journalctl --user -t
      omarchy-shell`, or a state without `inset`. Rollback: step 3e.
   e. Rollback: `pacman -U /var/cache/pacman/pkg/omamobile-shell-0.2.133-1-any.pkg.tar.zst`
      (check it is there first: `ls /var/cache/pacman/pkg/omamobile-shell-*`),
      then `hyprctl eval 'hl.env("OMAMOBILE_BACK_EDGE_INSET", "0")'`,
      `hyprctl eval 'hl.env("OMAMOBILE_BACK_EDGE_WIDTH", "14")'` and
      `omarchy-restart-shell`. If the cache is empty, `pacman -S omamobile-shell`
      reinstalls the repo's current version. Risk: a shell restart only; no
      reboot, no partition write.
4. With the patched shell installed and the owner ready, set the geometry and
   restart as in step 3c and 3d (not `systemctl --user set-environment`: the
   shell is Hyprland's child, so the user manager's environment never reaches
   it). Expect: `OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell call
   omamobile.back state ''` shows `"edge":32,"inset":48`.
   Stop: QML errors, inaccessible UI or unexpected state. Rollback: step 3e.
   Risk: temporary input interception/session disruption; never flash.
5. Owner gestures only: test left/right inward swipes in an unlocked app and
   Wi-Fi list; short/vertical drags must not navigate. Confirm ordinary app taps
   outside the strip pass through. Test nested Wi-Fi sheet, keyboard, then list:
   each Back closes one level (keyboard first). Compare IPC
   `shell call omamobile.back back ''` with the physical swipe to distinguish
   dispatch from capture failure. Expect: Wi-Fi registration in state while open,
   removed on close. Stop: multiple levels close, stale registration, blocked taps.
   Rollback: step 4. Risk: UI navigation only; use no real network credentials.
6. Owner locks/unlocks with Wi-Fi open. Expect: lock owns input; picker/back
   strip do not bypass lock, unlock remains possible. Stop: lock bypass or input
   loss; coordinator restores original shell via step 3. Record pass/fail, actual
   kernel release, scale and geometry; do not record SSID, secrets or identifiers.

## Results

[V] Pending device verification; patch applicability and host checks are recorded
in `docs/upstream/README.md`. No exact boundary, lock failure cause, or successful
phone behavior is claimed.

## Safe-inset follow-up (2026-11-18)

[V] `patches/0004-device-safe-insets.patch` adds a shared QML `SafeInsets`
component to the pinned 0.2.133 shell source. It reads
`/usr/share/omamobile/device-ui.conf`, defaults to zero, bounds values, converts
physical output pixels to logical units by the output scale, and supplies a
separate gesture edge width. It is consumed by the status bar, Back strips,
launcher dock/strip/drawer, quick-settings shade and Wi-Fi/Bluetooth/record
panels, and the keyboard language sheet. The status bar's host geometry
includes the top safe band so notification and OSD placement through the host
stays below it. Squeekboard draws the key surface itself; the launcher strip
and language sheet use bottom/side insets, while key layout geometry remains
owned by Squeekboard.

[I] (superseded 2026-11-18, see below) `device-ui.conf` provisionally proposed 144 physical
pixels on each side (48 logical pixels at scale 3) and a 96 physical-pixel
gesture width. The observed x minimum around 144 is anecdotal and is not a
measurement of active panel area or symmetric right-edge touch; do not install
these values until the coordinator reviews the calibration output. The future
device package must install this file at `/usr/share/omamobile/device-ui.conf`.

### Gated calibration and package validation

1. **Owner-attended read-only calibration.** Coordinator runs
   `tools/instantnoodlep-edge-calibrate` as root while the owner taps left and
   right physical edges when prompted. Expect touchscreen ABS_MT X/Y ranges,
   connected DRM mode(s), and captured edge coordinate bounds on stdout.
   Stop if `evtest` finds no panel touchscreen, the selected event node is
   ambiguous, or DRM mode is unavailable. Rollback: none; the script only
   reads input/sysfs and stores no samples. Risk: L.
2. **Offline shell source.** In a disposable clone, check and apply patches
   `0001`, `0002`, `0003` and `0004` in order against upstream
   `c4623572be1c141d602cf99a83ae0bf9e3eea09c`. Set local package
   `pkgrel=1.2` so its version is `0.2.133-1.2` (the prior local shell build
   was `0.2.133-1.1`); build through
   `device/instantnoodlep/tools/shellpkg-build-in-alarm.sh`. Expect all patches
   apply and `test/all`, QML lint/format checks pass in the build container.
   Stop on patch drift or any QML/test failure. Rollback: discard the clone.
   Risk: L.
3. **Install and attended UI review.** Only after calibration has been reviewed
   and config values replaced with accepted measurements, package the file at
   `/usr/share/omamobile/device-ui.conf`, install the `0.2.133-1.2` shell package and
   restart through the known shell path in the earlier gated steps. Test bar,
   drawer hit regions, home strip, quick-settings shade, Wi-Fi/Bluetooth and
   keyboard language sheet at each edge; verify Back still dismisses keyboard
   first and remains available. Expect zero values when config is absent and
   inset controls outside configured edge bands when present. Stop on blocked
   taps, unexpected Back behavior or lock/session trouble. Rollback: restore
   package `0.2.133-1.1`, remove `/usr/share/omamobile/device-ui.conf`, then restart
   the shell. Risk: M (input geometry and session restart).

### Host checks

[V] On the x86 host, the pinned package's `test/all` ran through the UI and
model checks but exited 1 at the unrelated staged weather timer assertion
(`test/all:1199-1208`, `not ok - omamobile-weather`). The package's QML parse
and offscreen touch checks were skipped because `qmlformat` and
`qmltestrunner` are unavailable here. [V] `bash -n` passed for the calibration
and ALARM build scripts; the inline Python compiled. `git apply --check` passed
for patch 0004 against the tree after patches 0001-0003. [I] This does not
replace `qmllint`, QML execution, ARM package build, or device interaction;
`shellcheck`, `qmllint`, and Docker are unavailable in this workspace.

[V] 2026-11-17, shell-pkg worker: `omamobile-shell-0.2.133-1.1-any.pkg.tar.zst`
built in the ALARM container from upstream `c462357` with patches 0001-0003
applied; `test/all` passes there (335 checks, 0 failures) and the package's file
list is upstream's, with `Back.qml` and `WifiPanel.qml` the only changed files.
[V] Patch 0002 alone fails `test/back-surfaces.py`; 0003 is the missing test
entry. [I] Nothing is installed or run on the phone yet: steps 3-6 are the
coordinator's.

## Launcher regression and fix (2026-11-18, shell 0.2.133-1.3, device 0.0.7)

[V] Shell `0.2.133-1.2` (patch 0004 as first written) put
`anchors.{top,bottom,left,right}Margin` on eight `PanelWindow`s. Quickshell's
window `anchors` group holds only the four booleans, so `Launcher.qml`,
`LanguageWindow.qml` and `RecordPanel.qml` failed to load on the phone
("Cannot assign to non-existent property", quickshell log). The launcher owns
the dock and the home strip, so apps covered the whole screen with no way out.
[V] The package's `test/all` passed anyway: its render/touch harnesses turn
each window into an `Item`, where `anchors.*Margin` is valid.

Fix, in patch 0004: window margins use `margins { ... }` (the upstream form,
`Voice.qml`), and the six harnesses drop that window-level line the way
`test/voice-render` already does. Guard: `tools/lint-panelwindow-margins`
flags `anchors.*Margin` beside boolean window anchors; it reports all 32 lines
of the old patch and nothing in upstream's tree. Run it on the patched
`plugins/` before every shell build.

[V] Phone after `pacman -U` of shell `0.2.133-1.3` (sha256 `66beb248…`) and
device `0.0.7-1` (`5f0a508a…`): no QML load errors; `omamobile-launcher`,
`omamobile-dock` (home screen) and `omamobile-home-strip` (480x44 at the bottom,
`reserved` bottom grows by 44 with an app open) are mapped; `test/all` 332 ok,
0 not ok on omabook.

Values from the edge calibration (`edge-cal.txt`: taps at x=19..79 left and
1365..1413 right of 0..1439) now ship in the device package:
`safe_insets_px=24,0,30,0`, `gesture_edge_width_px=96` and
`OMAMOBILE_BACK_EDGE_INSET=0`, so the Back strip covers 0..32 logical px from
each edge instead of 48..80. [I] The inset env applies from the next login.

Open, owner-attended: swipe up on the strip (home), swipe-and-hold (recents),
Back from both edges. Persistent Back/Home/Recents buttons wait until the
owner has used the restored strip.
