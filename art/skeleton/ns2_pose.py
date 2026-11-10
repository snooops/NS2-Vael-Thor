"""Bind-pose (rest) world transforms of an NS2 .model skeleton, including bone scale.

Bone chunk floats: pos(3), quat xyzw(4), scale(3), scale-orientation quat xyzw(4), 1 extra.
local = T(pos) * R(quat) * SO * S(scale) * SO^-1   (Max convention: scale along the scale axes)
world = parent_world * local. Pure Python (4x4 lists), NS2 space.
"""
from ns2_model import read_bones

def qmat(x, y, z, w):
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
            [0, 0, 0, 1]]

def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def transpose3(m):
    return [[m[j][i] for j in range(3)] + [0] for i in range(3)] + [[0, 0, 0, 1]]

def bind_world(path):
    bones, _, _ = read_bones(path)
    world = []
    for b in bones:
        f = b["f"]
        T = [[1, 0, 0, f[0]], [0, 1, 0, f[1]], [0, 0, 1, f[2]], [0, 0, 0, 1]]
        R = qmat(*f[3:7])
        S = [[f[7], 0, 0, 0], [0, f[8], 0, 0], [0, 0, f[9], 0], [0, 0, 0, 1]]
        SO = qmat(*f[10:14])
        local = mul(mul(T, R), mul(mul(SO, S), transpose3(SO)))
        world.append(local if b["parent"] < 0 else mul(world[b["parent"]], local))
    return bones, world

def xform(m, p):
    return [sum(m[i][k] * p[k] for k in range(3)) + m[i][3] for i in range(3)]

def xdir(m, d):
    return [sum(m[i][k] * d[k] for k in range(3)) for i in range(3)]
