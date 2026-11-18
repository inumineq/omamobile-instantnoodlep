<!-- SPDX-License-Identifier: MIT -->
# Draft issue: add Security to native Settings

**Status:** Draft only; not posted. Upstream source checked read-only at
`derekross/omarchy-mobile` commit `c4623572be1c141d602cf99a83ae0bf9e3eea09c`.
The implementation proposal and packaging notes are in
[`patches/omamobile-settings/`](../../patches/omamobile-settings/).

## Observation

- [V] `packages/omamobile-settings/version` is `0.1.2`; its root catalog and
  `Main.qml` expose Display and About, with no Security page.
- [V] `packages/omamobile-shell/bin/omamobile-set-pin` still changes the
  account password and stores the selected PIN/password keyboard type.
- [V] The `ENCRYPTION-PLAN.md` credential model keeps the full account
  password for disk unlock, sudo and polkit, and proposes a separate
  lock-screen-only PIN with a ten-attempt lockout.

## Request

Add a native Security page for changing the lock-screen PIN, changing the
account password, and toggling the lock-screen numeric keypad. Use the on-screen
keyboard and report validation or authorization errors clearly. QML should
call a narrow polkit-authorized helper and must never create or handle password
hashes.

Keep today's single-secret behavior as the default. Offer separate lock-screen
PIN mode only as an explicit opt-in: save a distinct PIN hash, use it only in
the lock-screen PAM service, and retain the ten-try lockout without falling
back to the account password. `sudo`, polkit and disk unlock continue to use
the account password. Switching the option off restores the previous lock
PAM configuration.

## Verification requested

Run the package checks on x86, lint the QML and shell scripts, and use
`pamtester` with throwaway users in an isolated container to cover both modes,
account-password separation, rollback, and lockout. No issue has been posted
upstream.

**Status 2026-11-18:** the offline part is done — `qmllint` on every QML file
(0 errors), a clean `qmake6`/`make` build, static checks, a 61-check
`pamtester` matrix in a throwaway archlinux container, and the patch's own
Debian fixture all pass; commands and results in
[`patches/omamobile-settings/README.md`](../../patches/omamobile-settings/README.md).
Still pending: the real `pkexec` round trip and the phone lock session.
