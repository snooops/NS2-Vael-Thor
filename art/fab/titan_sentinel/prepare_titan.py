"""Titan Sentinel: T-pose biped -> Exosuit (dual minigun) pose, normalised for the exo rig pipeline.

Usage: blender -b --factory-startup -P prepare_titan.py -- <Character_output.fbx> <exo_mm_reference.blend> <tex_dir> <out.blend> <preview_dir>
Like silver_sentinel/prepare_sentinel.py, but the joint targets come from the Exosuit skeleton:
the Titan's own 24-bone rig swings its limbs onto the exo joints, then is applied. Output object "robot".
The exo faces -Y; its forearms point forward (wrist = minigun mount), legs are digitigrade.
The Titan's ankle goes on the exo's lower foot joint (Exosuit_*Foot) so its feet stay on the floor.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix

IN, REF, TEX, OUT, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]

bpy.ops.wm.open_mainfile(filepath=REF)
earm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
EJ = {b.name: (earm.matrix_world @ b.head_local) for b in earm.data.bones}

def mid(a, b, t=0.5): return a.lerp(b, t)
clav_mid = mid(EJ["Exosuit_LClavicle"], EJ["Exosuit_RClavicle"])
pelvis = EJ["Exosuit_Pelvis"]
FWD = Vector((0, -1, 0))
# target points (Blender space) for every biped joint
T = {
    "Hips": pelvis,
    "Spine02": mid(pelvis, clav_mid, 0.20),
    "Spine01": mid(pelvis, clav_mid, 0.45),
    "Spine":   mid(pelvis, clav_mid, 0.75),
    "neck":    clav_mid + Vector((0, -0.05, 0.05)),
    "Head":    clav_mid + Vector((0, -0.10, 0.20)),
}
for s, S in (("Left", "L"), ("Right", "R")):
    T[s + "Shoulder"] = EJ[f"Exosuit_{S}Clavicle"]
    T[s + "Arm"]      = EJ[f"Exosuit_{S}Shldr"]
    T[s + "ForeArm"]  = EJ[f"Exosuit_{S}Elbow"]
    T[s + "Hand"]     = EJ[f"Exosuit_{S}Wrist"]
    T[s + "UpLeg"]    = EJ[f"Exosuit_{S}Hip2"]
    T[s + "Leg"]      = EJ[f"Exosuit_{S}Knee"]
    T[s + "Foot"]     = EJ[f"Exosuit_{S}Foot"]
    T[s + "ToeBase"]  = EJ[f"Exosuit_{S}Foot"] + Vector((0, -0.18, -0.12))

NEXT = {"Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head"}
for s in ("Left", "Right"):
    NEXT.update({s + "Shoulder": s + "Arm", s + "Arm": s + "ForeArm", s + "ForeArm": s + "Hand",
                 s + "UpLeg": s + "Leg", s + "Leg": s + "Foot", s + "Foot": s + "ToeBase"})
# end bones keep their length and point along a fixed direction
END_DIR = {"LeftHand": FWD, "RightHand": FWD, "LeftToeBase": FWD, "RightToeBase": FWD, "Head": Vector((0, 0, 1))}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=IN)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
mesh = next(o for o in sc.objects if o.type == 'MESH')
missing = [n for n in T if n not in arm.data.bones]
if missing: raise SystemExit(f"biped bones missing: {missing}")

def bworld(name): return arm.matrix_world @ arm.data.bones[name].head_local
fwd = bworld("headfront") - bworld("Head") if "headfront" in arm.data.bones else Vector((0, -1, 0))
fwd.z = 0
print("FACING forward", tuple(round(x, 3) for x in fwd))
if fwd.y > 0:
    arm.matrix_world = Matrix.Rotation(math.pi, 4, 'Z') @ arm.matrix_world
bpy.context.view_layer.update()
if bworld("LeftArm").x < 0:
    raise SystemExit("left/right mismatch - mesh is mirrored relative to exo")

# uniform scale: biped shoulder height -> exo shoulder height; feet on the floor
zs = [(mesh.matrix_world @ v.co).z for v in mesh.data.vertices]
z0 = min(zs)
s = T["LeftArm"].z / (bworld("LeftArm").z - z0)
arm.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -z0)) @ arm.matrix_world
bpy.context.view_layer.update()
print("SIZE scale", round(s, 3), "height", round((max(zs) - z0) * s, 3))

for b in arm.data.bones:
    b.inherit_scale = 'NONE'
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
inv = arm.matrix_world.inverted()
A = lambda v: inv @ v
for name in [b.name for b in arm.data.bones]:   # parent-first
    if name not in T: continue
    pb = arm.pose.bones[name]
    cur = pb.matrix.copy()
    head_w = arm.matrix_world @ cur.translation
    ydir = (cur.to_3x3().normalized() @ Vector((0, 1, 0))).normalized()
    length = pb.bone.length
    th = A(T[name])
    if name in NEXT:
        tt = A(T[NEXT[name]]); new_len = (tt - th).length; tdir = (tt - th).normalized()
    elif name in END_DIR:
        tdir = (inv.to_3x3() @ END_DIR[name]).normalized(); new_len = length
    else:
        tdir = ydir; new_len = length
    R = ydir.rotation_difference(tdir).to_matrix() @ cur.to_3x3().normalized()
    stretch = new_len / length if length > 1e-9 else 1.0
    pb.matrix = Matrix.Translation(th) @ R.to_4x4() @ Matrix.Diagonal((1, stretch, 1, 1))
    bpy.context.view_layer.update()
    got = arm.matrix_world @ pb.head
    print(f"FITJ {name:13} moved {(T[name] - head_w).length*100:5.1f} cm  stretch {stretch:4.2f}  err {(got - T[name]).length*1000:.1f} mm")
bpy.ops.object.mode_set(mode='OBJECT')

dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(mesh.evaluated_get(dg))
robot = bpy.data.objects.new("robot", me); sc.collection.objects.link(robot)
robot.matrix_world = mesh.matrix_world.copy()
bpy.data.objects.remove(mesh); bpy.data.objects.remove(arm)
for o in list(sc.objects):
    if o is not robot: bpy.data.objects.remove(o)
for o in sc.objects: o.select_set(o == robot)
bpy.context.view_layer.objects.active = robot
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
robot.vertex_groups.clear()
print("SIZE final height", round(max(v.co.z for v in robot.data.vertices), 3))

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

sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = 800; sc.render.resolution_y = 900
w = bpy.data.worlds.new("w"); sc.world = w
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.38, 1)
ld = bpy.data.lights.new("sun", 'SUN'); ld.energy = 3
lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo); lo.rotation_euler = (math.radians(50), 0, math.radians(-30))
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 3.3
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, -0.1, 1.4))
for vname, pos in {"front": (0, -6, 0), "side": (6, 0, 0), "front34": (4.5, -4.5, 0.8)}.items():
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(PREV, f"exopose_{vname}.png"); bpy.ops.render.render(write_still=True)
