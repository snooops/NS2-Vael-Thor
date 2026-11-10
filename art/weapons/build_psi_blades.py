"""Psionic blades (Infiltrator, Zealot style): wrist-mounted energy blades placed on a model's forearms.

Usage: python3 build_psi_blades.py <model> <r_wrist> <r_elbow> <l_wrist> <l_elbow> <r_hand_bones,> <l_hand_bones,> <out.json> [style]
style: "blade" (default, Infiltrator psi blade) or "claws" (Subject: knuckle plate + three curved claws per hand).
Bind-pose transforms come from art/skeleton/ns2_pose.py (incl. bone scale). Per side: blade along the forearm
(elbow -> wrist), standing up from the back of the hand (flattest axis of the hand vertices, oriented outward),
emitter housing on the back of the wrist. Output: [[{"p","n","uv","bone"} x3], ...] in NS2 model space.
UV atlas: u < 0.5 emitter housing (dark metal), u > 0.5 psionic blade (glow).
"""
import sys, os, json, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skeleton"))
from ns2_pose import bind_world, xform
from ns2_model import read_mesh

MODEL, RW, RE, LW, LE, RH, LH, OUT = sys.argv[1:9]
STYLE = sys.argv[9] if len(sys.argv) > 9 else "blade"
HOUSING_U, BLADE_U = 0.25, 0.75

def sub(a, b): return [a[i] - b[i] for i in range(3)]
def add(a, b): return [a[i] + b[i] for i in range(3)]
def mulv(a, s): return [x * s for x in a]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def norm(a):
    l = math.sqrt(dot(a, a)) or 1
    return [x / l for x in a]

bones, W = bind_world(MODEL)
names = [b["name"] for b in bones]
verts, _, _ = read_mesh(MODEL)
P = lambda bn: xform(W[names.index(bn)], [0, 0, 0])

def smallest_axis(pts):
    c = [sum(p[k] for p in pts) / len(pts) for k in range(3)]
    C = [[sum((p[i] - c[i]) * (p[j] - c[j]) for p in pts) / len(pts) for j in range(3)] for i in range(3)]
    # power iteration on the inverse-ish: deflate the two largest eigenvectors
    def power(M, it=60):
        v = [1, 0.3, 0.1]
        for _ in range(it):
            v = norm([sum(M[i][k] * v[k] for k in range(3)) for i in range(3)])
        lam = dot(v, [sum(M[i][k] * v[k] for k in range(3)) for i in range(3)])
        return v, lam
    v1, l1 = power(C)
    C2 = [[C[i][j] - l1 * v1[i] * v1[j] for j in range(3)] for i in range(3)]
    v2, _ = power(C2)
    return norm(cross(v1, v2)), c

tris = []
def emit(quad_or_tri, normal_hint_center, u, bone):
    pts = quad_or_tri
    for a, b, c in [(pts[0], pts[1], pts[2])] + ([(pts[0], pts[2], pts[3])] if len(pts) == 4 else []):
        n = norm(cross(sub(b, a), sub(c, a)))
        cen = [(a[k] + b[k] + c[k]) / 3 for k in range(3)]
        if dot(n, sub(cen, normal_hint_center)) < 0:
            n = mulv(n, -1)
        tris.append([{"p": v, "n": n, "uv": [u + (0.08 if i % 2 else -0.08), 0.3 + 0.4 * (i // 2)], "bone": bone}
                     for i, v in enumerate((a, b, c))])

def build_side(wrist, elbow, hand_bones, side_sign):
    w, e = P(wrist), P(elbow)
    D = norm(sub(w, e))                                     # forearm direction
    hand_idx = {names.index(b) for b in hand_bones}
    pts = [v[0] for v in verts if v[3] and max(v[3], key=lambda t: t[1])[0] in hand_idx]
    N, hc = smallest_axis(pts) if len(pts) > 20 else ([side_sign, 0, 0], w)
    N = norm(sub(N, mulv(D, dot(N, D))))                    # orthogonal to the forearm
    if N[0] * side_sign < 0:                                # back of the hand faces outward
        N = mulv(N, -1)
    T = norm(cross(D, N))
    frame = lambda l, wv, tv: add(add(add(w, mulv(D, l)), mulv(N, wv)), mulv(T, tv))
    if STYLE == "claws":
        build_claws(frame, D, N, T, wrist)
        return

    # emitter housing: box on the back of the wrist
    l0, l1, w0, w1, t0, t1 = -0.07, 0.05, 0.015, 0.05, -0.024, 0.024
    corners = {(i, j, k): frame((l0, l1)[i], (w0, w1)[j], (t0, t1)[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    hcen = frame((l0 + l1) / 2, (w0 + w1) / 2, 0)
    for q in (((0,0,0),(1,0,0),(1,1,0),(0,1,0)), ((0,0,1),(0,1,1),(1,1,1),(1,0,1)), ((0,0,0),(0,0,1),(1,0,1),(1,0,0)),
              ((0,1,0),(1,1,0),(1,1,1),(0,1,1)), ((0,0,0),(0,1,0),(0,1,1),(0,0,1)), ((1,0,0),(1,0,1),(1,1,1),(1,1,0))):
        emit([corners[c] for c in q], hcen, HOUSING_U, wrist)

    # psionic blade: lens-section fin from the housing forward past the fist
    BL0, BL1, ST = 0.0, 0.56, 12
    secs = []
    for i in range(ST + 1):
        s = i / ST
        l = BL0 + (BL1 - BL0) * s
        inner = 0.045 + 0.01 * s                            # edge nearest the hand
        width = 0.055 * (1 - s ** 2.2) + 0.006
        outer = inner + width
        th = 0.007 * (1 - 0.6 * s)
        if i == ST:
            tip = frame(l + 0.03, inner + 0.004, 0); secs.append([tip] * 4); continue
        mid = (inner + outer) / 2
        secs.append([frame(l, inner, 0), frame(l, mid, th), frame(l, outer, 0), frame(l, mid, -th)])
    for i, (a, b) in enumerate(zip(secs, secs[1:])):
        s = (i + 0.5) / ST
        cen = frame(BL0 + (BL1 - BL0) * s, 0.045 + 0.01 * s + 0.03 * (1 - s), 0)
        for k in range(4):
            k2 = (k + 1) % 4
            quad = [a[k], a[k2], b[k2], b[k]]
            if quad[2] is quad[3]:
                emit(quad[:3], cen, BLADE_U, wrist)
            else:
                emit(quad, cen, BLADE_U, wrist)
    base = secs[0]
    emit(base, frame(-0.05, 0.06, 0), BLADE_U, wrist)

def box(frame, l0, l1, w0, w1, t0, t1, u, bone):
    corners = {(i, j, k): frame((l0, l1)[i], (w0, w1)[j], (t0, t1)[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    cen = frame((l0 + l1) / 2, (w0 + w1) / 2, (t0 + t1) / 2)
    for q in (((0,0,0),(1,0,0),(1,1,0),(0,1,0)), ((0,0,1),(0,1,1),(1,1,1),(1,0,1)), ((0,0,0),(0,0,1),(1,0,1),(1,0,0)),
              ((0,1,0),(1,1,0),(1,1,1),(0,1,1)), ((0,0,0),(0,1,0),(0,1,1),(0,0,1)), ((1,0,0),(1,0,1),(1,1,1),(1,1,0))):
        emit([corners[c] for c in q], cen, u, bone)

def build_claws(frame, D, N, T, bone):
    # armoured knuckle plate over the claw roots (kept small: it sits right in front of the first-person camera)
    box(frame, 0.045, 0.105, 0.014, 0.032, -0.036, 0.036, HOUSING_U, bone)
    # three curved claws from the plate's front edge, bending toward the palm (-N)
    L0, L1, ST = 0.07, 0.40, 10
    for tc in (-0.030, 0.0, 0.030):
        secs = []
        for i in range(ST + 1):
            s_ = i / ST
            l = L0 + (L1 - L0) * s_
            wc = 0.030 - 0.075 * s_ * s_                    # curve toward the palm
            hw = 0.010 * (1 - s_) + 0.0008                  # half width across the hand
            ht = 0.0065 * (1 - s_) + 0.0006                 # half thickness
            if i == ST:
                tip = frame(l + 0.015, wc - 0.01, tc); secs.append([tip] * 4); continue
            c = frame(l, wc, tc)
            secs.append([add(c, mulv(N, ht)), add(c, mulv(T, hw)), add(c, mulv(N, -ht)), add(c, mulv(T, -hw))])
        for i, (a, b) in enumerate(zip(secs, secs[1:])):
            s_ = (i + 0.5) / ST
            cen = frame(L0 + (L1 - L0) * s_, 0.030 - 0.075 * s_ * s_, tc)
            for k in range(4):
                k2 = (k + 1) % 4
                quad = [a[k], a[k2], b[k2], b[k]]
                emit(quad[:3] if quad[2] is quad[3] else quad, cen, BLADE_U, bone)
        emit(secs[0], frame(L0 - 0.05, 0.03, tc), BLADE_U, bone)

build_side(RW, RE, RH.split(","), -1)
build_side(LW, LE, LH.split(","), +1)
json.dump(tris, open(OUT, "w"))
print("blades", len(tris), "tris ->", OUT)
