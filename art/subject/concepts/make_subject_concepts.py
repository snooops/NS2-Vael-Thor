"""Subject (Bio-Construct) concept renders: three looks for the engineered war-beast, same design language as the
building / Artificer concepts (polished chrome, dark gunmetal, violet crystals and seams) plus grown flesh.

Every concept is built ON the NS2 marine skeleton (joint positions from art/skeleton/marine_reference.blend, facing
-Y, z up, marine scale; the game draws the Subject x1.3): the body is a Skin-modifier mesh grown along the marine
bones, every other part sits on one bone, so the chosen look can be rigged to the marine skeleton directly.

Usage: blender -b -P make_subject_concepts.py -- <out_dir> [concept ...]
Concepts: shackled (restrained brute), stalker (chitin predator), graft (flesh on a chrome frame).
"""
import bpy, math, sys, os
from mathutils import Vector, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- marine joints (left side +x)
J = {
    "pelvis": (0, 0.02, 1.13), "belly": (0, 0.0, 1.30), "chest": (0, 0.02, 1.47), "upchest": (0, 0.04, 1.60),
    "neck": (0, 0.035, 1.68), "head": (0, 0.0, 1.79),
    "clav": (0.09, 0.04, 1.61), "shoulder": (0.19, 0.06, 1.575), "elbow": (0.31, 0.07, 1.326),
    "wrist": (0.461, -0.013, 1.099), "hand": (0.50, -0.05, 0.98),
    "hip": (0.11, 0.0, 1.09), "knee": (0.127, 0.0, 0.646), "ankle": (0.15, 0.07, 0.14), "toe": (0.165, -0.11, 0.05),
}


def j(name, s=1, off=(0, 0, 0)):
    p = J[name]
    return Vector((p[0] * s + off[0] * s, p[1] + off[1], p[2] + off[2]))


def lerp(a, b, t):
    return a + (b - a) * t


# ---------------------------------------------------------------- scene / materials
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("VT_SAMPLES", "128"))
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = int(os.environ.get("VT_RES", "1200"))
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.33, 0.34, 0.40, 1)
    bg.inputs["Strength"].default_value = 0.55
    global M
    M = {
        "silver":  mat("silver", (0.72, 0.74, 0.80), 1.0, 0.22),
        "gun":     mat("gun", (0.09, 0.09, 0.12), 0.85, 0.36),
        "dark":    mat("dark", (0.04, 0.03, 0.06), 0.3, 0.55),
        "glow":    mat("glow", (0.45, 0.12, 0.85), 0.0, 0.4, emit=(0.50, 0.15, 1.0), strength=3.0),
        "crystal": mat("crystal", (0.32, 0.08, 0.75), 0.0, 0.08, emit=(0.45, 0.12, 1.0), strength=0.9),
        "flesh":   mat("flesh", (0.12, 0.035, 0.12), 0.0, 0.34, sss=0.2),
        "fleshd":  mat("fleshd", (0.06, 0.02, 0.07), 0.0, 0.4, sss=0.1),
        "chitin":  mat("chitin", (0.10, 0.06, 0.14), 0.55, 0.2),
        "bone":    mat("bone", (0.62, 0.58, 0.66), 0.1, 0.35),
    }


def mat(name, color, metal, rough, emit=None, strength=0.0, sss=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if sss:
        # skin: fine wrinkled bump + larger sinew ridges, so the flesh doesn't read as plastic
        nt = m.node_tree
        tc = nt.nodes.new("ShaderNodeTexCoord")
        fine = nt.nodes.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 60; fine.inputs["Detail"].default_value = 8
        sinew = nt.nodes.new("ShaderNodeTexWave"); sinew.wave_type = "BANDS"; sinew.bands_direction = "Z"
        sinew.inputs["Scale"].default_value = 9; sinew.inputs["Distortion"].default_value = 6
        weak = nt.nodes.new("ShaderNodeMath"); weak.operation = "MULTIPLY"; weak.inputs[1].default_value = 0.12
        mix = nt.nodes.new("ShaderNodeMath"); mix.operation = "ADD"
        mottle = nt.nodes.new("ShaderNodeTexNoise"); mottle.inputs["Scale"].default_value = 7; mottle.inputs["Detail"].default_value = 3
        bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.45; bump.inputs["Distance"].default_value = 0.004
        nt.links.new(tc.outputs["Object"], fine.inputs["Vector"]); nt.links.new(tc.outputs["Object"], sinew.inputs["Vector"])
        nt.links.new(fine.outputs["Fac"], mix.inputs[0]); nt.links.new(sinew.outputs["Fac"], weak.inputs[0]); nt.links.new(weak.outputs[0], mix.inputs[1])
        nt.links.new(tc.outputs["Object"], mottle.inputs["Vector"])
        nt.links.new(mix.outputs[0], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
        # darker in the creases
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.35; ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[0].color = (color[0] * 0.5, color[1] * 0.45, color[2] * 0.55, 1)
        ramp.color_ramp.elements[1].color = (*color, 1)
        nt.links.new(mottle.outputs["Fac"], ramp.inputs["Fac"]); nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
        p.inputs["Subsurface Weight"].default_value = sss
        p.inputs["Subsurface Radius"].default_value = (0.6, 0.15, 0.4)
        p.inputs["Subsurface Scale"].default_value = 0.03
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def finish(obj, m, bevel=0.0, smooth=False):
    obj.data.materials.append(M[m])
    if bevel > 0:
        b = obj.modifiers.new("bevel", "BEVEL")
        b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def box(sx, sy, sz, loc, m, rot=(0, 0, 0), bevel=0.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def seg(p0, p1, w, d, m, bevel=0.01, twist=0.0):
    """box spanning p0 -> p1 (cross-section w x d)"""
    p0, p1 = Vector(p0), Vector(p1)
    v = p1 - p0
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.object; o.scale = (w, d, v.length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.location = (p0 + p1) / 2
    o.rotation_mode = "QUATERNION"
    q = v.to_track_quat("Z", "Y")
    if twist:
        q = q @ Quaternion((0, 0, 1), twist)
    o.rotation_quaternion = q
    return finish(o, m, bevel)


def cyl(n, r, p0, p1, m, r2=None, bevel=0.0, smooth=False):
    p0, p1 = Vector(p0), Vector(p1)
    v = p1 - p0
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if r2 is None else r2, depth=v.length,
                                    location=(p0 + p1) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = v.to_track_quat("Z", "Y")
    return finish(o, m, bevel, smooth)


def ball(r, loc, m, sub=2, smooth=True, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.object; o.scale = scale
    return finish(o, m, smooth=smooth)


def ring(R, r, loc, m="silver", axis=(0, 0, 1), n=32, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=n, minor_segments=8,
                                     location=loc)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector(axis).to_track_quat("Z", "Y")
    o.scale = scale
    return finish(o, m, smooth=True)


def band(p0, p1, t, R, r=0.014, m="silver", scale=(1, 1, 1)):
    """restraint ring around the limb p0->p1 at fraction t"""
    p0, p1 = Vector(p0), Vector(p1)
    return ring(R, r, lerp(p0, p1, t), m, axis=p1 - p0, scale=scale)


def spike(r, length, base, direction, m="crystal", n=5):
    d = Vector(direction).normalized()
    return cyl(n, r, base, Vector(base) + d * length, m, r2=0.0)


def crystal(r, up, down, loc, m="crystal", n=6, tilt=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=up, location=(0, 0, up / 2))
    a = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=down, location=(0, 0, -down / 2),
                                    rotation=(math.pi, 0, 0))
    b = bpy.context.object
    bpy.ops.object.select_all(action="DESELECT"); a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    a.location = loc; a.rotation_euler = tilt
    return finish(a, m)


def cable(points, r=0.012, m="dark"):
    cu = bpy.data.curves.new("cable", "CURVE"); cu.dimensions = "3D"
    cu.bevel_depth = r; cu.bevel_resolution = 3
    sp = cu.splines.new("BEZIER"); sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new("cable", cu); bpy.context.scene.collection.objects.link(o)
    cu.materials.append(M[m])
    return o


def claw(base, direction, side, length=0.26, r=0.022, m="silver", curl=0.5):
    """curved claw: three tapering segments bending forward/down"""
    d = Vector(direction).normalized()
    bend = Vector((0, -1, -0.4)).normalized()
    p = Vector(base); rr = r
    for i in range(3):
        nd = (d + bend * curl * (i + 1) / 3).normalized()
        q = p + nd * length / 3
        cyl(6, rr, p, q, m, r2=rr * 0.62)
        p = q; rr *= 0.62
    return p


def mirror(fn):
    for s in (-1, 1):
        fn(s)


# ---------------------------------------------------------------- the body: skin modifier along the marine bones
MIDS = {"bicep": ("shoulder", "elbow", 0.45), "forearm": ("elbow", "wrist", 0.4), "thigh": ("hip", "knee", 0.4),
        "calf": ("knee", "ankle", 0.3), "waist": ("belly", "chest", 0.0)}


def joint(name, s, offsets):
    if name in MIDS and name != "waist":
        a, b, t = MIDS[name]
        p = lerp(joint(a, s, offsets), joint(b, s, offsets), t)
        o = offsets.get(name, (0, 0, 0))
        return p + Vector((o[0] * s, o[1], o[2]))
    if name == "waist":
        return joint("belly", s, offsets)
    return j(name, s, offsets.get(name, (0, 0, 0)))


def skin_body(radius, m="flesh", subdiv=2, offsets=None, head=False):
    """Skin-modifier body along the marine bones. radius: joint -> (rx, ry), incl. the mid joints bicep / forearm /
    thigh / calf (mirrored). offsets: joint -> (dx, dy, dz), x mirrored. The head is modelled per concept."""
    offsets = offsets or {}
    verts, edges, radii, index = [], [], [], {}

    def add(name, s=1):
        key = (name, s)
        if key in index:
            return index[key]
        index[key] = len(verts)
        verts.append(joint(name, s, offsets))
        radii.append(radius[name])
        return index[key]

    chain = ["pelvis", "belly", "chest", "upchest", "neck"] + (["head"] if head else [])
    for a, b in zip(chain, chain[1:]):
        edges.append((add(a), add(b)))
    for s in (-1, 1):
        arm = ["upchest", "clav", "shoulder", "bicep", "elbow", "forearm", "wrist", "hand"]
        for a, b in zip(arm, arm[1:]):
            edges.append((add(a, 1 if a == "upchest" else s), add(b, s)))
        leg = ["pelvis", "hip", "thigh", "knee", "calf", "ankle", "toe"]
        for a, b in zip(leg, leg[1:]):
            edges.append((add(a, 1 if a == "pelvis" else s), add(b, s)))
    me = bpy.data.meshes.new("body")
    me.from_pydata([tuple(v) for v in verts], edges, [])
    o = bpy.data.objects.new("body", me); bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for i, r in enumerate(radii):
        o.data.skin_vertices[0].data[i].radius = r
    o.data.skin_vertices[0].data[index[("pelvis", 1)]].use_root = True
    sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = subdiv
    o.data.materials.append(M[m])
    return o


def muscle(loc, r, m="flesh", scale=(1, 1, 1)):
    return ball(r, loc, m, sub=3, scale=scale)


def vein(points, r=0.006):
    return cable(points, r, "glow")


# ================================================================ I  SHACKLED: a restrained brute
def shackled():
    R = {"pelvis": (0.16, 0.12), "belly": (0.15, 0.12), "chest": (0.22, 0.16), "upchest": (0.26, 0.17),
         "neck": (0.12, 0.12), "clav": (0.13, 0.13), "shoulder": (0.14, 0.14), "bicep": (0.115, 0.12),
         "elbow": (0.085, 0.085), "forearm": (0.12, 0.11), "wrist": (0.09, 0.08), "hand": (0.075, 0.06),
         "hip": (0.12, 0.12), "thigh": (0.13, 0.13), "knee": (0.08, 0.085), "calf": (0.095, 0.10),
         "ankle": (0.055, 0.06), "toe": (0.05, 0.035)}
    # hunched: head down and forward, neck sunk between the shoulders
    skin_body(R, "flesh", offsets={"neck": (0, -0.03, -0.03), "upchest": (0, 0.03, 0)})
    # muscle mass: trapezius hump, pecs, biceps, forearms like hams
    muscle((0, 0.10, 1.62), 0.20, "flesh", scale=(1.3, 0.9, 0.7))
    mirror(lambda s: muscle(j("chest", 1, (s * 0.10, -0.08, 0.06)), 0.10, scale=(1.1, 0.7, 0.8)))
    # chrome yoke over the shoulders + collar with a crystal lock
    ring(0.22, 0.035, (0, 0.02, 1.665), "silver", axis=(0, 0.25, 1), scale=(1.15, 0.85, 1))
    mirror(lambda s: box(0.20, 0.24, 0.05, j("shoulder", s, (0.06, -0.01, 0.07)), "silver",
                         rot=(0, s * 0.5, 0), bevel=0.015))
    mirror(lambda s: box(0.17, 0.20, 0.03, j("shoulder", s, (0.08, -0.01, 0.10)), "gun",
                         rot=(0, s * 0.5, 0), bevel=0.01))
    crystal(0.045, 0.07, 0.05, (0, -0.17, 1.62), tilt=(math.pi / 2, 0, 0))
    box(0.10, 0.03, 0.12, (0, -0.14, 1.62), "silver", bevel=0.01)
    # restraint plate on the belly + chained straps
    box(0.26, 0.05, 0.16, (0, -0.15, 1.27), "gun", rot=(0.15, 0, 0), bevel=0.02)
    box(0.20, 0.06, 0.03, (0, -0.17, 1.27), "glow", rot=(0.15, 0, 0), bevel=0)
    # cage helm: bars over the skull, glowing eyes inside
    hc = j("head", 1, (0, -0.08, 0.02))
    ball(0.10, hc, "flesh", sub=3, scale=(0.95, 1.05, 0.95))                        # skull
    box(0.16, 0.13, 0.085, hc + Vector((0, -0.05, -0.085)), "flesh", bevel=0.03)    # heavy jaw
    box(0.17, 0.05, 0.035, hc + Vector((0, -0.09, 0.035)), "fleshd", bevel=0.012)  # brow ridge
    mirror(lambda s: spike(0.015, 0.05, hc + Vector((s * 0.05, -0.10, -0.11)), (s * 0.2, -0.3, 1), "bone"))  # tusks
    for a in (-0.6, -0.2, 0.2, 0.6):
        ring(0.12, 0.008, hc + Vector((0, 0, 0.01)), "silver", axis=(math.cos(a), 0, math.sin(a) * 0.3), n=24)
    ring(0.125, 0.012, hc + Vector((0, 0, -0.02)), "silver", axis=(0, 0, 1))
    mirror(lambda s: ball(0.016, hc + Vector((s * 0.04, -0.095, 0.0)), "glow", sub=2))
    # shackles on biceps, wrists, thighs, ankles + broken chain links
    for s in (-1, 1):
        band(j("shoulder", s), j("elbow", s), 0.62, 0.105, 0.02)
        band(j("elbow", s), j("wrist", s), 0.85, 0.11, 0.028)
        band(j("elbow", s), j("wrist", s), 0.85, 0.112, 0.008, "glow")
        band(j("hip", s), j("knee", s), 0.55, 0.13, 0.018)
        band(j("knee", s), j("ankle", s), 0.82, 0.075, 0.024)
        w = lerp(j("elbow", s), j("wrist", s), 0.85)
        for k in range(3):
            ring(0.022, 0.006, w + Vector((s * (0.09 + k * 0.035), 0.02, -0.06 - k * 0.04)), "gun",
                 axis=(1, k % 2, 0), n=12, scale=(1, 1, 1.6))
    # spine: crystal shards growing out of the hump
    for i, (z, h) in enumerate(((1.75, 0.13), (1.64, 0.17), (1.52, 0.14), (1.40, 0.10))):
        spike(0.035, h, (0, 0.16 + 0.02 * (i == 1), z), (0, 1, 0.35 - i * 0.1))
    # glowing veins over the muscle
    for s in (-1, 1):
        vein([j("shoulder", s, (0.03, -0.09, 0.0)), lerp(j("shoulder", s), j("elbow", s), 0.5) + Vector((s * 0.03, -0.09, 0)),
              j("elbow", s, (0.02, -0.07, 0)), lerp(j("elbow", s), j("wrist", s), 0.5) + Vector((s * 0.02, -0.11, 0))])
        vein([j("chest", 1, (s * 0.05, -0.17, 0.10)), j("belly", 1, (s * 0.10, -0.15, 0.0)), j("pelvis", 1, (s * 0.08, -0.13, -0.02))])
    # claws: three bone-chrome hooks out of each fist
    for s in (-1, 1):
        h = j("hand", s)
        for k in (-1, 0, 1):
            claw(h + Vector((s * 0.01, -0.03 + k * 0.03, -0.02)), (s * 0.15, -0.25 + k * 0.1, -1), s, 0.30, 0.02, "silver")
    # heavy hooves
    mirror(lambda s: box(0.13, 0.22, 0.07, j("toe", s, (0, 0.06, 0.0)), "gun", bevel=0.02))


# ================================================================ II  STALKER: chitin predator
def stalker():
    R = {"pelvis": (0.12, 0.09), "belly": (0.085, 0.08), "chest": (0.15, 0.11), "upchest": (0.17, 0.11),
         "neck": (0.055, 0.055), "clav": (0.065, 0.065), "shoulder": (0.075, 0.075), "bicep": (0.06, 0.06),
         "elbow": (0.045, 0.045), "forearm": (0.055, 0.05), "wrist": (0.04, 0.035), "hand": (0.04, 0.035),
         "hip": (0.08, 0.08), "thigh": (0.085, 0.085), "knee": (0.05, 0.055), "calf": (0.06, 0.065),
         "ankle": (0.04, 0.045), "toe": (0.035, 0.03)}
    skin_body(R, "fleshd")
    # segmented carapace: overlapping plates down the torso (front and back)
    for i, z in enumerate((1.58, 1.49, 1.40, 1.31, 1.22)):
        w = 0.36 - abs(i - 1) * 0.05
        box(w, 0.06, 0.10, (0, -0.10 + i * 0.012, z), "chitin", rot=(0.25, 0, 0), bevel=0.02)
        box(w * 0.9, 0.012, 0.012, (0, -0.135 + i * 0.012, z - 0.05), "glow", rot=(0.25, 0, 0), bevel=0)
        box(w * 0.95, 0.06, 0.10, (0, 0.14 - i * 0.008, z + 0.02), "chitin", rot=(-0.3, 0, 0), bevel=0.02)
    # dorsal blades
    for i, z in enumerate((1.62, 1.50, 1.38, 1.26)):
        spike(0.03, 0.22 - i * 0.03, (0, 0.18, z), (0, 1, 0.9))
    # elongated eyeless head crest, swept back; violet slit where a face would be
    hc = j("head", 1, (0, -0.04, -0.02))
    ball(0.06, hc, "fleshd", sub=3)
    cyl(6, 0.075, hc + Vector((0, -0.06, -0.02)), hc + Vector((0, 0.30, 0.10)), "chitin", r2=0.012)
    cyl(6, 0.05, hc + Vector((0, -0.10, -0.05)), hc + Vector((0, 0.02, 0.0)), "chitin", r2=0.06)
    box(0.09, 0.01, 0.012, hc + Vector((0, -0.105, -0.01)), "glow", bevel=0)
    mirror(lambda s: spike(0.02, 0.16, hc + Vector((s * 0.05, 0.02, 0.03)), (s * 0.5, 1, 0.5), "chitin"))
    # mandibles
    mirror(lambda s: claw(hc + Vector((s * 0.03, -0.08, -0.07)), (s * 0.3, -1, -0.6), s, 0.10, 0.012, "bone", curl=0.2))
    # limb armor: plates along every bone, glowing joints
    for s in (-1, 1):
        for a, b, w, d in (("shoulder", "elbow", 0.11, 0.10), ("elbow", "wrist", 0.10, 0.09), ("hip", "knee", 0.15, 0.13),
                           ("knee", "ankle", 0.10, 0.10)):
            pa, pb = j(a, s), j(b, s)
            seg(lerp(pa, pb, 0.12), lerp(pa, pb, 0.88), w, d, "chitin", bevel=0.02)
            ball(0.035, pb, "glow", sub=2)
        # shoulder carapace with crystal spurs
        box(0.17, 0.20, 0.07, j("shoulder", s, (0.03, 0, 0.07)), "chitin", rot=(0, s * 0.45, 0), bevel=0.025)
        spike(0.025, 0.14, j("shoulder", s, (0.08, 0.03, 0.10)), (s * 0.6, 0.4, 1))
        # knee spur and digitigrade heel spike
        spike(0.025, 0.12, j("knee", s, (0, -0.06, 0.02)), (0, -0.6, 1), "chitin")
        spike(0.02, 0.16, j("ankle", s, (0, 0.04, 0.02)), (0, 1, 0.3), "chitin")
        # scything forearm blades (the claws): long curved blade from wrist past the hand + finger talons
        w0 = j("wrist", s)
        tip = claw(w0 + Vector((s * 0.03, 0.0, 0.02)), (s * 0.15, -0.35, -1), s, 0.50, 0.03, "silver", curl=0.35)
        for k in (-1, 1):
            claw(j("hand", s) + Vector((0, k * 0.02, -0.03)), (s * 0.1, -0.2, -1), s, 0.16, 0.012, "bone")
    # short tail
    cable([(0, 0.12, 1.10), (0, 0.30, 1.0), (0, 0.42, 0.78), (0, 0.46, 0.60)], 0.035, "chitin")
    spike(0.03, 0.12, (0, 0.46, 0.62), (0, 0.1, -1))


# ================================================================ III  GRAFT: flesh grown onto a chrome frame
def graft():
    R = {"pelvis": (0.14, 0.11), "belly": (0.13, 0.11), "chest": (0.18, 0.14), "upchest": (0.21, 0.15),
         "neck": (0.08, 0.08), "clav": (0.10, 0.10), "shoulder": (0.11, 0.11), "bicep": (0.09, 0.09),
         "elbow": (0.07, 0.07), "forearm": (0.09, 0.085), "wrist": (0.07, 0.065), "hand": (0.06, 0.05),
         "hip": (0.10, 0.10), "thigh": (0.11, 0.11), "knee": (0.07, 0.075), "calf": (0.08, 0.085),
         "ankle": (0.05, 0.055), "toe": (0.045, 0.03)}
    skin_body(R, "flesh")
    # right arm is chrome: flesh stops at the shoulder (hidden inside the mechanical arm)
    s = -1
    sh, el, wr, hd = j("shoulder", s), j("elbow", s), j("wrist", s), j("hand", s)
    ball(0.12, sh, "silver", sub=3)
    ring(0.12, 0.02, sh, "glow", axis=(1, 0, 0.3))
    cyl(8, 0.105, sh, el, "gun", r2=0.085, bevel=0.01)
    for t in (0.3, 0.6):
        band(sh, el, t, 0.105, 0.012, "silver")
    ball(0.085, el, "silver", sub=3)
    cyl(8, 0.11, el, wr, "silver", r2=0.085, bevel=0.01)
    seg(lerp(el, wr, 0.2) + Vector((0, -0.07, 0)), lerp(el, wr, 0.9) + Vector((0, -0.06, 0)), 0.04, 0.03, "glow", bevel=0)
    ball(0.075, hd, "gun", sub=2)
    for t in (0.5, 0.7):
        cyl(6, 0.015, lerp(el, wr, t) + Vector((0, 0.08, 0)), lerp(sh, el, 0.6) + Vector((0, 0.09, 0)), "gun")
    # mechanical claw: three piston talons
    for k in (-1, 0, 1):
        claw(hd + Vector((0, k * 0.035, 0.02)), (s * 0.1, -0.15 + k * 0.15, -1), s, 0.30, 0.022, "silver", curl=0.3)
    # left arm: flesh, swollen, bone claws breaking out of the knuckles
    s = 1
    for k in (-1, 0, 1):
        claw(j("hand", s) + Vector((0, -0.03 + k * 0.03, -0.02)), (0.1, -0.3 + k * 0.1, -1), s, 0.28, 0.02, "bone")
    vein([j("shoulder", s, (0.02, -0.08, 0)), j("elbow", s, (0.03, -0.06, 0)), j("wrist", s, (0.01, -0.07, 0))])
    # exposed chest: chrome rib cage around a crystal heart
    crystal(0.07, 0.10, 0.08, (0, -0.16, 1.47))
    ball(0.10, (0, -0.10, 1.47), "glow", sub=3, scale=(1, 0.6, 1))
    for i, z in enumerate((1.58, 1.51, 1.44, 1.37)):
        for sd in (-1, 1):
            cable([(sd * 0.03, -0.20, z), (sd * 0.15, -0.17, z + 0.01), (sd * 0.22, -0.05, z + 0.02),
                   (sd * 0.20, 0.10, z + 0.03)], 0.012, "silver")
    cyl(8, 0.02, (0, -0.21, 1.60), (0, -0.21, 1.33), "silver")
    # spine rail with pistons and feed tubes to the head
    for i, z in enumerate((1.70, 1.60, 1.50, 1.40, 1.30, 1.20)):
        box(0.09, 0.07, 0.06, (0, 0.17, z), "silver", bevel=0.01)
        box(0.05, 0.02, 0.012, (0, 0.205, z), "glow", bevel=0)
    cyl(8, 0.02, (0.06, 0.18, 1.72), (0.06, 0.18, 1.20), "gun")
    cyl(8, 0.02, (-0.06, 0.18, 1.72), (-0.06, 0.18, 1.20), "gun")
    hc = j("head", 1, (0, -0.03, -0.02))
    for sd in (-1, 1):
        cable([hc + Vector((sd * 0.07, 0.0, -0.06)), (sd * 0.10, 0.12, 1.70), (sd * 0.06, 0.20, 1.62)], 0.014, "dark")
    # chrome face mask with a vertical visor slit
    cyl(8, 0.085, hc + Vector((0, -0.02, -0.08)), hc + Vector((0, -0.02, 0.08)), "silver", r2=0.07, bevel=0.01)
    box(0.012, 0.02, 0.10, hc + Vector((0, -0.105, 0.0)), "glow", bevel=0)
    ball(0.09, hc + Vector((0, 0.03, 0.02)), "fleshd", sub=3, scale=(0.9, 1, 0.9))
    # pelvis frame + leg braces
    box(0.34, 0.26, 0.08, (0, 0.0, 1.16), "gun", bevel=0.02)
    for s in (-1, 1):
        hp, kn, an = j("hip", s), j("knee", s), j("ankle", s)
        seg(hp + Vector((s * 0.10, 0, 0)), kn + Vector((s * 0.08, 0, 0)), 0.03, 0.03, "silver")
        ball(0.04, kn + Vector((s * 0.08, 0, 0)), "glow", sub=2)
        seg(kn + Vector((s * 0.08, 0, 0)), an + Vector((s * 0.06, 0, 0)), 0.03, 0.03, "silver")
        box(0.12, 0.22, 0.06, j("toe", s, (0, 0.06, 0.0)), "silver", bevel=0.02)


CONCEPTS = {"shackled": shackled, "stalker": stalker, "graft": graft}


# ---------------------------------------------------------------- camera / lights / render
def frame_and_light(view):
    sc = bpy.context.scene
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in sc.objects:
        if o.type == "MESH":   # curve bounds include far-off bezier handles
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    cam_data = bpy.data.cameras.new("cam"); cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
    fov = 2 * math.atan(18 / 50)
    dist = radius / math.sin(fov / 2) * 0.9
    az = math.radians({"front": -62, "back": 128}[view]); el = math.radians(10)
    direction = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
    cam.location = centre + direction * dist
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    for name, d, energy, size in (("key", (0.7, -0.8, 0.9), 800, 4), ("fill", (-0.9, -0.4, 0.4), 260, 6),
                                  ("rim", (-0.3, 0.9, 0.7), 650, 3)):
        ld = bpy.data.lights.new(name, "AREA"); ld.energy = energy; ld.size = size
        lo_ = bpy.data.objects.new(name, ld); sc.collection.objects.link(lo_)
        v = Vector(d).normalized()
        lo_.location = centre + v * (radius * 3 + 4)
        lo_.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    return cam, centre, dist


if __name__ == "__main__":
    for name, build in CONCEPTS.items():
        if ONLY and name not in ONLY:
            continue
        for view in ("front", "back"):
            reset()
            build()
            frame_and_light(view)
            bpy.context.scene.render.filepath = os.path.join(OUT, "%s_%s_transparent.png" % (name, view))
            bpy.ops.render.render(write_still=True)
            print("rendered", name, view)
