"""Vael'Thor commander HUD textures: the marine commander textures with their cyan/blue hues (150-250 deg)
shifted to violet (~285 deg); saturation, brightness, alpha and layout stay identical, so every pixel
coordinate the vanilla GUI scripts use still fits.
Usage: python3 make_commander_theme.py <vanilla_ui_dir> <out_dir> <name> [<name> ...]   (names without .dds)
"""
import sys, os
import numpy as np
from PIL import Image

SRC, OUT, NAMES = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(OUT, exist_ok=True)

def shift(img):
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    m = d > 1e-5
    rm, gm, bm = m & (mx == r), m & (mx == g) & (mx != r), m & (mx == b) & (mx != r) & (mx != g)
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    h = h * 60.0
    s = np.where(mx > 1e-5, d / np.maximum(mx, 1e-5), 0)
    v = mx
    sel = (h >= 150) & (h <= 250) & (s > 0.12)
    h2 = np.where(sel, 285.0 + (h - 200.0) * 0.25, h)
    s2 = np.where(sel, np.minimum(1.0, s * 1.05), s)
    # HSV -> RGB
    c = v * s2
    hp = (h2 / 60.0) % 6
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(c)
    conds = [(hp < 1), (hp < 2), (hp < 3), (hp < 4), (hp < 5), (hp < 6)]
    choices = [np.stack(t, -1) for t in ((c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x))]
    out = np.select([np.stack([k] * 3, -1) for k in conds], choices) + (v - c)[..., None]
    out = np.where(sel[..., None], out, rgb)
    res = np.concatenate([out, alpha], -1)
    print("  shifted %.1f%% of pixels" % (100 * sel.mean()))
    return Image.fromarray((np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")

for name in NAMES:
    img = Image.open(os.path.join(SRC, name + ".dds"))
    print(name, img.size)
    shift(img).save(os.path.join(OUT, name + ".tga"))
