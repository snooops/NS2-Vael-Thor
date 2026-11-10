import bpy, sys, os, math
from mathutils import Vector
IN, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == 'MESH']
for o in meshes:
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector([min(p[k] for p in pts) for k in range(3)]); hi = Vector([max(p[k] for p in pts) for k in range(3)])
    print(f"PART {o.name:24} min {tuple(round(x,2) for x in lo)} max {tuple(round(x,2) for x in hi)} n={len(pts)}")
# slices along the long axis: vertical extent per slice shows where grip/magazine hang down
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
xs = [p.y for p in pts]; x0, x1 = min(xs), max(xs)
for i in range(16):
    a = x0 + (x1 - x0) * i / 16; b = x0 + (x1 - x0) * (i + 1) / 16
    s = [p for p in pts if a <= p.y < b]
    if s: print(f"SLICE y {a:7.2f}..{b:7.2f}  z {min(p.z for p in s):6.2f}..{max(p.z for p in s):6.2f}  x {min(p.x for p in s):6.2f}..{max(p.x for p in s):6.2f}")
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x = 1000; sc.render.resolution_y = 500
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = (x1 - x0) * 1.15
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, (x0 + x1) / 2, sum(p.z for p in pts) / len(pts)))
cam.location = c + Vector((100, 0, 0)); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = os.path.join(PREV, "falcon_side.png"); bpy.ops.render.render(write_still=True)
