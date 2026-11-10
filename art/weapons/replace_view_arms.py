"""Replace the arms (face set 0) of a first-person view model, keeping weapon, skeleton and animations byte-exact.

Usage: python3 replace_view_arms.py <view.model> <arms.json from build_view_arms.py> <material_path> <out.model>

The arm face set must be face set 0 and own one contiguous vertex block at the start of the vertex chunk (true
for every marine view model). The new arm vertices take that block; all other vertex indices and face set
triangle offsets are shifted. Vertex layout (92 B): pos3 normal3 tangent3 binormal3 uv2 u32 colour,
4 x (f32 weight, u32 face-set palette index).
"""
import sys, os, json, struct
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_model import chunks, read_bones

SRC, ARMS, MAT, OUT = sys.argv[1:5]
d = open(SRC, "rb").read(); ch = chunks(d)
order = []; o = 4
while o + 8 <= len(d):
    cid, sz = struct.unpack_from("<II", d, o); order.append(cid); o += 8 + sz
bone_names = [b["name"] for b in read_bones(SRC)[0]]

s, _ = ch[3]; n = struct.unpack_from("<I", d, s)[0]; o = s + 4; facesets = []
for _ in range(n):
    mat, first, count, nb = struct.unpack_from("<4I", d, o); o += 16
    pal = list(struct.unpack_from(f"<{nb}I", d, o)); o += 4 * nb
    facesets.append(dict(material=mat, first=first, count=count, palette=pal))
s, _ = ch[2]; ni = struct.unpack_from("<I", d, s)[0]; idx = list(struct.unpack_from(f"<{ni}I", d, s + 4))
s1, _ = ch[1]; nv = struct.unpack_from("<I", d, s1)[0]

fs0 = facesets[0]
assert fs0["first"] == 0, "arm face set must start at triangle 0"
used = sorted({v for t in range(fs0["count"]) for v in idx[3 * t:3 * t + 3]})
old_n = len(used)
assert used == list(range(old_n)), "arm vertices are not one block at the start"
rest_tris = range(fs0["count"], ni // 3)
assert all(v >= old_n for t in rest_tris for v in idx[3 * t:3 * t + 3]), "other face sets use arm vertices"

arms = json.load(open(ARMS))
new_n = len(arms["verts"]); new_t = len(arms["tris"])
palette = [bone_names.index(name) for name in arms["palette"]]

new_verts = bytearray()
for v in arms["verts"]:
    new_verts += struct.pack("<14fI", *v["p"], *v["n"], *v["t"], *v["b"], *v["uv"], 0xFFFFFFFF)
    w = v["w"] + [[0, 0.0]] * (4 - len(v["w"]))
    for pi, wt in w:
        new_verts += struct.pack("<fI", wt, pi)
assert len(new_verts) == 92 * new_n

dv = new_n - old_n; dt = new_t - fs0["count"]
out_chunks = {}
out_chunks[1] = struct.pack("<I", nv + dv) + bytes(new_verts) + d[s1 + 4 + 92 * old_n: s1 + 4 + 92 * nv]
all_idx = [i for tri in arms["tris"] for i in tri] + [i + dv for i in idx[3 * fs0["count"]:]]
out_chunks[2] = struct.pack("<I", len(all_idx)) + struct.pack(f"<{len(all_idx)}I", *all_idx)

s, _ = ch[4]; nm = struct.unpack_from("<I", d, s)[0]; o = s + 4; mats = []
for _ in range(nm):
    ln = struct.unpack_from("<I", d, o)[0]; o += 4; mats.append(d[o:o + ln].decode("latin1")); o += ln
mats[fs0["material"]] = MAT          # face set 0 owns its material slot (hands.material) in every view model
assert sum(1 for f in facesets if f["material"] == fs0["material"]) == 1, "arm material slot is shared"
out_chunks[4] = struct.pack("<I", len(mats)) + b"".join(struct.pack("<I", len(m)) + m.encode("latin1") for m in mats)

fs0.update(count=new_t, palette=palette)
for f in facesets[1:]:
    f["first"] += dt
b3 = struct.pack("<I", len(facesets))
for f in facesets:
    b3 += struct.pack("<4I", f["material"], f["first"], f["count"], len(f["palette"])) + struct.pack(f"<{len(f['palette'])}I", *f["palette"])
out_chunks[3] = b3

out = bytearray(d[:4])
for cid in order:
    body = out_chunks.get(cid)
    if body is None:
        st, sz = ch[cid]; body = d[st:st + sz]
    out += struct.pack("<II", cid, len(body)) + body
open(OUT, "wb").write(out)
print(f"REPLACED arms: {old_n} -> {new_n} verts, {fs0['count'] - dt} -> {new_t} tris, {len(palette)} bones, material {MAT} -> {OUT}")
