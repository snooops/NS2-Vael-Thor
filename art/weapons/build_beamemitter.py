"""Praetor II shoulder beam emitter: emitter body (with pylon + shoulder plate) and a spinning focus ring.

Usage: blender -b --factory-startup -P build_beamemitter.py -- <body.fbx> <ring.fbx> <atlas_proxy.tga> [preview.png]

Same frame and atlas as the laser guns (build_lasergun.py): origin = lens tip, NS2 +Z (beam direction) = Blender -Y,
NS2 up = Blender +Z; the emitter extends backwards to +Y and its mount goes down (-Z) to the shoulder plate. The ring
sits around the barrel just behind the lens; the client spins it about the beam axis while the beam fires.
Atlas columns: hull | dark panels | psionic glow | emitter steel.
"""
import bpy, bmesh, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
OUT_BODY, OUT_RING, TGA = args[:3]
PREVIEW = args[3] if len(args) > 3 else None
HULL, PANEL, GLOW, STEEL = 0, 1, 2, 3


def col_uv(col, v=0.5):
    return ((col + 0.5) / 4.0, v)


def oct_ring(bm, y, w, h, ch, xoff=0.0, zoff=0.0):
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

# ------------------------------------------------------------------ emitter body
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
# crystal lens: glowing cone recessed in the tip
lens = circ_ring(bm, 0.0, 0.030)
tip = bm.verts.new((0, 0.025, 0))
for k in range(12):
    f = bm.faces.new((lens[k], lens[(k + 1) % 12], tip))
    for loop in f.loops:
        loop[uv].uv = col_uv(GLOW)
# barrel: lens rim, steel muzzle, three glowing coils, hull
loft(bm, uv, [
    (circ_ring(bm, 0.000, 0.030), STEEL),
    (circ_ring(bm, 0.010, 0.040), STEEL),
    (circ_ring(bm, 0.040, 0.040), HULL),
    (circ_ring(bm, 0.170, 0.042), GLOW),
    (circ_ring(bm, 0.182, 0.042), HULL),
    (circ_ring(bm, 0.205, 0.042), GLOW),
    (circ_ring(bm, 0.217, 0.042), HULL),
    (circ_ring(bm, 0.240, 0.042), GLOW),
    (circ_ring(bm, 0.252, 0.042), HULL),
    (circ_ring(bm, 0.300, 0.046), HULL),
])
# rear power housing (octagonal, wider), glowing core band
loft(bm, uv, [
    (oct_ring(bm, 0.29, 0.060, 0.058, 0.020), HULL),
    (oct_ring(bm, 0.33, 0.075, 0.070, 0.025), HULL),
    (oct_ring(bm, 0.40, 0.075, 0.070, 0.025), GLOW),
    (oct_ring(bm, 0.42, 0.075, 0.070, 0.025), HULL),
    (oct_ring(bm, 0.52, 0.072, 0.066, 0.024), PANEL),
    (oct_ring(bm, 0.55, 0.060, 0.055, 0.020), PANEL),
], cap_front=HULL, cap_back=PANEL)
# top sensor fin + side heat vanes
box(bm, uv, -0.008, 0.008, 0.36, 0.53, 0.070, 0.115, PANEL)
for side in (-1, 1):
    x = side * 0.075
    box(bm, uv, min(x, x + side * 0.03), max(x, x + side * 0.03), 0.43, 0.51, -0.012, 0.012, HULL)
# gimbal: a yoke around the housing and the pylon down to the shoulder plate
box(bm, uv, -0.090, -0.078, 0.36, 0.47, -0.06, 0.03, STEEL)
box(bm, uv, 0.078, 0.090, 0.36, 0.47, -0.06, 0.03, STEEL)
box(bm, uv, -0.090, 0.090, 0.36, 0.47, -0.10, -0.06, STEEL)
box(bm, uv, -0.035, 0.035, 0.37, 0.46, -0.24, -0.10, HULL)       # pylon
box(bm, uv, -0.045, 0.045, 0.38, 0.45, -0.20, -0.17, GLOW)       # pylon glow band
# shoulder plate (stepped)
box(bm, uv, -0.13, 0.13, 0.30, 0.56, -0.28, -0.24, HULL)
box(bm, uv, -0.10, 0.10, 0.33, 0.53, -0.24, -0.225, PANEL)
body = finish("beam_emitter", bm)

# ------------------------------------------------------------------ focus ring (spins about the beam axis)
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
loft(bm, uv, [
    (circ_ring(bm, 0.060, 0.058, 16), STEEL),
    (circ_ring(bm, 0.060, 0.066, 16), STEEL),
    (circ_ring(bm, 0.090, 0.066, 16), GLOW),
    (circ_ring(bm, 0.100, 0.066, 16), STEEL),
    (circ_ring(bm, 0.100, 0.058, 16), STEEL),
    (circ_ring(bm, 0.060, 0.058, 16), STEEL),
])
for i in range(3):
    a = math.pi / 2 + i * 2 * math.pi / 3
    cx, cz = 0.074 * math.cos(a), 0.074 * math.sin(a)
    box(bm, uv, cx - 0.008, cx + 0.008, -0.04, 0.10, cz - 0.008, cz + 0.008, STEEL)   # prong
    box(bm, uv, cx - 0.005, cx + 0.005, -0.055, -0.04, cz - 0.005, cz + 0.005, GLOW)  # crystal tip
ring = finish("beam_emitter_ring", bm)

export(body, OUT_BODY)
export(ring, OUT_RING)

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    scene.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 0.85
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.75, -0.35, 0.45)
    target = bpy.data.objects.new("target", None); scene.collection.objects.link(target)
    target.location = (0, 0.27, -0.09)
    con = cam.constraints.new('TRACK_TO'); con.target = target; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    scene.camera = cam
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
