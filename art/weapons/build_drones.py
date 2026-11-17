"""Artificer drones (concept class 2026-11-17): Wasp, Lancer, Sapper.

Usage: blender -b --factory-startup -P build_drones.py -- <wasp.fbx> <lancer.fbx> <sapper.fbx> <atlas_proxy.tga> [preview.png]

Frame like the laser guns / beam emitter (shared atlas + material models/vaelthor/lasergun/lasergun.material):
origin = the drone's centre (= entity origin, hitbox centre), NS2 +Z (flight / beam direction) = Blender -Y,
NS2 up = Blender +Z. Atlas columns: hull | dark panels | psionic glow | emitter steel.
Sizes: Wasp ~0.55 m long, Lancer ~0.85 m, Sapper ~0.6 m (hitbox radii 0.32 / 0.38 / 0.4, kVTDroneTypes).
"""
import bpy, bmesh, sys, math
args = sys.argv[sys.argv.index("--") + 1:]
OUT_WASP, OUT_LANCER, OUT_SAPPER, TGA = args[:4]
PREVIEW = args[4] if len(args) > 4 else None
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




def cone(bm, uv, base_y, tip_y, r, col, tip_col=None, n=8, xoff=0.0, zoff=0.0):
    """cone along Y: base ring at base_y, apex at tip_y"""
    ring = circ_ring(bm, base_y, r, n, xoff, zoff)
    tip = bm.verts.new((xoff, tip_y, zoff))
    for k in range(n):
        f = bm.faces.new((ring[k], ring[(k + 1) % n], tip))
        for loop in f.loops:
            loop[uv].uv = col_uv(tip_col if tip_col is not None else col)
    cap(bm, uv, list(reversed(ring)) if tip_y < base_y else ring, col)


def xcone(bm, uv, base, tip, r, col, n=6):
    """cone between two arbitrary points (spikes)"""
    import mathutils
    b, t = mathutils.Vector(base), mathutils.Vector(tip)
    axis = (t - b).normalized()
    side = axis.cross(mathutils.Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = axis.cross(mathutils.Vector((1, 0, 0)))
    side.normalize()
    up = axis.cross(side)
    ring = [bm.verts.new(b + (side * math.cos(2 * math.pi * k / n) + up * math.sin(2 * math.pi * k / n)) * r) for k in range(n)]
    apex = bm.verts.new(t)
    for k in range(n):
        f = bm.faces.new((ring[k], ring[(k + 1) % n], apex))
        for loop in f.loops:
            loop[uv].uv = col_uv(col)
    f = bm.faces.new(list(reversed(ring)))
    for loop in f.loops:
        loop[uv].uv = col_uv(col)


bpy.ops.wm.read_factory_settings(use_empty=True)

# ------------------------------------------------------------------ Wasp: dart interceptor with swept wings
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
cone(bm, uv, -0.20, -0.29, 0.030, STEEL, GLOW)                      # sensor eye
loft(bm, uv, [
    (oct_ring(bm, -0.20, 0.032, 0.028, 0.010), HULL),
    (oct_ring(bm, -0.12, 0.070, 0.050, 0.020), HULL),
    (oct_ring(bm, -0.02, 0.082, 0.058, 0.024), GLOW),
    (oct_ring(bm,  0.01, 0.082, 0.058, 0.024), HULL),
    (oct_ring(bm,  0.16, 0.066, 0.048, 0.020), PANEL),
    (oct_ring(bm,  0.22, 0.046, 0.036, 0.014), PANEL),
], cap_back=PANEL)
loft(bm, uv, [(circ_ring(bm, 0.22, 0.030, 10), GLOW), (circ_ring(bm, 0.26, 0.022, 10), GLOW)], cap_back=GLOW)  # thruster
for side in (-1, 1):
    # swept wing as two boxes stepping back, glowing tip
    box(bm, uv, *sorted((side * 0.07, side * 0.20)), -0.02, 0.10, -0.008, 0.008, HULL)
    box(bm, uv, *sorted((side * 0.19, side * 0.29)), 0.05, 0.16, -0.006, 0.006, HULL)
    box(bm, uv, *sorted((side * 0.285, side * 0.305)), 0.06, 0.17, -0.012, 0.012, GLOW)
box(bm, uv, -0.006, 0.006, 0.02, 0.18, 0.050, 0.085, PANEL)        # dorsal fin
box(bm, uv, -0.012, 0.012, -0.18, -0.04, -0.075, -0.050, STEEL)    # emitter prong
cone(bm, uv, -0.18, -0.215, 0.010, STEEL, GLOW, 6, 0.0, -0.0625)
wasp = finish("drone_wasp", bm)

# ------------------------------------------------------------------ Lancer: long-barrel beam platform with a halo ring
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
cone(bm, uv, -0.44, -0.47, 0.026, STEEL, GLOW, 12)                  # lens
loft(bm, uv, [
    (circ_ring(bm, -0.44, 0.028), STEEL),
    (circ_ring(bm, -0.42, 0.036), STEEL),
    (circ_ring(bm, -0.38, 0.036), HULL),
    (circ_ring(bm, -0.30, 0.036), GLOW),
    (circ_ring(bm, -0.29, 0.036), HULL),
    (circ_ring(bm, -0.24, 0.036), GLOW),
    (circ_ring(bm, -0.23, 0.036), HULL),
    (circ_ring(bm, -0.18, 0.036), GLOW),
    (circ_ring(bm, -0.17, 0.036), HULL),
    (circ_ring(bm, -0.08, 0.044), HULL),
])
loft(bm, uv, [
    (oct_ring(bm, -0.10, 0.080, 0.065, 0.025), HULL),
    (oct_ring(bm, -0.04, 0.125, 0.090, 0.035), HULL),
    (oct_ring(bm,  0.08, 0.125, 0.090, 0.035), GLOW),
    (oct_ring(bm,  0.10, 0.125, 0.090, 0.035), HULL),
    (oct_ring(bm,  0.30, 0.110, 0.080, 0.030), PANEL),
    (oct_ring(bm,  0.36, 0.070, 0.055, 0.020), PANEL),
], cap_front=HULL, cap_back=PANEL)
loft(bm, uv, [(circ_ring(bm, 0.36, 0.040), GLOW), (circ_ring(bm, 0.40, 0.030), GLOW)], cap_back=GLOW)
for side in (-1, 1):
    box(bm, uv, *sorted((side * 0.125, side * 0.19)), 0.00, 0.26, -0.035, 0.035, HULL)     # side pods
    box(bm, uv, *sorted((side * 0.19, side * 0.20)), 0.04, 0.22, -0.012, 0.012, GLOW)
box(bm, uv, -0.008, 0.008, 0.05, 0.32, 0.09, 0.15, PANEL)          # dorsal fin
box(bm, uv, -0.008, 0.008, 0.08, 0.30, -0.14, -0.09, PANEL)        # ventral fin
# halo: flat tube ring around the hull
R0, R1 = 0.215, 0.245
loft(bm, uv, [
    (circ_ring(bm, 0.12, R1, 20), STEEL),
    (circ_ring(bm, 0.17, R1, 20), GLOW),
    (circ_ring(bm, 0.17, R0, 20), STEEL),
    (circ_ring(bm, 0.12, R0, 20), STEEL),
    (circ_ring(bm, 0.12, R1, 20), STEEL),
])
for a in (0, 90, 180, 270):                                        # halo struts
    c, s = math.cos(math.radians(a + 45)), math.sin(math.radians(a + 45))
    x0, z0, x1, z1 = c * 0.09, s * 0.07, c * 0.22, s * 0.22
    box(bm, uv, min(x0, x1) - 0.01, max(x0, x1) + 0.01, 0.13, 0.16, min(z0, z1) - 0.01, max(z0, z1) + 0.01, STEEL)
lancer = finish("drone_lancer", bm)

# ------------------------------------------------------------------ Sapper: armoured charge with breaching spikes
bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
loft(bm, uv, [
    (oct_ring(bm, -0.22, 0.070, 0.070, 0.025), STEEL),
    (oct_ring(bm, -0.14, 0.160, 0.150, 0.055), PANEL),
    (oct_ring(bm, -0.04, 0.190, 0.175, 0.065), PANEL),
    (oct_ring(bm, -0.02, 0.195, 0.180, 0.066), GLOW),
    (oct_ring(bm,  0.04, 0.195, 0.180, 0.066), GLOW),
    (oct_ring(bm,  0.06, 0.190, 0.175, 0.065), HULL),
    (oct_ring(bm,  0.18, 0.140, 0.130, 0.050), HULL),
    (oct_ring(bm,  0.24, 0.080, 0.080, 0.030), PANEL),
], cap_front=GLOW, cap_back=PANEL)
loft(bm, uv, [(circ_ring(bm, 0.24, 0.050), GLOW), (circ_ring(bm, 0.29, 0.038), GLOW)], cap_back=GLOW)   # thruster
for sx in (-1, 1):                                                  # breaching spikes
    for sz in (-1, 1):
        xcone(bm, uv, (sx * 0.10, -0.15, sz * 0.09), (sx * 0.13, -0.33, sz * 0.12), 0.028, STEEL)
for sz in (-1, 1):                                                  # armour plates top / bottom
    box(bm, uv, -0.11, 0.11, -0.10, 0.14, *sorted((sz * 0.17, sz * 0.205)), HULL)
for sx in (-1, 1):                                                  # side vents
    box(bm, uv, *sorted((sx * 0.19, sx * 0.215)), -0.06, 0.10, -0.06, 0.06, PANEL)
    box(bm, uv, *sorted((sx * 0.214, sx * 0.22)), -0.03, 0.07, -0.035, 0.035, GLOW)
sapper = finish("drone_sapper", bm)

export(wasp, OUT_WASP)
export(lancer, OUT_LANCER)
export(sapper, OUT_SAPPER)

if PREVIEW:
    wasp.location = (-0.75, 0, 0)
    sapper.location = (0.75, 0, 0)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 1400, 700
    scene.world = bpy.data.worlds.new("w")
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = 'ORTHO'; cam_data.ortho_scale = 2.4
    cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    cam.location = (0.9, -1.6, 1.0)
    target = bpy.data.objects.new("target", None); scene.collection.objects.link(target)
    target.location = (0, 0, 0)
    con = cam.constraints.new('TRACK_TO'); con.target = target; con.track_axis = 'TRACK_NEGATIVE_Z'; con.up_axis = 'UP_Y'
    scene.camera = cam
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
