<!-- SPDX-License-Identifier: MIT -->
# Type-C DP USB recovery candidates

macbookpro, `inumineq/typec-fix`, investigating QMP mode restore and USB2
clock behavior after DP Alt Mode on instantnoodlep.

Files in scope: `device/instantnoodlep/TYPEC-DP-PLAN.md`,
`docs/research/typec-dp-usb-recovery.md`, and a learning under
`.trail/learnings/`. Do not edit `DAILY-K3-PLAN.md`. Kernel candidates are
on `instantnoodlep-k3-typec-fix1` and `instantnoodlep-k3-typec-fix2` in
`inumineq/linux-omarchy-mobile`; builds stay in separate
`~/android/build/k3-typec-fix1/` and `~/android/build/k3-typec-fix2/`
directories. No phone is attached. All phone gates are RAM boot only and
run by the coordinator with the owner.
