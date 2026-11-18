#!/bin/bash
# SPDX-License-Identifier: MIT
# Runs inside the Arch Linux ARM aarch64 container: keyrings, full upgrade,
# base-devel plus the PKGBUILD's makedepends/checkdepends, then makepkg as
# "builder" on /work/omamobile-settings. The source tree is prepared on the
# host: upstream c4623572be1c141d602cf99a83ae0bf9e3eea09c with
# patches/omamobile-settings/0001-settings-security-page.patch applied via
# `git apply --directory=packages/omamobile-settings` (version 0.1.3); this
# script only builds and runs the package's own check() (test/all).
#
#   docker run --rm --platform linux/arm64 \
#     -v $B/work:/work -v $B/out:/out \
#     -v $B/build-in-container.sh:/build.sh:ro \
#     alarm-aarch64:20260805-42a4eeaa bash /build.sh
set -euo pipefail
date -u +"start %FT%TZ"
pacman-key --init >/dev/null 2>&1
pacman-key --populate archlinuxarm >/dev/null 2>&1
grep -q '^DisableSandbox' /etc/pacman.conf || sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf
pacman -Syu --noconfirm --needed base-devel git sudo >/dev/null
pacman -Rns --noconfirm linux-aarch64 >/dev/null 2>&1 || true
userdel -r alarm >/dev/null 2>&1 || true
useradd -m -u 1000 builder
sed -i 's/^#\\?MAKEFLAGS=.*/MAKEFLAGS="-j'"$(nproc)"'"/' /etc/makepkg.conf
cd /work/omamobile-settings
chown -R builder: /work/omamobile-settings /out
# makedepends + checkdepends of the patched PKGBUILD, plus qmake6 (qt6-base)
# for bin/build and qmllint (qt6-declarative) for test/security-static.sh.
# The runtime depends (omarchy, polkit, ...) are not in ALARM's repos, so
# makepkg runs with --nodeps.
pacman -S --noconfirm --needed gcc make qt6-base qt6-declarative qt6-svg dbus python curl >/dev/null
# ALARM aarch64 ships no shellcheck package (no Haskell stack in extra), but
# check() runs test/security-static.sh, which needs it: bootstrap the official
# static aarch64 binary with a pinned archive hash.
curl -fsSL -o /tmp/shellcheck.tar.xz \
  https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.aarch64.tar.xz
echo '324a7e89de8fa2aed0d0c28f3dab59cf84c6d74264022c00c22af665ed1a09bb  /tmp/shellcheck.tar.xz' | sha256sum -c -
tar -xJf /tmp/shellcheck.tar.xz -C /usr/local/bin --strip-components=1 shellcheck-v0.10.0/shellcheck
rm -f /tmp/shellcheck.tar.xz
shellcheck --version | head -1
pacman -Q gcc make qt6-base qt6-declarative qt6-svg dbus python 2>/dev/null || true
date -u +"makepkg %FT%TZ"
# qmllint lives in /usr/lib/qt6/bin (not /usr/bin) on ALARM; check() calls it
# by name through test/security-static.sh.
su builder -c "PATH=/usr/lib/qt6/bin:\$PATH PKGDEST=/out PKGEXT=.pkg.tar.zst makepkg -f --nodeps --noconfirm"
date -u +"end %FT%TZ"
ls -l /out
