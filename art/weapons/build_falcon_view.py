"""Falcon -> first-person view model: vanilla rifle_view.model arms + animations, Falcon instead of the rifle.

Usage: blender -b --factory-startup -P build_falcon_view.py -- <rifle_view_reference.blend> <scene.gltf> <out.blend> <preview_dir>
The view rifle sits at the origin in bind pose, forward -Y, up +Z (same axes as the Falcon). The Falcon is scaled and
shifted so its muzzle and trigger land on the vanilla muzzle node and trigger joint, skinned rigidly to
rifle_view_root_jnt. Hands (material 0) keep their weights; rifle + ammo display faces are dropped.
"""
import bpy, bmesh, sys, os
from mathutils import Vector, Matrix
REF, GLTF, OUT, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from falcon_common import import_falcon, MUZZLE, TRIGGER

bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
view = next(o for o in sc.objects if o.type == 'MESH')
J = lambda n: arm.matrix_world @ arm.data.bones[n].head_local
v_muzzle, v_trigger = J("fxnode_riflemuzzle"), J("rifle_view_trigger_jnt")

# hands only
bm = bmesh.new(); bm.from_mesh(view.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != 0], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(view.data); bm.free()
mats = list(view.data.materials)
view.data.materials.clear(); view.data.materials.append(bpy.data.materials.new("hands"))
print("HANDS verts", len(view.data.vertices))

falcon = import_falcon(GLTF)
fm, ft = Vector(MUZZLE), Vector(TRIGGER)
s = (v_trigger.y - v_muzzle.y) / (ft.y - fm.y)
M = Matrix.Translation(v_trigger) @ Matrix.Scale(s, 4) @ Matrix.Translation(-ft)
falcon.data.transform(M); falcon.data.update()
print("FALCON view scale", round(s, 5), "muzzle", tuple(round(x, 3) for x in M @ fm), "vanilla muzzle", tuple(round(x, 3) for x in v_muzzle))

for b in arm.data.bones: falcon.vertex_groups.new(name=b.name)
falcon.vertex_groups["rifle_view_root_jnt"].add(list(range(len(falcon.data.vertices))), 1.0, 'REPLACE')
falcon.data.materials.append(bpy.data.materials.new("falcon_view"))
view.modifiers.clear(); view.parent = None
for o in sc.objects: o.select_set(o in (view, falcon))
bpy.context.view_layer.objects.active = view
bpy.ops.object.join()
view.name = "falcon_view"
view.parent = arm
mod = view.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
print("JOINED verts", len(view.data.vertices), "materials", [m.name for m in view.data.materials])
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)

sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'
sc.render.resolution_x = 900; sc.render.resolution_y = 700
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 1.6
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, -0.05, -0.25)); cam.location = c + Vector((4, 0, 0))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = os.path.join(PREV, "falcon_view_side.png"); bpy.ops.render.render(write_still=True)
