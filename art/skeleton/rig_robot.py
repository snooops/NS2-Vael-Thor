"""Fit the NS2 marine skeleton to the robot mesh and transfer the marine's skin weights.

Usage: blender -b --factory-startup -P rig_robot.py -- <marine_reference.blend> <robot_lowpoly.blend> <out.blend> <preview_dir>
Only bone *positions* are changed; every bone keeps the marine's world rotation.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
import numpy as np

REF, ROBOT_BLEND, OUT, PREV = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
marine = next(o for o in sc.objects if o.type == 'MESH')
with bpy.data.libraries.load(ROBOT_BLEND) as (src, dst):
    dst.objects = ["robot"]
robot = dst.objects[0]; sc.collection.objects.link(robot)

def world_verts(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg); m = e.to_mesh()
    a = np.array([ob.matrix_world @ v.co for v in m.vertices]); e.to_mesh_clear(); return a

MV, RV = world_verts(marine), world_verts(robot)
bones = arm.data.bones
head = {b.name: b.head_local.copy() for b in bones}

def slab_centroid(V, p, n, side, radius, lateral_min=None):
    n = n.normalized(); d = (V - np.array(p)) @ np.array(n)
    sel = np.abs(d) < 0.03
    sel &= np.linalg.norm(V - np.array(p), axis=1) < radius
    if side: sel &= np.sign(V[:, 0]) == side
    if lateral_min is not None: sel &= np.abs(V[:, 0]) > lateral_min
    if sel.sum() < 8: return None
    return Vector(V[sel].mean(0))

delta = {}
UP = Vector((0, 0, 1))
NOFIT = bool(os.environ.get("VT_NOFIT"))  # mesh already fitted to the marine skeleton: keep bones exactly
if NOFIT: print("FIT disabled (VT_NOFIT) - marine skeleton kept unchanged")
def fit(name, n, side, radius, lateral_min=None, axes=(1, 1, 0), scale=1.0):
    if NOFIT: return
    p = head[name]
    cm = slab_centroid(MV, p, n, side, radius, lateral_min)
    cr = slab_centroid(RV, p, n, side, radius + 0.12, lateral_min)
    if cm is None or cr is None:
        print("FIT skip", name); return
    dv = (cr - cm) * scale
    delta[name] = Vector((dv.x * axes[0], dv.y * axes[1], dv.z * axes[2]))
    print(f"FIT {name:16} {tuple(round(x, 3) for x in delta[name])}")

# torso column (front/back only)
for nm in ("Hip", "Spine1", "Spine2", "Spine3", "Neck", "Head"):
    fit(nm, UP, 0, 0.35, axes=(0, 1, 0))
# legs
for s, L in ((1, "LLeg"), (-1, "RLeg")):
    for j in ("_Hip", "_Knee", "_Ankle"):
        fit(L + j, UP, s, 0.3, lateral_min=0.02)
    if NOFIT: continue
    delta[L + "_Toe"] = delta.get(L + "_Ankle", Vector()).copy()
# arms: slab perpendicular to the upper arm / forearm
for s, A, H, W in ((1, "LArm", "LHand", "LArm_Wrist02"), (-1, "RArm", "RHand", "RArm_Wrist01")):
    up_dir = head[A + "_Elbow"] - head[A + "_Shoulder"]
    fo_dir = head[W] - head[A + "_Elbow"]
    fit(A + "_Elbow", up_dir, s, 0.25, lateral_min=abs(head[A + "_Elbow"].x) - 0.10, axes=(1, 1, 1))
    fit(W, fo_dir, s, 0.25, lateral_min=abs(head[W].x) - 0.10, axes=(1, 1, 1))
    # hand tip along the forearm (captures longer robot arms)
    def tip(V):
        o = np.array(head[A + "_Elbow"]); d = np.array(fo_dir.normalized())
        rel = V - o; t = rel @ d
        perp = np.linalg.norm(rel - np.outer(t, d), axis=1)
        sel = (np.sign(V[:, 0]) == s) & (perp < 0.18) & (t > 0)
        return np.percentile(t[sel], 99) if sel.sum() > 20 else None
    tm, tr = (None, None) if NOFIT else (tip(MV), tip(RV))
    if tm is not None and tr is not None:
        extra = fo_dir.normalized() * (tr - tm) * 0.8
        delta[W] = delta.get(W, Vector()) + Vector(extra)
        print(f"FIT {W:16} +length {tr - tm:.3f}")
    if NOFIT: continue
    e = delta.get(A + "_Elbow", Vector())
    delta[A + "_Shoulder"] = Vector((e.x * 0.7, e.y * 0.5, 0))
    delta[A + "_Clavicle"] = Vector((e.x * 0.35, e.y * 0.3, 0))

# propagate: bones without a fitted delta move rigidly with their nearest fitted ancestor
full = {}
for b in bones:  # bones are ordered parent-first
    if b.name in delta: full[b.name] = delta[b.name]
    elif b.parent: full[b.name] = full[b.parent.name].copy()
    else: full[b.name] = Vector()

# 1) pose the marine into the fitted layout and freeze the deformed mesh as the weight source
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
for b in bones:
    pb = arm.pose.bones[b.name]
    pb.matrix = Matrix.Translation(full[b.name]) @ b.matrix_local
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode='OBJECT')
dg = bpy.context.evaluated_depsgraph_get()
src_mesh = bpy.data.meshes.new_from_object(marine.evaluated_get(dg))
src = bpy.data.objects.new("marine_fitted", src_mesh); sc.collection.objects.link(src)
src.matrix_world = marine.matrix_world
for vg in marine.vertex_groups: src.vertex_groups.new(name=vg.name)
for v in marine.data.vertices:
    for g in v.groups: src.vertex_groups[g.group].add([v.index], g.weight, 'REPLACE')

# 2) make the fitted pose the new rest pose
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')

# 3) transfer weights to the robot
for vg in src.vertex_groups: robot.vertex_groups.new(name=vg.name)
dt = robot.modifiers.new("dt", 'DATA_TRANSFER'); dt.object = src
dt.use_vert_data = True; dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'
dt.layers_vgroup_select_src = 'ALL'; dt.layers_vgroup_select_dst = 'NAME'
bpy.context.view_layer.objects.active = robot
for o in sc.objects: o.select_set(o == robot)
bpy.ops.object.modifier_apply(modifier="dt")

# 3b) automatic weights on a clean deform set; transferred weights stay only where heat fails
DEFORM = {"Hip", "Crotch", "Spine1", "Spine2", "Spine3", "Neck", "Head",
          "LLeg_Hip", "LLeg_Knee", "LLeg_Ankle", "LLeg_Toe", "RLeg_Hip", "RLeg_Knee", "RLeg_Ankle", "RLeg_Toe",
          "LArm_Clavicle", "LArm_Shoulder", "LArm_Elbow", "LArm_Wrist02",
          "RArm_Clavicle", "RArm_Shoulder", "RArm_Elbow", "RArm_Wrist01"}
DEFORM |= {b.name for b in bones if ("Hand_" in b.name and "Weapon" not in b.name and not b.name.endswith("_Wrist"))}
transferred = {v.index: [(robot.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in robot.data.vertices}
for b in arm.data.bones: b.use_deform = b.name in DEFORM
robot.vertex_groups.clear()
for o in sc.objects: o.select_set(o in (robot, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for b in arm.data.bones: b.use_deform = True
robot.modifiers.clear()
fallback = 0
for v in robot.data.vertices:
    if not any(g.weight > 0.001 for g in v.groups):
        fallback += 1
        for name, w in transferred[v.index]:
            if name not in robot.vertex_groups: robot.vertex_groups.new(name=name)
            robot.vertex_groups[name].add([v.index], w, 'REPLACE')
print("AUTO weights done, fallback verts", fallback)

# 4) merge accessory bones into their parents, cap to 4 influences
MERGE = ("Face_", "Belt_", "Strap_", "BodyArmor_", "JetPack", "Pack", "KneeCap", "ShldrPad", "ForearmPad")
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
unweighted = sum(1 for inf in W.values() if not inf)
print("ROBOT verts", len(robot.data.vertices), "unweighted", unweighted)

robot.parent = arm
robot.modifiers.clear()
m = robot.modifiers.new("Armature", 'ARMATURE'); m.object = arm
bpy.data.objects.remove(src); bpy.data.objects.remove(marine)
arm.name = "robot_skeleton"
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)

# previews: rest + a test pose
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 700; sc.render.resolution_y = 900
w = bpy.data.worlds.new("w"); sc.world = w
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.38, 1)
ld = bpy.data.lights.new("sun", 'SUN'); ld.energy = 3
lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo); lo.rotation_euler = (math.radians(50), 0, math.radians(-30))
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 2.3
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, 0, 0.95))
def shot(tag, pos):
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(PREV, f"rig_{tag}.png"); bpy.ops.render.render(write_still=True)
shot("rest_front34", (3.5, -3.5, 0.5))
def rot(name, axis, deg):
    pb = arm.pose.bones[name]; pb.rotation_mode = 'XYZ'
    e = [0, 0, 0]; e["XYZ".index(axis)] = math.radians(deg); pb.rotation_euler = e
rot("LArm_Shoulder", 'Z', 70); rot("LArm_Elbow", 'Z', 60)
rot("RArm_Shoulder", 'Z', 70); rot("RArm_Elbow", 'Z', 80)
rot("RLeg_Hip", 'Z', 50); rot("RLeg_Knee", 'Z', -70)
rot("Spine2", 'Z', 15); rot("Head", 'Y', 30)
shot("pose_front34", (3.5, -3.5, 0.5))
shot("pose_side", (5, 0, 0))
