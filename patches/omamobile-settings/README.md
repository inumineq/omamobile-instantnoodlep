<!-- SPDX-License-Identifier: MIT -->
# Native Settings Security patch

This patch targets upstream `omamobile-settings` 0.1.2 at commit
`c4623572be1c141d602cf99a83ae0bf9e3eea09c`. It bumps to 0.1.3 and adds a
Security page, a narrow `pkexec` helper, and a separate lock-screen PAM branch
that remains disabled until the user opts in.

From the upstream checkout root, apply with:

```sh
git apply --check --directory=packages/omamobile-settings \
  /path/to/this/repository/patches/omamobile-settings/0001-settings-security-page.patch
git apply --directory=packages/omamobile-settings \
  /path/to/this/repository/patches/omamobile-settings/0001-settings-security-page.patch
```

The default PIN action updates the account password as the existing script
does. Enabling separate PIN mode collects a PIN in the UI, writes a distinct
SHA-512 crypt hash under `/var/lib/omamobile/lock-pin/<uid>`, and updates the
lock PAM service for only that UID. The hash is root-owned, mode 0640, and
readable only through the user's private primary group; setup refuses a shared
primary group. QML sends secrets to `pkexec` on stdin; it never handles hashes.
The PAM helper verifies the hash, `pam_faillock` enforces ten attempts, and
opted-in accounts cannot fall through to account-password authentication.
Other accounts retain the standard lock password stack. `sudo`, polkit, and
disk unlock continue to use the full account password. Opt-out restores the
saved PAM file; package removal is refused while the separate mode is active.

No account or PAM changes happen at package install time. No upstream issue
has been posted; the issue text is included in the internal PR body.

## Offline x86 checks

Run these in an x86 Arch package container with `qmake6`, `make`, `dbus-run-session`,
`qmllint`, `shellcheck`, and Python installed:

```sh
test/all
```

The PAM integration test runs in its own Debian container and creates only
throwaway accounts inside it:

```sh
docker build -f tests/security-auth.Dockerfile -t omamobile-settings-security-test .
docker run --rm omamobile-settings-security-test
```

It uses `pamtester` for default PIN/password behavior, the distinct PIN,
no-fallback behavior, non-opted-in accounts, PAM restoration, and ten-failure
lockout. No phone is used.

## Offline verification log (2026-11-18, x86 laptop + throwaway containers)

All checks below were run read-only against the upstream tarball; nothing was
pushed upstream and no phone was used. Throwaway test secrets only.

1. Fetch and apply (read-only):

   ```sh
   curl -sL -o omamobile.tar.gz \
     https://github.com/derekross/omarchy-mobile/archive/c4623572be1c141d602cf99a83ae0bf9e3eea09c.tar.gz
   tar xzf omamobile.tar.gz && cd omarchy-mobile-c4623572be1c141d602cf99a83ae0bf9e3eea09c
   git init -q && git add -A && git commit -qm "upstream c4623572"
   git apply --check --directory=packages/omamobile-settings \
     /path/to/this/repository/patches/omamobile-settings/0001-settings-security-page.patch
   git apply --directory=packages/omamobile-settings \
     /path/to/this/repository/patches/omamobile-settings/0001-settings-security-page.patch
   ```

   Result: `git apply --check` and apply both clean; `packages/omamobile-settings/version`
   becomes `0.1.3`. Every hunk header was re-validated against its body after
   editing (see "Fixes" below).

2. qmllint on every QML file (Qt 6.12.0, `/usr/lib/qt6/bin/qmllint`):

   ```sh
   cd packages/omamobile-settings
   for f in app/*.qml; do /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml "$f"; done
   ```

   Result: all 10 files (`AboutPage`, `DisplayPage`, `Main`, `SecurityPage`,
   `SettingsButton`, `SettingsItemDelegate`, `SettingsLabel`, `SettingsScrollBar`,
   `SettingsStyle`, `SettingsTextField`) exit 0 with **0 errors**; only the same
   warning classes (`unqualified`, `missing-property`, `layout-positioning`)
   that the untouched upstream files already produce.

3. Build as upstream does (`bin/build` = `qmake6` + `make`), plus smoke test:

   ```sh
   PATH=/usr/lib/qt6/bin:$PATH OMAMOBILE_SETTINGS_BUILD_DIR="$PWD/../build-app" ./bin/build
   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ../build-app/omamobile-settings --version
   HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
     ../build-app/omamobile-settings --check
   ```

   Result: clean compile with `-Wall -Wextra` (no warnings), binary produced;
   `--version` prints `omamobile-settings 0.1.3`; `--check` prints
   `{"errors":[],"ok":true}` (the catalog accepts the new Security page).

4. Static checks: `python3 -m py_compile bin/credentials-helper bin/verify-lock-pin`,
   `bash -n` on `omamobile-settings.install`, `test/security-auth-container.sh`,
   `test/security-static.sh`, `test/all`, `bin/build`, `install`; `sh -n` on
   `test/security-static.sh`; `git diff --check`; `shellcheck` on the three added
   shell scripts (run inside the container, which has shellcheck). All pass.

5. PAM verification in a throwaway **archlinux** container (the harness is
   `verification/Dockerfile` + `verification/pam-verify.sh`):

   ```sh
   stage=$(mktemp -d)
   cp -r packages/omamobile-settings "$stage/omamobile-settings"   # patch applied
   cp verification/Dockerfile verification/pam-verify.sh "$stage/"
   docker build -t omamobile-settings-pam-verify "$stage"
   docker run --rm omamobile-settings-pam-verify
   ```

   The container installs the helper and polkit policy exactly like the package
   `install` script, builds `pamtester` 0.1.2 from the AUR, creates throwaway
   users (`pinuser`, `plainuser`, `lockuser`) with throwaway passwords/PINs,
   and runs the helper as root with `PKEXEC_UID` (the same contract `pkexec`
   provides; the polkit daemon itself is not run in the container).

   Result: `RESULT: pass=61 fail=0`, exit 0. Proven with `pamtester`:

   - option OFF (default): the account password authenticates the
     `omarchy-lock-password` lock service, a separate PIN does not; `sudo` and
     `polkit-1` accept the password and reject the PIN; the keypad toggle and
     `set-pin` leave `/etc/pam.d/omarchy-lock-password` byte-identical and
     create no roster — nothing changes. `set-pin` in default mode still sets
     the account password (single secret).
   - option ON (`set-separate-pin`): the PIN unlocks the lock service only
     then; the PIN hash is `root:<private primary group>`, mode `0640`; the
     account password does **not** fall through on the lock service
     (two-secret design); `sudo` and `polkit-1` reject the PIN and accept the
     account password; a non-opted-in account keeps password auth on the lock
     service; changing the account password leaves the lock PIN working.
   - ten wrong PIN attempts lock the account out (`pam_faillock` `deny=10
     unlock_time=120`): the correct PIN is then rejected and the tally file
     exists.
   - opt-out (`use-account-password`): with one user left opted in the roster,
     backup and rendered PAM stay; after the last opt-out the lock PAM service
     is byte-identical to stock again, backup/roster/hash removed, the account
     password works on the lock service again and the PIN no longer does.
   - helper validation: 3-digit PIN and mismatched confirm rejected; the
     helper refuses to run unprivileged and refuses `PKEXEC_UID=0`.

6. The shipped Debian fixture (above) also passes after the fixes below:
   `docker run --rm omamobile-settings-security-test` prints 13 `ok` lines,
   exit 0.

### Fixes applied during this verification

- `app/SecurityPage.qml`: the separate-PIN toggle validated with
  `/^\\d{4,12}$/` (matches a literal backslash + `d`, never digits —
  `node -e '/^\\d{4,12}$/.test("1357")' === false`), so the toggle could never
  enable the mode. Now `/^\d{4,12}$/`, same as the PIN field.
- `test/security-auth-container.sh` (Debian fixture): pinned a plain
  `pam_unix` password stack for the `chpasswd` PAM service (Debian runs
  `pam_pwquality` there and refuses the 4-digit test PIN as account password;
  Arch, the target, has no quality gate on that path) and symlinked
  `/usr/sbin/chpasswd` to `/usr/bin/chpasswd` (the helper hardcodes the Arch
  path, which is also the safe choice under `pkexec`). Two expectations were
  wrong: after `set-pin 2468` in default mode the account password *is*
  `2468`, so the later sudo/no-fallthrough checks now use `2468`.
- The new-file hunk header for `test/security-auth-container.sh` said `+1,56`
  while the body had more lines; `git apply` silently truncated the applied
  file. The header now matches the body (all 23 hunk headers re-validated).

### Fix found by the 2026-11-18 aarch64 package build

The first ALARM build of this patch failed the package's own `check()`:
`CoreTests::navigationRejectsUnknownAndHiddenActions()` expected 2 root rows,
but the Security row makes 3. `tests/core_tests.cpp` now expects 3 and
navigates to `security` and back. The same build then failed to link
`tests/session_app.pro` (`main.cpp` references `CredentialsController`, which
only `omamobile-settings.pro` listed); the session test app now links
`credentialscontroller.{h,cpp}` like the main app. The patch was regenerated
from the applied tree (so every hunk header matches its body) and re-validated
with `git apply --check` against pristine `c462357`.

Not verified offline (still pending): the `pkexec`/polkit agent round trip on
a real session, the lock screen itself on the phone, and the D-Bus single
instance fixture in `test/all` (needs `shellcheck` on the build host; its
components were run individually here).
