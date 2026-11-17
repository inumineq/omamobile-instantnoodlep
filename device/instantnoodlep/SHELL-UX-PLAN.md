<!-- SPDX-License-Identifier: MIT -->
# Shell UI: offline proposals and attended verification

Status: 2026-11-17, shell-ux branch on obsidian. [V] Source research only;
no phone commands run. Upstream source is pinned to
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
   `uname -r; shell call omamobile.back state ''`
   Expect: record kernel release and JSON containing edge=14. Stop: command
   absent or unexpected shell version. Rollback: none (reads).
2. Offline, on a disposable clone of the pinned upstream source:
   `git apply --check /path/to/patches/0001-back-gesture-device-edge-geometry.patch`
   then `git apply /path/to/patches/0001-back-gesture-device-edge-geometry.patch`;
   repeat for patch 2. Expect: both apply without errors. Stop: any mismatch.
   Rollback: discard the disposable clone. Risk: local source files only.
3. [I] Integration gate: coordinator builds/stages the patched shell using the
   actual installed package workflow, backs up the existing package first and
   confirms the way to restore it over the existing remote terminal. No generic
   install command is supplied: installed package/version/layout is unverified.
   Do not restart a session until that concrete command and rollback are reviewed.
   Expect: package contains only reviewed changes. Stop: unknown layout, lost
   remote recovery, or package build failure. Rollback: restore original package.
4. With the patched shell installed and the owner ready, run in the existing
   phone shell:
   `systemctl --user set-environment OMAMOBILE_BACK_EDGE_INSET=48 OMAMOBILE_BACK_EDGE_WIDTH=32`
   Coordinator then uses the confirmed shell service restart command from step 3.
   Expect: `shell call omamobile.back state ''` shows edge=32, inset=48.
   Stop: QML errors, inaccessible UI or unexpected state. Rollback command:
   `systemctl --user unset-environment OMAMOBILE_BACK_EDGE_INSET OMAMOBILE_BACK_EDGE_WIDTH`
   then restore original shell package and restart via step 3's confirmed command.
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
