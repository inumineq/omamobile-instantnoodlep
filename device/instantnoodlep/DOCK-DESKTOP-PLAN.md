<!-- SPDX-License-Identifier: MIT -->
# Docked desktop and external displays plan

Status: 2026-11-18. Design and offline Settings proposal only; no phone
commands were run. Package proposal: `omamobile-settings` 0.1.4, on upstream
`c4623572be1c141d602cf99a83ae0bf9e3eea09c` plus patches 0001 and 0002.

## Goal and scope

- [I] When a USB-C display appears, make it the main work surface for ordinary
  Hyprland tiling windows, with the pointer on the external desktop. Keep the
  phone panel available as a secondary touch surface initially; panel-off and
  touchpad behavior are policy choices to qualify separately.
- [I] When the external display is removed, restore the handset's normal
  phone-first layout and touch behavior without restarting Hyprland or losing
  running windows.
- [V: task brief, 2026-11-18] The owner reports a DP Alt Mode picture on the
  Dell U3219Q. Keyboard and mouse connected through that display's hub do not
  work yet; USB host/hub input is tracked by kernel task B.
- [V: `DESKTOP-MODE-RESEARCH.md` §4, lines 39-42] Hyprland supports multiple
  outputs, per-output mode/scale/position and hotplug events; Omarchy's desktop
  components and the phone shell share the same compositor.

## Evidence and constraints

- [V: upstream Hyprland monitor documentation,
  <https://wiki.hypr.land/Configuring/Basics/Monitors/>] Hyprland 0.55+ uses
  Lua monitor rules such as `hl.monitor({ output = "DP-1", mode =
  "1920x1080@60", position = "auto", scale = 1 })`; `hyprctl monitors all`
  lists active and inactive outputs.
- [V: upstream Settings `backends/display.sh` at the pinned commit, lines
  89-98; upstream `packages/omamobile-sensors/lib/autorotate.py`, lines
  83-94] Omarchy Mobile's current Lua-config path applies monitor changes with
  `hyprctl eval 'hl.monitor({...})'`. The old `hyprctl keyword monitor ...`
  hyprlang form is not the selected interface for this 0.57 Lua-config build.
- [V: upstream Settings `DisplayPage.qml` at the pinned commit, lines 5-24]
  The existing Display page uses a fixed-argument backend and its refresh
  change is session-only. The separate Displays page in patch 0002 follows the
  same Settings/ActionRunner structure.
- [V: task brief] DP video currently works on the named external display while
  dock USB input does not. [I] The initial display layout can be developed and
  mode-tested independently; a usable docked pointer/keyboard desktop depends
  on task B passing USB host enumeration and hub input.
- [I] `monitoradded` and `monitorremoved` events are the session manager's
  triggers. On attach it should query `hyprctl -j monitors all`, ignore the
  internal `DSI-1` output for external profile selection, apply the remembered
  external rule and focus/move the desktop workspace there. On removal it
  should return focus and the phone profile to `DSI-1`.
- [I] Keep the phone panel on as the initial safe behavior. A later shell
  profile can blank/disable it or translate touch into a touchpad only after
  lock-screen visibility, touch, suspend/resume and unplug recovery pass.
  Keyboard presence is not required to recognize a display; it gates the
  complete desktop-input experience, not DP output configuration.

## Design

### Dock transition

1. [I] A small session-side shell component subscribes to Hyprland's
   `monitoradded` / `monitorremoved` events. Events trigger a fresh monitor
   query rather than trusting the event payload as a complete state snapshot.
2. [I] When an external output is present, Hyprland keeps the regular desktop
   compositor and tiling layout. The shell moves its desktop bar/workspace
   focus to that output and places it as the primary work surface; no second
   compositor or app restart is needed. A USB mouse supplies the pointer when
   task B enables the dock hub.
3. [I] Initially leave `DSI-1` enabled as a secondary touch display. Test
   panel-off and touchpad variants as separate gates; never make either the
   only way to see the lock screen or recover the session.
4. [I] On removal, restore the phone's normal workspaces, bar and touch-first
   behavior. Running apps remain under Hyprland and return to the handset
   layout.

### Per-monitor settings

- [I] Remember a preferred mode, scale and position independently for each
  external connector in the user's Hyprland config. Patch 0002 writes a
  managed, per-output block into `~/.config/hypr/monitors.lua`; each selected
  rule records the mode, chosen scale and `position = "auto"` so Hyprland reads
  it on the next login/config load. Existing user content is preserved.
- [V: upstream Hyprland monitor documentation linked above; pinned Settings
  backend lines 89-98] Apply changes live through `hyprctl eval` with
  `hl.monitor`, not `hyprctl keyword monitor`. Restrict the output name, scale
  and mode to validated values; the mode must appear in that output's
  `availableModes`.
- [I] The Settings Displays page lists connected outputs, their current mode
  and available modes. External outputs can select mode and scale; the
  built-in `DSI-1` panel is shown read-only so this page does not conflict with
  phone auto-rotation or panel policy.
- [V: patch 0002's fake fixture] Offline fixture includes a `DSI-1` panel and
  U3219Q modes 3840x2160@60, 2560x1440@60 and 1920x1080@60. [I] Those choices
  still need verification against the live connector/mode list and the exact
  monitor link on the phone.

### Upstream fit and dependencies

- [V: upstream `omamobile-settings` package at the pinned commit and patch
  0001] The Settings app is Qt Quick/QML and already uses an ActionRunner with
  fixed backend arguments. Patch 0002 adds a sibling Displays page/backend and
  keeps the phone panel read-only.
- [I] Hotplug-driven desktop profile transitions belong in the shell/session
  layer, not the Settings page. Settings owns the user's persistent mode and
  scale choices; the shell consumes `monitors.lua` on login and reacts to
  monitor events.
- [V: task brief] USB keyboard/mouse through the monitor hub is blocked on
  kernel task B. [I] Do not claim full docked desktop input until B has passed
  the self-powered hub, keyboard and mouse gates.

## What is proposed

| Area | Proposal | Evidence/status |
| --- | --- | --- |
| Settings | `patches/omamobile-settings/0002-settings-displays-page.patch`, stacked on 0001; package version 0.1.4 | [V: `patches/omamobile-settings/README.md`, “Displays page patch (0002)”] Patch application and fake-backend checks passed; package `test/all` and phone checks remain pending |
| Session hotplug | shell/session integration using `monitoradded` and `monitorremoved` | [I] Not implemented in this Settings patch |
| USB hub input | kernel/USB host work from task B | [V: task brief] Pending; no input-device qualification in this task |
| Phone panel policy | keep visible initially; panel-off/touchpad options later | [I] Needs attended phone tests |

## Gated runbook

No handset is attached to this worker's host. The following steps are for the
coordinator and owner. There are no flash or partition-write steps; the only
fastboot operation is the non-writing `fastboot boot` RAM test in Gate 1.

### Gate 0 — offline package checks

- Command: apply 0001 then 0002 to upstream commit
  `c4623572be1c141d602cf99a83ae0bf9e3eea09c`; run the package `test/all`,
  `qmllint` on changed QML and `qmlformat --check` where available.
- Expect/Pass: both patches apply cleanly; package check passes; the fake
  `hyprctl -j monitors all` fixture lists the DSI panel and all three U3219Q
  modes; DSI writes and unsupported modes are rejected; external apply calls
  the Lua API and preserves the user's monitor config.
- Stop if: a patch hunk is truncated/mismatched, any package test fails, or
  the managed config can overwrite unrelated content.
- Rollback: discard the temporary upstream checkout; no phone state is
  touched.
- Risk: low (host-only).

### Gate 1 — RAM boot, package install and read-only output inventory

- Precondition: the coordinator has built the 0.1.4 Settings package and the
  owner has approved a RAM-boot image. From fastboot, run
  `fastboot boot <approved-instantnoodlep-RAM-image>`; then install only the
  Settings package with `pacman -U <omamobile-settings-0.1.4-package>`.
- Commands: open Settings → Displays; independently run
  `hyprctl -j monitors all` and inspect `hyprctl devices`.
- Expect/Pass: external output is listed with its current mode and
  `availableModes`; `DSI-1` appears but has no controls; the owner confirms the
  observed connector is the U3219Q and checks for a keyboard/mouse only after
  task B's USB host gate.
- Stop if: the panel is offered as writable, connector names or modes are
  missing, or the external output is unstable.
- Rollback: close Settings; reboot to leave the temporary RAM boot and return
  to the existing slot-B kernel. The RAM boot does not write a partition.
- Risk: low.

### Gate 2 — external resolution and scale

- Commands: record current mode/scale/position; in Settings apply
  3840x2160@60, then 2560x1440@60 and 1920x1080@60 at a chosen scale. Read
  back `hyprctl -j monitors all` and `~/.config/hypr/monitors.lua` after each
  selection.
- Expect/Pass: each listed mode applies, the selected scale is reported by
  Hyprland, the managed rule is updated once for that connector, and unrelated
  monitor config remains intact. Re-login/reload once and confirm the saved
  external rule is read.
- Stop if: the screen blanks, mode/scale is not accepted, the monitor drops,
  Hyprland reports config errors, or the lock screen is not visible.
- Rollback: restore the recorded mode/scale through Settings (or
  `hyprctl eval 'hl.monitor({ output = "<connector>", mode = "<old-mode>",
  position = "<old-position>", scale = <old-scale> })'`) and remove only the
  managed Settings block if needed; restore the pre-test `monitors.lua` copy.
- Risk: medium (display mode change; no partition writes).

### Gate 3 — docked desktop and unplug recovery (after task B)

- Commands: with an owner-attended RAM-booted candidate and the hub attached,
  connect the monitor, USB keyboard and mouse; observe
  `hyprctl -j monitors all`, `hyprctl devices` and the shell workspace/bar;
  unplug the monitor, reconnect it, then log out/in once.
- Expect/Pass: monitor hotplug events transition the desktop profile without
  restarting apps; tiled windows and pointer work on the external display;
  DSI-1 remains available for touch; unplug returns to the handset profile;
  reconnect uses the per-monitor mode/scale/auto-position choice.
- Stop if: keyboard/mouse enumeration fails, pointer is lost, windows become
  inaccessible, the lock screen disappears, DPMS fails to restore, or the
  handset cannot recover its phone profile.
- Rollback: use the handset screen and physical buttons as needed; disable the
  external profile and restore the saved `monitors.lua`. Do not proceed to
  panel-off/touchpad experiments in this gate.
- Risk: medium; task B USB input support is a prerequisite.

### Gate 4 — optional phone panel policy

- Commands: only after Gate 3 passes, test panel-off and touchpad behavior one
  at a time, including lock/unlock, touch, keyboard focus, suspend/resume and
  monitor removal.
- Expect/Pass: the user can always see and unlock the phone, touch input has a
  clear role, and removal restores the visible handset panel.
- Stop if: the lock UI or recovery controls are hidden, touch coordinates are
  wrong, or any output fails to wake.
- Rollback: re-enable `DSI-1`, return to the visible phone profile and restore
  the saved monitor settings.
- Risk: medium-high (screen/input policy).

## Results and open questions

- [V: `patches/omamobile-settings/README.md`, “Displays page patch (0002)”] On 2026-11-18, 0001 then 0002 applied cleanly to the pinned upstream commit. The fake `hyprctl` backend test passed its monitor inventory, DSI-1/unsupported-mode rejection, Lua apply, current-mode parsing and managed-config preservation checks; shell syntax and diff whitespace checks passed.
- [V: same source] The full package `test/all` stopped before running its build because `qmake6` is absent on this host. `qmllint`, `qmlformat` and `shellcheck` are unavailable, and Docker cannot reach its daemon. This leaves the package build/static checks unverified here.
- [V] No phone access or phone test was performed by this worker.
- [I] Exact Hyprland hotplug event consumption, primary-workspace transition,
  dock keyboard/mouse support, persistence across the phone shell's actual
  login path, mode stability and the optional phone-panel policy remain to be
  checked by the coordinator and owner.
- [I] Proposed phone test: use `fastboot boot <approved-instantnoodlep-RAM-image>`
  only (no flash), then install the 0.1.4 Settings package with `pacman -U`.
  Verify `hyprctl -j monitors all`, apply the three U3219Q modes in Settings,
  reconnect/login to confirm persisted mode/scale, and verify external tiling,
  pointer and unplug restoration after task B input passes. Keep the current
  mode/scale and `monitors.lua` backup for rollback.
