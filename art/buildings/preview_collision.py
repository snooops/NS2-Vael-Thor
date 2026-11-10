"""Collision check render: the building in grey, its collision hulls in translucent orange, three views
(front, side, 3/4). Usage: blender -b --factory-startup -P preview_collision.py -- <name>_prepared.blend <name> <out.png>"""
import bpy, sys, math
from mathutils import Vector
blend, name, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
ob = sc.objects[name]
grey = bpy.data.materials.new("grey"); grey.diffuse_color = (0.55, 0.57, 0.62, 1)
hullm = bpy.data.materials.new("hull"); hullm.diffuse_color = (1.0, 0.45, 0.1, 0.45)
ob.data.materials.clear(); ob.data.materials.append(grey)
for o in sc.objects:
    if o.name.startswith("Hull"):
        o.data.materials.clear(); o.data.materials.append(hullm)
        o.show_wire = True
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_xray = False
sc.render.film_transparent = False
sc.render.resolution_x, sc.render.resolution_y = 512, 640
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.18, 0.19, 0.22)
zs = [v.co.z for v in ob.data.vertices]; h = max(zs)
r = max(max(abs(v.co.x), abs(v.co.y)) for v in ob.data.vertices)
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = max(h, 2 * r) * 1.15
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
import os
parts = []
for i, (az, el) in enumerate(((0, 0), (math.pi / 2, 0), (0.7, 0.5))):
    centre = Vector((0, 0, h * 0.5)); d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
    cam.location = centre + d * (h + 2 * r + 5); cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    p = out.replace(".png", f"_{i}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True); parts.append(p)
imgs = [bpy.data.images.load(p) for p in parts]
W, H = imgs[0].size
big = bpy.data.images.new("all", W * 3, H)
px = [0.0] * (W * 3 * H * 4)
for k, im in enumerate(imgs):
    src = list(im.pixels)
    for y in range(H):
        row = src[y * W * 4:(y + 1) * W * 4]
        o = (y * W * 3 + k * W) * 4
        px[o:o + W * 4] = row
big.pixels = px; big.filepath_raw = out; big.file_format = "PNG"; big.save()
for p in parts: os.remove(p)
print("PREVIEW", out)
