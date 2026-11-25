<!-- SPDX-License-Identifier: MIT -->
# udev policy for omamobile-device-instantnoodlep

One rule file per feature, named `<NN>-omamobile-<feature>.rules` under
`udev/`, staged to `/usr/lib/udev/rules.d/` by `install`. Every shipped rule
is parsed by `test/udev` (wired into `test/all`), which fails if a rule
file is not listed in the table below or not staged by `install`, has a
syntax error, names a group that neither `sysusers.d/omamobile.conf` nor
base Arch provides, sets an invalid mode, repeats a match key, or points
`SYSTEMD_WANTS`/`TAG` at something the package does not ship. Per-feature
work therefore shrinks to its one rule file plus one row here.

## Policy table (device class → group → mode → why)

| Device class | Rule file | Group | Mode | Extra keys | Why |
| --- | --- | --- | --- | --- | --- |
| Bluetooth controller: `SUBSYSTEM=="bluetooth"`, `KERNEL=="hci[0-9]*"`, `DRIVERS=="hci_uart_qca"` | `80-omamobile-bt-public-addr.rules` | — (root) | — | `TAG+="systemd"`, `ENV{SYSTEMD_WANTS}+="omamobile-bt-public-addr@%k.service"` | The QCA6390 has no factory public address. The unit assigns a stable, locally administered one, stored only in `/var/lib/omamobile/bt-public-addr` mode 600 [V: `bin/omamobile-bt-public-addr`, `systemd/omamobile-bt-public-addr@.service`]. No device node permission is needed, so no group/mode. |
| Camera nodes: `SUBSYSTEM=="video4linux"` and `SUBSYSTEM=="media"` (planned, one rule file when it lands) | planned | `camera` | `0660` | `TAG+="uaccess"` | Camera access for the session user without root. A dedicated group, not the shared `video` group and not root, keeps camera access auditable and separable from display/GPU access. The group is created by `sysusers.d/omamobile.conf`; `uaccess` gives the active seat-0 user the ACL at runtime. |
| Haptics FF node: `SUBSYSTEM=="input"`, `KERNEL=="event*"`, vibrator `ATTRS{name}` (planned, one rule file when it lands) | planned | — | — | `TAG+="uaccess"`, `ENV{FEEDBACKD_TYPE}="vibra"`, optionally `TAG+="systemd"` + `ENV{SYSTEMD_WANTS}` | Lets feedbackd drive the AW869x vibrator as the desktop user; upstream per-device rules use the same shape [V: upstream omarchy-mobile @ 8991845, `packages/omamobile-device-cheetah/vendor/udev/rules.d/72-omamobile-feedbackd.rules`]. |
| Torch LED: `SUBSYSTEM=="leds"`, flash `KERNEL=="white:torch"` (planned, one rule file when it lands) | planned | `video` (base Arch group) or — | — | — | The torch consumer runs as the desktop user; the kernel's board current cap bounds every request regardless of who writes [V: upstream `packages/omamobile-device-tegu/vendor/udev/rules.d/20-omamobile-torch.rules` grants `video` on the brightness attribute]. |

## Conventions for new rules

- One file per feature; add the file to `install`, to the table above and
  let `test/udev` cover it automatically (it globs `udev/*.rules`).
- SPDX header on every rule file, like the existing one.
- Rules that set `TAG+="uaccess"` must sort before `73-seat-late.rules`,
  which turns the uaccess tag into an ACL [V: upstream cheetah
  `72-omamobile-feedbackd.rules` comment, ibid.].
- Every `GROUP=` must be declared in `sysusers.d/omamobile.conf` or be a
  base-Arch group (`video`, `input`, `audio`, ... are created from
  `/usr/lib/sysusers.d/` [V: host `ls /usr/lib/sysusers.d`,
  `grep -h '^g' /usr/lib/sysusers.d/*.conf`]). `test/udev` enforces this.
- Every `ENV{SYSTEMD_WANTS}` unit must ship in this package (or be a base
  system unit), and the same rule must also `TAG+="systemd"` — the service
  manager ignores `SYSTEMD_WANTS` on devices without the `systemd` tag
  [V: man systemd.device, SYSTEMD_WANTS=]. `test/udev` enforces both.
- `TAG+` is limited to the builtins `systemd` and `uaccess` (extending this
  list is a one-line change in `test/udev` plus a row here).
- `RUN+=` targets under `/usr/bin/omamobile*` must exist in `bin/`.
- No serials, MAC addresses, IMEI or per-device identifiers in any rule
  (AGENTS.md rule 4); match on driver/device class, not on unit identity.

## Groups on an already-installed phone (owner-gated runbook)

`sysusers.d/omamobile.conf` ships as `/usr/lib/sysusers.d/omamobile.conf`.
`systemd-sysusers(8)` applies it — at boot via `systemd-sysusers.service`
when `/etc` changed, or immediately with an explicit file argument
[V: man systemd-sysusers.service; host `systemctl cat
systemd-sysusers.service`]. On a phone that already has the package
installed and has already run firstboot, the owner creates the group and
adds the login user by hand. These steps write `/etc/group` on the phone,
so they run only on the owner's explicit go (AGENTS.md rule 1).

1. Create the group now:
   - Command: `sudo systemd-sysusers /usr/lib/sysusers.d/omamobile.conf`
   - Expect: exit 0, no output; then `getent group camera` prints
     `camera:x:<gid>:`, and `test/udev` on the package source still passes.
   - Stop: `systemd-sysusers` reports an error, or `getent group camera`
     prints nothing.
   - Rollback: `sudo groupdel camera` — safe while no shipped rule names
     the group (`test/udev` keeps rule files and this file consistent), or
     reinstall the previous package version.
2. Add the session user (the login user firstboot created) to the group:
   - Command: `sudo usermod -aG camera <login-user>`
   - Expect: `id <login-user>` lists `camera`; the group applies from the
     next login (log out and back in).
   - Stop: the user name is unknown or `usermod` fails.
   - Rollback: `sudo gpasswd -d <login-user> camera`.
3. After the camera rule ships (planned), verify once on the phone:
   - Command: `udevadm info /dev/video0 | grep -E '^(E: )?(GROUP|MODE)'`
     (adjust the node name to what the camera binds).
   - Expect: `GROUP=camera`, `MODE=0660` (and a `uaccess` ACL in
     `getfacl /dev/video0` while the session is active).
   - Stop: any other group/mode, or the node stays root-only.
   - Rollback: remove the rule file from the package and reinstall; the
     group itself is inert without a rule naming it.

On fresh installs, firstboot creates the session user in
`wheel,audio,video,input` [V: upstream omarchy-mobile @ 8991845,
`packages/omamobile-firstboot/bin/omamobile-firstboot:87` `GROUPS_WANTED`]
plus every group listed in `/var/lib/omarchy/provisioning/groups` that
exists in `/etc/group` [V: ibid. :279]. This package does not ship that
file, so step 2 above applies to fresh installs too.
