<!-- SPDX-License-Identifier: MIT -->
# Upstream UI proposals, not posted upstream

[V] Research source: read-only clone of
<https://github.com/derekross/omarchy-mobile> at
`c4623572be1c141d602cf99a83ae0bf9e3eea09c`; its AGENTS.md and CONTRIBUTING.md
were read. Issue drafts 001–003 are for owner review only. The native Settings security
proposal is an implementation patch with package notes and an unposted issue
draft; no phone or upstream issue was used.

[V] Patch 1 adds bounded environment configuration and a provisional device
file; patch 2 registers the Wi-Fi picker with the existing BackLink dispatcher.
Neither patch is installed on a phone. The proposed device file is not a
complete device package: an eventual installer must copy it into
`/usr/lib/environment.d/`, following the panther package convention.
[I] 48/32 logical pixels are trial values, not calibrated hardware facts.
NOTES records corner taps, not an exhaustive edge sweep. A physical/logical
coordinate comparison also needs confirmation of compositor mapping and scale.

[V] Host validation on 2026-11-17:

- Both patches passed `git apply --check` separately against the pinned source,
  then applied together in a disposable clone.
- Upstream Node tests `back-link.js`, `back-model.js`, `wifi-model.js` passed.
- A temporary Node harness extracted `configuredPixels()` from patched QML:
  missing/empty/nonfinite inputs, clamping, default values and strip containment
  at width/inset bounds passed. A second harness exercised the exact proposed
  Wi-Fi handler with upstream BackLink.js: keyboard, nested sheet, panel, then
  fallback, with unregister on close.
- Upstream Qt `test/back-surfaces.py` returned 77 (qmltestrunner unavailable).
  No rendered QML, compositor, touchscreen or lock-session test ran.

[V] Source establishes the fixed mask, focus-dependent Wi-Fi Escape fallback,
and missing native Settings PIN route. [I] It does not establish the actual
cause of the owner's panel-exit failure, whether the session was locked, or
when/why the older Settings entry disappeared. The lock intentionally excludes
ordinary shell surfaces; changing its above-lock rules is not proposed.

[V] Coordinator verification gates, including stop and rollback conditions,
are in `device/instantnoodlep/SHELL-UX-PLAN.md`. Installation/restart is explicitly
blocked on checking the actual phone layout and recovery command: this research
worker has no phone access and supplies no guessed service name.

[V] The native Settings Security proposal is `patches/omamobile-settings/`
for upstream `omamobile-settings` 0.1.2 at the pinned source revision above.
It adds the account/PIN page, an opt-in distinct lock PIN PAM service, x86
static checks, and a container PAM test. Offline verification passed on
2026-11-18 (qmllint on all QML, qmake6 build, 61-check archlinux pamtester
container, shipped Debian fixture): exact commands and results are in
`patches/omamobile-settings/README.md`; PR #100 carries the summary. Phone
verification of the lock session remains pending.
