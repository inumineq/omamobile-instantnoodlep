# Trace the `nopd` kernel without a login

Status: prepared, not run. Phone work is the owner's, through the coordinator.

## Why

Session 2026-11-20, step S1: the daily kernel was RAM-booted without
`pd_ignore_unused` (image `nopd`, sha256 `f4e7f325...c023b`). The USB gadget
enumerated, SSH never answered, and the gadget vanished about 134 s later
with the cable untouched. The phone itself kept running. The kernel log
showed no USB or power-domain line near the loss. [V, coordinator's report]

Nobody could log in, so nobody knows which domain or clock changed. Wi-Fi
SSH is closed by the firewall. `tools/instantnoodlep-nopd-trace` records the
answer on the root file system instead, and it is read afterwards on the
daily kernel.

What the source says [V, kernel tree of the daily, `drivers/pmdomain/core.c`]:
the flag only skips the sweep at `late_initcall_sync` (`:1367-1387`). A domain
whose `stay_on` mark is set is not powered off (`:966-968`); the provider's
`sync_state` clears the mark and tries the power-off, with or without the
flag (`:3684-3698`). The S1 log has the sweep line at 4.05 s. [V, coordinator] The sweep
ran about two minutes before the loss, so the time of the loss does not point at it
directly. [I] The cause is open; this run is meant to find it.

## What is installed

Three files on the phone's root, all removed again by the rollback:

- `/var/lib/s2idle/nopd-trace`, a copy of `tools/instantnoodlep-nopd-trace`.
- `/etc/systemd/system/nopd-trace.service`, a copy of
  `tools/instantnoodlep-nopd-trace.service`.
- `/var/lib/s2idle/nopd-armed`, an empty file. The tool runs only when it
  exists and is less than 30 minutes old, and removes it when it starts. One
  arming gives one run, and it cannot carry over to a later boot. `nopd` is
  the daily kernel with another command line, so the kernel version cannot
  tell the two apart; the flag and the arming do.

Three things keep the unit from running by accident. The unit's condition is
false on the daily kernel. The tool refuses when the flag is set, when it is
not armed, on any slot but B and with less than 100 MB free. The tool exits 0
only after a complete trace: a refusal, an unreadable power-domain summary, a
failed write or a failed wait is a failed first command, and systemd then
skips the sleep step after it.

On `nopd` the unit traces for 240 s and then runs the one sleep step that S1
never reached (60 s, RTC wake), with the step tool from
`S2IDLE-FIRST-RUNBOOK.md` that is already on the phone. That tool refuses to
sleep when it cannot set the RTC alarm. `/bin/sh` on the phone is bash; the
tool has been tested under bash only.

## Steps

1. **Install, on the daily kernel over USB SSH** (from the repo root on the laptop):

   ```sh
   ssh root@PHONE 'test -x /var/lib/s2idle/step && grep -c pd_ignore_unused /proc/cmdline'
   sha256sum tools/instantnoodlep-nopd-trace
   scp tools/instantnoodlep-nopd-trace root@PHONE:/var/lib/s2idle/nopd-trace
   scp tools/instantnoodlep-nopd-trace.service root@PHONE:/etc/systemd/system/nopd-trace.service
   ssh root@PHONE 'chmod 755 /var/lib/s2idle/nopd-trace; sha256sum /var/lib/s2idle/nopd-trace /var/lib/s2idle/step; df -h /var/lib/s2idle | tail -1; systemctl daemon-reload; systemctl enable nopd-trace.service; systemctl start nopd-trace.service; systemctl status nopd-trace.service | head -5; ls /var/lib/s2idle | grep -c trace-; touch /var/lib/s2idle/nopd-armed; ls /var/lib/s2idle/nopd-armed'
   ```

   Run the lines one at a time. The first must print `1`; if it does not,
   stop before copying anything. Boot `nopd` (step 2) within 30 minutes of
   this block, because the arming expires.

   Expect: the two tool hashes match the laptop's and the step hash from the
   session runbook (`6c5200f4...`); more than 1 GB free; the status shows the
   condition was not met ("start condition unmet"); the count is `0`; the
   arming file is listed last.
   Stop: any other result. Run the rollback.

2. **Boot `nopd`** with the boot block of `POWER-SESSION-2026-11-20.md`
   (`fastboot boot`, RAM only). When the boot screen shows, pull the cable.
   It stays out until step 4: the sleep step does not need it, and three
   restarts with the cable in hung in the bootloader after S1. [V, coordinator]

3. **Leave the phone alone for 7 minutes.** Do not touch the screen or keys.
   Expect: it looks normal, then the screen goes dark for about a minute
   (the sleep step) and comes back.
   Stop: the phone feels hot, or shows nothing 9 minutes after boot. In both
   cases hold the power key until it restarts.

4. **Restart into the daily kernel** (hold the power key, cable still out).
   Plug the cable in after the lock screen shows. Read back over USB SSH:

   ```sh
   cd /var/lib/s2idle && d=$(ls -d trace-* | tail -1) && cat "$d/index.txt"
   grep -c pd_ignore_unused "$d/cmdline.txt"
   tail -30 R4d.log
   ```

   Expect: `index.txt` has a `start` line, about 25 samples and an `end`
   line; the count is `0`; `R4d.log` ends with the `== after` block;
   `grep -l UNREADABLE "$d"/*` prints nothing.
   The phone's hardware clock is not kept across boots, so the clock early
   in boot is the one systemd saved at the last clean shutdown. If the tool
   refused with "armed ... s away from now", that clock was off; this is a
   void run, not a fault of the kernel under test.
   If there is no trace folder, no `end` line or no `R4d.log` from this run:
   the run is void. Read `journalctl -b -1 -u nopd-trace.service`, report it
   and stop.
   For each sample `N` that `index.txt` marks as changed:

   ```sh
   diff "$d/genpd.$((N-1))" "$d/genpd.$N"; diff "$d/usb.$((N-1))" "$d/usb.$N"
   diff "$d/clk.$((N-1))" "$d/clk.$N" | head -60
   diff "$d/reg.$((N-1))" "$d/reg.$N"; diff "$d/deferred.$((N-1))" "$d/deferred.$N"
   diff "$d/dmesg.$((N-1))" "$d/dmesg.$N" | grep -v 'UFW\|audit'
   ```

   Report the changed lines and the uptime of the sample. The files stay on
   the phone or in the private capture folder; the kernel log can hold
   hardware addresses, so quote the fact, not the file.

## What the result means

- A domain or clock changes at the sample where `usb` changes: that names
  what the flag keeps alive for USB. The fix is then a device-tree reference,
  and it is planned as its own step.
- `usb` changes and nothing else does: the loss is not a power domain or a
  clock that the kernel reports. The flag is then a weaker lead for USB.
- `usb` never changes: the loss did not repeat without a cable. Repeat once
  with the cable in before drawing a conclusion.
- `R4d.log`: if the `cxsd`, `aosd` or `ddr` counts rise, the flag is part of
  what blocks SoC sleep. If they stay 0, it is not the only blocker.

## Rollback

On the daily kernel:

```sh
systemctl disable nopd-trace.service
rm -f /etc/systemd/system/nopd-trace.service /var/lib/s2idle/nopd-trace /var/lib/s2idle/nopd-armed
systemctl daemon-reload
systemctl is-enabled nopd-trace.service
```

Expect: the last line says the unit is not found.

The trace folders can stay; they are some tens of megabytes. No partition is
written at any step, and the slot is never changed.
