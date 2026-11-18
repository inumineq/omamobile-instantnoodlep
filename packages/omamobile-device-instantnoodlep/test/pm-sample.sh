#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Host-side tests for the read-only PM sampler; uses fake sysfs and proc files.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../../.." && pwd)
sampler=$repo/tools/instantnoodlep-pm-sample
tmp=$(mktemp -d /tmp/instantnoodlep-pm-test.XXXXXX)
trap 'rm -rf -- "$tmp"' EXIT

root=$tmp/sys
power=$root/class/power_supply/battery0
mkdir -p "$power" "$root/kernel/debug"
printf 'Battery\n' >"$power/type"
printf '%s\n' -500000 >"$power/current_now"
printf '%s\n' 3900000 >"$power/voltage_now"
printf '%s\n' 245 >"$power/temp"
cat >"$root/kernel/debug/wakeup_sources" <<'EOF'
name active_count event_count wakeup_count expire_count active_since total_time max_time last_change prevent_suspend_time
rtc0 0 10 2 0 0 100 15 1000 0
power-key 0 4 3 0 0 50 10 1000 0
EOF
cat >"$tmp/interrupts" <<'EOF'
           CPU0       CPU1
  9:         10          4   GICv3  123 Level     rtc0
 42:         20         12   GICv3  456 Edge      power-key
EOF

output=$tmp/sample.csv
(
  sleep 0.2
  cat >"$root/kernel/debug/wakeup_sources" <<'EOF'
name active_count event_count wakeup_count expire_count active_since total_time max_time last_change prevent_suspend_time
rtc0 0 11 3 0 0 100 15 1000 0
power-key 0 5 3 0 0 50 10 1000 0
EOF
  cat >"$tmp/interrupts" <<'EOF'
           CPU0       CPU1
  9:         12          5   GICv3  123 Level     rtc0
 42:         22         12   GICv3  456 Edge      power-key
EOF
) &
writer=$!
PM_SAMPLE_SYSFS=$root \
PM_SAMPLE_POWER_SUPPLY=$power \
PM_SAMPLE_WAKEUP_SOURCES=$root/kernel/debug/wakeup_sources \
PM_SAMPLE_PROC_INTERRUPTS=$tmp/interrupts \
  "$sampler" --duration 1 --interval 1 --output "$output" >/dev/null
wait "$writer"

grep -qx 'timestamp,elapsed_seconds,record,name,metric,value' "$output"
grep -Eq ',battery,current_now,current_now_ua,-500000$' "$output"
grep -Eq ',battery,voltage_now,voltage_now_uv,3900000$' "$output"
grep -Eq ',battery,temp,temp_deci_c,245$' "$output"
grep -Eq ',wakeup_source,rtc0,event_count_delta,1$' "$output"
grep -Eq ',wakeup_source,rtc0,wakeup_count_delta,1$' "$output"
grep -Eq ',wakeup_source,power-key,event_count_delta,1$' "$output"
grep -Eq ',interrupt,irq_9,count_delta,3$' "$output"
grep -Eq ',interrupt,irq_42,count_delta,2$' "$output"
if "$sampler" --duration 1 --interval 1 --output "$repo/packages/omamobile-device-instantnoodlep/test/outside.csv" >/dev/null 2>&1; then
  echo "sampler accepted an output path outside /tmp" >&2
  exit 1
fi
default_result=$(PM_SAMPLE_SYSFS=$root \
  PM_SAMPLE_POWER_SUPPLY=$power \
  PM_SAMPLE_WAKEUP_SOURCES=$root/kernel/debug/wakeup_sources \
  PM_SAMPLE_PROC_INTERRUPTS=$tmp/interrupts \
    "$sampler" --duration 1 --interval 1)
default_output=${default_result#CSV: }
[[ $default_output == /tmp/instantnoodlep-pm-sample-*.csv && -f $default_output ]]
grep -qx 'timestamp,elapsed_seconds,record,name,metric,value' "$default_output"
rm -f -- "$default_output"

echo 'ok - PM sampler writes battery telemetry and per-interval counters without identifiers'
