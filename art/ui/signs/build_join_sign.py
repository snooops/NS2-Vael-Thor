"""3D "VAEL'THOR" ready room sign in the frame of the vanilla sign model (marine_join.model):
letters along X, up Y, front facing +Z, height <= 0.313 m (y 0.191-0.504), depth z 0.054-0.105, centred x 0.014.
Extruded + bevelled text in the vanilla sign font. UVs by face normal (like vanilla):
  front / back faces -> dark letter fill (texture rows 64-255, u = position along the text)
  bevels / sides     -> bright violet bar   (texture v 0.02-0.13), so every letter gets a bright rim
Usage: blender -b --factory-startup -P build_join_sign.py -- <font.ttf> <texture.tga> <out.fbx> <text>
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

FONT, TGA, OUT, TEXT = sys.argv[sys.argv.index("--") + 1:]

# vanilla frame (engine units = metres)
Y0, Y1 = 0.191, 0.504
Z0, Z1 = 0.054, 0.105
X_CENTRE = 0.014
MAX_W = 2.05
SCALE = 1.5           # letters bigger than the vanilla frame, grown around its centre (user: +50%)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

cu = bpy.data.curves.new("sign", type="FONT")
cu.body = TEXT
cu.font = bpy.data.fonts.load(FONT)
cu.align_x = "CENTER"
cu.size = 1.0
cu.extrude = 0.5 * 0.08          # scaled later; bevel/extrude ratio is what matters
cu.bevel_depth = 0.012
cu.bevel_resolution = 0
ob = bpy.data.objects.new("sign", cu)
bpy.context.scene.collection.objects.link(ob)

# to mesh
dg = bpy.context.evaluated_depsgraph_get()
me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
mo = bpy.data.objects.new("vt_join_sign", me)
bpy.context.scene.collection.objects.link(mo)
bpy.data.objects.remove(ob)

bm = bmesh.new()
bm.from_mesh(me)

# scale/translate in Blender text space (x along text, y up, z depth) to the vanilla frame
lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
w, h, d = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
k = min((Y1 - Y0) / h, MAX_W / w) * SCALE
kz = (Z1 - Z0) / d
for v in bm.verts:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * k + X_CENTRE,
                   (v.co.y - (lo.y + hi.y) / 2) * k + (Y0 + Y1) / 2,
                   (v.co.z - lo.z) * kz + Z0))
bm.normal_update()
print("SIZE %.3f x %.3f x %.3f m" % (w * k, h * k, d * kz))

# UVs by normal
uv = bm.loops.layers.uv.new("UVMap")
x_lo = min(v.co.x for v in bm.verts); x_hi = max(v.co.x for v in bm.verts)
y_lo = min(v.co.y for v in bm.verts); y_hi = max(v.co.y for v in bm.verts)
for f in bm.faces:
    nz = f.normal.z
    for l in f.loops:
        p = l.vert.co
        if abs(nz) > 0.9:                                   # front / back: dark fill, u along the text
            u = 0.04 + 0.92 * (p.x - x_lo) / (x_hi - x_lo)
            vv = 0.30 + 0.62 * (1 - (p.y - y_lo) / (y_hi - y_lo))   # brighter (texture top of fill) at the top
        else:                                               # bevel / side: bright bar
            u = 0.04 + 0.92 * (p.x - x_lo) / (x_hi - x_lo)
            vv = 0.02 + 0.11 * (p.z - Z0) / (Z1 - Z0)
        l[uv].uv = (u, 1 - vv)                              # Blender UV origin is bottom-left
bm.to_mesh(me)
bm.free()

# Blender (Z up) <- engine frame (Y up, front +Z): text up = Blender +Z. With the FBX export
# (axis_forward=-Z, axis_up=Y) this lands in the vanilla frame: front +Z, reading like marine_join.model
# (checked by projecting both models' +Z faces).
me.transform(Matrix.Rotation(math.radians(90), 4, "X"))

mat = bpy.data.materials.new("vt_join_sign")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(TGA)
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
me.materials.append(mat)

for o in bpy.context.scene.objects:
    o.select_set(o is mo)
bpy.context.view_layer.objects.active = mo
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"},
                         apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                         axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_tspace=True,
                         path_mode="ABSOLUTE")
print("EXPORTED", OUT, len(me.polygons), "faces")
