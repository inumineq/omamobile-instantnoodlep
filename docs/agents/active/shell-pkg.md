<!-- SPDX-License-Identifier: MIT -->
# shell-pkg

macbookpro, inumineq/shell-pkg: build a patched `omamobile-shell` 0.2.133-1.1 package (patches 0001/0002 from PR #71) in the ALARM container and write the install/rollback/restart runbook for SHELL-UX-PLAN step 3; no phone access.

- Touches `device/instantnoodlep/SHELL-UX-PLAN.md`, `device/instantnoodlep/tools/`, `docs/agents/state.md`.
- The shell is not a systemd user unit: `omarchy-restart-shell` (omarchy 4.5.0-3) is the restart path, and it refuses while the session is locked. Do not add a unit for it.
- Artefacts stay on this Mac in `~/vibe-runs/shellpkg/out/`; nothing is pushed to the phone from here.
