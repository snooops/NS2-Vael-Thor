"""Falcon texture -> the bake_* inputs make_ns2_textures.py expects (the glTF only has a base colour).
Paints the solid patches falcon_common.PATCH_UV points at: dark grey (Material__2) and purple (the emissive
cyan strip, Material__1_ncl1_1; the 'accent' glow pass then lights it). Flat metallic/roughness/normal.
Usage: python3 make_falcon_bakes.py <baseColor.jpeg> <out_dir>
"""
import sys, os
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert("RGB")
assert im.size == (1024, 1024), im.size
px = im.load()
for (cx, cy), col in (((730, 70), (29, 29, 29)), ((830, 70), (158, 56, 255))):
    for x in range(cx - 30, cx + 30):
        for y in range(cy - 30, cy + 30):
            px[x, y] = col
im.save(os.path.join(out, "bake_albedo.png"))
Image.new("L", im.size, 110).save(os.path.join(out, "bake_metallic.png"))
Image.new("L", im.size, 120).save(os.path.join(out, "bake_roughness.png"))
Image.new("RGB", im.size, (128, 128, 255)).save(os.path.join(out, "bake_normal.png"))
print("bakes written to", out)
