"""Praetor laser gun (replaces the exo miniguns): body + sliding emitter barrel, exported for CompileModel.

Usage: blender -b --factory-startup -P build_lasergun.py -- <body.fbx> <barrel.fbx> <atlas_proxy.tga> [preview.png]

Frame: NS2 +Z (barrel direction) = Blender -Y, NS2 up = Blender +Z, NS2 right = Blender -X... (export axis_forward='-Z',
axis_up='Y' as for the other VT props). Origin = muzzle tip; the gun extends backwards to +Y = LENGTH. Both models
share this frame: the client places them at the exo muzzle attach point and slides the barrel back on recoil
(Client.lua, Praetor laser guns). One 4-column atlas for both: hull | dark panels | psionic glow | emitter steel.
"""
import bpy, bmesh, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
OUT_BODY, OUT_BARREL, TGA = args[:3]
PREVIEW = args[3] if len(args) > 3 else None

LENGTH = 1.0
HULL, PANEL, GLOW, STEEL = 0, 1, 2, 3


def col_uv(col, v=0.5):
    return ((col + 0.5) / 4.0, v)


def oct_ring(bm, y, w, h, ch, xoff=0.0, zoff=0.0):
    """Chamfered rectangle (8 verts) of half-width w, half-height h, chamfer ch, in the XZ plane at y."""
    pts = [(w, h - ch), (w - ch, h), (-(w - ch), h), (-w, h - ch), (-w, -(h - ch)), (-(w - ch), -h), (w - ch, -h), (w, -(h - ch))]
    return [bm.verts.new((x + xoff, y, z + zoff)) for x, z in pts]


def circ_ring(bm, y, r, n=12, xoff=0.0, zoff=0.0):
    return [bm.verts.new((r * math.cos(2 * math.pi * k / n) + xoff, y, r * math.sin(2 * math.pi * k / n) + zoff)) for k in range(n)]


def bridge(bm, uv, a, b, col):
    n = len(a)
    for k in range(n):
        k2 = (k + 1) % n
        f = bm.faces.new((a[k], a[k2], b[k2], b[k]))
        for loop in f.loops:
            loop[uv].uv = col_uv(col, (k + 0.5) / n)


def cap(bm, uv, ring, col):
    f = bm.faces.new(ring)
    for loop in f.loops:
        loop[uv].uv = col_uv(col)


def loft(bm, uv, rings_cols, cap_front=None, cap_back=None):
    """rings_cols: [(ring, col_of_band_to_next)]; caps with the given columns."""
    for (a, col), (b, _) in zip(rings_cols, rings_cols[1:]):
        bridge(bm, uv, a, b, col)
    if cap_front is not None:
        cap(bm, uv, list(reversed(rings_cols[0][0])), cap_front)
    if cap_back is not None:
        cap(bm, uv, rings_cols[-1][0], cap_back)


def box(bm, uv, x0, x1, y0, y1, z0, z1, col):
    v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                     (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        f = bm.faces.new([v[i] for i in q])
        for loop in f.loops:
            loop[uv].uv = col_uv(col)


def finish(name, bm):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.get("lasergun")
    if not mat:
        mat = bpy.data.materials.new("lasergun"); mat.use_nodes = True
        nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(TGA)
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def export(ob, path):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_tspace=True,
                             path_mode='ABSOLUTE')
    print("EXPORTED", path, "verts", len(ob.data.vertices), "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))


bpy.ops.wm.read_factory_settings(use_empty=True)

# ------------------------------------------------------------------ body
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
# front emitter shroud (the barrel slides inside it)
loft(bm, uv, [
    (oct_ring(bm, 0.10, 0.060, 0.055, 0.020), STEEL),
    (oct_ring(bm, 0.13, 0.066, 0.060, 0.022), HULL),
    (oct_ring(bm, 0.30, 0.070, 0.064, 0.024), PANEL),
    (oct_ring(bm, 0.32, 0.070, 0.064, 0.024), HULL),
], cap_front=PANEL)
# main housing: tapers out from the shroud, long flat sides
loft(bm, uv, [
    (oct_ring(bm, 0.30, 0.074, 0.068, 0.026), HULL),
    (oct_ring(bm, 0.40, 0.095, 0.085, 0.032), HULL),
    (oct_ring(bm, 0.62, 0.095, 0.085, 0.032), PANEL),
    (oct_ring(bm, 0.64, 0.095, 0.085, 0.032), HULL),
    (oct_ring(bm, 0.80, 0.095, 0.085, 0.032), HULL),
    (oct_ring(bm, 0.84, 0.088, 0.080, 0.030), HULL),
], cap_front=HULL)
# rear power pack (wider, glowing core windows on both sides)
loft(bm, uv, [
    (oct_ring(bm, 0.83, 0.110, 0.100, 0.035), HULL),
    (oct_ring(bm, 0.86, 0.115, 0.105, 0.036), PANEL),
    (oct_ring(bm, 0.96, 0.115, 0.105, 0.036), HULL),
    (oct_ring(bm, LENGTH, 0.100, 0.090, 0.032), HULL),
], cap_front=HULL, cap_back=PANEL)
for side in (-1, 1):
    # core windows on the power pack
    x = side * 0.117
    box(bm, uv, min(x, x + side * 0.006), max(x, x + side * 0.006), 0.875, 0.945, -0.05, 0.05, GLOW)
    # energy rails along the housing sides
    x = side * 0.096
    box(bm, uv, min(x, x + side * 0.008), max(x, x + side * 0.008), 0.42, 0.80, -0.012, 0.012, GLOW)
# heat-sink fins on top
for i in range(6):
    y = 0.44 + i * 0.055
    box(bm, uv, -0.06, 0.06, y, y + 0.012, 0.085, 0.118, PANEL if i % 2 else HULL)
# under-rail
box(bm, uv, -0.03, 0.03, 0.36, 0.78, -0.11, -0.085, PANEL)
body = finish("lasergun_body", bm)

# ------------------------------------------------------------------ barrel (slides back on recoil)
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
loft(bm, uv, [
    (circ_ring(bm, 0.000, 0.026), GLOW),     # lens rim
    (circ_ring(bm, 0.008, 0.034), STEEL),
    (circ_ring(bm, 0.030, 0.034), GLOW),     # coil 1
    (circ_ring(bm, 0.042, 0.034), STEEL),
    (circ_ring(bm, 0.062, 0.034), GLOW),     # coil 2
    (circ_ring(bm, 0.074, 0.034), STEEL),
    (circ_ring(bm, 0.094, 0.034), GLOW),     # coil 3
    (circ_ring(bm, 0.106, 0.034), STEEL),
    (circ_ring(bm, 0.420, 0.034), STEEL),    # hidden inside the housing at rest
], cap_back=STEEL)
# crystal lens: recessed glowing cone in the muzzle
lens = circ_ring(bm, 0.000, 0.026)
tip = bm.verts.new((0, 0.020, 0))
for k in range(12):
    f = bm.faces.new((lens[k], lens[(k + 1) % 12], tip))
    for loop in f.loops:
        loop[uv].uv = col_uv(GLOW)
# three focusing prongs around the muzzle
for i in range(3):
    a = math.pi / 2 + i * 2 * math.pi / 3
    cx, cz = 0.045 * math.cos(a), 0.045 * math.sin(a)
    box(bm, uv, cx - 0.007, cx + 0.007, -0.035, 0.11, cz - 0.007, cz + 0.007, STEEL)
    box(bm, uv, cx - 0.004, cx + 0.004, -0.045, -0.035, cz - 0.004, cz + 0.004, GLOW)
barrel = finish("lasergun_barrel", bm)

export(body, OUT_BODY)
export(barrel, OUT_BARREL)

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 1200, 700
    scene.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 1.35
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (1.2, -0.25, 0.75)
    target = bpy.data.objects.new("target", None); scene.collection.objects.link(target)
    target.location = (0, 0.48, 0)
    con = cam.constraints.new('TRACK_TO'); con.target = target; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    scene.camera = cam
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
