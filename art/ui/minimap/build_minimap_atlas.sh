#!/usr/bin/env bash
# Vael'Thor minimap atlas -> output/ui/vaelthor/minimap_blip.dds (vanilla ui/minimap_blip.dds + Vael'Thor rows)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/ui/minimap"; OUT="$MOD/output/ui/vaelthor"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT"; cd "$HERE"
python3 -I -c "
from PIL import Image
Image.open('$NS2/ns2/ui/minimap_blip.dds').convert('RGBA').save('vanilla_minimap_blip.png')"
python3 -I make_minimap_atlas.py vanilla_minimap_blip.png vaelthor_minimap_blip.tga
# uncompressed like the vanilla atlas (pixel art, no mips)
wine "$NS2/utils/nvcompress.exe" -rgb -nomips vaelthor_minimap_blip.tga "$(w "$OUT/minimap_blip.dds")" >/dev/null 2>&1
ls -l "$OUT/minimap_blip.dds"
