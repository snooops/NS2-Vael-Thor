#!/usr/bin/env bash
# Caste portraits for the Synthesis Matrix menu (GUIVTMatrixMenu):
# renders each rigged player model with its in-game texture (render_caste_portrait.py), trims, and packs
# them into output/ui/vaelthor/caste_portraits.dds (1024x256: vanguard | infiltrator | subject | praetor).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; MOD="$(cd "$HERE/../.." && pwd)"
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
WORK="$HERE/work/portraits"; OUT="$MOD/output/ui/vaelthor"; TEX="$MOD/output/models/vaelthor"
mkdir -p "$WORK" "$OUT"
render(){  # blend tex_dir tex_name out_name [framing]
  blender -b --factory-startup "$1" --python-exit-code 1 -P "$HERE/render_caste_portrait.py" -- "$2" "$3" "$WORK/$4.png" ${5:-} \
    2>&1 | grep -E "PORTRAIT|Traceback|Error:" | grep -v OCIO || true
}
render "$MOD/art/fab/silver_sentinel/work/sentinel_rigged.blend" "$TEX/sentinel" sentinel vanguard
render "$MOD/art/fab/cyber_sentinel/work/cyber_rigged.blend"     "$TEX/cyber"    cyber    infiltrator
render "$MOD/art/fab/mecha_sentinel/work/mecha_rigged.blend"     "$TEX/mecha"    mecha    subject
render "$MOD/art/fab/titan_sentinel/work/titan_rigged.blend"     "$TEX/titan"    titan    praetor full
python3 -I - "$WORK" <<'PY'
import sys, os
from PIL import Image
work = sys.argv[1]; cell = 256
atlas = Image.new("RGBA", (cell * 4, cell), (0, 0, 0, 0))
for i, name in enumerate(["vanguard", "infiltrator", "subject", "praetor"]):
    im = Image.open(os.path.join(work, name + ".png")).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())          # trim empty space
    s = min((cell - 8) / im.width, (cell - 4) / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    atlas.alpha_composite(im, (i * cell + (cell - im.width) // 2, cell - im.height))   # bottom aligned
atlas.save(os.path.join(work, "caste_portraits.tga"))
print("atlas ok")
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -rgb -nomips caste_portraits.tga "Z:$(echo "$OUT/caste_portraits.dds" | sed 's#/#\\#g')" >/dev/null 2>&1
ls -l "$OUT/caste_portraits.dds"
