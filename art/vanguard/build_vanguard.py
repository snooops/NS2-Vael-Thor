# ============================================================================
# Vael'Thor Vanguard - procedural blockout from concept art (vanguard.png)
# Run:  blender -b -P build_vanguard.py
# Produces vanguard.blend + preview renders next to this script.
# Units: metres, Z up, character faces -Y. Height ~1.95 m (NS2 marine ~1.8 m).
# ============================================================================
import bpy, bmesh, math, os
from mathutils import Vector, Euler

OUT = os.path.dirname(os.path.abspath(__file__))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- materials
def mat(name, base, metal=0.8, rough=0.35, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*base, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha < 1:
        p.inputs["Alpha"].default_value = alpha
        if hasattr(m, "blend_method"):
            m.blend_method = "BLEND"
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
    return m

M_ARMOR  = mat("VT_Armor",  (0.09, 0.093, 0.11), 0.85, 0.32)
M_UNDER  = mat("VT_Under",  (0.018, 0.018, 0.022), 0.3, 0.7)
M_TRIM   = mat("VT_Trim",   (0.12, 0.12, 0.14), 0.95, 0.22)
M_GLOW   = mat("VT_Glow",   (0.5, 0.1, 1.0), 0.0, 0.3, (0.55, 0.1, 1.0), 3)
M_VISOR  = mat("VT_Visor",  (0.4, 0.05, 0.9), 0.0, 0.2, (0.6, 0.15, 1.0), 5)
M_SHIELD = mat("VT_Shield", (0.1, 0.9, 1.0), 0.0, 0.1, (0.15, 0.9, 1.0), 1.5, alpha=0.3)
M_PLASMA = mat("VT_Plasma", (0.9, 0.3, 1.0), 0.0, 0.2, (0.9, 0.3, 1.0), 6)

COL = bpy.data.collections.new("Vanguard")
scene.collection.children.link(COL)

def finish(obj, material, bevel=0.012, segs=2):
    COL.objects.link(obj)
    obj.data.materials.append(material)
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj

def box(name, size, loc, material=M_ARMOR, rot=(0, 0, 0), taper=None, bevel=0.012):
    """Box; taper=(sx, sy) scales the +Z face for wedge/armour shapes."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
        if taper and v.co.z > 0:
            v.co.x *= taper[0]; v.co.y *= taper[1]
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(o, material, bevel)

def cyl(name, r, depth, loc, material=M_ARMOR, rot=(0, 0, 0), verts=12, r2=None, bevel=0.006):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r,
                          radius2=r if r2 is None else r2, depth=depth)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    return finish(o, material, bevel)

def mirrored(fn, name, size, loc, *a, rot=(0, 0, 0), **k):
    """Create the left (+X) part and its right mirror."""
    x, y, z = loc
    fn(name + ".L", size, (x, y, z), *a, rot=rot, **k)
    fn(name + ".R", size, (-x, y, z), *a, rot=(rot[0], -rot[1], -rot[2]), **k)

# ---------------------------------------------------------------- helmet
# Angular helm with a forward point and a raised crest (concept: arrowhead).
def hull(name, pts, material=M_ARMOR, mirror=True, bevel=0.006):
    """Convex hull of points; mirror=True adds the -X copy of every point."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    all_pts = list(pts) + ([(-x, y, z) for x, y, z in pts if x != 0] if mirror else [])
    for p in all_pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    return finish(o, material, bevel)

def bar(name, p0, p1, thick=0.012, material=None):
    """Thin glowing strip from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    o = box(name, (thick, thick, d.length), (p0 + p1) / 2, material or M_GLOW, bevel=0)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o

# Kite helm (concept): wide, flat pyramid crown overhanging the face, mask
# tapering to a pointed chin with a centre ridge, purple V lines on the face.
def on_surface(obj, x, z, lift=0.006):
    """Point on obj's front (-Y) surface at (x, z), lifted slightly off it."""
    hit, loc, normal, _ = obj.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
    assert hit, (obj.name, x, z)
    return loc + normal * lift

def helmet():
    # crown: low pyramid; the brim drops to a point over the face
    hull("Helm_Crown", [
        (0.00, -0.235, 1.835),          # forward brow point
        (0.185, -0.07, 1.86), (0.17, 0.11, 1.86), (0.00, 0.17, 1.86),
        (0.14, -0.06, 1.83), (0.12, 0.09, 1.835), (0.00, -0.19, 1.815), (0.00, 0.13, 1.835),
        (0.00, -0.03, 1.935),           # apex
    ])
    hull("Helm_CrownRidge", [
        (0.012, -0.228, 1.842), (0.012, -0.03, 1.942), (0.012, 0.16, 1.866),
        (0.0, -0.228, 1.835), (0.0, 0.16, 1.86),
    ], M_TRIM, bevel=0.002)
    # face mask: wide under the brow, keeled, narrowing to a pointed chin
    mask = hull("Helm_Mask", [
        (0.00, -0.185, 1.82), (0.135, -0.10, 1.83), (0.15, 0.05, 1.83),
        (0.00, -0.175, 1.71),           # keel
        (0.105, -0.10, 1.70), (0.125, 0.05, 1.71),
        (0.00, -0.14, 1.585),           # chin point
        (0.045, -0.09, 1.61), (0.07, 0.03, 1.62),
    ])
    hull("Helm_Back", [
        (0.12, 0.00, 1.83), (0.10, 0.12, 1.83), (0.00, 0.14, 1.83),
        (0.09, 0.02, 1.64), (0.06, 0.09, 1.64), (0.00, 0.10, 1.64),
    ], M_UNDER)
    bpy.context.view_layer.update()
    for s in (1, -1):
        # purple V lines: brow corner down towards the chin, on the mask
        a0 = on_surface(mask, s * 0.115, 1.81)
        a1 = on_surface(mask, s * 0.065, 1.71)
        a2 = on_surface(mask, s * 0.022, 1.63)
        bar(f"Helm_GlowV1.{s}", a0, a1)
        bar(f"Helm_GlowV2.{s}", a1, a2)
        # slanted eye slit just under the brow
        bar(f"Helm_Eye.{s}", on_surface(mask, s * 0.025, 1.785), on_surface(mask, s * 0.09, 1.80),
            thick=0.016, material=M_VISOR)
helmet()

# ---------------------------------------------------------------- torso
# V-shaped power armour (concept): broad chest, narrow segmented waist.
from mathutils import Matrix

chest = hull("Chest", [
    (0.22, -0.12, 1.53), (0.24, 0.10, 1.53), (0.00, -0.15, 1.54), (0.00, 0.14, 1.54),
    (0.22, -0.16, 1.38), (0.23, 0.12, 1.38), (0.00, -0.18, 1.38),
    (0.16, -0.13, 1.23), (0.17, 0.11, 1.23), (0.00, -0.14, 1.22), (0.00, 0.11, 1.22),
])
hull("Waist", [
    (0.15, -0.10, 1.25), (0.16, 0.09, 1.25), (0.00, -0.11, 1.25), (0.00, 0.10, 1.25),
    (0.12, -0.085, 1.00), (0.13, 0.075, 1.00), (0.00, -0.10, 1.00), (0.00, 0.09, 1.00),
], M_UNDER)
# high collar / gorget the helmet sits in
hull("Gorget", [
    (0.13, -0.09, 1.52), (0.16, 0.07, 1.52), (0.00, -0.13, 1.52), (0.00, 0.13, 1.52),
    (0.10, -0.07, 1.62), (0.11, 0.06, 1.63), (0.00, -0.09, 1.60), (0.00, 0.10, 1.64),
], M_TRIM)
# angled pectoral plates meeting in a V, with purple chevrons
bpy.context.view_layer.update()
for s in (1, -1):
    pec = hull(f"Pec.{s}", [
        (s * 0.015, -0.175, 1.50), (s * 0.20, -0.145, 1.52), (s * 0.235, -0.15, 1.40), (s * 0.03, -0.20, 1.29),
        (s * 0.015, -0.145, 1.50), (s * 0.20, -0.115, 1.52), (s * 0.235, -0.12, 1.40), (s * 0.03, -0.17, 1.29),
    ], mirror=False)
    bpy.context.view_layer.update()
    bar(f"PecGlow.{s}", on_surface(pec, s * 0.205, 1.40), on_surface(pec, s * 0.05, 1.32))
    bar(f"PecGlowTop.{s}", on_surface(pec, s * 0.06, 1.48), on_surface(pec, s * 0.18, 1.495), thick=0.009)
    # side ribs below the chest
    hull(f"Rib.{s}", [
        (s * 0.17, -0.12, 1.30), (s * 0.20, -0.06, 1.33), (s * 0.15, -0.11, 1.22), (s * 0.17, -0.05, 1.22),
        (s * 0.15, -0.10, 1.30), (s * 0.18, -0.05, 1.33),
    ], mirror=False)
# angular centre plate where the pecs meet (concept: hexagonal sternum)
sternum = hull("Sternum", [
    (0.0, -0.205, 1.46), (0.035, -0.198, 1.43), (0.035, -0.198, 1.36), (0.0, -0.205, 1.33),
    (0.0, -0.17, 1.46), (0.035, -0.165, 1.43), (0.035, -0.165, 1.36), (0.0, -0.17, 1.33),
], M_TRIM, bevel=0.003)
# segmented abdomen: two columns of plates, narrowing to the waist
for i, (z, w) in enumerate(((1.205, 0.105), (1.135, 0.095), (1.065, 0.085))):
    for sx in (1, -1):
        hull(f"AbPlate{i}.{sx}", [
            (sx * 0.010, -0.140, z + 0.028), (sx * w, -0.118, z + 0.028),
            (sx * 0.010, -0.138, z - 0.028), (sx * w * 0.92, -0.115, z - 0.028),
            (sx * 0.010, -0.105, z + 0.028), (sx * w, -0.09, z + 0.028),
            (sx * 0.010, -0.105, z - 0.028), (sx * w * 0.92, -0.09, z - 0.028),
        ], mirror=False, bevel=0.004)
    # flank plates beside the abs
    for sx in (1, -1):
        hull(f"Flank{i}.{sx}", [
            (sx * (w + 0.012), -0.11, z + 0.026), (sx * (w + 0.045), -0.06, z + 0.026),
            (sx * (w + 0.008), -0.105, z - 0.026), (sx * (w + 0.04), -0.055, z - 0.026),
            (sx * (w + 0.01), -0.08, z), (sx * (w + 0.03), -0.03, z),
        ], M_TRIM if i == 1 else M_ARMOR, mirror=False, bevel=0.003)
# belt, hip pouches, thigh holster, tassets
hull("Belt", [(0.17, -0.12, 1.00), (0.18, 0.10, 1.00), (0, -0.13, 1.00), (0, 0.11, 1.00),
              (0.17, -0.12, 0.94), (0.18, 0.10, 0.94), (0, -0.13, 0.94), (0, 0.11, 0.94)], M_TRIM)
box("BeltGlow", (0.06, 0.012, 0.03), (0, -0.135, 0.97), M_GLOW, bevel=0)
box("HipPouch", (0.05, 0.10, 0.08), (0.10, 0.13, 0.95), M_UNDER, bevel=0.008)
box("HipPouch2", (0.05, 0.10, 0.08), (-0.10, 0.13, 0.95), M_UNDER, bevel=0.008)
box("Holster", (0.05, 0.10, 0.18), (-0.25, -0.01, 0.72), M_UNDER, rot=(0, 0, 0), bevel=0.01)
box("HolsterBand", (0.012, 0.11, 0.03), (-0.226, -0.01, 0.76), M_TRIM, bevel=0.003)
# diagonal strap from the left hip down to the holster on the right thigh
bar("Strap", (0.16, -0.135, 0.985), (-0.19, -0.11, 0.86), thick=0.022, material=M_TRIM)
# front tassets: two layered plates per side over the hips
for sx in (1, -1):
    hull(f"Tasset.{sx}", [
        (sx * 0.03, -0.135, 0.94), (sx * 0.17, -0.11, 0.94), (sx * 0.04, -0.15, 0.82), (sx * 0.175, -0.12, 0.83),
        (sx * 0.03, -0.11, 0.94), (sx * 0.17, -0.085, 0.94), (sx * 0.04, -0.125, 0.82), (sx * 0.175, -0.095, 0.83),
    ], mirror=False)
    hull(f"HipPlate.{sx}", [
        (sx * 0.17, -0.10, 0.96), (sx * 0.17, 0.08, 0.96), (sx * 0.22, -0.08, 0.84), (sx * 0.22, 0.07, 0.84),
        (sx * 0.15, -0.09, 0.96), (sx * 0.15, 0.07, 0.96), (sx * 0.20, -0.07, 0.84), (sx * 0.20, 0.06, 0.84),
    ], mirror=False)

# ---------------------------------------------------------------- back: shield booster
box("Backpack", (0.34, 0.14, 0.36), (0, 0.20, 1.36), M_ARMOR, taper=(0.9, 1))
for s in (1, -1):
    cyl(f"BoosterCell.{s}", 0.045, 0.32, (s * 0.12, 0.28, 1.40), M_TRIM)
    cyl(f"BoosterCore.{s}", 0.028, 0.27, (s * 0.12, 0.31, 1.40), M_GLOW)
    box(f"BoosterFin.{s}", (0.025, 0.14, 0.18), (s * 0.17, 0.24, 1.60), M_ARMOR, rot=(-25, 0, s * -10), taper=(1, 0.3))
box("BoosterEmitter", (0.08, 0.04, 0.08), (0, 0.285, 1.57), M_GLOW, bevel=0.004)

# ---------------------------------------------------------------- arms
def dome(name, center, radii, tilt_deg, side, material=M_ARMOR, rings=4, segs=10, theta_max=90):
    """Faceted ellipsoid cap (pauldron plate), tilted outwards.  theta_max > 90
    wraps the cap below its equator so it closes around the joint."""
    rot = Matrix.Rotation(math.radians(-side * tilt_deg), 4, "Y")
    pts = []
    for r in range(rings + 1):
        th = math.radians(theta_max) * r / rings
        for k in range(segs):
            ph = 2 * math.pi * k / segs
            v = Vector((math.sin(th) * math.cos(ph) * radii[0], math.sin(th) * math.sin(ph) * radii[1],
                        math.cos(th) * radii[2]))
            pts.append(tuple(rot @ v + Vector(center)))
    return hull(name, pts, material, mirror=False, bevel=0.004)

def dome_point(center, radii, tilt_deg, side, th_deg, ph_deg, lift=0.008):
    rot = Matrix.Rotation(math.radians(-side * tilt_deg), 4, "Y")
    th, ph = math.radians(th_deg), math.radians(ph_deg)
    v = Vector((math.sin(th) * math.cos(ph) * (radii[0] + lift), math.sin(th) * math.sin(ph) * (radii[1] + lift),
                math.cos(th) * (radii[2] + lift)))
    return rot @ v + Vector(center)

def limb(name, p0, p1, r0, r1, material=M_ARMOR, flat=1.0, sides=8, bevel=0.004):
    """Tapered faceted tube from p0 (radius r0) to p1 (radius r1)."""
    p0, p1 = Vector(p0), Vector(p1)
    q = (p1 - p0).to_track_quat("Z", "Y")
    pts = []
    for c, r in ((p0, r0), (p1, r1)):
        for k in range(sides):
            a = 2 * math.pi * (k + 0.5) / sides
            pts.append(tuple(c + q @ Vector((math.cos(a) * r, math.sin(a) * r * flat, 0))))
    return hull(name, pts, material, mirror=False, bevel=bevel)

def outward(p0, p1, side_dir):
    """Unit vector perpendicular to p0->p1, pointing towards side_dir."""
    d = (Vector(p1) - Vector(p0)).normalized()
    v = Vector(side_dir) - d * d.dot(Vector(side_dir))
    return v.normalized()

def lerp(a, b, t):
    return Vector(a).lerp(Vector(b), t)

# Grip points on the carbine (see carbine()): right hand on the pistol grip,
# left hand on the vertical foregrip.
GRIP_R = Vector((-0.02, -0.295, 1.03))
GRIP_L = Vector((-0.02, -0.585, 1.02))
ARM_JOINTS = {}

def hand(side, grip, grip_r=0.028):
    """Armoured glove wrapped around a vertical grip.  Palm on the outer side,
    four curled fingers around the front (-Y), thumb around the back."""
    s = 1 if side == "L" else -1
    palm_c = grip + Vector((s * (grip_r + 0.022), 0.012, 0.0))
    # palm / back-of-hand plate
    hull(f"Palm.{side}", [
        tuple(palm_c + Vector((dx, dy, dz)))
        for dx in (-0.014, 0.014) for dy in (-0.035, 0.04) for dz in (-0.045, 0.045)
    ], M_UNDER, mirror=False, bevel=0.006)
    hull(f"HandGuard.{side}", [
        tuple(palm_c + Vector((s * 0.02 + dx, dy, dz)))
        for dx in (-0.006, 0.006) for dy in (-0.03, 0.035) for dz in (-0.038, 0.04)
    ], M_ARMOR, mirror=False, bevel=0.004)
    # fingers: three joints curling around the grip, stacked down the grip
    for f, dz in enumerate((0.032, 0.011, -0.010, -0.030)):
        r = grip_r + 0.012
        pts = []
        for ang in (0, 55, 110, 160):   # degrees around the grip, from the palm side
            a = math.radians(ang)
            # start on the palm side (s*X), sweep through the front (-Y)
            pts.append(grip + Vector((s * math.cos(a) * r, -math.sin(a) * r, dz)))
        pts[0] = pts[0] + Vector((s * 0.012, -0.03, 0))   # knuckle at the palm's front edge
        for i in range(len(pts) - 1):
            limb(f"Finger{f}_{i}.{side}", pts[i], pts[i + 1], 0.0105, 0.0095,
                 M_ARMOR if i == 0 else M_UNDER, sides=6, bevel=0.002)
    # thumb: from the palm's back edge around the rear (+Y) of the grip
    r = grip_r + 0.012
    t0 = palm_c + Vector((0, 0.035, 0.03))
    t1 = grip + Vector((s * math.cos(math.radians(60)) * r, math.sin(math.radians(60)) * r, 0.045))
    t2 = grip + Vector((-s * math.cos(math.radians(70)) * r, math.sin(math.radians(70)) * r, 0.05))
    limb(f"Thumb0.{side}", t0, t1, 0.012, 0.011, M_ARMOR, sides=6, bevel=0.002)
    limb(f"Thumb1.{side}", t1, t2, 0.011, 0.009, M_UNDER, sides=6, bevel=0.002)
    return palm_c

def arm(side):
    """Legionnaire arm: light segmented energy armour over a dark undersuit."""
    s = 1 if side == "L" else -1
    # shoulder joint: undersuit ball linking chest and upper arm
    joint = Vector((s * 0.30, 0.0, 1.44))
    dome(f"ShoulderJoint.{side}", tuple(joint - Vector((0, 0, 0.0))), (0.068, 0.072, 0.068), 0, s,
         M_UNDER, rings=5, segs=10, theta_max=180)
    # main pauldron: closed rounded cap wrapping over the joint and down the arm
    c0, r0, t0 = (s * 0.31, 0.0, 1.43), (0.115, 0.13, 0.105), 18
    dome(f"Pauldron.{side}", c0, r0, t0, s, rings=6, segs=12, theta_max=118)
    # outer plate: layered over the side of the cap, hugging the upper arm
    c1, r1, t1 = (s * 0.36, 0.0, 1.37), (0.075, 0.11, 0.05), 68
    dome(f"Pauldron2.{side}", c1, r1, t1, s, M_TRIM, rings=4, segs=12, theta_max=100)
    # purple accent following the outer curve of the cap, front to back
    pts = [dome_point(c0, r0, t0, s, 40, (180 if s < 0 else 0) + d, lift=0.006) for d in range(-70, 71, 10)]
    for i in range(len(pts) - 1):
        bar(f"PauldronGlow{i}.{side}", pts[i], pts[i + 1], thick=0.011)

    # joints: rifle hold, left elbow forward under the barrel, right elbow low
    shoulder = Vector((s * 0.31, 0.0, 1.44))
    palm = hand(side, GRIP_L if s > 0 else GRIP_R)
    elbow = Vector((0.27, -0.20, 1.17)) if s > 0 else Vector((-0.29, 0.0, 1.13))
    wrist = palm + (elbow - palm).normalized() * 0.055
    ARM_JOINTS[side] = (shoulder, elbow, wrist)
    out_u = outward(shoulder, elbow, (s, 0.3, 0))
    out_f = outward(elbow, wrist, (s, 0, 0.6))

    # undersuit
    limb(f"UpperArmSuit.{side}", shoulder, elbow, 0.060, 0.052, M_UNDER, sides=8)
    limb(f"ForearmSuit.{side}", elbow, wrist, 0.052, 0.042, M_UNDER, sides=8)
    # segmented upper-arm guard (overlapping bands, each flaring at its top)
    for i, (ta, tb) in enumerate(((0.18, 0.40), (0.38, 0.60), (0.58, 0.80))):
        limb(f"ArmBand{i}.{side}", lerp(shoulder, elbow, ta), lerp(shoulder, elbow, tb),
             0.078 - i * 0.004, 0.069 - i * 0.004, M_ARMOR, flat=0.92)
    # elbow cop: pointed plate on the outside/back of the elbow
    tip = elbow + out_u * 0.08 + (elbow - lerp(elbow, wrist, 0.3)).normalized() * 0.03
    hull(f"ElbowCop.{side}", [tuple(elbow + out_u * 0.045 + Vector(d)) for d in
                              ((0.03, 0.03, 0.03), (-0.03, 0.03, 0.03), (0.03, -0.03, -0.03), (-0.03, -0.03, -0.03))]
         + [tuple(tip)], M_TRIM, mirror=False)
    # vambrace: slim forearm guard, slightly flared at the wrist
    v0, v1 = lerp(elbow, wrist, 0.18), lerp(elbow, wrist, 0.95)
    limb(f"Vambrace.{side}", v0, v1, 0.060, 0.066, M_ARMOR, flat=0.85)
    limb(f"Cuff.{side}", lerp(elbow, wrist, 0.86), lerp(elbow, wrist, 1.05), 0.071, 0.068, M_TRIM, flat=0.85)
    # energy-armour seam along the vambrace
    bar(f"VambraceGlow.{side}", lerp(elbow, wrist, 0.25) + out_f * 0.058, lerp(elbow, wrist, 0.85) + out_f * 0.064,
        thick=0.010)
    # Personal Shield Boost emitter on the outer forearm (hex node, glowing core)
    node = lerp(elbow, wrist, 0.5) + out_f * 0.063
    limb(f"ShieldNode.{side}", node, node + out_f * 0.018, 0.026, 0.022, M_TRIM, sides=6, bevel=0.002)
    limb(f"ShieldNodeCore.{side}", node + out_f * 0.012, node + out_f * 0.024, 0.014, 0.012, M_GLOW, sides=6, bevel=0)
    # glow line down the upper arm, under the bands
    bar(f"ArmGlow.{side}", lerp(shoulder, elbow, 0.2) + out_u * 0.082, lerp(shoulder, elbow, 0.78) + out_u * 0.072,
        thick=0.009)
arm("L"); arm("R")

# glowing booster hose: backpack -> right shield node (concept)
def hose():
    shoulder, elbow, wrist = ARM_JOINTS["R"]
    end = lerp(elbow, wrist, 0.45) + outward(elbow, wrist, (-1, 0, 0.6)) * 0.07
    cd = bpy.data.curves.new("HoseCurve", "CURVE")
    cd.dimensions = "3D"; cd.bevel_depth = 0.014; cd.bevel_resolution = 2
    sp = cd.splines.new("BEZIER")
    pts = [(-0.14, 0.24, 1.48), (-0.40, 0.16, 1.38), (-0.44, 0.04, 1.20), tuple(end)]
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    tmp = bpy.data.objects.new("HoseTmp", cd)
    scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp); bpy.data.curves.remove(cd)
    finish(bpy.data.objects.new("Hose", me), M_GLOW, bevel=0)
hose()

# ---------------------------------------------------------------- legs
def leg(side):
    """Armoured leg (concept): layered thigh plates, pointed knee cop,
    tapered greave with a purple strip, heavy boot with ankle cuff."""
    s = 1 if side == "L" else -1
    hip = Vector((s * 0.105, 0.0, 0.93))
    knee = Vector((s * 0.135, -0.015, 0.52))
    ankle = Vector((s * 0.16, 0.01, 0.12))
    out_t = outward(hip, knee, (s, 0, 0))
    fwd_t = outward(hip, knee, (0, -1, 0))
    fwd_s = outward(knee, ankle, (0, -1, 0))
    out_s = outward(knee, ankle, (s, 0, 0))
    # undersuit
    limb(f"ThighSuit.{side}", hip, knee, 0.085, 0.062, M_UNDER, sides=8)
    limb(f"ShinSuit.{side}", knee, ankle, 0.056, 0.042, M_UNDER, sides=8)
    # thigh: armour shell + outer plate + front plate
    limb(f"Thigh.{side}", lerp(hip, knee, 0.05), lerp(hip, knee, 0.82), 0.105, 0.076, M_ARMOR, flat=0.95)
    t0, t1 = lerp(hip, knee, 0.12), lerp(hip, knee, 0.70)
    hull(f"ThighOuter.{side}", [tuple(p + out_t * d + fwd_t * f) for p, d in ((t0, 0.116), (t1, 0.088))
                                for f in (-0.05, 0.05)] +
         [tuple(p + out_t * d + fwd_t * f) for p, d in ((t0, 0.095), (t1, 0.072)) for f in (-0.055, 0.055)],
         M_TRIM, mirror=False, bevel=0.003)
    tf0, tf1 = lerp(hip, knee, 0.30), lerp(hip, knee, 0.86)
    hull(f"ThighFront.{side}", [tuple(p + fwd_t * d + out_t * w) for p, d, ww in ((tf0, 0.114, 0.055), (tf1, 0.088, 0.045))
                                for w in (-ww, ww)] +
         [tuple(p + fwd_t * (d - 0.02) + out_t * w) for p, d, ww in ((tf0, 0.114, 0.06), (tf1, 0.088, 0.05))
          for w in (-ww, ww)], M_ARMOR, mirror=False, bevel=0.003)
    # knee cop: angular, pointing forward
    kc = knee + fwd_t * 0.058 + Vector((0, 0, 0.01))
    hull(f"KneeCop.{side}", [tuple(kc + Vector(v)) for v in (
        (0.05, 0.02, 0.06), (-0.05, 0.02, 0.06), (0.055, 0.02, -0.05), (-0.055, 0.02, -0.05),
        (0.03, -0.035, 0.03), (-0.03, -0.035, 0.03), (0.0, -0.05, -0.01), (0.03, -0.03, -0.055), (-0.03, -0.03, -0.055))],
         M_TRIM, mirror=False, bevel=0.004)
    limb(f"KneeJoint.{side}", knee - Vector((0.065, 0, 0)), knee + Vector((0.065, 0, 0)), 0.05, 0.05, M_UNDER, sides=8)
    # greave: calf swells below the knee, tapers to the ankle
    mid = lerp(knee, ankle, 0.35)
    limb(f"GreaveUpper.{side}", lerp(knee, ankle, 0.10), mid, 0.078, 0.086, M_ARMOR, flat=0.95)
    limb(f"GreaveLower.{side}", mid, lerp(knee, ankle, 0.95), 0.086, 0.062, M_ARMOR, flat=0.95)
    g0, g1 = lerp(knee, ankle, 0.14), lerp(knee, ankle, 0.92)
    shin = hull(f"ShinPlate.{side}", [tuple(p + fwd_s * d + out_s * w) for p, d, ww in ((g0, 0.094, 0.05), (g1, 0.070, 0.036))
                                     for w in (-ww, ww)] +
                [tuple(p + fwd_s * (d - 0.025) + out_s * w) for p, d, ww in ((g0, 0.094, 0.055), (g1, 0.070, 0.04))
                 for w in (-ww, ww)], M_ARMOR, mirror=False, bevel=0.003)
    # purple strip down the front-outer side of the greave
    bar(f"ShinGlow.{side}", lerp(knee, ankle, 0.30) + fwd_s * 0.080 + out_s * 0.054,
        lerp(knee, ankle, 0.88) + fwd_s * 0.064 + out_s * 0.040, thick=0.012)
    # boot: heavy, ankle cuff, toe cap, strap
    ax, ay = ankle.x, ankle.y
    limb(f"AnkleCuff.{side}", ankle + Vector((0, 0, 0.03)), ankle - Vector((0, 0, 0.04)), 0.064, 0.07, M_TRIM, sides=8)
    hull(f"Boot.{side}", [
        (ax + 0.06, ay + 0.09, 0.0), (ax - 0.06, ay + 0.09, 0.0), (ax + 0.065, ay - 0.15, 0.0), (ax - 0.055, ay - 0.15, 0.0),
        (ax + 0.06, ay + 0.08, 0.10), (ax - 0.06, ay + 0.08, 0.10), (ax + 0.06, ay - 0.04, 0.10), (ax - 0.06, ay - 0.04, 0.10),
        (ax + 0.055, ay - 0.15, 0.05), (ax - 0.05, ay - 0.15, 0.05), (ax, ay - 0.19, 0.02),
    ], M_ARMOR, mirror=False)
    hull(f"BootToe.{side}", [
        (ax + 0.067, ay - 0.09, 0.0), (ax - 0.058, ay - 0.09, 0.0), (ax + 0.06, ay - 0.155, 0.0), (ax - 0.052, ay - 0.155, 0.0),
        (ax, ay - 0.198, 0.0), (ax + 0.062, ay - 0.09, 0.065), (ax - 0.058, ay - 0.09, 0.065), (ax, ay - 0.19, 0.035),
        (ax + 0.05, ay - 0.15, 0.055), (ax - 0.045, ay - 0.15, 0.055),
    ], M_TRIM, mirror=False)
    hull(f"BootSole.{side}", [
        (ax + 0.068, ay + 0.10, 0.0), (ax - 0.068, ay + 0.10, 0.0), (ax + 0.07, ay - 0.16, 0.0), (ax - 0.06, ay - 0.16, 0.0),
        (ax + 0.068, ay + 0.10, 0.02), (ax - 0.068, ay + 0.10, 0.02), (ax + 0.07, ay - 0.16, 0.02), (ax - 0.06, ay - 0.16, 0.02),
    ], M_UNDER, mirror=False, bevel=0.003)
    box(f"BootStrap.{side}", (0.135, 0.03, 0.025), (ax, ay - 0.06, 0.085), M_TRIM, rot=(-30, 0, 0), bevel=0.003)
leg("L"); leg("R")

# ---------------------------------------------------------------- energy shield (left arm)
def energy_shield():
    """Oval energy barrier curved around the left/front of the body."""
    me = bpy.data.meshes.new("EnergyShield")
    bm = bmesh.new()
    cx, cy, cz, R = 0.05, 0.0, 1.17, 0.62
    heading = math.radians(-45)           # between +X (left) and -Y (front)
    half_a, half_h, nu, nv = 0.62, 0.55, 20, 24
    grid = {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            u = -1 + 2 * i / nu; v = -1 + 2 * j / nv
            if u * u + v * v > 1.0:
                continue
            ang = heading + u * half_a
            r = R + 0.05 * (1 - v * v)      # slight vertical bulge
            grid[i, j] = bm.verts.new((cx + math.cos(ang) * r, cy + math.sin(ang) * r, cz + v * half_h))
    for i in range(nu):
        for j in range(nv):
            q = [grid.get(k) for k in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
            if all(q):
                bm.faces.new(q)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("EnergyShield", me)
    finish(o, M_SHIELD, bevel=0)
    sol = o.modifiers.new("Thickness", "SOLIDIFY"); sol.thickness = 0.012
    for p in o.data.polygons:
        p.use_smooth = True
    cyl("ShieldEmitter", 0.045, 0.05, (0.42, -0.15, 1.10), M_GLOW, rot=(0, 90, 0), verts=10)
# energy_shield()  # removed: no energy shield on the Vanguard model

# ---------------------------------------------------------------- plasma carbine
def carbine():
    """Plasma carbine (concept): angular receiver with a glowing plasma core,
    split front: vented upper shroud over a lower barrel housing with a long
    plasma channel, plasma flare at the muzzle.  Points along -Y."""
    gx = -0.02
    def gh(name, pts, material=M_ARMOR, bevel=0.004):
        """Hull mirrored around the gun's centre plane (x = gx); pts give +X half-width."""
        allp = []
        for w, y, z in pts:
            allp += [(gx + w, y, z), (gx - w, y, z)]
        return hull(name, allp, material, mirror=False, bevel=bevel)

    # stock: angular, open frame into the shoulder
    gh("Gun_StockTop", [(0.028, -0.06, 1.17), (0.028, -0.22, 1.18), (0.028, -0.06, 1.14), (0.028, -0.22, 1.15)])
    gh("Gun_StockBot", [(0.028, -0.06, 1.05), (0.028, -0.20, 1.09), (0.028, -0.06, 1.08), (0.028, -0.20, 1.12)])
    gh("Gun_Buttplate", [(0.032, -0.04, 1.19), (0.032, -0.07, 1.19), (0.032, -0.04, 1.03), (0.032, -0.07, 1.03)], M_TRIM)
    # receiver: heavy, chamfered, sloping into the front
    gh("Gun_Receiver", [
        (0.045, -0.20, 1.20), (0.045, -0.50, 1.21), (0.045, -0.20, 1.06), (0.045, -0.50, 1.06),
        (0.035, -0.20, 1.22), (0.035, -0.47, 1.23), (0.035, -0.53, 1.18), (0.035, -0.53, 1.07),
    ])
    gh("Gun_ReceiverPlate", [(0.049, -0.24, 1.17), (0.049, -0.40, 1.17), (0.049, -0.24, 1.09), (0.049, -0.38, 1.09)], M_TRIM)
    # plasma core: glowing orb set into each side of the receiver
    for sx in (1, -1):
        c = Vector((gx + sx * 0.040, -0.455, 1.14))
        limb(f"Gun_CoreRing{sx}", c, c + Vector((sx * 0.02, 0, 0)), 0.042, 0.038, M_TRIM, sides=10, bevel=0.002)
        dome(f"Gun_Core{sx}", tuple(c + Vector((sx * 0.012, 0, 0))), (0.033, 0.033, 0.033), 90, -sx,
             M_GLOW, rings=4, segs=10, theta_max=90)
    # sight on top of the receiver
    gh("Gun_Sight", [(0.018, -0.30, 1.235), (0.018, -0.42, 1.235), (0.014, -0.31, 1.265), (0.014, -0.40, 1.265)], M_TRIM)
    # upper shroud: long slab with vent ribs on top
    gh("Gun_Shroud", [
        (0.036, -0.48, 1.22), (0.036, -0.96, 1.21), (0.036, -0.48, 1.16), (0.036, -0.97, 1.165),
        (0.028, -0.48, 1.23), (0.028, -0.93, 1.22), (0.028, -1.00, 1.19),
    ])
    for i in range(9):
        y = -0.55 - i * 0.045
        gh(f"Gun_Vent{i}", [(0.03, y, 1.222), (0.03, y - 0.022, 1.221), (0.03, y, 1.236), (0.03, y - 0.022, 1.235)],
           M_TRIM, bevel=0.002)
    # inner barrel, visible in the gap between shroud and lower housing
    limb("Gun_Barrel", (gx, -0.50, 1.145), (gx, -1.00, 1.145), 0.020, 0.020, M_GLOW, sides=10)
    # lower barrel housing with the long plasma channel on each side
    gh("Gun_Lower", [
        (0.042, -0.50, 1.13), (0.042, -0.97, 1.13), (0.042, -0.50, 1.06), (0.036, -0.95, 1.07),
        (0.034, -1.01, 1.11), (0.034, -1.01, 1.08),
    ])
    for sx in (1, -1):
        bar(f"Gun_Channel{sx}", (gx + sx * 0.044, -0.56, 1.097), (gx + sx * 0.040, -0.99, 1.097), thick=0.014)
    # energy clip under the receiver, glowing window
    gh("Gun_Clip", [(0.026, -0.38, 1.06), (0.026, -0.46, 1.06), (0.026, -0.40, 0.95), (0.026, -0.47, 0.96)], M_TRIM)
    gh("Gun_ClipGlow", [(0.028, -0.40, 1.04), (0.028, -0.45, 1.04), (0.028, -0.415, 0.98), (0.028, -0.455, 0.98)],
       M_GLOW, bevel=0)
    # pistol grip (right hand) and short angled foregrip (left hand)
    cyl("Gun_Grip", 0.026, 0.13, (gx, -0.295, 1.04), M_UNDER, verts=8)
    gh("Gun_TriggerGuard", [(0.008, -0.24, 1.06), (0.008, -0.33, 1.06), (0.008, -0.25, 1.03), (0.008, -0.32, 1.03)], M_TRIM)
    cyl("Gun_Foregrip", 0.026, 0.10, (gx, -0.585, 1.025), M_UNDER, verts=8)
    # muzzle: open emitter with a recessed glowing bore and heat-sink fins
    for i in range(3):
        y = -0.985 - i * 0.022
        limb(f"Gun_HeatFin{i}", (gx, y, 1.12), (gx, y - 0.010, 1.12), 0.056, 0.056, M_TRIM, sides=8, bevel=0.002)
    limb("Gun_Muzzle", (gx, -1.00, 1.12), (gx, -1.08, 1.12), 0.045, 0.048, M_ARMOR, sides=8)
    limb("Gun_MuzzleLip", (gx, -1.075, 1.12), (gx, -1.09, 1.12), 0.050, 0.050, M_TRIM, sides=8, bevel=0.002)
    limb("Gun_Bore", (gx, -1.07, 1.12), (gx, -1.092, 1.12), 0.030, 0.030, M_PLASMA, sides=10, bevel=0)
    # heat vents on the shroud sides near the front
    for sx in (1, -1):
        for i in range(4):
            y = -0.80 - i * 0.035
            bar(f"Gun_Vent{sx}_{i}", (gx + sx * 0.038, y, 1.172), (gx + sx * 0.038, y - 0.012, 1.205), thick=0.008)
carbine()

# ---------------------------------------------------------------- apply & join
# Apply modifiers and join into one mesh per material group -> one object
# "Vanguard" (rigid blockout; rigging comes later).
bpy.ops.object.select_all(action="DESELECT")
deps = bpy.context.evaluated_depsgraph_get()
for o in list(COL.objects):
    if o.type != "MESH":
        continue
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    old = o.data
    o.modifiers.clear()
    o.data = me
    bpy.data.meshes.remove(old)
meshes = [o for o in COL.objects if o.type == "MESH"]
bpy.context.view_layer.objects.active = meshes[0]
for o in meshes:
    o.select_set(True)
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "Vanguard"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ---------------------------------------------------------------- preview scene
world = bpy.data.worlds.new("W"); scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.03, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

def light(name, loc, energy, color=(1, 1, 1), size=1.5):
    d = bpy.data.lights.new(name, "AREA"); d.energy = energy; d.color = color; d.size = size
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
light("Key", (-2.5, -3.0, 3.0), 600)
light("Rim", (2.5, 2.5, 2.5), 500, (0.6, 0.5, 1.0))
light("Fill", (3.0, -2.0, 1.0), 150, (0.6, 0.9, 1.0))

floor = bpy.data.meshes.new("Floor")
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=4); bm.to_mesh(floor); bm.free()
fo = bpy.data.objects.new("Floor", floor); scene.collection.objects.link(fo)
fo.data.materials.append(mat("Floor", (0.08, 0.08, 0.09), 0.0, 0.8))

cam_d = bpy.data.cameras.new("Cam"); cam_d.lens = 60
cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
try:
    scene.view_settings.view_transform = "AgX"
except Exception:
    pass

def shoot(tag, angle_deg, dist=4.6, h=1.25, target=(0, 0, 1.0)):
    a = math.radians(angle_deg)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, h + 0.2)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"preview_{tag}.png")
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "vanguard.blend"))
shoot("front34", -30)
shoot("side", 90)
shoot("back34", 150)
shoot("arms", -40, dist=1.9, h=1.25, target=(0, -0.25, 1.18))
shoot("arms_side", 75, dist=1.9, h=1.25, target=(0, -0.25, 1.18))
shoot("shoulders", 0, dist=2.0, h=1.35, target=(0, 0, 1.32))
shoot("shoulders_back", 180, dist=2.0, h=1.35, target=(0, 0, 1.32))
shoot("gun", -80, dist=2.4, h=1.3, target=(0, -0.62, 1.13))
shoot("legs", -35, dist=2.6, h=0.7, target=(0, -0.05, 0.55))
shoot("torso", -20, dist=1.8, h=1.3, target=(0, 0, 1.2))
shoot("head", -25, dist=1.3, h=1.62, target=(0, 0, 1.77))
shoot("head_side", 80, dist=1.3, h=1.62, target=(0, 0, 1.77))
print("VANGUARD tris:", sum(len(p.vertices) - 2 for p in body.data.polygons))
