"""Make the collision solids of a freshly compiled building model bone-relative.

Usage: python3 fix_solid_space.py <model> [<model> ...]       (run ONCE right after CompileModel)

The engine places a collision solid at  bone_world * solid_matrix  (vanilla convention: arms_lab's footings only
land mirrored left/right that way). For our static buildings CompileModel writes solid_matrix already in model
space, while the root bone carries a bind rotation (quat 0.707, 0.707, 0, 0 from the Blender/FBX bone axes), so
in-game every hitbox was rotated onto its side (height along +x, half under the floor). This rewrites each
solid's 3x4 matrix as inverse(bone_world) * solid_matrix.

Solid record in chunk 5 (after u32 count): u32 name length, name, i32 bone, 12 f32 (x/y/z axis + origin),
then the solid's geometry. Our solids are named Hull<N>, which is used to find the records.
"""
import sys, os, struct, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_pose import bind_world


def inverse_affine(W):
    R = [[W[i][j] for j in range(3)] for i in range(3)]
    # general 3x3 inverse (bones may carry scale)
    a, b, c = R[0]; d, e, f = R[1]; g, h, k = R[2]
    det = a * (e * k - f * h) - b * (d * k - f * g) + c * (d * h - e * g)
    inv = [[(e * k - f * h) / det, (c * h - b * k) / det, (b * f - c * e) / det],
           [(f * g - d * k) / det, (a * k - c * g) / det, (c * d - a * f) / det],
           [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det]]
    t = [W[i][3] for i in range(3)]
    ti = [-sum(inv[i][j] * t[j] for j in range(3)) for i in range(3)]
    return inv, ti


def fix(path):
    d = bytearray(open(path, "rb").read())
    o = 4; ch = {}
    while o + 8 <= len(d):
        cid, sz = struct.unpack_from("<II", d, o); ch[cid] = (o + 8, sz); o += 8 + sz
    s, sz = ch[5]
    n = struct.unpack_from("<I", d, s)[0]
    _, W = bind_world(path)
    fixed = 0
    for m in re.finditer(rb"Hull\d+", bytes(d[s:s + sz])):
        name_off = s + m.start()
        ln = struct.unpack_from("<I", d, name_off - 4)[0]
        if ln != len(m.group(0)):
            continue
        bone_off = name_off + ln
        bone = struct.unpack_from("<i", d, bone_off)[0]
        if bone < 0:
            continue
        M = list(struct.unpack_from("<12f", d, bone_off + 4))
        inv, ti = inverse_affine(W[bone])
        cols = [M[0:3], M[3:6], M[6:9]]
        new_cols = [[sum(inv[i][j] * col[j] for j in range(3)) for i in range(3)] for col in cols]
        org = M[9:12]
        new_org = [sum(inv[i][j] * org[j] for j in range(3)) + ti[i] for i in range(3)]
        struct.pack_into("<12f", d, bone_off + 4, *(new_cols[0] + new_cols[1] + new_cols[2] + new_org))
        fixed += 1
    assert fixed == n, f"{path}: fixed {fixed} of {n} solids"
    open(path, "wb").write(bytes(d))
    print(f"SOLIDS {os.path.basename(path)}: {fixed} solids made bone-relative")


for p in sys.argv[1:]:
    fix(p)
