<!-- SPDX-License-Identifier: MIT -->
# Draft issue: expose PIN management from native Settings

**Status:** Draft only; not posted. Source checked at `derekross/omarchy-mobile` commit `c4623572be1c141d602cf99a83ae0bf9e3eea09c`.

## Observation

- [V] `packages/omamobile-settings/version:1` is version `0.1.2`.
- [V] The root catalog at `packages/omamobile-settings/app/catalog.json:2-19` has exactly two rows: Display and About this device. `packages/omamobile-settings/app/Main.qml:27-29,63-68` has a custom page mapping only for Display and renders the About page; no PIN route/page is present in the native Settings catalog or page map.
- [V] PIN setup still exists as `packages/omamobile-shell/bin/omamobile-set-pin:3-15,42-77`; it configures the account password used by Omarchy's lock and records only whether the credential is a PIN or password.
- [V] `packages/omamobile-shell/bin/omamobile-setup-user:462-468` adds a `System > PIN` Omarchy menu action invoking `omamobile-set-pin`. This is separate from the native `omamobile-settings` app.

## Request

- [I] Please add a discoverable PIN/credential entry to native Settings that invokes the existing safe setup flow, or provide a clear link to the existing `System > PIN` action. Avoid duplicating credential-setting logic in the Settings application.
- [I] Please clarify whether the absence from the native Settings catalog is intentional; the current source confirms absence from the 0.1.2 app but does not establish when or why an older page was removed.

## Verification requested

- [I] Confirm the new Settings entry is visible and opens the existing `omamobile-set-pin` flow; verify no credential secret is logged or written outside the established PAM and credential-type behavior.
