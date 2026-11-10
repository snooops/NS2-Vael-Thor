"""Turn the PBR bakes (albedo/metallic/roughness/normal) into NS2 maps (TGA, then nvcompress -> DDS).

NS2 marine.surface_shader: albedoMap rgb, specularMap rgb=spec colour a=gloss, normalMap xyz, emissiveMap rgb.
Cyan light strips are detected in the albedo and recoloured to Vael'Thor purple (albedo + emissive).
Usage: python3 make_ns2_textures.py <art_dir> <out_dir> [prefix=robot] [glow=cyan|purple|teal|orange|accent] [paint=none|orange]
  cyan: detect cyan strips and recolour them purple; purple: detect existing purple strips, keep colour
  teal: detect teal strips of any brightness by hue (Cyber Sentinel), recolour purple at the same
        brightness; only the bright parts glow
  orange: same as teal for orange accents (Mecha Sentinel visor/seams); dull copper stays as is
  accent: any saturated colour (on an otherwise grey model, e.g. the Falcon rifle) -> purple glow
  paint=orange: additionally repaint saturated orange panels deep Vael'Thor purple, NOT emissive
        (Titan Sentinel's orange paint); applied after the glow pass
"""
import sys, os
import numpy as np
from PIL import Image

ART, OUT = sys.argv[1], sys.argv[2]
PREFIX = sys.argv[3] if len(sys.argv) > 3 else "robot"
GLOW = sys.argv[4] if len(sys.argv) > 4 else "cyan"
PAINT = sys.argv[5] if len(sys.argv) > 5 else "none"
PAINT_PURPLE = np.array([0.42, 0.16, 0.72])
os.makedirs(OUT, exist_ok=True)
PURPLE = np.array([0.62, 0.22, 1.0])

def load(name, mode="RGB"):
    return np.asarray(Image.open(os.path.join(ART, name)).convert(mode)).astype(np.float32) / 255.0

alb = load("bake_albedo.png")
met = load("bake_metallic.png", "L")
rough = load("bake_roughness.png", "L")
nrm = load("bake_normal.png")

# glow mask: bright, blue-dominant, saturated (the cyan strips)
r, g, b = alb[..., 0], alb[..., 1], alb[..., 2]
mx = alb.max(-1); mn = alb.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-4)
if GLOW == "purple":
    glow = np.clip((b - 0.35) / 0.15, 0, 1) * np.clip((r - 0.2) / 0.1, 0, 1) * np.clip((np.minimum(r, b) - g - 0.15) / 0.1, 0, 1)
elif GLOW == "teal":
    glow = np.clip(((np.minimum(g, b) - r) - 0.10) / 0.08, 0, 1) * np.clip((sat - 0.35) / 0.10, 0, 1)
elif GLOW == "accent":
    glow = np.clip((sat - 0.40) / 0.10, 0, 1) * np.clip((mx - 0.20) / 0.10, 0, 1)
elif GLOW == "orange":
    glow = np.clip(((r - b) - 0.25) / 0.08, 0, 1) * np.clip((r - g) / 0.05 + 0.5, 0, 1) * np.clip((sat - 0.50) / 0.08, 0, 1)
else:
    glow = np.clip(((b - r) - 0.11) / 0.06, 0, 1) * np.clip((g - 0.85) / 0.08, 0, 1) * np.clip((sat - 0.08) / 0.06, 0, 1)
glow = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(1.5))).astype(np.float32) / 255
print("glow coverage %.2f%%" % (100 * (glow > 0.3).mean()))
g3 = glow[..., None]
lum = alb.mean(-1, keepdims=True)

# albedo: darken metals (metal colour lives in spec), recolour strips purple
albedo = alb * (1 - 0.75 * met[..., None])
HUE_MODES = ("teal", "orange", "accent")  # recolour at original brightness, glow only where bright
if GLOW in HUE_MODES:
    albedo = albedo * (1 - g3) + PURPLE * mx[..., None] * g3
elif GLOW != "purple":
    albedo = albedo * (1 - g3) + (PURPLE * np.clip(lum * 1.3, 0.3, 1)) * g3
if PAINT == "orange":
    paint = np.clip(((r - b) - 0.25) / 0.08, 0, 1) * np.clip((r - g) / 0.05 + 0.5, 0, 1) * np.clip((sat - 0.45) / 0.08, 0, 1)
    paint = paint * (1 - glow)
    print("paint coverage %.2f%%" % (100 * (paint > 0.3).mean()))
    p3 = paint[..., None]
    albedo = albedo * (1 - p3) + PAINT_PURPLE * mx[..., None] * p3
# spec: dielectric 0.04 -> albedo colour for metals; gloss = 1 - roughness
spec = 0.04 * (1 - met[..., None]) + alb * met[..., None]
spec = spec * (1 - g3) + 0.3 * g3
gloss = np.clip(1 - rough, 0, 1)
# emissive: purple strips only
emis = (alb * 1.2 if GLOW == "purple" else PURPLE) * g3
if GLOW in HUE_MODES:  # dark accent panels stay unlit, bright strips glow
    emis = emis * np.clip((mx - 0.35) / 0.4, 0, 1)[..., None]

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
