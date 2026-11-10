"""Quick Cycles preview of a prepared building with its converted NS2 albedo + emissive maps.
Usage: blender -b --factory-startup -P preview_building.py -- <name>_prepared.blend <name> <tga_dir> <out.png>"""
import bpy, sys, math, os
from mathutils import Vector
blend, name, tga_dir, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
for o in list(sc.objects):
    if o.name.startswith("Hull"):
        bpy.data.objects.remove(o, do_unlink=True)
ob = sc.objects[name]; nt = ob.data.materials[0].node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
em = nt.nodes.new("ShaderNodeTexImage"); em.image = bpy.data.images.load(os.path.join(tga_dir, name + "_illum.tga"))
nt.links.new(em.outputs["Color"], bsdf.inputs["Emission Color"]); bsdf.inputs["Emission Strength"].default_value = 3
bsdf.inputs["Metallic"].default_value = 0.6; bsdf.inputs["Roughness"].default_value = 0.35
sc.render.engine = "CYCLES"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x = sc.render.resolution_y = 768; sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.26, 0.3, 1)
zs = [v.co.z for v in ob.data.vertices]; h = max(zs)
r = max(max(abs(v.co.x), abs(v.co.y)) for v in ob.data.vertices)
cd = bpy.data.cameras.new("c"); cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
centre = Vector((0, 0, h * 0.5)); d = Vector((math.cos(0.6), math.sin(0.6), 0.45)).normalized()
cam.location = centre + d * (max(h, 2 * r) * 1.9); cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
ld = bpy.data.lights.new("k", "SUN"); ld.energy = 3
lo = bpy.data.objects.new("k", ld); sc.collection.objects.link(lo); lo.rotation_euler = (0.8, 0.3, 0.6)
sc.render.filepath = out; bpy.ops.render.render(write_still=True)
print("PREVIEW", out)
