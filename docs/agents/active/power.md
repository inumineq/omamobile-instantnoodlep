<!-- SPDX-License-Identifier: MIT -->
# Active work

omabook, inumineq/power (PR #69): P2b charger-as-module kernel built offline (release `7.3.0-rc6-instantnoodlep-k3-g8c252b516245`), modules tarball and RAM image `boot-p2b-charger-m` built, §7.5 runbook + hang analysis written; RAM boot pending the coordinator's gates; this worker writes no partition and never touches the phone.

- Touches: `device/instantnoodlep/POWER-M5-PLAN.md`,
  `device/instantnoodlep/NOTES.md`, `device/instantnoodlep/kernel.config`,
  `tools/instantnoodlep-charge-watch`, `.trail/learnings/`,
  `docs/agents/state.md` (power rows only after the main merge).
- Kernel tree `~/src/l-k3p` (branch `instantnoodlep-k3-power`, tip
  `8c252b516245`), build dir `~/android/build/k3-power-p2b`; RAM artifacts
  in `~/android/build/k3-power-ram/boot-p2b-charger-m*`.
- The P2 freeze (§7.4) is still unexplained; P2b arms hung-task/lockup
  panic + ramoops pmsg so a repeat leaves a pstore dump. The P2 delta
  hang review with file:line is in §7.5.
- Stop the charge watch by its PID file, never `pkill -f` over ssh
  (it matches the ssh shell itself and kills the session).
