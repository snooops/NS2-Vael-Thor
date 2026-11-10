"""First-person preview: vanilla arm face set vs new arms (json), flat shaded, perspective from the eye."""
import sys, os, json, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "skeleton"))
from ns2_model import read_mesh
from PIL import Image, ImageDraw
VIEW, ARMS, EYE_Y, OUT = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
W, H, F = 640, 480, 520
AXIS = 0   # set per pass: 0 = front (x, y), 1 = side (z, y)
def proj(p):
    u = p[0] if AXIS == 0 else p[2]
    return (W / 2 + 560 * u, H / 2 - 560 * (p[1] - EYE_Y + 0.55))
def render(tris, colour):
    img = Image.new("RGB", (W, H), (40, 44, 52)); dr = ImageDraw.Draw(img)
    L = (0.3, 0.8, -0.5); l = math.sqrt(sum(x * x for x in L)); L = [x / l for x in L]
    items = []
    for a, b, c in tris:
        pa, pb, pc = proj(a), proj(b), proj(c)
        if not (pa and pb and pc): continue
        e1 = [b[i] - a[i] for i in range(3)]; e2 = [c[i] - a[i] for i in range(3)]
        nn = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]
        ln = math.sqrt(sum(x * x for x in nn)) or 1
        sh = 0.35 + 0.65 * abs(sum(nn[i] / ln * L[i] for i in range(3)))
        depth = (a[2] + b[2] + c[2]) / 3 if AXIS == 0 else -(a[0] + b[0] + c[0]) / 3
        items.append((depth, [pa, pb, pc], tuple(int(k * sh) for k in colour)))
    for _, pts, col in sorted(items, key=lambda x: -x[0]):
        dr.polygon(pts, fill=col)
    return img
verts, tris, fs = read_mesh(VIEW)
van = [[verts[v][0] for v in t] for t, m in tris[:fs[0]["count"]]]
arms = json.load(open(ARMS)); new = [[arms["verts"][v]["p"] for v in t] for t in arms["tris"]]
out = Image.new("RGB", (W * 2, H * 2))
for row, ax in enumerate((0, 1)):
    AXIS = ax
    out.paste(render(van, (200, 170, 140)), (0, row * H)); out.paste(render(new, (190, 200, 225)), (W, row * H))
out.save(OUT)
