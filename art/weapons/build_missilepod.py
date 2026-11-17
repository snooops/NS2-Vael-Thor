"""Praetor (I) shoulder missile pod: 2x2 launch tubes in an armoured box on a gimbal, pylon and shoulder plate.

Usage: blender -b --factory-startup -P build_missilepod.py -- <pod.fbx> <atlas_proxy.tga> [preview.png]

Same frame and atlas as the laser guns / beam emitter: origin = centre of the tube faces (launch point), NS2 +Z
(launch direction) = Blender -Y, NS2 up = Blender +Z; the pod extends backwards to +Y, the mount goes down (-Z).
Atlas columns: hull | dark panels | psionic glow | steel. The client kicks the pod back on every launch.
"""
import bpy, bmesh, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
OUT_POD, TGA = args[:2]
PREVIEW = args[2] if len(args) > 2 else None
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

bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
W, H = 0.13, 0.12          # half width / half height of the pod
Y0, Y1 = 0.0, 0.46         # front face .. back
TUBE_R, TUBE_X, TUBE_Z = 0.042, 0.062, 0.058
DEPTH = 0.05               # tube recess

# front face: a plate with four tube holes = a frame of boxes around the tube openings (keeps it simple: the
# openings are dark recessed tubes inside the plate)
# front plate as a frame with a square opening behind each round tube lip (a solid plate hid the missiles)
R = TUBE_R
for z0, z1 in ((TUBE_Z + R, H), (-H, -TUBE_Z - R), (-TUBE_Z + R, TUBE_Z - R)):           # horizontal strips
    box(bm, uv, -W, W, Y0 + 0.005, Y0 + 0.02, z0, z1, PANEL)
for tz in (-TUBE_Z, TUBE_Z):                                                               # vertical strips
    for x0, x1 in ((-W, -TUBE_X - R), (-TUBE_X + R, TUBE_X - R), (TUBE_X + R, W)):
        box(bm, uv, x0, x1, Y0 + 0.005, Y0 + 0.02, tz - R, tz + R, PANEL)
for tx in (-TUBE_X, TUBE_X):
    for tz in (-TUBE_Z, TUBE_Z):
        # tube lip ring + dark tube interior with a glowing missile tip inside
        loft(bm, uv, [
            (circ_ring(bm, Y0 - 0.012, TUBE_R + 0.008, 12, tx, tz), STEEL),
            (circ_ring(bm, Y0 - 0.012, TUBE_R, 12, tx, tz), PANEL),
            (circ_ring(bm, Y0 + DEPTH, TUBE_R, 12, tx, tz), PANEL),
        ])
        ring_out = circ_ring(bm, Y0 - 0.012, TUBE_R + 0.008, 12, tx, tz)
        ring_back = circ_ring(bm, Y0 + 0.005, TUBE_R + 0.008, 12, tx, tz)
        bridge(bm, uv, ring_out, ring_back, STEEL)
        # missile nose inside the tube (glowing crystal tip)
        base = circ_ring(bm, Y0 + DEPTH, TUBE_R * 0.75, 10, tx, tz)
        tip = bm.verts.new((tx, Y0 + 0.004, tz))        # just behind the lip: visible from the front
        for k in range(10):
            f = bm.faces.new((base[k], base[(k + 1) % 10], tip))
            for loop in f.loops:
                loop[uv].uv = col_uv(GLOW)
# pod body: chamfered box behind the plate
loft(bm, uv, [
    (oct_ring(bm, Y0 + 0.02, W, H, 0.03), HULL),
    (oct_ring(bm, 0.30, W, H, 0.03), PANEL),
    (oct_ring(bm, 0.315, W, H, 0.03), HULL),
    (oct_ring(bm, Y1, W * 0.92, H * 0.9, 0.03), PANEL),
], cap_back=PANEL)
# armour hood over the top front edge + glowing status strip
box(bm, uv, -W - 0.01, W + 0.01, -0.02, 0.22, H, H + 0.025, HULL)
box(bm, uv, -0.06, 0.06, 0.05, 0.20, H + 0.025, H + 0.032, GLOW)
# side armour plates with vents
for side in (-1, 1):
    x0 = side * W
    x1 = side * (W + 0.018)
    box(bm, uv, min(x0, x1), max(x0, x1), 0.06, 0.40, -H * 0.8, H * 0.8, HULL)
    for i in range(3):
        y = 0.12 + i * 0.08
        x2 = side * (W + 0.022)
        box(bm, uv, min(x1, x2), max(x1, x2), y, y + 0.03, -0.05, 0.05, GLOW if i == 1 else PANEL)
# gimbal yoke, pylon, shoulder plate (as the beam emitter)
box(bm, uv, -W - 0.04, -W - 0.025, 0.24, 0.38, -0.08, 0.04, STEEL)
box(bm, uv, W + 0.025, W + 0.04, 0.24, 0.38, -0.08, 0.04, STEEL)
box(bm, uv, -W - 0.04, W + 0.04, 0.24, 0.38, -H - 0.04, -H, STEEL)
box(bm, uv, -0.035, 0.035, 0.26, 0.36, -0.30, -H - 0.04, HULL)          # pylon
box(bm, uv, -0.045, 0.045, 0.27, 0.35, -0.25, -0.22, GLOW)             # pylon glow band
box(bm, uv, -0.14, 0.14, 0.18, 0.46, -0.34, -0.30, HULL)               # shoulder plate
box(bm, uv, -0.11, 0.11, 0.21, 0.43, -0.30, -0.285, PANEL)
pod = finish("missile_pod", bm)
export(pod, OUT_POD)

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    scene.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 0.95
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.7, -0.6, 0.45)
    target = bpy.data.objects.new("target", None); scene.collection.objects.link(target)
    target.location = (0, 0.2, -0.08)
    con = cam.constraints.new('TRACK_TO'); con.target = target; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    scene.camera = cam
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
