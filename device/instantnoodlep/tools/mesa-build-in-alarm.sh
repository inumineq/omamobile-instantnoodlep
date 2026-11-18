#!/bin/bash
# SPDX-License-Identifier: MIT
# Runs inside the Arch Linux ARM aarch64 container: keyrings, full upgrade,
# base-devel + the PKGBUILD's makedepends, then makepkg as "builder".
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
cd /work/mesa
chown -R builder: /work /srcdest /out
deps=$(su builder -c "makepkg --printsrcinfo" | awk -F' = ' '/^\t(make)?depends = /{print $2}' | sort -u)
# shellcheck disable=SC2086 # Split .SRCINFO dependencies into separate arguments.
pacman -S --noconfirm --needed $deps >/dev/null
pacman -Q mesa llvm clang meson glslang libdrm spirv-tools 2>/dev/null || true
su builder -c "gpg -q --batch --import /work/pgp.asc"
date -u +"makepkg %FT%TZ"
su builder -c "SRCDEST=/srcdest PKGDEST=/out PKGEXT=.pkg.tar.zst makepkg -f --nodeps --noconfirm --nocheck"
date -u +"end %FT%TZ"
ls -l /out
