<!-- SPDX-License-Identifier: MIT -->
# Sensors phase 1
omabook, inumineq/sensors: SLPI/FastRPC kernel candidate and userspace packaging/runbook; no phone access.

[V] Dispatched task task_06d66c50c8ca; kernel worktree ~/src/l-k3-sensors, branch instantnoodlep-k3-sensors based on combo.

[V] Source/packaging audit and runbook pushed; kernel patches pass checkpatch.
[V] Kernel head 314f6714e5f2d4a3360d1ff0dbc35ba0c86d9f8d; output root
`~/android/build/k3-sensors-20261117/`; coordinator reniced to 15, keep -j4.
Build pipeline is running: initial compile, release synchronization/modules
packaging (`finish-build.sh`), then offline RAM image (`build-ram-image.py`).
Schema target is CHECK_DTBS=1 on this board, separate `schema/` output;
`compare-schema.py` compares diagnostics against the known combo DTB.
[I] No artifacts/hashes, runtime success, PR, or phone steps are complete yet.
Finish by collecting results into plan §10.3, updating state, removing this
file, running Trail lint and opening the private-repo PR. No upstream push.
