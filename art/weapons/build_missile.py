"""Praetor homing missile (VTHomingMissile): rocket body + separate exhaust flame, exported for CompileModel.

Usage: blender -b --factory-startup -P build_missile.py -- <missile.fbx> <missile_proxy.tga> <flame.fbx> <flame_proxy.tga> [preview.png]

Frames (same as the plasma bolt): NS2 +Z (flight direction) = Blender -Y, NS2 up = Blender +Z.
  missile: nose tip at the origin, body trails behind to +Y = LENGTH (the entity origin is the contact point).
  flame:   nozzle at the origin, plume along +Y (= behind the rocket), length 1 m and ~0.18 m wide at scale 1;
           the client scales it per frame (launch burst + flicker, Classes/VTWeapons.lua).
Missile texture = 4-column atlas (u): hull | dark panels | psionic glow | warhead steel; faces map to their column.
Flame texture: u across the plume (bright centre, black edges), v along it (white-hot at the nozzle -> black).
"""
import bpy, bmesh, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
OUT_M, TGA_M, OUT_F, TGA_F = args[:4]
PREVIEW = args[4] if len(args) > 4 else None

LENGTH = 0.75
R = 0.055                     # body radius
SEG = 16
HULL, PANEL, GLOW, STEEL = 0, 1, 2, 3


def col_uv(col, v=0.5):
    return ((col + 0.5) / 4.0, v)


def new_obj(name, bm, recalc=True):
    me = bpy.data.meshes.new(name)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, me


def add_material(me, name, tga):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(tga)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    me.materials.append(mat)
    return mat


def export(ob, path):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_tspace=True,
                             path_mode='ABSOLUTE')
    print("EXPORTED", path, "verts", len(ob.data.vertices), "tris",
          sum(len(p.vertices) - 2 for p in ob.data.polygons))


bpy.ops.wm.read_factory_settings(use_empty=True)

# ------------------------------------------------------------------ rocket body (lathe profile)
# (y, radius, atlas column of the band from this ring to the next)
profile = [
    (0.000, 0.000, GLOW),     # crystal tip
    (0.035, 0.016, STEEL),
    (0.070, 0.031, STEEL),
    (0.110, 0.043, STEEL),
    (0.150, 0.051, HULL),
    (0.185, R,     GLOW),     # front glow band
    (0.205, R,     HULL),
    (0.300, R,     PANEL),    # panel seam
    (0.310, R,     HULL),
    (0.480, R,     GLOW),     # rear glow band
    (0.500, R,     HULL),
    (0.620, R,     PANEL),
    (0.680, 0.044, PANEL),    # boat tail
    (0.700, 0.040, STEEL),    # nozzle ring
    (0.745, 0.046, STEEL),
    (0.750, 0.038, GLOW),     # nozzle lip -> inner glow
    (0.735, 0.000, GLOW),     # recessed glowing nozzle centre
]
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
rings = []
for y, r, col in profile:
    if r == 0:
        rings.append(([bm.verts.new((0, y, 0))], col))
    else:
        rings.append(([bm.verts.new((r * math.cos(2 * math.pi * k / SEG), y, r * math.sin(2 * math.pi * k / SEG)))
                       for k in range(SEG)], col))
for (a, col), (b, _) in zip(rings, rings[1:]):
    for k in range(SEG):
        k2 = (k + 1) % SEG
        if len(a) == 1:
            verts = (a[0], b[k2], b[k])
        elif len(b) == 1:
            verts = (a[k], a[k2], b[0])
        else:
            verts = (a[k], a[k2], b[k2], b[k])
        f = bm.faces.new(verts)
        for loop in f.loops:
            loop[uv].uv = col_uv(col, (k + 0.5) / SEG)


def add_fin(bm, angle, y0, y1, y_tip0, y_tip1, r_root, r_tip, thick, col_side, col_edge):
    """Swept trapezoid fin: root chord y0..y1 at r_root, tip chord y_tip0..y_tip1 at r_tip, rotated by angle."""
    c, s = math.cos(angle), math.sin(angle)
    def P(y, r, t):                       # radial r, tangential offset t
        return (r * c - t * s, y, r * s + t * c)
    h = thick * 0.5
    pts = [(y0, r_root), (y1, r_root), (y_tip1, r_tip), (y_tip0, r_tip)]
    top = [bm.verts.new(P(y, r, h)) for y, r in pts]
    bot = [bm.verts.new(P(y, r, -h)) for y, r in pts]
    faces = [(top[0], top[1], top[2], top[3], col_side), (bot[3], bot[2], bot[1], bot[0], col_side)]
    for i in range(4):
        j = (i + 1) % 4
        faces.append((top[j], top[i], bot[i], bot[j], col_edge))
    for *vs, col in faces:
        f = bm.faces.new(vs)
        for loop in f.loops:
            loop[uv].uv = col_uv(col)


for i in range(4):
    a = math.pi / 4 + i * math.pi / 2
    # tail fins: swept back, glowing trailing edge
    add_fin(bm, a, 0.53, 0.70, 0.64, 0.73, R * 0.92, 0.135, 0.007, HULL, GLOW)
    # canards behind the warhead
    add_fin(bm, a, 0.20, 0.27, 0.235, 0.275, R * 0.92, 0.085, 0.005, PANEL, STEEL)

ob_m, me_m = new_obj("missile", bm)
for p in me_m.polygons:
    p.use_smooth = True
add_material(me_m, "missile", TGA_M)

# ------------------------------------------------------------------ exhaust flame (crossed planes + cone shell)
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
FL, FW = 1.0, 0.09                       # length, half width at the nozzle
for i in range(3):                        # three crossed planes, double-sided
    a = i * math.pi / 3
    c, s = math.cos(a), math.sin(a)
    def P(y, w):
        return (w * c, y, w * s)
    q = [P(0.0, -FW), P(0.0, FW), P(FL, FW * 0.25), P(FL, -FW * 0.25)]
    v = [bm.verts.new(p) for p in q]
    vb = [bm.verts.new(p) for p in q]
    uvs = [(0, 1), (1, 1), (1, 0), (0, 0)]   # v = 1 at the nozzle
    f = bm.faces.new(v)
    for loop, t in zip(f.loops, uvs): loop[uv].uv = t
    f = bm.faces.new(list(reversed(vb)))
    for loop, t in zip(f.loops, list(reversed(uvs))): loop[uv].uv = t
# short bright cone shell right at the nozzle (reads as a solid core from behind)
CS, CL, CR = 10, 0.28, 0.042
base = [bm.verts.new((CR * math.cos(2 * math.pi * k / CS), 0.0, CR * math.sin(2 * math.pi * k / CS))) for k in range(CS)]
tip = bm.verts.new((0, CL, 0))
base2 = [bm.verts.new(v.co) for v in base]
tip2 = bm.verts.new(tip.co)
for k in range(CS):                       # double-sided as well (own verts per side)
    k2 = (k + 1) % CS
    f = bm.faces.new((base[k], base[k2], tip))
    for loop, t in zip(f.loops, ((0.35, 1), (0.65, 1), (0.5, 0.45))): loop[uv].uv = t
    f = bm.faces.new((tip2, base2[k2], base2[k]))
    for loop, t in zip(f.loops, ((0.5, 0.45), (0.65, 1), (0.35, 1))): loop[uv].uv = t
# no normal recalculation: both sides of every plane / the cone must stay (additive Emissive, seen from anywhere)
ob_f, me_f = new_obj("missile_flame", bm, recalc=False)
add_material(me_f, "missile_flame", TGA_F)

export(ob_m, OUT_M)
export(ob_f, OUT_F)

# ------------------------------------------------------------------ preview render (visual check only)
if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 1200, 600
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w"); scene.world = world
    ob_f.location = (0, LENGTH, 0)
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 1.9
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (1.6, 0.85, 0.75)
    target = bpy.data.objects.new("target", None); scene.collection.objects.link(target)
    target.location = (0, 0.85, 0)
    con = cam.constraints.new('TRACK_TO'); con.target = target; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    scene.camera = cam
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
