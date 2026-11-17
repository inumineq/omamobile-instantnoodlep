<!-- SPDX-License-Identifier: MIT -->
# Miscellaneous hardware phase 1

[V] Apply the numbered GPL kernel patches in order to combo `aa996bae0`
(`instantnoodlep-k3-combo`). They are exported from the local
`instantnoodlep-k3-misc` branch. The inherited test-only Kona match is
**not** in this series and must never be sent upstream.

[V] `kernel.config` is a fragment for this test release, merged after the
combo configuration. Both new hardware nodes and I2C1 remain disabled in
the committed board DTS. `MISC-HW-PLAN.md` §8 describes the separate RAM
candidates, source pins, checks and owner-only runbook.

[V] The haptics driver derives from the public GPL-2.0-only
[SM8250 driver at tag 7.2.0-dev](https://gitlab.nura.eco/soc/qualcomm-sm8250/linux/-/blob/3c5440e9dd3c3e3b5735ad8f1b22bdfd02c707d9/drivers/input/misc/aw8695-haptics.c).
It retains copyright, generates a sine with Linux fixed-point arithmetic,
and requests no firmware. Its lifecycle, fault handling, gain scaling,
parameter checks and finite playback differ from that source. Probe-time
resonance calibration can cause a brief vibration. The provisional binding
retains the source author's contact; this is no claim that the author has
accepted maintenance or reviewed this series.

[I] Haptics and torch remain untested on this handset. The alert-slider
**driver is deferred**, as agreed with the coordinator: I2C1 is prepared for
four chip-ID reads only. No Hall clients, supply manipulation, stock
calibration, profile daemon or desktop integration are included.
