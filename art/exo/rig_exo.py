"""Skin a posed mesh ("robot", from fab/*/prepare_titan.py) to the Exosuit skeleton and keep the exo's miniguns.

Usage: blender -b --factory-startup -P rig_exo.py -- <exo_mm_reference.blend> <robot.blend> <out.blend> <preview_dir>
The exo skeleton is kept exactly (its animations pin the joints). The exo body (material 0) is the weight
source and is then dropped; the minigun faces (material 1, minigun.material) are kept with their original
weights and joined into the result as material slot 1.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

REF, ROBOT_BLEND, OUT, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]
bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
exo = next(o for o in sc.objects if o.type == 'MESH')
with bpy.data.libraries.load(ROBOT_BLEND) as (src, dst):
    dst.objects = ["robot"]
robot = dst.objects[0]; sc.collection.objects.link(robot)
bones = arm.data.bones

def split_by_material(ob, keep_index, name):
    c = ob.copy(); c.data = ob.data.copy(); c.name = name; sc.collection.objects.link(c)
    bm = bmesh.new(); bm.from_mesh(c.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != keep_index], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(c.data); bm.free()
    return c

body = split_by_material(exo, 0, "exo_body")
guns = split_by_material(exo, 1, "exo_guns")
for o in (body, guns):
    o.modifiers.clear(); o.parent = None; o.matrix_world = exo.matrix_world.copy()
print("SPLIT body verts", len(body.data.vertices), "gun verts", len(guns.data.vertices))

# 1) transferred weights from the exo body (fallback where heat weighting fails)
for vg in body.vertex_groups: robot.vertex_groups.new(name=vg.name)
dt = robot.modifiers.new("dt", 'DATA_TRANSFER'); dt.object = body
dt.use_vert_data = True; dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'
dt.layers_vgroup_select_src = 'ALL'; dt.layers_vgroup_select_dst = 'NAME'
bpy.context.view_layer.objects.active = robot
for o in sc.objects: o.select_set(o == robot)
bpy.ops.object.modifier_apply(modifier="dt")
transferred = {v.index: [(robot.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in robot.data.vertices}

# 2) automatic weights on the exo's main deform chain
DEFORM = {"Exosuit_UpprTorso", "Exosuit_Pelvis"}
for S in ("L", "R"):
    DEFORM |= {f"Exosuit_{S}Clavicle", f"Exosuit_{S}Shldr", f"Exosuit_{S}Elbow", f"Exosuit_{S}Wrist",
               f"Exosuit_{S}Hip", f"Exosuit_{S}Hip2", f"Exosuit_{S}Knee", f"Exosuit_{S}Ankle", f"Exosuit_{S}Foot"}
for b in bones: b.use_deform = b.name in DEFORM
robot.vertex_groups.clear()
for o in sc.objects: o.select_set(o in (robot, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for b in bones: b.use_deform = True
robot.modifiers.clear()
fallback = 0
for v in robot.data.vertices:
    if not any(g.weight > 0.001 for g in v.groups):
        fallback += 1
        for name, w in transferred[v.index]:
            if name not in robot.vertex_groups: robot.vertex_groups.new(name=name)
            robot.vertex_groups[name].add([v.index], w, 'REPLACE')
print("AUTO weights done, fallback verts", fallback)

# 3) merge accessory bones into their main-chain parent, cap to 4 influences
MERGE = ("Piston", "Hose", "Wire", "Chain", "Tube", "Brace", "railgun", "Claw", "fxnode", "minigun_root", "Hood", "Spine")
def merge_target(name):
    b = bones[name]
    while b.parent and any(k in b.name for k in MERGE): b = b.parent
    return b.name
W = {}
for v in robot.data.vertices:
    acc = {}
    for g in v.groups:
        tgt = merge_target(robot.vertex_groups[g.group].name)
        acc[tgt] = acc.get(tgt, 0) + g.weight
    top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
    top = [(k, w) for k, w in top if w > 0.02] or top[:1]
    tot = sum(w for _, w in top) or 1
    W[v.index] = [(k, w / tot) for k, w in top]
robot.vertex_groups.clear()
for b in bones: robot.vertex_groups.new(name=b.name)
for vi, inf in W.items():
    for k, w in inf: robot.vertex_groups[k].add([vi], w, 'REPLACE')
print("ROBOT verts", len(robot.data.vertices), "unweighted", sum(1 for inf in W.values() if not inf))

# 4) join the exo miniguns (original weights) as material slot 1
robot.data.materials.clear()
robot.data.materials.append(bpy.data.materials.new("robot"))
guns.data.materials.clear()
guns.data.materials.append(bpy.data.materials.new("minigun"))
for o in sc.objects: o.select_set(o in (robot, guns))
bpy.context.view_layer.objects.active = robot
bpy.ops.object.join()
print("JOINED verts", len(robot.data.vertices), "materials", [m.name for m in robot.data.materials])

robot.parent = arm
m = robot.modifiers.new("Armature", 'ARMATURE'); m.object = arm
bpy.data.objects.remove(body); bpy.data.objects.remove(exo)
arm.name = "robot_skeleton"
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)

# previews: rest + test pose
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
robot.data.materials[0].diffuse_color = (0.85, 0.85, 0.88, 1)
robot.data.materials[1].diffuse_color = (0.45, 0.45, 0.5, 1)
sc.render.resolution_x = 800; sc.render.resolution_y = 900
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 3.4
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, -0.2, 1.4))
def shot(tag, pos):
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(PREV, f"exorig_{tag}.png"); bpy.ops.render.render(write_still=True)
shot("rest_front34", (4.5, -4.5, 0.8)); shot("rest_side", (6, 0, 0))
def rot(name, axis, deg):
    pb = arm.pose.bones[name]; pb.rotation_mode = 'XYZ'
    e = [0, 0, 0]; e["XYZ".index(axis)] = math.radians(deg); pb.rotation_euler = e
rot("Exosuit_LShldr", 'X', 40); rot("Exosuit_RElbow", 'X', -35)
rot("Exosuit_RHip2", 'X', 30); rot("Exosuit_RKnee", 'X', -30)
rot("Exosuit_UpprTorso", 'Z', 15)
shot("pose_front34", (4.5, -4.5, 0.8))
