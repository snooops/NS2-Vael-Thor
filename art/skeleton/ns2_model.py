"""Minimal reader for NS2 Spark .model files (MDL v7): chunk table + bone chunk (id 6)."""
import struct, sys

def chunks(d):
    assert d[:3] == b"MDL", "not a Spark model"
    o, ch = 4, {}
    while o + 8 <= len(d):
        cid, sz = struct.unpack_from("<II", d, o); ch[cid] = (o + 8, sz); o += 8 + sz
    return ch

def read_bones(path, nfloats=15):
    d = open(path, "rb").read(); ch = chunks(d)
    s, sz = ch[6]; o = s
    n = struct.unpack_from("<I", d, o)[0]; o += 4
    bones = []
    for _ in range(n):
        ln = struct.unpack_from("<I", d, o)[0]; o += 4
        name = d[o:o + ln].decode("latin1"); o += ln
        parent = struct.unpack_from("<i", d, o)[0]; o += 4
        f = struct.unpack_from(f"<{nfloats}f", d, o); o += 4 * nfloats
        bones.append(dict(name=name, parent=parent, f=f))
    return bones, o - s, sz

if __name__ == "__main__":
    bones, used, sz = read_bones(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 15)
    print("bones", len(bones), "used", used, "chunk", sz)
    for i, b in enumerate(bones):
        print(i, b["name"], b["parent"], " ".join(f"{x:.3f}" for x in b["f"]))


def read_mesh(path):
    """Returns verts [(pos, normal, uv, [(boneIndex, weight)...])], tris [(a,b,c)], facesets."""
    d = open(path, "rb").read(); ch = chunks(d)
    s, sz = ch[3]; o = s
    n = struct.unpack_from("<I", d, o)[0]; o += 4
    facesets = []
    for _ in range(n):
        mat, first, count, nb = struct.unpack_from("<4I", d, o); o += 16
        pal = struct.unpack_from(f"<{nb}I", d, o); o += 4 * nb
        facesets.append(dict(material=mat, first=first, count=count, palette=pal))
    s, sz = ch[2]
    ni = struct.unpack_from("<I", d, s)[0]
    idx = struct.unpack_from(f"<{ni}I", d, s + 4)
    s, sz = ch[1]
    nv = struct.unpack_from("<I", d, s)[0]
    raw = []
    for i in range(nv):
        b = s + 4 + 92 * i
        f = struct.unpack_from("<14f", d, b)
        inf = []
        for k in range(4):
            w, bi = struct.unpack_from("<fI", d, b + 60 + 8 * k)
            if w > 0: inf.append((bi, w))
        raw.append((f[0:3], f[3:6], f[12:14], inf))
    # palette indices are local to each face set: resolve per vertex via the face sets that use it
    verts = [None] * nv
    tris = []
    for fs in facesets:
        for t in range(fs["first"], fs["first"] + fs["count"]):
            tri = idx[3 * t:3 * t + 3]; tris.append((tri, fs["material"]))
            for vi in tri:
                if verts[vi] is None:
                    p, nrm, uv, inf = raw[vi]
                    verts[vi] = (p, nrm, uv, [(fs["palette"][bi], w) for bi, w in inf])
    for i, v in enumerate(verts):
        if v is None: verts[i] = (raw[i][0], raw[i][1], raw[i][2], [])
    return verts, tris, facesets


def read_materials(path):
    d = open(path, "rb").read(); ch = chunks(d)
    s, sz = ch[4]; o = s
    n = struct.unpack_from("<I", d, o)[0]; o += 4
    out = []
    for _ in range(n):
        ln = struct.unpack_from("<I", d, o)[0]; o += 4
        out.append(d[o:o + ln].decode("latin1")); o += ln
    return out
