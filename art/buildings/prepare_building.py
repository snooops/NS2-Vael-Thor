"""Tripo GLB -> NS2 static building FBX + convex collision FBX (used by build_building.sh).
Usage: blender -b --factory-startup -P prepare_building.py -- <in.glb> <out_dir> <name> <albedo.tga>
                                                             <height_m> <target_tris> <bands>

  * decimates the ~500k-tri Tripo mesh (UVs kept) to target_tris
  * scales to height_m (Tripo GLBs are normalised to 1 m tall), centres XY on the origin, base at z = 0
  * collision, bands = "auto[:slice_m[:clear_radius_m]]" (model-following, see auto_hulls): thin horizontal
    slices split into their separate pieces, each piece one convex hull; hulls that are mostly empty space are
    split further. Legacy: bands = "a-b,c-d,..." height fractions, one convex hull each.
  * everything is bound to one root bone: CompileModel attaches collision solids to the bone their FBX node
    is parented to - unparented solids got bone index -1, which the engine never placed in the world
    (no collision, use traces and bullets passed through the building).
  * exports <out_dir>/<name>.fbx (rig + geometry, one material -> albedo.tga), <name>_physics.fbx (rig + hulls)
    and <name>_prepared.blend (for previews)
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

GLB, OUT, NAME, TGA, HEIGHT, TARGET, BANDS = sys.argv[sys.argv.index("--") + 1:]
HEIGHT, TARGET = float(HEIGHT), int(TARGET)
AUTO = None
DISC = None                                    # (radius, centre z): clear disc in the XZ plane (Rift membrane)
if BANDS.startswith("auto"):                   # "auto[:slice_m[:clear_radius_m[:disc_r@disc_z]]]"
    parts = BANDS.split(":")
    AUTO = (float(parts[1]) if len(parts) > 1 else 0.35, float(parts[2]) if len(parts) > 2 else 0.0)
    if len(parts) > 3:
        r, z = parts[3].split("@"); DISC = (float(r), float(z))
    BANDS = []
else:
    BANDS = [tuple(float(x) for x in band.split("-")) for band in BANDS.split(",")]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
src = bpy.context.view_layer.objects.active

# ---- decimate (collapse keeps UVs)
tris = sum(len(p.vertices) - 2 for p in src.data.polygons)
dec = src.modifiers.new("dec", "DECIMATE"); dec.ratio = min(1.0, TARGET / tris); dec.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=dec.name)
print("TRIS", tris, "->", len(src.data.polygons))

# ---- scale + centre
vs = [v.co for v in src.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
k = HEIGHT / (hi.z - lo.z)
shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in src.data.vertices:
    v.co = (v.co - shift) * k
src.data.update()
print("SIZE %.2f x %.2f x %.2f m" % ((hi.x - lo.x) * k, (hi.y - lo.y) * k, HEIGHT))

# ---- material: one slot, base colour from the converted albedo TGA (CompileModel maps it to the .material)
src.data.materials.clear()
mat = bpy.data.materials.new(NAME); mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(TGA)
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
src.data.materials.append(mat)
src.name = NAME


def hull_mesh(me):
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.to_mesh(me); bm.free()


# ---- collision hulls
def finish_hull(me, name, max_faces=64):
    """convex hull of me's verts, simplified to <= max_faces (re-hulled so it stays convex)"""
    hull_mesh(me)
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    if len(me.polygons) > max_faces:          # stay well under PhysX's convex limits
        d = ob.modifiers.new("d", "DECIMATE"); d.ratio = max_faces / len(me.polygons)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=d.name)
        hull_mesh(me)
    me.materials.append(mat)
    return ob


def band_hulls():
    """legacy mode: one convex hull per height band"""
    out = []
    for i, (a, b) in enumerate(BANDS):
        z0, z1 = a * HEIGHT, b * HEIGHT
        me = bpy.data.meshes.new(f"hull{i}")
        bm = bmesh.new()
        for v in src.data.vertices:
            if z0 <= v.co.z <= z1:
                bm.verts.new(v.co)
        bm.to_mesh(me); bm.free()
        ob = finish_hull(me, f"Hull{i:02d}", 120)
        out.append(ob)
        print("HULL", ob.name, "band %.2f-%.2f m" % (z0, z1), "faces", len(me.polygons))
    return out


def auto_hulls(slice_h, clear_r):
    """Model-following decomposition: horizontal slices of slice_h, each split into its connected pieces; a
    piece whose convex hull is mostly empty space (occupancy test against the real mesh) is cut in half along
    its longer horizontal axis, recursively. clear_r > 0 keeps a vertical column of that radius around the
    origin free between 0.25 m and 2.2 m (Rift Portal: players must reach the centre)."""
    from mathutils.bvhtree import BVHTree
    from mathutils import Matrix
    # Watertight collision copy: the decimated Tripo mesh is split at UV seams and has holes (hundreds of
    # loose pieces, thousands of open edges), which breaks both the piece split and any inside test. A voxel
    # remesh (VOXEL_SIZE) is closed by construction and keeps separate parts (floating crystals) separate.
    proxy = bpy.data.objects.new("collision_proxy", src.data.copy())
    bpy.context.scene.collection.objects.link(proxy)
    bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    rm = proxy.modifiers.new("remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = VOXEL_SIZE
    bpy.ops.object.modifier_apply(modifier=rm.name)
    if len(proxy.data.polygons) > 40000:
        dm = proxy.modifiers.new("dec", "DECIMATE"); dm.ratio = 40000 / len(proxy.data.polygons)
        bpy.ops.object.modifier_apply(modifier=dm.name)
    src_bm = bmesh.new(); src_bm.from_mesh(proxy.data)
    bpy.data.objects.remove(proxy, do_unlink=True)
    bmesh.ops.triangulate(src_bm, faces=src_bm.faces[:])
    tree = BVHTree.FromBMesh(src_bm)
    print("HULL proxy: voxel %.3f m, %d faces, %d open edges" % (
        VOXEL_SIZE, len(src_bm.faces), sum(1 for e in src_bm.edges if e.is_boundary)))

    ray_dirs = [Vector(d).normalized() for d in ((1, 0.013, 0.007), (-0.011, 1, 0.017), (0.009, -0.013, 1),
                                                  (-1, -0.02, 0.01), (0.02, -1, 0.005))]

    def inside_mesh(p):
        """ray parity, majority of 5 directions"""
        votes = 0
        for d in ray_dirs:
            n, q = 0, p.copy()
            for _ in range(64):
                hit = tree.ray_cast(q, d, 50.0)
                if hit[0] is None: break
                n += 1; q = hit[0] + d * 1e-4
            votes += n % 2
        return votes >= 3

    def islands(bm):
        seen = set(); out = []
        for f in bm.faces:
            if f.index in seen: continue
            stack = [f]; seen.add(f.index); group = []
            while stack:
                g = stack.pop(); group.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index); stack.append(h)
            out.append(group)
        return out

    def sub_bm(faces):
        bm = bmesh.new(); vmap = {}
        for f in faces:
            vs = []
            for v in f.verts:
                if v not in vmap: vmap[v] = bm.verts.new(v.co)
                vs.append(vmap[v])
            try: bm.faces.new(vs)
            except ValueError: pass
        bm.faces.ensure_lookup_table(); bm.faces.index_update()
        return bm

    def cut(bm, co, no, keep_positive):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no,
                               clear_inner=keep_positive, clear_outer=not keep_positive)
        bm.faces.ensure_lookup_table(); bm.faces.index_update()

    def hull_planes(pts):
        bm = bmesh.new()
        for p in pts: bm.verts.new(p)
        if len(bm.verts) < 4:
            bm.free(); return None
        bmesh.ops.convex_hull(bm, input=bm.verts[:])
        hull_verts = [v.co.copy() for v in bm.verts if v.link_faces]
        if not hull_verts:
            bm.free(); return None
        centroid = sum(hull_verts, Vector()) / len(hull_verts)
        planes = []
        for f in bm.faces:
            c, n = f.calc_center_median(), f.normal.copy()
            if n.length < 1e-9: continue
            if (centroid - c).dot(n) > 0:      # nearly flat point sets: convex_hull can leave inward normals
                n = -n
            planes.append((c, n))
        bm.free()
        return planes if planes else None

    def occupancy(pts, planes, lo, hi):
        n_in = n_tot = 0
        steps = 6
        for ix in range(steps):
            for iy in range(steps):
                for iz in range(2):
                    p = Vector((lo.x + (ix + 0.5) / steps * (hi.x - lo.x), lo.y + (iy + 0.5) / steps * (hi.y - lo.y),
                                lo.z + (iz + 0.5) / 2 * (hi.z - lo.z)))
                    if all((p - c).dot(n) <= 0 for c, n in planes):
                        n_tot += 1
                        n_in += inside_mesh(p)
        return (n_in / n_tot) if n_tot else 1.0

    def in_hull(p, planes):
        return all((p - c).dot(n) <= 0 for c, n in planes)

    def blocks_clear_zone(lo, hi, planes):
        if DISC:                                       # disc in the XZ plane, facing +-y (ring opening / membrane)
            r, cz = DISC
            for y in [k * 0.03 for k in range(-10, 11)]:     # dense: the membrane is only ~8 cm thick
                for f in (0.0, 0.5, 0.8, 1.0):
                    for k in range(12 if f else 1):
                        a = k * math.pi / 6
                        p = Vector((f * r * math.cos(a), y, cz + f * r * math.sin(a)))
                        if lo.z - 0.01 <= p.z <= hi.z + 0.01 and in_hull(p, planes):
                            return True
        if clear_r <= 0 or hi.z < 0.25 or lo.z > CLEAR_TOP: return False
        for z in (0.4, 1.0, 1.6, 2.1, CLEAR_TOP - 0.05):
            if lo.z <= z <= hi.z:
                ring = [(clear_r * f * math.cos(a), clear_r * f * math.sin(a)) for f in (0.5, 1.0)
                        for a in [k * math.pi / 4 for k in range(8)]]
                for dx, dy in [(0, 0)] + ring:
                    p = Vector((dx, dy, z))
                    if all((p - c).dot(n) <= 0 for c, n in planes):
                        return True
        return False

    pieces = []        # lists of points
    LEVEL = {}

    def process(bm, depth):
        for group in islands(bm):
            pts = [v.co.copy() for f in group for v in f.verts]
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            size = hi - lo
            if max(size) < 0.05:
                continue                                   # tiny decoration
            if min(size) < 0.02:
                continue                                   # flat sliver (e.g. a remeshed membrane surface): no volume
            planes = hull_planes(pts)
            if planes is None:
                continue
            occ = occupancy(pts, planes, lo, hi)
            blocked = blocks_clear_zone(lo, hi, planes)
            span = max(size.x, size.y)
            if (occ < LEVEL["occ"] or blocked) and depth < 5 and (span > LEVEL["span"] or (blocked and span > 0.3)):
                axis = Vector((1, 0, 0)) if size.x >= size.y else Vector((0, 1, 0))
                mid = (lo + hi) / 2
                for keep in (True, False):
                    half = sub_bm(group); cut(half, mid, axis, keep)
                    if half.faces: process(half, depth + 1)
                    half.free()
                continue
            if blocked:
                continue                                   # small piece inside the clear zone: drop it
            pieces.append((pts, occ))

    LEVEL.update(occ=0.55, span=0.3)
    n_slices = max(1, round(HEIGHT / slice_h))
    for i in range(n_slices):
        z0, z1 = i * HEIGHT / n_slices, (i + 1) * HEIGHT / n_slices
        bm = src_bm.copy()
        cut(bm, Vector((0, 0, z0 - 1e-4)), Vector((0, 0, 1)), True)
        cut(bm, Vector((0, 0, z1 + 1e-4)), Vector((0, 0, 1)), False)
        if bm.faces:
            first = len(pieces); process(bm, 0)
            for k in range(first, len(pieces)): pieces[k] = pieces[k] + (i,)
        bm.free()
    src_bm.free()

    # Hull budget: vanilla models go up to 174 solids (the Hive); stay well below. Over budget, the smallest
    # piece is merged with its nearest neighbour in the same slice (a strut lattice becomes dome segments),
    # never across the clear zones.
    def centre(pts): return sum(pts, Vector()) / len(pts)
    def extent(pts):
        return max(max(p[k] for p in pts) - min(p[k] for p in pts) for k in range(3))
    merges = 0
    while len(pieces) > MAX_HULLS:
        order = sorted(range(len(pieces)), key=lambda k: extent(pieces[k][0]))
        done = False
        for a in order:
            pa, _, sa = pieces[a]; ca = centre(pa)
            cands = sorted((k for k in range(len(pieces)) if k != a and pieces[k][2] == sa),
                           key=lambda k: (centre(pieces[k][0]) - ca).length)
            for b in cands[:4]:
                merged = pa + pieces[b][0]
                planes = hull_planes(merged)
                if planes is None: continue
                lo = Vector((min(p.x for p in merged), min(p.y for p in merged), min(p.z for p in merged)))
                hi = Vector((max(p.x for p in merged), max(p.y for p in merged), max(p.z for p in merged)))
                if blocks_clear_zone(lo, hi, planes): continue
                pieces[b] = (merged, occupancy(merged, planes, lo, hi), sa)
                pieces.pop(a); merges += 1; done = True
                break
            if done: break
        if not done: break
    if merges:
        print("HULL budget: %d merges to stay within %d hulls" % (merges, MAX_HULLS))

    out = []
    for i, (pts, occ, _) in enumerate(pieces):
        me = bpy.data.meshes.new(f"hull{i}")
        bm = bmesh.new()
        for p in pts: bm.verts.new(p)
        bm.to_mesh(me); bm.free()
        out.append(finish_hull(me, f"Hull{i:02d}"))
    occs = [o for _, o, _ in pieces]
    print("HULL auto: %d hulls from %d slices of %.2f m, occupancy min %.2f mean %.2f%s%s" % (
        len(out), n_slices, HEIGHT / n_slices, min(occs), sum(occs) / len(occs),
        (", clear column r=%.2f" % clear_r) if clear_r > 0 else "",
        (", clear disc r=%.2f at z=%.2f" % DISC) if DISC else ""))
    return out


VOXEL_SIZE = 0.04
MAX_HULLS = 120
CLEAR_TOP = 2.6        # clear zone (Rift Portal centre) height
hulls = auto_hulls(AUTO[0], AUTO[1]) if AUTO else band_hulls()


# ---- one root bone: geometry skinned to it, hulls parented to it
arm_data = bpy.data.armatures.new("rig"); rig = bpy.data.objects.new("rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.ops.object.select_all(action="DESELECT"); bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
bone = arm_data.edit_bones.new("root"); bone.head = (0, 0, 0); bone.tail = (0, 0, 0.5)
bpy.ops.object.mode_set(mode="OBJECT")
vg = src.vertex_groups.new(name="root"); vg.add(list(range(len(src.data.vertices))), 1.0, "REPLACE")
src.parent = rig; src.modifiers.new("rig", "ARMATURE").object = rig
for h in hulls:
    mw = h.matrix_world.copy()
    h.parent = rig; h.parent_type = "BONE"; h.parent_bone = "root"
    h.matrix_world = mw


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in [rig] + objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "ARMATURE"},
                             add_leaf_bones=False, primary_bone_axis="X", secondary_bone_axis="Y",
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_tspace=True,
                             path_mode="ABSOLUTE")
    print("EXPORTED", path)


export([src], os.path.join(OUT, NAME + ".fbx"))
export(hulls, os.path.join(OUT, NAME + "_physics.fbx"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + "_prepared.blend"))
print("SAVED")
