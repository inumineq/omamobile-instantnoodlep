<!-- SPDX-License-Identifier: MIT -->
# Sensors phase 1: packaging contract

[V] This is packaging guidance, not an installed or built Arch package.
No firmware, calibration, identity data, or proprietary library bytes are
included. The runtime gate remains SENSORS-M5-PLAN §10.2; no phone was
accessed while preparing this document. [I] Native aarch64 package builds,
owner-OTA names-only allowlist review, and runtime checks remain pending.

## Public source pins

[V] Pins were obtained with `git ls-remote` and source checkouts on
2026-11-17; references below are paths at those exact revisions.

| Component | Source / immutable revision | Build requirements and selection |
| --- | --- | --- |
| hexagonrpc 0.5.0 | <https://github.com/linux-msm/hexagonrpc> @ `da7a3742ab8d5273a281b70ee11f16fb2cb6a690` | Meson >=1.1, Ninja, C compiler; optional json-c tools (`meson.build:1`, `tools/meson.build:1`). Installs libhexagonrpc, hexagonrpcd and three systemd units (`data/meson.build`). |
| libssc 0.4.4 | <https://codeberg.org/DylanVanAssche/libssc> @ `033e2a32095c024d6dbdfb1d4ae1db4a94be32f1` | Meson >=1.4, Ninja, C compiler, GLib >=2.56, libqmi >=1.33.4 with QRTR support, protobuf-c, protobuf/protoc and its C generator; see `meson.build:20-80`. Installs libssc.pc and ssccli (`src/meson.build`). |
| iio-sensor-proxy 3.9 | <https://gitlab.freedesktop.org/hadess/iio-sensor-proxy> @ `ca0d5b08bd647afc5f8ead3ce00a44018fbc633f` | Meson >=0.54, Ninja, C compiler, GLib/GIO >=2.76, libgudev >=237, polkit, udev/systemd development metadata, libssc >=0.2.1; **explicitly** `-Dssc-support=enabled` (`meson.build:1-49`, `src/meson.build:3-14`). |

[V] The plan's older `agx/libssc` HEAD
`e0205d472a69e7482ecb63f025d7d6a00a1c7246` identifies itself as 0.1.7
and installs `libssc-glib.pc` (`meson.build:22`, `src/meson.build`), so it
cannot satisfy this proxy's `dependency('libssc', version: '>=0.2.1')`.
The selected current libssc source is the one used by proxy upstream CI
(`.gitlab-ci.yml:50`). Do not silently use the older fork.

[V] There is no extra IIO kernel bridge to build: proxy's SSC backend
links libssc (`src/meson.build:48-53`), which discovers the SSC QMI service
over QRTR (`libssc/src/libssc-client.c:356-368,473`). hexagonrpcd handles
reverse FastRPC requests for DSP files; it is not the sensor-value client.

## Native Arch packaging checklist

[I] Build on aarch64 in the matching local channel, with each source pinned
to the commit above and source checksums recorded in the eventual PKGBUILD.
Use `meson setup build --prefix=/usr --libdir=lib --buildtype=release`,
`meson compile -C build`, and
`DESTDIR="$pkgdir" meson install -C build`; add
`-Dssc-support=enabled` for the proxy. Do not run an upstream-channel
`pacman -Syu` to satisfy dependencies (learning `l-405b6773`).
Package names/dependency providers and build tests must be verified against
the selected Arch Linux ARM channel before installation.

[V] Do not install `omamobile-sensors`: it provides/conflicts with
`iio-sensor-proxy` and targets Pixel AoC (SENSORS-M5-PLAN §5).
The proxy package should provide the usual proxy D-Bus service and
monitor-sensor; its build must fail if libssc is missing. Confirm
`pkg-config --modversion libssc` is >=0.2.1 and inspect the resulting
binary's dynamic dependencies for libssc. [I] Record actual package build
results before treating O6 as passed.

[V] Upstream proxy's default misc udev rules advertise **only**
`ssc-light ssc-compass` on fastrpc-sdsp (`data/80-iio-sensor-proxy.rules:25`).
Acceleration discovery requires `ssc-accel`
(`src/drv-ssc-accel.c:36`), and proximity requires `ssc-proximity`
(`src/drv-ssc-proximity.c:32`). Therefore an instantnoodlep-specific
late rule is required for the phase-1 monitor test, for example:

```udev
# SPDX-License-Identifier: MIT
SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp", GROUP="fastrpc", MODE="0660", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"
```

[I] For the test, stage that rule under `/run/udev/rules.d/` and reload /
trigger only this device after the audited service stack is ready; ensure
proxy discovery happens after hexagonrpcd has attached the sensor PD.
Create the service user/group in a future package via sysusers; do not grant
world-writable access. Inspect device permissions and the udev properties
before starting the proxy. Remove the runtime rule and retrigger on rollback.
[V] Proxy upstream unit already allows `AF_QIPCRTR`
(`data/iio-sensor-proxy.service.in:17`); preserve it when adding hardening.
[I] The correct accelerometer mount matrix must be measured on the device;
no guessed matrix is packaged here.

## Firmware namespace and volatile state

[V] SLPI firmware destination stays exactly
`/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/slpi.mbn`
(`firmware.map:26`). The joined firmware comes from the owner's factory
image. It is not part of any source package.

[V] hexagonrpcd accepts
`-f /dev/fastrpc-sdsp -d sdsp -s -R ROOT`
(`hexagonrpcd/rpcd.c:70-84`; `data/hexagonrpcd-sdsp.service.in`).
Its default HexagonFS layout is documented in its `README.md:125-146`:
`dsp`, `sensors/config`, `sensors/registry`, `sensors/sns_reg.conf`,
`socinfo`. The mapped filesystem implementation opens files read-only
(`hexagonrpcd/hexagonfs_mapped.c:54,89`). Do not assume that creating an
empty registry provides working sensors.

[I] Provision only an allowlisted, owner-audited subset of `dsp/sdsp`,
`vendor/etc/sensors` and `odm/etc/sensor` from the owner's images, following
F2/F3. Do not recursively copy vendor directories. The current map has no
sensor-library/config allowlist, so this is a blocker for S6 rather than a
licence to extract arbitrary files. Never read or copy persist calibration.
Keep all test registry/cache under `/run/instantnoodlep-sensors`; stop if the
stack needs persistent writes or per-unit calibration. A future installer
may store immutable owner-supplied libraries/config in the reviewed
firmware tree only after its separate provisioning gate.

[I] Candidate runtime layout (not yet validated):

```text
/run/instantnoodlep-sensors/
  dsp/sdsp/               # reviewed owner libraries, read-only to service
  sensors/config/         # reviewed owner configs, read-only to service
  sensors/registry/       # empty; never populate from persist
  sensors/sns_reg.conf    # reviewed config only, if required
  socinfo/                # approved generic SoC fields only; no identifiers
```

[I] After the layout and provenance are reviewed, launch as the dedicated
non-root fastrpc user with only the SDSP node access:

```sh
hexagonrpcd -f /dev/fastrpc-sdsp -d sdsp -s -R /run/instantnoodlep-sensors
```

[I] Proposed systemd service packaging should use `RuntimeDirectory`,
`ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`,
`ReadWritePaths=/run/instantnoodlep-sensors`, and no StateDirectory or
persistent registry binding. The daemon's existing upstream unit defaults
to `/usr/share/qcom` and restarts indefinitely; replace those defaults
for the test, record logs privately, and stop on repeated DSP failures.
Do not enable ADSP units, which are outside phase 1.

## Validation boundary

[V] `ssccli --sensor accelerometer --timeout 3`,
`ssccli --sensor light --timeout 3`, and optionally
`ssccli --sensor proximity --timeout 3` are supported by the pinned
libssc CLI (`src/libssc-cli.c`, option table and sensor dispatch).
Proxy's `monitor-sensor` supports default accelerometer/light monitoring
and `--proximity` (`src/monitor-sensor.c`, option table).
[I] Proximity readings may be absent or unsuitable without factory
calibration; this task does not authorize fetching calibration to fix that.
[V] The read-only HexagonFS maps its virtual Android persist registry path
to the supplied ROOT/sensors/registry (`hexagonrpcd/rpcd_builder.c:163-168`);
that virtual name does not authorize mounting or reading the real persist
partition.

[I] No numeric sensor readings, orientation correctness, native packages,
or shell auto-brightness/rotation are claimed verified until S6/S7 pass.
