"""Field pulse ring (Pylon pulse, Vael'Thor counterpart of the power node impulse): unit-radius ring =
flat annulus (r 0.92-1.0) + a short vertical band (h 0.35) so it also reads from eye level. Scaled at runtime.
UV: u around the ring, v across the band (the texture carries a soft violet falloff across v).
Usage: blender -b --factory-startup -P make_pulse_ring.py -- <out.blend> <texture.tga>"""
import bpy, bmesh, sys, math
out, tga = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new("pulse"); ob = bpy.data.objects.new("pulse", me)
bpy.context.scene.collection.objects.link(ob)
bm = bmesh.new(); uv = bm.loops.layers.uv.new()
N = 96
def ring(r0, z0, r1, z1, v0, v1):
    for k in range(N):
        a0, a1 = 2 * math.pi * k / N, 2 * math.pi * (k + 1) / N
        corners = [(r0 * math.cos(a0), r0 * math.sin(a0), z0), (r0 * math.cos(a1), r0 * math.sin(a1), z0),
                   (r1 * math.cos(a1), r1 * math.sin(a1), z1), (r1 * math.cos(a0), r1 * math.sin(a0), z1)]
        uvs = [(k / N, v0), ((k + 1) / N, v0), ((k + 1) / N, v1), (k / N, v1)]
        # double sided: the back face needs its own vertices (bmesh rejects a second face on the same ones)
        for order in (range(4), reversed(range(4))):
            order = list(order)
            f = bm.faces.new([bm.verts.new(corners[i]) for i in order])
            for loop, i in zip(f.loops, order):
                loop[uv].uv = uvs[i]
ring(0.92, 0.0, 1.0, 0.0, 0.0, 1.0)      # flat annulus
ring(1.0, 0.0, 1.0, 0.35, 0.0, 1.0)      # vertical band
bm.to_mesh(me); bm.free()
mat = bpy.data.materials.new("pulse"); mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(tga)
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
me.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out)
