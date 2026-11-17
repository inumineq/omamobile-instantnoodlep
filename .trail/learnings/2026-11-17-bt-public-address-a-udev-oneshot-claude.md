---
title: "BT public address: a udev oneshot with the address stored on the phone"
author: claude on omabook
date: 2026-11-17
branch: inumineq/bt-addr
id: l-80ba159e
kind: decision
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/DAILY-K3-PLAN.md
  - device/instantnoodlep/rootfs
  - tests/omamobile-bt-addr
---

## Decided
- The QCA6390's public address is set at every boot by `80-omamobile-bt-addr.rules` (`DRIVERS=="hci_uart_qca"`) -> `omamobile-bt-addr@.service` -> `/usr/bin/omamobile-bt-addr hciN`: the Pixels' trigger and verification with dodge's address source [V: DAILY-K3-PLAN §5.3-5.4].
- The address lives only on the phone, in `/var/lib/omamobile/bt-public-addr` (mode 600): the owner's real one written by hand, or a random `02:` locally administered one generated on first run under `umask 077`. The script never prints it; the journal gets facts only [V: `device/instantnoodlep/rootfs/usr/bin/omamobile-bt-addr`].
- The script does not power the controller on before `public-addr`: an unconfigured controller cannot be powered, unlike the Pixels' BCM case [V: DAILY-K3-PLAN §5.3.3].

## Watch out
- `btmgmt` can exit 0 for an invalid index, so success is claimed only after a Read Info reply that reports the stored address; the host test covers that path with a fake `btmgmt` [V: `tests/omamobile-bt-addr`].
- `OMAMOBILE_BT_ADDR_FILE` and `OMAMOBILE_BT_ADDR_WAIT` exist for the host test only; the unit sets neither, so a change to the defaults is a change to the phone's behaviour [V: script header].
