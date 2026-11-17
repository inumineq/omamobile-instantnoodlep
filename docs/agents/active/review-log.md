<!-- SPDX-License-Identifier: MIT -->
# review-log: continuous quiet code review, five areas, most risky first

Host obsidian, branch review/log + review/<area> PR branches. Read-only against the phone (no adb/fastboot/ssh); kernel tree reads only in ~/src/l-k3 (combo aa996bae0); no builds; nothing posted upstream or to external services. Findings: [V] file:line or [I]; fixes in one PR per area on review/<area>; defects as GitHub issues label `review`; running log in docs/agents/review-log.md. Power branch instantnoodlep-k3-power is another worker's, not reviewed here.

Areas: 1 kernel patches (camera, modem/Sahara) vs ~/src/l-k3; 2 DTS fragments + kernel.config; 3 tools/ + scripts/ shell safety; 4 plans/runbooks gated steps vs AGENTS.md safety model; 5 privacy scan of tracked files and git history.
