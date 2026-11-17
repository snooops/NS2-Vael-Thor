#!/usr/bin/env bash
# Renders the Artificer look concepts (or the ones named): <name>_transparent.png (alpha), <name>.png (light grey
# background), overview.jpg (the three looks) and overview_anvil.jpg (the Anvil and its variants) with titles.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
blender -b -P "$HERE/make_artificer_concepts.py" -- "$HERE" "$@" 2>&1 | grep -E "^rendered|Traceback|Error:" | grep -v OpenColorIO || true
python3 -I - "$HERE" <<'PY'
import sys, os
from PIL import Image, ImageDraw, ImageFont
d = sys.argv[1]
SHEETS = {
    "overview.jpg": [("reliquary", "I  RELIQUARY", "the hangar on its back"),
                     ("choir", "II  CHOIR", "drones grown in a psionic halo"),
                     ("anvil", "III  ANVIL", "a walking quadruped foundry")],
    "overview_anvil.jpg": [("anvil", "ANVIL", "the original: four legs, crane cradle"),
                           ("anvil_strider", "A  STRIDER", "six legs, three-segment assembly line"),
                           ("anvil_crucible", "B  CRUCIBLE", "crab foundry, furnace dome, pincers"),
                           ("anvil_forgewarden", "C  FORGEWARDEN", "centaur: torso on a foundry body")],
}
def font(size):
    for f in ("/usr/share/fonts/google-noto/NotoSans-Bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
        if os.path.exists(f): return ImageFont.truetype(f, size)
    return ImageFont.load_default()
for sheet, names in SHEETS.items():
    tiles = []
    for n, title, sub in names:
        p = os.path.join(d, n + "_transparent.png")
        if not os.path.exists(p): continue
        im = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", im.size, (236, 236, 240, 255)); bg.alpha_composite(im)
        bg.convert("RGB").save(os.path.join(d, n + ".png"))
        tiles.append((bg.convert("RGB").resize((800, 800)), title, sub))
    if not tiles: continue
    out = Image.new("RGB", (800 * len(tiles), 900), (24, 18, 34))
    dr = ImageDraw.Draw(out)
    for i, (im, title, sub) in enumerate(tiles):
        out.paste(im, (i * 800, 100))
        dr.text((i * 800 + 30, 18), title, fill=(220, 190, 255), font=font(40))
        dr.text((i * 800 + 32, 66), sub, fill=(170, 150, 200), font=font(22))
    out.save(os.path.join(d, sheet), quality=90)
PY
