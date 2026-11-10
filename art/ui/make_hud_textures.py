"""Vael'Thor HUD textures (psionic crystal style), tinted at runtime.
Usage: python3 make_hud_textures.py <out_dir>
  hud_panel.tga 512x128  dark translucent body, angular cut corners, glowing violet crystal edge, facet lines
  hud_chip.tga  256x48   small hexagonal frame for ability rows
  hud_bar.tga   256x24   faceted parallelogram fill (white, tinted in Lua), highlight band
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
EDGE = (190, 120, 255)

def frame(w, h, cut, body_alpha, glow_px, facets):
    poly = [(cut, 0), (w - cut * 2, 0), (w - 1, cut * 2), (w - 1, h - cut), (w - cut, h - 1), (cut * 2, h - 1), (0, h - cut * 2), (0, cut)]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(body)
    d.polygon(poly, fill=(10, 5, 22, body_alpha))
    if facets:                                           # faint crystal facets inside
        for x in range(-h, w, 46):
            d.line([(x, h), (x + h, 0)], fill=(80, 40, 140, 26), width=1)
    im = Image.alpha_composite(im, body)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0)); g = ImageDraw.Draw(glow)
    g.line(poly + [poly[0]], fill=EDGE + (200,), width=glow_px + 2)
    glow = glow.filter(ImageFilter.GaussianBlur(glow_px))
    im = Image.alpha_composite(im, glow)
    line = Image.new("RGBA", (w, h), (0, 0, 0, 0)); l = ImageDraw.Draw(line)
    l.line(poly + [poly[0]], fill=(225, 190, 255, 255), width=2)
    # brighter accents on the two cut corners
    l.line([(cut, 0), (0, cut)], fill=(255, 240, 255, 255), width=3)
    l.line([(w - 1, h - cut), (w - cut, h - 1)], fill=(255, 240, 255, 255), width=3)
    return Image.alpha_composite(im, line)

frame(512, 128, 18, 165, 4, True).save(os.path.join(OUT, "hud_panel.tga"))
frame(256, 48, 10, 150, 3, False).save(os.path.join(OUT, "hud_chip.tga"))

w, h, s = 256, 24, 10
bar = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(bar)
d.polygon([(s, 0), (w - 1, 0), (w - 1 - s, h - 1), (0, h - 1)], fill=(255, 255, 255, 235))
px = bar.load()
for y in range(h):
    k = 1.0 - 0.45 * (y / (h - 1))                      # lighter on top
    hi = 1.25 if 3 <= y <= 6 else 1.0                   # highlight band
    for x in range(w):
        r, g, b, a = px[x, y]
        if a:
            v = min(255, int(255 * k * hi)); px[x, y] = (v, v, v, a)
for x in range(s + 18, w, 32):                           # facet notches
    d.line([(x, 0), (x - s, h - 1)], fill=(170, 170, 170, 235), width=1)
bar.save(os.path.join(OUT, "hud_bar.tga"))
print("hud textures ->", OUT)
