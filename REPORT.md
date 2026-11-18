# REPORT: slim K3 camera + modem kernel candidates rebuilt with clang 23 (omabook)

Date: 2026-11-18. Worker: claude on omabook, branch `inumineq/slim-cam-modem`, PR #107.
Scope: offline only — no phone access, no flashing, no partition writes.

## What was done

1. Read AGENTS.md, `docs/agents/state.md`, `KERNEL-SIZE.md`, learning
   `l-e03ff7fe` (clang 23 not clang 19), `CAMERA-PLAN.md`, `MODEM-M5-PLAN.md` /
   `MODEM-M5-DELTA.md`, PRs #73/#74.
2. Fetched the feature branches from the MacBook Pro
   (`~/src/l-k3-camera` @ `70d0761d1`, `~/src/l-k3-modem` @ `e9ff58528f8b`)
   via `git bundle` + `scp` into `~/bundles/`, then cherry-picked them onto the
   slim tip `78f38a2acc99` in `~/src/l-k3-slim`:
   - `instantnoodlep-k3-slim-cam` @ `d53d0fd6baaa` (3 camera commits; the board
     DTS commit merge-resolved against the daily tip's Wi-Fi/BT/gauge DTS)
   - `instantnoodlep-k3-slim-modem` @ `7dc2ea318807` (4 modem commits; same
     merge resolution for `&intc`/`&pcie2` vs `&i2c16`/`&pcie0`)
3. Configs: slim `.config` (`~/android/build/k3-slim/.config`) + only the
   feature fragment, `olddefconfig`, diff verified:
   - camera: exactly `CONFIG_VIDEO_IMX471=m` + `CONFIG_LOCALVERSION` changed;
     CAMSS / `SM_CAMCC_8250` / CCI / `V4L2_CCI*` stay `=m` (modules-first, so a
     camera probe hang cannot block boot)
   - modem: only the SDX55 fragment symbols (`MHI_BUS`, `MHI_BUS_PCI_GENERIC`,
     `MHI_BUS_SAHARA`, `MHI_NET`, `MHI_WWAN_CTRL`, `WWAN`, `QRTR`, `QRTR_MHI`,
     `PHY_QCOM_QMP_PCIE` → `y`; `GNSS*` unset; `LOCALVERSION`).
     `CONFIG_MHI_BUS_SAHARA=y` present → series applied.
4. Builds on this laptop with clang/LLD 23.1.3:
   `nice -n 5 make O=~/android/build/k3-slim-{cam,modem} ARCH=arm64 LLVM=1 -j8
   Image.gz qcom/sm8250-oneplus-instantnoodlep.dtb modules` — both RC=0.
5. Verification (all [V], offline):
   - `od -An -tx8 -j16 -N8 Image` → cam `0x1720000`, modem `0x1750000`
     (≤ ceiling `0x2b60000`, KERNEL-SIZE §1)
   - `CHECK_DTBS=y` (dtschema venv) clean on both; it caught one merge
     misplacement (`regulator-cam-front-avdd` inside `qca6390-pmu`), fixed
     before release
   - DTBs: one `sony,imx471` `camera@10` on CCI1 `i2c-bus@1` → camss `port@3`
     (cam); `pci17cb,306` `qcom,flashless` endpoint on pcie2 + GIC MBI route
     `mbi-ranges = <832 32>`, `mbi-alias = <0x17a10000>` (modem)
   - modules tarballs, `INSTALL_MOD_STRIP=1`: cam 1125 `.ko` (camera stack as
     `.ko`), modem 1113 `.ko`
   - RAM images via `tools/build-instantnoodlep-probe` with exactly the
     `~/android/build/k3-daily-ram/boot-daily.manifest.json` flags
     (`--boot 2 --root userdata --debug-shell`), read-back pass, manifests
   - sha256 sums in `SHA256SUMS` next to each image
6. Runbooks repointed to the new images: `CAMERA-PLAN.md` §9.2/§9.3/§9.5
   (new §9.5 with the 2026-11-18 results), `MODEM-M5-DELTA.md` §6.2 (new,
   builder block repointed). **Modem gates A-C and camera gates C0-C5 stay
   closed.** `docs/agents/state.md` rows updated, learning saved
   (`2026-11-18-rebuild-the-camera-and-modem-kernel-claude.md`),
   `scripts/trail-lite lint` ok, pushed, PR #107 opened.

## Artefacts (private, omabook)

| Artefact | Path | sha256 |
| --- | --- | --- |
| cam Image.gz | `~/android/build/k3-slim-cam/arch/arm64/boot/Image.gz` | `22d0ccf284003abde18f80715ecc84705e07ea5d6afcf9dd7ddbbd100956b574` |
| cam dtb | `~/android/build/k3-slim-cam/.../dts/qcom/sm8250-oneplus-instantnoodlep.dtb` | `7f04a8fd5d17794ce9fc0bcdc0f04d74e7f62b223c3ffb95346811699568f3ad` |
| cam modules | `~/android/build/k3-slim-cam/modules-7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa.tar.gz` | `87ec8cc7577357c094a91bb8b7d6d767e7aa37da457e51c0582158e5d7d605b9` |
| cam RAM image | `~/android/build/k3-slim-cam-ram/boot-slim-cam.img` | `1704fd45d9c70c50d5eabd3e0a27c4a8b63c63cd649a3e3fa4b6d5a331d8516f` |
| modem Image.gz | `~/android/build/k3-slim-modem/arch/arm64/boot/Image.gz` | `1c2cbe4dfb14fb99a311cd89d2d16cb59cfc27ee39b99c9bf1e902033ca57778` |
| modem dtb | `~/android/build/k3-slim-modem/.../dts/qcom/sm8250-oneplus-instantnoodlep.dtb` | `651136af5a3507c4fa0c28342bf5981b2b1da5bd84b04c2bdd95e82dec819efa` |
| modem modules | `~/android/build/k3-slim-modem/modules-7.3.0-rc6-instantnoodlep-k3-slim-modem-g7dc2ea318807.tar.gz` | `5952f74a8ee3b1ddf53a96b3e4c3f3533e66b455f8bb2f2a83c2546ad7e17a06` |
| modem RAM image | `~/android/build/k3-slim-modem-ram/boot-slim-modem.img` | `ea68defc1973583be8724ea1c4cd40414b2135507670ecf1880a784ab424beb2` |

Releases: `7.3.0-rc6-instantnoodlep-k3-slim-cam-gd53d0fd6baaa`,
`7.3.0-rc6-instantnoodlep-k3-slim-modem-g7dc2ea318807`.

## Not done (by design)

No RAM boot, no phone command, no flash. The clang 19 MBP builds remain the
reason these were rebuilt (learning `l-e03ff7fe`); the old camera build was
also over the image_size ceiling. Coordinator gates: camera C0-C5
(CAMERA-PLAN §9.1), modem A-I with A-C blocking (MODEM-M5-DELTA §6).
