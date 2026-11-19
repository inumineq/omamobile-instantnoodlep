<!-- SPDX-License-Identifier: MIT -->
# Holder matrix runbook (runtime A/B rows A0-A7)

`tools/instantnoodlep-holder-matrix` runs the runtime A/B rows A0-A7 of the
SoC-sleep investigation in one unattended pass on the phone. Each row
changes one volatile holder (Wi-Fi power save, Bluetooth, CPUs 1-7, USB
runtime PM, UFS PM QoS, bwmon), measures for a fixed time and undoes the
change. Row A8 (s2idle) is not part of this tool; it has its own gate.

Nothing persistent changes. No partition is written, nothing is flashed,
and every toggle is a sysfs/configfs value, a module or a radio power state
that a reboot resets. AGENTS.md rule 1 lets an agent prepare this; the
coordinator runs it on the phone.

## Safety model

- The script records the original value of every toggle before its first
  write and restores that value, not a default. Example: if Wi-Fi power
  save was already `on`, it stays `on` afterwards.
- Each row is undone before the next row starts. On exit (normal end,
  error, Ctrl-C, `kill`, SIGHUP), a trap undoes any pending row in reverse
  order, then sweeps every recorded toggle once more and checks the final
  state. Exit code 3 and an `UNDO FAILED` line mean a toggle did not return
  to its original value.
- `cpu0` is never written (the CPU list excludes it, and the single write
  helper refuses it).
- It refuses to start (exit 2) when not root, or when a charger or USB
  supply reports `online=1` (override: `--allow-cable`; row a4 then still
  needs `--force-a4`).
- Row a4 is skipped unless the SSH session's local address is on the Wi-Fi
  interface, so unbinding the USB gadget cannot cut the session that
  started the run. It is also skipped, before any write, when
  `power/runtime_status` is missing or unreadable, or when no configfs
  `usb_gadget/*/UDC` exists while the controller is not yet suspended.
- SIGKILL and a kernel hang cannot be trapped. Then `reboot` restores
  everything, because nothing persistent was changed.

## Prepare (laptop, cable in)

```sh
adb push tools/instantnoodlep-holder-matrix /root/      # or scp over USB SSH
```

On the phone, as root, over SSH:

```sh
lsmod | grep -q '^qcom_stats' || modprobe qcom_stats   # counters, if still a module
/root/instantnoodlep-holder-matrix --dry-run --allow-cable
```

Expect: one block per row with `apply:` and `undo:` commands, `SKIPPED`
lines only for rows whose precondition fails here. With the cable in, a4
reads `SKIPPED: cable in`; that is expected at this stage.

## Run (Wi-Fi SSH, cable out, screen off)

1. Connect over Wi-Fi SSH. Confirm that the session runs over Wi-Fi:
   `echo "$SSH_CONNECTION"` and `ip -o addr` show the third field of
   `SSH_CONNECTION` on the Wi-Fi interface.
2. Unplug the cable. Owner confirms the screen is off.
3. Start detached:

   ```sh
   nohup /root/instantnoodlep-holder-matrix > /root/holder-matrix.log 2>&1 & echo $! > /root/holder-matrix.pid
   ```

   `nohup` keeps the run alive when the SSH session drops. `tmux` works too.
   The output directory is printed on the first line of the log
   (default `/tmp/holder-matrix-<UTC stamp>`, mode 0700).
4. Expected duration: rows x (settle + wait) = 8 x (30 + 300) s = 44 min
   for the defaults, plus 10 s inside a4.
5. Wait without touching the phone. The log is readable over SSH at any
   time: `tail /root/holder-matrix.log`.

Shorter variants for a first pass: `--wait 120 --settle 20` (about 19 min),
or a subset such as `--rows a0,a3`.

## Expect per row

All [I] until measured; from the R1 SoC-sleep analysis section 7.

| Row | Toggle | Expect |
|---|---|---|
| a0 | none | [I] Baseline. Cluster Usage near zero, qcom_stats `ddr`/`cxsd`/`aosd` +0 |
| a1 | Wi-Fi power save on | [I] Lower gauge current, fewer ath11k/MHI IRQs, more cluster Usage. SSH stays up with more latency |
| a2 | Bluetooth off | [I] UART6 leaves the `cx` consumers. `cx`/`mx` perf drops from 48 |
| a3 | CPUs 1-7 offline | [I] Decisive for the cluster blocker. Usage jumps: the limit is the timer window across CPUs. Usage near 0 with Rejected near 0: look at QoS or cpu0 timers. Rejected grows: the RSC flush fails. `ddr`/`cxsd` still +0 while Usage climbs: the sleep set is dirty |
| a4 | USB `power/control=auto`, UDC unbound if still active | [I] `runtime_status=suspended`, `usb30_prim_gdsc` off, the USB DDR request gone. USB networking returns only after a replug |
| a5 | UFS `pm_qos_enable=0` | [I] `cpu_dma_latency` no longer reads 0 during IO. Cluster Usage rises slightly |
| a6 | `rmmod icc_bwmon` | [I] IRQ 174 gone from the top IRQs. Cluster Usage changes |
| a7 | a1+a2+a4+a5+a6, all CPUs online | [I] Best runtime-idle case. Cluster Usage up. `ddr`/`cxsd` still +0 because of the CPU DDR always-on vote |

## Stop conditions

- Wi-Fi SSH does not come back 5 minutes after the expected end: the owner
  wakes the screen and checks the phone (log, `ip link`, Wi-Fi state).
- The phone gets hot to the touch: stop with
  `kill -TERM $(cat /root/holder-matrix.pid)`. The trap undoes
  everything; the log ends with `Summary:`.
- The log shows `UNDO FAILED`: do not start another run. Read the named
  toggle and set it by hand, or reboot.

## Rollback

- Normal: the trap. Check the last lines of the log for `Summary:` and no
  `UNDO FAILED`.
- If the script was SIGKILLed or the phone hangs: `reboot` (or a long
  power-key press). Every toggle is volatile, so a reboot restores all of
  them.
- USB networking after a4: unplug and replug the cable.

## What to send back

Only `summary.md` from the output directory. It carries no MAC or IP
addresses, hostnames, SSIDs or serials (MAC and IPv4 patterns are redacted).
The raw snapshot files (`<row>/pre`, `<row>/post`, gauge samples,
`run.log`) stay on the phone or in the private `captures/`; never commit
them.
