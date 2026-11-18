#!/bin/bash
# SPDX-License-Identifier: MIT
# Runs inside the Arch Linux ARM aarch64 container from the staged repository tree under /work/repo.
# It runs the package's host-only checks but does not sign the resulting archive;
# the dedicated local-repository key stays on the owner's workstation.
#
#   docker run --rm --platform linux/arm64 \
#     -v "$B/work/repo:/work/repo" -v "$B/out:/out" \
#     -v "$B/devicepkg-build-in-alarm.sh:/build.sh:ro" \
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
sed -i 's/^#\?MAKEFLAGS=.*/MAKEFLAGS="-j'"$(nproc)"'"/' /etc/makepkg.conf
# ALARM aarch64 ships no shellcheck package (no Haskell stack in extra), but
# the package's check() runs test/all, which needs it: bootstrap the official
# static aarch64 binary with a pinned archive hash.
pacman -S --noconfirm --needed curl >/dev/null
curl -fsSL -o /tmp/shellcheck.tar.xz \
  https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.aarch64.tar.xz
echo '324a7e89de8fa2aed0d0c28f3dab59cf84c6d74264022c00c22af665ed1a09bb  /tmp/shellcheck.tar.xz' | sha256sum -c -
tar -xJf /tmp/shellcheck.tar.xz -C /usr/local/bin --strip-components=1 shellcheck-v0.10.0/shellcheck
rm -f /tmp/shellcheck.tar.xz
shellcheck --version | head -1
cd /work/repo/packages/omamobile-device-instantnoodlep
chown -R builder: /work/repo /out
date -u +"makepkg %FT%TZ"
su builder -c "PKGDEST=/out PKGEXT=.pkg.tar.zst makepkg -f --nodeps --noconfirm"
date -u +"end %FT%TZ"
ls -l /out
