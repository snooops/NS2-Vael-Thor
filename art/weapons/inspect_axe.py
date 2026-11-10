import bpy, sys, os
from mathutils import Vector
f = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=f)
sc = bpy.context.scene
me = next(o for o in sc.objects if o.type == 'MESH')
arm = next((o for o in sc.objects if o.type == 'ARMATURE'), None)
for mi, m in enumerate(me.data.materials):
    vs = {v for p in me.data.polygons if p.material_index == mi for v in p.vertices}
    pts = [me.matrix_world @ me.data.vertices[i].co for i in vs]
    lo = Vector([min(p[k] for p in pts) for k in range(3)]); hi = Vector([max(p[k] for p in pts) for k in range(3)])
    print(f"BBOX {m.name:28} min {tuple(round(x,3) for x in lo)} max {tuple(round(x,3) for x in hi)} n={len(pts)}")
    if arm:
        acc = {}
        for i in vs:
            for g in me.data.vertices[i].groups:
                n = me.vertex_groups[g.group].name; acc[n] = acc.get(n, 0) + g.weight
        print("   weights:", sorted(((round(w), n) for n, w in acc.items()), reverse=True)[:6])
if arm:
    for b in arm.data.bones:
        if "axe" in b.name or "RHand_Wrist" in b.name or "Cam" in b.name:
            h = arm.matrix_world @ b.head_local; t = arm.matrix_world @ b.tail_local
            print(f"BONE {b.name:20} head {tuple(round(x,3) for x in h)} dir {tuple(round(x,2) for x in (t-h).normalized())}")
# slices along the long axis of the non-hands part
mi = len(me.data.materials) - 1
vs = {v for p in me.data.polygons if p.material_index == mi for v in p.vertices}
pts = [me.matrix_world @ me.data.vertices[i].co for i in vs]
ext = [max(p[k] for p in pts) - min(p[k] for p in pts) for k in range(3)]
ax = ext.index(max(ext)); a0 = min(p[ax] for p in pts); a1 = max(p[ax] for p in pts)
print("LONG AXIS", "XYZ"[ax], round(a0, 3), round(a1, 3))
o = [k for k in range(3) if k != ax]
for i in range(10):
    lo_, hi_ = a0 + (a1 - a0) * i / 10, a0 + (a1 - a0) * (i + 1) / 10
    s = [p for p in pts if lo_ <= p[ax] < hi_]
    if s: print(f"SLICE {lo_:6.3f}..{hi_:6.3f}  " + "  ".join(f"{'XYZ'[k]} {min(p[k] for p in s):6.3f}..{max(p[k] for p in s):6.3f}" for k in o))
