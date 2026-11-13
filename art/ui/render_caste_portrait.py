"""Renders a caste portrait for the Synthesis Matrix menu (GUIVTMatrixMenu) from the rigged player model blend.
Usage: blender -b <x>_rigged.blend -P render_caste_portrait.py -- <texture_dir> <tex_name> <out.png> [framing]
  texture_dir/tex_name.dds        albedo (the in-game, already recoloured texture)
  texture_dir/tex_name_illum.dds  emissive (purple glow)
  framing: "body" (default, head to knees) or "full"
Transparent background, 3/4 front view, violet key/rim light. Material slots without the caste texture (the
Praetor's vanilla minigun) get plain dark metal.
"""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
TEXDIR, TEX, OUT = argv[0], argv[1], argv[2]
FRAMING = argv[3] if len(argv) > 3 else "body"
W, H = 512, 512

scene = bpy.context.scene
mesh = next(o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render)
for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)

# ---- materials
def load(path):
    img = bpy.data.images.load(path)
    return img

albedo = load(os.path.join(TEXDIR, TEX + ".dds"))
illum = load(os.path.join(TEXDIR, TEX + "_illum.dds"))

def caste_material():
    m = bpy.data.materials.new("portrait_" + TEX)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    t_alb = nt.nodes.new("ShaderNodeTexImage"); t_alb.image = albedo
    t_ill = nt.nodes.new("ShaderNodeTexImage"); t_ill.image = illum
    nt.links.new(t_alb.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(t_ill.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 4.0
    bsdf.inputs["Metallic"].default_value = 0.3
    bsdf.inputs["Roughness"].default_value = 0.45
    return m

def metal_material():
    m = bpy.data.materials.new("portrait_metal")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.12, 0.11, 0.14, 1)
    bsdf.inputs["Metallic"].default_value = 0.8
    bsdf.inputs["Roughness"].default_value = 0.4
    return m

cm, mm = caste_material(), metal_material()
for i, slot in enumerate(mesh.material_slots):
    name = slot.material.name if slot.material else ""
    slot.material = mm if "minigun" in name.lower() else cm

# ---- framing: bounding box of the posed mesh in world space
dg = bpy.context.evaluated_depsgraph_get()
ev = mesh.evaluated_get(dg)
pts = [ev.matrix_world @ v.co for v in ev.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
height = hi.z - lo.z
centre = (lo + hi) / 2
if FRAMING == "body":                      # head to mid thigh
    top, bottom = hi.z + height * 0.03, lo.z + height * 0.38
else:
    top, bottom = hi.z + height * 0.03, lo.z - height * 0.02
look = Vector((centre.x, centre.y, (top + bottom) / 2))
span = top - bottom

# the models face -Y (NS2 forward exported as Blender -Y); 3/4 view from the front right
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = span * 1.02
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
yaw = math.radians(28)
dist = 10
cam.location = look + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, span * 0.12))
direction = look - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

def light(name, kind, energy, color, loc, size=1.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    ob.location = loc
    d = look - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(ob)

light("key",  "AREA", 900, (1.0, 0.95, 1.0),  look + Vector((3, -4, 2.5)), 3)
light("fill", "AREA", 250, (0.55, 0.45, 1.0), look + Vector((-4, -3, 0.5)), 4)
light("rim",  "AREA", 1400, (0.75, 0.35, 1.0), look + Vector((-1.5, 4, 2.5)), 2)

world = bpy.data.worlds.new("w") if not scene.world else scene.world
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.55, 0.5, 0.7, 1)   # chrome needs something bright to reflect
    bg.inputs["Strength"].default_value = 0.9

engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.render.film_transparent = True
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("PORTRAIT", OUT)
