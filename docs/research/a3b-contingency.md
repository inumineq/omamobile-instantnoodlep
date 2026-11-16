<!-- SPDX-License-Identifier: MIT -->
# A3b contingency: routes that put stock on slot A if the same-version local install is refused

- Origin: read-only web research, 2026-11-15. No phone was touched and no
  command here runs on the phone. Ticket: the A3b decision in
  `docs/runbooks/STAGE-0-RUNBOOK.md` (stage-0 ticket "Stage-0 capture on
  the owner's phone (IN2023)").
- Situation (facts from stage-0 A3): stock
  `IN2023_13.1.0.591(EX01)` (build date 2025-10-11, the final EEA build)
  runs from slot `_b`; bootloader locked; verified boot green.
- Rule frame: the port never writes `super` or any `_a` partition
  [V: AGENTS.md:17]. The only writers allowed to touch `_a` are OnePlus's
  own tools (system updater, recovery, MSM), run by the owner
  [V: docs/RESTORE-RUNBOOK.md:7,94]. Slot A must keep stock
  [V: docs/RESTORE-RUNBOOK.md:15]; the descriptor pins the port's writes to
  slot B images plus `userdata` [V: device/instantnoodlep/device.conf:69].

> **Resolved 2026-11-16, not needed.** Route 6.1 worked: the same-version
> local install of the `.591` full zip was accepted and stock now runs
> from `_a` (locked, `green`) [V: stage-0 A3 rerun, see
> `device/instantnoodlep/NOTES.md` 2026-11-16]. The routes below stay as
> a record in case stock ever lands on `_b` again.

Legend: **[V]** = checked, with a source URL or file:line. **[I]** =
inference or search snippet; check it on the device or in the file.

## 0. Mechanics every route shares

- Any successful A/B install (OTA, local install, recovery) writes the
  currently unused slot, then marks it active; the slot is only marked
  successful after a good boot [V:
  docs/research/restore-assets-scouting.md:180-183,
  https://source.android.com/docs/core/ota/ab]. So from `_b`, one
  successful install of the `.591` full zip lands stock on `_a`. The only
  open question is whether OnePlus's updater accepts a same-version
  package [I: scouting §2, lines 195-197].
- A failed install falls back to the old slot by itself [V: scouting §2;
  STAGE-0-RUNBOOK.md A3b Rollback].

## 1. Route 1: local install of an older EEA full zip (downgrade)

- Steps would be: download an older EEA full zip (e.g. `13.1.0.587`),
  Settings → About device → OxygenOS → ⋮ → Local install.
- A downgrade via local install is refused by the Oplus updater's version
  check, with an error ("Verification failed" / "older than the installed
  version"), not a wipe [I: scouting §2, lines 202-204;
  https://droidwin.com/fix-verification-failed-when-installing-update-in-oneplus/
  (blocked to the fetcher; snippet);
  https://www.reddit.com/r/OnePlus8/comments/tst7g6/ ("the version I wanna
  roll back to is older than the one I have installed ... doesn't let me
  install it")].
- ARB: the device's anti-rollback index is read with `fastboot getvar
  anti` [I: https://magiskmodule.gitlab.io/blog/how-to-check-anti-rollback-index-of-oneplus-device-firmware/].
  A build's own ARB index is embedded in its `xbl_config` (0x0 means free
  of ARB) and can be parsed offline from the zip on the laptop [I:
  https://droidwin.com/how-to-check-anti-rollback-index-of-oneplus-device-firmware/].
  The public ARB trackers cover only OnePlus 12/13/15/16-era models, not
  the 8 Pro [V: https://github.com/Droidwin/OnePlus-arb-checker README].
  OnePlus 8 Pro EU downgrades from OOS 13 to 11 via MSM are reported
  working [I: https://xdaforums.com/t/oneplus-8-pro-eu-downgrade-from-oxygen-13-to-oxygen-11.4523467/].
  The January 2026 fuse-bricking wave targets ColorOS 16-era models, not
  this 2020 device [I:
  https://9to5google.com/2026/01/20/oneplus-update-starts-bricking-phones-when-you-try-to-install-older-software/].
- Verdict: not usable. The updater refuses the older zip before any
  write [I]. Even if forced, the payload's older `xbl` could trip ARB and
  leave a phone that does not boot [I]. And the install would land on an
  old build, which then needs the OTA chain back up, flipping the slot
  again [V: §0]. The ARB index of this unit and of `.591` is unknown until
  measured (`fastboot getvar anti`; parse `xbl_config_a` from the `.591`
  payload on the laptop).

## 2. Route 2: OnePlus "rollback" packages

- What they are: officially signed downgrade zips that OnePlus publishes
  only across a major-version transition, installed via Local install
  [V: https://oxygenupdater.com/article/361/, fetched 2026-11-15; I:
  https://www.xda-developers.com/how-to-install-oxygenos-ota-updates-on-oneplus-phones/].
- For the 8/8 Pro they exist only as OOS 13 → 12 (`C.35`/`C.36`), EU
  included, and they "will wipe all your data" [V:
  https://oxygenupdater.com/article/361/]. The community notes the
  downgrade method works only for the IN and EU variants [I:
  https://community.oneplus.com/thread/1200191691983159301]. No
  13.1 → 13.0 rollback package exists; rollback is major-version only
  [I, same sources].
- The runbook ban is correct: "Never use a 'rollback' package: those are
  special builds that wipe data" [V: docs/runbooks/STAGE-0-RUNBOOK.md:171-172].
  A rollback install would still flip one slot like any OTA [V: §0], but
  it wipes userdata and lands on OOS 12, from which the whole OTA chain to
  `.591` is needed anyway. It buys nothing over route 3 and costs a wipe.

## 3. Route 3: MSM Download Tool (EU `IN11BA`) plus an OTA chain

- Slot after MSM: the MSM tool only flashes slot A, and the phone boots
  stock afterwards, so slot A is active after MSM [I:
  https://communityus.oneplus.com/thread/1541327 ("The MSM tool only
  flashes to slot A"; "updating to the newest firmware after MSM ...
  will flash OOS to slot B")]. Confirm with `fastboot getvar current-slot`
  after MSM (expect `a`).
- Steps:
  1. EDL mode (phone off, hold Vol+ and Vol− while plugging in USB),
     `MsmDownloadTool V4.0_Win7.exe`, EU `IN11BA` package. Windows only,
     native USB 2.0 port, no VM [V: scouting §3.1]. EU MSM packages stop
     at OOS `11.0.4.4` [V: scouting §3.1, lines 213-214].
  2. Result: locked OOS 11.0.4.4 on slot A, all data wiped, bootloader
     relocked [V: scouting §3.1, lines 245-247; docs/RESTORE-RUNBOOK.md
     Path 2]. Never "SMT Download" mode [V: scouting §3.1].
  3. Install full zips through the stock updater (zips fetched with
     Oxygen Updater): `11.0.4.4` → OOS 12 (`C.xx`) → OOS 13 (`F.xx`) →
     13.1 (`5xx`) → `.591`. Each install flips the slot exactly once
     [V: §0]. Starting from A, the active slot after n installs is A iff
     n is even.
  4. So land `.591` on A by making the install count even (for example
     `C.36`, `F.15`, a `13.1.0.58x`, then `.591` = 4 installs). Intermediate
     EEA full zips exist at every era [V: scouting §1.1], so the parity is
     freely adjustable. Check the slot after each install with the A3
     rerun (`ro.boot.slot_suffix`) [V: STAGE-0-RUNBOOK.md A3b].
- Data loss: one full wipe at MSM; the OTAs afterwards do not wipe [I].
  In the port timeline this is no extra loss, because stage-0 phase C
  (unlock) wipes anyway [V: STAGE-0-RUNBOOK.md Phase C].
- Lock state: MSM relocks [V: scouting §3.1]; OTAs install fine on a
  locked phone [I]. End state: locked, stock `.591` on slot A.
- ARB risk: MSM writes OOS 11's `xbl` through EDL. If the unit's ARB
  fuse sat above OOS 11's index, the phone would not boot afterwards
  (EDL-only). Evidence says this does not happen on the 8 Pro [I, sources
  in §1], but check first: `fastboot getvar anti` against the ARB index
  in the MSM package's `xbl_config` and in `.591`'s `xbl_config_a`
  (laptop, offline) [I method].
- Side effect: slot B then holds the previous build's firmware, so the
  two bootloader slots may differ. Stage-0 D4 records that
  (`bootloader-ab.txt`), and upstream wants matching bootloader slots
  before a slot-B install [V: docs/research/gpt-exception-prep.md §4,
  quoting upstream CONTRIBUTING.md L63].
- Cost: a Windows PC, one data wipe, the relock, and the OTA chain.

## 4. Route 4: living with stock on `_b` (completeness, not a recommendation)

- What breaks: the port's only allowed writes are slot-B boot images and
  `userdata` [V: AGENTS.md:17; device/instantnoodlep/device.conf:69]. With
  stock on `_b`, installing the port means either writing `_a` (banned,
  always) or overwriting `_b`, which destroys the only stock copy and the
  way back.
- Path 0 of the restore runbook assumes slot A keeps stock [V:
  docs/RESTORE-RUNBOOK.md:15]. Upstream §3.1 requires the way back as
  "stock restored on slot A first, or the owner's written acceptance of
  buttons-only recovery" [V: docs/research/gpt-exception-prep.md §1,
  quoting UP/CONTRIBUTING.md#L60]. A doubly broken GPT would then be
  EDL-only [V: gpt-exception-prep.md §6.2].
- Precedent: enchilada ran with slot A not stock only after the owner's
  written acceptance saying what slot A holds [V:
  gpt-exception-prep.md §6.3, upstream #432 comment 6709637591]. No
  upstream device runs with stock on slot B. The stage-0 A3b Stop already
  leaves "go on with stock on `_b`" to the owner [V:
  docs/runbooks/STAGE-0-RUNBOOK.md A3b].
- Verdict: not viable under current rules without a maintainer-approved
  written acceptance, and it gives up the buttons-only way back.

## 5. Route 5: other credible routes

- 5a. `adb sideload` from stock recovery: OnePlus disabled ADB sideload on
  its A/B devices [I: https://xdaforums.com/t/guide-enable-adb-on-the-stock-oxygenos-recovery.4179839/;
  https://xdaforums.com/t/stock-recovery-has-no-option-for-apply-update-from-adb.4137851/].
  Recovery zip-flash existed only on some OOS 11 non-A/B devices and was
  deprecated with OOS 12 [I:
  https://www.xda-developers.com/how-to-install-oxygenos-ota-updates-on-oneplus-phones/].
  Expect unavailable on OOS 13. Checking costs one recovery boot; a refusal
  writes nothing [I].
- 5b. Recovery local-file install: the OOS recovery may offer "install
  from internal storage"; whether it skips the updater's same-version
  check is unknown [I]. Cheap to try; a refusal writes nothing [I].
- 5c. Other entry points for the same `.591` zip: the ⋮ → Local install
  menu on OOS 13, or the OnePlus-provided local-update APK that appears as
  "System update" [V: https://oxygenupdater.com/article/361/; I:
  https://xdaforums.com/t/oneplus-8-pro-rom-ota-oxygen-os-repo-of-oxygen-os-builds.4084315/].
  Same update engine, so the same-version check probably still applies
  [I], but it is free to try.
- 5d. Wait for an OTA: none. The device is end-of-life; `.591` (build date
  2025-10-11) is the final EEA build [V: stage-0 A3 facts; scouting §1.1].
- 5e. A newer cross-region build: none. `.590` was India-only and older
  than `.591` [V: scouting §1.1].
- Excluded by the task and AGENTS.md rule 8: file-hosting mirrors and
  leaked tools.

## 6. Ranked recommendation

1. A3b case (c): same-version local install of the `.591` full zip via the
   system updater, then via the local-update APK entry point if the first
   is refused (5c). Zero data loss, no lock change, and the stock updater
   — not the port — writes `_a`. Decisive [I], now answered [V
   2026-11-16]: the updater accepts a same-version full zip.
2. If refused: recovery local-file install of the same zip (5b), if that
   menu exists on this unit. Same profile as 1.
3. If refused everywhere: MSM route (§3) with an even install count.
   Deterministic by A/B mechanics; costs one wipe (phase C wipes anyway),
   a relock, a Windows PC and the OTA chain. Pre-check `fastboot getvar
   anti` against both packages' `xbl_config`.
4. Never for slot moving: an older-zip downgrade (§1, refused, ARB risk)
   or a rollback package (§2, wipes, lands on OOS 12).
5. Last resort, not recommended: live with stock on `_b` (§4). Needs a
   maintainer-approved written acceptance (enchilada precedent) and gives
   up the way back.

Decisive [I]s the owner can check cheaply:

- `fastboot getvar anti` in phase B (read-only; add it to the B2 grep):
  the device's ARB index.
- ARB index inside `.591`'s `xbl_config_a` and inside the MSM package's
  `xbl_config`, parsed on the laptop (SecTools method) [I method].
- One same-version local-install attempt (a refused install writes nothing
  [I]) — this is the A3b case (c) test itself.
- One recovery boot: does any local-file or sideload entry exist in the
  OOS 13 recovery on this unit?
- After any MSM: `fastboot getvar current-slot`, expect `a` — the parity
  base for route 3.
