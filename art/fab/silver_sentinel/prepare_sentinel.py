"""Silver Sentinel: T-pose biped -> marine A-pose static mesh, normalised for the NS2 rig pipeline.

Usage: blender -b --factory-startup -P prepare_sentinel.py -- <Character_output.fbx> <marine_reference.blend> <tex_dir> <out.blend> <preview_dir>
Uses the biped's own 24-bone rig only to swing the limbs into the marine's limb directions, then applies it.
Output object is called "robot" (the name rig_robot.py expects); its joints sit exactly on the marine joints.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix

IN, REF, TEX, OUT, PREV = sys.argv[sys.argv.index("--") + 1:]
HEIGHT = 1.9

# marine joint positions (Blender space, facing -Y)
bpy.ops.wm.open_mainfile(filepath=REF)
marm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
MJ = {b.name: (marm.matrix_world @ b.head_local) for b in marm.data.bones}

# sentinel bone -> marine joint its head must land on
MAP = {"Hips": "Hip", "Spine02": "Spine1", "Spine01": "Spine2", "Spine": "Spine3", "neck": "Neck", "Head": "Head",
       "LeftShoulder": "LArm_Clavicle", "LeftArm": "LArm_Shoulder", "LeftForeArm": "LArm_Elbow", "LeftHand": "LArm_Wrist02",
       "RightShoulder": "RArm_Clavicle", "RightArm": "RArm_Shoulder", "RightForeArm": "RArm_Elbow", "RightHand": "RArm_Wrist01",
       "LeftUpLeg": "LLeg_Hip", "LeftLeg": "LLeg_Knee", "LeftFoot": "LLeg_Ankle", "LeftToeBase": "LLeg_Toe",
       "RightUpLeg": "RLeg_Hip", "RightLeg": "RLeg_Knee", "RightFoot": "RLeg_Ankle", "RightToeBase": "RLeg_Toe"}
NEXT = {"Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head",
        "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
        "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
        "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
        "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase"}
# bones with no mapped child keep their length and point along the marine bone's direction
END_DIR = {"LeftHand": ("LArm_Elbow", "LArm_Wrist02"), "RightHand": ("RArm_Elbow", "RArm_Wrist01"),
           "LeftToeBase": ("LLeg_Ankle", "LLeg_Toe"), "RightToeBase": ("RLeg_Ankle", "RLeg_Toe")}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=IN)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
mesh = next(o for o in sc.objects if o.type == 'MESH')

def bworld(name):
    return arm.matrix_world @ arm.data.bones[name].head_local
fwd = bworld("headfront") - bworld("Head"); fwd.z = 0
print("FACING forward", tuple(round(x, 3) for x in fwd))
if fwd.y > 0:
    arm.matrix_world = Matrix.Rotation(math.pi, 4, 'Z') @ arm.matrix_world
bpy.context.view_layer.update()
if bworld("LeftArm").x < 0:
    raise SystemExit("left/right mismatch - mesh is mirrored relative to marine")

# uniform scale so the head joint height matches the marine; feet on the floor
zs = [(mesh.matrix_world @ v.co).z for v in mesh.data.vertices]
z0 = min(zs)
s = MJ["Head"].z / (bworld("Head").z - z0)
arm.matrix_world = Matrix.Translation((0, 0, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -z0)) @ arm.matrix_world
bpy.context.view_layer.update()
print("SIZE scale", round(s, 3), "height", round((max(zs) - z0) * s, 3))

# retarget: every mapped joint onto the marine joint, bones stretched along their length
for b in arm.data.bones:
    b.inherit_scale = 'NONE'
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
inv = arm.matrix_world.inverted()
A = lambda v: inv @ v                      # world point -> armature space
order = [b.name for b in arm.data.bones]  # parent-first
for name in order:
    if name not in MAP: continue
    pb = arm.pose.bones[name]
    cur = pb.matrix.copy()                 # armature space, unit scale
    head_w = arm.matrix_world @ cur.translation
    ydir = (cur.to_3x3().normalized() @ Vector((0, 1, 0))).normalized()
    length = pb.bone.length
    th = A(MJ[MAP[name]])
    if name in NEXT:
        tt = A(MJ[MAP[NEXT[name]]]); new_len = (tt - th).length; tdir = (tt - th).normalized()
    elif name in END_DIR:
        a_, b_ = END_DIR[name]; tdir = (A(MJ[b_]) - A(MJ[a_])).normalized(); new_len = length
    else:
        tdir = ydir; new_len = length
    R = ydir.rotation_difference(tdir).to_matrix() @ cur.to_3x3().normalized()
    stretch = new_len / length if length > 1e-9 else 1.0
    pb.matrix = Matrix.Translation(th) @ R.to_4x4() @ Matrix.Diagonal((1, stretch, 1, 1))
    bpy.context.view_layer.update()
    got = arm.matrix_world @ pb.head
    tgt = MJ[MAP[name]]
    print(f"FITJ {name:13} -> {MAP[name]:14} moved {(tgt - head_w).length*100:5.1f} cm  stretch {stretch:4.2f}  err {(got - tgt).length*1000:.1f} mm")
bpy.ops.object.mode_set(mode='OBJECT')

dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(mesh.evaluated_get(dg))
robot = bpy.data.objects.new("robot", me); sc.collection.objects.link(robot)
robot.matrix_world = mesh.matrix_world.copy()
bpy.data.objects.remove(mesh); bpy.data.objects.remove(arm)
for o in sc.objects: o.select_set(o == robot)
bpy.context.view_layer.objects.active = robot
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
robot.vertex_groups.clear()
print("SIZE final height", round(max(v.co.z for v in robot.data.vertices), 3))

# preview material from the supplied PBR maps
mat = bpy.data.materials.new("robot_preview"); mat.use_nodes = True
nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
def img(fn, noncolor):
    n = nt.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(os.path.join(TEX, fn))
    if noncolor: n.image.colorspace_settings.name = 'Non-Color'
    return n
nt.links.new(img("bake_albedo.png", False).outputs['Color'], bsdf.inputs['Base Color'])
nt.links.new(img("bake_metallic.png", True).outputs['Color'], bsdf.inputs['Metallic'])
nt.links.new(img("bake_roughness.png", True).outputs['Color'], bsdf.inputs['Roughness'])
nm = nt.nodes.new('ShaderNodeNormalMap')
nt.links.new(img("bake_normal.png", True).outputs['Color'], nm.inputs['Color'])
nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
robot.data.materials.clear(); robot.data.materials.append(mat)
for p in robot.data.polygons: p.use_smooth = True
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)

# previews
sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = 700; sc.render.resolution_y = 900
w = bpy.data.worlds.new("w"); sc.world = w
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.38, 1)
ld = bpy.data.lights.new("sun", 'SUN'); ld.energy = 3
lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo); lo.rotation_euler = (math.radians(50), 0, math.radians(-30))
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 2.3
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, 0, 0.95))
for vname, pos in {"front": (0, -5, 0), "side": (5, 0, 0)}.items():
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(PREV, f"apose_{vname}.png"); bpy.ops.render.render(write_still=True)
