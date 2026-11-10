"""Rebuild an NS2 .model (skeleton + skinned mesh) in Blender.

Usage: blender -b --factory-startup -P import_ns2_marine.py -- <in.model> <out.blend> [preview_dir]

Coordinates: NS2 is Y-up, characters face +Z. Blender gets (x, y, z)_ns2 -> (x, -z, y)
(rotation of +90 deg about X), so the marine faces -Y like a Blender character.
Bone local frames: NS2/Max bones point along their local +X. Blender bones point along +Y, so each
bone's edit matrix is world @ R where R maps Blender bone Y -> NS2 bone X. The original NS2 local
transform of every bone is also stored as custom properties ("ns2_pos", "ns2_quat") so exporters
can write it back exactly.
"""
import bpy, sys, os, math, mathutils
from mathutils import Matrix, Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = args[0], args[1]
PREV = args[2] if len(args) > 2 else None
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ns2_model import read_bones, read_mesh, read_materials

C = Matrix.Rotation(math.radians(90), 4, 'X')          # NS2 -> Blender
BONE_FIX = Matrix(((0, 1, 0, 0), (1, 0, 0, 0), (0, 0, -1, 0), (0, 0, 0, 1)))  # Blender bone Y <- NS2 bone X (det +1)

bpy.ops.wm.read_factory_settings(use_empty=True)
bones, _, _ = read_bones(IN)
verts, tris, facesets = read_mesh(IN)
name = os.path.splitext(os.path.basename(IN))[0]

# world matrices in NS2 space
world = []
for b in bones:
    f = b["f"]
    local = Matrix.Translation(Vector(f[0:3])) @ Quaternion((f[6], f[3], f[4], f[5])).to_matrix().to_4x4()
    world.append(local if b["parent"] < 0 else world[b["parent"]] @ local)

arm_data = bpy.data.armatures.new(name + "_skeleton")
arm = bpy.data.objects.new(name + "_skeleton", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
children = {}
for i, b in enumerate(bones):
    children.setdefault(b["parent"], []).append(i)
ebs = []
for i, b in enumerate(bones):
    eb = arm_data.edit_bones.new(b["name"])
    m = C @ world[i] @ BONE_FIX
    # length: distance to the first child along the bone, else a default
    ln = 0.05
    for c in children.get(i, []):
        d = (world[c].translation - world[i].translation).length
        if d > 0.01: ln = d; break
    eb.head = (0, 0, 0); eb.tail = (0, ln, 0)
    eb.matrix = m
    ebs.append(eb)
for i, b in enumerate(bones):
    if b["parent"] >= 0:
        ebs[i].parent = ebs[b["parent"]]
bpy.ops.object.mode_set(mode='OBJECT')
for i, b in enumerate(bones):
    pb = arm.pose.bones[b["name"]]
    pb["ns2_index"] = i
    pb["ns2_pos"] = list(b["f"][0:3]); pb["ns2_quat"] = list(b["f"][3:7]); pb["ns2_extra"] = list(b["f"][7:])
arm["ns2_bone_order"] = [b["name"] for b in bones]

# mesh
me = bpy.data.meshes.new(name)
cv = [tuple(C @ Vector(v[0])) for v in verts]
me.from_pydata(cv, [], [t for t, _ in tris])
me.update()
uvl = me.uv_layers.new(name="UVMap")
for poly in me.polygons:
    for li in poly.loop_indices:
        u, v = verts[me.loops[li].vertex_index][2]
        uvl.data[li].uv = (u, 1 - v)
mats = read_materials(IN)
for mpath in mats:
    me.materials.append(bpy.data.materials.new(os.path.basename(mpath)))
for poly, (_, mi) in zip(me.polygons, tris):
    poly.material_index = mi
ob = bpy.data.objects.new(name, me)
bpy.context.scene.collection.objects.link(ob)
for b in bones:
    ob.vertex_groups.new(name=b["name"])
for vi, v in enumerate(verts):
    for bi, w in v[3]:
        ob.vertex_groups[bi].add([vi], w, 'ADD')
ob.parent = arm
mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
for p in me.polygons: p.use_smooth = True

# report handedness: left arm should be on +X when facing -Y
la = arm.data.bones.get("LArm_Shoulder ") or next((bb for bb in arm.data.bones if bb.name.startswith("LArm_Shoulder")), None)
print("CHECK left shoulder x =", round(la.head_local.x, 3) if la else None,
      "| height", round(max(v[2] for v in cv), 3), "| facing: nose y =",
      round(arm.data.bones["Head"].head_local.y, 3) if "Head" in arm.data.bones else None)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT, "bones", len(bones), "verts", len(verts), "tris", len(tris))

if PREV:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_xray = False
    sc.render.resolution_x = 700; sc.render.resolution_y = 900
    arm.show_in_front = True; arm_data.display_type = 'STICK'
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 2.2
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
    c = Vector((0, 0, 0.95))
    for vname, pos in {"front": (0, -5, 0), "side": (5, 0, 0)}.items():
        cam.location = c + Vector(pos)
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(PREV, f"{name}_{vname}.png")
        bpy.ops.render.render(write_still=True)
