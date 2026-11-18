<!-- SPDX-License-Identifier: MIT -->
# OnePlus 8 Pro alert-slider plan

Status: research and owner runbook only. No phone was accessed and no driver,
device-tree node, or calibration data is included. The modem/kernel RAM test is
not a gate for this subsystem; the specific gate here is the I2C1 Hall chip-ID
probe described in `MISC-HW-PLAN.md` §8.3. Do not enable a Hall client before
that probe identifies the fitted pair.

Evidence labels follow `AGENTS.md`: [V] is checked against the linked public
source or repository file; [I] is a design proposal or a fact still requiring
on-device confirmation.

## 1. Identified hardware and public sensor facts

- [V] The public OnePlus GPL source `cad09e061ef6`, `kona-oem.dtsi:49–95`,
  describes two Hall sensors on the `qupv3_se1_i2c` bus with either iSentek
  IST8801 devices at 7-bit addresses `0x18`/`0x19` or MagnaChip MXM1120 devices
  at `0x0c`/`0x0d`, IRQs 157/158, and a 1.8 V supply. `oneplus_tri_key.c:91–95`
  uses calibrated Hall positions to classify the physical slider. These are
  source descriptions, not proof of which devices this handset has. The
  read-only chip-ID probe in `MISC-HW-PLAN.md` §8.3 resolves that [I until run].
- [V] The IST8801 manufacturer page describes a digital linear Hall sensor,
  I2C interface, 1.8–3.6 V supply, 40.96 mT range, 500 Hz maximum ODR, and
  9-WLCSP package. Its downloadable register-map document requires a request
  or login, so this plan does not assert register addresses, ID values, data
  encoding, or interrupt programming from that document.
- [V] The publicly available MagnaChip MXM1120 datasheet (Rev. 2.4, §§7.1–7.2)
  identifies a linear Hall sensor with I2C, interrupt output, programmable
  measurement range/resolution, and registers: PERSINT `0x00`, INTSRS `0x01`,
  lower/upper thresholds `0x02–0x05`, I2CDIS `0x06`, reset `0x07`, OPMODE
  `0x08`, read-only DID `0x09` (reset value `0x9c`), INFO `0x0a`, status
  `0x10`, and measurement `0x11–0x12`. Datasheet §7.2 says the 10-bit and
  8-bit measurement formats are selected by OPMODE; do not infer scaling or
  byte order in a driver without checking the full datasheet and confirming
  the actual chip revision. The datasheet is linked for research, not copied
  into this repository.
- [V] Mainline Linux does not currently have an IST8801 or MXM1120 driver in
  the checked kernel source. Generic IIO magnetometer/Hall drivers exist, but
  neither sensor is a drop-in supported compatible there. No mainline input
  driver for this OnePlus dual-Hall slider was found. Recheck the target
  kernel's `drivers/iio/` and `drivers/input/` at implementation time; this
  status can change.

Public references:

- [OnePlus public GPL kernel, `cad09e061ef6`](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250/tree/cad09e061ef6):
  `arch/arm64/boot/dts/vendor/qcom/kona-oem.dtsi` and
  `drivers/input/misc/oneplus_tri_key.c` (used as factual descriptions only;
  no code is copied).
- [iSentek IST8801 product page](https://www.isentek.com/en/products/kzzOiTz9zB)
  (feature data; its register-map document is request/login gated).
- [MagnaChip MXM1120 datasheet, Rev. 2.4](https://static.chipdip.ru/lib2/a/851/DOC063851499.pdf)
  (manufacturer datasheet hosted by a distributor; see §§7.1–7.2).
- [Linux input event codes](https://docs.kernel.org/input/event-codes.html)
  (recheck the target kernel ABI before selecting an event code).

## 2. Proposed driver and calibration

- [I] Prefer a small upstreamable `hall-tri-state` driver under
  `drivers/input/misc/`. It should bind to the verified sensor pair, use the
  appropriate sensor-specific I2C transactions, sample both sensors together,
  and report one stable three-state value. Keep transport, filtering, and
  hysteresis in the driver; do not put per-phone thresholds or calibration
  values in device tree.
- [I] Use an input `EV_ABS` event with `ABS_MISC` range 0–2 for ring, vibrate,
  and silent. `EV_SW` codes are binary and the standard switch meanings do not
  describe all three alert positions; assigning unrelated `SW_*` meanings
  would misrepresent the hardware. Document the value mapping in the driver
  ABI and userspace consumer. Add settling/debounce and hysteresis based on
  measured noise and position separation, not guessed constants.
- [I] Keep calibration per device in `/var/lib/omamobile/alert-slider.json`,
  owned by root and mode 0600. The privileged calibration utility should
  validate a versioned schema and write atomically. Store three measured
  representative values/ranges for each sensor, polarity/orientation, and
  margin; do not store serials or other device identifiers. Do not commit,
  log, upload, or include raw readings in issue/PR text. If calibration is
  missing or invalid, report `unknown` and do not silently select a profile.

Owner calibration flow, after a working driver exposes raw paired samples:

1. Owner starts a local calibration utility and confirms the displayed sensor
   pair matches the chip-ID result.
2. For each prompted position (ring, vibrate, silent), move the physical
   slider there and hold it still. Collect a short stable window of paired
   raw values; show only the local median/spread and prompt again if the
   samples vary or overlap a prior position's margin.
3. Repeat every position at least three times, including transitions in both
   directions. Require each cluster to remain separated after applying a
   safety margin. Save through root-owned atomic replacement under
   `/var/lib/omamobile`; never print the values in shell history or logs.
4. Restart/reload the local service and verify each position is classified
   correctly. Recalibrate after sensor/slider repair or if the service reports
   ambiguous samples.

## 3. Userspace mapping

[I] A small device-package service should consume the input state and map
`0=ring`, `1=vibrate`, `2=silent` to the desktop audio profile. The shell's
profile action should set the audio policy and UI indicator, not write sensor
registers. Make the initial service opt-in until the event values and physical
positions are confirmed. On unknown/ambiguous state, preserve the last explicit
user profile and show a neutral unavailable indicator; do not force silent or
ring. Avoid logging transitions with timestamps or other location/context data.

## 4. Gated owner runbook (after chip-ID probe)

The earlier read-only probe is the prerequisite and should establish one
supported pair. The steps below are a future owner-only live test; no command
here has been run. The owner must review the matched datasheet, mainline
interface, DTS binding, and exact commands for the identified sensor before
the first sensor write. No flash or partition writes are part of this runbook.

| Step | Command / action | Expect | Stop | Rollback |
| --- | --- | --- | --- | --- |
| A0 — gates | Confirm M1b/M2 and M3 prerequisites, healthy slot-B baseline, reviewed RAM image, I2C1 chip-ID result, and owner go. | Identified pair is exactly IST8801 or MXM1120 at the documented addresses; no unidentified responding device. | Probe result is ambiguous, addresses differ, or I2C1 is not safely accessible. | Do not bind a driver; return to known-good slot B using the existing recovery plan. |
| A1 — passive values | Boot the approved RAM image with the reviewed driver in raw/read-only mode; run the device-specific read command from the reviewed implementation, first at neutral position and then at each physical detent. The exact command must be filled in only after the sensor register documentation and driver are reviewed. | Both sensors return plausible stable samples in every detent; transitions correspond reproducibly to physical movement. | Any read requires an undocumented write, sensor errors, unexpected bus activity, or unstable/overlapping position data. | Stop the test/service and reboot to known-good slot B; leave the node disabled. |
| A2 — calibration | Owner follows §2 flow locally, with all raw output redirected only to a private local terminal/file excluded from git. | Three distinct clusters with margin; calibration saved mode 0600 under `/var/lib/omamobile`. | Cluster overlap, permission mismatch, or any request to add raw values to a commit/log. | Delete the local calibration file and disable the service; no hardware state is persisted. |
| A3 — event check | Run `evtest` on the proposed input device while owner moves slider through all three detents repeatedly in both directions. | Exactly the documented `ABS_MISC` values 0/1/2, stable after settling, with no spurious transitions. | Wrong mapping, chatter, missed state, or a value outside 0–2. | Stop the service and unbind/disable the feature; reboot to known-good slot B if necessary. |
| A4 — shell profile | Enable the package service only for this test; move each detent and inspect the shell profile indicator/audio policy without playing loud audio. | Ring/vibrate/silent map to the correct UI and output policy; ambiguous state leaves the last user-selected profile unchanged. | A transition selects the wrong profile or causes unexpected sound. | Disable service and restore the user's prior audio profile. |
| A5 — final state | Check current slot and success flags using the existing read-only state procedure. | No partition or slot state changed. | Any unexpected slot/fallback or unknown state. | Stop feature work and follow the existing slot recovery plan. |

## 5. Privacy and implementation limits

- Calibration values are device-specific and remain in `/var/lib/omamobile`;
  never add them to git, captures, logs, bug reports, or upstream issues.
- No Hall measurement samples are required for package operation after
  calibration. Diagnostic mode must be explicit, local, and short-lived.
- No proprietary vendor source or firmware is copied. Public GPL source is
  cited only for board topology and calibrated-position behavior; sensor
  protocol implementation must be written from public documentation.
- No compile-ready skeleton is proposed yet because the public IST8801
  register map is gated and the handset's fitted chip pair and field scaling
  remain unconfirmed. Resolve those facts before code or DT changes.
