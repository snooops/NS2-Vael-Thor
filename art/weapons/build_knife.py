"""Psionic Knife (Vanguard melee): procedural combat knife, built into the vanilla axe's world + view frames.

Usage: blender -b --factory-startup -P build_knife.py -- <axe_view_reference.blend> <out_world.blend> <out_view.blend> <preview_dir>
Local knife frame (L, E, N): L along the knife (butt 0 -> tip 0.355 m), E = cutting-edge side, N = flat normal.
World axe frame: long axis +X (butt x = -0.017), axe edge +Y           -> L = +X, E = +Y, N = +Z (static mesh)
View axe frame:  long axis +Z (butt z = -0.105), axe edge -Y, root bone -> L = +Z, E = -Y, N = +X (skinned to axe_root_bone)
UV atlas regions (u): 0-.25 blade steel, .25-.5 psionic glow (edge bevel + grip rings), .5-.75 grip, .75-1 guard/pommel.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix
REF, OUT_W, OUT_V, PREV = [os.path.abspath(p) for p in sys.argv[sys.argv.index("--") + 1:]]
STEEL, GLOW, GRIP, GUARD = 0.125, 0.375, 0.625, 0.875

def build_knife():
    bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
    def face(vs, u):
        f = bm.faces.new(vs)
        for i, l in enumerate(f.loops): l[uv].uv = (u + 0.05 * ((i % 2) - 0.5), 0.3 + 0.4 * (i // 2 % 2))
        return f
    V = lambda l, e, n: bm.verts.new((l, e, n))

    # ---- blade: stations along L with a 5-vertex wedge section (spine pair, flat pair, edge)
    L0, L1, ST = 0.135, 0.355, 14
    secs = []
    for i in range(ST + 1):
        t = i / ST
        l = L0 + (L1 - L0) * t
        edge = 0.032 * (1 - t ** 2.6) + 0.004 * t            # edge rises toward the tip
        spine = -0.003 + (max(0, t - 0.62) / 0.38) ** 1.4 * 0.011   # clip point: spine drops near the tip
        th = 0.0032 * (1 - 0.7 * t)
        if i == ST:
            secs.append([V(l + 0.004, 0.009, 0)] * 5); continue
        flat = spine + (edge - spine) * 0.55
        secs.append([V(l, spine, th), V(l, flat, th * 0.8), V(l, edge, 0), V(l, flat, -th * 0.8), V(l, spine, -th)])
    for a, b in zip(secs, secs[1:]):
        for k in range(5):
            k2 = (k + 1) % 5
            quad = [a[k], a[k2], b[k2], b[k]]
            u = GLOW if k in (1, 2) else STEEL                 # edge bevels (flat->edge, edge->flat) glow
            uniq = list(dict.fromkeys(quad))
            if len(uniq) >= 3: face(uniq, u)
    face(list(reversed(secs[0])), STEEL)                      # blade base (hidden in the guard)

    # ---- guard: box
    def box(l0, l1, e0, e1, n0, n1, u):
        p = [V(l, e, n) for l in (l0, l1) for e in (e0, e1) for n in (n0, n1)]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            face([p[i] for i in q], u)
    box(0.123, 0.135, -0.020, 0.044, -0.009, 0.009, GUARD)

    # ---- grip, rings, pommel: oval octagon tubes
    def tube(l0, l1, r0, r1, u, cap0=False, cap1=False, ce=0.012, sides=8):
        ring = lambda l, r: [V(l, ce + r * 1.15 * math.cos(2 * math.pi * k / sides), r * 0.85 * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
        a, b = ring(l0, r0), ring(l1, r1)
        for k in range(sides):
            k2 = (k + 1) % sides
            face([a[k], a[k2], b[k2], b[k]], u)
        if cap0: face(list(reversed(a)), u)
        if cap1: face(b, u)
    tube(0.018, 0.123, 0.0125, 0.0135, GRIP)
    for l in (0.045, 0.072, 0.099):
        tube(l, l + 0.005, 0.0142, 0.0142, GLOW, True, True)
    tube(0.0, 0.018, 0.0145, 0.0128, GUARD, cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("knife"); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    return me

def place(me, basis, offset):
    M = Matrix.Translation(offset) @ basis.to_4x4()
    me.transform(M); me.update()

# ---------------------------------------------------------------- world model (static)
bpy.ops.wm.read_factory_settings(use_empty=True)
me = build_knife()
place(me, Matrix(((1, 0, 0), (0, 1, 0), (0, 0, 1))), Vector((-0.017, 0, 0)))   # L,E,N -> X,Y,Z
ob = bpy.data.objects.new("knife", me); bpy.context.scene.collection.objects.link(ob)
me.materials.append(bpy.data.materials.new("knife"))
bpy.ops.wm.save_as_mainfile(filepath=OUT_W)
print("SAVED world", OUT_W, "verts", len(me.vertices))

# ---------------------------------------------------------------- view model (arms + knife on axe_root_bone)
bpy.ops.wm.open_mainfile(filepath=REF)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
view = next(o for o in sc.objects if o.type == 'MESH')
bm = bmesh.new(); bm.from_mesh(view.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != 0], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(view.data); bm.free()
view.data.materials.clear(); view.data.materials.append(bpy.data.materials.new("hands"))
kme = build_knife()
# columns = images of L, E, N: L -> +Z, E -> -Y, N -> +X
place(kme, Matrix(((0, 0, 1), (0, -1, 0), (1, 0, 0))), Vector((0, 0, -0.105)))
knife = bpy.data.objects.new("knife", kme); sc.collection.objects.link(knife)

# Triangles in NS2 model space for replace_view_weapon.py (the view model is spliced binary-wise, so the vanilla
# arms keep their exact bind pose incl. the 0.849 shoulder scale that Blender bones can't represent).
# Blender (X, Y, Z) -> NS2 (X, Z, -Y); UV v flipped back.
import json
tris = []
kme.calc_loop_triangles()
for lt in kme.loop_triangles:
    n = lt.normal
    tri = []
    for li in lt.loops:
        co = kme.vertices[kme.loops[li].vertex_index].co
        u, v = kme.uv_layers.active.data[li].uv
        tri.append({"p": [co.x, co.z, -co.y], "n": [n.x, n.z, -n.y], "uv": [u, 1 - v]})
    tris.append(tri)
json.dump(tris, open(os.path.join(os.path.dirname(OUT_V), "knife_view_tris.json"), "w"))
print("TRIS", len(tris))
for b in arm.data.bones: knife.vertex_groups.new(name=b.name)
knife.vertex_groups["axe_root_bone"].add(list(range(len(kme.vertices))), 1.0, 'REPLACE')
kme.materials.append(bpy.data.materials.new("knife_view"))
view.modifiers.clear(); view.parent = None
for o in sc.objects: o.select_set(o in (view, knife))
bpy.context.view_layer.objects.active = view
bpy.ops.object.join()
view.parent = arm
m = view.modifiers.new("Armature", 'ARMATURE'); m.object = arm
print("JOINED view verts", len(view.data.vertices), [mm.name for mm in view.data.materials])
bpy.ops.wm.save_as_mainfile(filepath=OUT_V)
print("SAVED view", OUT_V)

# preview: knife alone, flat side and edge-on
for o in list(sc.objects):
    if o is not view: o.hide_render = True
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'
sc.render.resolution_x = 900; sc.render.resolution_y = 500
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 0.45
cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
c = Vector((0, -0.01, 0.075))
for tag, pos in (("flat", (1, 0, 0)), ("edge", (0, -1, 0))):
    cam.location = c + Vector(pos); cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(PREV, f"knife_{tag}.png"); bpy.ops.render.render(write_still=True)
