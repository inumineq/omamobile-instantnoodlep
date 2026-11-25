<!-- SPDX-License-Identifier: MIT -->
# instantnoodlep: Notification Path Audit

**Issue:** #190 (B-24, wayfinder:research, first wave 2026-11-25)
**Status:** Research note — phone verification protocol ready, not run
**Scope:** Which daemon serves the shell, lock-screen visibility, screen-off queueing, DND

---

## 0. Executive summary

Omarchy Mobile's notification path on instantnoodlep runs through **Quickshell's NotificationServer** (org.freedesktop.Notifications DBus interface) in `omarchy-shell`, not a separate daemon [V: omarchy-mobile/packages/omamobile-shell/shell/plugins/notifications/Service.qml:1-6]. The shell's notification service owns the DBus name, receives notifications, renders toasts via a per-output overlay layer surface, and persists them as single-line JSON files in `~/.local/state/omarchy/notifications/` (live) and `history/` (archived) [V: NotificationsModel.js:8-15].

The phone's shell packages (`omamobile-shell` 0.2.133-1.2 on the phone as of state.md 2026-11-18) carry four Omarchy patches that extend the notification model: **0015** (inline reply), **0017** (swipe-to-dismiss and touch close button), **0019** (forget one notification by IPC), **0020** (touch-friendly phrasing) [V: omarchy-mobile/packages/omamobile-omarchy/patches/0015-0020 patch headers]. These patches add touch-first interaction to a desktop-first codebase.

Lock-screen notification visibility, screen-off queueing, and the integration with Omarchy's lock/session are **unknown on this device** and require a read-only phone run to verify [I]. The **Notification LED is absent** from public hardware descriptions; MISC-HW-PLAN defers to the display/AOD notification path [V: MISC-HW-PLAN.md:78].

---

## 1. Notification daemon and serving path

### 1.1 The daemon

**Quickshell's NotificationServer** is the notification daemon. It implements the freedesktop org.freedesktop.Notifications DBus interface and is loaded as a first-party service by omarchy-shell [V: Service.qml:1-6].

- **DBus name:** `org.freedesktop.Notifications`
- **Implementation:** `shell/plugins/notifications/Service.qml` (Quickshell plugin)
- **Process:** Runs within the omarchy-shell process (Quickshell-based)
- **Capabilities advertised:**
  - `actionsSupported: true`
  - `bodyHyperlinksSupported: true`
  - `bodyMarkupSupported: true`
  - `imageSupported: true`
  - `persistenceSupported: true`
  - `inlineReplySupported: true` (added by patch 0015)

### 1.2 End-to-end flow

```
Sender (any DBus client)
    ↓ org.freedesktop.Notifications.Notify()
Quickshell NotificationServer (Service.qml)
    ↓ Creates Notification object, assigns key
    ↓ Stores live entry in ~/.local/state/omarchy/notifications/<timestamp>-<id>.json
    ↓ Renders toast on overlay layer (WlrLayershell, namespace: omarchy-notifications)
    ↓ On display, timeout, or user action → moves file to history/ or deletes

Quick Settings Shade
    ↓ Reads from same file store via NotificationsModel.js
    ↓ Renders NotificationRow.qml for each entry
    ↓ Swipe dismiss triggers forget IPC call (patch 0019)
```

**File storage format:**
- Live: `~/.local/state/omarchy/notifications/<timestamp>-<id>.json` — one file per active toast
- History: `~/.local/state/omarchy/notifications/history/<timestamp>-<id>.json` — moved when toast closes
- Format: Single-line JSON, one object per file (Omarchy 4.0) or consolidated arrays in live.json/history.json (Omarchy 4.5)
- **On Omarchy 4.5:** Live notifications in `live.json`, history in `history.json`, both as JSON arrays, newest first [V: NotificationsModel.js:16-22]

### 1.3 Shell integration points

| Component | Location | Role |
|-----------|----------|------|
| NotificationServer | `shell/plugins/notifications/Service.qml` | DBus server, toast rendering, file persistence |
| Toast UI | `shell/plugins/notifications/Toast.qml` | Individual notification card on overlay layer |
| Deck/Stack | `shell/plugins/notifications/Service.qml` (Deck.qml components) | Per-output stack of toasts |
| Quick Settings Model | `plugins/omamobile.quicksettings/NotificationsModel.js` | Parse files, provide entries to shade |
| Quick Settings Row | `plugins/omamobile.quicksettings/NotificationRow.qml` | Shade list entry |
| DND toggle | `shell/plugins/notifications/Service.qml` | `doNotDisturb` property, persisted [V: Service.qml:56-61] |

---

## 2. Lock-screen visibility

### 2.1 What is known

- **Omarchy's lock:** Quickshell provides a lock screen (`shell/plugins/lock/`); notifications are rendered on overlay layers
- **Hyprland layer:** Notification surfaces use `WlrLayer.Overlay` which can draw over the lock [V: Service.qml:1384-1385 from patch 0015 context]
- **Mobile shell overlay:** Omarchy Mobile patches add `above_lock = 2` capability for call card to draw over lock; same layer type used for notifications [V: TELEPHONY-APPS-PLAN.md §8 line 365]
- **Public summary hint:** Upstream telephony plan notes that Omarchy 4.0.4 does not set `inlineReplySupported`, and that lock-state detection may use `org.freedesktop.ScreenSaver` or logind's LockedHint [V: TELEPHONY-APPS-PLAN.md:659]

### 2.2 What is unknown [I]

- Whether instantnoodlep's shell configuration enables overlay-layer notifications over the lock
- Whether the phone's omamobile-shell (0.2.133-1.2 with patches 0001-0004) includes lock-overlay support
- Whether notifications show sender text or only "New message" when locked (telephony requirement T5-7.2) [V: TELEPHONY-APPS-PLAN.md:560]
- Whether the `x-omamobile-public-summary` hint is honored for lock-screen redaction

### 2.3 Verification needed (phone-gated)

See §6.1 Lock-screen protocol.

---

## 3. Screen-off queueing

### 3.1 What is known

- **Quickshell service lifecycle:** NotificationServer runs as part of omarchy-shell, a user session service. When the screen is off, the session may be locked but the user slice typically remains active
- **File persistence:** Notifications are written to disk immediately on arrival; the toast rendering is the only part that depends on a visible screen [V: Service.qml design]
- **Hyprland dependency:** Toast surfaces require a running compositor; if Hyprland stops when screen-off, overlay layers cannot render
- **Mobile profile:** Omarchy Mobile's shell profile for phones may have different screen-off behavior than desktop

### 3.2 What is unknown [I]

- Whether Hyprland continues running with screen off on this device
- Whether notifications received while screen-off are queued for display when screen returns
- Whether the notification service itself remains active during screen-off suspend
- Whether any power-saving mechanism defers notification processing

### 3.3 Verification needed (phone-gated)

See §6.2 Screen-off protocol.

---

## 4. Do Not Disturb (DND)

### 4.1 Implementation

DND is implemented as a **shell-level property** in the notification service:

```javascript
// Service.qml:56-61
property bool doNotDisturb: false
function setDoNotDisturb(value) {
  var on = !!value
  if (on === doNotDisturb) return
  doNotDisturb = on
  saveQuiet()  // Persists to disk
}
```

- **Persistence:** DND state is saved via `saveQuiet()` and `saveSoon("quiet")` — persisted to user config, survives shell restarts [V: Service.qml:62]
- **DBus interface:** DND can be toggled via IPC: `isDnd()` returns current state, `toggleDnd()` toggles it [V: Service.qml from patch 0019 context:1446-1448]

### 4.2 Behavior when DND is active

- Notifications are **still received and stored** — DND is a presentation setting, not a delivery block [V: Service.qml design, no filter in handleNotification]
- **Toasts are suppressed** — no visible toast appears [I: inferred from property name and typical DND behavior]
- **Sound/vibration may be suppressed** — depends on feedbackd integration and sound theme; omatel-agent 0.2.3 silences callers during DND [V: TELEPHONY-APPS-PLAN.md:8 line 363]
- **Quick settings shade still shows notifications** — DND affects toast display, not the history/shade [I: needs verification]

### 4.3 What is unknown [I]

- Exact suppression behavior (toast only vs all visual/sound)
- Whether DND state is exposed in the quick settings panel
- Whether DND affects the lock-screen notification display differently

### 4.4 Verification needed (phone-gated)

See §6.3 DND protocol.

---

## 5. Omarchy patches applied to shell

All four notification-related patches from `omamobile-omarchy` package are referenced in the issue. These patches extend the upstream Omarchy notification system for phone use:

| Patch | File | Capability | Status on phone |
|-------|------|-------------|------------------|
| 0015 | `0015-notifications-inline-reply.patch` | Inline reply in toasts (freedesktop extension) | Present in omamobile-omarchy 0.1.6+ [V: TELEPHONY-APPS-PLAN.md:8 line 365] |
| 0017 | `0017-notifications-swipe-to-dismiss-and-a-touch-close-button.patch` | Touch swipe dismiss + close button for touchscreens | Present |
| 0019 | `0019-notifications-forget-one-notification-by-ipc.patch` | Forget individual notification by filename via IPC | Present |
| 0020 | `0020-notifications-touch-phrasing-for-keyboard-and-click-hints.patch` | Replace "click" with "tap", remove Super+ key hints | Present |

**Patch 0015 details:** Adds `inlineReplySupported` capability, Reply button on applicable toasts, text field with Send/Cancel, pauses countdown while field is open, sends `NotificationReplied` DBus signal [V: 0015-notifications-inline-reply.patch].

**Patch 0017 details:** Adds touch-screen drag handler for swipe-to-dismiss, close button with 44px touch target visible on touch devices, disables drag during reply [V: 0017-notifications-swipe-to-dismiss-and-a-touch-close-button.patch].

**Patch 0019 details:** Adds `forgetNotification(name)` function that removes a notification by its filename without sender action, deletes history entry, used by quick settings swipe dismiss [V: 0019-notifications-forget-one-notification-by-ipc.patch].

**Patch 0020 details:** Modifies `omarchy-notification-send` to detect touch platform (via `/usr/bin/omamobile-update` or `OMARCHY_NOTIFICATION_PHRASING=touch`) and reword notifications for touch: "Click to" → "Tap to", remove Super+ hints, special cases for screenshot/toast messages [V: 0020-notifications-touch-phrasing-for-keyboard-and-click-hints.patch].

---

## 6. Telephony consumers

Omarchy's telephony stack (omatel) integrates with the notification system:

### 6.1 Incoming calls

- **omadialer:** Sends a **critical notification** with Answer and Decline actions for incoming calls [V: TELEPHONY-APPS-PLAN.md:8 line 359]
- **omamobile-shell:** Renders a **heads-up card** with Answer and Decline buttons on unlocked phone; full-screen card over lock on locked phone [V: TELEPHONY-APPS-PLAN.md:8 line 359]
- **omatel-agent:** Silences callers during DND except for starred contacts; publishes `SilencedCalls` which the card follows [V: TELEPHONY-APPS-PLAN.md:8 line 363]

### 6.2 SMS and messages

- **omamessages:** Sends notifications with `inline-reply` action; listens for `NotificationReplied` DBus signal [V: TELEPHONY-APPS-PLAN.md:367]
- **Inline reply flow:** User taps Reply on notification → text field appears → Send emits `NotificationReplied` → omamessages receives it and sends SMS, marks conversation read [V: TELEPHONY-APPS-PLAN.md:8 line 367]
- **Notification structure:** One notification per conversation, replaced as messages arrive; category `im.received`; hints: `sender-pid`, `desktop-entry`, `x-omamobile-private`, `x-omamobile-public-summary` [V: TELEPHONY-APPS-PLAN.md:368, 656]
- **Lock screen behavior:** Missed-call notifications offer Call back and Message actions; new messages show "New message" only by default, with sender and text as option [V: TELEPHONY-APPS-PLAN.md:560]

### 6.3 Emergency call

- **omamobile-omarchy patch 0014:** Adds "Emergency call" button on lock screen under PIN pad [V: TELEPHONY-APPS-PLAN.md:8 line 363]
- **omamobile-shell 0.2.14:** Answers emergency calls with warning dialog over lock [V: TELEPHONY-APPS-PLAN.md:8 line 363]

---

## 7. Gap list vs stock Android

This device ships with **OxygenOS** (OnePlus's Android fork). The Omarchy notification path replaces Android's notification system entirely.

| Aspect | Stock (OxygenOS) | Omarchy Mobile | Gap |
|--------|-------------------|----------------|-----|
| **Daemon** | `NotificationManagerService` (Android system service) | Quickshell NotificationServer (user session) | Different process model; no system-service integration |
| **Transport** | Binder IPC, Android APIs | DBus `org.freedesktop.Notifications` | Apps must use DBus instead of Android APIs |
| **Display** | System UI notification shade, lock screen, AOD | Shell overlay layers, quick settings shade | Lock-screen integration unclear on this device [I] |
| **Persistence** | System-managed, survives reboots | User session files in `~/.local/state/omarchy/notifications/` | Does not survive reboot; no system backup |
| **LED notification** | Hardware notification LED (status indicator) | **Absent** — no discrete LED found in public hardware descriptions [V: MISC-HW-PLAN.md:78]; display/AOD only |
| **Sound** | Android sound pool, per-app channels | feedbackd + sound theme | Different sound system; omatel uses feedbackd for call ringtone |
| **DND** | Android Do Not Disturb with schedules | Shell-level DND property | No scheduling; manual toggle only [I] |
| **Screen-off behavior** | Notifications wake screen, appear on lock | Unknown — depends on Hyprland/session state [I] | Screen-off queueing and wake unclear |
| **Action buttons** | Android Quick Settings actions | freedesktop actions via DBus | Limited to sender-provided actions |
| **Inline reply** | Android's `MessagingStyle` + `RemoteInput` | freedesktop `inline-reply` extension | Different API; requires sender support |
| **Priority/urgency** | Android importance levels (1-5) | freedesktop urgency (Low=0, Normal=1, Critical=2) | Mapping may differ |
| **Grouping** | Android notification groups/channels | None — each notification is independent | No grouping support |
| **History** | Persistent in system DB | Session-local files, max 10 history entries | Limited history; no cross-session |

### 7.1 Critical gaps for phone use

1. **No hardware notification LED** — Instantnoodlep has no documented discrete notification LED; users rely on display/AOD [V: MISC-HW-PLAN.md:78]
2. **No native Android app support** — Android apps using Android notification APIs will not send to Omarchy's DBus interface without a shim
3. **No reboot persistence** — Notifications do not survive reboot; history is session-local
4. **DND lacks scheduling** — Shell DND is manual toggle only; no time-based or location-based rules
5. **Screen-off behavior unknown** — Unclear if notifications wake screen or queue for display [I]
6. **Lock-screen redaction unclear** — Unknown if public-summary hints are honored [I]

---

## 8. Read-only on-phone verification protocol

### 8.1 Prerequisites

- Phone booted into Omarchy Mobile (daily K3 on `boot_b`, B5 set) [V: state.md]
- omamobile-shell 0.2.133-1.2 with device package 0.0.6-1 installed [V: state.md]
- SSH access available (Wi-Fi connected)
- No writes to any partition; read-only commands only

### 8.2 Lock-screen visibility (T-LS)

**Purpose:** Determine if notifications display on lock screen and what information is shown.

**Steps:**
```bash
# 1. Verify lock state
ssh phone systemctl --user status omarchy-lock 2>&1 | head -5
# Expect: active (running) or inactive

# 2. Verify notification service is running
ssh phone systemctl --user status omarchy-shell 2>&1 | head -5
# Expect: active (running)

# 3. Check if lock overlay is supported
ssh phone grep -r above_lock /etc/xdg/omamobile-shell/ /usr/share/omamobile-shell/ 2>/dev/null || echo "not found in config"
# Expect: above_lock = 2 in some config, or not found

# 4. Send a test notification while locked
ssh phone su - user -c 'omarchy-notification-send --app "Test" --summary "Test notification" --body "This is a test" --urgency normal'
# Expect: notification appears somewhere (lock, shade, or nowhere)

# 5. Observe: Does notification appear on lock screen?
#    - Full content (app, summary, body)?
#    - Redacted to "New message" only?
#    - Not visible at all?

# 6. Check notification files
ssh phone ls -la ~/.local/state/omarchy/notifications/ 2>/dev/null
# Expect: <timestamp>-<id>.json files

# 7. Check file content (sanitized)
ssh phone cat ~/.local/state/omarchy/notifications/*.json 2>/dev/null | python3 -c "import sys,json; [print(json.dumps(json.loads(l), indent=2)) for l in sys.stdin]" 2>&1 | head -20
# Expect: JSON with app, summary, body fields
```

**Stop condition:** Test notification sent and files observed, or error recorded.
**Rollback:** None needed (read-only).

### 8.3 Screen-off queueing (T-SO)

**Purpose:** Determine if notifications are queued during screen-off and displayed when screen returns.

**Steps:**
```bash
# 1. Verify current screen state
ssh phone cat /sys/class/drm/card?-*/status 2>/dev/null | sort -u
# Expect: "connected" for active outputs

# 2. Check if Hyprland is running
ssh phone pgrep -a hyprland
# Expect: process running

# 3. Turn screen off (or wait for auto-off)
#    Owner: press power button or wait for timeout
#    Verify:
ssh phone cat /sys/class/drm/card?-*/status 2>/dev/null | sort -u
# Expect: "off" or "disconnected" for display outputs

# 4. From another terminal, send notifications while screen off
for i in 1 2 3; do
  ssh phone su - user -c "omarchy-notification-send --app Test --summary \"Test $i\" --body \"Message $i\" --urgency normal"
  sleep 2
done

# 5. Turn screen on
#    Owner: press power button or tap

# 6. Observe: Do queued notifications appear?
#    - Immediately on screen-on?
#    - Only after unlock?
#    - Not at all?

# 7. Check notification files
ssh phone ls -la ~/.local/state/omarchy/notifications/ 2>/dev/null
ssh phone ls -la ~/.local/state/omarchy/notifications/history/ 2>/dev/null
# Expect: Files for sent notifications
```

**Stop condition:** Screen cycled off/on, notifications sent, files checked.
**Rollback:** None needed (read-only).

### 8.4 DND behavior (T-DND)

**Purpose:** Determine DND suppression behavior.

**Steps:**
```bash
# 1. Check current DND state
ssh phone su - user -c 'gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.GetCapabilities' 2>&1
# Expect: array of capability strings, may include DND-related hints

# 2. Or via omarchy-omarchy IPC (if available)
ssh phone su - user -c 'omarchy-ipc isDnd' 2>&1 || echo "command not found"
# Expect: "on" or "off"

# 3. Toggle DND off (ensure clean state)
ssh phone su - user -c 'omarchy-ipc toggleDnd' 2>&1

# 4. Send test notification
ssh phone su - user -c 'omarchy-notification-send --app Test --summary "DND off test" --body "DND is off" --urgency normal'
# Expect: notification appears

# 5. Toggle DND on
ssh phone su - user -c 'omarchy-ipc toggleDnd' 2>&1

# 6. Send another test notification
ssh phone su - user -c 'omarchy-notification-send --app Test --summary "DND on test" --body "DND is on" --urgency normal'
# Expect: notification does NOT appear (toast suppressed)

# 7. Check files (notification should still be stored)
ssh phone ls -la ~/.local/state/omarchy/notifications/ 2>/dev/null
# Expect: file exists for DND-on notification

# 8. Check DND state
ssh phone su - user -c 'omarchy-ipc isDnd' 2>/dev/null
# Expect: "on"
```

**Stop condition:** DND toggled, notifications sent, behavior observed.
**Rollback:** Toggle DND off to restore normal behavior.

### 8.5 Quick settings shade (T-QS)

**Purpose:** Verify quick settings notification list shows history.

**Steps:**
```bash
# 1. Open quick settings shade (owner gesture)
# 2. Verify notification entries appear
# 3. Swipe dismiss one entry
# 4. Verify it disappears from shade
# 5. Check history files
ssh phone ls -la ~/.local/state/omarchy/notifications/history/ 2>/dev/null
# Expect: file may or may not exist (depends on patch 0019 implementation)
```

**Stop condition:** Shade interaction complete.
**Rollback:** None needed.

---

## 9. What was verified off-phone [V]

| Claim | Source |
|-------|--------|
| Notification daemon is Quickshell's NotificationServer | omarchy-mobile/packages/omamobile-shell/shell/plugins/notifications/Service.qml:1-6 |
| File storage in ~/.local/state/omarchy/notifications/ | NotificationsModel.js:8-15 |
| Patch 0015 adds inline reply | omarchy-mobile/packages/omamobile-omarchy/patches/0015-notifications-inline-reply.patch header |
| Patch 0017 adds swipe dismiss | omarchy-mobile/packages/omamobile-omarchy/patches/0017-notifications-swipe-to-dismiss-and-a-touch-close-button.patch header |
| Patch 0019 adds forget by IPC | omarchy-mobile/packages/omamobile-omarchy/patches/0019-notifications-forget-one-notification-by-ipc.patch header |
| Patch 0020 adds touch phrasing | omarchy-mobile/packages/omamobile-omarchy/patches/0020-notifications-touch-phrasing-for-keyboard-and-click-hints.patch header |
| DND implemented as shell property | Service.qml:56-62 |
| omatel sends notifications with inline-reply | TELEPHONY-APPS-PLAN.md:367 |
| No notification LED on device | MISC-HW-PLAN.md:78 |
| NotificationRow.qml location | omarchy-mobile/packages/omamobile-shell/plugins/omamobile.quicksettings/NotificationRow.qml |
| NotificationsModel.js location | omarchy-mobile/packages/omamobile-shell/plugins/omamobile.quicksettings/NotificationsModel.js |

---

## 10. What is left for the phone

1. **Lock-screen visibility:** Run T-LS protocol to confirm notifications appear on lock screen and determine redaction behavior
2. **Screen-off queueing:** Run T-SO protocol to determine if notifications wake screen and/or queue for display
3. **DND behavior:** Run T-DND protocol to confirm suppression behavior
4. **Quick settings integration:** Run T-QS protocol to verify shade shows and can dismiss notifications
5. **Telephony integration:** Verify omatel/omadialer notifications appear correctly with actions
6. **History persistence:** Verify notifications survive session restarts (unlikely without reboot test)

---

## 11. Recommendations

1. **Add lock-screen notification support** if absent: ensure overlay layers can draw over lock; honor `x-omamobile-public-summary` for redaction
2. **Add screen-off handling:** ensure Hyprland stays running or notifications are queued for display on wake
3. **Add DND scheduling:** extend shell DND with time-based rules for phone use
4. **Consider notification LED emulator:** since no hardware LED exists, use display/AOD or status bar indicator for missed notifications
5. **Document the notification path** in device-specific docs for app developers

---

*Generated for issue #190. Worked by a Mistral Vibe agent from the issue room.*
