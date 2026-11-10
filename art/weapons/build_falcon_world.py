"""Falcon -> third-person world model on the vanilla rifle.model skeleton (rifle_root + fx nodes).

Usage: blender -b --factory-startup -P build_falcon_world.py -- <rifle_reference.blend> <scene.gltf> <out.blend> <preview_dir>
World rifle frame (Blender): forward +X, down +Y (grenade launcher node hangs at +Y), side Z; the hand attach
is rifle_root at the origin. Falcon (forward -Y, up +Z, side X) is mapped (x,y,z) -> (-y, -z, x), scaled so the
muzzle->grip distance matches the vanilla rifle; barrel line on the vanilla barrel line (the hand attach is
at barrel height, not at the grip); fxnode_riflemuzzle moves to the new muzzle.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
REF, GLTF, OUT, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from falcon_common import import_falcon, MUZZLE, GRIP

bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
old = next(o for o in sc.objects if o.type == 'MESH')
vanilla_muzzle = arm.matrix_world @ arm.data.bones["fxnode_riflemuzzle"].head_local
bpy.data.objects.remove(old)

falcon = import_falcon(GLTF)
R = Matrix(((0, -1, 0), (0, 0, -1), (1, 0, 0))).to_4x4()     # det +1
g, m = Vector(GRIP), Vector(MUZZLE)
s = vanilla_muzzle.x / (R @ (m - g)).x                        # muzzle->grip along +X matches vanilla
M = Matrix.Scale(s, 4) @ R @ Matrix.Translation(-g)
# The hand attach (rifle_root) sits at about barrel height on the vanilla rifle (its muzzle node is 1.7 cm
# above it), not at the grip: put the Falcon's barrel line on the vanilla barrel line (height + side), so
# the gun doesn't float above the hands. Only the forward position stays grip-based.
mz = M @ m
M = Matrix.Translation((0, vanilla_muzzle.y - mz.y, vanilla_muzzle.z - mz.z)) @ M
falcon.data.transform(M); falcon.data.update()
new_muzzle = M @ m
print("FALCON world scale", round(s, 5), "muzzle", tuple(round(x, 3) for x in new_muzzle),
      "length", round(max(v.co.x for v in falcon.data.vertices) - min(v.co.x for v in falcon.data.vertices), 3))

# move the muzzle fx node (keep its orientation)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones["fxnode_riflemuzzle"]
d = new_muzzle - eb.head
eb.head += d; eb.tail += d
bpy.ops.object.mode_set(mode='OBJECT')

vg = falcon.vertex_groups.new(name="rifle_root")
vg.add(list(range(len(falcon.data.vertices))), 1.0, 'REPLACE')
for b in arm.data.bones:
    if b.name != "rifle_root": falcon.vertex_groups.new(name=b.name)
falcon.data.materials.append(bpy.data.materials.new("robot"))
falcon.parent = arm
mod = falcon.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)

sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'
sc.render.resolution_x = 1000; sc.render.resolution_y = 500
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 1.2
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0.1, 0.05, 0)); cam.location = c + Vector((0, 0, 5))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
arm.show_in_front = True
sc.render.filepath = os.path.join(PREV, "falcon_world.png"); bpy.ops.render.render(write_still=True)
