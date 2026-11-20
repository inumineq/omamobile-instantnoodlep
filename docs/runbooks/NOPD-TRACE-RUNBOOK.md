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
the flag only skips the sweep at `late_initcall_sync` (`:1367-1387`). Domains
that were on at boot stay on until their provider's `sync_state` (`:968`),
and that power-off runs with or without the flag (`:3684-3700`). The sweep
runs a few seconds into boot, so the time of the loss does not point at it
directly. [I] The cause is open; this run is meant to find it.

## What is installed

Two files on the phone's root, both removed again by the rollback:

- `/var/lib/s2idle/nopd-trace`, a copy of `tools/instantnoodlep-nopd-trace`.
- `/etc/systemd/system/nopd-trace.service`, below.

```ini
[Unit]
Description=Trace power domains on a kernel without pd_ignore_unused
ConditionKernelCommandLine=!pd_ignore_unused
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/modprobe -a rtc-pm8xxx qcom_stats
ExecStart=/var/lib/s2idle/nopd-trace 240 10
ExecStart=/var/lib/s2idle/step R4d none 60

[Install]
WantedBy=multi-user.target
```

The unit does nothing on the daily kernel: the condition is false there, and
the tool itself exits when the flag is set. On `nopd` it traces for 240 s and
then runs the one sleep step that S1 never reached (60 s, RTC wake), with the
step tool from `S2IDLE-FIRST-RUNBOOK.md` that is already on the phone.

## Steps

1. **Install, on the daily kernel over USB SSH** (from the repo root on the laptop):

   ```sh
   sha256sum tools/instantnoodlep-nopd-trace
   scp tools/instantnoodlep-nopd-trace root@PHONE:/var/lib/s2idle/nopd-trace
   scp nopd-trace.service root@PHONE:/etc/systemd/system/nopd-trace.service
   ssh root@PHONE 'chmod 755 /var/lib/s2idle/nopd-trace; sha256sum /var/lib/s2idle/nopd-trace /var/lib/s2idle/step; systemctl daemon-reload; systemctl enable nopd-trace.service; systemctl start nopd-trace.service; systemctl status nopd-trace.service | head -5; ls /var/lib/s2idle | grep -c trace-'
   ```

   Expect: the two tool hashes match the laptop's and the step hash from the
   session runbook (`6c5200f4...`); the status shows the condition was not met
   ("start condition unmet"); the count is `0`.
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
   line; the count is `0`; `R4d.log` ends with the `== after` block.
   For each sample `N` that `index.txt` marks as changed:

   ```sh
   diff "$d/genpd.$((N-1))" "$d/genpd.$N"; diff "$d/usb.$((N-1))" "$d/usb.$N"
   diff "$d/clk.$((N-1))" "$d/clk.$N" | head -60
   grep -n -i 'genpd\|usb\|dwc3\|gdsc' "$d/dmesg.txt" | tail -40
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
rm /etc/systemd/system/nopd-trace.service /var/lib/s2idle/nopd-trace
systemctl daemon-reload
```

The trace folders can stay; they are a few megabytes. No partition is
written at any step, and the slot is never changed.
