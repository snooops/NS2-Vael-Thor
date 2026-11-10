"""Append a rigidly skinned mesh as a new face set (+ material) to a compiled NS2 model, everything else untouched.

Usage: python3 append_faceset.py <in.model> <tris.json> <material_path> <out.model>
tris.json as for replace_view_weapon.py, every vertex needs a "bone". Winding follows the model's first face set.
Used to put the Infiltrator's wrist blades into cyber_player.model (shown/hidden in Lua via a material override).
"""
import sys, os, json, struct, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_model import chunks, read_bones

SRC, TRIS, MAT, OUT = sys.argv[1:5]
d = open(SRC, "rb").read(); ch = chunks(d)
order = []; o = 4
while o + 8 <= len(d):
    cid, sz = struct.unpack_from("<II", d, o); order.append(cid); o += 8 + sz
bones, _, _ = read_bones(SRC); bnames = [b["name"] for b in bones]
s, _ = ch[3]; n = struct.unpack_from("<I", d, s)[0]; o = s + 4; facesets = []
for _ in range(n):
    mat, first, count, nb = struct.unpack_from("<4I", d, o); o += 16
    pal = list(struct.unpack_from(f"<{nb}I", d, o)); o += 4 * nb
    facesets.append(dict(material=mat, first=first, count=count, palette=pal))
s2, _ = ch[2]; ni = struct.unpack_from("<I", d, s2)[0]; idx = list(struct.unpack_from(f"<{ni}I", d, s2 + 4))
s1, _ = ch[1]; nv = struct.unpack_from("<I", d, s1)[0]
fv = lambda i: struct.unpack_from("<6f", d, s1 + 4 + 92 * i)
def wind(a, b, c, n):
    e1 = [b[k] - a[k] for k in range(3)]; e2 = [c[k] - a[k] for k in range(3)]
    cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    return sum(cr[k] * n[k] for k in range(3))
a, b, c = idx[0:3]
want_positive = wind(fv(a)[:3], fv(b)[:3], fv(c)[:3], fv(a)[3:6]) > 0
def frame(n):
    ref = (0, 1, 0) if abs(n[1]) < 0.9 else (1, 0, 0)
    t = (ref[1] * n[2] - ref[2] * n[1], ref[2] * n[0] - ref[0] * n[2], ref[0] * n[1] - ref[1] * n[0])
    l = math.sqrt(sum(x * x for x in t)) or 1; t = tuple(x / l for x in t)
    return t, (n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0])
tris = json.load(open(TRIS))
palette = []
for tri in tris:
    for v in tri:
        if v["bone"] not in palette: palette.append(v["bone"])
pi = {bn: i for i, bn in enumerate(palette)}
new_verts = bytearray(); new_idx = []
for tri in tris:
    if (wind(tri[0]["p"], tri[1]["p"], tri[2]["p"], tri[0]["n"]) > 0) != want_positive:
        tri = [tri[0], tri[2], tri[1]]
    for v in tri:
        t, bt = frame(v["n"])
        new_verts += struct.pack("<14fI", *v["p"], *v["n"], *t, *bt, *v["uv"], 0xFFFFFFFF)
        new_verts += struct.pack("<fIfIfIfI", 1.0, pi[v["bone"]], 0.0, 0, 0.0, 0, 0.0, 0)
        new_idx.append(nv + len(new_idx))
s4, _ = ch[4]; nm = struct.unpack_from("<I", d, s4)[0]; o = s4 + 4; mats = []
for _ in range(nm):
    ln = struct.unpack_from("<I", d, o)[0]; o += 4; mats.append(d[o:o + ln].decode("latin1")); o += ln
mats.append(MAT)
facesets.append(dict(material=len(mats) - 1, first=ni // 3, count=len(new_idx) // 3, palette=[bnames.index(bn) for bn in palette]))
out_chunks = {
    1: struct.pack("<I", nv + len(new_idx)) + d[s1 + 4: s1 + 4 + 92 * nv] + bytes(new_verts),
    2: struct.pack("<I", ni + len(new_idx)) + struct.pack(f"<{ni + len(new_idx)}I", *(idx + new_idx)),
    3: struct.pack("<I", len(facesets)) + b"".join(struct.pack("<4I", f["material"], f["first"], f["count"], len(f["palette"]))
                                                    + struct.pack(f"<{len(f['palette'])}I", *f["palette"]) for f in facesets),
    4: struct.pack("<I", len(mats)) + b"".join(struct.pack("<I", len(m)) + m.encode("latin1") for m in mats),
}
out = bytearray(d[:4])
for cid in order:
    body = out_chunks.get(cid)
    if body is None:
        st, sz = ch[cid]; body = d[st:st + sz]
    out += struct.pack("<II", cid, len(body)) + body
open(OUT, "wb").write(out)
print(f"appended face set: {len(new_idx)//3} tris on {palette}, material #{len(mats)-1} {MAT}")
