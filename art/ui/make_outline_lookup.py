"""Build the mod's ui/marine_outline_lookup.dds: the vanilla outline colour lookup
(TSFBlue, Green, Fuchsia, Yellow, Red[, Orange since the 2026-11-17 update], 64 px each) with the right half of the red band
turned into a red -> black gradient. Vanilla samples each band at its centre (red: x=288),
which stays untouched; bands after red (Orange) stay vanilla. The Echo Scan fade slides its "outline" parameter from the centre
to the band's end (see Client.lua, kEchoFadeU*). The outline composite is additive, so
black = invisible. Alpha stays 255 (alpha < 1 would fill the silhouette instead).

Usage: python3 make_outline_lookup.py <vanilla.dds> <out.tga>
"""
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
w, h = im.size
assert h == 8 and w % 64 == 0 and w >= 320, (w, h)     # 5 bands (320) before 2026-11-17, 6 (384) after
px = im.load()
START, END = 289, 319          # 288 = red band centre (kept), 319 = last texel (black)
for x in range(START, END + 1):
    k = 1 - (x - START + 1) / (END - START + 1)     # 1 -> 0
    for y in range(h):
        px[x, y] = (int(255 * k + 0.5), 0, 0, 255)
im.save(out)
print("wrote", out)
