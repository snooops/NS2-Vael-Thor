"""Check render: a model's rest-pose mesh + blade triangles (NS2 space JSON), close-ups of both hands.
Usage: blender -b --factory-startup -P render_blades_check.py -- <imported.blend> <tris.json> <out_prefix>"""
import bpy, sys, json
from mathutils import Vector
blend, tj, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
body = next(o for o in sc.objects if o.type == 'MESH')
body.modifiers.clear()                                     # rest pose = stored vertex positions
for o in [o for o in sc.objects if o.type == 'ARMATURE']: bpy.data.objects.remove(o)
tris = json.load(open(tj))
verts, faces = [], []
for t in tris:
    base = len(verts)
    for v in t:
        x, y, z = v["p"]; verts.append((x, -z, y))           # NS2 -> Blender
    faces.append((base, base + 1, base + 2))
me = bpy.data.meshes.new("blades"); me.from_pydata(verts, [], faces); me.update()
bl = bpy.data.objects.new("blades", me); sc.collection.objects.link(bl)
m = bpy.data.materials.new("glow"); m.diffuse_color = (0.75, 0.35, 1.0, 1); me.materials.append(m)
mb = bpy.data.materials.new("skin"); mb.diffuse_color = (0.55, 0.55, 0.58, 1)
body.data.materials.clear(); body.data.materials.append(mb)
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
sc.render.resolution_x = 800; sc.render.resolution_y = 600
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 1.1
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
for side in (-1, 1):
    pts = [Vector(v) for v in verts if v[0] * side > 0]
    c = sum(pts, Vector()) / len(pts)
    for tag, off in (("front", Vector((0, -2.5, 0.3))), ("out", Vector((side * 2.5, -0.6, 0.5)))):
        cam.location = c + off; cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = f"{out}_{'R' if side < 0 else 'L'}_{tag}.png"; bpy.ops.render.render(write_still=True)
