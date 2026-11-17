"""Artificer (drone-factory caste) concept renders: three directions for the look, same design language as the
building concepts (art/buildings/concepts/make_concepts.py): polished chrome + dark gunmetal, chamfered angular
plates, faceted violet crystals, thin violet seams, a few dark bio-mechanical cables.

Usage: blender -b -P make_artificer_concepts.py -- <out_dir> [concept ...]
Concepts: reliquary (hangar carried on the back), choir (psionic halo that grows drones), anvil (quadruped foundry).
Every image shows the Artificer at roughly in-game size (Praetor ~2.4 m) with its three drone types around it
(Wasp dart, Lancer halo barrel, Sapper spiked charge).
"""
import bpy, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)


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
        "amber":   mat("amber", (0.9, 0.45, 0.1), 0.0, 0.4, emit=(1.0, 0.45, 0.12), strength=2.5),
        "pink":    mat("pink", (0.9, 0.3, 0.8), 0.0, 0.4, emit=(1.0, 0.35, 0.9), strength=2.5),
    }


def mat(name, color, metal, rough, emit=None, strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
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


def box(sx, sy, sz, loc, m, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def seg(p0, p1, w, d, m, bevel=0.02, twist=0.0):
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
        from mathutils import Quaternion
        q = q @ Quaternion((0, 0, 1), twist)
    o.rotation_quaternion = q
    return finish(o, m, bevel)


def cyl(n, r, p0, p1, m, r2=None, bevel=0.015, smooth=False):
    """n-gon prism / frustum from p0 (radius r) to p1 (radius r2)"""
    p0, p1 = Vector(p0), Vector(p1)
    v = p1 - p0
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if r2 is None else r2, depth=v.length,
                                    location=(p0 + p1) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = v.to_track_quat("Z", "Y")
    return finish(o, m, bevel, smooth)


def ball(r, loc, m, sub=2, smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    return finish(bpy.context.object, m, smooth=smooth)


def ring(R, r, loc, m="glow", rot=(0, 0, 0), n=48):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=n, minor_segments=10,
                                     location=loc, rotation=rot)
    return finish(bpy.context.object, m, smooth=True)


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


def cable(points, r=0.025, m="dark"):
    """smooth bio-mechanical cable through points"""
    cu = bpy.data.curves.new("cable", "CURVE"); cu.dimensions = "3D"
    cu.bevel_depth = r; cu.bevel_resolution = 3
    sp = cu.splines.new("BEZIER"); sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new("cable", cu); bpy.context.scene.collection.objects.link(o)
    cu.materials.append(M[m])
    return o


def group(build, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    """run build(); parent everything it made to an empty at loc/rot"""
    before = set(bpy.data.objects)
    build()
    made = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("grp", None); bpy.context.scene.collection.objects.link(root)
    for o in made:
        o.parent = root
    root.location = loc; root.rotation_euler = rot; root.scale = (scale, scale, scale)
    return root


def mirror(fn):
    for s in (-1, 1):
        fn(s)


# ---------------------------------------------------------------- drones (facing -Y)
def wasp():
    cyl(6, 0.075, (0, 0.20, 0), (0, -0.16, 0), "gun", r2=0.06)
    cyl(6, 0.06, (0, -0.16, 0), (0, -0.27, 0), "silver", r2=0.0)
    ball(0.025, (0, -0.25, 0), "pink", sub=1)
    mirror(lambda s: seg((s * 0.06, 0.0, 0), (s * 0.30, 0.10, 0), 0.10, 0.015, "gun"))
    mirror(lambda s: seg((s * 0.29, 0.06, 0), (s * 0.31, 0.16, 0), 0.025, 0.025, "pink", bevel=0))
    cyl(8, 0.04, (0, 0.20, 0), (0, 0.24, 0), "pink", bevel=0)


def lancer():
    cyl(10, 0.035, (0, -0.05, 0), (0, -0.46, 0), "silver")
    for y in (-0.18, -0.25, -0.32):
        cyl(10, 0.039, (0, y, 0), (0, y - 0.015, 0), "glow", bevel=0)
    ball(0.03, (0, -0.47, 0), "glow", sub=1)
    box(0.24, 0.40, 0.17, (0, 0.12, 0), "gun", bevel=0.03)
    box(0.25, 0.02, 0.05, (0, -0.02, 0), "glow", bevel=0)
    ring(0.24, 0.018, (0, 0.14, 0), "silver", rot=(math.pi / 2, 0, 0))
    ring(0.24, 0.008, (0, 0.10, 0), "glow", rot=(math.pi / 2, 0, 0))


def sapper():
    ball(0.19, (0, 0, 0), "gun", sub=1, smooth=False)
    ring(0.19, 0.022, (0, 0, 0), "amber", rot=(math.pi / 2, 0, 0))
    ball(0.07, (0, -0.17, 0), "amber", sub=1, smooth=False)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cyl(5, 0.03, (sx * 0.10, -0.10, sz * 0.10), (sx * 0.15, -0.33, sz * 0.15), "silver", r2=0.0)
    cyl(8, 0.06, (0, 0.17, 0), (0, 0.26, 0), "amber", r2=0.04, bevel=0)


def drone_swarm(points):
    """points: (builder, loc, yaw, pitch)"""
    for builder, loc, yaw, pitch in points:
        group(builder, loc=loc, rot=(pitch, 0, yaw))


# ---------------------------------------------------------------- shared humanoid parts (facing -Y, z up)
def heavy_leg(s, hip=(0.30, 0.0, 1.10), knee=(0.36, -0.14, 0.60), ankle=(0.37, 0.04, 0.13), w=0.24):
    hip = Vector((s * hip[0], hip[1], hip[2])); knee = Vector((s * knee[0], knee[1], knee[2]))
    ankle = Vector((s * ankle[0], ankle[1], ankle[2]))
    seg(hip, knee, w, w * 1.1, "gun")
    seg(hip + Vector((s * 0.06, -0.06, -0.05)), knee + Vector((s * 0.05, -0.08, 0.08)), w * 0.9, 0.07, "silver")
    ball(w * 0.55, knee, "gun", sub=1, smooth=False)
    box(w * 0.9, 0.10, 0.22, knee + Vector((0, -0.14, 0.02)), "silver", rot=(0.25, 0, 0))
    seg(knee, ankle, w * 0.85, w, "gun")
    seg(knee + Vector((s * 0.03, -0.09, -0.06)), ankle + Vector((s * 0.03, -0.07, 0.12)), w * 0.8, 0.06, "silver")
    seg(knee + Vector((s * 0.0, -0.13, -0.12)), ankle + Vector((0, -0.11, 0.2)), 0.02, 0.01, "glow", bevel=0)
    box(w * 1.2, 0.48, 0.12, ankle + Vector((0, -0.08, -0.07)), "gun", bevel=0.03)
    box(w * 1.0, 0.18, 0.06, ankle + Vector((0, -0.27, -0.02)), "silver", bevel=0.02)


def arm(s, shoulder, elbow, wrist, w=0.17):
    shoulder, elbow, wrist = Vector(shoulder), Vector(elbow), Vector(wrist)
    seg(shoulder, elbow, w, w, "gun")
    ball(w * 0.6, elbow, "gun", sub=1, smooth=False)
    seg(elbow, wrist, w * 1.15, w * 1.15, "silver")
    seg(elbow + Vector((s * 0.07, 0, 0)), wrist + Vector((s * 0.07, 0, 0)), 0.015, w * 0.4, "glow", bevel=0)
    return wrist


def claw_hand(s, wrist, direction=(0, -1, -0.3)):
    wrist = Vector(wrist); d = Vector(direction).normalized()
    ball(0.08, wrist, "gun", sub=1, smooth=False)
    for k in range(3):
        a = k * 2 * math.pi / 3
        off = Vector((math.cos(a) * 0.06, 0, math.sin(a) * 0.06))
        mid = wrist + d * 0.14 + off * 1.4
        seg(wrist + off * 0.6, mid, 0.035, 0.035, "silver")
        seg(mid, wrist + d * 0.26 + off * 0.5, 0.025, 0.025, "silver")
    ball(0.035, wrist + d * 0.16, "glow", sub=1)


def emitter_arm(wrist, direction=(0, -1, -0.15)):
    wrist = Vector(wrist); d = Vector(direction).normalized()
    cyl(8, 0.09, wrist - d * 0.05, wrist + d * 0.22, "gun")
    cyl(10, 0.045, wrist + d * 0.22, wrist + d * 0.48, "silver")
    for t in (0.28, 0.34, 0.40):
        cyl(10, 0.05, wrist + d * t, wrist + d * (t + 0.02), "glow", bevel=0)
    crystal(0.04, 0.07, 0.03, wrist + d * 0.52, tilt=(math.pi / 2, 0, 0))


# ---------------------------------------------------------------- 1: RELIQUARY (hangar on the back)
def reliquary():
    mirror(heavy_leg)
    # pelvis + waist
    box(0.62, 0.40, 0.24, (0, 0.02, 1.12), "gun", bevel=0.04)
    mirror(lambda s: box(0.26, 0.36, 0.32, (s * 0.36, -0.02, 1.02), "silver", rot=(0, s * 0.25, 0), bevel=0.03))
    cyl(8, 0.22, (0, 0.02, 1.22), (0, 0.02, 1.36), "dark", r2=0.26)
    # chest: wide armoured block with the reactor crystal
    cyl(6, 0.48, (0, 0.04, 1.34), (0, 0.04, 1.92), "gun", r2=0.56)
    box(0.82, 0.12, 0.46, (0, -0.32, 1.66), "silver", rot=(-0.12, 0, 0), bevel=0.04)
    box(0.34, 0.06, 0.34, (0, -0.39, 1.64), "dark", rot=(-0.12, 0, 0), bevel=0.02)
    crystal(0.13, 0.17, 0.17, (0, -0.42, 1.64), tilt=(math.pi / 2 - 0.12, 0, 0))
    ring(0.19, 0.012, (0, -0.42, 1.64), "glow", rot=(math.pi / 2 - 0.12, 0, 0))
    # head: sunk between the shoulders, crested helmet + visor slit
    cyl(6, 0.15, (0, -0.06, 1.92), (0, -0.06, 2.18), "silver", r2=0.11)
    box(0.20, 0.04, 0.03, (0, -0.19, 2.06), "glow", bevel=0)
    seg((0, -0.05, 2.18), (0, 0.18, 2.27), 0.03, 0.10, "silver")
    # pauldrons
    mirror(lambda s: box(0.40, 0.52, 0.22, (s * 0.62, 0.02, 1.92), "silver", rot=(0, -s * 0.3, 0), bevel=0.05))
    mirror(lambda s: box(0.36, 0.48, 0.03, (s * 0.64, 0.02, 1.81), "glow", rot=(0, -s * 0.3, 0), bevel=0))
    # arms: left = beam emitter, right = fabricator claw
    w = arm(-1, (-0.62, 0.0, 1.78), (-0.74, -0.08, 1.38), (-0.70, -0.36, 1.16))
    emitter_arm(w, (0.05, -1, 0.05))
    w = arm(1, (0.62, 0.0, 1.78), (0.76, 0.02, 1.36), (0.74, -0.30, 1.10))
    claw_hand(1, w, (0, -1, -0.4))
    # the reliquary: a hexagonal drone hangar carried on the back, launch tubes open upwards
    cyl(6, 0.50, (0, 0.62, 1.10), (0, 0.62, 2.50), "gun", r2=0.42)
    for z in (1.35, 1.80, 2.25):
        cyl(6, 0.53 - (z - 1.1) * 0.06, (0, 0.62, z), (0, 0.62, z + 0.06), "silver")
        cyl(6, 0.535 - (z - 1.1) * 0.06, (0, 0.62, z + 0.06), (0, 0.62, z + 0.075), "glow", bevel=0)
    for k in range(3):
        a = math.radians(-60 + k * 60) + math.pi / 2
        x, y = math.cos(a) * 0.22, 0.62 + math.sin(a) * 0.22
        cyl(6, 0.10, (x, y, 2.30), (x, y, 2.78), "silver")
        cyl(6, 0.075, (x, y, 2.70), (x, y, 2.79), "glow", bevel=0)
    crystal(0.10, 0.30, 0.10, (0, 0.78, 2.70))
    # side racks with docked Sappers and a Wasp leaving the top tube
    mirror(lambda s: box(0.06, 0.50, 0.90, (s * 0.52, 0.62, 1.70), "gun"))
    for s in (-1, 1):
        for z in (1.45, 1.85):
            group(sapper, loc=(s * 0.66, 0.62, z), rot=(0, 0, s * math.pi / 2), scale=0.8)
    # spine cables
    mirror(lambda s: cable([(s * 0.2, 0.30, 1.30), (s * 0.28, 0.45, 1.6), (s * 0.18, 0.40, 1.95)], 0.035))
    drone_swarm([
        (wasp,   (0.25, 0.70, 3.15), math.radians(150), -0.6),
        (wasp,   (-1.15, -0.6, 2.3), math.radians(20), 0.1),
        (lancer, (1.25, -0.4, 2.55), math.radians(-10), 0.05),
        (lancer, (-0.9, 0.6, 2.85), math.radians(40), 0.0),
        (sapper, (1.05, -0.9, 0.9), math.radians(-30), 0.0),
    ])


# ---------------------------------------------------------------- 2: CHOIR (psionic halo grows the drones)
def choir():
    # digitigrade legs
    for s in (-1, 1):
        hip = Vector((s * 0.22, 0.02, 1.25)); knee = Vector((s * 0.26, -0.24, 0.85))
        hock = Vector((s * 0.27, 0.16, 0.42)); foot = Vector((s * 0.27, -0.02, 0.06))
        seg(hip, knee, 0.17, 0.19, "gun"); ball(0.10, knee, "gun", sub=1, smooth=False)
        box(0.18, 0.08, 0.30, knee + Vector((0, -0.10, 0.10)), "silver", rot=(0.4, 0, 0))
        seg(knee, hock, 0.14, 0.15, "silver"); ball(0.08, hock, "gun", sub=1, smooth=False)
        seg(hock, foot, 0.11, 0.12, "gun")
        seg(hock + Vector((0, -0.07, 0)), foot + Vector((0, -0.07, 0.1)), 0.015, 0.01, "glow", bevel=0)
        for k in (-1, 0, 1):
            seg(foot, foot + Vector((k * 0.09, -0.26, -0.03)), 0.05, 0.05, "silver")
    # long plated skirt (robe of hanging armour plates)
    for k in range(10):
        a = math.radians(-90 + (k - 4.5) * 24)
        r = 0.30
        top = Vector((math.cos(a) * r, math.sin(a) * r + 0.02, 1.32))
        bot = Vector((math.cos(a) * (r + 0.16), math.sin(a) * (r + 0.16) + 0.02, 0.78))
        if k in (4, 5):
            continue                               # open at the front for the legs
        seg(top, bot, 0.17, 0.025, "silver" if k % 2 else "gun", twist=a)
        seg(top + (bot - top) * 0.05, bot, 0.012, 0.03, "glow", bevel=0, twist=a)
    cyl(8, 0.30, (0, 0.02, 1.25), (0, 0.02, 1.40), "gun")
    # slender torso, high collar
    cyl(6, 0.25, (0, 0.02, 1.40), (0, 0.02, 1.98), "gun", r2=0.34)
    box(0.44, 0.08, 0.38, (0, -0.24, 1.74), "silver", rot=(-0.15, 0, 0), bevel=0.04)
    crystal(0.07, 0.12, 0.12, (0, -0.29, 1.72), tilt=(math.pi / 2 - 0.15, 0, 0))
    mirror(lambda s: box(0.10, 0.30, 0.30, (s * 0.24, 0.02, 2.06), "silver", rot=(0, s * 0.35, 0)))
    # elongated head with a backswept crest and a glowing face line
    cyl(6, 0.10, (0, -0.02, 2.02), (0, 0.04, 2.36), "silver", r2=0.06)
    seg((0, 0.02, 2.30), (0, 0.30, 2.52), 0.03, 0.12, "silver")
    seg((0, -0.11, 2.12), (0, -0.07, 2.30), 0.02, 0.01, "glow", bevel=0)
    # shoulders + long arms, open hands with glowing palms
    mirror(lambda s: box(0.24, 0.30, 0.14, (s * 0.42, 0.02, 1.98), "silver", rot=(0, -s * 0.45, 0), bevel=0.04))
    for s in (-1, 1):
        w = arm(s, (s * 0.44, 0.02, 1.88), (s * 0.62, -0.12, 1.55), (s * 0.72, -0.42, 1.62), w=0.12)
        ball(0.06, w, "gun", sub=1, smooth=False)
        ball(0.05, w + Vector((0, -0.07, 0.03)), "glow", sub=2)
        for k in range(4):
            a = (k - 1.5) * 0.35
            seg(w, w + Vector((math.sin(a) * 0.08, -0.16, 0.05 + math.cos(a) * 0.03)), 0.022, 0.022, "silver")
        # psionic threads from the palms to the nearest cradle
    # the halo: a floating ring behind the head with six crystal cradles; drones condense inside them
    centre = Vector((0, 0.42, 2.45))
    ring(0.95, 0.035, centre, "silver", rot=(math.radians(75), 0, 0), n=72)
    ring(0.95, 0.012, centre + Vector((0, -0.04, 0)), "glow", rot=(math.radians(75), 0, 0), n=72)
    for k in range(6):
        a = math.radians(90 + k * 60)
        p = centre + Vector((math.cos(a) * 0.95, -math.sin(a) * 0.95 * math.cos(math.radians(75)),
                             math.sin(a) * 0.95 * math.sin(math.radians(75))))
        crystal(0.10, 0.20, 0.20, p, tilt=(0, 0, a))
        ring(0.16, 0.012, p, "glow", rot=(math.radians(75), 0, 0))
    # drones half-formed in two cradles, finished ones peeling away
    group(wasp, loc=(0.55, 0.30, 3.05), rot=(0.3, 0, math.radians(200)), scale=0.9)
    group(sapper, loc=(-0.95, 0.38, 2.70), rot=(0, 0, math.radians(120)), scale=0.75)
    # floating psi-shield plates at the sides (the tank part)
    for s in (-1, 1):
        box(0.05, 0.55, 0.85, (s * 1.05, -0.25, 1.45), "silver", rot=(0, s * 0.15, s * 0.5), bevel=0.03)
        box(0.06, 0.45, 0.05, (s * 1.05, -0.25, 1.45), "glow", rot=(0, s * 0.15, s * 0.5), bevel=0)
    mirror(lambda s: cable([(s * 0.12, 0.25, 1.45), (s * 0.20, 0.32, 1.75), (s * 0.10, 0.28, 2.0)], 0.03))
    drone_swarm([
        (lancer, (1.30, -0.75, 2.30), math.radians(-25), 0.0),
        (lancer, (-1.45, -0.40, 2.75), math.radians(15), 0.05),
        (wasp,   (0.75, -1.25, 1.55), math.radians(-5), 0.1),
        (wasp,   (-0.55, -1.30, 2.05), math.radians(10), -0.05),
    ])


# ---------------------------------------------------------------- 3: ANVIL (quadruped foundry)
def anvil():
    # hull: low armoured foundry block
    box(1.20, 1.70, 0.62, (0, 0.20, 1.05), "gun", bevel=0.06)
    box(1.30, 1.40, 0.10, (0, 0.25, 1.40), "silver", bevel=0.04)
    box(1.36, 0.06, 0.40, (0, -0.66, 1.05), "silver", bevel=0.03)
    mirror(lambda s: box(0.08, 1.50, 0.40, (s * 0.64, 0.20, 1.02), "silver", bevel=0.03))
    mirror(lambda s: box(0.02, 1.30, 0.03, (s * 0.69, 0.20, 1.10), "glow", bevel=0))
    # four legs (spider stance)
    for sx in (-1, 1):
        for sy in (-1, 1):
            hip = Vector((sx * 0.55, 0.20 + sy * 0.62, 0.95))
            knee = Vector((sx * 1.05, 0.20 + sy * 1.00, 1.30))
            foot = Vector((sx * 1.30, 0.20 + sy * 1.20, 0.08))
            ball(0.16, hip, "gun", sub=1, smooth=False)
            seg(hip, knee, 0.22, 0.24, "gun")
            box(0.26, 0.30, 0.10, knee + Vector((0, 0, 0.12)), "silver", rot=(0, sx * 0.5, 0))
            ball(0.13, knee, "gun", sub=1, smooth=False)
            seg(knee, foot, 0.18, 0.20, "silver")
            seg(knee + Vector((sx * 0.1, 0, 0)), foot + Vector((sx * 0.1, 0, 0.3)), 0.015, 0.02, "glow", bevel=0)
            cyl(6, 0.20, foot + Vector((0, 0, -0.06)), foot + Vector((0, 0, 0.06)), "gun", r2=0.14)
    # front: command torso rising out of the hull, head + beam emitter arms
    cyl(6, 0.36, (0, -0.48, 1.30), (0, -0.52, 1.85), "gun", r2=0.30)
    box(0.56, 0.10, 0.36, (0, -0.80, 1.62), "silver", rot=(-0.2, 0, 0), bevel=0.04)
    crystal(0.10, 0.14, 0.14, (0, -0.86, 1.60), tilt=(math.pi / 2 - 0.2, 0, 0))
    cyl(6, 0.13, (0, -0.55, 1.85), (0, -0.58, 2.10), "silver", r2=0.10)
    box(0.18, 0.04, 0.03, (0, -0.68, 2.00), "glow", bevel=0)
    mirror(lambda s: box(0.30, 0.36, 0.16, (s * 0.38, -0.50, 1.86), "silver", rot=(0, -s * 0.35, 0), bevel=0.04))
    w = arm(-1, (-0.42, -0.50, 1.76), (-0.56, -0.72, 1.48), (-0.50, -1.02, 1.42), w=0.14)
    emitter_arm(w, (0.05, -1, 0.0))
    w = arm(1, (0.42, -0.50, 1.76), (0.58, -0.70, 1.46), (0.50, -1.00, 1.38), w=0.14)
    claw_hand(1, w, (0, -1, -0.2))
    # back: foundry chimneys venting psionic glow
    for x, y in ((-0.30, 0.70), (0.30, 0.70), (0.0, 0.95)):
        cyl(6, 0.13, (x, y, 1.40), (x, y, 2.05), "gun", r2=0.10)
        cyl(6, 0.105, (x, y, 2.05), (x, y, 2.10), "glow", bevel=0)
    # assembly cradle on the back: two crane arms holding a Lancer mid-assembly
    box(0.70, 0.60, 0.08, (0, 0.15, 1.50), "dark", bevel=0.02)
    ring(0.32, 0.015, (0, 0.15, 1.56), "glow", rot=(0, 0, 0))
    for s in (-1, 1):
        base = Vector((s * 0.45, 0.30, 1.50)); elbow = Vector((s * 0.55, 0.05, 2.20)); tip = Vector((s * 0.18, 0.12, 2.05))
        seg(base, elbow, 0.08, 0.08, "silver"); ball(0.06, elbow, "gun", sub=1, smooth=False)
        seg(elbow, tip, 0.06, 0.06, "silver"); ball(0.035, tip, "glow", sub=1)
    group(lancer, loc=(0, 0.12, 1.98), rot=(0, 0, math.radians(90)))
    # magazine racks of Sappers along both flanks
    for s in (-1, 1):
        for y in (-0.15, 0.25, 0.65):
            group(sapper, loc=(s * 0.82, y, 1.48), rot=(0, 0, s * math.pi / 2), scale=0.7)
    cable([(-0.2, -0.3, 1.45), (0.0, -0.1, 1.62), (0.2, -0.3, 1.45)], 0.04)
    drone_swarm([
        (wasp,   (-1.30, -1.10, 1.90), math.radians(25), 0.0),
        (wasp,   (-0.70, -1.60, 2.25), math.radians(10), 0.1),
        (wasp,   (1.10, -1.30, 2.10), math.radians(-20), -0.05),
        (lancer, (1.40, 0.20, 2.60), math.radians(-60), 0.0),
    ])


# ---------------------------------------------------------------- Anvil variants (user picked the Anvil lore)
def spider_leg(hip, knee, foot, w=0.20, plate=True):
    hip, knee, foot = Vector(hip), Vector(knee), Vector(foot)
    ball(w * 0.75, hip, "gun", sub=1, smooth=False)
    seg(hip, knee, w, w * 1.1, "gun")
    if plate:
        seg(hip + (knee - hip) * 0.15 + Vector((0, 0, 0.09)), knee + Vector((0, 0, 0.09)), w * 1.2, 0.05, "silver")
    ball(w * 0.65, knee, "gun", sub=1, smooth=False)
    seg(knee, foot, w * 0.85, w * 0.9, "silver")
    out = Vector((knee.x - hip.x, knee.y - hip.y, 0)).normalized() * 0.07
    seg(knee + out, foot + out + Vector((0, 0, 0.25)), 0.015, 0.02, "glow", bevel=0)
    cyl(6, w * 0.95, foot + Vector((0, 0, -0.06)), foot + Vector((0, 0, 0.07)), "gun", r2=w * 0.65)


def chimney(x, y, z0, z1, r=0.12):
    cyl(6, r, (x, y, z0), (x, y, z1), "gun", r2=r * 0.78)
    cyl(6, r * 0.82, (x, y, z1), (x, y, z1 + 0.05), "glow", bevel=0)


def crane(base, elbow, tip):
    base, elbow, tip = Vector(base), Vector(elbow), Vector(tip)
    seg(base, elbow, 0.08, 0.08, "silver"); ball(0.06, elbow, "gun", sub=1, smooth=False)
    seg(elbow, tip, 0.06, 0.06, "silver"); ball(0.035, tip, "glow", sub=1)


def sensor_head(loc, size=1.0):
    loc = Vector(loc)
    cyl(6, 0.16 * size, loc, loc + Vector((0, -0.05, 0.24 * size)), "silver", r2=0.11 * size)
    box(0.22 * size, 0.04, 0.035, loc + Vector((0, -0.16 * size, 0.13 * size)), "glow", bevel=0)
    seg(loc + Vector((0, 0.02, 0.22 * size)), loc + Vector((0, 0.24 * size, 0.32 * size)), 0.03, 0.1 * size, "silver")


# A  STRIDER: six-legged, three hull segments - front command head, assembly cradle, rear launch rail
def anvil_strider():
    for y, l in ((-0.70, 0.62), (0.10, 0.75), (0.92, 0.66)):
        box(1.00, l, 0.52, (0, y, 1.08), "gun", bevel=0.05)
        box(1.08, l - 0.1, 0.08, (0, y, 1.38), "silver", bevel=0.03)
        mirror(lambda s: box(0.02, l - 0.15, 0.03, (s * 0.55, y, 1.12), "glow", bevel=0))
    for y in (-0.33, 0.52):
        cyl(8, 0.26, (0, y - 0.08, 1.08), (0, y + 0.08, 1.08), "dark", bevel=0.01)
    for y, spread in ((-0.70, -0.35), (0.10, 0.0), (0.92, 0.35)):
        for sx in (-1, 1):
            spider_leg((sx * 0.50, y, 0.95), (sx * 1.05, y + spread * 0.6, 1.45), (sx * 1.40, y + spread, 0.08), 0.17)
    # front: sensor head, beam emitter and a claw under the chin
    sensor_head((0, -0.92, 1.36))
    w = arm(-1, (-0.36, -0.95, 1.10), (-0.48, -1.15, 0.95), (-0.40, -1.40, 0.98), w=0.12)
    emitter_arm(w, (0.03, -1, 0.05))
    w = arm(1, (0.36, -0.95, 1.10), (0.48, -1.15, 0.92), (0.40, -1.38, 0.90), w=0.12)
    claw_hand(1, w, (0, -1, -0.25))
    # middle: assembly cradle with cranes
    ring(0.30, 0.015, (0, 0.10, 1.44), "glow")
    for s in (-1, 1):
        crane((s * 0.42, 0.28, 1.42), (s * 0.50, 0.05, 2.05), (s * 0.16, 0.10, 1.88))
    group(lancer, loc=(0, 0.08, 1.80), rot=(0, 0, math.radians(90)))
    # rear: chimneys + launch rail with Wasps
    chimney(-0.30, 1.10, 1.40, 2.00); chimney(0.30, 1.10, 1.40, 1.90)
    seg((0, 0.70, 1.45), (0, 1.25, 2.05), 0.30, 0.06, "silver")
    mirror(lambda s: seg((s * 0.15, 0.70, 1.48), (s * 0.15, 1.25, 2.08), 0.02, 0.03, "glow", bevel=0))
    group(wasp, loc=(0, 0.95, 1.80), rot=(-0.85, 0, math.pi), scale=0.9)
    # Sapper magazine under the belly
    for y in (-0.55, -0.15, 0.30, 0.70):
        group(sapper, loc=(0, y, 0.68), rot=(0, 0, math.pi / 2), scale=0.65)
    box(0.12, 1.70, 0.06, (0, 0.10, 0.85), "gun")
    drone_swarm([
        (wasp,   (-1.20, -1.55, 2.00), math.radians(25), 0.0),
        (wasp,   (1.15, 1.75, 2.45), math.radians(160), 0.4),
        (lancer, (1.35, -1.20, 2.30), math.radians(-20), 0.0),
    ])


# B  CRUCIBLE: round crab-like body on six legs, a furnace dome on top, two big pincers
def anvil_crucible():
    cyl(8, 0.85, (0, 0.05, 0.80), (0, 0.05, 1.15), "gun", r2=0.80)
    cyl(8, 0.88, (0, 0.05, 1.15), (0, 0.05, 1.22), "silver")
    cyl(8, 0.89, (0, 0.05, 0.98), (0, 0.05, 1.01), "glow", bevel=0)
    cyl(8, 0.60, (0, 0.05, 0.70), (0, 0.05, 0.80), "silver", r2=0.85)
    # furnace dome: frustum with glowing slots, an open iris on top showing the crystal core
    cyl(8, 0.62, (0, 0.10, 1.22), (0, 0.10, 1.70), "gun", r2=0.38)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        p0 = Vector((math.cos(a) * 0.60, 0.10 + math.sin(a) * 0.60, 1.26))
        p1 = Vector((math.cos(a) * 0.40, 0.10 + math.sin(a) * 0.40, 1.66))
        seg(p0, p1, 0.04, 0.02, "glow", bevel=0)
    ring(0.30, 0.04, (0, 0.10, 1.72), "silver")
    crystal(0.16, 0.38, 0.12, (0, 0.10, 1.70))
    for k in range(6):                                    # iris petals, opened
        a = k * math.pi / 3
        seg((math.cos(a) * 0.30, 0.10 + math.sin(a) * 0.30, 1.72),
            (math.cos(a) * 0.48, 0.10 + math.sin(a) * 0.48, 1.95), 0.16, 0.025, "silver", twist=a)
    group(wasp, loc=(0.05, 0.05, 2.45), rot=(-1.2, 0, 0.6))
    # six legs radiating from the rim
    for a_deg in (40, 0, -40):
        for sx in (-1, 1):
            a = math.radians(a_deg)
            d = Vector((sx * math.cos(a), math.sin(a), 0))
            hip = Vector((0, 0.05, 0.95)) + d * 0.75
            spider_leg(hip, hip + d * 0.55 + Vector((0, 0, 0.55)), hip + d * 1.10 + Vector((0, 0, -0.87)), 0.16)
    # eye cluster + beam emitter between the pincers
    for x in (-0.12, 0, 0.12):
        ball(0.04, (x, -0.80, 1.12 + (0.04 if x == 0 else 0)), "glow", sub=2)
    cyl(8, 0.07, (0, -0.78, 0.95), (0, -1.05, 0.95), "gun")
    cyl(10, 0.035, (0, -1.05, 0.95), (0, -1.28, 0.95), "silver")
    crystal(0.035, 0.06, 0.02, (0, -1.31, 0.95), tilt=(math.pi / 2, 0, 0))
    # pincers: shoulder, forearm, two jaws; the right one holds a Sapper being assembled
    for s in (-1, 1):
        sh = Vector((s * 0.55, -0.62, 1.05)); el = Vector((s * 0.95, -1.05, 1.35)); wr = Vector((s * 0.65, -1.45, 1.10))
        ball(0.13, sh, "gun", sub=1, smooth=False)
        seg(sh, el, 0.16, 0.16, "gun"); ball(0.11, el, "gun", sub=1, smooth=False)
        seg(el, wr, 0.22, 0.20, "silver")
        seg(el + Vector((0, 0, 0.11)), wr + Vector((0, 0, 0.11)), 0.02, 0.02, "glow", bevel=0)
        jaw_dir = Vector((-s * 0.25, -1, 0)).normalized()
        seg(wr + Vector((0, 0, 0.08)), wr + jaw_dir * 0.35 + Vector((0, 0, 0.10)), 0.10, 0.06, "silver")
        seg(wr - Vector((0, 0, 0.08)), wr + jaw_dir * 0.30 - Vector((0, 0, 0.12)), 0.09, 0.06, "gun")
    group(sapper, loc=(0.48, -1.80, 1.10), rot=(0, 0, 0.3), scale=0.85)
    # belly pods with Sappers
    for a in range(0, 360, 72):
        r = math.radians(a)
        group(sapper, loc=(math.cos(r) * 0.42, 0.05 + math.sin(r) * 0.42, 0.55), rot=(0, 0, r), scale=0.6)
    drone_swarm([
        (lancer, (-1.45, -1.30, 2.10), math.radians(20), 0.0),
        (lancer, (1.50, 0.90, 2.30), math.radians(140), 0.0),
        (wasp,   (-0.80, -1.90, 1.70), math.radians(10), 0.1),
    ])


# C  FORGEWARDEN: centaur - humanoid command torso on a four-legged foundry body
def anvil_forgewarden():
    box(0.95, 1.55, 0.55, (0, 0.30, 1.10), "gun", bevel=0.06)
    box(1.03, 1.30, 0.08, (0, 0.35, 1.42), "silver", bevel=0.03)
    mirror(lambda s: box(0.08, 1.35, 0.38, (s * 0.50, 0.30, 1.05), "silver", bevel=0.03))
    mirror(lambda s: box(0.02, 1.15, 0.03, (s * 0.555, 0.30, 1.12), "glow", bevel=0))
    # four heavy digitigrade legs
    for sy in (-1, 1):
        for sx in (-1, 1):
            hip = Vector((sx * 0.48, 0.30 + sy * 0.55, 0.98))
            knee = hip + Vector((sx * 0.25, -0.30 if sy < 0 else 0.30, -0.38))
            hock = knee + Vector((sx * 0.05, 0.28 if sy < 0 else -0.10, -0.30))
            foot = Vector((hock.x, hock.y - 0.12, 0.08))
            ball(0.15, hip, "gun", sub=1, smooth=False)
            seg(hip, knee, 0.22, 0.24, "gun")
            box(0.26, 0.10, 0.34, (hip + knee) / 2 + Vector((sx * 0.08, -0.08, 0)), "silver", rot=(0.2, sx * 0.3, 0))
            ball(0.12, knee, "gun", sub=1, smooth=False)
            seg(knee, hock, 0.17, 0.18, "silver")
            ball(0.09, hock, "gun", sub=1, smooth=False)
            seg(hock, foot, 0.14, 0.15, "gun")
            box(0.26, 0.36, 0.10, foot + Vector((0, -0.08, -0.03)), "gun", bevel=0.03)
            seg(knee + Vector((sx * 0.1, 0, 0)), hock + Vector((sx * 0.1, 0, 0.05)), 0.015, 0.015, "glow", bevel=0)
    # upright torso at the front (the Artificer itself)
    cyl(6, 0.34, (0, -0.35, 1.30), (0, -0.40, 1.95), "gun", r2=0.42)
    box(0.62, 0.10, 0.40, (0, -0.72, 1.72), "silver", rot=(-0.15, 0, 0), bevel=0.04)
    crystal(0.10, 0.14, 0.14, (0, -0.78, 1.70), tilt=(math.pi / 2 - 0.15, 0, 0))
    ring(0.16, 0.012, (0, -0.79, 1.70), "glow", rot=(math.pi / 2 - 0.15, 0, 0))
    sensor_head((0, -0.45, 1.95), 1.05)
    mirror(lambda s: box(0.36, 0.44, 0.18, (s * 0.50, -0.38, 1.95), "silver", rot=(0, -s * 0.3, 0), bevel=0.05))
    mirror(lambda s: box(0.32, 0.40, 0.03, (s * 0.52, -0.38, 1.85), "glow", rot=(0, -s * 0.3, 0), bevel=0))
    w = arm(-1, (-0.52, -0.40, 1.82), (-0.66, -0.52, 1.46), (-0.60, -0.84, 1.30), w=0.15)
    emitter_arm(w, (0.04, -1, 0.05))
    w = arm(1, (0.52, -0.40, 1.82), (0.68, -0.48, 1.44), (0.62, -0.80, 1.22), w=0.15)
    claw_hand(1, w, (0, -1, -0.35))
    # foundry back: magazine spine of docked Wasps, chimneys, cradle with a Sapper
    seg((0, 0.10, 1.48), (0, 1.00, 1.75), 0.12, 0.10, "silver")
    for t, s in ((0.25, -1), (0.45, 1), (0.65, -1), (0.85, 1)):
        p = Vector((0, 0.10, 1.48)) + (Vector((0, 0.90, 0.27))) * t
        group(wasp, loc=p + Vector((s * 0.22, 0, 0.10)), rot=(0, 0, math.pi + s * 0.2), scale=0.75)
    chimney(-0.32, 0.95, 1.45, 2.15); chimney(0.32, 0.95, 1.45, 2.05); chimney(0, 1.02, 1.45, 2.30, 0.10)
    ring(0.22, 0.015, (0, 0.40, 1.48), "glow")
    group(sapper, loc=(0, 0.40, 1.72), scale=0.9)
    for s in (-1, 1):
        crane((s * 0.36, 0.62, 1.46), (s * 0.40, 0.40, 2.05), (s * 0.12, 0.40, 1.85))
    cable([(-0.25, -0.15, 1.40), (-0.30, 0.05, 1.70), (-0.10, 0.20, 1.55)], 0.035)
    cable([(0.25, -0.15, 1.40), (0.30, 0.05, 1.70), (0.10, 0.20, 1.55)], 0.035)
    drone_swarm([
        (lancer, (-1.25, -1.10, 2.40), math.radians(20), 0.0),
        (wasp,   (1.10, -1.30, 2.20), math.radians(-15), 0.0),
        (sapper, (-1.05, -0.60, 0.80), math.radians(15), 0.0),
    ])


CONCEPTS = {"reliquary": reliquary, "choir": choir, "anvil": anvil,
            "anvil_strider": anvil_strider, "anvil_crucible": anvil_crucible, "anvil_forgewarden": anvil_forgewarden}


# ---------------------------------------------------------------- camera / lights / render
def frame_and_light():
    sc = bpy.context.scene
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in sc.objects:
        if o.type in ("MESH", "CURVE"):
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2

    cam_data = bpy.data.cameras.new("cam"); cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
    fov = 2 * math.atan(18 / 50)
    dist = radius / math.sin(fov / 2) * 0.92
    # the figures face -Y: camera front-right, slightly above
    az, el = math.radians(-62), math.radians(14)
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


for name, build in CONCEPTS.items():
    if ONLY and name not in ONLY:
        continue
    reset()
    build()
    frame_and_light()
    bpy.context.scene.render.filepath = os.path.join(OUT, name + "_transparent.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
