"""Subject "Stalker" player model: the chitin predator from concepts/make_subject_concepts.py, worked out for the game.

Usage: blender -b --factory-startup -P build_stalker.py -- <work_dir> [bake_size=2048]
Writes to <work_dir>:
  stalker_apose.blend   object "robot": one mesh in the marine A-pose (built on the marine joint positions, facing
                        -Y), UV-unwrapped, material slot 0 = "stalker" (body), slot 1 = "stalker_blades" (forearm
                        blades + finger talons: face set 1, hidden by Client.lua while the claws aren't drawn)
  bake_albedo.png, bake_metallic.png, bake_roughness.png, bake_normal.png, bake_emission.png
                        Cycles bakes of the procedural materials (robot/make_ns2_textures.py "baked" mode)
  stalker_preview_front.png / _back.png
The rig (marine skeleton, unchanged) is added afterwards by art/skeleton/rig_robot.py (VT_NOFIT=1).
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "concepts"))
argv = sys.argv[sys.argv.index("--") + 1:]
WORK = os.path.abspath(argv[0])
BAKE = int(argv[1]) if len(argv) > 1 else 2048
os.makedirs(WORK, exist_ok=True)
sys.argv = [sys.argv[0], "--", WORK]          # the concept module parses argv on import
import make_subject_concepts as mc
from make_subject_concepts import j, lerp, mirror, box, seg, cyl, ball, spike, cable

BLADE_OBJECTS = []
BONE_OF = {}      # object name -> marine bone it rides on rigidly (everything but the flesh body)


def bone_segments():
    segs = [("Hip", j("pelvis"), j("belly")), ("Spine2", j("belly"), j("chest")), ("Spine3", j("chest"), j("neck")),
            ("Neck", j("neck"), j("head")), ("Head", j("head"), j("head") + Vector((0, 0, 0.12)))]
    for s, L in ((1, "L"), (-1, "R")):
        wrist = "LArm_Wrist02" if s == 1 else "RArm_Wrist01"
        segs += [(L + "Arm_Clavicle", j("upchest"), j("clav", s)), (L + "Arm_Shoulder", j("shoulder", s), j("elbow", s)),
                 (L + "Arm_Elbow", j("elbow", s), j("wrist", s)), (wrist, j("wrist", s), j("hand", s)),
                 (L + "Leg_Hip", j("hip", s), j("knee", s)), (L + "Leg_Knee", j("knee", s), j("ankle", s)),
                 (L + "Leg_Ankle", j("ankle", s), j("toe", s)),
                 (L + "Leg_Toe", j("toe", s), j("toe", s) + Vector((0, -0.08, 0)))]
    return segs


def nearest_bone(p):
    best, bd = None, 1e9
    for name, a, b in bone_segments():
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        d = (a + ab * t - p).length
        if d < bd:
            best, bd = name, d
    return best


def on_bone(bone, fn):
    """everything fn() creates rides rigidly on bone"""
    before = set(bpy.data.objects)
    fn()
    for o in bpy.data.objects:
        if o not in before:
            BONE_OF[o.name] = bone


def blades(fn):
    """everything fn() creates belongs to face set 1 (the claws)"""
    before = set(bpy.data.objects)
    fn()
    BLADE_OBJECTS.extend(o for o in bpy.data.objects if o not in before)


def plate(p0, p1, w, d, m="chitin", taper=0.55):
    """hexagonal chitin sleeve along a bone, flattened front/back, tapering"""
    o = cyl(6, w * 0.62, p0, p1, m, r2=w * 0.62 * taper, bevel=0.006)
    o.scale = (1, d / w, 1)
    return o


def curved(base, direction, length, segs, w0, d0, m, bend=(0, -1, -0.4), curl=0.5, flat=True):
    """tapering curved blade / claw from base; flat=True -> blade (w >> d), else round"""
    d = Vector(direction).normalized(); b = Vector(bend).normalized()
    p = Vector(base); w, dd = w0, d0
    pts = [p.copy()]
    for i in range(segs):
        nd = (d + b * curl * (i + 1) / segs).normalized()
        q = p + nd * length / segs
        k = 1 - (i + 1) / segs
        if flat:
            seg(p, q, w, dd, m, bevel=0.002, twist=0.0)
            w, dd = max(0.004, w0 * (0.25 + 0.75 * k)), max(0.003, d0 * (0.4 + 0.6 * k))
        else:
            cyl(6, w, p, q, m, r2=max(0.002, w * 0.6))
            w *= 0.6
        p = q; pts.append(p.copy())
    return pts


def stalker_model():
    R = {"pelvis": (0.12, 0.09), "belly": (0.085, 0.08), "chest": (0.15, 0.11), "upchest": (0.17, 0.11),
         "neck": (0.055, 0.055), "clav": (0.065, 0.065), "shoulder": (0.075, 0.075), "bicep": (0.06, 0.06),
         "elbow": (0.045, 0.045), "forearm": (0.055, 0.05), "wrist": (0.04, 0.035), "hand": (0.04, 0.035),
         "hip": (0.08, 0.08), "thigh": (0.085, 0.085), "knee": (0.05, 0.055), "calf": (0.06, 0.065),
         "ankle": (0.04, 0.045), "toe": (0.035, 0.03)}
    R["head"] = (0.05, 0.055)          # flesh runs up into the head: the neck bridges Spine3 -> Neck -> Head
    R["ankle"], R["toe"] = (0.03, 0.032), (0.015, 0.015)    # flesh foot stays inside the scaled bird shank
    body = mc.skin_body(R, "fleshd", subdiv=1, head=True,
                        offsets={"head": (0, -0.04, -0.03), "toe": (0, 0.043, -0.012)})   # flesh toe -> the ball
    body["vt_skin"] = True

    # ---- torso carapace: overlapping plates front and back, glowing seams between them
    for i, z in enumerate((1.58, 1.49, 1.40, 1.31, 1.22)):
        w = 0.36 - abs(i - 1) * 0.05
        box(w, 0.06, 0.10, (0, -0.10 + i * 0.012, z), "chitin", rot=(0.25, 0, 0), bevel=0.02)
        box(w * 0.9, 0.012, 0.012, (0, -0.135 + i * 0.012, z - 0.05), "glow", rot=(0.25, 0, 0), bevel=0)
        box(w * 0.95, 0.06, 0.10, (0, 0.14 - i * 0.008, z + 0.02), "chitin", rot=(-0.3, 0, 0), bevel=0.02)
    # pelvis plates
    box(0.26, 0.20, 0.08, (0, 0.0, 1.12), "chitin", bevel=0.02)
    mirror(lambda s: box(0.10, 0.16, 0.12, (s * 0.15, 0.0, 1.06), "chitin", rot=(0, s * 0.3, 0), bevel=0.015))
    # dorsal crystal blades
    for i, z in enumerate((1.62, 1.50, 1.38, 1.26)):
        spike(0.03, 0.22 - i * 0.03, (0, 0.18, z), (0, 1, 0.9))

    # ---- head: swept-back eyeless crest, glowing slit, side horns, mandibles
    hc = j("head", 1, (0, -0.04, -0.02))
    on_bone("Head", lambda: head_parts(hc))


def head_parts(hc):
    ball(0.06, hc, "fleshd", sub=3)
    cyl(6, 0.075, hc + Vector((0, -0.06, -0.02)), hc + Vector((0, 0.30, 0.10)), "chitin", r2=0.012, bevel=0.004)
    cyl(6, 0.05, hc + Vector((0, -0.10, -0.05)), hc + Vector((0, 0.02, 0.0)), "chitin", r2=0.06, bevel=0.004)
    box(0.09, 0.01, 0.012, hc + Vector((0, -0.105, -0.01)), "glow", bevel=0)
    mirror(lambda s: spike(0.02, 0.16, hc + Vector((s * 0.05, 0.02, 0.03)), (s * 0.5, 1, 0.5), "chitin"))
    mirror(lambda s: curved(hc + Vector((s * 0.03, -0.08, -0.07)), (s * 0.3, -1, -0.6), 0.10, 3, 0.012, 0, "bone",
                            curl=0.2, flat=False))


# marine leg pivots (bone heads, art/skeleton/marine_reference.blend): hinges are centred on them so the rigid parts
# of neighbouring bones turn about the same axis instead of tearing apart
LEG_PIVOT = {"hip": (0.104, -0.003, 1.110), "knee": (0.128, 0.016, 0.647), "ankle": (0.152, 0.091, 0.133),
             "ball": (0.164, -0.067, 0.038)}


def pv(name, s, off=(0, 0, 0)):
    p = LEG_PIVOT[name]
    return Vector((p[0] * s + off[0] * s, p[1] + off[1], p[2] + off[2]))


def hinge(centre, s, r, depth=0.035, core="glow"):
    """actuator disk on the outside of a joint, axis = the leg's x (knee / ankle swing axis)"""
    out = Vector((s, 0, 0))
    cyl(10, r, centre - out * depth / 2, centre + out * depth / 2, "gun", bevel=0.004)
    cyl(10, r * 0.7, centre + out * depth / 2, centre + out * (depth / 2 + 0.008), "silver", bevel=0.002)
    cyl(10, r * 0.38, centre + out * (depth / 2 + 0.008), centre + out * (depth / 2 + 0.014), core)


def piston(top, bottom, r, split=0.55, mount_top=None, mount_bottom=None):
    """hydraulic: dark housing from top, chrome rod into it from bottom, glowing seal ring at the join;
    mount_*: points on the limb the ends are bracketed to"""
    top, bottom = Vector(top), Vector(bottom)
    for end, mount in ((top, mount_top), (bottom, mount_bottom)):
        if mount is not None:
            seg(end, Vector(mount), r * 0.9, r * 1.4, "gun", bevel=0.002)
    mid = lerp(top, bottom, split)
    cyl(8, r, top, mid, "gun", bevel=0.003)
    cyl(8, r * 0.45, lerp(top, bottom, split - 0.1), bottom, "silver")
    cyl(8, r * 1.08, lerp(top, bottom, split - 0.03), mid, "glow")
    ball(r * 0.9, top, "silver", sub=1); ball(r * 0.8, bottom, "silver", sub=1)


def leg(s):
    """chitin leg with a mechanical exo-frame: hip actuator, outer struts, knee / ankle hinges, thigh + calf pistons;
    digitigrade foot with three clawed toes, heel spur and dew claw. Every part rides one bone (on_bone)."""
    L = "L" if s == 1 else "R"
    hp, kn, an, bl = pv("hip", s), pv("knee", s), pv("ankle", s), pv("ball", s)
    out = Vector((s, 0, 0))

    def thigh():
        plate(lerp(j("hip", s), j("knee", s), 0.12), lerp(j("hip", s), j("knee", s), 0.86), 0.155, 0.13)
        hinge(hp + out * 0.105, s, 0.07, depth=0.045)                                  # hip actuator
        seg(hp + out * 0.10 + Vector((0, 0.0, -0.06)), kn + out * 0.085 + Vector((0, 0.0, 0.05)), 0.03, 0.05,
            "silver", bevel=0.006)                                                    # outer strut
        seg(hp + out * 0.06 + Vector((0, 0.09, -0.08)), kn + out * 0.05 + Vector((0, 0.07, 0.07)), 0.022, 0.03,
            "gun", bevel=0.004)                                                       # rear strut
        piston(hp + Vector((s * 0.02, -0.10, -0.10)), kn + Vector((s * 0.01, -0.085, 0.10)), 0.022,
               mount_top=hp + Vector((s * 0.02, -0.04, -0.10)), mount_bottom=kn + Vector((s * 0.01, -0.03, 0.10)))
        box(0.10, 0.03, 0.012, lerp(hp, kn, 0.5) + out * 0.112, "glow", rot=(0, 0, 0), bevel=0)

    def shin():
        plate(lerp(j("knee", s), j("ankle", s), 0.12), lerp(j("knee", s), j("ankle", s), 0.86), 0.115, 0.11)
        hinge(kn + out * 0.085, s, 0.055)                                              # knee hinge
        box(0.11, 0.05, 0.12, kn + Vector((0, -0.07, 0.0)), "chitin", rot=(-0.2, 0, 0), bevel=0.02)  # kneecap
        spike(0.025, 0.12, kn + Vector((0, -0.08, 0.04)), (0, -0.6, 1), "chitin")
        seg(kn + out * 0.08 + Vector((0, 0, -0.05)), an + out * 0.075 + Vector((0, 0, 0.05)), 0.026, 0.04,
            "silver", bevel=0.005)                                                    # outer strut
        piston(kn + Vector((0, 0.085, -0.10)), an + Vector((0, 0.06, 0.15)), 0.024,      # calf piston
               mount_top=kn + Vector((0, 0.03, -0.10)), mount_bottom=an + Vector((0, 0.01, 0.15)))
        for t in (0.35, 0.6):
            box(0.05, 0.012, 0.012, lerp(kn, an, t) + out * 0.09, "glow", bevel=0)

    def foot():
        hinge(an + out * 0.075, s, 0.045, depth=0.03)                                  # ankle hinge
        # chrome stirrup under the heel (exo-frame)
        seg(an + Vector((-s * 0.045, 0.06, -0.06)), an + Vector((s * 0.045, 0.06, -0.06)), 0.03, 0.03, "silver")
        seg(an + out * 0.075, an + Vector((s * 0.045, 0.06, -0.06)), 0.02, 0.02, "silver")
        seg(an - out * 0.045 + Vector((0, 0, 0.02)), an + Vector((-s * 0.045, 0.06, -0.06)), 0.02, 0.02, "silver")
        # bird shank (tarsometatarsus): scaled core, overlapping scutes down the front, spur at the back
        top, bot = an + Vector((0, 0.0, -0.01)), bl + Vector((0, 0.01, 0.012))
        axis = (bot - top).normalized()
        front = (Vector((0, -1, 0)) - axis * axis.dot(Vector((0, -1, 0)))).normalized()
        cyl(10, 0.046, top, bot, "scales", r2=0.036)
        ball(0.047, top, "scales", sub=2)                                             # ankle joint cap
        n = 7
        for i in range(n):
            t0, t1 = i / n, (i + 1.35) / n
            r = 0.046 + (0.036 - 0.046) * (t0 + t1) / 2
            seg(lerp(top, bot, t0) + front * (r * 0.92), lerp(top, bot, min(t1, 1.0)) + front * (r * 0.98),
                r * 1.55, 0.011, "chitin", bevel=0)
        spike(0.014, 0.06, lerp(top, bot, 0.35) - front * 0.04, (-s * 0.25, 1, -0.2), "bone")   # spur

    def bird_toe(base, yaw, lengths, radii, heights, talon):
        """one toe: phalanx segments (scaled), knuckles, scutes on top, pads underneath, hooked talon"""
        d = Vector((s * math.sin(yaw), -math.cos(yaw), 0))
        pts = [Vector((base.x, base.y, heights[0]))]
        for i, ln in enumerate(lengths):
            q = pts[-1] + d * ln
            pts.append(Vector((q.x, q.y, heights[i + 1])))
        up = Vector((0, 0, 1))
        for i in range(len(lengths)):
            p0, p1, r0, r1 = pts[i], pts[i + 1], radii[i], radii[i + 1]
            cyl(8, r0, p0, p1, "scales", r2=r1)
            seg(lerp(p0, p1, 0.12) + up * r0 * 0.78, lerp(p0, p1, 1.04) + up * r1 * 0.86, r0 * 1.25, 0.006,
                "chitin", bevel=0.0025)                                               # scute
            ball(r1 * 1.06, p1, "scales", sub=1)                                      # knuckle
            pad = lerp(p0, p1, 0.55)
            ball(r0 * 1.05, Vector((pad.x, pad.y, max(r0 * 0.5, pad.z - r0 * 0.55))), "fleshd", sub=1,
                 scale=(1.0, 1.25, 0.6))                                              # pad
        tip = pts[-1]
        curved(tip + d * radii[-1] * 0.6, (d.x, d.y, 0.55), talon, 4, radii[-1] * 1.25, 0, "bone",
               bend=(d.x * 0.15, d.y * 0.15, -1), curl=1.25, flat=False)              # talon
        return pts

    def toes():
        # three forward toes like a raptor's: inner (II, 3 phalanges), middle (III, 4, longest), outer (IV, 4)
        H3, H4 = (0.034, 0.026, 0.022, 0.02), (0.034, 0.027, 0.023, 0.021, 0.02)
        bird_toe(bl + Vector((-s * 0.022, 0.0, 0)), math.radians(-24), (0.055, 0.045, 0.035),
                 (0.021, 0.018, 0.015, 0.012), H3, 0.075)
        bird_toe(bl + Vector((0, -0.006, 0)), 0.0, (0.055, 0.048, 0.04, 0.03),
                 (0.023, 0.02, 0.017, 0.014, 0.012), H4, 0.085)
        bird_toe(bl + Vector((s * 0.022, 0.0, 0)), math.radians(27), (0.05, 0.042, 0.034, 0.026),
                 (0.02, 0.017, 0.015, 0.013, 0.011), H4, 0.07)

    def hallux():
        # back toe (I): short, points back and inward, big talon - the wall grip from behind
        bird_toe(bl + Vector((-s * 0.02, 0.045, 0)), math.radians(180 + 20), (0.04, 0.032),
                 (0.02, 0.017, 0.014), (0.034, 0.026, 0.022), 0.07)

    on_bone(L + "Leg_Hip", thigh)
    on_bone(L + "Leg_Knee", shin)
    on_bone(L + "Leg_Ankle", foot)
    on_bone(L + "Leg_Ankle", hallux)
    on_bone(L + "Leg_Toe", toes)


def limbs_and_tail():
    for s in (-1, 1):
        # ---- limb armour along every bone, glowing joints
        for a, b, w, d in (("shoulder", "elbow", 0.12, 0.10), ("elbow", "wrist", 0.11, 0.09)):
            pa, pb = j(a, s), j(b, s)
            plate(lerp(pa, pb, 0.10), lerp(pa, pb, 0.90), w, d)
            ball(0.03, pb, "glow", sub=2)
        on_bone(("L" if s == 1 else "R") + "Arm_Shoulder", lambda: (
            box(0.17, 0.20, 0.07, j("shoulder", s, (0.03, 0, 0.07)), "chitin", rot=(0, s * 0.45, 0), bevel=0.025),
            spike(0.025, 0.14, j("shoulder", s, (0.08, 0.03, 0.10)), (s * 0.6, 0.4, 1))))
        leg(s)

        # ---- claws (face set 1): long scything blade along each forearm + three finger talons
        def claw_set(s=s):
            w0, el = j("wrist", s), j("elbow", s)
            fwd = (w0 - el).normalized()
            start = lerp(el, w0, 0.55) + Vector((s * 0.05, 0.0, 0.0))
            pts = curved(start, fwd + Vector((s * 0.12, -0.25, -0.2)), 0.55, 6, 0.09, 0.014, "silver",
                         bend=(0, -1, -0.3), curl=0.7)
            for p, q in zip(pts[:-2], pts[1:-1]):     # glowing edge along the blade's spine
                seg(p + Vector((s * 0.008, 0.0, 0.0)), q + Vector((s * 0.008, 0.0, 0.0)), 0.008, 0.016, "glow", bevel=0)
            box(0.07, 0.06, 0.09, start + Vector((-s * 0.01, 0.0, 0.02)), "gun", bevel=0.01)   # blade mount
            for k in (-1, 0, 1):
                curved(j("hand", s) + Vector((0, -0.01 + k * 0.022, -0.03)), (s * 0.1, -0.2 + k * 0.1, -1), 0.17,
                       3, 0.013, 0, "bone", curl=0.5, flat=False)
        blades(lambda: on_bone("LArm_Wrist02" if s == 1 else "RArm_Wrist01", claw_set))

    # ---- short tail (on the hip bone)
    on_bone("Hip", lambda: (cable([(0, 0.12, 1.10), (0, 0.30, 1.0), (0, 0.42, 0.78), (0, 0.46, 0.60)], 0.035, "chitin"),
                            spike(0.03, 0.12, (0, 0.46, 0.62), (0, 0.1, -1))))


# ---------------------------------------------------------------- build, join, unwrap, bake
def build_all():
    stalker_model()
    limbs_and_tail()


mc.reset()
# game materials: matte flesh, satin chitin (the concept's gloss reads as plastic once baked)
for key, rough, metal in (("fleshd", 0.62, 0.0), ("chitin", 0.38, 0.4), ("bone", 0.5, 0.05)):
    p = mc.M[key].node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough; p.inputs["Metallic"].default_value = metal
mc.M["chitin"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.045, 0.025, 0.075, 1)


def scale_material():
    """bird-foot skin: small reticulate scales (voronoi cell edges as bump, darker in the grooves)"""
    m = mc.mat("scales", (0.07, 0.045, 0.085), 0.2, 0.5)
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 130
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.7
    bump.inputs["Distance"].default_value = 0.003
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0; ramp.color_ramp.elements[0].color = (0.015, 0.01, 0.02, 1)
    ramp.color_ramp.elements[1].position = 0.12; ramp.color_ramp.elements[1].color = (0.07, 0.045, 0.085, 1)
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    nt.links.new(vor.outputs["Distance"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"]); nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    mc.M["scales"] = m


scale_material()
build_all()
sc = bpy.context.scene
blade_names = {o.name for o in BLADE_OBJECTS}

# curves -> meshes (low resolution), every modifier applied
for o in list(sc.objects):
    if o.type == "CURVE":
        o.data.resolution_u = 4; o.data.bevel_resolution = 1
        bpy.ops.object.select_all(action="DESELECT"); o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target="MESH")
meshes = [o for o in sc.objects if o.type == "MESH"]
RIGID_BONES = []
for o in meshes:
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    # mark the claw faces (survives the join as a face attribute)
    attr = o.data.attributes.new("vt_blade", "BOOLEAN", "FACE")
    for i in range(len(o.data.polygons)):
        attr.data[i].value = o.name in blade_names
    # rigid bone per vertex (-1 = flesh body: keeps the weights transferred from the marine skin)
    if o.get("vt_skin"):
        bone = None
    else:
        bone = BONE_OF.get(o.name) or nearest_bone(o.matrix_world @ (sum((v.co for v in o.data.vertices), Vector()) / max(1, len(o.data.vertices))))
    battr = o.data.attributes.new("vt_bone", "INT", "POINT")
    if bone and bone not in RIGID_BONES:
        RIGID_BONES.append(bone)
    idx = RIGID_BONES.index(bone) if bone else -1
    for i in range(len(o.data.vertices)):
        battr.data[i].value = idx
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
robot = bpy.context.object
robot.name = "robot"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
robot.data["vt_rigid_bones"] = RIGID_BONES
print("STALKER rigid parts on", ", ".join(RIGID_BONES))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
me = robot.data
me.set_sharp_from_angle(angle=math.radians(50))
tris = len(me.polygons)
print("STALKER tris", tris, "verts", len(me.vertices))

# bake every map from the procedural materials
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.use_denoising = False
bake = sc.render.bake
bake.margin = 6
images = {}
for name in ("albedo", "metallic", "roughness", "normal", "emission"):
    img = bpy.data.images.new("bake_" + name, BAKE, BAKE, float_buffer=False)
    if name in ("metallic", "roughness", "normal"):
        img.colorspace_settings.name = "Non-Color"
    images[name] = img
mats = [s.material for s in robot.material_slots]


def set_target(img):
    for m in mats:
        nt = m.node_tree
        node = nt.nodes.get("vt_bake") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "vt_bake"; node.image = img
        nt.nodes.active = node


def run(kind, img, **kw):
    set_target(img)
    bpy.ops.object.select_all(action="DESELECT"); robot.select_set(True)
    bpy.context.view_layer.objects.active = robot
    bpy.ops.object.bake(type=kind, **kw)
    img.filepath_raw = os.path.join(WORK, img.name + ".png"); img.file_format = "PNG"; img.save()
    print("BAKED", img.name)


run("DIFFUSE", images["albedo"], pass_filter={"COLOR"})
run("ROUGHNESS", images["roughness"])
run("NORMAL", images["normal"], normal_space="TANGENT")
run("EMIT", images["emission"])
# metallic: temporarily route each material's metallic value into its emission
saved = {}
for m in mats:
    p = m.node_tree.nodes["Principled BSDF"]
    saved[m.name] = (tuple(p.inputs["Emission Color"].default_value), p.inputs["Emission Strength"].default_value)
    v = p.inputs["Metallic"].default_value
    p.inputs["Emission Color"].default_value = (v, v, v, 1); p.inputs["Emission Strength"].default_value = 1.0
    for link in list(m.node_tree.links):          # nothing else may light up
        if link.to_socket == p.inputs["Emission Color"]:
            m.node_tree.links.remove(link)
run("EMIT", images["metallic"])
for m in mats:
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Emission Color"].default_value, p.inputs["Emission Strength"].default_value = saved[m.name]

# ---- two game materials: body (0) and claws (1), faces sorted by the vt_blade attribute
blade_attr = me.attributes["vt_blade"]
body_mat = bpy.data.materials.new("stalker"); blade_mat = bpy.data.materials.new("stalker_blades")
for mt in (body_mat, blade_mat):
    mt.use_nodes = True
    t = mt.node_tree.nodes.new("ShaderNodeTexImage"); t.image = images["albedo"]
    mt.node_tree.links.new(t.outputs["Color"], mt.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
me.materials.clear(); me.materials.append(body_mat); me.materials.append(blade_mat)
nblade = 0
for poly in me.polygons:
    is_blade = blade_attr.data[poly.index].value
    poly.material_index = 1 if is_blade else 0
    nblade += is_blade
me.attributes.remove(me.attributes["vt_blade"])
print("STALKER claw tris", nblade)

for o in list(sc.objects):
    if o != robot:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "stalker_apose.blend"))
print("SAVED stalker_apose.blend")

# ---- preview with the baked textures (what the game gets)
for mt in (body_mat, blade_mat):
    nt = mt.node_tree; p = nt.nodes["Principled BSDF"]
    for key, img, col in (("Roughness", images["roughness"], False), ("Metallic", images["metallic"], False),
                          ("Emission Color", images["emission"], True)):
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img
        nt.links.new(t.outputs["Color"], p.inputs[key])
    p.inputs["Emission Strength"].default_value = 3.0
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = images["normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x = sc.render.resolution_y = 900
for view in ("front", "back"):
    for o in [o for o in sc.objects if o.type in ("CAMERA", "LIGHT")]:
        bpy.data.objects.remove(o, do_unlink=True)
    mc.frame_and_light(view)
    sc.render.filepath = os.path.join(WORK, "stalker_preview_%s.png" % view)
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", view)
