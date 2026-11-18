"""Artificer "Crucible" (chosen look 2026-11-17, concept art/artificer/concepts anvil_crucible): game models.

Usage: blender -b --factory-startup -P build_crucible.py -- <src_dir> <atlas_proxy.tga> [preview.png]
Writes <src_dir>/crucible_{body,core,thigh,shin,foot,view}.fbx.

Rigid parts, animated in Lua (Client: lua/VaelThor/VTCrucible.lua) - no skeleton, no animation graph:
  body   hull, furnace dome with open iris, pincers, beam emitter, eyes, belly Sapper pods.
         Origin = ground point under the centre (= the player's origin), faces NS2 +Z.
  core   the crystal in the iris, origin = its centre (spun + pulsed by Lua).
  thigh  hip -> knee, origin = hip, length LEG_THIGH along NS2 +Z, armour on NS2 +Y (the upper side).
  shin   knee -> ankle, origin = knee, length LEG_SHIN along NS2 +Z, armour on NS2 +Y.
  foot   origin = ankle, pad below it (NS2 -Y), faces NS2 +Z.
  view   first person, built in CAMERA space (origin = the eye, NS2 +Z = view direction): the emitter turret at
         the bottom centre (tip LUA: VIEW_EMITTER_TIP), a slice of the front plate with the eyes below it and the
         pincer forearms reaching in from the lower corners - no dome / chimneys / belly / hips (the camera sits inside the dome). Same origin as body;
         drawn in the view model zone with the camera at kVTCrucible.eyeHeight.
Frame: NS2 +Z = Blender -Y, NS2 +Y = Blender +Z (axis_forward='-Z', axis_up='Y' like every other VT model).
Size fits the exo hitbox it borrows (0.55 m radius, 2.4 m): body r 0.62, dome top ~1.6 m, feet ~1.1 m out.
Keep the numbers marked LUA in sync with VTCrucible.lua.

Atlas (8 columns, 5 used): chrome | gunmetal | dark | psionic glow | crystal. Each face takes its column's colour.
"""
import bpy, math, sys, os
from mathutils import Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
SRC, TGA = args[0], args[1]
PREVIEW = args[2] if len(args) > 2 else None
PORTRAIT = args[3] if len(args) > 3 else None   # transparent 512x512 render for the spawn menu (make_caste_portraits.sh)

COLS = {"chrome": 0, "gun": 1, "dark": 2, "glow": 3, "crystal": 4}
NCOLS = 8

# ---- LUA: shared with VTCrucible.lua
HIP_RADIUS = 0.50          # hips on the hull rim
HIP_HEIGHT = 0.92          # above the ground at rest
LEG_ANGLES = (40, 0, -40)  # degrees from the side axis towards the rear (+Y in Blender = rear)
LEG_THIGH = 0.60
LEG_SHIN = 0.85
CORE_HEIGHT = 1.50         # core centre above the ground
EMITTER_TIP = (0.0, -0.90, 0.93)   # Blender coords (NS2: x, z=0.93 up, forward 0.90)

bpy.ops.wm.read_factory_settings(use_empty=True)
PARTS = []                  # objects of the model being built


def tag(o, col, bevel=0.0, smooth=False):
    o["col"] = col
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL"); b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
    if smooth and o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
    PARTS.append(o)
    return o


def box(sx, sy, sz, loc, col, rot=(0, 0, 0), bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.object; o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.location = loc; o.rotation_euler = rot
    return tag(o, col, bevel)


def seg(p0, p1, w, d, col, bevel=0.015, twist=0.0):
    p0, p1 = Vector(p0), Vector(p1); v = p1 - p0
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.object; o.scale = (w, d, v.length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.location = (p0 + p1) / 2
    o.rotation_mode = "QUATERNION"
    q = v.to_track_quat("Z", "Y")
    if twist:
        q = q @ Quaternion((0, 0, 1), twist)
    o.rotation_quaternion = q
    return tag(o, col, bevel)


def cyl(n, r, p0, p1, col, r2=None, bevel=0.01, smooth=False):
    p0, p1 = Vector(p0), Vector(p1); v = p1 - p0
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if r2 is None else r2, depth=v.length,
                                    location=(0, 0, 0))
    o = bpy.context.object
    o.location = (p0 + p1) / 2
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = v.to_track_quat("Z", "Y")
    return tag(o, col, bevel, smooth)


def ball(r, loc, col, sub=1, smooth=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    return tag(bpy.context.object, col, smooth=smooth)


def ring(R, r, loc, col, rot=(0, 0, 0), n=32, minor=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=n, minor_segments=minor,
                                     location=loc, rotation=rot)
    return tag(bpy.context.object, col, smooth=True)


def crystal(r, up, down, loc, col="crystal", n=6, tilt=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=up, location=(0, 0, up / 2))
    a = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=down, location=(0, 0, -down / 2),
                                    rotation=(math.pi, 0, 0))
    b = bpy.context.object
    bpy.ops.object.select_all(action="DESELECT"); a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    a.location = loc; a.rotation_euler = tilt
    return tag(a, col)


def mini_sapper(loc, yaw, scale):
    """belly pod: a docked Sapper (spiked charge, amber read as glow here)"""
    loc = Vector(loc)
    c, s = math.cos(yaw), math.sin(yaw)
    def L(x, y, z):
        return loc + Vector((x * c - y * s, x * s + y * c, z)) * 1.0
    ball(0.19 * scale, loc, "gun")
    ring(0.19 * scale, 0.02 * scale, loc, "glow", rot=(math.pi / 2, 0, yaw), n=16, minor=6)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cyl(5, 0.03 * scale, L(sx * 0.10 * scale, -0.10 * scale, sz * 0.10 * scale),
                L(sx * 0.15 * scale, -0.30 * scale, sz * 0.15 * scale), "chrome", r2=0.0, bevel=0)


def collect(name):
    """apply modifiers, UV every face to its atlas column, join into one object with the crucible material"""
    global PARTS
    objs = []
    for o in PARTS:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
        col = o["col"]
        if o.modifiers or o.type != "MESH":
            bpy.ops.object.convert(target="MESH")
            o = bpy.context.object
        me = o.data
        uv = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
        u = (COLS[col] + 0.5) / NCOLS
        for poly in me.polygons:
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.25 + 0.5 * ((poly.index * 0.37) % 1.0))
        me.materials.clear()
        objs.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.object; ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mat = bpy.data.materials.get("crucible")
    if not mat:
        mat = bpy.data.materials.new("crucible"); mat.use_nodes = True
        nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(TGA)
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.append(mat)
    PARTS = []
    return ob


# ================================================================== body
VIEW_EMITTER_TIP = (0.0, -0.76, -0.25)   # Blender coords, camera space (NS2: up -0.25, forward 0.76)


def build_view():
    tip = Vector(VIEW_EMITTER_TIP)
    # emitter turret
    cyl(8, 0.075, (0, -0.30, -0.33), (0, -0.52, -0.29), "gun", r2=0.06)
    cyl(10, 0.034, (0, -0.52, -0.29), tip + Vector((0, 0.02, -0.003)), "chrome")
    for y in (-0.58, -0.64, -0.70):
        z = -0.29 + (y + 0.52) / (tip.y + 0.52) * (tip.z + 0.29)
        cyl(10, 0.039, (0, y, z), (0, y - 0.014, z), "glow", bevel=0)
    crystal(0.03, 0.055, 0.015, tip, tilt=(math.pi / 2 + 0.05, 0, 0))
    box(0.20, 0.30, 0.05, (0, -0.40, -0.25), "chrome", rot=(0.12, 0, 0), bevel=0.012)      # top cowl
    box(0.012, 0.26, 0.012, (0, -0.42, -0.222), "glow", rot=(0.12, 0, 0), bevel=0)
    # front plate slice with the three eyes, below the turret
    box(0.56, 0.10, 0.20, (0, -0.48, -0.47), "chrome", rot=(-0.5, 0, 0), bevel=0.02)
    for x in (-0.12, 0.0, 0.12):
        ball(0.032, (x, -0.535, -0.43 + (0.02 if x == 0 else 0)), "glow", sub=2, smooth=True)
    # pincer forearms from the lower corners, jaws towards the centre
    for s in (-1, 1):
        el = Vector((s * 0.62, -0.30, -0.42)); wr = Vector((s * 0.40, -0.80, -0.30))
        seg(el, wr, 0.14, 0.13, "chrome")
        seg(el + Vector((0, 0, 0.075)), wr + Vector((0, 0, 0.075)), 0.014, 0.014, "glow", bevel=0)
        ball(0.075, el, "gun")
        jaw = Vector((-s * 0.45, -1, 0.05)).normalized()
        seg(wr + Vector((0, 0, 0.05)), wr + jaw * 0.22 + Vector((0, 0, 0.06)), 0.07, 0.045, "chrome")
        seg(wr - Vector((0, 0, 0.05)), wr + jaw * 0.19 - Vector((0, 0, 0.07)), 0.06, 0.045, "gun")
        ball(0.045, wr, "dark")
    return collect("crucible_view")


def build_body(view=False):
    if not view:   # first person: no hull (its roof would cover the emitter seen from the eye)
        # hull: octagonal saucer with a rim and a glowing seam; under-plate
        cyl(8, 0.62, (0, 0, 0.78), (0, 0, 1.02), "gun", r2=0.58, bevel=0.02)
        cyl(8, 0.64, (0, 0, 1.02), (0, 0, 1.08), "chrome", bevel=0.01)
        cyl(8, 0.645, (0, 0, 0.90), (0, 0, 0.925), "glow", bevel=0)
        cyl(8, 0.42, (0, 0, 0.68), (0, 0, 0.78), "chrome", r2=0.62, bevel=0.01)
        cyl(8, 0.30, (0, 0, 0.62), (0, 0, 0.68), "dark", r2=0.42, bevel=0)
        # armour panels on the rim between the legs
        for a_deg in (90, 270, 20, 160, 200, 340):
            a = math.radians(a_deg)
            d = Vector((math.cos(a), math.sin(a), 0))
            box(0.30, 0.05, 0.22, d * 0.63 + Vector((0, 0, 0.92)), "chrome", rot=(0, 0, a + math.pi / 2), bevel=0.012)
    # front plate with eyes
    box(0.50, 0.08, 0.26, (0, -0.60, 0.93), "chrome", rot=(-0.15, 0, 0), bevel=0.02)
    for x in (-0.11, 0.0, 0.11):
        ball(0.035, (x, -0.645, 0.99 + (0.03 if x == 0 else 0)), "glow", sub=2, smooth=True)
    # beam emitter under the eyes (LUA: EMITTER_TIP)
    cyl(8, 0.06, (0, -0.58, 0.93), (0, -0.74, 0.93), "gun")
    cyl(10, 0.032, (0, -0.74, 0.93), (0, -0.88, 0.93), "chrome")
    for y in (-0.78, -0.82):
        cyl(10, 0.036, (0, y, 0.93), (0, y - 0.012, 0.93), "glow", bevel=0)
    crystal(0.028, 0.05, 0.015, EMITTER_TIP, tilt=(math.pi / 2, 0, 0))
    # furnace dome with glowing slots and the iris ring on top
    cyl(8, 0.46, (0, 0.04, 1.08), (0, 0.04, 1.45), "gun", r2=0.30, bevel=0.015)
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        p0 = Vector((math.cos(a) * 0.45, 0.04 + math.sin(a) * 0.45, 1.11))
        p1 = Vector((math.cos(a) * 0.31, 0.04 + math.sin(a) * 0.31, 1.42))
        seg(p0, p1, 0.035, 0.02, "glow", bevel=0)
    ring(0.24, 0.035, (0, 0.04, 1.46), "chrome")
    cyl(8, 0.20, (0, 0.04, 1.40), (0, 0.04, 1.44), "glow", bevel=0)      # glowing furnace floor
    for k in range(6):                                                  # opened iris petals
        a = k * math.pi / 3
        seg((math.cos(a) * 0.24, 0.04 + math.sin(a) * 0.24, 1.46),
            (math.cos(a) * 0.38, 0.04 + math.sin(a) * 0.38, 1.64), 0.13, 0.022, "chrome", twist=a)
    # chimneys at the rear
    for x in (-0.20, 0.20):
        cyl(6, 0.07, (x, 0.42, 1.02), (x, 0.48, 1.38), "gun", r2=0.055)
        cyl(6, 0.058, (x, 0.48, 1.38), (x, 0.485, 1.41), "glow", bevel=0)
    build_pincers()
    # belly: ring of docked Sappers
    for a in range(0, 360, 72):
        r = math.radians(a + 36)
        mini_sapper((math.cos(r) * 0.30, math.sin(r) * 0.30, 0.55), r, 0.55)
    finish_body()
    return collect("crucible_body")


def build_pincers():
    # pincers: shoulder, upper arm, forearm, two jaws (feed the furnace)
    for s in (-1, 1):
        sh = Vector((s * 0.40, -0.40, 0.98)); el = Vector((s * 0.66, -0.70, 1.22)); wr = Vector((s * 0.46, -0.98, 1.02))
        ball(0.10, sh, "gun")
        seg(sh, el, 0.12, 0.12, "gun"); ball(0.085, el, "gun")
        seg(el, wr, 0.16, 0.15, "chrome")
        seg(el + Vector((0, 0, 0.085)), wr + Vector((0, 0, 0.085)), 0.015, 0.015, "glow", bevel=0)
        jaw = Vector((-s * 0.30, -1, 0)).normalized()
        seg(wr + Vector((0, 0, 0.06)), wr + jaw * 0.26 + Vector((0, 0, 0.07)), 0.08, 0.05, "chrome")
        seg(wr - Vector((0, 0, 0.06)), wr + jaw * 0.22 - Vector((0, 0, 0.09)), 0.07, 0.05, "gun")
        ball(0.05, wr, "dark")


def finish_body():
    # cables from the dome into the hull
    for s in (-1, 1):
        cu = bpy.data.curves.new("cable", "CURVE"); cu.dimensions = "3D"; cu.bevel_depth = 0.022; cu.bevel_resolution = 2
        sp = cu.splines.new("BEZIER"); sp.bezier_points.add(2)
        for bp, p in zip(sp.bezier_points, [(s * 0.42, -0.10, 1.08), (s * 0.50, 0.10, 1.20), (s * 0.40, 0.30, 1.08)]):
            bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
        o = bpy.data.objects.new("cable", cu); bpy.context.scene.collection.objects.link(o)
        tag(o, "dark")
    # hip sockets (the thighs start here, LUA: HIP_*)
    for a_deg in LEG_ANGLES:
        for sx in (-1, 1):
            a = math.radians(a_deg)
            d = Vector((sx * math.cos(a), math.sin(a), 0))
            ball(0.10, d * HIP_RADIUS + Vector((0, 0, HIP_HEIGHT)), "gun")
            box(0.18, 0.05, 0.16, d * (HIP_RADIUS + 0.06) + Vector((0, 0, HIP_HEIGHT + 0.10)), "chrome",
                rot=(0, 0, math.atan2(d.y, d.x) + math.pi / 2), bevel=0.01)


def build_core():
    crystal(0.11, 0.26, 0.10, (0, 0, 0))
    for k in range(3):
        a = k * 2 * math.pi / 3
        crystal(0.035, 0.08, 0.04, (math.cos(a) * 0.17, math.sin(a) * 0.17, -0.02), tilt=(0.3 * math.sin(a), 0.3 * math.cos(a), 0))
    return collect("crucible_core")


# legs: built along Blender -Y (= NS2 +Z) from the origin, armour on +Z (= NS2 +Y)
def build_thigh():
    L = LEG_THIGH
    seg((0, 0, 0), (0, -L, 0), 0.13, 0.15, "gun")
    seg((0, -0.08, 0.085), (0, -L + 0.06, 0.085), 0.17, 0.035, "chrome", bevel=0.01)
    seg((0, -0.10, 0.105), (0, -L + 0.10, 0.105), 0.025, 0.012, "glow", bevel=0)
    cyl(8, 0.04, (-0.09, -L, 0), (0.09, -L, 0), "dark")                  # knee pin
    ball(0.09, (0, -L, 0), "gun")
    return collect("crucible_thigh")


def build_shin():
    L = LEG_SHIN
    seg((0, -0.02, 0), (0, -L + 0.05, 0), 0.11, 0.12, "chrome")
    seg((0, -0.05, 0.07), (0, -L * 0.75, 0.065), 0.13, 0.03, "gun", bevel=0.01)
    seg((0, -0.08, 0.088), (0, -L * 0.7, 0.084), 0.02, 0.012, "glow", bevel=0)
    cyl(6, 0.06, (0, -L + 0.12, 0), (0, -L, 0), "gun", r2=0.035)
    return collect("crucible_shin")


def build_foot():
    ball(0.055, (0, 0, 0), "dark")
    cyl(6, 0.13, (0, 0, -0.03), (0, 0, -0.10), "gun", r2=0.10)
    cyl(6, 0.10, (0, 0, -0.10), (0, 0, -0.12), "glow", bevel=0)
    for k in range(3):                                                  # three toes, front-facing
        a = math.radians(-90 + (k - 1) * 45)
        seg((math.cos(a) * 0.05, math.sin(a) * 0.05, -0.06), (math.cos(a) * 0.20, math.sin(a) * 0.20, -0.11),
            0.05, 0.04, "chrome", bevel=0.008)
    return collect("crucible_foot")


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_tspace=True,
                             path_mode="ABSOLUTE")
    print("EXPORTED", path, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))


models = {
    "crucible_body": build_body(),
    "crucible_core": build_core(),
    "crucible_thigh": build_thigh(),
    "crucible_shin": build_shin(),
    "crucible_foot": build_foot(),
    "crucible_view": build_view(),
}
for name, ob in models.items():
    export(ob, os.path.join(SRC, name + ".fbx"))

if PREVIEW:
    # assemble one standing pose for the preview (same IK as VTCrucible.lua)
    sc = bpy.context.scene
    models["crucible_core"].location = (0, 0.04, CORE_HEIGHT)
    for a_deg in LEG_ANGLES:
        for sx in (-1, 1):
            a = math.radians(a_deg)
            d = Vector((sx * math.cos(a), math.sin(a), 0))
            hip = d * HIP_RADIUS + Vector((0, 0, HIP_HEIGHT))
            foot = d * (HIP_RADIUS + 0.60) + Vector((0, 0, 0.12))
            dist = (foot - hip).length
            u = (foot - hip).normalized()
            along = (LEG_THIGH ** 2 - LEG_SHIN ** 2 + dist ** 2) / (2 * dist)
            h = math.sqrt(max(0, LEG_THIGH ** 2 - along ** 2))
            bend = (Vector((0, 0, 1)) - u * u.z).normalized()
            knee = hip + u * along + bend * h
            for name, p0, p1 in (("crucible_thigh", hip, knee), ("crucible_shin", knee, foot)):
                o = models[name].copy(); o.data = models[name].data; sc.collection.objects.link(o)
                v = p1 - p0
                up = (Vector((0, 0, 1)) - v.normalized() * v.normalized().z).normalized()
                # model -Y along the segment, +Z = up
                o.rotation_mode = "QUATERNION"
                o.rotation_quaternion = (-v).to_track_quat("Y", "Z")
                o.location = p0
            o = models["crucible_foot"].copy(); o.data = models["crucible_foot"].data; sc.collection.objects.link(o)
            o.location = foot; o.rotation_euler = (0, 0, math.atan2(d.y, d.x) + math.pi / 2)
    for name in ("crucible_thigh", "crucible_shin", "crucible_foot", "crucible_view"):
        models[name].hide_render = True
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 1200, 900
    sc.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 3.4
    cam = bpy.data.objects.new("cam", cam_data); sc.collection.objects.link(cam)
    cam.location = (2.6, -3.2, 2.2)
    target = bpy.data.objects.new("t", None); sc.collection.objects.link(target); target.location = (0, -0.1, 0.8)
    con = cam.constraints.new("TRACK_TO"); con.target = target; con.track_axis = "TRACK_NEGATIVE_Z"; con.up_axis = "UP_Y"
    sc.camera = cam
    sc.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
    if PORTRAIT:
        sc.render.film_transparent = True
        sc.render.resolution_x = sc.render.resolution_y = 512
        cam.location = (1.6, -3.9, 1.7)
        sc.render.filepath = PORTRAIT
        bpy.ops.render.render(write_still=True)
        print("PORTRAIT", PORTRAIT)
