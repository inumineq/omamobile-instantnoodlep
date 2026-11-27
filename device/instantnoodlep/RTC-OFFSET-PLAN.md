<!-- SPDX-License-Identifier: MIT -->
# RTC offset userspace service: instantnoodlep (OnePlus 8 Pro, SM8250)

Status: implemented host-side and packaged (device package 0.0.9); no phone
was accessed by this work. All on-device steps below are gated for the
coordinator/owner per AGENTS.md rule 1.

## 1. Problem

- The PM8150 RTC (`rtc-pm8xxx`, node `rtc@6000`, compatible
  `qcom,pm8941-rtc`) can only apply a wall-clock offset from an nvmem SDAM
  cell named `offset` or from a UEFI variable behind `qcom,uefi-rtc-info`;
  `set_time` without `allow-set-time` updates that offset and fails with
  `-ENODEV` when neither exists
  [V: `drivers/rtc/rtc-pm8xxx.c:345-356,564-583,623-628` in the local kernel
  trees, e.g. `~/src/l-k3-pm-cam2-work`].
- The PM8150 DT node carries no `offset` nvmem cell and no
  `qcom,uefi-rtc-info` [V: `arch/arm64/boot/dts/qcom/pm8150.dtsi:119-124`],
  and the phone boots through Android ABL, so no UEFI variables exist.
  Writing an unknown SDAM cell would be a permanent hardware write, so a
  kernel/DT fix is out of scope here.
- Consequence on the phone: the RTC comes up at ~1970 (observed 1970 and
  2026-01-02) and the clock stays wrong on every boot, especially RAM boots,
  until NTP syncs [V: `device/instantnoodlep/NOTES.md` 2026-11-17 night
  ("The RTC came up at 1970/2026-01-02, so time is lost on every boot until
  NTP or an RTC fix") and 2026-11-17 B4 ("The RTC reads 2026-10-26 (no time
  sync yet)"); `PM-PLAN.md` line 30]. `systemd-timesyncd` keeps
  `/var/lib/systemd/timesync/clock`, which systemd uses as a boot timestamp
  only once the root fs is mounted [V: `strings /usr/lib/systemd/systemd`
  on the omaserver host (systemd 262) contains `/var/lib/systemd/timesync/clock`].

## 2. Design

Packaged in `packages/omamobile-device-instantnoodlep` (0.0.9):

| File | Role |
| --- | --- |
| `bin/omamobile-rtc-offset` | `save` stores `wall - rtc` in `/var/lib/omamobile/rtc-offset` (mode 600, atomic replace); `apply` sets the system clock to `rtc + offset` when the clock is below the build floor. Never writes to the RTC. |
| `systemd/omamobile-rtc-offset-apply.service` | oneshot, `DefaultDependencies=no`, `After=local-fs.target`, `Before=time-set.target time-sync.target systemd-timesyncd.service sysinit.target`, enabled in `sysinit.target.wants`: runs after local-fs, before time-sync.target and timesyncd [V: host systemd 262 — `sysinit.target` has `After=local-fs.target` and `Wants=systemd-timesyncd.service`; `systemd-timesyncd.service` has `DefaultDependencies=no`, `Before=time-set.target sysinit.target`, `Wants=time-set.target`; `time-sync.target` has `After=time-set.target`, `Wants=time-set.target`]. |
| `systemd/omamobile-rtc-offset-save.service` | oneshot `save`, triggered by the timer and the path unit (no `[Install]`). |
| `systemd/omamobile-rtc-offset-save.timer` | `OnCalendar=hourly`, `Persistent=true`, `WantedBy=timers.target`. |
| `systemd/omamobile-rtc-offset-save.path` | `PathChanged=/var/lib/systemd/timesync/clock`, `WantedBy=paths.target` — refresh right after timesyncd reports a sync [I: that timesyncd rewrites the file (mtime = synced time) on every sync on the phone's systemd version]. |
| `systemd/omamobile-rtc-offset-shutdown.service` | `RemainAfterExit` oneshot with `ExecStart`/`ExecStop` = `save`, `WantedBy=multi-user.target`: default dependencies give `Conflicts/Before=shutdown.target`, so `ExecStop` saves on every clean stop/reboot while the root fs is writable. |

Guards in the helper:

- **Build floor.** `FLOOR` is the package build date in UTC seconds; `./install`
  stamps `date -u +%s` over the checked-in literal (2026-11-24). `save`
  refuses to store while the wall clock is below the floor (never poisons the
  state with a 1970 clock); `apply` only acts when the clock is below the
  floor and never sets it below the floor.
- **Never backwards.** `apply` refuses when the target is behind the
  timesyncd clock file's mtime (`/var/lib/systemd/timesync/clock`) or behind
  the current clock. Once NTP corrects the clock, `apply` is a no-op, so a
  later NTP step is never undone.
- **Robust state.** Missing or non-integer state file, unreadable RTC, or an
  offset outside ±100 years: log and do nothing, exit 0 (the unit stays
  green; the journal carries the reason).
- RTC read: `/sys/class/rtc/rtc0/since_epoch`, falling back to
  `hwclock --get` [I: `rtc0` is the PMIC RTC's sysfs name on the phone].

Host tests: `packages/omamobile-device-instantnoodlep/test/rtc-offset`
(17 cases: missing/corrupt state, bogus/sane clock, floor and backwards
guards, negative offset, hwclock fallback, round trip, idempotency), wired
into `test/all` together with `bash -n`, shellcheck and staging checks.

## 3. Failure modes

| Failure | Behavior |
| --- | --- |
| State file missing/corrupt at boot | log, leave the clock alone; NTP fixes it later as today |
| Wall clock below floor at `save` time | skip storing (no bogus offset) |
| RTC unreadable | log, do nothing |
| `rtc + offset` below the build floor | refuse, log |
| Target behind timesyncd clock file or current clock | refuse (never move backwards), log |
| NTP later corrects the clock | `apply` already ran or is a no-op; nothing is undone |
| Unclean power loss | last saved state file remains; next boot applies it |
| Package built long after the state was saved | floor only moves forward with builds; a stale-but-valid offset still restores a sane clock |
| RTC hardware write | never attempted (read-only sysfs/hwclock) |

## 4. Gated on-device runbook (coordinator/owner; AGENTS.md rule 1)

No step writes flash or partitions. Install is `pacman -U` of the built
package (or `makepkg -Csf` on the phone); all reboots are owner-gated.

| Gate | Action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| T1 | Build/install 0.0.9 on the phone (`pacman -U`), `systemctl daemon-reload`, check `systemctl list-unit-files 'omamobile-rtc-offset*'` and `systemctl show -p WantedBy --value` for apply, shutdown, timer and path | all five units listed (vendor `.wants` symlinks under `/usr/lib` show as `disabled` there; that is expected), WantedBy is sysinit/multi-user/timers/paths.target respectively | any unit missing or failed after `daemon-reload` | `pacman -R omamobile-device-instantnoodlep` (or reinstall 0.0.8) |
| T2 | Before any reboot, with NTP synced: `systemctl start omamobile-rtc-offset-save.service`; then `cat /var/lib/omamobile/rtc-offset` | state file holds `date +%s` minus `cat /sys/class/rtc/rtc0/since_epoch`, mode 600 | value is not an integer or is absurd | delete `/var/lib/omamobile/rtc-offset` |
| T3 | Clean reboot (`reboot`), then **before NTP**: `timedatectl`, `journalctl -b -u 'omamobile-rtc-offset*'`, `date -u` | apply logged "set the system clock to …"; `timedatectl` shows the restored time (not 1970), NTP sync "yes" only later | clock still 1970 after multi-user, apply unit failed, or clock moved backwards vs the timesyncd clock file | `systemctl disable --now omamobile-rtc-offset-apply.service omamobile-rtc-offset-shutdown.service omamobile-rtc-offset-save.timer omamobile-rtc-offset-save.path; rm -f /var/lib/omamobile/rtc-offset` |
| T4 | RAM-boot case: `fastboot boot boot-slim-*.img` (RAM only, no flash write), same checks as T3 before NTP | same as T3 | same as T3 | same as T3 (RAM boot changed nothing on flash) |
| T5 | Corrupt-state case on the phone: first `systemctl stop omamobile-rtc-offset-shutdown.service omamobile-rtc-offset-save.path omamobile-rtc-offset-save.timer` (otherwise the ExecStop save overwrites the garbage before the reboot), then `echo garbage > /var/lib/omamobile/rtc-offset`, reboot, check journal before NTP | apply logs "does not hold an integer" and leaves the clock alone (timesyncd may still advance it to its recorded timestamp), unit not failed | unit enters failed state | restore a valid state via `omamobile-rtc-offset save` with NTP synced |
| T6 | Clean shutdown saves: after T3, `systemctl reboot` and on the next boot check the state file's mtime advanced and the journal shows the ExecStop save | shutdown save logged | ExecStop did not run (killed by timeout) | none needed; hourly timer re-saves |

Full rollback of the feature: `systemctl disable --now` the five units,
`rm -f /var/lib/omamobile/rtc-offset /usr/bin/omamobile-rtc-offset
/usr/lib/systemd/system/omamobile-rtc-offset-*`, `systemctl daemon-reload`,
or remove the package.

## 5. Open items [I]

- `/sys/class/rtc/rtc0` is the PMIC RTC's sysfs name and `since_epoch` is
  readable there on the phone's kernel (host tests fake it).
- The phone's systemd rewrites `/var/lib/systemd/timesync/clock` on every
  sync, so the `.path` unit fires (host systemd 262 does; phone version
  unverified).
- Whether PID 1 on the phone already restores the clock from the timesyncd
  clock file at boot (systemd ≥ 252 does on the host [V: strings above]);
  if it does, `apply` becomes a harmless no-op or a forward-only correction.
- `timedatectl` before NTP on the phone shows the restored clock (T3).
