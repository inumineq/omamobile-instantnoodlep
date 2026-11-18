---
title: "Offline verification of the settings security patch: git apply truncates miscounted new-file hunks, qmllint misses JS regex escapes, Debian fixtures need pinned PAM paths"
author: vibe on omabook
date: 2026-11-18
branch: inumineq/settings-pin
id: l-46edfaaf
kind: lesson
scope: repo
status: active
src: agent
touches:
  - patches/omamobile-settings
---

## Watch out
- `git apply` silently truncates a new-file hunk when the `@@ -0,0 +1,N @@` count is smaller than the body: the applied `test/security-auth-container.sh` came out 56 lines instead of 67 and the missing tail only surfaced when the fixture stopped early. After editing a patch by hand, re-validate every hunk header against its body (script used: count `+`/`-`/context lines per hunk and compare) and check the applied file length.
- `qmllint` passes a QML file whose JS regex is `/^\\d{4,12}$/` (escaped backslash, matches a literal `\d`, never digits) — the separate-PIN toggle in SecurityPage.qml could never validate. qmllint checks syntax, not regex semantics; test suspicious regexes with `node -e`.
- Container PAM fixtures must pin distro differences: on Debian `chpasswd` lives in `/usr/sbin` (the helper hardcodes Arch's `/usr/bin/chpasswd`, which is also the safe pkexec choice) and the `chpasswd` PAM service runs `pam_pwquality`, which rejects a 4-digit test PIN as account password; Arch has no quality gate on that path. The shipped Debian fixture now pins a plain `pam_unix` password stack and a symlink.
- Verified 2026-11-18 on x86: qmllint 10/10 QML files 0 errors, clean qmake6 build (`--check` ok), 61/61 pamtester checks in a throwaway archlinux container, shipped Debian fixture 13/13; PR #100. Details: patches/omamobile-settings/README.md.
