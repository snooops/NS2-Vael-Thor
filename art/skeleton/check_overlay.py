import bpy, sys, os, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
REF, ROBOT_BLEND, OUTDIR = args
bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
marine = next(o for o in sc.objects if o.type == 'MESH')

def render(tag, views):
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = 700; sc.render.resolution_y = 900
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 2.2
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
    c = Vector((0, 0, 0.95))
    for vname, pos in views.items():
        cam.location = c + Vector(pos)
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(OUTDIR, f"{tag}_{vname}.png")
        bpy.ops.render.render(write_still=True)

# 1) deformation test: bend left arm forward, right knee, head turn
def rot(name, axis, deg):
    pb = arm.pose.bones[name]; pb.rotation_mode = 'XYZ'
    e = [0, 0, 0]; e["XYZ".index(axis)] = math.radians(deg); pb.rotation_euler = e
rot(next(b.name for b in arm.pose.bones if b.name.startswith("LArm_Shoulder")), 'Z', 60)
rot("RLeg_Knee", 'Z', 60)
rot("Head", 'X', 35)
render("deformtest", {"front34": (3.5, -3.5, 0.5)})
for pb in arm.pose.bones:
    pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)

# 2) overlay with robot
with bpy.data.libraries.load(ROBOT_BLEND) as (src, dst):
    dst.objects = ["robot"]
robot = dst.objects[0]; sc.collection.objects.link(robot)
sc.display.shading.color_type = 'OBJECT'
marine.color = (0.2, 0.8, 0.3, 1); robot.color = (0.9, 0.5, 0.2, 1)
sc.display.shading.show_xray = True; sc.display.shading.xray_alpha = 0.5
render("overlay", {"front": (0, -5, 0), "side": (5, 0, 0)})
