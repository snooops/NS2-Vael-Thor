#!/usr/bin/env bash
# Renders the Subject look concepts (or the ones named): <name>_{front,back}_transparent.png (alpha),
# <name>.png (front + back on light grey) and overview.jpg (the three looks, front and back, with titles).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
blender -b -P "$HERE/make_subject_concepts.py" -- "$HERE" "$@" 2>&1 | grep -E "^rendered|Traceback|Error:" | grep -v OpenColorIO || true
python3 -I - "$HERE" <<'PY'
import sys, os
from PIL import Image, ImageDraw, ImageFont
d = sys.argv[1]
LOOKS = [("shackled", "I  SHACKLED", "a brute held in chrome restraints"),
         ("stalker", "II  STALKER", "chitin predator, scything forearm blades"),
         ("graft", "III  GRAFT", "flesh on a chrome frame, crystal heart")]
def font(size):
    for f in ("/usr/share/fonts/google-noto/NotoSans-Bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
        if os.path.exists(f): return ImageFont.truetype(f, size)
    return ImageFont.load_default()
def tile(name, view, size):
    im = Image.open(os.path.join(d, "%s_%s_transparent.png" % (name, view))).convert("RGBA")
    bg = Image.new("RGBA", im.size, (236, 236, 240, 255)); bg.alpha_composite(im)
    return bg.convert("RGB").resize((size, size))
cols = []
for n, title, sub in LOOKS:
    if not os.path.exists(os.path.join(d, n + "_front_transparent.png")): continue
    pair = Image.new("RGB", (1200, 600)); pair.paste(tile(n, "front", 600), (0, 0)); pair.paste(tile(n, "back", 600), (600, 0))
    pair.save(os.path.join(d, n + ".png"))
    cols.append((tile(n, "front", 600), tile(n, "back", 600), title, sub))
out = Image.new("RGB", (600 * len(cols), 1300), (24, 18, 34))
dr = ImageDraw.Draw(out)
for i, (f, b, title, sub) in enumerate(cols):
    out.paste(f, (i * 600, 100)); out.paste(b, (i * 600, 700))
    dr.text((i * 600 + 24, 16), title, fill=(220, 190, 255), font=font(38))
    dr.text((i * 600 + 26, 62), sub, fill=(170, 150, 200), font=font(21))
out.save(os.path.join(d, "overview.jpg"), quality=90)
PY
