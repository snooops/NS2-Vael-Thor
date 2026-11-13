"""Texture of the Vael'Thor ready room sign model (vt_join_sign.model, build_join_sign.sh).
Layout (1024 x 256), mirroring the vanilla marine_join.dds:
  rows   0- 47  bright violet bar   -> bevels and sides of the letters (UV v 0.02-0.13, like vanilla)
  rows  64-255  dark violet fill    -> letter fronts / backs (vertical gradient + faint scanlines)
Usage: python3 make_sign_texture.py <ns2 install dir> <out.tga>"""
import sys, colorsys
from PIL import Image, ImageDraw

NS2, OUT = sys.argv[1], sys.argv[2]
W, H = 1024, 256
im = Image.new("RGB", (W, H), (0, 0, 0))
px = im.load()

# bar: the vanilla bar rows, hue-shifted cyan -> violet (keeps its soft vertical glow profile)
vanilla = Image.open(NS2 + "/ns2/models/props/generic/marine_join.dds").convert("RGB")
vpx = vanilla.load()
for y in range(0, 48):
    for x in range(W):
        r, g, b = vpx[x, y]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        r2, g2, b2 = colorsys.hsv_to_rgb((h + 85 / 360) % 1, s, min(1, v * 1.15))
        px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255))

# letter faces: dark violet, a little brighter towards the top, faint horizontal scanlines
for y in range(64, H):
    t = (y - 64) / (H - 64)
    k = 1.0 - 0.45 * t
    line = 0.85 if y % 6 == 0 else 1.0
    c = (int(58 * k * line), int(24 * k * line), int(96 * k * line))
    for x in range(W):
        px[x, y] = c

im.save(OUT)
print("texture ->", OUT)
