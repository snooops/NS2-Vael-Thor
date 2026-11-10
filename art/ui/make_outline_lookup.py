"""Build the mod's ui/marine_outline_lookup.dds: the vanilla 5-band outline colour lookup
(TSFBlue, Green, Fuchsia, Yellow, Red, 64 px each) with the right half of the red band
turned into a red -> black gradient. Vanilla samples each band at its centre (red: x=288),
which stays untouched; the Echo Scan fade slides its "outline" parameter from the centre
to the band's end (see Client.lua, kEchoFadeU*). The outline composite is additive, so
black = invisible. Alpha stays 255 (alpha < 1 would fill the silhouette instead).

Usage: python3 make_outline_lookup.py <vanilla.dds> <out.tga>
"""
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
w, h = im.size
assert (w, h) == (320, 8), (w, h)
px = im.load()
START, END = 289, 319          # 288 = red band centre (kept), 319 = last texel (black)
for x in range(START, END + 1):
    k = 1 - (x - START + 1) / (END - START + 1)     # 1 -> 0
    for y in range(h):
        px[x, y] = (int(255 * k + 0.5), 0, 0, 255)
im.save(out)
print("wrote", out)
