<!-- SPDX-License-Identifier: MIT -->
# Mobile UX audit: instantnoodlep

Date: 2026-11-18. Scope: research only; no phone was inspected during this
write-up. Upstream source was cloned read-only at its current `main` snapshot.

## Evidence key and device baseline

- [V] means checked in the cited source. [I] means a hypothesis or proposed
  device behavior that needs an attended handset check.
- [V] The OnePlus 8 Pro panel is described in this task as 1440x3168 curved
  AMOLED; device descriptor is still marked draft and values need Stage-0
  confirmation (`device/instantnoodlep/device.conf:9-11`).
- [I] At compositor scale 3 this is 480x1056 logical pixels. The reported
  touch minimum near x=144 is an observation, not a calibrated active-area
  or touch-controller boundary. Do not turn it directly into a permanent
  48-logical-pixel dead zone: test both edges, multiple y positions, and
  touch-to-output mapping first. Existing shell research likewise calls its
  48/32 geometry provisional (`device/instantnoodlep/SHELL-UX-PLAN.md`,
  “Scope and evidence”; `.trail/learnings/l-ecac9b32`).
- [V] The shell-edge learning says to retain the default geometry until
  calibration and to keep Back at its existing surface tier, below keyboard
  dismissal (`.trail/learnings/l-ecac9b32`, “Decided” and “Watch out”).
- [V] Upstream Omarchy Mobile's current package already sets phone scale,
  GDK scale, Foot touch behavior, Chromium flags, and Nautilus portal routing
  (`packages/omamobile-shell/bin/omamobile-setup-user:181-196,313-378,439-446`,
  `packages/omamobile-shell/README.md:95-102`). This is a moving `main`
  checkout; verify commit/version before proposing code upstream.

## Audit matrix (ranked by expected daily-use impact)

| Rank | Surface / symptom | Cause and proposed fix | Where | Effort / risk |
|---|---|---|---|---|
| 1 | [I] Curved edge controls may be hard to hit or visually clipped. | [V] Existing shell plan's 48/32 values are provisional. [I] Calibrate touch range against panel/DT and define `safe_insets = left,top,right,bottom` in physical pixels, with separate `gesture_edge_width`; provide per-device config. Shell controls and app content should consume safe insets. Do not reserve a compositor-wide dead strip for all clients until verified. | Device package config plus upstream `omamobile-shell` safe-inset API; shell handles its own bars/overlays. | M / M: could waste viewport or conflict with back gestures. |
| 2 | [I] Chromium websites and PWAs may render desktop layouts or narrow/clipped controls. | [V] Upstream setup seeds a mobile UA, text-input-v3/IME, no-first-run, and device scale factor 0.83 (`setup-user:313-328,350-378`). [I] Test the existing set on OnePlus; use Chromium's per-user `~/.config/chromium-flags.conf` and package-managed idempotent setup. Add Ozone Wayland only if runtime does not select Wayland automatically. Test touch/pinch and overlay scrollbars before adding flags; avoid global touch emulation and `--use-mobile-user-agent` because it is documented upstream as ineffective on desktop Linux. | Upstream `omamobile-shell` profile, with per-device factor/UA in device package. | S/M / M: flags vary by Chromium build; UA can break sites/client hints. |
| 3 | [I] Shell bar, launcher, notification shade, OSD, lock screen, keyboard, Wi-Fi/BT panels, gestures may be too small, occluded or unsafe near edges. | [V] Upstream has distinct phone shell surfaces and keyboard/back behavior (package `plugins/`, `hypr/phone.lua`; `README.md`). [I] Survey each surface at device scale, portrait/landscape, keyboard open, lock/unlock. Apply safe insets to visual and hit regions; maintain keyboard-first Back; verify lock owns input; test shade and OSD touch targets. | Upstream `omamobile-shell`; device config supplies insets only. | M/L / H for lock/gesture regressions. |
| 4 | [I] 1Password Electron desktop interface likely overflows or has tiny controls. | [V] Installed app list supplied by coordinator includes `1password`; no proprietary Android UI should be copied. [I] First test the 1Password browser extension in a mobile-tuned Chromium profile, then web vault at phone width. Do not make `op` CLI + custom QML a first choice: it creates a security-sensitive credential UI and extra maintenance. Electron zoom/scale is a diagnostic fallback. | App configuration / browser profile. | S / M (extension compatibility and unlock UX). |
| 5 | [I] Foot TUI applications (btop, vim/neovim, uuctl, cliamp and shell workflows) can be dense and shortcut-heavy. | [V] Upstream adjusts Foot padding, scrollback multiplier and long press (`setup-user:439-446`). [I] Set a legible default font for 480 logical px, ensure touch scrolling/selection, expose common actions through shell buttons, and document keyboard availability. For each TUI tune its own density where supported. | App config, Foot config and upstream shell affordances. | S / L-M: font may reduce columns. |
| 6 | [I] GTK/Qt desktop apps, dialogs, settings and polkit may have undersized controls or over-wide layouts. | [V] Upstream matches GDK scale to monitor scale and routes file choosers to Nautilus's adaptive libadwaita chooser (`setup-user:189-196`; `README.md:95-97`). [I] Prefer adaptive GTK/libadwaita apps; configure per-app GDK/QT scale only for mismatches, not globally. Check portal chooser and polkit modal window fits around keyboard. Alternatives with mobile Linux support are candidates only after testing with this shell. | Upstream shell package for portal/window rules; app config for scale overrides. | S/M / M: environment scale can double-scale. |
| 7 | [I] Electron apps including Discord, Zoom, Obsidian, LocalSend, Basecamp, HEY, X, WhatsApp, YouTube may open desktop layouts. | [V] Chromium app/PWA launchers are in installed-app list from coordinator. [I] Use Chromium scale/UA/viewport profile per web app; Electron apps get individual zoom and `--ozone-platform=wayland` only where supported. Prefer web/PWA for touch-responsive sites. | App config and upstream browser launcher profile. | S / M: per-app quirks. |
| 8 | [I] Image, document, office, media and utility apps may present desktop toolbars/dialogs: Pinta, LibreOffice, Evince/Papers, Loupe, Maps, mpv, CUPS, Disk Utility, Qt V4L2 tools, Fcitx config. | [V] The supplied installed-app inventory includes these apps. [I] Prioritize responsive GTK/libadwaita alternatives and full-screen/maximized windows; route file dialogs through portals. Use app-specific scaling for Qt/GTK only after measurement. Defer rare admin/authoring tools behind phone-friendly launchers. | App config; upstream shell portal/window policy; alternatives selected per app. | M/L / L-M. |
| 9 | [I] System UI may be inconsistent across compositor, GTK, Qt, cursors and fonts. | [V] Upstream explicitly aligns monitor and GDK scale and individually adjusts Chromium (`setup-user:181-196,350-378`). [I] Record Hyprland output mode+scale, `GDK_SCALE`, `QT_SCALE_FACTOR`, font DPI and cursor theme/size in the survey; avoid duplicating fractional scaling. Set all from device package only when verified. | Device package scale defaults plus shell setup; app-specific exceptions. | S/M / M: inconsistent XWayland and toolkit scaling. |

## Curved edges: calibration and interface proposal

1. [I] Read panel dimensions/active area and touch-controller coordinate range
   from the OnePlus 8 Pro DT and kernel driver, then compare with an attended
   edge sweep. Capture minimum/maximum touch x/y and mapped compositor
   coordinates at several y positions. The anecdotal x minimum ~144 is not
   sufficient to infer either panel pixels or safe inset.
2. [I] Store a named `safe_insets_px = {left, top, right, bottom}` and
   `gesture_edge_width_px` in the instantnoodlep device package, with zero or
   unset defaults until measured. Convert physical-pixel insets using the
   active output scale and orientation. Keep gesture capture width separately
   configurable from content inset.
3. [V] Hyprland supports reserved areas through layer-shell exclusive zones;
   upstream shell already owns its bars and overlays (`packages/omamobile-shell`
   and Hyprland layer-shell conventions). [I] A compositor reservation can
   constrain ordinary windows, but global left/right `addreserved` strips may
   mis-handle rotated layouts, fullscreen clients, edge gestures and shell
   overlays. Prefer an upstream shell safe-inset mechanism that positions
   shell controls and publishes usable-area insets; use compositor reservation
   only for confirmed app content area if tested with all layer surfaces.
4. [I] Qt/GTK safe-area support is inconsistent across native Wayland desktop
   apps. Do not make toolkit-specific client support the only safety mechanism.
   For Qt/QML shell surfaces, pass explicit insets; upstream can expose
   `OMAMOBILE_SAFE_INSETS` (or a shell IPC/settings API) to shell-owned
   applications and portal dialogs.
5. [V] Existing shell plan requires testing physical gestures, ordinary taps,
   nested Wi-Fi sheet, keyboard dismissal and locked state before enabling
   changes (`SHELL-UX-PLAN.md`, steps 4-6). Follow it after measurement.

## Chromium and Electron profile to test

[V] Upstream's current setup writes `~/.config/chromium-flags.conf`, preserving
user values, and includes `--no-first-run`, a mobile `--user-agent`,
`--force-device-scale-factor=0.83`, `--enable-wayland-ime`, and
`--wayland-text-input-version=3` (`packages/omamobile-shell/bin/omamobile-setup-user:313-328,350-378`).
It reports Chromium auto-selects Wayland in its current packaging context;
the scale factor is a specific workaround for a 480 px logical panel and
500 px minimum layout width (`:350-353`).

[V] Package release 0.0.4-2 installs a user service after upstream's
`omamobile-setup-user.service`. Its profile merge replaces only the Pixel 7 Pro
UA, keeps one scale/IME/text-input switch, and preserves unrelated user flags.
A managed desktop launcher wrapper adds app-specific scale or Ozone flags only
when its per-app profile sets them. `reset` restores original files if they
have not changed since setup; `disable` prevents later login application.

[I] Concrete starting profile for OnePlus test (use one setting per line;
the quoted UA is needed because the launcher splits on spaces):

```text
--no-first-run
--enable-wayland-ime
--wayland-text-input-version=3
--force-device-scale-factor=0.83
"--user-agent=Mozilla/5.0 (Linux; Android 13; OnePlus 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/<installed-major>.0.0.0 Mobile Safari/537.36"
```

The package does not add `--no-first-run` a second time. It preserves
upstream's IME/text-input flags when present and adds them only when absent;
its candidate scale is the upstream 0.83 seed. The Android version, model
string, factor and mobile UA remain [I] until the phone survey. Per-app scale
defaults to `inherit`; overlay scrollbars, touch events, pinch and Ozone
Wayland default to `auto`, leaving Chromium's build defaults in control.

[I] First verify native Wayland through `WAYLAND_DEBUG`/window protocol or
`hyprctl clients`; add `--ozone-platform=wayland` only if it otherwise uses
XWayland. Touch-events, pinch zoom and overlay scrollbars are build/version
dependent and not included by default: test actual touch scrolling, pinch on
web content, and scrollbar hit regions before selecting
`--touch-events=enabled`, `--enable-pinch`, or overlay-scrollbar switches.
Avoid `--use-mobile-user-agent` (upstream notes it is ignored for desktop
Chromium) and global forced touch emulation. Confirm web text fields summon
Squeekboard via text-input-v3, and test virtual keyboard resize/viewport,
selection handles, password manager prompts and PWA display modes.

[I] Electron app launches should be per-app: try Ozone Wayland, native app
zoom controls, then the app's supported scale setting. Chromium flags do not
automatically control Electron. Avoid blanket Electron flags until each
runtime is identified.

## Morning phone survey matrix

All rows are [I] until the owner runs them on the unlocked phone. Start with
the package profile as staged, record its package version and Chromium/app
versions, and change one candidate at a time. Use the installed desktop IDs
from `tools/instantnoodlep-ui-survey`; keep screenshots in `/tmp/ui-survey`
and out of git.

| Surface | Site/app to launch | Check on phone | Record before changing a profile value |
|---|---|---|---|
| Chromium browser | `chromium` | Right/left viewport clipping; responsive mobile layout; UA-dependent content; text field opens Squeekboard; keyboard resize and selection handles; touch scroll; pinch; scrollbar hit area; Wayland vs XWayland. | Panel mode and Hyprland scale, Chromium major, observed UA, native Wayland selection, and which control fails at the current 0.83 factor. |
| PWA/web app | HEY | Standalone window and login page fit; text entry and keyboard viewport; touch scroll/pinch; primary navigation is reachable. | Desktop ID/Exec, clipped edge and smallest usable controls. Keep account/content screenshots private. |
| PWA/web app | WhatsApp | Conversation list and composer fit; text entry, keyboard resize, touch scroll/pinch; navigation remains visible with keyboard open. | Desktop ID/Exec and per-app scale only for a distinct layout problem. Do not send a message. |
| PWA/web app | YouTube | Home/search/player controls fit; touch scroll and pinch; search field/keyboard; landscape behavior if used. | Desktop ID/Exec, viewport dimensions and controls that require a scale exception. Do not play or upload private content. |
| PWA/web app | X | Timeline/navigation fit; composer opens with keyboard; touch scroll/pinch; buttons are reachable without accidental edge-back. | Desktop ID/Exec and measured scale/zoom issue. Do not post or interact with private messages. |
| PWA/web app | Basecamp | Project list and task/detail views fit; forms and keyboard; scroll/pinch; narrow controls are not clipped. | Desktop ID/Exec and smallest usable per-app scale. Do not create or edit project content. |
| Electron | Obsidian | Note list/editor and toolbar fit; touch scroll/selection; text input and keyboard; record native Wayland or XWayland. | Desktop ID/Exec, Electron version, current app zoom and clipping; only then choose scale or Ozone override. Do not edit vault content. |
| Electron | Discord | Server/channel layout fits; text composer and keyboard; touch targets; record native Wayland or XWayland. | Desktop ID/Exec, Electron version, current zoom and overflow. Do not send messages or join voice. |
| Electron | LocalSend | Main window and receive/send controls fit; touch targets and dialogs; record native Wayland or XWayland. | Desktop ID/Exec, Electron version and any scale exception. Inspect UI only; do not start a transfer. |

At each app, first test the inherited global profile. Use the site's or app's
own zoom control to separate zoom from device scale; only then set a per-app
`scale_factor` in `chromium/apps.conf` if a persistent exception is needed.
Keep `ozone_platform=auto` unless the runtime check shows XWayland and that
app accepts `--ozone-platform=wayland`. Test overlay scrollbars, pinch and
touch-event flags separately; do not enable global touch emulation. If a test
would expose private account data, record the result without copying the screen.

## 1Password recommendation

[V] `1password` is in the supplied installed desktop-id list; this research
did not inspect its proprietary binary or phone behavior. [I] Recommend the
official browser extension in a dedicated mobile-tuned Chromium profile as the
first experiment: it reuses responsive browser layout and avoids copying
proprietary Android UI. Compare with the web vault at 480 logical px and check
autofill, unlock, clipboard and keyboard behavior. Electron zoom/flags are a
fallback if the installed desktop app supports them. A small Qt/QML client
around `op` would be a new security-sensitive credential front end and should
not be built absent a clear need and review. Bitwarden/Vaultwarden web or
KeePassXC with a mobile frontend are alternatives only if the user chooses a
credential migration; they are not drop-in compatibility fixes.

## Survey script and use

`tools/instantnoodlep-ui-survey` launches each installed desktop ID, waits,
captures `/tmp/ui-survey/<id>.png`, closes the active window, and writes an
index. It is intentionally run by the coordinator while the owner has the
phone unlocked. Screenshots can contain private content and stay in `/tmp`,
never in git. Capture shell-only surfaces separately by hand because a desktop
app sweep cannot exercise gestures, lock UI, OSK, OSD or quick settings.

## Prioritized tickets

1. **Calibrate OnePlus 8 Pro active/touch area and safe insets** — Why: [I]
   curved edge reach and clipping are unmeasured; ~144 x-min is anecdotal.
   Change: record panel/DT and touch coordinates, derive orientation-aware
   physical-pixel insets and gesture widths. Where: device package/plan.
   Effort: M. Risk: M (incorrect inset wastes area or harms input).
2. **Add upstream shell safe-inset contract** — Why: [I] a device-specific
   measurement needs consistent application to controls and usable content.
   Change: shell setting/API with per-edge pixel insets; apply to owned shell
   surfaces and publish usable-area information; preserve keyboard-first Back
   and lock ownership. Where: upstream `omarchy-mobile` `omamobile-shell`.
   Effort: M. Risk: H (layer/input regressions).
3. **Validate Chromium phone profile on instantnoodlep** — Why: [V] upstream
   already seeds IME, UA and scale; [I] OnePlus needs its own scale and actual
   browser tests. Change: profile test for Wayland, text-input-v3, responsive
   pages/PWAs, pinch, scrollbars and keyboard; add only proven flags. Where:
   upstream shell plus device package values. Effort: S/M. Risk: M.
4. **Survey all installed apps and shell surfaces** — Why: [I] several desktop
   and Electron apps are in the phone image; no screenshots/measurements were
   available. Change: run survey tool and annotate viewport/control issues,
   then manually test shell surfaces. Where: device package/research. Effort:
   S + review. Risk: L if captures remain private.
5. **Provide a 1Password mobile workflow** — Why: [I] Electron desktop UI may
   not adapt. Change: test browser extension and web vault in mobile Chromium;
   document supported launch/profile; evaluate alternatives only by user
   preference. Where: app config/upstream app packaging. Effort: S. Risk: M
   (credential and autofill behavior).
6. **Tune touch ergonomics for Foot/TUIs and GTK/Qt exceptions** — Why: [I]
   keyboard-heavy and desktop-style apps likely have dense controls. Change:
   measure touch/scroll/font and apply per-app scale or phone-friendly launch
   defaults; prefer adaptive apps and portal dialogs. Where: app config and
   upstream shell. Effort: S/M. Risk: L/M (workspace/font changes).

## Sources

- [V] Upstream repository: <https://github.com/derekross/omarchy-mobile>
- [V] Upstream setup script (Chromium, monitor/GDK scale, Foot):
  <https://github.com/derekross/omarchy-mobile/blob/c4623572be1c141d602cf99a83ae0bf9e3eea09c/packages/omamobile-shell/bin/omamobile-setup-user>
- [V] Upstream shell README (file dialogs and window behavior):
  <https://github.com/derekross/omarchy-mobile/blob/main/packages/omamobile-shell/README.md>
- [V] Hyprland layer rules documentation: <https://wiki.hypr.land/Configuring/Workspace-and-Monitor/>
- [V] Chromium switches are build-sensitive; source of truth is Chromium
  source/docs, check the installed version before adoption:
  <https://chromium.googlesource.com/chromium/src/+/main/docs/linux/ozone_overview.md>
- [V] Local device context: `device/instantnoodlep/device.conf:9-11,13-27`;
  `device/instantnoodlep/SHELL-UX-PLAN.md`; `.trail/learnings/l-ecac9b32`.
