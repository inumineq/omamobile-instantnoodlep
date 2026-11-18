#!/bin/sh
# SPDX-License-Identifier: MIT
# Prepare the offline aarch64 Alpine root that tools/build-instantnoodlep-
# probe takes as --initramfs-root. Laptop only: this script never contacts a
# phone and never executes an aarch64 binary. The x86_64 apk.static verifies
# every target package against Alpine's published keys.
#
# Usage:
#   scripts/prepare-initramfs-root.sh [--root DIR] [--kernel-build DIR]
#       [--dropbear-host-key PHONE_KEY_COPY] [--dry-run]
#       [--touch-unlock-bin STATIC_AARCH64_BINARY]
#
# --root defaults to ~/android/build/initramfs-root and must stay outside
# this repository; downloads are cached beside it in <root>.cache. Re-running
# is safe: already-installed packages are left alone, and the module tree is
# only touched when --kernel-build names a CONFIG_QCOM_WDT=m build.
#
# --kernel-build is optional. With CONFIG_QCOM_WDT=y (the K1 configuration)
# the watchdog driver is built in, /dev/watchdog0 exists without any module,
# and the probe init's "modprobe qcom_wdt || ..." falls through, so no module
# tree is installed. With CONFIG_QCOM_WDT=m the script runs "make
# modules_install INSTALL_MOD_PATH=<root>" in that build directory (host tools
# only; the build must be finished first, never run a second make in a tree
# that is still building), keeps only qcom_wdt plus its dependency closure,
# and writes modules.dep with host depmod. Without --kernel-build only the
# Alpine package set is prepared.
#
# Alpine v3.22 is pinned because both upstream probe builders use it at
# derekross/omarchy-mobile 6c11752ae4c3 (tools/build-flame-probe runs
# alpine:3.22; tools/dipper/build defaults ALPINE to alpine:3.22). The package
# set is dipper's: alpine-baselayout busybox busybox-extras dropbear iproute2
# util-linux e2fsprogs e2fsprogs-extra kmod cryptsetup.
#
# --dropbear-host-key imports the Ed25519 private key generated on the phone
# by scripts/provision-initramfs-dropbear-host-key.sh. Pass a secured copy of
# the phone's /etc/dropbear/dropbear_ed25519_host_key; the private key is
# copied only to OUT (which must be outside the repository), never tracked.
#
# apk-tools-static comes from the official Alpine CDN and is verified two
# ways: the pinned SHA256 values below, recorded from dl-cdn.alpinelinux.org
# over HTTPS on 2026-11-16, and Alpine's RSA signature over sbin/apk.static,
# checked with openssl against the keys shipped in the pinned alpine-keys
# package. --allow-untrusted is never used. --no-scripts also skips Alpine's
# busybox trigger (an aarch64 script), so the applet symlinks are created on
# the host from the /etc/busybox-paths.d lists the packages ship.

set -eu

ALPINE_RELEASE=v3.22
CDN=https://dl-cdn.alpinelinux.org/alpine
APK_TOOLS_VERSION=2.14.13-r0
APK_TOOLS_SHA256=d78d2a9ebadc8179b3b9063c3316e948f594c833db51eaeabe67f1d044245527
APK_STATIC_SHA256=99b6de1fdd5725b22f316e00be64e80fb3c708c5eba4ffebbcfe18dcec469aee
ALPINE_KEYS_VERSION=2.5-r0
ALPINE_KEYS_SHA256=1069fa68769607690e46b0d689f1ad9b5e346be2752ece313685b4f29ec70e25
PACKAGES='alpine-baselayout busybox busybox-extras dropbear iproute2 util-linux e2fsprogs e2fsprogs-extra kmod cryptsetup'

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
OUT=$HOME/android/build/initramfs-root
KERNEL_BUILD=
DROPBEAR_HOST_KEY=
TOUCH_UNLOCK_BIN=
DRY=0

usage() {
    sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "missing host tool: $1"
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --kernel-build)
            [ "$#" -ge 2 ] || die "--kernel-build needs a directory"
            KERNEL_BUILD=$2
            shift
            ;;
        --dropbear-host-key)
            [ "$#" -ge 2 ] || die "--dropbear-host-key needs a file path"
            DROPBEAR_HOST_KEY=$2
            shift
            ;;
        --touch-unlock-bin)
            [ "$#" -ge 2 ] || die "--touch-unlock-bin needs a binary path"
            TOUCH_UNLOCK_BIN=$2
            shift
            ;;
        --root)
            [ "$#" -ge 2 ] || die "--root needs a directory"
            OUT=$2
            shift
            ;;
        --dry-run)
            DRY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
    shift
done

[ "$(uname -m)" = x86_64 ] || die "this script bootstraps on x86_64 only (got $(uname -m))"
need readlink
OUT=$(readlink -m "$OUT")
CACHE=${CACHE_DIR:-$OUT.cache}
case $OUT/ in
    "$REPO_ROOT"/*) die "--root must be outside $REPO_ROOT" ;;
esac
case $CACHE/ in
    "$REPO_ROOT"/*) die "the download cache must be outside $REPO_ROOT" ;;
esac
[ "$OUT" != / ] && [ -n "$OUT" ] || die "--root must not be / or empty"

if [ -n "$DROPBEAR_HOST_KEY" ]; then
    need stat
    [ ! -L "$DROPBEAR_HOST_KEY" ] ||
        die "--dropbear-host-key must not be a symlink"
    DROPBEAR_HOST_KEY=$(readlink -e "$DROPBEAR_HOST_KEY") ||
        die "--dropbear-host-key does not exist"
    case $DROPBEAR_HOST_KEY in
        "$REPO_ROOT"/*) die "private host keys must stay outside the repository" ;;
    esac
    [ -f "$DROPBEAR_HOST_KEY" ] ||
        die "--dropbear-host-key must be a regular, non-symlink file"
    [ "$(stat -c %a "$DROPBEAR_HOST_KEY")" = 600 ] ||
        die "private host key mode must be 0600"
    [ -f "$DROPBEAR_HOST_KEY.pub" ] && [ ! -L "$DROPBEAR_HOST_KEY.pub" ] ||
        die "matching .pub file is required"
    [ "$(stat -c %a "$DROPBEAR_HOST_KEY.pub")" = 644 ] ||
        die "public host key mode must be 0644"
    awk 'NR == 1 && $1 == "ssh-ed25519" && NF == 2 { valid=1 }
         END { exit !valid }' "$DROPBEAR_HOST_KEY.pub" ||
        die "matching .pub file must contain one ssh-ed25519 key"
fi
if [ -n "$TOUCH_UNLOCK_BIN" ]; then
    [ -f "$TOUCH_UNLOCK_BIN" ] && [ ! -L "$TOUCH_UNLOCK_BIN" ] ||
        die "--touch-unlock-bin must be a regular, non-symlink file"
    TOUCH_UNLOCK_BIN=$(readlink -e "$TOUCH_UNLOCK_BIN") ||
        die "--touch-unlock-bin does not exist"
    case $TOUCH_UNLOCK_BIN in
        "$REPO_ROOT"/*) die "touch-unlock binary input must stay outside the repository" ;;
    esac
    need file
    file -b "$TOUCH_UNLOCK_BIN" | grep -q 'statically linked' ||
        die "--touch-unlock-bin must be statically linked"
    file -b "$TOUCH_UNLOCK_BIN" | grep -q 'ARM aarch64' ||
        die "--touch-unlock-bin must target aarch64"
fi

APK_TOOLS_APK=apk-tools-static-$APK_TOOLS_VERSION.apk
ALPINE_KEYS_APK=alpine-keys-$ALPINE_KEYS_VERSION.apk
APK_TOOLS_URL=$CDN/$ALPINE_RELEASE/main/x86_64/$APK_TOOLS_APK
ALPINE_KEYS_URL=$CDN/$ALPINE_RELEASE/main/x86_64/$ALPINE_KEYS_APK
REPOSITORY=$CDN/$ALPINE_RELEASE/main

if [ "$DRY" = 1 ]; then
    cat <<EOF
Dry run only; no files would be changed.
Host arch: $(uname -m)
Alpine release: $ALPINE_RELEASE (matches upstream flame and dipper at 6c11752ae4c3)
Root: $OUT
Cache: $CACHE
Download and pin-verify: $APK_TOOLS_URL
  apk sha256: $APK_TOOLS_SHA256
Download and pin-verify: $ALPINE_KEYS_URL
  apk sha256: $ALPINE_KEYS_SHA256
Extract sbin/apk.static, check its sha256 ($APK_STATIC_SHA256) and Alpine's
RSA signature over it against the keys from the pinned alpine-keys package.
Run the verified x86_64 apk.static with --arch aarch64 --root <root> --initdb
  --no-scripts --no-cache, repository $REPOSITORY, Alpine keys, never
  --allow-untrusted, installing: $PACKAGES
Then create the busybox applet symlinks on the host from etc/busybox-paths.d.
Kernel build: ${KERNEL_BUILD:-none given; only the Alpine package set}
Dropbear host key: ${DROPBEAR_HOST_KEY:-not imported; initramfs dropbear will create ephemeral keys}
Touch unlock binary: ${TOUCH_UNLOCK_BIN:-not imported; USB SSH path only}
No aarch64 binary would be executed.
EOF
    exit 0
fi

for tool in awk cat cp curl depmod dirname find grep install make mkdir mktemp modinfo mv openssl rm sed sha256sum tar tr uname; do
    need "$tool"
done

fetch_verify() { # URL SHA256 destination
    fv_url=$1
    fv_sum=$2
    fv_dest=$3
    if [ ! -f "$fv_dest" ]; then
        printf 'Downloading %s\n' "$fv_url"
        curl -fL --retry 3 -o "$fv_dest.download" "$fv_url"
        mv "$fv_dest.download" "$fv_dest"
    fi
    fv_actual=$(sha256sum "$fv_dest" | awk '{print $1}')
    [ "$fv_actual" = "$fv_sum" ] || {
        rm -f "$fv_dest"
        die "SHA256 mismatch for $fv_url (expected $fv_sum, got $fv_actual)"
    }
}

mkdir -p "$OUT" "$CACHE"
WORK=$(mktemp -d "$OUT.work.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

fetch_verify "$APK_TOOLS_URL" "$APK_TOOLS_SHA256" "$CACHE/$APK_TOOLS_APK"
fetch_verify "$ALPINE_KEYS_URL" "$ALPINE_KEYS_SHA256" "$CACHE/$ALPINE_KEYS_APK"

# Extract the static apk and Alpine's published signing keys.
mkdir -p "$WORK/apk" "$WORK/keytree" "$WORK/keys"
tar -xzf "$CACHE/$APK_TOOLS_APK" -C "$WORK/apk" sbin/apk.static 2>/dev/null
APK_STATIC=$WORK/apk/sbin/apk.static
[ -f "$APK_STATIC" ] || die "apk-tools-static did not contain sbin/apk.static"
APK_STATIC_SHA=$(sha256sum "$APK_STATIC" | awk '{print $1}')
[ "$APK_STATIC_SHA" = "$APK_STATIC_SHA256" ] ||
    die "apk.static sha256 mismatch (expected $APK_STATIC_SHA256, got $APK_STATIC_SHA)"
chmod +x "$APK_STATIC"

tar -xzf "$CACHE/$ALPINE_KEYS_APK" -C "$WORK/keytree" usr/share/apk/keys 2>/dev/null
cp "$WORK/keytree/usr/share/apk/keys/"*.rsa.pub "$WORK/keys/"
[ -n "$(find "$WORK/keys" -name '*.rsa.pub' -print -quit)" ] ||
    die "the pinned alpine-keys package shipped no signing keys"

# Verify Alpine's RSA signature over apk.static with the published keys.
SIG_MEMBER=$(tar -tzf "$CACHE/$APK_TOOLS_APK" 2>/dev/null |
    grep -E 'sbin/apk\.static\.SIGN\.RSA\.sha256\..+\.rsa\.pub$' | head -n 1)
[ -n "$SIG_MEMBER" ] || die "apk-tools-static carries no sha256 signature for apk.static"
tar -xzf "$CACHE/$APK_TOOLS_APK" -C "$WORK/apk" "$SIG_MEMBER" 2>/dev/null
sig_ok=0
for key in "$WORK/keys/"*.rsa.pub; do
    [ -e "$key" ] || continue
    if openssl dgst -sha256 -verify "$key" \
            -signature "$WORK/apk/$SIG_MEMBER" "$APK_STATIC" >/dev/null 2>&1; then
        sig_ok=1
        SIGN_KEY=$key
        break
    fi
done
[ "$sig_ok" = 1 ] || die "apk.static's signature did not verify against Alpine's published keys"
printf 'apk.static sha256 verified and signed by %s\n' "$(basename "$SIGN_KEY")"

printf 'Installing Alpine %s aarch64 packages into %s\n' "$ALPINE_RELEASE" "$OUT"
# Word splitting is intentional: PACKAGES is the fixed literal list above.
# shellcheck disable=SC2086
"$APK_STATIC" --arch aarch64 --root "$OUT" --initdb --no-scripts \
    --no-cache --repository "$REPOSITORY" --keys-dir "$WORK/keys" \
    add $PACKAGES

# --no-scripts skips Alpine's busybox trigger, which would run an aarch64
# binary. Create the applet symlinks on the host instead, from the path lists
# the busybox packages ship in /etc/busybox-paths.d, never overwriting a real
# binary another package installed (e.g. util-linux's /bin/mount).
for paths in "$OUT"/etc/busybox-paths.d/*; do
    [ -e "$paths" ] || continue
    applet_bin=/bin/$(basename "$paths")
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        case $rel in
            /*|*..*) die "unexpected applet path in $paths: $rel" ;;
        esac
        dest=$OUT/$rel
        if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            ln -s "$applet_bin" "$dest"
        fi
    done < "$paths"
done
[ -e "$OUT/bin/busybox" ] || die "busybox did not land at bin/busybox"
[ -e "$OUT/usr/sbin/dropbear" ] || die "dropbear did not land at usr/sbin/dropbear"

if [ -n "$DROPBEAR_HOST_KEY" ]; then
    mkdir -p "$OUT/etc/dropbear"
    cp "$DROPBEAR_HOST_KEY" "$OUT/etc/dropbear/dropbear_ed25519_host_key"
    cp "$DROPBEAR_HOST_KEY.pub" "$OUT/etc/dropbear/dropbear_ed25519_host_key.pub"
    chmod 0600 "$OUT/etc/dropbear/dropbear_ed25519_host_key"
    chmod 0644 "$OUT/etc/dropbear/dropbear_ed25519_host_key.pub"
fi
if [ -n "$TOUCH_UNLOCK_BIN" ]; then
    mkdir -p "$OUT/usr/local/sbin"
    install -m 0755 "$TOUCH_UNLOCK_BIN" \
        "$OUT/usr/local/sbin/cryptroot-touch-unlock"
fi

KERNEL_RELEASE=
WDT_MODE=none
if [ -n "$KERNEL_BUILD" ]; then
    KERNEL_INPUT=$KERNEL_BUILD
    KERNEL_BUILD=$(readlink -e "$KERNEL_BUILD") ||
        die "--kernel-build must exist: $KERNEL_INPUT"
    [ -d "$KERNEL_BUILD" ] || die "--kernel-build must name a directory"
    [ -f "$KERNEL_BUILD/.config" ] ||
        die "no .config in $KERNEL_BUILD; configure the kernel first"
    [ -f "$KERNEL_BUILD/include/config/kernel.release" ] ||
        die "no include/config/kernel.release in $KERNEL_BUILD; build the kernel first"
    RELEASE=$(cat "$KERNEL_BUILD/include/config/kernel.release")
    [ -n "$RELEASE" ] || die "empty kernel release"
    case $RELEASE in
        *[!A-Za-z0-9._+-]*) die "unsafe kernel release: $RELEASE" ;;
    esac
    KERNEL_RELEASE=$RELEASE
    WDT_MODE=$(sed -n 's/^CONFIG_QCOM_WDT=\(.\)$/\1/p' "$KERNEL_BUILD/.config")
    case $WDT_MODE in
        y)
            printf 'CONFIG_QCOM_WDT=y in %s: the watchdog is built in, /dev/watchdog0 needs no module; skipping the module tree.\n' "$KERNEL_BUILD"
            ;;
        m)
            printf 'Installing K1 modules for %s (host tools only)\n' "$RELEASE"
            make -C "$KERNEL_BUILD" ARCH=arm64 modules_install INSTALL_MOD_PATH="$OUT"
            MODULE_ROOT=$OUT/lib/modules/$RELEASE
            [ -d "$MODULE_ROOT" ] || die "modules_install did not create $MODULE_ROOT"
            QCOM_MODULE=$(modinfo -b "$OUT" -k "$RELEASE" -n qcom_wdt) ||
                die "qcom_wdt.ko is missing; finish 'make modules' in $KERNEL_BUILD first"
            [ -f "$QCOM_MODULE" ] || die "qcom_wdt module is not a file: $QCOM_MODULE"
            case $(modinfo -F vermagic "$QCOM_MODULE") in
                "$RELEASE "*) ;;
                *) die "qcom_wdt vermagic does not match $RELEASE" ;;
            esac
            # Keep only the closure modprobe qcom_wdt needs; host modinfo
            # reads the .ko files without executing target code.
            KEEP=$WORK/keep
            mkdir -p "$KEEP"
            copy_module() { # module name from the installed module tree
                cm_path=$(modinfo -b "$OUT" -k "$RELEASE" -n "$1") ||
                    die "missing module dependency: $1"
                case $cm_path in
                    "$MODULE_ROOT"/*) cm_rel=${cm_path#"$MODULE_ROOT"/} ;;
                    *) die "module escaped its kernel release directory: $cm_path" ;;
                esac
                cm_dest=$KEEP/$cm_rel
                [ -f "$cm_dest" ] && return 0
                mkdir -p "$(dirname "$cm_dest")"
                cp -a "$cm_path" "$cm_dest"
                for cm_dep in $(modinfo -F depends "$cm_path" | tr ',' ' '); do
                    copy_module "$cm_dep"
                done
            }
            copy_module qcom_wdt
            rm -rf "$MODULE_ROOT"
            mkdir -p "$MODULE_ROOT"
            cp -a "$KEEP/." "$MODULE_ROOT/"
            rm -f "$MODULE_ROOT/build" "$MODULE_ROOT/source"
            depmod -b "$OUT" "$RELEASE"
            [ -s "$MODULE_ROOT/modules.dep" ] || die "depmod did not write modules.dep"
            modinfo -b "$OUT" -k "$RELEASE" -n qcom_wdt >/dev/null ||
                die "pruned module tree lost qcom_wdt"
            ;;
        *)
            die "$KERNEL_BUILD/.config has no CONFIG_QCOM_WDT line; set it to y or m"
            ;;
    esac
else
    printf 'No --kernel-build given: preparing the Alpine package set only.\n'
fi

INFO=$OUT.prepare-initramfs-root
{
    printf 'ALPINE_RELEASE=%s\n' "$ALPINE_RELEASE"
    printf 'ALPINE_REPOSITORY=%s\n' "$REPOSITORY"
    printf 'APK_TOOLS_STATIC_PACKAGE=%s\n' "$APK_TOOLS_APK"
    printf 'APK_TOOLS_STATIC_PACKAGE_SHA256=%s\n' "$APK_TOOLS_SHA256"
    printf 'APK_STATIC_SHA256=%s\n' "$APK_STATIC_SHA"
    printf 'APK_STATIC_SIGNED_BY=%s\n' "$(basename "$SIGN_KEY")"
    printf 'ALPINE_KEYS_PACKAGE=%s\n' "$ALPINE_KEYS_APK"
    printf 'ALPINE_KEYS_PACKAGE_SHA256=%s\n' "$ALPINE_KEYS_SHA256"
    printf 'KERNEL_RELEASE=%s\n' "$KERNEL_RELEASE"
    printf 'CONFIG_QCOM_WDT=%s\n' "$WDT_MODE"
    printf 'REQUESTED_PACKAGES=%s\n' "$PACKAGES"
    printf 'TOUCH_UNLOCK=%s\n' "$([ -n "$TOUCH_UNLOCK_BIN" ] && echo yes || echo no)"
    printf 'INSTALLED_PACKAGES:\n'
    awk '/^P:/{name=substr($0,3)} /^V:/{print name "=" substr($0,3)}' \
        "$OUT/lib/apk/db/installed"
} > "$INFO"
rm -rf "$WORK"
trap - EXIT HUP INT TERM

printf 'apk.static sha256: %s\n' "$APK_STATIC_SHA"
printf 'Build record: %s\n' "$INFO"
printf 'Prepared %s (Alpine %s aarch64, kernel release "%s", CONFIG_QCOM_WDT=%s); no aarch64 binary was executed.\n' \
    "$OUT" "$ALPINE_RELEASE" "$KERNEL_RELEASE" "$WDT_MODE"
