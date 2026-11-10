# ============================================================================
# Vael'Thor Vanguard - HIGH-POLY version, built from the base model.
# Run:  blender -b -P build_vanguard_hq.py
#
# Re-uses build_vanguard.py for the shapes (it stays the single source of the
# design), then:
#   * doubles the roundness of every limb / dome / cylinder,
#   * 3-segment bevels with hardened normals + smooth shading by angle
#     (clean hard-surface look, no faceting),
#   * procedural materials: brushed gunmetal with colour/roughness variation,
#     micro-surface bump, clear coat; ribbed rubbery undersuit; soft plasma glow,
#   * Cycles renders (GPU if available).
# Output: vanguard_hq.blend + hq_*.png next to this script.
# This is the "high-poly" source; the in-game (low-poly) model gets its
# detail baked from it later.
# ============================================================================
import bpy, math, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "build_vanguard.py")
SPLIT = "# ---------------------------------------------------------------- apply & join"

src = open(BASE).read()
parts_src = src[:src.index(SPLIT)]

# --- more roundness: patch the base helpers' resolution --------------------
parts_src = parts_src.replace(
    '    p0, p1 = Vector(p0), Vector(p1)\n    q = (p1 - p0).to_track_quat("Z", "Y")',
    '    sides = max(sides * 2, 12)\n    p0, p1 = Vector(p0), Vector(p1)\n    q = (p1 - p0).to_track_quat("Z", "Y")')
parts_src = parts_src.replace(
    '    rot = Matrix.Rotation(math.radians(-side * tilt_deg), 4, "Y")\n    pts = []',
    '    rings, segs = rings * 2, segs * 2\n    rot = Matrix.Rotation(math.radians(-side * tilt_deg), 4, "Y")\n    pts = []')
parts_src = parts_src.replace(
    '    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts,',
    '    bmesh.ops.create_cone(bm, cap_ends=True, segments=max(verts * 2, 16),')
parts_src = parts_src.replace(
    'cd.bevel_depth = 0.014; cd.bevel_resolution = 2',
    'cd.bevel_depth = 0.014; cd.bevel_resolution = 6; cd.resolution_u = 24')
assert parts_src.count("max(sides * 2, 12)") == 1 and parts_src.count("rings * 2") == 1

g = {"__file__": BASE, "__name__": "vanguard_base"}
exec(compile(parts_src, BASE, "exec"), g)
COL = g["COL"]
scene = bpy.context.scene

# --- hard-surface finishing per part ----------------------------------------
GLOW_MATS = {"VT_Glow", "VT_Visor", "VT_Plasma", "VT_Shield"}
for o in COL.objects:
    if o.type != "MESH":
        continue
    me = o.data
    is_glow = any(m and m.name in GLOW_MATS for m in me.materials)
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(40 if is_glow else 32))
    b = o.modifiers.get("Bevel")
    if b:
        b.segments = 3
        b.profile = 0.6
        b.width = max(b.width, 0.004)
        b.harden_normals = True
        b.miter_outer = "MITER_ARC"
    elif not is_glow:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width, b.segments, b.limit_method, b.harden_normals = 0.003, 3, "ANGLE", True
    wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True

# --- procedural materials ---------------------------------------------------
def rebuild(name, build):
    m = bpy.data.materials.get(name)
    if not m:
        return
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    build(nt, bsdf)

def tex_coord(nt):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    return tc.outputs["Object"]

def noise(nt, scale, detail=6, rough=0.55, vec=None):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    if vec is not None:
        nt.links.new(vec, n.inputs["Vector"])
    return n

def ramp(nt, src, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(src, r.inputs["Fac"])
    els = r.color_ramp.elements
    while len(els) > 2:
        els.remove(els[-1])
    for i, (pos, col) in enumerate(stops):
        e = els[i] if i < len(els) else els.new(pos)
        e.position = pos
        e.color = col
    return r

def bump(nt, height_src, strength, distance=0.002):
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = strength
    bp.inputs["Distance"].default_value = distance
    nt.links.new(height_src, bp.inputs["Height"])
    return bp

def armor(base, coat=0.35):
    def build(nt, bsdf):
        v = tex_coord(nt)
        # large-scale tone variation + fine brushed/worn grain
        big = noise(nt, 4, 3, 0.45, v)
        fine = noise(nt, 90, 5, 0.45, v)
        col = ramp(nt, big.outputs["Fac"], [(0.3, (*[c * 0.85 for c in base], 1)), (0.75, (*[c * 1.15 for c in base], 1))])
        nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
        rgh = ramp(nt, fine.outputs["Fac"], [(0.3, (0.30, 0.30, 0.30, 1)), (0.75, (0.40, 0.40, 0.40, 1))])
        nt.links.new(rgh.outputs["Color"], bsdf.inputs["Roughness"])
        bsdf.inputs["Metallic"].default_value = 0.7
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.12
        bp = bump(nt, fine.outputs["Fac"], 0.015, 0.0005)
        nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    return build

def undersuit(nt, bsdf):
    v = tex_coord(nt)
    # ribbed, rubbery bodysuit
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"; wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 120
    wave.inputs["Distortion"].default_value = 0.6
    nt.links.new(v, wave.inputs["Vector"])
    bsdf.inputs["Base Color"].default_value = (0.008, 0.008, 0.011, 1)
    bsdf.inputs["Metallic"].default_value = 0.1
    bsdf.inputs["Roughness"].default_value = 0.7
    bsdf.inputs["Sheen Weight"].default_value = 0.0
    bp = bump(nt, wave.outputs["Fac"], 0.08, 0.0008)
    nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])

def glow(color, strength):
    def build(nt, bsdf):
        # hot core, softer rim (facing ratio) -> plasma look
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.35
        mix = nt.nodes.new("ShaderNodeMath"); mix.operation = "MULTIPLY_ADD"
        nt.links.new(lw.outputs["Facing"], mix.inputs[0])
        mix.inputs[1].default_value = -0.6
        mix.inputs[2].default_value = 1.0
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        nt.links.new(mix.outputs[0], mul.inputs[0])
        mul.inputs[1].default_value = strength
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        nt.links.new(mul.outputs[0], bsdf.inputs["Emission Strength"])
        bsdf.inputs["Roughness"].default_value = 0.15
        bsdf.inputs["Coat Weight"].default_value = 0.6
    return build

rebuild("VT_Armor", armor((0.022, 0.023, 0.03)))
rebuild("VT_Trim", armor((0.05, 0.05, 0.058), coat=0.15))
rebuild("VT_Under", undersuit)
rebuild("VT_Glow", glow((0.45, 0.06, 1.0), 2.2))
rebuild("VT_Visor", glow((0.55, 0.1, 1.0), 3.0))
rebuild("VT_Plasma", glow((0.75, 0.25, 1.0), 4.0))

# --- apply modifiers and join (same as the base) ----------------------------
deps = bpy.context.evaluated_depsgraph_get()
for o in list(COL.objects):
    if o.type != "MESH":
        continue
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    old = o.data
    o.modifiers.clear()
    o.data = me
    bpy.data.meshes.remove(old)
bpy.ops.object.select_all(action="DESELECT")
meshes = [o for o in COL.objects if o.type == "MESH"]
bpy.context.view_layer.objects.active = meshes[0]
for o in meshes:
    o.select_set(True)
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "Vanguard_HQ"
print("VANGUARD HQ tris:", sum(len(p.vertices) - 2 for p in body.data.polygons))

# --- studio scene -----------------------------------------------------------
world = bpy.data.worlds.new("Studio"); scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.015, 0.014, 0.022, 1)
bg.inputs[1].default_value = 1.0

from mathutils import Vector
def area(name, loc, energy, color, size, target=(0, 0, 1.1)):
    d = bpy.data.lights.new(name, "AREA"); d.energy = energy; d.color = color; d.size = size
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
area("Key", (-2.2, -2.8, 3.2), 380, (1.0, 0.96, 0.92), 2.5)
area("RimL", (2.4, 2.2, 2.6), 900, (0.55, 0.45, 1.0), 1.2)
area("RimR", (-2.6, 2.0, 2.0), 500, (0.4, 0.8, 1.0), 1.0)
area("Fill", (2.8, -2.2, 0.9), 60, (0.75, 0.85, 1.0), 2.5)

import bmesh
floor = bpy.data.meshes.new("Floor")
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6); bm.to_mesh(floor); bm.free()
fo = bpy.data.objects.new("Floor", floor); scene.collection.objects.link(fo)
fm = bpy.data.materials.new("FloorMat"); fm.use_nodes = True
fp = fm.node_tree.nodes["Principled BSDF"]
fp.inputs["Base Color"].default_value = (0.03, 0.03, 0.035, 1)
fp.inputs["Roughness"].default_value = 0.35
fp.inputs["Metallic"].default_value = 0.4
fo.data.materials.append(fm)

cam_d = bpy.data.cameras.new("Cam"); cam_d.lens = 70
cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam)
scene.camera = cam

# Cycles on the GPU when possible, else EEVEE
try:
    scene.render.engine = "CYCLES"
    cp = bpy.context.preferences.addons["cycles"].preferences
    for t in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
        try:
            cp.compute_device_type = t
            cp.get_devices()
            devs = [d for d in cp.devices if d.type == t]
            if devs:
                for d in devs:
                    d.use = True
                scene.cycles.device = "GPU"
                print("Cycles device:", t, [d.name for d in devs])
                break
        except Exception:
            pass
    scene.cycles.samples = 160
    scene.cycles.use_denoising = True
except Exception as e:
    print("Cycles unavailable, using EEVEE:", e)
    scene.render.engine = "BLENDER_EEVEE"

scene.render.resolution_x = 1200
scene.render.resolution_y = 1500
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass

def shoot(tag, angle_deg, dist=5.0, h=1.3, target=(0, 0, 1.0), lens=70):
    cam_d.lens = lens
    a = math.radians(angle_deg)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, h + 0.2)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(HERE, f"hq_{tag}.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "vanguard_hq.blend"))
shoot("front34", -30)
shoot("back34", 150)
shoot("side", 90)
shoot("closeup", -25, dist=2.2, h=1.35, target=(0, -0.15, 1.35))
