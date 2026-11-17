<!-- SPDX-License-Identifier: MIT -->
# Draft issue: make the back gesture edge configurable per device

**Status:** Draft only; not posted. Source checked at `derekross/omarchy-mobile` commit `c4623572be1c141d602cf99a83ae0bf9e3eea09c`.

## Problem

- [V] `packages/omamobile-shell/plugins/omamobile.back/Back.qml:74-77,149-160` defines a fixed 14-pixel edge strip, masks input to that strip, and places it flush against the physical screen edge. `Back.qml:164-188` handles the drag and invokes Back when the threshold is crossed.
- [V] `packages/omamobile-shell/plugins/omamobile.back/BackModel.js:50-67` uses a 56-pixel inward swipe threshold.
- [I: `device/instantnoodlep/NOTES.md:85-90`; check on phone] On IN2023, the smallest recorded left corner tap is x=144; this does not establish the minimum reachable touch coordinate, while the gesture strip starts at x=0. With the session's display scale of 3 [V: `device/instantnoodlep/NOTES.md:157-159`], 144 physical pixels would map to 48 logical pixels if the mapping is linear. If an attended edge sweep confirms that boundary, touches cannot start inside the current 14-pixel strip.

## Request

- [I] Read a bounded strip width and symmetric inset from environment variables, with the current 14-pixel/zero-inset defaults for other devices. Keep the input mask limited to the configured strip and move the arrow with it.
- [I] The proposed starting values for instantnoodlep are `OMAMOBILE_BACK_EDGE_INSET=48` and `OMAMOBILE_BACK_EDGE_WIDTH=32` compositor logical pixels. They are provisional until an attended touch test confirms both sides.
- [V] `packages/omamobile-device-panther/install:37-40` and `packages/omamobile-device-panther/vendor/environment.d/40-omamobile-rotation.conf:1-6` show the existing device-package pattern for installing device environment overrides. The proposed patch is `patches/0001-back-gesture-device-edge-geometry.patch`.

## Verification requested

- [I] On the phone, open a screen with no on-screen keyboard and test a back swipe beginning in each configured strip, then repeat with the Wi-Fi picker open. Confirm the arrow follows the finger, a qualifying swipe invokes exactly one Back, and a short/vertical swipe does not.
- [I] While the phone is locked, confirm the lock remains the input surface and the Wi-Fi picker is not exposed above it; do not add an `above_lock` rule for the picker as part of this change.
