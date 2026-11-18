---
title: "Signed local overrides must follow upstream repo priority"
author: claude on omabook
date: 2026-11-18
branch: inumineq/local-repo
id: l-7fb99c45
kind: decision
scope: repo
status: active
src: agent
touches:
  - tools/omamobile-localrepo
  - device/instantnoodlep/LOCAL-REPO-PLAN.md
---

## Decided
- [V: Arch `pacman.conf(5)`, repository sections; Arch `pacman(8)`, `--sysupgrade`] Keep `[omamobile-local]` after `[omamobile]` so the upstream repository has first priority for duplicate names. Explicitly qualify local package names on the first install; `pacman -Syu` updates only when the selected earlier-repo version is newer than the installed version.
- [V: Arch `repo-add(8)` and x86 `tests/localrepo.sh`] Sign each package archive, embed its signature with `repo-add --include-sigs`, and sign the repository database. Test keys and package archives belong only in a disposable temporary directory.
- [I] The package source transition and public-key trust operation remain phone-gated; do not infer their success from workstation signatures or dummy package tests.

## Watch out
- [I] When upstream reaches an equal package version, pacman will not replace an already-installed equal version solely because it came from an earlier repository. Confirm matching upstream contents, remove the local DB entry and explicitly reinstall from `[omamobile]` before dropping the local override.
- Never export or copy the private signing key into the build container, phone, repository directory, or git checkout.
