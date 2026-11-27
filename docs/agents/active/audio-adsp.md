<!-- SPDX-License-Identifier: MIT -->
# audio-adsp

omaserver, inumineq/audio-adsp: audio phase 1 on the flashed daily2 kernel —
ADSP remoteproc on as a RAM candidate (`k3-daily2-adsp`), phone gate in
AUDIO-M5-PLAN §11.

Touches: `device/instantnoodlep/AUDIO-M5-PLAN.md`, this file.
Kernel side: linux-omarchy-mobile branch `instantnoodlep-k3-daily2-adsp`
(@ `625fc540c`, one DTS commit on `instantnoodlep-k3-slim-daily2`
`c5e256242` that keeps only `&adsp`), build `~/android/build/k3-daily2-adsp/`
on omaserver (clang/LLD 23.1.3, same artifact layout as `k3-daily2-qce`).
No boot image packed; no phone access; packing and phone steps stay with
the coordinator/owner.
