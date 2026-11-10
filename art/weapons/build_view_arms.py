"""Cut the arms out of a rigged third-person player model and re-bind them to a first-person view skeleton.

Usage: python3 build_view_arms.py <player.model> <view.model> <out_arms.json> [shoulder_cut=0.12]

The player model must use the marine third-person skeleton (male.model bone names, e.g. the Silver Sentinel).
Two view skeleton naming styles are supported: the axe/grenade launcher style (same names as male.model:
LArm_Elbow, LHand_PointrBase ...) and the rifle style (male_l_Arm_Elbow_jnt_export, male_l_Finger_01_01_jnt_export
with Finger_01..04 = index, middle, ring, pinky; _01/_02/_03 = base/mid/tip).

Fitting is done by JOINT POSITIONS, not bone orientations (the two rigs use different local axes):
  * hand:     similarity fit (Kabsch + uniform scale) of hand wrist + the five finger bases
  * fingers:  hand rotation, then the minimal rotation turning the bone direction onto the view bone direction,
              anchored at the bone's joint
  * forearm:  hand rotation, then the minimal rotation elbow->wrist onto the view's, anchored at the elbow,
              scaled by the forearm length ratio
  * upper arm: forearm rotation, then shoulder->elbow, anchored at the shoulder
Every vertex is moved with the blend of its bones' transforms (its skin weights), so seams stay closed.
Vertices keep their skin weights, mapped to the view bones (max 4 influences).

Output JSON: {"palette": [view bone names], "verts": [{p,n,t,b,uv,w:[[palette idx, weight]...]}], "tris": [[a,b,c]...]}
"""
import sys, os, json, math, struct
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_model import chunks, read_bones
from ns2_pose import bind_world

PLAYER, VIEW, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SHOULDER_CUT = float(sys.argv[4]) if len(sys.argv) > 4 else 0.12

# ------------------------------------------------------------------ small vector math (3x3 lists)
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def add(a, b): return [a[i] + b[i] for i in range(3)]
def scl(a, s): return [x * s for x in a]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def norm(a): return math.sqrt(dot(a, a))
def unit(a):
    l = norm(a); return [x / l for x in a] if l > 1e-12 else [0.0, 0.0, 0.0]
def mv(m, v): return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]
def mm(a, b): return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def mt(a): return [[a[j][i] for j in range(3)] for i in range(3)]
I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

def rot_between(a, b):
    """minimal rotation taking unit a onto unit b"""
    a, b = unit(a), unit(b); v = cross(a, b); c = dot(a, b); s = norm(v)
    if s < 1e-9:
        if c > 0: return [r[:] for r in I3]
        p = unit(cross(a, [1, 0, 0] if abs(a[0]) < 0.9 else [0, 1, 0]))          # 180 deg about any normal
        return [[2 * p[i] * p[j] - (1 if i == j else 0) for j in range(3)] for i in range(3)]
    k = scl(v, 1 / s)
    K = [[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]]
    K2 = mm(K, K)
    return [[I3[i][j] + s * K[i][j] + (1 - c) * K2[i][j] for j in range(3)] for i in range(3)]

def kabsch(P, Q):
    """similarity (R, s) with Q ~ s R (P - cp) + cq; Horn's quaternion method, pure Python"""
    cp = scl([sum(p[i] for p in P) for i in range(3)], 1 / len(P))
    cq = scl([sum(q[i] for q in Q) for i in range(3)], 1 / len(Q))
    A = [sub(p, cp) for p in P]; B = [sub(q, cq) for q in Q]
    S = [[sum(a[i] * b[j] for a, b in zip(A, B)) for j in range(3)] for i in range(3)]
    N = [[S[0][0] + S[1][1] + S[2][2], S[1][2] - S[2][1], S[2][0] - S[0][2], S[0][1] - S[1][0]],
         [S[1][2] - S[2][1], S[0][0] - S[1][1] - S[2][2], S[0][1] + S[1][0], S[2][0] + S[0][2]],
         [S[2][0] - S[0][2], S[0][1] + S[1][0], -S[0][0] + S[1][1] - S[2][2], S[1][2] + S[2][1]],
         [S[0][1] - S[1][0], S[2][0] + S[0][2], S[1][2] + S[2][1], -S[0][0] - S[1][1] + S[2][2]]]
    q = [1.0, 0.0, 0.0, 0.0]                                   # power iteration on N + shift -> max eigenvector
    for _ in range(200):
        q2 = [sum((N[i][j] + (10.0 if i == j else 0.0)) * q[j] for j in range(4)) for i in range(4)]
        l = math.sqrt(sum(x * x for x in q2)); q = [x / l for x in q2]
    w, x, y, z = q
    R = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    s = math.sqrt(sum(dot(b, b) for b in B) / sum(dot(a, a) for a in A))
    return R, s, cp, cq

# ------------------------------------------------------------------ skeletons
def joints(path):
    bones, W = bind_world(path)
    return [b["name"] for b in bones], {b["name"]: [W[i][r][3] for r in range(3)] for i, b in enumerate(bones)}

pnames, PJ = joints(PLAYER)
vnames, VJ = joints(VIEW)
rifle_style = any(n.endswith("_jnt_export") for n in vnames)

FINGERS = {"Pointr": "01", "Middl": "02", "Ring": "03", "Pinky": "04"}
SEG = {"Base": "01", "Mid": "02", "Tip": "03"}

def view_name(side, part):
    """side 'L'/'R'; part in Shoulder, Elbow, ForearmPad, ForearmScaler, Wrist, <Finger><Seg>"""
    if not rifle_style:
        return f"{side}Arm_{part}" if part in ("Shoulder", "Elbow", "ForearmPad", "ForearmScaler") else f"{side}Hand_{part}"
    s = side.lower()
    if part in ("Shoulder", "Elbow", "Wrist"):
        return f"male_{s}_Arm_{part}_jnt_export"
    if part in ("ForearmPad", "ForearmScaler"):
        return f"male_{s}_Arm_{part}_01_01_jnt_export"
    for seg, sn in SEG.items():
        if part.endswith(seg):
            f = part[:-len(seg)]
            return f"male_{s}_Thumb_01_{sn}_jnt_export" if f == "Thumb" else f"male_{s}_Finger_{FINGERS[f]}_{sn}_jnt_export"
    raise KeyError(part)

def player_to_part(name):
    """male.model arm bone -> (side, view part) or None (not part of the first-person arm)"""
    for side in ("L", "R"):
        if name in (f"{side}Arm_Shoulder", f"{side}Arm_Shoulder_Twist1", f"{side}Arm_Shoulder_Twist2",
                    f"{side}Arm_ShldrPad1", f"{side}Arm_ShldrPad2"):
            return side, "Shoulder"
        if name == f"{side}Arm_Elbow": return side, "Elbow"
        if name == f"{side}Arm_ForearmPad": return side, "ForearmPad"
        if name in (f"{side}Arm_ForearmScaler", f"{side}Arm_Wrist"): return side, "ForearmScaler"
        if name in (f"{side}Arm_Wrist01", f"{side}Arm_Wrist02", f"{side}Hand_Wrist", f"{side}Hand_Weapon"):
            return side, "Wrist"
        if name.startswith(f"{side}Hand_"):
            return side, name[len(side) + 5:]
    return None

def pj(side, part):
    """joint position in the player skeleton for a view part"""
    if part == "Wrist": return PJ[f"{side}Hand_Wrist"]
    if part in ("Shoulder", "Elbow", "ForearmPad", "ForearmScaler"): return PJ[f"{side}Arm_{part}"]
    return PJ[f"{side}Hand_{part}"]

def vj(side, part): return VJ[view_name(side, part)]

# ------------------------------------------------------------------ per-part transforms: p' = s R (p - a) + b
T = {}
for side in ("L", "R"):
    bases = ["Wrist"] + [f + "Base" for f in ("Thumb", "Pointr", "Middl", "Ring", "Pinky")]
    Rh, sh, cp, cq = kabsch([pj(side, b) for b in bases], [vj(side, b) for b in bases])
    T[(side, "Wrist")] = (Rh, sh, cp, cq)
    for f in ("Thumb", "Pointr", "Middl", "Ring", "Pinky"):
        chain = [f + "Base", f + "Mid", f + "Tip"]
        for i, part in enumerate(chain):
            a, b = (chain[i], chain[i + 1]) if i < 2 else (chain[1], chain[2])
            d_src = mv(Rh, sub(pj(side, b), pj(side, a))); d_dst = sub(vj(side, b), vj(side, a))
            R = mm(rot_between(d_src, d_dst), Rh)
            T[(side, part)] = (R, sh, pj(side, part), vj(side, part))
    # forearm: twist from the hand
    d_src = mv(Rh, sub(pj(side, "Wrist"), pj(side, "Elbow"))); d_dst = sub(vj(side, "Wrist"), vj(side, "Elbow"))
    Rf = mm(rot_between(d_src, d_dst), Rh)
    sf = norm(d_dst) / norm(d_src)
    for part in ("Elbow", "ForearmPad", "ForearmScaler"):
        T[(side, part)] = (Rf, sf, pj(side, "Elbow"), vj(side, "Elbow"))
    # upper arm: twist from the forearm
    d_src = mv(Rf, sub(pj(side, "Elbow"), pj(side, "Shoulder"))); d_dst = sub(vj(side, "Elbow"), vj(side, "Shoulder"))
    Ru = mm(rot_between(d_src, d_dst), Rf)
    su = norm(d_dst) / norm(d_src)
    T[(side, "Shoulder")] = (Ru, su, pj(side, "Shoulder"), vj(side, "Shoulder"))
    print(f"FIT {side}: hand scale {sh:.3f}, forearm {sf:.3f}, upper arm {su:.3f}, view style {'rifle' if rifle_style else 'axe'}")

# ------------------------------------------------------------------ player mesh (raw, with tangents)
d = open(PLAYER, "rb").read(); ch = chunks(d)
s, _ = ch[3]; n = struct.unpack_from("<I", d, s)[0]; o = s + 4; facesets = []
for _ in range(n):
    mat, first, count, nb = struct.unpack_from("<4I", d, o); o += 16
    pal = struct.unpack_from(f"<{nb}I", d, o); o += 4 * nb
    facesets.append((first, count, pal))
s, _ = ch[2]; ni = struct.unpack_from("<I", d, s)[0]; idx = struct.unpack_from(f"<{ni}I", d, s + 4)
s1, _ = ch[1]
def raw_vert(i):
    b = s1 + 4 + 92 * i
    f = struct.unpack_from("<14f", d, b)
    inf = [struct.unpack_from("<fI", d, b + 60 + 8 * k) for k in range(4)]
    return f, [(bi, w) for w, bi in inf if w > 0]

vert_bones = {}
tris_src = []
for first, count, pal in facesets:
    for t in range(first, first + count):
        tri = idx[3 * t:3 * t + 3]; tris_src.append(tri)
        for vi in tri:
            if vi not in vert_bones:
                f, inf = raw_vert(vi)
                vert_bones[vi] = (f, [(pnames[pal[bi]], w) for bi, w in inf])

def arm_info(vi):
    """(side, mapped weights {part: w}, arm weight fraction) for a player vertex"""
    f, inf = vert_bones[vi]
    parts = {}; total = sum(w for _, w in inf) or 1.0; side = None
    for name, w in inf:
        m = player_to_part(name)
        if m:
            side = side or m[0]
            if m[0] == side:
                parts[m[1]] = parts.get(m[1], 0) + w
    return side, parts, sum(parts.values()) / total

def shoulder_t(side, p):
    S, E = pj(side, "Shoulder"), pj(side, "Elbow"); dd = sub(E, S)
    return dot(sub(p, S), dd) / dot(dd, dd)

keep = []
for tri in tris_src:
    infos = [arm_info(vi) for vi in tri]
    sides = {i[0] for i in infos}
    if None in sides or len(sides) != 1 or min(i[2] for i in infos) < 0.5:
        continue
    side = infos[0][0]
    if min(shoulder_t(side, vert_bones[vi][0][0:3]) for vi in tri) < SHOULDER_CUT:
        continue
    keep.append(tri)

# ------------------------------------------------------------------ transform + output
palette = []; pal_idx = {}
out_verts = []; remap = {}
for tri in keep:
    for vi in tri:
        if vi in remap: continue
        f, _ = vert_bones[vi]
        side, parts, _ = arm_info(vi)
        tot = sum(parts.values())
        p, nrm, tan, bit, uv = f[0:3], f[3:6], f[6:9], f[9:12], f[12:14]
        P = [0.0] * 3; Nn = [0.0] * 3; Tt = [0.0] * 3; Bb = [0.0] * 3
        for part, w in parts.items():
            R, sc, a, b = T[(side, part)]; w /= tot
            P = add(P, scl(add(scl(mv(R, sub(p, a)), sc), b), w))
            Nn = add(Nn, scl(mv(R, nrm), w)); Tt = add(Tt, scl(mv(R, tan), w)); Bb = add(Bb, scl(mv(R, bit), w))
        weights = sorted(((view_name(side, part), w / tot) for part, w in parts.items()), key=lambda x: -x[1])[:4]
        ws = sum(w for _, w in weights)
        wl = []
        for name, w in weights:
            if name not in pal_idx:
                pal_idx[name] = len(palette); palette.append(name)
            wl.append([pal_idx[name], w / ws])
        remap[vi] = len(out_verts)
        out_verts.append(dict(p=P, n=unit(Nn), t=unit(Tt), b=unit(Bb), uv=list(uv), w=wl))

for name in palette:
    assert name in VJ, f"view skeleton has no bone {name}"
out_tris = [[remap[v] for v in tri] for tri in keep]
json.dump(dict(palette=palette, verts=out_verts, tris=out_tris), open(OUT, "w"))
print(f"ARMS {len(out_tris)} tris, {len(out_verts)} verts, {len(palette)} bones -> {OUT}")
