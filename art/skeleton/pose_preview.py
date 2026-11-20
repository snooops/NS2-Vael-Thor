"""Pose test renders of a rigged player model (rest + a few marine-skeleton poses), Cycles with its textures.
Usage: blender -b --factory-startup -P pose_preview.py -- <rigged.blend> <out_prefix>
"""
import bpy, sys, math
from mathutils import Vector
BLEND, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 700, 900
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.5, 0.55, 1)
for d, e in (((50, 0, -30), 4), ((60, 0, 150), 2)):
    ld = bpy.data.lights.new("sun", "SUN"); ld.energy = e
    lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo); lo.rotation_euler = [math.radians(x) for x in d]
cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = 2.4
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, 0, 0.95))
def shot(tag, pos):
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (OUT, tag); bpy.ops.render.render(write_still=True); print("POSE", tag)
def rot(name, axis, deg):
    pb = arm.pose.bones[name]; pb.rotation_mode = "XYZ"
    e = [0, 0, 0]; e["XYZ".index(axis)] = math.radians(deg); pb.rotation_euler = e
shot("rest", (3.5, -3.5, 0.5))
rot("LArm_Shoulder", "Z", 70); rot("LArm_Elbow", "Z", 60)
rot("RArm_Shoulder", "Z", 70); rot("RArm_Elbow", "Z", 80)
rot("RLeg_Hip", "Z", 50); rot("RLeg_Knee", "Z", -70)
rot("Spine2", "Z", 15); rot("Head", "Y", 30)
shot("pose", (3.5, -3.5, 0.5))
shot("pose_side", (5, 0, 0))
