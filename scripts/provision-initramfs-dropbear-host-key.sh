#!/bin/sh
# SPDX-License-Identifier: MIT
# Run as root on the installed phone during setup; never run on the build host.

set -eu

key_dir=${1:-/etc/dropbear}
key="$key_dir/dropbear_ed25519_host_key"
public="$key.pub"
tmp_key=
tmp_key_public=
tmp_public=

fail() {
    echo "provision-initramfs-dropbear-host-key: $*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "run as root on the phone"
command -v ssh-keygen >/dev/null 2>&1 || fail "ssh-keygen is required"
mkdir -p "$key_dir"
chmod 0700 "$key_dir"
[ ! -L "$key" ] || fail "refusing a symlink at $key"
[ ! -L "$public" ] || fail "refusing a symlink at $public"

if [ ! -e "$key" ]; then
    umask 077
    tmp_key=$(mktemp "$key_dir/.dropbear-ed25519.XXXXXX")
    rm -f "$tmp_key"
    tmp_key_public=$tmp_key.pub
    trap 'rm -f "$tmp_key" "$tmp_key_public" "$tmp_public"' EXIT HUP INT TERM
    ssh-keygen -q -t ed25519 -N '' -C omamobile-initramfs-host -f "$tmp_key"
    [ -s "$tmp_key" ] || fail "dropbearkey produced no private key"
    chmod 0600 "$tmp_key"
    # A hard link creates the final name without replacing a concurrent key.
    if ! ln "$tmp_key" "$key" 2>/dev/null; then
        [ -s "$key" ] || fail "could not install the host key"
    fi
    rm -f "$tmp_key" "$tmp_key_public"
    tmp_key=
    tmp_key_public=
else
    [ -f "$key" ] || fail "existing host key is not a regular file"
    [ -s "$key" ] || fail "existing host key is empty"
    chmod 0600 "$key"
fi

umask 077
tmp_public=$(mktemp "$key_dir/.dropbear-ed25519.pub.XXXXXX")
ssh-keygen -y -f "$key" 2>/dev/null |
    awk '$1 == "ssh-ed25519" && NF >= 2 { print $1 " " $2; found++ }
         END { if (found != 1) exit 1 }' > "$tmp_public" ||
    fail "could not derive exactly one Ed25519 public key"
[ -s "$tmp_public" ] || fail "derived public key is empty"
chmod 0644 "$tmp_public"
mv -f "$tmp_public" "$public"
tmp_public=
trap - EXIT HUP INT TERM
echo "Dropbear Ed25519 host key is ready in $key_dir (private key mode 0600)."
