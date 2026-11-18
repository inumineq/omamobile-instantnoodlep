#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
home=$root/home
share=$root/share
sources=$root/sources
mkdir -p "$home/.config/foot" "$home/.config/hypr" "$share" "$sources/applications"
cp scaling/apps.tsv "$share/apps.tsv"
cp hypr/windowrules.lua "$share/windowrules.lua"
cat > "$home/.config/foot/foot.ini" <<'EOF'
font=JetBrainsMono Nerd Font:size=9
pad=6x6
[scrollback]
multiplier=3.0
[touch]
long-press-delay=300
EOF
cat > "$home/.config/hypr/looknfeel.lua" <<'EOF'
dofile("/usr/share/omarchy/hypr/phone.lua")
EOF
cat > "$sources/applications/qv4l2.desktop" <<'EOF'
[Desktop Entry]
Name=Qt V4L2
Exec=qv4l2 %f
EOF
cat > "$sources/applications/org.pinta_project.Pinta.desktop" <<'EOF'
[Desktop Entry]
Name=Pinta
Exec=pinta %F
EOF
cat > "$sources/applications/libreoffice-writer.desktop" <<'EOF'
[Desktop Entry]
Name=Writer
Exec=libreoffice --writer %U
EOF
cat > "$sources/applications/org.fcitx.Fcitx5.Config.desktop" <<'EOF'
[Desktop Entry]
Name=Fcitx config
Exec=fcitx5-configtool
EOF

HOME=$home XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
  OMAMOBILE_SCALING_SHARE="$share" OMAMOBILE_DESKTOP_SOURCE_DIRS="$sources" \
  ./bin/omamobile-instantnoodlep-scaling
grep -qx 'font=JetBrainsMono Nerd Font:size=8' "$home/.config/foot/foot.ini"
grep -qx 'pad=4x4' "$home/.config/foot/foot.ini"
grep -qx 'multiplier=2.0' "$home/.config/foot/foot.ini"
grep -qx 'long-press-delay=300' "$home/.config/foot/foot.ini"
grep -q '^Exec=env QT_SCALE_FACTOR=0.85 qv4l2 %f$' "$home/.local/share/applications/qv4l2.desktop"
grep -q '^Exec=env GDK_SCALE=2 pinta %F$' "$home/.local/share/applications/org.pinta_project.Pinta.desktop"
grep -q '^Exec=env GDK_SCALE=2 libreoffice --writer %U$' "$home/.local/share/applications/libreoffice-writer.desktop"
grep -q '^Exec=env QT_SCALE_FACTOR=0.85 fcitx5-configtool$' "$home/.local/share/applications/org.fcitx.Fcitx5.Config.desktop"
grep -q '^X-Omamobile-Scaling=I$' "$home/.local/share/applications/qv4l2.desktop"
test ! -e "$home/.local/share/applications/qvidcap.desktop"
test ! -e "$home/.config/environment.d"
grep -q 'dofile(".*/windowrules.lua")' "$home/.config/hypr/looknfeel.lua"

# Idempotent and respects user-modified Foot values and desktop entries.
printf 'font=User Font:size=12\npad=12x12\n[scrollback]\nmultiplier=1.0\n' > "$home/.config/foot/foot.ini"
printf '[Desktop Entry]\nName=My override\nExec=custom-launcher\n' > "$home/.local/share/applications/qv4l2.desktop"
HOME=$home XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
  OMAMOBILE_SCALING_SHARE="$share" OMAMOBILE_DESKTOP_SOURCE_DIRS="$sources" \
  ./bin/omamobile-instantnoodlep-scaling
grep -qx 'font=User Font:size=12' "$home/.config/foot/foot.ini"
grep -qx 'Exec=custom-launcher' "$home/.local/share/applications/qv4l2.desktop"
test "$(grep -c '/windowrules.lua' "$home/.config/hypr/looknfeel.lua")" -eq 1
