#!/usr/bin/env bash
# Mod override of ui/marine_outline_lookup.dds with a fading red band (Echo Scan).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/ui"; OUT="$MOD/output/ui"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT"
python3 -I "$HERE/make_outline_lookup.py" "$NS2/ns2/ui/marine_outline_lookup.dds" "$HERE/marine_outline_lookup.tga"
cd "$HERE"
wine "$NS2/utils/nvcompress.exe" -rgb marine_outline_lookup.tga "$(w "$OUT/marine_outline_lookup.dds")" >/dev/null 2>&1
ls -l "$OUT/marine_outline_lookup.dds"
