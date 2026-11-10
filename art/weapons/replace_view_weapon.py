"""Replace the weapon geometry of a vanilla first-person view model, keeping arms/skeleton/animations byte-exact.

Usage: python3 replace_view_weapon.py <vanilla_view.model> <faceset_index> <tris.json> <bone_name> <material_path> <out.model>
tris.json: [[{"p":[x,y,z], "n":[x,y,z], "uv":[u,v], "bone"?: name} x3], ...] in NS2 model space. Every new vertex is
rigidly bound to its "bone" (default <bone_name>). The replaced face set must be the last one and own a contiguous vertex block at the end of the
vertex chunk (true for the marine view models); those vertices are dropped. Winding is matched to the vanilla
face set (cross(b-a, c-a) . normal sign). Vertex layout (92 B): pos3 normal3 tangent3 binormal3 uv2 u32 colour,
4 x (f32 weight, u32 palette index).
"""
import sys, os, json, struct, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_model import chunks, read_bones

SRC, FS, TRIS, BONE, MAT, OUT = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
d = open(SRC, "rb").read(); ch = chunks(d)
order = []
o = 4
while o + 8 <= len(d):
    cid, sz = struct.unpack_from("<II", d, o); order.append(cid); o += 8 + sz
bones, _, _ = read_bones(SRC)
bone_index = [b["name"] for b in bones].index(BONE)

# face sets
s, _ = ch[3]; n = struct.unpack_from("<I", d, s)[0]; o = s + 4; facesets = []
for _ in range(n):
    mat, first, count, nb = struct.unpack_from("<4I", d, o); o += 16
    pal = list(struct.unpack_from(f"<{nb}I", d, o)); o += 4 * nb
    facesets.append(dict(material=mat, first=first, count=count, palette=pal))
assert FS == len(facesets) - 1, "replaced face set must be the last one"
s, _ = ch[2]; ni = struct.unpack_from("<I", d, s)[0]; idx = list(struct.unpack_from(f"<{ni}I", d, s + 4))
s1, _ = ch[1]; nv = struct.unpack_from("<I", d, s1)[0]
V = lambda i: d[s1 + 4 + 92 * i: s1 + 4 + 92 * (i + 1)]
fs = facesets[FS]
used = sorted({v for t in range(fs["first"], fs["first"] + fs["count"]) for v in idx[3 * t:3 * t + 3]})
keep_n = used[0]
assert used == list(range(keep_n, nv)), "weapon vertices are not one block at the end"
assert all(v < keep_n for t in range(fs["first"]) for v in idx[3 * t:3 * t + 3]), "earlier face sets use weapon verts"

def wind_sign(a, b, c, nrm):
    e1 = [b[k] - a[k] for k in range(3)]; e2 = [c[k] - a[k] for k in range(3)]
    cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    return sum(cr[k] * nrm[k] for k in range(3))
t0 = fs["first"]; a, b, c = idx[3 * t0:3 * t0 + 3]
fv = lambda i: struct.unpack_from("<6f", V(i))
want_positive = wind_sign(fv(a)[:3], fv(b)[:3], fv(c)[:3], fv(a)[3:6]) > 0

def tangent_frame(nrm):
    n = nrm; ref = (0, 1, 0) if abs(n[1]) < 0.9 else (1, 0, 0)
    t = (ref[1] * n[2] - ref[2] * n[1], ref[2] * n[0] - ref[0] * n[2], ref[0] * n[1] - ref[1] * n[0])
    l = math.sqrt(sum(x * x for x in t)) or 1; t = tuple(x / l for x in t)
    bt = (n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0])
    return t, bt

tris = json.load(open(TRIS))
palette = []
for tri in tris:
    for v in tri:
        bn = v.get("bone", BONE)
        if bn not in palette: palette.append(bn)
pal_index = {bn: i for i, bn in enumerate(palette)}
pal_bones = [[b["name"] for b in bones].index(bn) for bn in palette]
new_verts = bytearray(); new_idx = []
for tri in tris:
    if (wind_sign(tri[0]["p"], tri[1]["p"], tri[2]["p"], tri[0]["n"]) > 0) != want_positive:
        tri = [tri[0], tri[2], tri[1]]
    for v in tri:
        t, bt = tangent_frame(v["n"])
        new_verts += struct.pack("<14fI", *v["p"], *v["n"], *t, *bt, *v["uv"], 0xFFFFFFFF)
        new_verts += struct.pack("<fIfIfIfI", 1.0, pal_index[v.get("bone", BONE)], 0.0, 0, 0.0, 0, 0.0, 0)
        new_idx.append(keep_n + len(new_idx))

out_chunks = {}
out_chunks[1] = struct.pack("<I", keep_n + len(new_idx)) + d[s1 + 4: s1 + 4 + 92 * keep_n] + bytes(new_verts)
all_idx = idx[:3 * fs["first"]] + new_idx
out_chunks[2] = struct.pack("<I", len(all_idx)) + struct.pack(f"<{len(all_idx)}I", *all_idx)
fs.update(count=len(new_idx) // 3, palette=pal_bones)
b3 = struct.pack("<I", len(facesets))
for f in facesets:
    b3 += struct.pack("<4I", f["material"], f["first"], f["count"], len(f["palette"])) + struct.pack(f"<{len(f['palette'])}I", *f["palette"])
out_chunks[3] = b3
s, _ = ch[4]; nm = struct.unpack_from("<I", d, s)[0]; o = s + 4; mats = []
for _ in range(nm):
    ln = struct.unpack_from("<I", d, o)[0]; o += 4; mats.append(d[o:o + ln].decode("latin1")); o += ln
mats[fs["material"]] = MAT
out_chunks[4] = struct.pack("<I", len(mats)) + b"".join(struct.pack("<I", len(m)) + m.encode("latin1") for m in mats)

out = bytearray(d[:4])
for cid in order:
    body = out_chunks.get(cid)
    if body is None:
        st, sz = ch[cid]; body = d[st:st + sz]
    out += struct.pack("<II", cid, len(body)) + body
open(OUT, "wb").write(out)
print(f"replaced face set {FS}: {fs['count']} tris on {palette}, {keep_n} vanilla verts kept, materials {mats}")
