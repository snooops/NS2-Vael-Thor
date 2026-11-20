"""Rigid parts ride 100% on one bone (after rig_robot.py, whose weights come from the marine skin / bone heat).

Usage: blender -b --factory-startup -P apply_rigid_weights.py -- <rigged.blend>
The mesh needs the INT point attribute "vt_bone" (index into the mesh property "vt_rigid_bones", -1 = keep the
rig's weights), written by the model's build script (e.g. art/subject/build_stalker.py). Saves in place.
"""
import bpy, sys
BLEND = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.open_mainfile(filepath=BLEND)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
me = mesh.data
names = list(me.get("vt_rigid_bones", []))
attr = me.attributes.get("vt_bone")
assert attr is not None and names, "no vt_bone attribute / vt_rigid_bones list on the mesh"
groups = {n: (mesh.vertex_groups.get(n) or mesh.vertex_groups.new(name=n)) for n in names}
all_groups = list(mesh.vertex_groups)
count = {n: 0 for n in names}
for v in me.vertices:
    i = attr.data[v.index].value
    if i < 0:
        continue
    for g in all_groups:
        g.remove([v.index])
    groups[names[i]].add([v.index], 1.0, "REPLACE")
    count[names[i]] += 1
for n in names:
    print("RIGID %-16s %5d verts" % (n, count[n]))
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("SAVED", BLEND)
