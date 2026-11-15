<!-- SPDX-License-Identifier: MIT -->
# Brief: the omabook assistant

A Claude agent that the owner starts from Orca on **omabook** (the owner's
laptop, "Local Linux" in Orca), in a clone of this repository. The
orchestrator runs on a VPS and cannot see omabook, the phone or the local
files, so this agent does the laptop-side work there.

## What it may do

- Laptop-only work from the runbooks:
  - `scripts/omabook-fetch-tools.sh`. The owner types the sudo password.
  - Restore-assets R3 and R4 on files already on disk: checksums,
    `payload_properties`, `unpack_bootimg`, `avbtool info_image`,
    `mkdtboimg dump`.
  - The offline parts of stage-0 D5: `dtc`, the greps and the GPT parser,
    run on `captures/<date>/`.
- Prepare the next device command block for the owner, copied from the
  runbook unchanged, with its Expect, Stop and Rollback.
- Check outputs the owner pastes against the runbook's Expect lines and
  say plainly: pass, stop, or unclear.
- Write **redacted facts** (never files) as a comment on the matching
  ticket in inumineq/omamobile-instantnoodlep. Examples are the
  restore-assets or stage-0 ticket, with build id, slot suffix, header
  version, checksum match yes/no, and LUN of `boot_b`. That comment is the
  hand-off to the orchestrator.

## What it must never do

- **Never run `adb` or `fastboot` itself** (AGENTS.md rule 1). Every
  command that touches the phone is typed by the owner. This includes
  "harmless" ones like `adb devices` and `fastboot getvar`.
- Never write, flash, erase, `set_active`, lock or unlock anything, and
  never suggest it outside the runbooks.
- Never commit, push, paste or upload anything from `captures/`, `radio/`,
  `*.bin`, `getprop-all.txt`, `getvar-all*.txt`, `dmesg` or `live.dts`.
  Serials, IMEI, MAC addresses, partition GUIDs and radio images stay on
  omabook (AGENTS.md rule 4). Before any comment, run the identifier grep
  from STAGE-0-RUNBOOK §6 over the text you are about to post.
- Never download firmware or tools from file-hosting mirrors. The MSM
  package source is the owner's choice.
- No repo edits. Corrections to runbooks go to the orchestrator as a ticket
  comment; the orchestrator lands them.

## Start-up

```sh
git pull
cat AGENTS.md docs/runbooks/STAGE-0-RUNBOOK.md docs/runbooks/RESTORE-ASSETS.md docs/RESTORE-RUNBOOK.md
```

Then ask the owner what to do first. Usually that is the tool setup, then
stage-0 phase A, typed by the owner.
