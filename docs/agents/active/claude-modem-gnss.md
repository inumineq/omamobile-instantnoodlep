<!-- SPDX-License-Identifier: MIT -->
# GNSS and modem plan refresh

omabook, branch `modem-gnss`: refresh instantnoodlep MODEM-M5-PLAN and add GNSS-M5-PLAN using public sources; plans only, no phone access or kernel changes.

## Files in scope

- `device/instantnoodlep/MODEM-M5-PLAN.md`
- `device/instantnoodlep/GNSS-M5-PLAN.md`

## Current coordination facts

- K3 combo is on `boot_b` and contains the test-only `qcom,kona` root-compatible match patch.
- The neutral DTBO is parked; stock `dtbo_b` remains in place.
- No phone access in this worker task. All device steps are owner-gated runbook steps.
