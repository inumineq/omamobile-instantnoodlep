<!-- SPDX-License-Identifier: MIT -->
# Upstream Ledger: every carried patch gets a home

This ledger tracks every patch or patch series that is carried locally in this
repository and that could be sent upstream. Each entry documents what it is,
the evidence that it works, where it belongs (home), its current status, and
any blockers to sending it upstream.

**Purpose:** #867 Phase 4 bar — nothing upstreamable stays a private patch
without a written home and a link to where it was sent.

**Columns:**
- **What**: brief description and location
- **Evidence**: offline checks, compile tests, runtime verification
- **Home**: target upstream (Omarchy Mobile / omarchy-mobile / mainline kernel)
- **Status**: draft / ready / sent / merged / stay-device-local
- **Blocker**: what prevents sending or merging

---

## Audio

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| TFA987x codec driver series (`device/instantnoodlep/patches/audio-tfa987x/`) — ASoC driver for TFA9872/9873/9874 speaker amplifiers with DT binding, regmap, DAPM, suspend/resume. No vendor firmware or calibration data. | [V] Offline: `tfa987x.o` compiles clean (clang 23.1.3, `ARCH=arm64 LLVM=1`), `dt_binding_check` clean (CHKDT/LINT/STYLE/DTEX/DTC), `checkpatch.pl --strict` 0/0/0 over 651 lines. README and REPORT in same directory. | mainline kernel (`sound/soc/codecs/tfa987x.c`) | ready | Phone gate: first sound not verified on device (AUDIO-M5-PLAN §9). Needs owner RAM boot with test PCM. |

---

## Bluetooth / Wi-Fi

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| BT public address helper (`packages/omamobile-device-instantnoodlep/bin/omamobile-bt-public-addr`, udev rules, systemd service) — sets QCA6390 public address from persistent store after firmware load; generates random address if none stored. | [V] Shellcheck clean, static analysis passed. Used daily on phone; `btmgmt public-addr` works. | Omarchy Mobile device package (`omamobile-device-instantnoodlep`) | stay-device-local | Device-specific; relies on `btmgmt` and phone hci0. Not applicable upstream. |

---

## Camera

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| IMX471 DT binding (`device/instantnoodlep/patches/camera/0001-dt-bindings-media-Add-Sony-IMX471-image-sensor.patch`) — adds DT schema for Sony IMX471 image sensor. | [V] Part of 3-patch series; compiles and schema-validates. README documents offline gates. | mainline kernel (`Documentation/devicetree/bindings/media/i2c/sony,imx471.yaml`) | ready | Phone gate: actual 200 MHz streaming and power-up sequencing not verified (CAMERA-PLAN §9.1). |
| IMX471 DT enumeration (`device/instantnoodlep/patches/camera/0002-media-i2c-imx471-Support-device-tree-enumeration.patch`) — adds OF-based device tree enumeration to upstream ACPI-only IMX471 driver. | [V] Compiles clean; `dt_binding_check` clean. README cites public Nura source (05bdc4b73377). | mainline kernel (`drivers/media/i2c/imx471.c`) | ready | Phone gate: bulk regulator ordering and 200 MHz streaming unverified. |
| Instantnoodlep front camera enable (`device/instantnoodlep/patches/camera/0003-arm64-dts-qcom-instantnoodlep-Enable-the-front-camer.patch`) — board DTS enablement for front camera: CCI1 master 1, front endpoint, rails (PM8009 L3F/L7F + GPIO24 BOB 2.8 V). | [V] Schema validation passed; base wiring from public Nura patch. README documents MAC build. | mainline kernel (`arch/arm64/boot/dts/qcom/instantnoodlep.dts`) | draft | Phone gate: actual probe and frame capture unverified. Needs CAMERA-PLAN §9.1. |

---

## GPU / PM

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| GMU fw_devlink sync_state (`device/instantnoodlep/patches/pm/0001-drm-msm-adreno-bind-the-GMU-device-so-fw_devlink-sy.patch`) — binds no-op platform driver to GMU device so its consumer links become ACTIVE; fixes `sync_state() pending due to 3d6a000.gmu`. | [V] `a6xx_gmu.o` compiles clean (clang 23.1.3, `LLVM=1`). README documents analysis with file:line citations. | mainline kernel (`drivers/gpu/drm/msm/adreno/a6xx_gmu.c`) | ready | Phone gate: PM-PLAN §4.5 runbook not executed; `sync_state` pending status unverified on device. |

---

## Kona Root-Compatible Replacement (PR #84, closed)

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| UBWC fallback to SMEM SoC ID (`device/instantnoodlep/KONA-ROOT-DESIGN.md` design; patches in PR #84 draft) — when root compatible matches nothing, select UBWC table from `qcom_smem_get_soc_id()` instead of failing. | [V] PR #84: `checkpatch.pl --strict` passes (SOB missing only), targeted `W=1` builds clean for touched drivers. Full candidate build: `7.3.0-rc6-instantnoodlep-k3-kona-g8fb338f6ee97`. | mainline kernel (`drivers/soc/qcom/ubwc_config.c`) | ready | Human review and DCO sign-off needed; phone gate: PD service registration and Wi-Fi association not verified (combo predates Wi-Fi enablement). |
| PD-mapper fallback to SMEM SoC ID (`device/instantnoodlep/KONA-ROOT-DESIGN.md` design; patches in PR #84 draft) — same SMEM fallback for protection-domain tables. | [V] Same as above; `qcom_pdm_domains` maps SM8250 to `sm8250_domains`. | mainline kernel (`drivers/soc/qcom/qcom_pd_mapper.c`) | ready | Same as above. |
| cpufreq-dt exclusion by QCOM cpufreq-hw node (`device/instantnoodlep/KONA-ROOT-DESIGN.md` design; patches in PR #84 draft) — skip `cpufreq-dt` when QCOM cpufreq-hw/EPSS node exists instead of matching root compatible. | [V] Same as above; blocklist logic verified. | mainline kernel (`drivers/cpufreq/cpufreq-dt-platdev.c`) | ready | Same as above. |

---

## Mesa / GPU Userspace

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| Freedreno (Turnip) for Adreno 650 (`device/instantnoodlep/patches/mesa-freedreno.patch`) — adds Gallium freedreno and Vulkan Turnip to Omarchy Mobile Mesa package for Adreno 6xx GPUs (OnePlus 8 Pro, SM8250). | [V] Patch applies cleanly against `derekross/omarchy-mobile`@`c462357`. Adds `freedreno-kmds=msm`, `gallium-drivers=...freedreno...`, `vulkan-drivers=panfrost,freedreno`, new `vulkan-freedreno` split package. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/mesa/PKGBUILD) | draft | Needs owner upstream PR; currently local package only. |

---

## Modem

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| Flashless SDX55 endpoint binding (`patches/instantnoodlep/kernel-modem/0001-dt-bindings-modem-describe-the-flashless-SDX55-PCI-e.patch`) — DT binding for `qcom,flashless` SDX55 PCIe endpoint. | [V] Part of 4-patch modem series; `checkpatch.pl --strict` warns only on separate patch split (binding and include should be separate — already are). README documents. | mainline kernel (`Documentation/devicetree/bindings/modem/qcom,modem.yaml`) | ready | Phone gate: MODEM-M5-DELTA §6 A-C (EFS/NV, DDR training, sync lifecycle) blocked; not tested on device. |
| Bounded Sahara loader (`patches/instantnoodlep/kernel-modem/0002-bus-mhi-host-add-a-bounded-image-only-Sahara-loader-.patch`) — MHI host Sahara loader with bounded commands, image size, served bytes, TX batch waits; serves only non-private `qcom/sdx55m/` images. | [V] Same as above; no DMA/lifecycle test yet (host-side parser test exists in `tests/modem-sahara/`). | mainline kernel (`drivers/bus/mhi/host/pci_generic.c` + new Sahara module) | ready | Same as above: needs private-state policy approval. |
| Instantnoodlep SDX55 DTS (`patches/instantnoodlep/kernel-modem/0003-arm64-dts-qcom-instantnoodlep-describe-the-external-.patch`) — board DTS for `pcie2`/`pcie2_phy`, MSI routing to GICv3 MBI, `pci17cb,306` with `qcom,flashless`. | [V] Same as above; schema validation passed. | mainline kernel (`arch/arm64/boot/dts/qcom/instantnoodlep.dts`) | ready | Same as above. |
| PCIe msi-parent schema allowance (`patches/instantnoodlep/kernel-modem/0004-dt-bindings-PCI-qcom-pcie-sm8250-allow-an-external-M.patch`) — allows external MSI parent for QCOM PCIe. | [V] Same as above. | mainline kernel (`Documentation/devicetree/bindings/pci/qcom,pcie-sm8250.yaml`) | ready | Same as above. |
| Firmware map exclude modem DDR state (`patches/instantnoodlep/0001-firmware-map-exclude-modem-ddr-state.patch`) — removes `qcom/sdx55m` from firmware.map; modem firmware is private-state and must not be shipped in device package. | [V] Patch applies cleanly; validates firmware separation. | Omarchy Mobile device package (`omamobile-device-instantnoodlep`) | merged | Already in device package; no upstream issue. |

---

## Settings UI (omamobile-settings)

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| Security page (`patches/omamobile-settings/0001-settings-security-page.patch`) — adds Security page to native Settings with: change lock-screen PIN, change account password, toggle numeric keypad. Uses `pkexec` helper, narrow polkit-authorized PAM, separate opt-in PIN hash (SHA-512) with ten-attempt lockout. No hash handling in QML. | [V] Offline x86: `git apply --check` clean, `qmllint` 0 errors on all 10 QML files, clean `qmake6`/`make` build, `--version` prints `0.1.3`, `--check` passes, `test/all` passes, PAM verification 61/61 in archlinux container, Debian fixture 13/13 pass. README documents all commands and results. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/omamobile-settings) | ready | Phone gate: `pkexec`/polkit round trip on real session and lock screen unverified. |
| Displays page (`patches/omamobile-settings/0002-settings-displays-page.patch`) — adds Displays page: read `hyprctl -j monitors all`, present modes, DSI/eDP read-only, external mode/scale changes via `hyprctl eval` and `hl.monitor`, store managed section of `~/.config/hypr/monitors.lua`. | [V] Offline: patches 0001+0002 apply clean, `bash test/displays-backend.sh` 4/4 pass with fake `hyprctl` fixture, static checks pass. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/omamobile-settings) | ready | Phone gate: live connector modes, mode/scale application, login persistence unverified (DOCK-DESKTOP-PLAN). |

---

## Shell UI

| What | Evidence | Home | Status | Blocker |
|------|----------|------|--------|---------|
| Back gesture edge geometry (`patches/0001-back-gesture-device-edge-geometry.patch`) — makes back gesture strip configurable per device via `OMAMOBILE_BACK_EDGE_WIDTH` and `OMAMOBILE_BACK_EDGE_INSET` env vars (compositor logical pixels). Current defaults: 14px width, 0px inset. Proposed instantnoodlep: 48px inset, 32px width. | [V] `git apply --check` clean against pinned upstream `c462357`. Upstream Node tests pass (`back-link.js`, `back-model.js`, `wifi-model.js`). Temporary Node harness: `configuredPixels()` edge cases pass, Wi-Fi handler with BackLink.js passes. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/omamobile-shell) | draft | Phone gate: attended edge sweep to confirm boundaries (SHELL-UX-PLAN). Focus-dependent Wi-Fi Escape fallback needs verification. |
| Wi-Fi picker register BackLink (`patches/0002-wifi-picker-register-back-link.patch`) — registers open Wi-Fi picker with `BackLinkClient.qml` so Back gesture targets picker directly instead of relying on focus-dependent Escape. | [V] `git apply --check` clean. Minimal registration preserves existing Escape path. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/omamobile-shell) | draft | Phone gate: back swipe from picker list and nested password sheet; focus and lock session behavior (SHELL-UX-PLAN). |
| Back surfaces test Wi-Fi picker (`patches/0003-back-surfaces-test-wifi-picker.patch`) — test fixture for Wi-Fi picker back gesture. | [V] `git apply --check` clean. | Omarchy Mobile upstream (test suite) | draft | Same as above; depends on 0001 and 0002. |
| Device safe insets (`patches/0004-device-safe-insets.patch`) — adds safe area insets per device to prevent UI from overlapping notches/cutouts. | [V] `git apply --check` clean. | Omarchy Mobile upstream (`derekross/omarchy-mobile` packages/omamobile-shell) | draft | Phone gate: device-specific insets calibration and verification. |

---

## Summary Statistics

| Category | Total | Draft | Ready | Sent | Merged | Stay-Local |
|----------|-------|-------|-------|------|--------|------------|
| Audio | 1 | 0 | 1 | 0 | 0 | 0 |
| Bluetooth/Wi-Fi | 1 | 0 | 0 | 0 | 0 | 1 |
| Camera | 3 | 1 | 2 | 0 | 0 | 0 |
| GPU/PM | 1 | 0 | 1 | 0 | 0 | 0 |
| Kona root | 3 | 0 | 3 | 0 | 0 | 0 |
| Mesa | 1 | 1 | 0 | 0 | 0 | 0 |
| Modem | 5 | 0 | 4 | 0 | 1 | 0 |
| Settings | 2 | 0 | 2 | 0 | 0 | 0 |
| Shell | 4 | 4 | 0 | 0 | 0 | 0 |
| **Total** | **21** | **6** | **13** | **0** | **1** | **1** |

---

## Legend

- **[V]**: Verified offline (compile-check, static analysis, x86 test)
- **[I]**: Inferred or not yet verified on phone
- **Home values**:
  - `mainline kernel`: Linux kernel upstream
  - `Omarchy Mobile upstream`: `derekross/omarchy-mobile` repo
  - `stay-device-local`: device-specific, not applicable upstream
- **Status values**:
  - `draft`: needs more work before sending
  - `ready`: ready to send, pending owner action
  - `sent`: sent upstream, awaiting review
  - `merged`: merged upstream
  - `stay-device-local`: remains in device package

---

## References

- Issue: inumineq/omamobile-instantnoodlep#193
- Phase 4 requirement: #867 Phase 4 — "nothing upstreamable stays a private patch without a written home and a link to where it was sent"
- Upstream roadmap: [ctx/upstream-867-roadmap.md](../../../claude/issue-room/2026-11-25/ctx/upstream-867-roadmap.md)
- Related PRs: #84 (kona root, closed), #82 (audio), #92 (device package), #99 (Chromium), #100 (settings security summary), #111 (package tooling)
- Plan files: AUDIO-M5-PLAN.md, CAMERA-PLAN.md, DTBO-PLAN.md, KONA-ROOT-DESIGN.md, MODEM-M5-DELTA.md, PM-PLAN.md, SHELL-UX-PLAN.md, DOCK-DESKTOP-PLAN.md
