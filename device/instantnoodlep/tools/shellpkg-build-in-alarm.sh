#!/bin/bash
# SPDX-License-Identifier: MIT
# Runs inside the Arch Linux ARM aarch64 container: keyrings, full upgrade,
# base-devel and the check tools, then makepkg as "builder" on
# /work/omamobile-shell. The source tree is prepared on the host with patches
# 0001-0004 and local pkgrel=2 (see SHELL-UX-PLAN); this script only builds.
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
sed -i 's/^#\?MAKEFLAGS=.*/MAKEFLAGS="-j'"$(nproc)"'"/' /etc/makepkg.conf
cd /work/omamobile-shell
chown -R builder: /work/omamobile-shell /out
# The package's own checkdepends (nodejs) plus what test/all needs to run
# rather than skip: jq, python-dbus and python-gobject (test/call-watch.py
# imports dbus), and qt6-declarative's qmlformat (the patched QML has to
# parse) and qmltestrunner (the offscreen touch tests). The runtime depends
# are not installed: omarchy, squeekboard and the rest are not in ALARM's
# repos, and makepkg runs with --nodeps.
pacman -S --noconfirm --needed nodejs jq python-dbus python-gobject qt6-declarative >/dev/null
pacman -Q nodejs jq python-dbus python-gobject qt6-declarative 2>/dev/null || true
date -u +"makepkg %FT%TZ"
su builder -c "PKGDEST=/out PKGEXT=.pkg.tar.zst makepkg -f --nodeps --noconfirm"
date -u +"end %FT%TZ"
ls -l /out
