#!/usr/bin/env bash
# Vael'Thor crosshair atlas -> output/ui/vaelthor/crosshair_atlas.dds (used by GUI/GUIVTCrosshair.lua).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/ui"; OUT="$MOD/output/ui/vaelthor"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT" "$HERE/crosshair"
python3 -I "$HERE/make_crosshair_textures.py" "$HERE/crosshair/crosshair_atlas.tga"
cd "$HERE/crosshair"
# -rgb keeps the alpha channel uncompressed; -nomips keeps the thin lines crisp
wine "$NS2/utils/nvcompress.exe" -rgb -nomips crosshair_atlas.tga "$(w "$OUT/crosshair_atlas.dds")" >/dev/null 2>&1
ls -l "$OUT/crosshair_atlas.dds"
