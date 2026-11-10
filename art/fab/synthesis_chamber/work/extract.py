import bpy, sys, os
out = sys.argv[sys.argv.index("--") + 1]
for img in bpy.data.images: pass
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(out, "..", "synthesis_chamber.glb"))
for img in bpy.data.images:
    if img.packed_file or img.source == "FILE":
        img.filepath_raw = os.path.join(out, img.name if "." in img.name else img.name + ".png")
        img.save()
        print("SAVED", img.filepath_raw)
