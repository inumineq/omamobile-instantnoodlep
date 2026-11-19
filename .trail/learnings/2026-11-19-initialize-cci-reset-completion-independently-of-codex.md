---
title: "Initialize CCI reset completion independently of enabled buses"
author: codex on macbookpro
date: 2026-11-19
branch: inumineq/cam-cci
id: l-07c02921
kind: lesson
scope: repo
status: active
src: agent
touches:
  - device/instantnoodlep/CAMERA-BISECT.md
  - device/instantnoodlep/patches/camera-bisect
---

## Watch out

- [V] B2 only enables CCI1 master 1. CCI probe initializes completions
  for available DT children, but reset and its ACK use master 0
  (kernel `350441f7b9fe`, `drivers/i2c/busses/i2c-qcom-cci.c:143–146,271–288,523–563`).
- [I] Use the two completion tests in CAMERA-BISECT before changing
  clock rates, GDSC behavior, interconnect votes or the sensor wiring.
