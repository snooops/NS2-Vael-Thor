"""Tripo PBR maps -> NS2 marine.surface_shader maps for Vael'Thor buildings.
Usage: python3 make_building_textures.py <basecolor> <rm> <normal> <out_dir> <prefix> [size=2048]

Tripo 'rm': R unused (occlusion = 1), G = roughness, B = metallic (under-reported: silver ~0.23).
  * metallic: boosted on the neutral silver / gunmetal plating (low saturation), violet stays dielectric
  * gloss (spec alpha) = 1 - roughness, softened a little (Tripo's ~0.03 roughness reads as a mirror)
  * emissive: violet panels and the vat glow softly, the bright magenta seams glow fully
Outputs <prefix>.tga, <prefix>_spec.tga (rgb spec, a gloss), <prefix>_normal.tga, <prefix>_illum.tga.
"""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

BASE, RM, NRM, OUT, PREFIX = sys.argv[1:6]
SIZE = int(sys.argv[6]) if len(sys.argv) > 6 else 2048
os.makedirs(OUT, exist_ok=True)


def load(path, mode="RGB"):
    im = Image.open(path).convert(mode).resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


alb = load(BASE)
rm = load(RM)
nrm = load(NRM)
rough, met = rm[..., 1], rm[..., 2]

r, g, b = alb[..., 0], alb[..., 1], alb[..., 2]
mx, mn = alb.max(-1), alb.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-4)

violet = np.clip(((np.minimum(r, b) - g) - 0.12) / 0.10, 0, 1) * np.clip((sat - 0.30) / 0.10, 0, 1)
# seams are pink-magenta (red ~ blue), the panels lean blue: separate them by hue, then brightness
seam = violet * np.clip((r - b + 0.06) / 0.06, 0, 1) * np.clip((mx - 0.72) / 0.10, 0, 1)
neutral = np.clip((0.20 - sat) / 0.08, 0, 1)                      # silver + gunmetal plating


def blur(a, px=1.5):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(px))).astype(np.float32) / 255.0


violet, seam = blur(violet), blur(seam)
print("violet %.1f%%  seams %.1f%%  neutral %.1f%%" % (100 * (violet > 0.3).mean(), 100 * (seam > 0.3).mean(),
                                                       100 * (neutral > 0.5).mean()))

metal = np.clip(np.maximum(met * 1.5, 0.85 * neutral), 0, 1) * (1 - violet)
m3 = metal[..., None]
albedo = alb * (1 - 0.45 * m3)                                    # metal colour mostly lives in the spec map
spec = 0.04 * (1 - m3) + alb * m3
gloss = np.clip(1 - (0.18 + rough * 1.5), 0.25, 0.85)
glow = np.clip(0.22 * violet + 0.9 * seam, 0, 1)[..., None]
emis = alb * glow


def save(arr, name, alpha=None):
    a = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    if alpha is not None:
        a = np.dstack([a, (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)])
    Image.fromarray(a).save(os.path.join(OUT, name))
    print("wrote", name)


save(albedo, f"{PREFIX}.tga")
save(spec, f"{PREFIX}_spec.tga", gloss)
save(nrm, f"{PREFIX}_normal.tga")
save(emis, f"{PREFIX}_illum.tga")
