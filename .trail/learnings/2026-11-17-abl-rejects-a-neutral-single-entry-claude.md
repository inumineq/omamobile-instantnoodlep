---
title: "ABL rejects a neutral single-entry dtbo_b; dtbo_b stays stock"
author: claude on omabook
date: 2026-11-17
branch: inumineq/trail-code
id: l-48e0c482
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DTBO-PLAN.md
  - device/instantnoodlep/dtbo/neutral.dts
---

## Decided
- `dtbo_b` stays the stock OTA `dtbo.img`. The neutral one-entry dtbo from DTBO-PLAN §2 is ruled out as built [V: laptop session 2026-11-17, DTBO-PLAN D3; NOTES entry pending].
- Until another fix lands, the `qcom,kona` compatible rewrite stays and K3 boots with the test-only "DO NOT UPSTREAM" kona patch (tree `~/src/l-k3`, see docs/agents/where.md). Research on what ABL needs from a dtbo runs as the `abl-dtbo` worker.

## Tried and ruled out
- Neutral `dtbo_b` (one entry, stock entry 16's board ids, mainline root identity, no fragments, no AVB footer): ABL rejected it, marked slot B unbootable and fell back to slot A, which stopped in stock recovery [V: laptop session 2026-11-17]. Which of the two open [I]s failed (entry selection, or the missing AVB footer) is not known yet [I].

## Watch out
- A dtbo ABL does not accept costs the slot: slot B gets marked unbootable and the phone falls to slot A (stock). A stock boot has erased the ext4 root on `userdata` before (NOTES 2026-11-16 night), so check the root after any fallback [I: whether it survived this time].
- Recovery that worked: flash the stock `dtbo_b` back (D-R), `fastboot --set-active=b`, then redo the B5 success mark with `tools/instantnoodlep-slot-b-mark` from a fresh GPT read. All three are owner-gated writes (AGENTS rule 1).
- Offline `ufdt_apply_overlay` said the neutral image was harmless; offline checks do not model what ABL accepts.
