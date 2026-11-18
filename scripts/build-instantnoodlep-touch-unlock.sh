#!/bin/sh
# SPDX-License-Identifier: MIT
# Build the libc-only framebuffer/evdev unlock UI as a static executable.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
if [ "$#" -ne 1 ]; then
    echo "usage: CC=aarch64-linux-musl-gcc $0 OUTPUT" >&2
    exit 2
fi
cc=${CC:-aarch64-linux-musl-gcc}
out=$1
case $out in
    "$repo"/*) echo "output must stay outside the repository" >&2; exit 1 ;;
esac
command -v "$cc" >/dev/null 2>&1 || {
    echo "missing compiler: $cc" >&2
    exit 1
}
mkdir -p "$(dirname -- "$out")"
"$cc" -std=c11 -Os -static -s -Wall -Wextra -Werror \
    "$repo/device/instantnoodlep/initramfs/cryptroot-touch-unlock.c" \
    -o "$out"
file "$out"
