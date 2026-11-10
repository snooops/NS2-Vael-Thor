"""Vael'Thor commander icons: vanilla ui/buildmenu.dds (12 columns x 16 rows of 80 px) plus five rows of
original Vael'Thor icons in the vanilla style (shaded greyscale metal on transparency, lit from the top left),
with violet crystal accents. Usage: python3 make_command_icons.py <vanilla_buildmenu.png> <out.tga> [preview.png]

The cell table (ICONS, in order) is mirrored in source/lua/VaelThor/Hooks/TechTreeButtons.lua: icon i sits at
column i % 12, row 16 + i // 12. Every vanilla icon keeps its pixel position (consumers address cells in pixels).
"""
import sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SRC, OUT = sys.argv[1], sys.argv[2]
PREVIEW = sys.argv[3] if len(sys.argv) > 3 else None
SS = 4
S = 80 * SS                       # drawing size of one cell
COLS, VANILLA_ROWS, NEW_ROWS = 12, 16, 5

VIOLET = (170, 90, 255)
VIOLET_DARK = (70, 25, 130)


# ---------------------------------------------------------------- primitives
def U(v):
    return v * S


def pts(seq):
    return [(U(x), U(y)) for x, y in seq]


def ngon(n, r, cx=0.5, cy=0.5, rot=0.0, sy=1.0):
    return [(cx + r * math.cos(rot + 2 * math.pi * k / n), cy + sy * r * math.sin(rot + 2 * math.pi * k / n))
            for k in range(n)]


class Icon:
    """Layers: metal (greyscale shaded), crystal (violet), glow; composited at the end."""

    def __init__(self):
        self.metal = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.crystal = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # metal shape with a vertical light gradient, dark outline and a top-left highlight edge
    def metal_poly(self, seq, shade=1.0, outline=True):
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).polygon(pts(seq), fill=255)
        self._metal(mask, shade, outline)

    def metal_ellipse(self, cx, cy, rx, ry, shade=1.0, outline=True):
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).ellipse([U(cx - rx), U(cy - ry), U(cx + rx), U(cy + ry)], fill=255)
        self._metal(mask, shade, outline)

    def metal_line(self, a, b, w, shade=1.0):
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).line([(U(a[0]), U(a[1])), (U(b[0]), U(b[1]))], fill=255, width=int(U(w)))
        self._metal(mask, shade, True)

    def _metal(self, mask, shade, outline):
        grad = Image.linear_gradient("L").resize((S, S)).point(lambda v: int((235 - v * 0.55) * shade))
        body = Image.merge("RGBA", (grad, grad, grad, mask))
        if outline:
            edge = mask.filter(ImageFilter.MaxFilter(9)).point(lambda v: 255 if v else 0)
            ring = Image.new("RGBA", (S, S), (25, 25, 30, 0)); ring.putalpha(edge)
            self.metal.alpha_composite(ring)
        self.metal.alpha_composite(body)
        # rim light on the top-left edges
        shifted = ImageChops.offset(mask, 6, 6)
        rim = ImageChops.subtract(mask, shifted).point(lambda v: int(v * 0.8))
        light = Image.new("RGBA", (S, S), (255, 255, 255, 0)); light.putalpha(rim)
        self.metal.alpha_composite(light)

    # violet faceted crystal (bipyramid in 2D: kite) with a light facet
    def crystal_kite(self, cx, cy, w, h_up, h_down):
        d = ImageDraw.Draw(self.crystal)
        top, right, bot, left = (cx, cy - h_up), (cx + w, cy), (cx, cy + h_down), (cx - w, cy)
        d.polygon(pts([top, right, bot, left]), fill=VIOLET + (255,), outline=(40, 10, 80, 255), width=SS * 2)
        d.polygon(pts([top, (cx, cy), left]), fill=(215, 175, 255, 255))
        d.polygon(pts([(cx, cy), right, bot]), fill=VIOLET_DARK + (255,))

    def crystal_poly(self, seq, light=False):
        d = ImageDraw.Draw(self.crystal)
        d.polygon(pts(seq), fill=((205, 160, 255, 255) if light else VIOLET + (255,)), outline=(40, 10, 80, 255),
                  width=SS * 2)

    def crystal_line(self, a, b, w):
        ImageDraw.Draw(self.crystal).line([(U(a[0]), U(a[1])), (U(b[0]), U(b[1]))], fill=VIOLET + (255,),
                                          width=int(U(w)))

    def crystal_ring(self, cx, cy, r, w, sy=1.0):
        ImageDraw.Draw(self.crystal).ellipse([U(cx - r), U(cy - r * sy), U(cx + r), U(cy + r * sy)],
                                             outline=VIOLET + (255,), width=int(U(w)))

    def render(self):
        glow = self.crystal.split()[3].filter(ImageFilter.GaussianBlur(U(0.035))).point(lambda v: int(v * 0.8))
        halo = Image.new("RGBA", (S, S), VIOLET + (0,)); halo.putalpha(glow)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.alpha_composite(self.metal)
        out.alpha_composite(halo)
        out.alpha_composite(self.crystal)
        return out.resize((80, 80), Image.LANCZOS)


# ---------------------------------------------------------------- shared pieces
def base_plate(ic, cy=0.82, rx=0.36, ry=0.08, sides=8):
    ic.metal_poly(ngon(sides, rx, 0.5, cy, math.pi / sides, ry / rx), 0.75)
    ic.metal_poly(ngon(sides, rx * 0.8, 0.5, cy - 0.04, math.pi / sides, ry / rx), 0.95)


def plus_badge(ic, sign):
    ic.metal_ellipse(0.80, 0.80, 0.14, 0.14, 0.55)
    ic.crystal_line((0.71, 0.80), (0.89, 0.80), 0.05)
    if sign > 0:
        ic.crystal_line((0.80, 0.71), (0.80, 0.89), 0.05)


def level_pips(ic, n):
    for i in range(3):
        x = 0.30 + i * 0.20
        if i < n:
            ic.crystal_kite(x, 0.88, 0.06, 0.07, 0.07)
        else:
            ic.metal_ellipse(x, 0.88, 0.035, 0.035, 0.5)


# ---------------------------------------------------------------- structures
def nexus(ic):
    base_plate(ic, 0.84, 0.42, 0.10)
    for x, lean in ((0.22, 0.06), (0.78, -0.06), (0.36, 0.03), (0.64, -0.03)):
        ic.metal_poly([(x - 0.05, 0.80), (x + 0.05, 0.80), (x + 0.04 + lean, 0.30), (x - 0.04 + lean, 0.30)],
                      0.9 if abs(lean) > 0.04 else 0.7)
    ic.crystal_kite(0.5, 0.45, 0.13, 0.33, 0.20)
    ic.crystal_ring(0.5, 0.30, 0.22, 0.025, 0.3)


def siphon(ic):
    base_plate(ic, 0.86, 0.38, 0.08, 6)
    for a, b in (((0.18, 0.84), (0.42, 0.30)), ((0.82, 0.84), (0.58, 0.30)), ((0.50, 0.86), (0.50, 0.32))):
        ic.metal_line(a, b, 0.07, 0.85)
    ic.metal_poly(ngon(8, 0.20, 0.5, 0.28, math.pi / 8, 0.35), 1.0)
    ic.crystal_kite(0.5, 0.20, 0.07, 0.15, 0.04)
    ic.crystal_poly([(0.27, 0.58), (0.35, 0.58), (0.35, 0.78), (0.27, 0.78)])


def pylon(ic):
    base_plate(ic, 0.86, 0.26, 0.06, 6)
    for x, lean in ((0.32, -0.05), (0.68, 0.05), (0.5, 0.0)):
        ic.metal_poly([(x - 0.04, 0.84), (x + 0.04, 0.84), (x + 0.025 + lean, 0.42), (x - 0.025 + lean, 0.42)],
                      0.85 if lean else 0.65)
    ic.crystal_kite(0.5, 0.26, 0.13, 0.20, 0.20)
    ic.crystal_kite(0.22, 0.18, 0.04, 0.06, 0.05)
    ic.crystal_kite(0.80, 0.24, 0.04, 0.06, 0.05)


def chamber(ic):
    base_plate(ic, 0.86, 0.38, 0.08)
    ic.crystal_poly([(0.34, 0.30), (0.66, 0.30), (0.66, 0.78), (0.34, 0.78)])
    ic.crystal_poly([(0.38, 0.32), (0.46, 0.32), (0.46, 0.76), (0.38, 0.76)], light=True)
    for x in (0.28, 0.72):
        ic.metal_poly([(x - 0.04, 0.82), (x + 0.04, 0.82), (x + 0.03, 0.26), (x - 0.03, 0.26)], 0.9)
    ic.metal_poly(ngon(8, 0.25, 0.5, 0.24, math.pi / 8, 0.35), 1.0)
    ic.crystal_kite(0.5, 0.14, 0.04, 0.08, 0.02)


def shield_generator(ic):
    base_plate(ic, 0.84, 0.42, 0.09, 6)
    ic.metal_poly([(0.46, 0.80), (0.54, 0.80), (0.52, 0.42), (0.48, 0.42)], 0.8)
    ic.crystal_kite(0.5, 0.38, 0.07, 0.10, 0.06)
    for k in range(5):                                   # lattice dome arcs
        a0 = 180 + k * 36
        ImageDraw.Draw(ic.crystal).arc([U(0.14), U(0.24), U(0.86), U(1.18)], 180, 360, fill=VIOLET + (255,),
                                       width=int(U(0.025)))
        ImageDraw.Draw(ic.crystal).line([(U(0.5), U(0.24)), (U(0.5 + 0.36 * math.cos(math.radians(a0))),
                                          U(0.71 + 0.47 * math.sin(math.radians(a0))))], fill=VIOLET + (255,),
                                        width=int(U(0.02)))


def obelisk(ic):
    base_plate(ic, 0.88, 0.24, 0.06)
    ic.metal_poly([(0.40, 0.86), (0.60, 0.86), (0.55, 0.30), (0.45, 0.30)], 0.95)
    ic.crystal_line((0.5, 0.82), (0.5, 0.36), 0.025)
    for x in (0.38, 0.62, 0.5):
        ic.metal_line((0.5, 0.32), (x, 0.10), 0.035, 0.8)
    ic.crystal_kite(0.5, 0.20, 0.07, 0.10, 0.08)


def rift_portal(ic):
    base_plate(ic, 0.86, 0.42, 0.09, 6)
    ic.metal_poly(ngon(8, 0.30, 0.5, 0.48, math.pi / 8), 0.9)
    ic.crystal_poly(ngon(8, 0.23, 0.5, 0.48, math.pi / 8))
    ic.crystal_poly(ngon(8, 0.12, 0.44, 0.42, math.pi / 8), light=True)
    for x in (0.12, 0.88):
        ic.metal_poly([(x - 0.05, 0.84), (x + 0.05, 0.84), (x + 0.04, 0.40), (x - 0.04, 0.40)], 0.8)


def spire(ic):
    base_plate(ic, 0.88, 0.30, 0.07)
    y, w = 0.82, 0.16
    for i in range(6):
        ic.metal_poly([(0.5 - w, y), (0.5 + w, y), (0.5 + w * 0.85, y - 0.09), (0.5 - w * 0.85, y - 0.09)],
                      0.95 if i % 2 == 0 else 0.6)
        ic.crystal_line((0.5 - w * 0.9, y - 0.005), (0.5 + w * 0.9, y - 0.005), 0.012)
        y -= 0.09; w *= 0.86
    ic.crystal_kite(0.5, y - 0.04, 0.07, 0.14, 0.04)


def nexus_gate(ic):
    nexus(ic)
    ic.crystal_ring(0.5, 0.52, 0.40, 0.03, 0.55)


# ---------------------------------------------------------------- castes (busts)
def bust(ic, shoulders, helm_shade=1.0):
    ic.metal_poly([(0.5 - shoulders, 0.92), (0.5 + shoulders, 0.92), (0.5 + shoulders * 0.85, 0.66),
                   (0.62, 0.56), (0.38, 0.56), (0.5 - shoulders * 0.85, 0.66)], 0.8)
    ic.metal_poly(ngon(8, 0.16, 0.5, 0.40, math.pi / 8, 1.15), helm_shade)
    ic.crystal_poly([(0.40, 0.38), (0.60, 0.38), (0.56, 0.44), (0.44, 0.44)])   # visor


def vanguard(ic):
    bust(ic, 0.30)
    ic.metal_poly([(0.62, 0.70), (0.95, 0.62), (0.95, 0.70), (0.64, 0.78)], 1.0)  # carbine
    ic.crystal_line((0.70, 0.70), (0.92, 0.65), 0.02)


def infiltrator(ic):
    bust(ic, 0.22, 0.7)
    for side in (-1, 1):
        ic.crystal_poly([(0.5 + side * 0.20, 0.86), (0.5 + side * 0.44, 0.40), (0.5 + side * 0.26, 0.82)], light=side > 0)


def subject(ic):
    bust(ic, 0.36, 0.8)
    for side in (-1, 1):
        for k in range(3):
            x = 0.5 + side * (0.30 + k * 0.05)
            ic.crystal_line((x, 0.80), (x + side * 0.10, 0.56 + k * 0.03), 0.025)


def praetor(ic):
    ic.metal_poly([(0.10, 0.94), (0.90, 0.94), (0.86, 0.56), (0.66, 0.44), (0.34, 0.44), (0.14, 0.56)], 0.75)
    ic.metal_poly(ngon(8, 0.13, 0.5, 0.36, math.pi / 8, 1.1), 1.0)
    ic.crystal_poly([(0.42, 0.34), (0.58, 0.34), (0.55, 0.40), (0.45, 0.40)])
    for x in (0.12, 0.88):
        ic.metal_poly([(x - 0.07, 0.94), (x + 0.07, 0.94), (x + 0.05, 0.52), (x - 0.05, 0.52)], 1.0)
        ic.crystal_kite(x, 0.50, 0.04, 0.05, 0.04)
    ic.crystal_kite(0.5, 0.70, 0.07, 0.09, 0.07)


def quota(caste_fn, sign):
    def fn(ic):
        caste_fn(ic)
        plus_badge(ic, sign)
    return fn


def quota_menu(ic):
    for i, x in enumerate((0.28, 0.5, 0.72)):
        ic.metal_poly(ngon(8, 0.10, x, 0.40 + (0.06 if i != 1 else 0), math.pi / 8, 1.1), 0.9 if i == 1 else 0.7)
        ic.metal_poly([(x - 0.14, 0.86), (x + 0.14, 0.86), (x + 0.10, 0.58), (x - 0.10, 0.58)], 0.8 if i == 1 else 0.6)
    ic.crystal_line((0.18, 0.92), (0.82, 0.92), 0.03)


# ---------------------------------------------------------------- edicts / commander abilities
def requisition(ic):
    ic.crystal_kite(0.40, 0.58, 0.18, 0.26, 0.26)
    ic.metal_poly([(0.72, 0.84), (0.84, 0.84), (0.84, 0.40), (0.92, 0.40), (0.78, 0.18), (0.64, 0.40), (0.72, 0.40)], 1.0)


def relentless(ic):
    for i, x in enumerate((0.20, 0.42, 0.64)):
        seq = [(x, 0.22), (x + 0.20, 0.50), (x, 0.78), (x - 0.08, 0.78), (x + 0.12, 0.50), (x - 0.08, 0.22)]
        if i == 2:
            ic.crystal_poly(seq)
        else:
            ic.metal_poly(seq, 0.7 + 0.15 * i)


def shield_shape(cx=0.5, cy=0.5, w=0.30, h=0.40):
    return [(cx - w, cy - h * 0.7), (cx, cy - h), (cx + w, cy - h * 0.7), (cx + w * 0.9, cy + h * 0.2),
            (cx, cy + h), (cx - w * 0.9, cy + h * 0.2)]


def iron_discipline(ic):
    ic.metal_poly(shield_shape(), 0.9)
    for y in (0.38, 0.50, 0.62):
        ic.metal_poly([(0.34, y), (0.66, y), (0.64, y + 0.06), (0.36, y + 0.06)], 0.55)
    ic.crystal_kite(0.5, 0.24, 0.06, 0.06, 0.06)


def shield_pulse(ic):
    for r, w in ((0.42, 0.025), (0.32, 0.03), (0.22, 0.035)):
        ic.crystal_ring(0.5, 0.5, r, w)
    ic.metal_poly(shield_shape(0.5, 0.5, 0.14, 0.18), 1.0)


def rift_recall(ic):
    ic.metal_poly(ngon(8, 0.22, 0.62, 0.50, math.pi / 8), 0.9)
    ic.crystal_poly(ngon(8, 0.16, 0.62, 0.50, math.pi / 8))
    ic.metal_poly([(0.06, 0.44), (0.30, 0.44), (0.30, 0.34), (0.48, 0.50), (0.30, 0.66), (0.30, 0.56), (0.06, 0.56)], 1.0)


# ---------------------------------------------------------------- research / upgrades
def tier(n):
    def fn(ic):
        ic.metal_poly(shield_shape(0.5, 0.48, 0.34, 0.40), 0.6)
        for i in range(n):
            x = 0.5 + (i - (n - 1) / 2) * 0.20
            ic.crystal_kite(x, 0.46, 0.08, 0.16, 0.16)
    return fn


def overcharge(ic):
    ic.crystal_kite(0.5, 0.5, 0.26, 0.38, 0.38)
    # the bolt sits on the crystal layer (metal is always drawn below crystal)
    ImageDraw.Draw(ic.crystal).polygon(pts([(0.56, 0.16), (0.36, 0.54), (0.50, 0.54), (0.42, 0.86), (0.66, 0.42),
                                            (0.52, 0.42)]), fill=(250, 240, 255, 255), outline=(40, 10, 80, 255),
                                       width=SS * 2)


def singularity(ic):
    for k in range(4):
        a0 = k * 90
        ImageDraw.Draw(ic.crystal).arc([U(0.14), U(0.14), U(0.86), U(0.86)], a0, a0 + 60, fill=VIOLET + (255,),
                                       width=int(U(0.06)))
        ImageDraw.Draw(ic.crystal).arc([U(0.28), U(0.28), U(0.72), U(0.72)], a0 + 45, a0 + 100,
                                       fill=(205, 160, 255, 255), width=int(U(0.05)))
    ic.metal_ellipse(0.5, 0.5, 0.10, 0.10, 0.3)


def phase_dash(ic):
    for i, (x, a) in enumerate(((0.26, 0.35), (0.42, 0.6), (0.62, 1.0))):
        seq = [(x - 0.12, 0.30), (x + 0.10, 0.30), (x + 0.18, 0.50), (x + 0.10, 0.70), (x - 0.12, 0.70), (x - 0.04, 0.50)]
        if i == 2:
            ic.metal_poly(seq, 1.0)
        else:
            ic.crystal_poly(seq, light=i == 1)


def shield_overdrive(ic):
    ic.metal_poly(shield_shape(0.42, 0.52, 0.28, 0.36), 0.9)
    ic.crystal_poly(shield_shape(0.42, 0.52, 0.16, 0.22))
    for y in (0.22, 0.42):
        ic.crystal_poly([(0.70, y + 0.16), (0.82, y), (0.94, y + 0.16), (0.88, y + 0.16), (0.82, y + 0.08), (0.76, y + 0.16)],
                        light=True)


def targeting_visor(ic):
    ic.metal_poly([(0.10, 0.40), (0.90, 0.40), (0.84, 0.62), (0.16, 0.62)], 0.9)
    ic.crystal_poly([(0.18, 0.44), (0.82, 0.44), (0.78, 0.58), (0.22, 0.58)])
    ic.crystal_ring(0.5, 0.51, 0.08, 0.02)
    for a, b in (((0.5, 0.22), (0.5, 0.36)), ((0.5, 0.66), (0.5, 0.80))):
        ic.metal_line(a, b, 0.03, 1.0)


def phase_cloak(ic):
    bust(ic, 0.26, 0.7)
    fade = ic.metal.split()
    ic.metal.putalpha(fade[3].point(lambda v: int(v * 0.45)))
    ic.crystal_ring(0.5, 0.55, 0.40, 0.025, 1.0)


def neural_override(ic):
    ic.metal_ellipse(0.5, 0.48, 0.30, 0.26, 0.8)
    ic.metal_line((0.5, 0.24), (0.5, 0.72), 0.02, 0.4)
    for (a, b) in (((0.30, 0.40), (0.44, 0.40)), ((0.56, 0.56), (0.70, 0.56)), ((0.36, 0.60), (0.44, 0.52))):
        ic.crystal_line(a, b, 0.025)
    ic.crystal_kite(0.78, 0.78, 0.08, 0.12, 0.10)
    ic.metal_line((0.66, 0.66), (0.74, 0.72), 0.03, 1.0)


def psionic_edicts(ic):
    ic.metal_poly([(0.24, 0.20), (0.76, 0.20), (0.72, 0.84), (0.28, 0.84)], 0.9)
    for y in (0.36, 0.48, 0.60):
        ic.metal_line((0.34, y), (0.66, y), 0.02, 0.45)
    ic.crystal_kite(0.5, 0.20, 0.10, 0.12, 0.08)


def archons_throne(ic):
    base_plate(ic, 0.88, 0.36, 0.07)
    ic.metal_poly([(0.30, 0.82), (0.70, 0.82), (0.70, 0.62), (0.30, 0.62)], 0.8)              # seat
    ic.metal_poly([(0.32, 0.62), (0.68, 0.62), (0.62, 0.18), (0.38, 0.18)], 1.0)              # back
    ic.crystal_kite(0.5, 0.14, 0.08, 0.10, 0.06)
    for x in (0.26, 0.74):
        ic.metal_poly([(x - 0.04, 0.82), (x + 0.04, 0.82), (x + 0.03, 0.56), (x - 0.03, 0.56)], 0.7)


def resonant_pylon(ic):
    pylon(ic)
    ic.crystal_ring(0.5, 0.30, 0.34, 0.02, 0.4)
    ic.crystal_ring(0.5, 0.30, 0.44, 0.015, 0.4)


def aegis_array(ic):
    shield_generator(ic)
    ic.metal_poly(shield_shape(0.80, 0.30, 0.13, 0.17), 1.0)


def plasma_calibration(n):
    def fn(ic):
        ic.metal_poly([(0.10, 0.44), (0.80, 0.36), (0.90, 0.40), (0.90, 0.50), (0.40, 0.56), (0.30, 0.70),
                       (0.20, 0.70), (0.24, 0.54), (0.10, 0.54)], 1.0)
        ic.crystal_line((0.30, 0.46), (0.84, 0.42), 0.03)
        level_pips(ic, n)
    return fn


def shield_matrix(n):
    def fn(ic):
        ic.metal_poly(shield_shape(0.5, 0.44, 0.30, 0.36), 0.85)
        ic.crystal_poly(shield_shape(0.5, 0.44, 0.20, 0.25))
        ic.crystal_poly(shield_shape(0.46, 0.40, 0.08, 0.10), light=True)
        level_pips(ic, n)
    return fn


# ---------------------------------------------------------------- weapons / tools
def plasma_carbine(ic):
    plasma_calibration(0)(ic)


def psionic_blade(ic):
    ic.metal_poly([(0.16, 0.84), (0.30, 0.70), (0.38, 0.78), (0.24, 0.92)], 0.8)
    ic.crystal_poly([(0.30, 0.70), (0.86, 0.10), (0.40, 0.78)])
    ic.crystal_poly([(0.34, 0.70), (0.80, 0.18), (0.36, 0.74)], light=True)


def subject_claws(ic):
    ic.metal_ellipse(0.32, 0.72, 0.18, 0.14, 0.8)
    for k in range(3):
        y = 0.50 + k * 0.10
        ic.crystal_poly([(0.40, y + 0.02), (0.88, y - 0.24 + k * 0.04), (0.44, y + 0.08)])


def psionic_knife(ic):
    ic.metal_poly([(0.20, 0.80), (0.34, 0.66), (0.42, 0.74), (0.28, 0.88)], 0.7)
    ic.metal_poly([(0.30, 0.62), (0.46, 0.78), (0.42, 0.82), (0.26, 0.66)], 1.0)
    ic.metal_poly([(0.36, 0.68), (0.84, 0.20), (0.44, 0.76)], 1.0)
    ic.crystal_line((0.40, 0.70), (0.80, 0.26), 0.02)


def singularity_launcher(ic):
    ic.metal_poly([(0.08, 0.48), (0.70, 0.40), (0.70, 0.62), (0.40, 0.66), (0.30, 0.80), (0.20, 0.80), (0.22, 0.62),
                   (0.08, 0.60)], 1.0)
    ic.crystal_ring(0.80, 0.50, 0.14, 0.03)
    ic.crystal_kite(0.80, 0.50, 0.05, 0.06, 0.06)


def echo_pulse(ic):
    ic.metal_poly([(0.16, 0.30), (0.48, 0.30), (0.48, 0.80), (0.16, 0.80)], 0.9)
    ic.crystal_poly([(0.21, 0.36), (0.43, 0.36), (0.43, 0.62), (0.21, 0.62)])
    for r in (0.20, 0.32, 0.44):
        ImageDraw.Draw(ic.crystal).arc([U(0.48 - r), U(0.55 - r), U(0.48 + r), U(0.55 + r)], -40, 40,
                                       fill=VIOLET + (255,), width=int(U(0.03)))


# ---------------------------------------------------------------- Sentinel Obelisk beams
def obelisk_head(ic, cx=0.22, cy=0.28):
    """small obelisk at the left: shaft, prongs and the crystal the beams leave from"""
    ic.metal_poly([(cx - 0.08, 0.92), (cx + 0.08, 0.92), (cx + 0.05, cy + 0.10), (cx - 0.05, cy + 0.10)], 0.95)
    for dx in (-0.08, 0.08):
        ic.metal_line((cx, cy + 0.10), (cx + dx, cy - 0.10), 0.03, 0.8)
    ic.crystal_kite(cx, cy, 0.06, 0.09, 0.07)


def beams(n):
    ends = {1: [(0.90, 0.50)], 2: [(0.90, 0.30), (0.90, 0.72)], 3: [(0.90, 0.20), (0.90, 0.50), (0.90, 0.80)]}[n]
    def fn(ic):
        obelisk_head(ic)
        width = {1: 0.07, 2: 0.045, 3: 0.032}[n]     # thinner beams = less damage each
        for e in ends:
            ic.crystal_line((0.24, 0.28), e, width)
            ic.metal_ellipse(e[0], e[1], 0.05, 0.05, 0.7)
    return fn


def obelisk_focus(ic):
    obelisk_head(ic)
    ic.crystal_line((0.24, 0.28), (0.70, 0.62), 0.05)
    ic.crystal_ring(0.70, 0.62, 0.20, 0.025)
    for a, b in (((0.70, 0.36), (0.70, 0.46)), ((0.70, 0.78), (0.70, 0.88)),
                 ((0.44, 0.62), (0.54, 0.62)), ((0.86, 0.62), (0.96, 0.62))):
        ic.metal_line(a, b, 0.035, 1.0)


def obelisk_lens(n):
    def fn(ic):
        obelisk(ic)
        # facetted lens in front of the head, one pip per beam it allows
        ic.crystal_poly(ngon(6, 0.13, 0.78, 0.30, 0.0), light=True)
        ic.crystal_ring(0.78, 0.30, 0.17, 0.02)
        level_pips(ic, n)
    return fn


# order = atlas cells (mirrored in Hooks/TechTreeButtons.lua kVTIconCells)
ICONS = [
    ("VTNexus", nexus), ("VTSiphon", siphon), ("VTSubventionPylon", pylon), ("VTSynthesisChamber", chamber),
    ("VTShieldGenerator", shield_generator), ("VTSentinelObelisk", obelisk), ("VTRiftPortal", rift_portal),
    ("VTPsionicSpire", spire), ("VTNexusGate", nexus_gate), ("VTNexusGateUpgrade", nexus_gate),
    ("VTResonantPylonUpgrade", resonant_pylon), ("VTAegisArrayUpgrade", aegis_array),

    ("VTVanguard", vanguard), ("VTInfiltrator", infiltrator), ("VTSubject", subject), ("VTPraetor", praetor),
    ("VTQuotaMenu", quota_menu),
    ("VTQuotaInfiltratorUp", quota(infiltrator, 1)), ("VTQuotaInfiltratorDown", quota(infiltrator, -1)),
    ("VTQuotaSubjectUp", quota(subject, 1)), ("VTQuotaSubjectDown", quota(subject, -1)),
    ("VTQuotaPraetorUp", quota(praetor, 1)), ("VTQuotaPraetorDown", quota(praetor, -1)),
    ("VTArchonsThrone", archons_throne),

    ("VTEdictRequisition", requisition), ("VTEdictRelentless", relentless), ("VTEdictIronDiscipline", iron_discipline),
    ("VTShieldPulse", shield_pulse), ("VTRiftRecall", rift_recall),
    ("VTAuthorizationTier2", tier(2)), ("VTAuthorizationTier3", tier(3)), ("VTOverchargeTech", overcharge),
    ("VTSingularityTech", singularity), ("VTPhaseDashTech", phase_dash), ("VTShieldOverdriveTech", shield_overdrive),
    ("VTTargetingVisorTech", targeting_visor),

    ("VTPhaseCloakTech", phase_cloak), ("VTNeuralOverrideTech", neural_override),
    ("VTPsionicEdictsTech", psionic_edicts),
    ("Weapons1", plasma_calibration(1)), ("Weapons2", plasma_calibration(2)), ("Weapons3", plasma_calibration(3)),
    ("Armor1", shield_matrix(1)), ("Armor2", shield_matrix(2)), ("Armor3", shield_matrix(3)),
    ("VTPlasmaCarbine", plasma_carbine), ("VTPsionicBlade", psionic_blade), ("VTSubjectClaws", subject_claws),

    ("VTPsionicKnife", psionic_knife), ("VTSingularityLauncher", singularity_launcher), ("VTEchoPulse", echo_pulse),
    ("VTObeliskPrismUpgrade", obelisk_lens(2)), ("VTObeliskTrinityUpgrade", obelisk_lens(3)),
    ("VTObeliskFocus", obelisk_focus),
    ("VTObeliskBeams1", beams(1)), ("VTObeliskBeams2", beams(2)), ("VTObeliskBeams3", beams(3)),
]

if __name__ == "__main__":
    vanilla = Image.open(SRC).convert("RGBA")
    assert vanilla.size == (COLS * 80, VANILLA_ROWS * 80), vanilla.size
    atlas = Image.new("RGBA", (COLS * 80, (VANILLA_ROWS + NEW_ROWS) * 80), (0, 0, 0, 0))
    atlas.paste(vanilla, (0, 0))
    assert len(ICONS) <= COLS * NEW_ROWS
    for i, (name, fn) in enumerate(ICONS):
        ic = Icon(); fn(ic)
        atlas.paste(ic.render(), ((i % COLS) * 80, (VANILLA_ROWS + i // COLS) * 80))
    atlas.save(OUT)
    print("atlas ->", OUT, atlas.size, len(ICONS), "icons")
    with open(OUT.rsplit(".", 1)[0] + "_cells.txt", "w") as f:
        for i, (name, _) in enumerate(ICONS):
            f.write("%s %d %d\n" % (name, i % COLS, VANILLA_ROWS + i // COLS))
    if PREVIEW:
        part = atlas.crop((0, VANILLA_ROWS * 80, COLS * 80, (VANILLA_ROWS + NEW_ROWS) * 80))
        bg = Image.new("RGBA", part.size, (38, 40, 48, 255)); bg.alpha_composite(part)
        bg.save(PREVIEW)
