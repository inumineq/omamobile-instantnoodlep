#!/bin/sh
# SPDX-License-Identifier: MIT
# Read-only stage-0 stock capture for OnePlus 8 Pro (instantnoodlep, IN2023).
# Collects facts from a booted stock phone (step 1) and, if present,
# fastboot (step 2). Writes captures/<date>/ and NOTHING to the phone.
#
# PRIVACY: output contains serials, the IMEI and MAC addresses.
# Keep it local; redact before posting anything upstream.

set -eu

DATE="$(date +%Y-%m-%d)"
OUT="captures/${DATE}"
mkdir -p "${OUT}"

have_adb() { command -v adb >/dev/null 2>&1; }
have_fastboot() { command -v fastboot >/dev/null 2>&1; }

if ! have_adb; then
  echo "adb not found (android-tools). Install it first." >&2
  exit 1
fi

echo "==> Checking for a device..."
if ! adb get-state >/dev/null 2>&1; then
  echo "No adb device. Connect the phone, enable USB debugging, re-run." >&2
  exit 1
fi

echo "==> getprop (model, slot, dtbo, bootdevice)"
adb shell getprop > "${OUT}/getprop-all.txt"
adb shell getprop | grep -Ei 'model|slot|dtbo|bootdevice' > "${OUT}/getprop-interesting.txt" || true

echo "==> Partition list (both slots, by-name)"
adb shell ls -l /dev/block/by-name/ > "${OUT}/by-name.txt"

echo "==> Boot device / LUN layout"
adb shell getprop ro.boot.bootdevice > "${OUT}/bootdevice.txt" || true
adb shell ls -l /dev/block/sda* > "${OUT}/block-devs.txt" 2>/dev/null || true

echo "==> cpuinfo / meminfo / cmdline / modules"
adb shell cat /proc/cpuinfo > "${OUT}/cpuinfo.txt"
adb shell cat /proc/meminfo > "${OUT}/meminfo.txt"
adb shell cat /proc/cmdline > "${OUT}/cmdline.txt" || true
adb shell cat /proc/modules > "${OUT}/modules.txt" || true

if have_fastboot; then
  echo "==> fastboot: switch when you are ready (script does NOT reboot the phone)."
  echo "    When the phone is in fastboot, run:  fastboot getvar all 2>&1 | tee ${OUT}/getvar-all.txt"
else
  echo "==> fastboot not found; run 'fastboot getvar all' later and save to ${OUT}/getvar-all.txt"
fi

cat <<EOF

Done. Output in ${OUT}/ .

REMEMBER:
- Contents are PRIVATE (serials, IMEI, MACs). Never commit, attach or post them.
- Quote individual facts (redacted) into issue #808, not the files.
- Temporary-root steps (dmesg, live device tree) are manual: see docs/STAGE-0.md steps 8-11.
EOF
