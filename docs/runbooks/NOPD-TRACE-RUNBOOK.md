# Trace the `nopd` and `noclk` kernels without a login

Status: prepared, not run. Phone work is the owner's, through the coordinator.

## Why

Session 2026-11-20 RAM-booted the daily kernel with one boot flag removed at
a time. Both runs lost USB, so neither gave a capture or a sleep step.
[V, coordinator's reports]

- `nopd` (no `pd_ignore_unused`, sha256 `f4e7f325...c023b`): the gadget
  enumerated, SSH never answered, and the gadget vanished about 134 s later
  with the cable untouched. The log has "Disabling unused power domains" at
  4.05 s and no USB or power-domain line near the loss.
- `noclk` (no `clk_ignore_unused`, sha256 `e23eb776...e5a62`): the log has
  "Disabling unused clocks" at 3.9037 s and "USB gadget up" at 3.9053 s, with
  no USB error, but the laptop never saw the phone.

In both runs the phone itself kept running. Wi-Fi SSH is closed by the
firewall. `tools/instantnoodlep-nopd-trace` records what the kernel reports
on the root file system instead, and it is read afterwards on the daily
kernel.

What the source says [V, kernel tree of the daily]: `pd_ignore_unused` only
skips the sweep at `late_initcall_sync` (`drivers/pmdomain/core.c:1367-1387`).
A domain whose `stay_on` mark is set is not powered off (`:966-968`); the
provider's `sync_state` clears the mark and tries the power-off, with or
without the flag (`:3684-3698`). `clk_ignore_unused` only skips the sweep
that gates clocks nobody has claimed (`drivers/clk/clk.c:1580-1627`).

[I] On `nopd` the sweep ran two minutes before the loss, so the time does not
point at it directly. On `noclk` the sweep ran 2 ms before the gadget
started, so a clock on the USB path without a registered user is the leading
guess. Both causes are open; these runs are meant to find them.

## What is installed

Three files on the phone's root, all removed again by the rollback:

- `/var/lib/s2idle/nopd-trace`, a copy of `tools/instantnoodlep-nopd-trace`.
- `/etc/systemd/system/nopd-trace.service`, a copy of
  `tools/instantnoodlep-nopd-trace.service`.
- `/var/lib/s2idle/nopd-armed`, a file that holds the word `nopd` or
  `noclk`. The tool runs only when it exists and is less than 30 minutes
  old, and removes it when it starts. One arming gives one run, and it cannot
  carry over to a later boot.

Both variants are the daily kernel with another command line, so the kernel
version cannot tell them apart. The command line does. The unit starts only
when one of the two flags is missing. The tool then requires the exact pair
of the armed variant: `nopd` has `clk_ignore_unused` and lacks
`pd_ignore_unused`, `noclk` is the reverse. The daily kernel has both flags
and the `noboth` image has neither; the tool refuses both.

The tool also refuses when it is not armed, on any slot but B and with less
than 100 MB free. It exits 0 only after a complete trace: a refusal, an
unreadable power-domain summary, a failed write or a failed wait is a failed
first command, and systemd then skips the sleep step after it.

After a complete trace of 240 s the unit runs the one sleep step that the
session never reached (60 s, RTC wake): `R4d` on `nopd`, `R4e` on `noclk`. It
uses the step tool from `S2IDLE-FIRST-RUNBOOK.md` that is already on the
phone. That tool refuses to sleep when it cannot set the RTC alarm, and it
switches charging off for the step and back on after it. `/bin/sh` on the
phone is bash; the trace tool has been tested under bash only.

## Steps

Do the whole list once per variant. Set the variant on the laptop first:

```sh
V=nopd      # or: V=noclk
```

1. **Install and arm, on the daily kernel over USB SSH** (from the repo root
   on the laptop):

   ```sh
   ssh root@PHONE 'test -x /var/lib/s2idle/step && grep -c "clk_ignore_unused pd_ignore_unused" /proc/cmdline'
   sha256sum tools/instantnoodlep-nopd-trace
   scp tools/instantnoodlep-nopd-trace root@PHONE:/var/lib/s2idle/nopd-trace
   scp tools/instantnoodlep-nopd-trace.service root@PHONE:/etc/systemd/system/nopd-trace.service
   ssh root@PHONE 'set -e; cd /var/lib/s2idle; chmod 755 nopd-trace; sha256sum nopd-trace step; df -h . | tail -1; cat /sys/kernel/debug/clk/clk_summary > daily-clk.txt; cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > daily-genpd.txt; cat /sys/kernel/debug/regulator/regulator_summary > daily-reg.txt; wc -l daily-clk.txt daily-genpd.txt daily-reg.txt; systemctl daemon-reload; systemctl enable nopd-trace.service; systemctl start nopd-trace.service; systemctl status nopd-trace.service | head -5 || true'
   ssh root@PHONE "set -e; cd /var/lib/s2idle; ls -d trace-$V-* 2>/dev/null | wc -l; echo $V > nopd-armed; cat nopd-armed"
   ```

   Run the lines one at a time. The first must print `1`; if it does not,
   stop before copying anything. Boot the variant (step 2) within 30 minutes
   of the last line, because the arming expires.

   Expect: the two tool hashes match the laptop's and the step hash from the
   session runbook (`6c5200f4...`); more than 1 GB free; the three `daily-`
   files have lines; the status shows the condition was not met ("start
   condition unmet"); the count is `0`; the last line is the variant.
   Stop: any other result. Run the rollback.

   The three `daily-` files are the reference: the same reads on the daily
   kernel with the cable in.

2. **Boot the variant** with the boot block of `POWER-SESSION-2026-11-20.md`
   (`fastboot boot`, RAM only), image `nopd` or `noclk` to match `V`. Leave
   the cable in, so the trace sees the same USB situation as the reference
   and as the failed runs. Note on the laptop whether and when the phone
   enumerates (`dmesg -w`).

3. **Leave the phone alone for 7 minutes.** Do not touch the screen, the keys
   or the cable.
   Expect: it looks normal, then the screen goes dark for about a minute
   (the sleep step) and comes back.
   Stop: the phone feels hot, or shows nothing 9 minutes after boot. In both
   cases go to step 4 at once.

4. **Restart into the daily kernel.** Pull the cable first: three restarts
   with the cable in hung in the bootloader after the first `nopd` run.
   [V, coordinator] Hold the power key until the phone restarts. Plug the
   cable in after the lock screen shows. Read back over USB SSH (set `V` on
   the phone as on the laptop):

   ```sh
   cd /var/lib/s2idle && d=$(ls -d trace-$V-* | tail -1) && cat "$d/index.txt"
   cat "$d/cmdline.txt" | tr ' ' '\n' | grep ignore_unused
   s=$(cat trace-step); echo "$s"; tail -30 "$s.log"
   grep -l UNREADABLE "$d"/*
   ```

   Expect: `index.txt` has a `start` line, about 25 samples and an `end`
   line; exactly one flag is printed, the one the variant keeps; the step
   name is `R4d` for `nopd` and `R4e` for `noclk`, and its log ends with the
   `== after` block; the last command prints nothing. A file it does print
   is a source this kernel does not offer (clock or regulator summary,
   deferred list, kernel log); report its name. The run still counts, because
   the power-domain summary is the one source the tool requires.

   The phone's hardware clock is not kept across boots, so the clock early
   in boot is the one systemd saved at the last clean shutdown. If the tool
   refused with "armed ... s away from now", that clock was off; this is a
   void run, not a fault of the kernel under test.

   If there is no trace folder, no `end` line or no step log from this run:
   the run is void. Read `journalctl -b -1 -u nopd-trace.service`, report it
   and stop.

   Compare the first sample with the daily reference:

   ```sh
   diff daily-genpd.txt "$d/genpd.0"
   diff daily-reg.txt "$d/reg.0"
   diff daily-clk.txt "$d/clk.0" | grep -i 'usb\|qmp\|pipe\|utmi\|aux\|cxo\|ref' | head -80
   diff daily-clk.txt "$d/clk.0" | wc -l
   cat "$d/usb.0"
   ```

   Then, for each sample `N` that `index.txt` marks as changed:

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

- `noclk`: a clock that is on in `daily-clk.txt` and off in `clk.0`, on the
  USB path, names what `clk_ignore_unused` keeps alive. The fix is then a
  device-tree or driver reference to that clock, planned as its own step.
  The reference was read minutes after boot and the sample seconds after, so
  some differences are only runtime power management; a clock counts when it
  belongs to the USB controller or its PHYs.
- `nopd`: a domain, clock or regulator that changes at the sample where `usb`
  changes names what `pd_ignore_unused` keeps alive for USB. If `usb` changes
  and nothing else does, the loss is not something the kernel reports here,
  and the flag is a weaker lead.
- `usb` never changes on `nopd`, and the laptop kept the phone: the loss did
  not repeat. Run it once more before drawing a conclusion.
- The step log: if the `cxsd`, `aosd` or `ddr` counts rise, the missing flag
  is part of what blocks SoC sleep. If they stay 0, it is not the only
  blocker.

Samples are 10 s apart and show what coincides, not what causes what.

## Rollback

On the daily kernel:

```sh
systemctl disable nopd-trace.service
cd /var/lib/s2idle && rm -f /etc/systemd/system/nopd-trace.service nopd-trace nopd-armed trace-step
systemctl daemon-reload
systemctl is-enabled nopd-trace.service
```

Expect: the last line says the unit is not found.

The trace folders and the `daily-` files can stay; they are some tens of
megabytes. No partition is written at any step, and the slot is never
changed.
