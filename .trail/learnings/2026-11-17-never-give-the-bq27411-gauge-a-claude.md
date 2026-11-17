---
title: "Never give the bq27411 gauge a monitored-battery; i2c5:0x66 is no BQ25980"
author: claude on omabook
date: 2026-11-17
branch: inumineq/power
id: l-6560a52f
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/POWER-M5-PLAN.md
  - device/instantnoodlep/kernel.config
---

## Watch out
- The bq27411 keeps its data memory in RAM (`BQ27XXX_O_RAM`), so the mainline bq27xxx driver writes design capacity, design energy and terminate voltage from a `monitored-battery` node on every probe, whatever `CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM` says [V: bq27xxx_battery.c:1048, 1339-1358, 1561-1564]. C/ and D/ give it one, so D/ rewrites the gauge each boot. The binding does not require the property; P1 leaves it out and the driver only reads.
- The part at i2c5:0x66 is a BQ2597x wireless charge pump, not the BQ25980 that C/ names [V: D/kernel-patches/0076]. The BQ25980 driver is out of our build.

## Decision
- Charging follows D/'s PM8150B driver and its gauge-led policy (D/docs/charging.md, patches 0068/0165/0166), whose limits match the stock E/ fragment@2 values. It is staged (POWER-M5-PLAN §0.5) until the P1 gauge reads plausibly on this unit.
