<!-- SPDX-License-Identifier: MIT -->
# DTBO-PLAN: a neutral dtbo on slot B for instantnoodlep

House-rule-6 gate for writing `dtbo_b`. Date: 2026-11-17. Amends
BRINGUP-M1b-PLAN §4, which kept `dtbo_b` stock.

## 1. Problem [V]

- The stock dtbo that ABL applies on every boot, including `fastboot boot`,
  rewrites the root of the mainline DTB: on the phone, under K3,
  `/proc/device-tree/compatible` reads `qcom,kona-mtp qcom,kona qcom,mtp`
  and `model` reads `Qualcomm Technologies, Inc. kona MTP 19811`, although
  the DTB we boot says `oneplus,instantnoodlep qcom,sm8250` [V: phone,
  2026-11-17, K3 RAM boot].
- The rewrite comes from the root-node properties of stock entry 16
  (`compatible`, `model`, `qcom,board-id`, `oplus,*`) [V: `fdtget -p` on
  entry16.dtbo]. ABL merges them; AOSP `ufdt_apply_overlay` does not, so
  offline overlay checks miss this [V: offline apply keeps the mainline
  compatible].
- Effect: every kernel table keyed on `qcom,sm8250` through the machine
  compatible misses. Observed: `Couldn't find UBWC config data for this
  platform!` and `msm-mdss ... probe ... failed with error -22` [V: dmesg].
  By code reading also `drivers/soc/qcom/qcom_pd_mapper.c` (audio, sensors,
  modem in M5) and `drivers/cpufreq/cpufreq-dt-platdev.c` [V: L/ grep].
- K3 currently carries a test-only patch matching `qcom,kona`
  ("DO NOT UPSTREAM"); with it the panel driver binds and DSI-1 reports
  1440x3168 [V: phone]. This plan removes the need for that patch.

## 2. Design

- One dtbo table with one entry, built from
  `device/instantnoodlep/dtbo/neutral.dts`: the ids stock ABL matches on,
  copied from stock entry 16 (`qcom,board-id = <0x10008 0>`,
  `oplus,dtsi_no = <0x4d63>`, `oplus,pcb_range = <0 0x38>`), the mainline
  root identity (`compatible`, `model`), and no fragments. ABL then selects
  entry 0 and applies nothing but those root properties [I: ABL selects
  the single entry; same match fields as entry 16].
- Packed with AOSP `mkdtboimg.py create --page_size=4096`, then zero-padded
  to the full partition size (25165824 bytes) so the stale AVB footer at the
  end of `dtbo_b` is overwritten. The bootloader is unlocked and already
  boots our footer-less `boot_b`, so a dtbo without AVB footer is expected
  to boot the same way [I: ticket #10].
- Only `dtbo_b` is written. `dtbo_a`, `super` and every `_a` partition stay
  stock (AGENTS rule 3). Android on slot A keeps the stock dtbo.
- Precedent: the public darknagel/pmOS image for this phone flashes its own
  near-empty `dtbo.img` (pmaports `sm8250-oneplus-instantnoodlep-empty.dts`)
  [V: D/README.md:60, D/pmaports-patches/0006:77].
- The probe builder's overlay sink (`/__ovl_sink__`) becomes unnecessary
  but stays harmless; remove it in a later builder change.

## 3. Offline evidence

| Check | Result |
|---|---|
| Phone `dtbo_b` vs OTA `images/dtbo.img`, full 25165824 bytes | identical, sha256 `8b2bc24a…01ddaf` [V] (the rollback image) |
| `dtbo_a` vs `dtbo_b`, first 6894505 bytes (the dt table) | identical [V] |
| Neutral image dump | 1 entry, id/rev/custom 0, dt_size 265 [V] |
| `ufdt_apply_overlay` of the neutral dtbo on the K3 probe DTB | output identical to the input DTB [V] |

Artifacts (private build dir, not in git): `~/android/build/dtbo-neutral/`
`dtbo-neutral-full.img` sha256 `2549b79d…562a98`, `SHA256SUMS`.

## 4. Runbook (owner gates)

| Step | Command | Expect | Stop | Rollback |
|---|---|---|---|---|
| D0 | phone in fastboot: `fastboot getvar current-slot`, `slot-successful:b`, `slot-retry-count:b` | `b`, `yes`, retry count noted | anything else | none needed |
| D1 (**owner go**) | `fastboot flash dtbo_b ~/android/build/dtbo-neutral/dtbo-neutral-full.img` | `Writing 'dtbo_b' OKAY` | any FAILED | D-R |
| D2 | `fastboot getvar slot-successful:b`, `slot-retry-count:b` | unchanged (flashing dtbo does not touch the boot_b attributes [I: FastbootUpdateAttr only for boot partitions]) | successful cleared | rerun the B5 mark as after a boot_b flash |
| D3 | `fastboot reboot` (K2 on slot B boots) | SSH on 172.16.42.1; `/proc/device-tree/compatible` = `oneplus,instantnoodlep qcom,sm8250` | no SSH within 3 min, or a kona compatible | D-R |
| D4 | on the phone: `sha256sum /dev/disk/by-partlabel/dtbo_b` | `2549b79d…562a98` | mismatch | D-R |
| D5 | RAM boot K3 without the qcom,kona patch | `msm-mdss` probes, no UBWC error | UBWC error | keep the test patch; investigate |

D-R (rollback, owner go): phone into fastboot (cable out, Power+VolUp to
force restart, hold VolUp+VolDown, then plug in);
`fastboot flash dtbo_b ~/android/reference/instantnoodlep/images/dtbo.img`;
`fastboot reboot`. Slot A (Android) is never involved.

## 5. Open [I]s

1. ABL selects the single neutral entry and boots (D3).
2. ABL tolerates a dtbo without AVB footer on an unlocked device (D3).
3. Flashing `dtbo_b` leaves the `boot_b` GPT attributes alone (D2).
