<!-- SPDX-License-Identifier: MIT -->
# GNSS userspace for instantnoodlep

## Decision

Use Arch Linux ARM's `modemmanager`, `libqmi`, `libqrtr-glib`, and
`geoclue` packages. `libqmi` has the QMI LOC service and the QRTR backend;
`qmicli` supports `qrtr://<node>` and LOC operations. ModemManager 1.24.2's
shared QMI location implementation creates a LOC client and exposes GPS NMEA
and raw sources through `org.freedesktop.ModemManager1.Modem.Location`.
GeoClue's modem provider consumes ModemManager's GPS NMEA source.

This establishes protocol and API support, not successful SDX55 operation on
this image. The modem kernel has not been RAM-tested and its private RFS
backing is unresolved. Do not start GNSS until MODEM-M5's RAM and privacy
gates pass.

Source references:

- [ModemManager 1.24.2 shared QMI location implementation](https://github.com/linux-mobile-broadband/ModemManager/blob/1.24.2/src/mm-shared-qmi.c)
- [ModemManager QMI modem location interface](https://github.com/linux-mobile-broadband/ModemManager/blob/1.24.2/src/mm-broadband-modem-qmi.c)
- [libqmi LOC CLI](https://github.com/linux-mobile-broadband/libqmi/blob/1.38.0/src/qmicli/qmicli-loc.c)
- [libqmi QRTR support and `qrtr://` device syntax](https://github.com/linux-mobile-broadband/libqmi/blob/1.38.0/NEWS)
- [GeoClue ModemManager provider](https://github.com/geoclue/geoclue/blob/2.8.2/src/gclue-modem-manager.c)
- [Arch Linux ARM ModemManager](https://archlinuxarm.org/packages/aarch64/modemmanager), [libqmi](https://archlinuxarm.org/packages/aarch64/libqmi), and [GeoClue](https://archlinuxarm.org/packages/aarch64/geoclue)

Install packages:

```sh
pacman -S modemmanager libqmi libqrtr-glib geoclue
```

`modemmanager` depends on `libqmi` and `libqrtr-glib` in Arch Linux ARM's
package metadata. `qmicli` is shipped by `libqmi`. Do not enable the
ModemManager or GeoClue service at package install time. No udev or polkit
rule is required: clients use ModemManager's system D-Bus API and its
existing policy.

Install `geoclue.conf` to `/etc/geoclue/geoclue.conf` only as part of an
owner-approved package deployment. Its providers are disabled, including
modem GPS; this avoids network geolocation and prevents GeoClue from
requesting an assisted modem mode. Direct GNSS testing is separately
opt-in using `mmcli` after R1-R2 in `GNSS-M5-PLAN.md`.

## Offline capability checks

On a build host with the target Arch Linux ARM package database:

```sh
pacman -Si modemmanager libqmi libqrtr-glib geoclue
pacman -Ql libqmi | rg '/(qmicli|qmi-service-loc)'
qmicli --help-all | rg -- '--loc-(start|stop|follow-nmea|follow-position-report)'
```

The repository package metadata currently lists ModemManager 1.24.2-1 and
libqmi 1.38.0-1 for aarch64. Confirm the actual target mirror/package versions
at install time. The source audit is ModemManager 1.24.2
`src/mm-shared-qmi.c` and `src/mm-broadband-modem-qmi.c`, libqmi 1.38.0
LOC/QRTR APIs, and GeoClue's `gclue-modem-manager.c`.

## Location privacy

- GNSS is off until explicitly enabled by the owner; no GNSS unit is enabled.
- A-GPS, SUPL, XTRA/orbit downloads, Wi-Fi/cell/IP location lookups, and
  network NMEA are disabled by default. Do not use GeoClue's modem provider
  until its assisted-source behavior is confirmed for the installed version.
- Never log coordinates, NMEA, satellite identifiers, or precise fix times
  to git, issues, or shared logs. Keep captures in ignored `captures/` and
  report only pass/fail, coarse TTFF bucket and accuracy category.
- Never put modem NV, EFS, calibration, or per-device state in this package.

No QMI LOC to NMEA bridge is included: the current upstream ModemManager and
libqmi sources provide the required APIs. If the installed build cannot
discover LOC over QRTR, stop and revise this decision before adding another
LOC client; do not run it concurrently with ModemManager.
