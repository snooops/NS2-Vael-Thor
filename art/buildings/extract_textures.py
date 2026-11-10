"""Save a Tripo GLB's embedded maps as <out>/basecolor.*, rm.*, normal.* (picked by the image name suffix).
Usage: blender -b --factory-startup -P extract_textures.py -- <in.glb> <out_dir>"""
import bpy, sys, os
glb, out = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
for img in bpy.data.images:
    base, ext = os.path.splitext(img.name)
    for key in ("basecolor", "rm", "normal"):
        if base.lower().endswith(key):
            img.filepath_raw = os.path.join(out, key + (ext or ".png"))
            img.save()
            print("SAVED", key, img.filepath_raw)
