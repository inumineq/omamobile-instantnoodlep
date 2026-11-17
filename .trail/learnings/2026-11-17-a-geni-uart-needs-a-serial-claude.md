---
title: "A GENI UART needs a serial alias or it does not probe"
author: claude on macbookpro
date: 2026-11-17
branch: inumineq/wifi-bt
id: l-ad76f2af
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/WIFI-BT-M5-PLAN.md
---

## Watch out
- qcom_geni_serial (non-console port) without any `serial*` alias in the DTB fails probe with `Invalid line -19`: `of_alias_get_highest_id("serial")` returns -ENODEV and `ida_alloc_range()` refuses a negative minimum [V: K3 tree drivers/tty/serial/qcom_geni_serial.c probe and get_port_from_line; lib/idr.c; phone dmesg 2026-11-17].
- So the Bluetooth UART (uart6) needs `aliases { serial1 = &uart6; }`, as qrb5165-rb5 has. serial0 stays free for a debug UART (DTS-PORT-PLAN I5).
- Symptom on the phone: no hci0, hci_uart/btqca never load, `sync_state` pending on 998000.serial.
