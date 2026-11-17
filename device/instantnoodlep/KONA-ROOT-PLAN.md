<!-- SPDX-License-Identifier: MIT -->
# KONA-ROOT-PLAN: remove the vendor root-compatible workaround

[V] Scope and source analysis: [KONA-ROOT-DESIGN.md](KONA-ROOT-DESIGN.md).
This plan gates the UBWC, PD mapper and cpufreq platform-device changes;
no new hardware nodes or firmware are introduced.

1. [V] Continue `~/src/l-k3k`, branch `instantnoodlep-k3-kona`, from combo
   `aa996bae0`, reverting the test-only Kona aliases before the series.
2. [I] Review SMEM readiness/error handling and preserve root-table matches;
   inspect enabled/disabled cpufreq controller selection before building.
3. [I] Build with `nice -n 10`, `ARCH=arm64 LLVM=1 W=1`, fresh output under
   `~/android/build/k3-kona`; compile both supported linkage configurations.
   Run `checkpatch --strict`; human DCO sign-off remains an owner action.
4. [I] Build a fresh RAM image with the existing probe builder and package
   matching modules. Hash both; do not install them or contact the phone.
5. [I] Coordinator executes only the gated runbook in KONA-ROOT-DESIGN §5,
   after owner approval. Stop on any failed expectation and return to the
   installed slot-B kernel. Never boot stock Android or change slot flags.

[V] The probe builder disables all remoteprocs; combo lacks the later
Wi-Fi/BT enablement (builder `make_probe_dtb`, combo board DTS).
[I] Runtime PD service and Wi-Fi association require a separately reviewed
integration candidate and their M5 plans; this candidate can establish the
absence of regressions and the explicit disabled-node baseline only.
