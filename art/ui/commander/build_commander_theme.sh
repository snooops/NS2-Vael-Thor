#!/usr/bin/env bash
# Vael'Thor commander HUD theme -> output/ui/vaelthor/commander/*.dds (violet copies of the marine textures;
# swapped in for Vael'Thor commanders by source/lua/VaelThor/GUI/GUIVTCommanderTheme.lua)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/ui/commander"; WORK="$HERE/theme"; OUT="$MOD/output/ui/vaelthor/commander"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
NAMES="marine_commander_textures marine_commander_logout marine_commander_tabs marine_command_cooldown commander_alert_badge"
mkdir -p "$WORK" "$OUT"
python3 -I "$HERE/make_commander_theme.py" "$NS2/ns2/ui" "$WORK" $NAMES
cd "$WORK"
for n in $NAMES; do
  wine "$NS2/utils/nvcompress.exe" -rgb "$n.tga" "$(w "$OUT/$n.dds")" >/dev/null 2>&1
done
ls -l "$OUT"
