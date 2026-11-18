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
