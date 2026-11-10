"""Plasma bolt (Vanguard carbine projectile): a tapered, capped tube along NS2 +Z (Blender -Y), exported for CompileModel.

Usage: blender -b --factory-startup -P build_plasma_bolt.py -- <out.fbx> <emissive_proxy.tga>
The projectile origin is the bolt head; the body trails behind it (PredictedProjectile points model +Z along the
flight direction). UV v runs head (1) -> tail (0) so the emissive texture can fade the trail.
"""
import bpy, bmesh, sys, math
OUT, TGA = sys.argv[sys.argv.index("--") + 1:]
HEAD_Y, TAIL_Y = -0.06, 0.85          # Blender Y: -Y is NS2 forward
R_HEAD, R_TAIL, SEG, RINGS = 0.028, 0.012, 10, 12

bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new("plasma_bolt")
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
rings = []
for i in range(RINGS + 1):
    t = i / RINGS                                    # 0 head .. 1 tail
    y = HEAD_Y + (TAIL_Y - HEAD_Y) * t
    r = R_HEAD + (R_TAIL - R_HEAD) * t
    if i == 0: r *= 0.55                             # rounded nose
    ring = [bm.verts.new((r * math.cos(2 * math.pi * k / SEG), y, r * math.sin(2 * math.pi * k / SEG))) for k in range(SEG)]
    rings.append((ring, 1 - t))
for (a, va), (b, vb) in zip(rings, rings[1:]):
    for k in range(SEG):
        k2 = (k + 1) % SEG
        f = bm.faces.new((a[k], a[k2], b[k2], b[k]))
        for loop, (u, v) in zip(f.loops, ((k / SEG, va), ((k + 1) / SEG, va), ((k + 1) / SEG, vb), (k / SEG, vb))):
            loop[uv].uv = (u, v)
tipf = bm.verts.new((0, HEAD_Y - 0.03, 0)); tailp = bm.verts.new((0, TAIL_Y + 0.02, 0))
head, _ = rings[0]; tail, _ = rings[-1]
for k in range(SEG):
    k2 = (k + 1) % SEG
    f = bm.faces.new((tipf, head[k2], head[k]))
    for loop in f.loops: loop[uv].uv = (0.5, 1.0)
    f = bm.faces.new((tailp, tail[k], tail[k2]))
    for loop in f.loops: loop[uv].uv = (0.5, 0.0)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me); bm.free()
ob = bpy.data.objects.new("plasma_bolt", me); bpy.context.scene.collection.objects.link(ob)
for p in me.polygons: p.use_smooth = True
mat = bpy.data.materials.new("plasma_bolt"); mat.use_nodes = True
nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(TGA)
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
me.materials.append(mat)
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_tspace=True, path_mode='ABSOLUTE')
print("EXPORTED", OUT, "verts", len(me.vertices))
