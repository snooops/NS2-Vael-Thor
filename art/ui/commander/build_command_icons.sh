#!/usr/bin/env bash
# Commander icon atlas: vanilla ui/buildmenu.dds + five rows of Vael'Thor icons -> output/ui/buildmenu.dds
# (mod override; every vanilla icon keeps its pixel position). Cell order: make_command_icons.py ICONS,
# mirrored in source/lua/VaelThor/Hooks/TechTreeButtons.lua.
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/ui/commander"; OUT="$MOD/output/ui"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT"; cd "$HERE"
python3 -I -c "
from PIL import Image
Image.open('$NS2/ns2/ui/buildmenu.dds').convert('RGBA').save('vanilla_buildmenu.png')"
python3 -I make_command_icons.py vanilla_buildmenu.png vaelthor_buildmenu.tga preview_icons.png
# uncompressed with mipmaps, like the vanilla atlas
wine "$NS2/utils/nvcompress.exe" -rgb vaelthor_buildmenu.tga "$(w "$OUT/buildmenu.dds")" >/dev/null 2>&1
ls -l "$OUT/buildmenu.dds"
