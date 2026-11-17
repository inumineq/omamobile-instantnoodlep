<!-- SPDX-License-Identifier: MIT -->
# Draft issue: make Back from the Wi-Fi picker explicit

**Status:** Draft only; not posted. Source checked at `derekross/omarchy-mobile` commit `c4623572be1c141d602cf99a83ae0bf9e3eea09c`.

## Problem

- [V] `packages/omamobile-shell/plugins/omamobile.back/Back.qml:42-53` asks `BackLink.back()` first, then sends synthetic Escape when no registered surface handles Back.
- [V] `packages/omamobile-shell/plugins/omamobile.quicksettings/WifiPanel.qml:412-423,449-455` gives the Wi-Fi panel an on-demand keyboard-focus surface and handles Escape on its focused panel to return to quick settings. Its header back button also calls `backRequested` at `WifiPanel.qml:476-482`.
- [V] `packages/omamobile-shell/plugins/omamobile.quicksettings/QuickSettings.qml:697-703,726-736` opens the picker as its own window, dismisses the parent quick-settings sheet, and routes `backRequested` to a new quick-settings sheet.
- [V] The Wi-Fi picker does not load `omamobile.back/BackLinkClient.qml` or register itself in the shared BackLink list [V: full-file search of `WifiPanel.qml` and `QuickSettings.qml` at the pinned source commit]. Its Escape path consequently depends on the panel having keyboard focus.
- [V] `packages/omamobile-shell/hypr/phone.lua:142-157` grants above-lock display/input rules only to the fingerprint target, on-screen keyboard, and call surfaces. `packages/omamobile-shell/plugins/README.md:791-798` explains that surfaces need an `above_lock` rule to appear above the lock and distinguishes display-only from input-taking rules.
- [I: `device/instantnoodlep/NOTES.md:85-90`; check on phone] The reported curved-edge dead zone can prevent the 14-pixel back strip from receiving a swipe at all; issue 001 proposes configurable per-device strip geometry. If the failure was seen while locked, the lock intentionally occludes both the picker and back strip. If it was seen while unlocked, focus-dependent Escape delivery is a second path worth making explicit.

[V] A minimal registration proposal is in `patches/0002-wifi-picker-register-back-link.patch`; it keeps the existing Escape path. [I] Device verification is pending; no single root cause is proven by the report.

## Proposed fix

- [I] Register the open Wi-Fi picker with `BackLinkClient.qml`, at the standard surface tier (last opened first; keyboard stays higher), and have its handler close a nested action/password sheet first or emit `backRequested` otherwise. That makes the shell's Back route target the picker directly instead of relying on whichever layer surface currently owns keyboard focus.
- [I] Keep the picker below the lock; close it or leave it hidden when the session locks rather than adding an input-taking `above_lock` rule. Preserve the visible header back button as a fallback.

## Verification requested

- [I] With the phone unlocked, test edge Back from the picker list and from a nested password/action sheet: one gesture should close one level, then a second should return to quick settings. Repeat after opening the on-screen keyboard to confirm the keyboard is hidden first.
- [I] Lock while the picker is open; confirm the lock screen covers it and remains unlockable. After unlocking, confirm there is no stranded picker or stale Back registration.
