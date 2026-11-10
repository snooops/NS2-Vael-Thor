"""Vael'Thor minimap atlas: the vanilla ui/minimap_blip.dds (8 x 8 cells of 32 px) plus two extra rows of
original top-down Vael'Thor icons, in the vanilla style (greyscale, tinted by team colour at runtime).
Usage: python3 make_minimap_atlas.py <vanilla_minimap_blip.png> <out.tga> [preview.png]

Row 9  (y 256-287): Nexus, Siphon, Pylon, Synthesis Chamber, Shield Generator, Sentinel Obelisk, Rift Portal, Spire
Row 10 (y 288-319): Vanguard, Infiltrator, Subject, Praetor   (player icons face right like vanilla's; the map
                    rotates them by the view direction)
Cells are addressed in pixels (GUIGetSprite), so the vanilla cells keep their coordinates. The atlas is
padded to 256 x 512 (power of two); rows 11-16 are free for later icons.
"""
import sys, math
from PIL import Image, ImageDraw, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
PREVIEW = sys.argv[3] if len(sys.argv) > 3 else None
SS = 4                     # supersampling
C = 32 * SS                # cell size while drawing

# greyscale palette (the map multiplies these by the team colour)
DARK, MID, BODY, LIGHT, BRIGHT = 55, 120, 175, 215, 255


def poly(n, r, cx=0.5, cy=0.5, rot=0.0):
    return [((cx + r * math.cos(rot + 2 * math.pi * k / n)) * C, (cy + r * math.sin(rot + 2 * math.pi * k / n)) * C)
            for k in range(n)]


def P(x, y):
    return (x * C, y * C)


def new():
    return Image.new("LA", (C, C), (0, 0)), None


def shape(d, pts, fill, outline=DARK, width=2):
    d.polygon(pts, fill=(fill, 255), outline=(outline, 255), width=width * SS // 2)


def circle(d, cx, cy, r, fill, outline=DARK, width=2):
    d.ellipse([(cx - r) * C, (cy - r) * C, (cx + r) * C, (cy + r) * C], fill=(fill, 255), outline=(outline, 255),
              width=width * SS // 2)


def diamond(d, cx, cy, rx, ry, fill=BRIGHT, outline=DARK):
    shape(d, [P(cx, cy - ry), P(cx + rx, cy), P(cx, cy + ry), P(cx - rx, cy)], fill, outline)


# ---------------------------------------------------------------- buildings (top-down)
def nexus(d):
    shape(d, poly(8, 0.47, rot=math.pi / 8), MID)
    shape(d, poly(8, 0.37, rot=math.pi / 8), BODY)
    for k in range(4):                                  # four leaning plates
        a = math.pi / 4 + k * math.pi / 2
        cx, cy = 0.5 + 0.24 * math.cos(a), 0.5 + 0.24 * math.sin(a)
        shape(d, poly(4, 0.09, cx, cy, a + math.pi / 4), LIGHT)
    circle(d, 0.5, 0.5, 0.19, MID)
    diamond(d, 0.5, 0.5, 0.11, 0.16)


def siphon(d):
    shape(d, poly(6, 0.45), MID)
    for k in range(3):                                  # three legs
        a = -math.pi / 2 + k * 2 * math.pi / 3
        x2, y2 = 0.5 + 0.40 * math.cos(a), 0.5 + 0.40 * math.sin(a)
        d.line([P(0.5, 0.5), P(x2, y2)], fill=(DARK, 255), width=7 * SS // 2)
        d.line([P(0.5, 0.5), P(x2, y2)], fill=(LIGHT, 255), width=4 * SS // 2)
    for k in range(2):                                  # storage tanks
        a = math.pi / 6 + k * math.pi
        circle(d, 0.5 + 0.26 * math.cos(a), 0.5 + 0.26 * math.sin(a), 0.08, BODY)
    shape(d, poly(8, 0.17, rot=math.pi / 8), LIGHT)
    diamond(d, 0.5, 0.5, 0.07, 0.07)


def pylon(d):
    shape(d, poly(6, 0.30), MID)
    for k in range(3):                                  # three fins
        a = -math.pi / 2 + k * 2 * math.pi / 3
        cx, cy = 0.5 + 0.28 * math.cos(a), 0.5 + 0.28 * math.sin(a)
        shape(d, poly(4, 0.10, cx, cy, a), LIGHT)
    diamond(d, 0.5, 0.5, 0.17, 0.22)                    # floating crystal, big from above
    d.line([P(0.5, 0.30), P(0.5, 0.70)], fill=(LIGHT, 255), width=SS)


def chamber(d):
    shape(d, poly(8, 0.46, rot=math.pi / 8), MID)
    for k in range(4):                                  # frame ribs
        a = math.pi / 4 + k * math.pi / 2
        circle(d, 0.5 + 0.30 * math.cos(a), 0.5 + 0.30 * math.sin(a), 0.07, LIGHT)
    circle(d, 0.5, 0.5, 0.25, BODY)                     # vat seen from above
    circle(d, 0.5, 0.5, 0.17, BRIGHT, outline=MID)
    diamond(d, 0.5, 0.5, 0.06, 0.06, fill=LIGHT)


def shield_generator(d):
    shape(d, poly(6, 0.47), MID)
    circle(d, 0.5, 0.5, 0.38, BODY)
    for k in range(6):                                  # lattice dome struts
        a = k * math.pi / 3
        d.line([P(0.5, 0.5), P(0.5 + 0.38 * math.cos(a), 0.5 + 0.38 * math.sin(a))], fill=(BRIGHT, 255), width=2 * SS)
    d.polygon(poly(6, 0.22, rot=math.pi / 6), outline=(BRIGHT, 255), width=2 * SS)
    diamond(d, 0.5, 0.5, 0.08, 0.08)


def obelisk(d):
    shape(d, poly(8, 0.36, rot=math.pi / 8), MID)
    shape(d, poly(4, 0.25), BODY)                       # four-sided shaft from above
    for k in range(3):                                  # turret prongs
        a = -math.pi / 2 + k * 2 * math.pi / 3
        x, y = 0.5 + 0.30 * math.cos(a), 0.5 + 0.30 * math.sin(a)
        d.line([P(0.5, 0.5), P(x, y)], fill=(LIGHT, 255), width=3 * SS)
    circle(d, 0.5, 0.5, 0.11, BRIGHT)


def rift_portal(d):
    shape(d, poly(6, 0.46), MID)
    shape(d, poly(6, 0.34), BODY)
    shape(d, [P(0.18, 0.43), P(0.82, 0.43), P(0.82, 0.57), P(0.18, 0.57)], LIGHT)   # gate ring seen edge-on
    shape(d, [P(0.24, 0.47), P(0.76, 0.47), P(0.76, 0.53), P(0.24, 0.53)], BRIGHT, outline=BRIGHT, width=1)
    for x in (0.12, 0.88):
        circle(d, x, 0.5, 0.07, LIGHT)                  # pillars


def spire(d):
    r = 0.46
    for i, shade in enumerate((MID, BODY, LIGHT, BODY, LIGHT)):       # stacked, twisting segments
        shape(d, poly(6 if i else 8, r, rot=i * 0.3), shade)
        r *= 0.78
    diamond(d, 0.5, 0.5, 0.07, 0.09)


# ---------------------------------------------------------------- castes (top-down, facing right)
def soldier(d, shoulder, weapon):
    circle(d, 0.44, 0.5, shoulder, BODY)                                # shoulders / torso
    shape(d, [P(0.30, 0.5 - shoulder * 0.8), P(0.52, 0.5 - shoulder * 0.9), P(0.52, 0.5 + shoulder * 0.9),
              P(0.30, 0.5 + shoulder * 0.8)], LIGHT)                    # chest plate
    weapon(d)
    circle(d, 0.47, 0.5, 0.09, BRIGHT)                                  # helmet / visor


def vanguard(d):
    def rifle(d):
        shape(d, [P(0.45, 0.58), P(0.93, 0.58), P(0.93, 0.66), P(0.45, 0.68)], MID)
        shape(d, [P(0.80, 0.59), P(0.95, 0.60), P(0.95, 0.64), P(0.80, 0.65)], BRIGHT, outline=MID, width=1)
    soldier(d, 0.22, rifle)


def infiltrator(d):
    def blades(d):
        for y in (0.30, 0.70):
            shape(d, [P(0.50, y - 0.03), P(0.94, y), P(0.50, y + 0.03)], BRIGHT, outline=MID, width=1)
    soldier(d, 0.17, blades)


def subject(d):
    def claws(d):
        for y in (0.24, 0.76):
            for dy in (-0.05, 0.0, 0.05):
                d.line([P(0.58, y + dy), P(0.86, y + dy * 1.6)], fill=(BRIGHT, 255), width=2 * SS)
            circle(d, 0.56, y, 0.07, MID)
    soldier(d, 0.25, claws)


def praetor(d):
    circle(d, 0.42, 0.5, 0.30, MID)                                     # heavy chassis
    shape(d, poly(8, 0.24, 0.42, 0.5, math.pi / 8), BODY)
    for y in (0.20, 0.80):                                              # twin plasma miniguns
        shape(d, [P(0.40, y - 0.07), P(0.95, y - 0.05), P(0.95, y + 0.05), P(0.40, y + 0.07)], LIGHT)
        circle(d, 0.92, y, 0.04, BRIGHT, outline=MID, width=1)
    diamond(d, 0.46, 0.5, 0.09, 0.12)                                   # crystal core


ROW9 = [nexus, siphon, pylon, chamber, shield_generator, obelisk, rift_portal, spire]
ROW10 = [vanguard, infiltrator, subject, praetor]

vanilla = Image.open(SRC).convert("RGBA")
atlas = Image.new("RGBA", (256, 512), (0, 0, 0, 0))     # power of two; rows 11-16 stay free
atlas.paste(vanilla, (0, 0))
for row, fns in ((8, ROW9), (9, ROW10)):
    for col, fn in enumerate(fns):
        cell = Image.new("LA", (C, C), (0, 0))
        fn(ImageDraw.Draw(cell))
        cell = cell.convert("RGBA").resize((32, 32), Image.LANCZOS)
        atlas.paste(cell, (col * 32, row * 32))
atlas.save(OUT)
print("atlas ->", OUT, atlas.size)

if PREVIEW:
    tint = Image.new("RGBA", atlas.size, (60, 70, 80, 255))
    r, g, b, a = atlas.split()
    violet = Image.merge("RGBA", (r.point(lambda v: v * 0.80), g.point(lambda v: v * 0.55), b, a))
    tint.alpha_composite(violet)
    tint.crop((0, 224, 256, 320)).resize((768, 288), Image.NEAREST).save(PREVIEW)
