#!/bin/sh
# SPDX-License-Identifier: MIT
# Fetch the laptop-side tools for stage 0 and the restore-assets runbook
# (docs/runbooks/STAGE-0-RUNBOOK.md L1, docs/runbooks/RESTORE-ASSETS.md R4).
#
# Laptop only. Never talks to a phone. Idempotent: re-running skips what is
# already present. Downloads go outside the repo:
#   $R       (default ~/android/reference/instantnoodlep)   APKs, checksums
#   $SRC_DIR (default ~/aosp-tools)                          AOSP python tools
#
# Usage: sh scripts/omabook-fetch-tools.sh [--dry-run]
#   --dry-run  resolve and print what would be fetched; download nothing.

set -eu

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

R="${R:-$HOME/android/reference/instantnoodlep}"
SRC_DIR="${SRC_DIR:-$HOME/aosp-tools}"
BIN="${BIN:-$HOME/.local/bin}"

say() { printf '==> %s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then printf '    (dry-run) %s\n' "$*"; else "$@"; fi; }

need() { command -v "$1" >/dev/null 2>&1; }
for t in curl git python3 sha256sum tar; do
  need "$t" || { echo "missing: $t (install it first)" >&2; exit 1; }
done

# Latest GitHub release asset URL whose name matches a regex.
gh_asset() { # repo regex
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    python3 -I -c 'import json,re,sys
r=json.load(sys.stdin); pat=re.compile(sys.argv[1])
print(r["tag_name"])
for a in r["assets"]:
    if pat.search(a["name"]): print(a["browser_download_url"])' "$2"
}

run mkdir -p "$R/tools" "$SRC_DIR/system/tools" "$SRC_DIR/external" "$SRC_DIR/system" "$BIN"

# 1. Distribution packages (adb, fastboot, dtc, 7z).
say "Distribution packages"
if need pacman; then
  run sudo pacman -S --needed android-tools dtc p7zip
elif need apt-get; then
  run sudo apt-get install -y android-sdk-platform-tools device-tree-compiler p7zip-full
else
  echo "    unknown package manager: install adb, fastboot, dtc and 7z by hand"
fi

# 2. payload-dumper-go (extract images from payload.bin).
say "payload-dumper-go"
if need payload-dumper-go; then
  echo "    already installed: $(command -v payload-dumper-go)"
else
  case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; *) arch=unknown ;; esac
  out=$(gh_asset ssut/payload-dumper-go "linux_${arch}\\.tar\\.gz\$|checksums")
  tag=$(echo "$out" | sed -n 1p)
  tgz=$(echo "$out" | grep -E "linux_${arch}\\.tar\\.gz\$" | head -1 || true)
  sums=$(echo "$out" | grep -i checksums | head -1 || true)
  echo "    release $tag: ${tgz:-no linux_${arch} asset found}"
  if [ -n "$tgz" ] && [ "$DRY" = 0 ]; then
    tmp=$(mktemp -d)
    curl -fL --progress-bar -o "$tmp/pdg.tar.gz" "$tgz"
    if [ -n "$sums" ]; then
      want=$(curl -fsSL "$sums" | grep "$(basename "$tgz")" | cut -d' ' -f1)
      have=$(sha256sum "$tmp/pdg.tar.gz" | cut -d' ' -f1)
      [ "$want" = "$have" ] || { echo "    CHECKSUM MISMATCH, not installing" >&2; exit 1; }
      echo "    checksum OK"
    else
      echo "    no checksums asset published; recording sha256 only"
    fi
    tar -xzf "$tmp/pdg.tar.gz" -C "$tmp"
    install -m 0755 "$tmp/payload-dumper-go" "$BIN/payload-dumper-go"
    sha256sum "$tmp/pdg.tar.gz" | sed "s|$tmp/pdg.tar.gz|payload-dumper-go-$tag-linux_${arch}.tar.gz|" >> "$R/tools/SHA256SUMS"
    rm -rf "$tmp"
  fi
fi

# 3. AOSP python tools in the SRC_DIR layout the runbooks use.
say "AOSP tools in $SRC_DIR"
clone() { # url dest
  if [ -d "$2/.git" ]; then echo "    present: $2"; else run git clone -q --depth 1 "$1" "$2"; fi
}
clone https://android.googlesource.com/platform/system/tools/mkbootimg "$SRC_DIR/system/tools/mkbootimg"
clone https://android.googlesource.com/platform/external/avb           "$SRC_DIR/external/avb"
clone https://android.googlesource.com/platform/system/libufdt         "$SRC_DIR/system/libufdt"

# 4. Magisk APK, official GitHub release (stage-0 runbook D2).
say "Magisk APK"
if ls "$R/tools"/Magisk-v*.apk >/dev/null 2>&1; then
  echo "    present: $(ls "$R/tools"/Magisk-v*.apk)"
else
  out=$(gh_asset topjohnwu/Magisk '^Magisk-v[0-9.]+\.apk$')
  tag=$(echo "$out" | sed -n 1p); apk=$(echo "$out" | sed -n 2p)
  echo "    release $tag: ${apk:-no APK asset found}"
  if [ -n "$apk" ]; then
    run curl -fL --progress-bar -o "$R/tools/$(basename "$apk")" "$apk"
    [ "$DRY" = 0 ] && (cd "$R/tools" && sha256sum "$(basename "$apk")" >> SHA256SUMS)
  fi
fi

# 5. Check.
say "Check"
for t in adb fastboot dtc 7z payload-dumper-go; do
  printf '    %-18s' "$t"; command -v "$t" || echo "MISSING"
done
for f in system/tools/mkbootimg/unpack_bootimg.py external/avb/avbtool.py system/libufdt/utils/src/mkdtboimg.py; do
  printf '    %-45s' "$f"; [ -f "$SRC_DIR/$f" ] && echo OK || echo MISSING
done
case ":$PATH:" in *":$BIN:"*) ;; *) echo "    note: add $BIN to PATH" ;; esac
echo
echo "Done. Next: export SRC_DIR=$SRC_DIR, then stage-0 runbook phase A."
