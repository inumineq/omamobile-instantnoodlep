#!/bin/bash
# SPDX-License-Identifier: MIT
# Host-only profile/launcher test. All fake applications and flags live under T.
set -euo pipefail
profile_script=$(cd "$(dirname "$0")/.." && pwd)/bin/omamobile-instantnoodlep-mobile-profile
app_launcher=$(cd "$(dirname "$0")/.." && pwd)/bin/omamobile-instantnoodlep-app-launcher
profile_source=$(cd "$(dirname "$0")/.." && pwd)/chromium
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { echo "not ok - $*" >&2; exit 1; }
ok() { echo "ok - $*"; }

mkdir -p "$T/bin" "$T/home/.config" "$T/system/applications"
cp "$profile_source/instantnoodlep.conf" "$T/profile.conf"
cp "$profile_source/apps.conf" "$T/apps.conf"
# Synthetic per-app values prove the wrapper adds overrides only when set.
sed -i 's/^Basecamp|chromium|inherit|auto$/Basecamp|chromium|0.91|auto/' "$T/apps.conf"
sed -i 's/^obsidian|electron|inherit|auto$/obsidian|electron|1.08|wayland/' "$T/apps.conf"
cat > "$T/bin/chromium" <<'FAKE'
#!/bin/bash
printf '%s\n' 'Chromium 153.0.0.0'
FAKE
chmod +x "$T/bin/chromium"
for app in Basecamp HEY WhatsApp X YouTube; do
  cat > "$T/system/applications/$app.desktop" <<EOF_DESKTOP
[Desktop Entry]
Name=$app
Exec=chromium --app=https://example.invalid/$app %U
Type=Application
[Desktop Action NewWindow]
Name=New Window
Exec=chromium --new-window
EOF_DESKTOP
done
for app in obsidian Discord localsend; do
  command_name=$app
  [[ $app != localsend ]] || command_name=localsend_app
  cat > "$T/system/applications/$app.desktop" <<EOF_DESKTOP
[Desktop Entry]
Name=$app
Exec=$command_name %U
Type=Application
EOF_DESKTOP
done
cat > "$T/home/.config/chromium-flags.conf" <<'FLAGS'
--no-first-run
--enable-wayland-ime
--wayland-text-input-version=3
--force-device-scale-factor=0.83
"--user-agent=Mozilla/5.0 (Linux; Android 14; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Mobile Safari/537.36"
--user-data-dir=/tmp/user-profile-argument
FLAGS
cp "$T/home/.config/chromium-flags.conf" "$T/original-flags.conf"
export HOME="$T/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_DATA_DIRS="$T/system"
export XDG_STATE_HOME="$HOME/.local/state"
export PATH="$T/bin:$PATH"
export OMAMOBILE_INSTANTNOODLEP_PROFILE_DIR="$T"
mv "$T/profile.conf" "$T/instantnoodlep.conf"
mv "$T/apps.conf" "$T/apps.conf.tmp"
# The test directory hosts both profile files expected by the manager.
cp "$T/apps.conf.tmp" "$T/apps.conf"

run_profile() { "$profile_script" apply; }
run_profile
run_profile
flags=$XDG_CONFIG_HOME/chromium-flags.conf
[[ $(grep -c '^--force-device-scale-factor=' "$flags") = 1 ]] || fail 'duplicate device scale factors'
[[ $(grep -c '^"--user-agent=' "$flags") = 1 ]] || fail 'device UA was not singular'
grep -q 'OnePlus 8 Pro' "$flags" || fail 'upstream Pixel UA was not replaced'
! grep -q 'Pixel 7 Pro' "$flags" || fail 'upstream Pixel UA remains'
[[ $(grep -cx -- --no-first-run "$flags") = 1 ]] || fail 'upstream no-first-run flag changed'
[[ $(grep -cx -- --enable-wayland-ime "$flags") = 1 ]] || fail 'duplicate IME flag'
[[ $(grep -cx -- --wayland-text-input-version=3 "$flags") = 1 ]] || fail 'duplicate text-input-v3 flag'
grep -qx -- --user-data-dir=/tmp/user-profile-argument "$flags" || fail 'unrelated Chromium flag was lost'
! grep -Eq '^--(touch-events|enable-pinch|ozone-platform)=|^--enable-features=.*OverlayScrollbar' "$flags" || fail 'unmeasured optional feature was forced'
ok 'global flags preserve upstream values, replace only the Pixel UA, and remain idempotent'

for app in Basecamp HEY WhatsApp X YouTube obsidian Discord localsend; do
  desktop=$XDG_DATA_HOME/applications/$app.desktop
  test -f "$desktop" || fail "launcher override missing for $app"
  grep -q '^X-Omamobile-Instantnoodlep-Profile=1$' "$desktop" || fail "profile marker missing for $app"
  grep -q '^Exec=/usr/bin/omamobile-instantnoodlep-app-launcher ' "$desktop" || fail "launcher wrapper missing for $app"
done
[[ $(grep -c '^Exec=/usr/bin/omamobile-instantnoodlep-app-launcher ' "$XDG_DATA_HOME/applications/HEY.desktop") = 1 ]] || fail 'desktop Exec wrapped more than once'
grep -qx 'Exec=chromium --new-window' "$XDG_DATA_HOME/applications/HEY.desktop" || fail 'desktop action Exec was unexpectedly rewritten'
ok 'all five web apps and three Electron apps are wrapped once; secondary actions stay intact'

cat > "$T/fake-app" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" > "$APP_ARGS"
FAKE
chmod +x "$T/fake-app"
export APP_ARGS="$T/app-args"
"$app_launcher" Basecamp -- "$T/fake-app" --app=https://example.invalid/basecamp
 grep -qx -- --force-device-scale-factor=0.91 "$APP_ARGS" || fail 'per-app Chromium scale was not passed'
"$app_launcher" obsidian -- "$T/fake-app" note.md
grep -qx -- --force-device-scale-factor=1.08 "$APP_ARGS" || fail 'per-app Electron scale was not passed'
grep -qx -- --ozone-platform=wayland "$APP_ARGS" || fail 'measured per-app Wayland override was not passed'
ok 'per-app overrides are passed only when configured'

"$profile_script" reset
diff -u "$T/original-flags.conf" "$flags" >/dev/null || fail 'reset did not restore original Chromium flags'
for app in Basecamp HEY WhatsApp X YouTube obsidian Discord localsend; do
  test ! -e "$XDG_DATA_HOME/applications/$app.desktop" || fail "system launcher override remains for $app"
done
run_profile
diff -u "$T/original-flags.conf" "$flags" >/dev/null || fail 'disabled profile was unexpectedly reapplied'
ok 'reset restores original flags, removes owned launcher overrides, and disables future application'
