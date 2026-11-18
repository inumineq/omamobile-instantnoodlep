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
pacman -S --noconfirm --needed shellcheck >/dev/null
cd /work/repo/packages/omamobile-device-instantnoodlep
chown -R builder: /work/repo /out
date -u +"makepkg %FT%TZ"
su builder -c "PKGDEST=/out PKGEXT=.pkg.tar.zst makepkg -f --nodeps --noconfirm"
date -u +"end %FT%TZ"
ls -l /out
