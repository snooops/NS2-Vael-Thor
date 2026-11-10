import bpy, sys, os
from mathutils import Vector
f = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=f)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
me = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
print("MATS", [m.name for m in me.data.materials])
for mi, mname in enumerate(me.data.materials):
    vs = {v for p in me.data.polygons if p.material_index == mi for v in p.vertices}
    pts = [me.matrix_world @ me.data.vertices[i].co for i in vs]
    if not pts: continue
    lo = Vector([min(p[k] for p in pts) for k in range(3)]); hi = Vector([max(p[k] for p in pts) for k in range(3)])
    print(f"BBOX {mname.name:30} min {tuple(round(x,3) for x in lo)} max {tuple(round(x,3) for x in hi)} n={len(pts)}")
for b in arm.data.bones:
    if any(k in b.name for k in ("rifle", "fxnode", "Wrist", "CamBone", "ROOT")):
        h = arm.matrix_world @ b.head_local; t = arm.matrix_world @ b.tail_local
        print(f"BONE {b.name:32} head {tuple(round(x,3) for x in h)} dir {tuple(round(x,2) for x in (t-h).normalized())}")
