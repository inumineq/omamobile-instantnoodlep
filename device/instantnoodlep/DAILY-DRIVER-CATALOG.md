<!-- SPDX-License-Identifier: MIT -->
# Daily Driver Catalog: instantnoodlep (OnePlus 8 Pro IN2023)

**Purpose:** The "can I leave Android" index — one verdict per app category for
this phone, tracking what works today and what blocks daily use. This is a
living document updated as hardware and userspace mature.

**Source of truth for hardware:** [docs/STATUS.md](../../docs/STATUS.md) —
this catalog cites it and never contradicts it.

## Top leave-Android blockers

The three hardest categories preventing this phone from replacing Android today:

| Rank | Blocker | Current State | Owning Issue / Plan |
|---|---|---|---|
| 1 | **Modem / mobile data / SMS** | Kernel and userspace built but blocked by private EFS/DDR policy; no calls/SMS/data yet | [MODEM-M5-PLAN.md](MODEM-M5-PLAN.md), [GNSS-M5-PLAN.md](GNSS-M5-PLAN.md), issue #176 (hotspot/tethering), issue #156 (telephony UX) |
| 2 | **Camera** | Front camera (IMX471) hangs the kernel before root; bisect in progress | [CAMERA-PLAN.md](CAMERA-PLAN.md), issue #165 (device permissions) |
| 3 | **Android apps** | Waydroid not started; no Android compatibility layer | [DUAL-USE-PLAN.md](DUAL-USE-PLAN.md), issue #186 (mainline submissions policy) |

> **Note:** Wi-Fi, Bluetooth, charging and battery gauge all work [V: docs/STATUS.md
> matrix], so the phone functions as a Wi-Fi-only device with voice/sms gaps.

---

## App category catalog

Each category records: current answer on this phone, aarch64 packaging status
(Arch Linux ARM), touch-usability verdict, and owning plan/issue.

**Evidence key:** [V] = verified on device or from cited source; [I] = inference
to check on device.

### 1. Browser

| Aspect | Value | Source |
|---|---|---|
| Current answer | Chromium works with Wayland IME, mobile UA, device scale factor | [V: MOBILE-UX-RESEARCH.md:30-42,120-130] |
| aarch64 package | `chromium` available in Arch Linux ARM (AUR: `chromium-wayland-bin` for Wayland builds) | [I: Arch ARM packages, needs phone verification] |
| Touch-usable | Chromium flags configured for touch (text-input-v3, pinch, scrollbars) | [V: omamobile-shell setup-user:313-378] |
| Owning plan | [MOBILE-UX-RESEARCH.md](MOBILE-UX-RESEARCH.md) §"Chromium and Electron profile to test" |

**Verdict:** [V] Works. Profile needs phone validation per MOBILE-UX-RESEARCH.

---

### 2. Mail

| Aspect | Value | Source |
|---|---|---|
| Current answer | No mail client verified on phone | [I] |
| aarch64 package | `geary`, `thunderbird`, `evolution`, `claws-mail` available in Arch ARM | [I: Arch ARM packages] |
| Touch-usable | Geary (libadwaita) and Thunderbird have touch-optimized modes; evolution GTK may need scaling | [I] |
| Owning plan | Issue #182 (prove one email client end to end) |

**Verdict:** [I] Not verified. See issue #182 for viability matrix and owner test.

---

### 3. Chat / Messaging

| Aspect | Value | Source |
|---|---|---|
| Current answer | Discord (Electron), WhatsApp (PWA), X/Twitter (PWA), HEY (PWA) installed; no on-device verification | [V: MOBILE-UX-RESEARCH.md:30-42 installed app list] |
| aarch64 package | `discord`, `whatsapp-nativefier` (AUR), Chromium PWAs | [I: Arch ARM packages + AUR] |
| Touch-usable | PWAs via Chromium with mobile UA and scale factor; Discord Electron may need `--ozone-platform=wayland` | [I] |
| Owning plan | Issue #158 (prove one chat messenger end to end), [MOBILE-UX-RESEARCH.md](MOBILE-UX-RESEARCH.md) §"Morning phone survey matrix" |

**Verdict:** [I] Not verified on phone. Electron apps and PWAs need survey per MOBILE-UX-RESEARCH.

---

### 4. Maps / Navigation

| Aspect | Value | Source |
|---|---|---|
| Current answer | No maps client verified on phone | [I] |
| aarch64 package | `foliate` (web-based), `gnome-maps`, `osmAnd~` (AUR), `maps` (GNOME) | [I: Arch ARM packages] |
| Touch-usable | GNOME Maps designed for touch; osmAnd is Android port via Waydroid/Wayland | [I] |
| Owning plan | Issue #170 (offline maps and navigation plan) |

**Verdict:** [I] Not verified. GeoClue and location services blocked by lack of GNSS/modem.

---

### 5. Camera

| Aspect | Value | Source |
|---|---|---|
| Current answer | **Camera does not work** — Front IMX471 hangs kernel before root; bisect candidates built | [V: docs/STATUS.md matrix "Cameras | WIP"] |
| aarch64 package | `libcamera`, `libcamera-apps`, `qcamera` (AUR) | [I: Arch ARM packages] |
| Touch-usable | libcamera-qviewcam has simple touch UI; qcamera is Qt-based | [I] |
| Owning plan | [CAMERA-PLAN.md](CAMERA-PLAN.md), issue #165 (device permissions) |

**Verdict:** [V] **Blocked** — Kernel hang before root. See CAMERA-PLAN for bisect progress.

---

### 6. Gallery / Image viewer

| Aspect | Value | Source |
|---|---|---|
| Current answer | No gallery verified on phone | [I] |
| aarch64 package | `loupe`, `gThumb`, `feh`, `nomacs`, `ristretto` | [I: Arch ARM packages] |
| Touch-usable | Loupe (GNOME/GTK4) designed for touch; feh is keyboard-driven | [I] |
| Owning plan | MOBILE-UX-RESEARCH §"GTK/Qt desktop apps" |

**Verdict:** [I] Not verified. Loupe is upstream's recommended image viewer.

---

### 7. Music

| Aspect | Value | Source |
|---|---|---|
| Current answer | No music app verified on phone | [I] |
| aarch64 package | `rhythmbox`, `clementine`, `quodlibet`, `mpd` + `cantata`, `lollypop` | [I: Arch ARM packages] |
| Touch-usable | Lollypop designed for GNOME touch; others may need scaling | [I] |
| Owning plan | Issue #181 (userspace service-stack census) may cover media services |

**Verdict:** [I] Not verified. Requires audio phase 1 (ADSP on) which is built but not enabled.

---

### 8. Video

| Aspect | Value | Source |
|---|---|---|
| Current answer | No video app verified on phone; GPU works (freedreno) | [V: docs/STATUS.md "GPU | works"] |
| aarch64 package | `mpv`, `vlc`, `celluloid`, `haruna` | [I: Arch ARM packages] |
| Touch-usable | mpv/vlc have minimal touch; Celluloid (GTK) and Haruna (Qt) are more touch-friendly | [I] |
| Owning plan | Issue #174 (MEDIA-PLAN for Venus video decode and playback stack) |

**Verdict:** [I] Not verified. Venus video decode not yet enabled; GPU render works.

---

### 9. Contacts

| Aspect | Value | Source |
|---|---|---|
| Current answer | No contacts app verified on phone | [I] |
| aarch64 package | `evolution-data-server` + `gnome-contacts`, `kaddressbook` | [I: Arch ARM packages] |
| Touch-usable | GNOME Contacts designed for touch | [I] |
| Owning plan | Issue #169 (contacts and calendar plan) |

**Verdict:** [I] Not verified. See issue #169 for vcf import and CardDAV/CalDAV sync.

---

### 10. Calendar

| Aspect | Value | Source |
|---|---|---|
| Current answer | No calendar app verified on phone | [I] |
| aarch64 package | `gnome-calendar`, `evolution`, `korganizer` | [I: Arch ARM packages] |
| Touch-usable | GNOME Calendar designed for touch | [I] |
| Owning plan | Issue #169 (contacts and calendar plan) |

**Verdict:** [I] Not verified. See issue #169 for CalDAV sync.

---

### 11. Files / File manager

| Aspect | Value | Source |
|---|---|---|
| Current answer | Nautilus installed; file chooser portal routing active | [V: MOBILE-UX-RESEARCH.md:30-42, upstream setup-user:189-196] |
| aarch64 package | `nautilus`, `thunar`, `dolphin`, `pcmanfm` | [I: Arch ARM packages] |
| Touch-usable | Nautilus with libadwaita chooser is touch-optimized | [V: upstream omamobile-shell README:95-97] |
| Owning plan | [MOBILE-UX-RESEARCH.md](MOBILE-UX-RESEARCH.md) §"GTK/Qt desktop apps" |

**Verdict:** [V] Works. Nautilus used as portal file chooser upstream.

---

### 12. Payments

| Aspect | Value | Source |
|---|---|---|
| Current answer | **No payment solution** — MobilePay not in scope; no NFC; no ModemManager payment integration | [V: docs/STATUS.md "NFC | no"] |
| aarch64 package | `mobilepay` (proprietary, not packaged); generic: browser-based payment handlers | [I] |
| Touch-usable | Browser-based payments (stripe, etc.) via Chromium with text-input-v3 | [I] |
| Owning plan | Out of scope per wayfinder map [V: issue #1 "Out of scope"] |

**Verdict:** [V] **Blocked** — No NFC hardware support; no mobile payment apps packaged.

---

### 13. 2FA (Two-factor authentication)

| Aspect | Value | Source |
|---|---|---|
| Current answer | No 2FA app verified on phone | [I] |
| aarch64 package | `keepassxc`, `authy` (AUR), `andOTP` (AUR, Android port), `yubikey-manager` | [I: Arch ARM packages + AUR] |
| Touch-usable | KeePassXC has touch-optimized UI; andOTP requires Waydroid | [I] |
| Owning plan | Issue #177 (SIM/eSIM and PIN-handling policy) may relate to SMS-based 2FA |

**Verdict:** [I] Not verified. SMS 2FA blocked by lack of modem; TOTP apps need verification.

---

### 14. Android apps

| Aspect | Value | Source |
|---|---|---|
| Current answer | **No Android compatibility** — Waydroid not started | [I] |
| aarch64 package | `waydroid` (AUR) — containerized Android environment | [I: AUR] |
| Touch-usable | Waydroid provides full Android touch experience when working | [I] |
| Owning plan | [DUAL-USE-PLAN.md](DUAL-USE-PLAN.md) (phone/desktop convergence) |

**Verdict:** [I] **Blocked** — Not started. Depends on hardware virtualization support and phone/desktop mode.

---

### 15. Backup / Sync

| Aspect | Value | Source |
|---|---|---|
| Current answer | No backup/sync verified on phone | [I] |
| aarch64 package | `rsync`, `syncthing`, `nextcloud-client`, `borg`, `restic` | [I: Arch ARM packages] |
| Touch-usable | Syncthing has web UI; Nextcloud client is Qt-based | [I] |
| Owning plan | Issue #161 (working phone↔computer file transfer and continuous sync) |

**Verdict:** [I] Not verified. See issue #161 for LocalSend/Syncthing feasibility.

---

## Summary matrix

| Category | Works? | Phone-gated? | Packaging | Touch-ready | Blocker | Plan |
|---|---|---|---|---|---|---|
| Browser | ✓ | No | [I] Arch ARM | [V] Yes | None | MOBILE-UX-RESEARCH |
| Mail | ⚠ | Yes | [I] Arch ARM | [I] Yes | Verification | #182 |
| Chat | ⚠ | Yes | [I] Arch ARM + AUR | [I] Yes | Verification | #158 |
| Maps | ⚠ | Yes | [I] Arch ARM | [I] Yes | GNSS/modem | #170 |
| Camera | ✗ | Yes | [I] Arch ARM | [I] N/A | Kernel hang | CAMERA-PLAN |
| Gallery | ⚠ | Yes | [I] Arch ARM | [I] Yes | Verification | MOBILE-UX-RESEARCH |
| Music | ⚠ | Yes | [I] Arch ARM | [I] Yes | Audio ADSP | #181 |
| Video | ⚠ | Yes | [I] Arch ARM | [I] Yes | Venus decode | #174 |
| Contacts | ⚠ | Yes | [I] Arch ARM | [I] Yes | Verification | #169 |
| Calendar | ⚠ | Yes | [I] Arch ARM | [I] Yes | Verification | #169 |
| Files | ✓ | No | [I] Arch ARM | [V] Yes | None | MOBILE-UX-RESEARCH |
| Payments | ✗ | No | [I] None | [I] N/A | NFC/modem | Out of scope |
| 2FA | ⚠ | Yes | [I] Arch ARM + AUR | [I] Yes | Modem/SMS | #177 |
| Android apps | ✗ | Yes | [I] AUR | [I] N/A | Waydroid | DUAL-USE-PLAN |
| Backup | ⚠ | Yes | [I] Arch ARM | [I] Yes | Verification | #161 |

---

## How to use this catalog

1. **For phone users:** Check the "Current answer" column for each category
   you rely on. If it's marked [V] and not blocked, it should work.

2. **For contributors:** Pick an [I]-marked category and:
   - Verify the aarch64 package availability on Arch Linux ARM
   - Test on the phone (or provide a phone-gated runbook)
   - Update the entry with [V] and a source citation

3. **For upstream:** Once all categories reach at least "degraded but usable",
   the phone can be considered a viable daily driver.

---

## Updates and maintenance

- Update this file when a category's hardware status changes in
  [docs/STATUS.md](../../docs/STATUS.md)
- Update when a phone survey (MOBILE-UX-RESEARCH) verifies an installed app
- Update when a category-owning issue is closed
- Keep the "Top leave-Android blockers" list at ≤3 items, sorted by impact

---

## References

- [V] Hardware status matrix: [docs/STATUS.md](../../docs/STATUS.md)
- [V] Installed app audit: [MOBILE-UX-RESEARCH.md](MOBILE-UX-RESEARCH.md)
- [V] Local packages: [LOCAL-REPO-PLAN.md](LOCAL-REPO-PLAN.md)
- [V] Upstream device matrix: derekross/omarchy-mobile docs/DEVICES.md
- [V] Wayfinder map: issue #1

---

*Created: 2026-11-25. Last updated: [fill on edit].*
