<!-- SPDX-License-Identifier: MIT -->
# Power-baseline runbook: run the #867 recipe on the owner's IN2023

Ticket: U1 baseline tool (`tools/instantnoodlep-power-baseline`). This
runbook is how the owner runs the tool by hand on the phone (AGENTS.md
rule 1: agents never touch the phone). The tool is read-only: it writes
nothing except its one report file, never writes sysfs/debugfs, and never
requests suspend. There is no rollback because there is nothing to undo.

Ground rules:

- Copy the tool to the phone yourself (e.g. `scp
  tools/instantnoodlep-power-baseline root@<phone>:/root/`). It needs only
  bash, coreutils, awk/sed/sort/find and `iw` on the phone; no python.
- The report can contain kernel names and paths. The tool redacts MAC/IP/
  serial tokens and never prints the full cmdline, but **eyeball the report
  once before posting it anywhere public** (AGENTS.md rule 4: captures are
  private; quote facts, not files).

## Phase 1 — set up the session (any time)

Command:

```sh
ssh root@<phone>
tmux new -s power
cp /root/instantnoodlep-power-baseline /root/pb && chmod +x /root/pb
```

Expect: a tmux session named `power` on the phone. Detaching
(`Ctrl-b d`) must not kill the run.

Stop: none. Rollback: none.

## Phase 2 — conditions for Part B/C: cable out, screen off, SSH over Wi-Fi

1. Unplug the USB cable. Confirm no supply reports online:

   ```sh
   for d in /sys/class/power_supply/*; do echo "$d $(cat $d/type 2>/dev/null) online=$(cat $d/online 2>/dev/null)"; done
   ```

   Expect: the USB/charger supplies show `online=0`.
2. Keep the SSH session alive over Wi-Fi (UFW on the phone blocks SSH on
   wlp1s0 — use the USB network interface or open it first, per the current
   network state in `docs/agents/state.md`).
3. Turn the screen off (power key) and leave the phone untouched.

Stop: if any supply shows `online=1` after unplugging, the run is not a
battery-only floor — the tool will say so itself in the report; you can
still run it, but label the result accordingly.

## Phase 3 — run the recipe (about 11 minutes with defaults)

Command (inside the tmux session):

```sh
cd /root && ./pb --part all --room-temp 21 --out /root/power-baseline-$(date -u +%Y%m%dT%H%M%SZ).md
```

`--room-temp` is optional (recorded in the header). Defaults: settle 600 s,
then 12 samples every 15 s (Part B), then a 60 s window (Part C). To shorten
a trial run: `--settle 60 --samples 4 --interval 15`.

Expect: progress lines on stdout (`Part A ...`, `Part B ...`, `Part C ...`,
`report: ...`); after ~11 min one Markdown file in /root, mode 0600, with
the title `Power baseline: OnePlus 8 Pro (instantnoodlep)`, a conditions
header, and Parts A, B, C each in a `<details>` block. Part B ends with
`median current: ... mA`, `raw current_now sign: ...`, `all samples
Discharging: yes` and either `floor verdict: clean screen-off floor ...`
or a `WARNING: not a clean floor` line (cable in or a non-Discharging
sample — then do not quote it as the floor).

Stop conditions:

- You need the phone back: `Ctrl-c` inside tmux. Parts already finished
  stay in the report file; a dropped SSH session does not stop the run
  (tmux).
- The phone reboots or the session dies: rerun Phase 3; nothing on the
  phone was changed.
- Any `WARNING: not a clean floor` line: keep the report, but post it with
  the warning visible — do not edit it away.

Rollback: none needed (read-only). The only file created is the `--out`
report; delete it freely.

## Phase 4 — post upstream

1. Pull the report off the phone (`scp root@<phone>:/root/power-baseline-*.md .`),
   read it once end to end (privacy check above).
2. Open an issue in `derekross/omarchy-mobile` titled exactly
   `Power baseline: OnePlus 8 Pro (instantnoodlep)`.
3. Paste the whole report file as the issue body (the three `<details>`
   blocks render collapsed, as #867 asks). The conditions (kernel, package
   version, cable, Wi-Fi power save, gauge, room temperature) are already in
   the report header — #867 asks for them next to the outputs.
4. If any command printed `<path>: missing`, leave that line in — #867 says
   a missing cpuidle/qcom_stats is a result, not a failure.
5. Link the issue from the device tracking issue / wayfinder map
   (`docs/agents/issue-tracker.md`).
