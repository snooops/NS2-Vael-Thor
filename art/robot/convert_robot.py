"""Convert a high-poly textured FBX (e.g. Tripo/Fab robot.fbx) into an NS2-ready low-poly mesh.

Usage:
  blender -b --factory-startup -P convert_robot.py -- <in.fbx> <art_dir> <modelsrc_dir> [target_tris]

Produces in <art_dir>:
  robot_lowpoly.blend, bake_*.png (albedo, normal, metallic, roughness), preview_*.png
Produces in <modelsrc_dir>:
  robot.fbx  (low-poly, UVs, material named 'robot' with texture path robot.tga)
"""
import bpy, bmesh, sys, os, math, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
IN_FBX, ART, MSRC = args[0], args[1], args[2]
TARGET_TRIS = int(args[3]) if len(args) > 3 else 15000
TEX = 2048
HEIGHT = 1.9  # NS2 metres; Player.kYExtents * 2
os.makedirs(ART, exist_ok=True); os.makedirs(MSRC, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=IN_FBX)
high = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
high.name = "robot_high"

# --- normalise transform: feet at origin, facing -Y (Blender front), HEIGHT tall
bpy.context.view_layer.objects.active = high
for o in bpy.context.scene.objects: o.select_set(o == high)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# model faces +X in the source; rotate so it faces -Y
high.rotation_euler = (0, 0, math.radians(-90))
bpy.ops.object.transform_apply(rotation=True)
bb = [mathutils.Vector(v) for v in high.bound_box]
zmin = min(v.z for v in bb); zmax = max(v.z for v in bb)
cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
s = HEIGHT / (zmax - zmin)
high.location = (-cx * s, -cy * s, -zmin * s)
high.scale = (s, s, s)
bpy.ops.object.transform_apply(location=True, scale=True)
print("HIGH tris", sum(len(p.vertices) - 2 for p in high.data.polygons))

# --- low poly copy
low = high.copy(); low.data = high.data.copy(); low.name = "robot"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new(); bm.from_mesh(low.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(low.data); bm.free()
cur = len(low.data.polygons)
mod = low.modifiers.new("dec", 'DECIMATE')
mod.ratio = min(1.0, TARGET_TRIS / max(1, cur))
mod.use_collapse_triangulate = True
for o in bpy.context.scene.objects: o.select_set(o == low)
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier="dec")
low.data.calc_loop_triangles()
print("LOW tris", len(low.data.loop_triangles))
# shading: smooth with sharp edges by angle
bpy.ops.object.shade_auto_smooth(angle=math.radians(50))

# new UVs
while low.data.uv_layers: low.data.uv_layers.remove(low.data.uv_layers[0])
low.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, scale_to_bounds=True)
try:
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
except Exception as e:
    print("pack warn", e)
bpy.ops.object.mode_set(mode='OBJECT')

# --- bake setup
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = 4
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for dev in ('HIP', 'OPTIX', 'CUDA'):
        try:
            prefs.compute_device_type = dev; prefs.get_devices()
            if any(d.type == dev for d in prefs.devices):
                for d in prefs.devices: d.use = True
                sc.cycles.device = 'GPU'; print("BAKE DEVICE", dev); break
        except Exception: pass
except Exception as e:
    print("gpu warn", e)

hmat = high.material_slots[0].material
nt = hmat.node_tree
bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
def tex_for(socket_name):
    sock = bsdf.inputs[socket_name]
    if not sock.links: return None
    n = sock.links[0].from_node
    while n.type != 'TEX_IMAGE' and n.inputs and any(i.links for i in n.inputs):
        n = next(i.links[0].from_node for i in n.inputs if i.links)
    return n if n.type == 'TEX_IMAGE' else None
tex_albedo = tex_for('Base Color'); tex_metal = tex_for('Metallic'); tex_rough = tex_for('Roughness')
emit = nt.nodes.new('ShaderNodeEmission')

# low material: one image node, the bake target
lmat = bpy.data.materials.new("robot")
lmat.use_nodes = True
low.data.materials.clear(); low.data.materials.append(lmat)
lnt = lmat.node_tree
target = lnt.nodes.new('ShaderNodeTexImage')
lnt.nodes.active = target

for o in sc.objects: o.select_set(o in (high, low))
bpy.context.view_layer.objects.active = low
bake = sc.render.bake
bake.use_selected_to_active = True
bake.use_cage = False
bake.cage_extrusion = 0.02
bake.max_ray_distance = 0.06
bake.margin = 8

def new_img(name, noncolor):
    im = bpy.data.images.new(name, TEX, TEX, alpha=False, float_buffer=False)
    if noncolor: im.colorspace_settings.name = 'Non-Color'
    return im

def bake_emit(name, texnode, noncolor):
    im = new_img(name, noncolor); target.image = im
    for l in list(out.inputs['Surface'].links): nt.links.remove(l)
    nt.links.new(texnode.outputs['Color'], emit.inputs['Color'])
    nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])
    bpy.ops.object.bake(type='EMIT')
    im.filepath_raw = os.path.join(ART, f"{name}.png"); im.file_format = 'PNG'; im.save()
    print("BAKED", name)

bake_emit("bake_albedo", tex_albedo, False)
if tex_metal: bake_emit("bake_metallic", tex_metal, True)
if tex_rough: bake_emit("bake_roughness", tex_rough, True)
# restore BSDF for the normal bake (includes the high-poly normal map)
for l in list(out.inputs['Surface'].links): nt.links.remove(l)
nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
im = new_img("bake_normal", True); target.image = im
sc.cycles.samples = 8
bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')
im.filepath_raw = os.path.join(ART, "bake_normal.png"); im.file_format = 'PNG'; im.save()
print("BAKED bake_normal")

# --- final low material for preview (albedo + normal + metal + rough)
lnt.nodes.clear()
lo = lnt.nodes.new('ShaderNodeOutputMaterial'); lb = lnt.nodes.new('ShaderNodeBsdfPrincipled')
lnt.links.new(lb.outputs['BSDF'], lo.inputs['Surface'])
def img_node(name, noncolor):
    n = lnt.nodes.new('ShaderNodeTexImage')
    n.image = bpy.data.images.load(os.path.join(ART, f"{name}.png"), check_existing=True)
    if noncolor: n.image.colorspace_settings.name = 'Non-Color'
    return n
lnt.links.new(img_node("bake_albedo", False).outputs['Color'], lb.inputs['Base Color'])
if tex_metal: lnt.links.new(img_node("bake_metallic", True).outputs['Color'], lb.inputs['Metallic'])
if tex_rough: lnt.links.new(img_node("bake_roughness", True).outputs['Color'], lb.inputs['Roughness'])
nm = lnt.nodes.new('ShaderNodeNormalMap')
lnt.links.new(img_node("bake_normal", True).outputs['Color'], nm.inputs['Color'])
lnt.links.new(nm.outputs['Normal'], lb.inputs['Normal'])

# --- export FBX for CompileModel: low only, texture path points at robot.tga in modelsrc
high.hide_render = True
for o in sc.objects: o.select_set(o == low)
bpy.context.view_layer.objects.active = low
fbx_mat = bpy.data.materials.new("robot_export")
fbx_mat.use_nodes = True
fnt = fbx_mat.node_tree
fb = next(n for n in fnt.nodes if n.type == 'BSDF_PRINCIPLED')
ft = fnt.nodes.new('ShaderNodeTexImage')
tga_path = os.path.join(MSRC, "robot.tga")
proxy = bpy.data.images.new("robot_tga", 4, 4); proxy.filepath_raw = tga_path; proxy.file_format = 'TARGA'; proxy.save()
ft.image = bpy.data.images.load(tga_path)
fnt.links.new(ft.outputs['Color'], fb.inputs['Base Color'])
preview_mat = low.data.materials[0]
low.data.materials[0] = fbx_mat
fbx_mat.name = "robot"; preview_mat.name = "robot_preview"
bpy.ops.export_scene.fbx(filepath=os.path.join(MSRC, "robot.fbx"), use_selection=True,
                         object_types={'MESH'}, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                         mesh_smooth_type='FACE', use_tspace=True, path_mode='ABSOLUTE',
                         axis_forward='-Z', axis_up='Y', add_leaf_bones=False, bake_anim=False)
low.data.materials[0] = preview_mat
print("EXPORTED", os.path.join(MSRC, "robot.fbx"))

# --- previews
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x = 700; sc.render.resolution_y = 900
w = bpy.data.worlds.new("w"); sc.world = w
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.38, 1)
ld = bpy.data.lights.new("sun", 'SUN'); ld.energy = 3
lo_ = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo_)
lo_.rotation_euler = (math.radians(50), 0, math.radians(-30))
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = HEIGHT * 1.15
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = mathutils.Vector((0, 0, HEIGHT / 2))
for name, pos in {"front": (0, -5, 0), "front34": (3.5, -3.5, 1.0), "back": (0, 5, 0)}.items():
    cam.location = c + mathutils.Vector(pos)
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(ART, f"preview_low_{name}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "robot_lowpoly.blend"))
print("DONE")
