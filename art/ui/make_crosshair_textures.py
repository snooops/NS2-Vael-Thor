"""Vael'Thor crosshair atlas (psionic crystal style): white shapes with a soft glow, tinted in Lua.
Usage: python3 make_crosshair_textures.py <out.tga>

512x512 atlas, 4x4 cells of 128 px (cell = col, row). Each shape is centred in its cell.
Nothing is rotated at runtime (the GUI rotation direction is not verified), so every orientation
a design needs has its own cell.
  (0,0) dot            soft core + glow
  (1,0) pip            small faceted diamond (energy / ammo / range pips)
  (2,0) ring           thin full circle (spread circle)
  (3,0) vortex         dashed ring with spiral hooks (spinning is direction-agnostic)
  (0,1) shard_down     crystal shard, tip pointing down   (placed above the centre)
  (1,1) shard_up       tip pointing up                    (placed below)
  (2,1) shard_right    tip pointing right                 (placed left)
  (3,1) shard_left     tip pointing left                  (placed right)
  (0,2) crescent_l     "(" psi blade                      (placed left)
  (1,2) crescent_r     ")" psi blade                      (placed right)
  (2,2) claws          three curved claw slashes
  (3,2) chevron_up     "^" dagger tip                     (placed below)
  (0,3) corner_tl  (1,3) corner_tr  (2,3) corner_bl  (3,3) corner_br   faceted bracket corners
"""
import sys, math
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
SS = 4                      # supersampling
C = 128 * SS                # cell size at supersampled resolution
atlas = Image.new("RGBA", (512 * SS, 512 * SS), (0, 0, 0, 0))


def cell(col, row, draw_fn, glow=10, glow_alpha=0.55):
    """draw_fn(draw, cx, cy) paints white shapes on a cell-sized mask; adds a blurred glow below."""
    mask = Image.new("L", (C, C), 0)
    draw_fn(ImageDraw.Draw(mask), C / 2, C / 2)
    halo = mask.filter(ImageFilter.GaussianBlur(glow * SS)).point(lambda v: int(min(255, v * 2.2) * glow_alpha))
    alpha = halo
    alpha = Image.composite(Image.new("L", (C, C), 255), alpha, mask)       # core over halo
    img = Image.merge("RGBA", (Image.new("L", (C, C), 255),) * 3 + (alpha,))
    atlas.paste(img, (col * C, row * C))


def S(v):
    return v * SS


def poly(d, pts, cx, cy):
    d.polygon([(cx + S(x), cy + S(y)) for x, y in pts], fill=255)


# ---- (0,0) dot
cell(0, 0, lambda d, cx, cy: d.ellipse([cx - S(9), cy - S(9), cx + S(9), cy + S(9)], fill=255), glow=12, glow_alpha=0.7)

# ---- (1,0) pip: faceted diamond
cell(1, 0, lambda d, cx, cy: poly(d, [(0, -16), (11, 0), (0, 16), (-11, 0)], cx, cy), glow=8)


# ---- (2,0) ring
def ring(d, cx, cy):
    r = S(54)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=255, width=S(3))
cell(2, 0, ring, glow=5, glow_alpha=0.45)


# ---- (3,0) vortex: 6 dashes, each ending in an inward hook
def vortex(d, cx, cy):
    r = S(50)
    for k in range(6):
        a0 = k * 60
        d.arc([cx - r, cy - r, cx + r, cy + r], a0, a0 + 34, fill=255, width=S(5))
        a = math.radians(a0 + 34)
        x1, y1 = cx + r * math.cos(a), cy + r * math.sin(a)
        x2, y2 = cx + (r - S(14)) * math.cos(a + 0.22), cy + (r - S(14)) * math.sin(a + 0.22)
        d.line([(x1, y1), (x2, y2)], fill=255, width=S(4))
cell(3, 0, vortex, glow=6)

# ---- shards: long faceted crystal, tip toward the centre of the crosshair
SHARD = [(0, 40), (9, 6), (5, -40), (-5, -40), (-9, 6)]          # tip at +y (down)
def rot(pts, k):   # k * 90 degrees, clockwise in screen space
    for _ in range(k):
        pts = [(-y, x) for x, y in pts]
    return pts
cell(0, 1, lambda d, cx, cy: poly(d, SHARD, cx, cy))                  # tip down
cell(1, 1, lambda d, cx, cy: poly(d, rot(SHARD, 2), cx, cy))          # tip up
cell(2, 1, lambda d, cx, cy: poly(d, rot(SHARD, 3), cx, cy))          # tip right
cell(3, 1, lambda d, cx, cy: poly(d, rot(SHARD, 1), cx, cy))          # tip left


# ---- crescents: psi blade arcs with sharp ends, bulging away from the centre
def crescent(mirror):
    def fn(d, cx, cy):
        ys = [-50 + 100 * i / 30 for i in range(31)]
        outer = [(-6 - 26 * (1 - (y / 50) ** 2), y) for y in ys]
        inner = [(-6 - 12 * (1 - (y / 50) ** 2), y) for y in reversed(ys)]
        shape = [(x + 16, y) for x, y in outer + inner]
        if mirror:
            shape = [(-x, y) for x, y in shape]
        poly(d, shape, cx, cy)
    return fn
cell(0, 2, crescent(False))
cell(1, 2, crescent(True))


# ---- (2,2) claws: three curved, tapered slashes, top-right -> bottom-left
def claws(d, cx, cy):
    nx, ny = 0.707, 0.707                       # normal of the slash direction (-1, 1)
    for off in (-22, 0, 22):
        side_a, side_b = [], []
        for i in range(21):
            t = i / 20
            x = 34 - 68 * t + off * 0.707
            y = -44 + 88 * t + off * 0.707
            bow = 9 * math.sin(math.pi * t)     # curve toward the lower right
            w = 1.0 + 5.5 * math.sin(math.pi * t)
            side_a.append((x + (bow + w) * nx, y + (bow + w) * ny))
            side_b.append((x + (bow - w) * nx, y + (bow - w) * ny))
        k = 0.78                                # keep the glow inside the cell
        poly(d, [(x * k, y * k) for x, y in side_a + list(reversed(side_b))], cx, cy)
cell(2, 2, claws, glow=9)

# ---- (3,2) chevron_up: dagger tip
cell(3, 2, lambda d, cx, cy: poly(d, [(0, -30), (34, 18), (22, 26), (0, -4), (-22, 26), (-34, 18)], cx, cy))


# ---- corners: faceted L brackets, the corner of the bracket at the outer corner
def corner(k):
    base = [(-44, -44), (20, -44), (14, -36), (-36, -36), (-36, 14), (-44, 20)]   # top-left
    def fn(d, cx, cy):
        pts = base
        if k in (1, 3):
            pts = [(-x, y) for x, y in pts]
        if k in (2, 3):
            pts = [(x, -y) for x, y in pts]
        poly(d, pts, cx, cy)
    return fn
for k in range(4):
    cell(k, 3, corner(k))

atlas = atlas.resize((512, 512), Image.LANCZOS)
atlas.save(OUT)
print("crosshair atlas ->", OUT)
