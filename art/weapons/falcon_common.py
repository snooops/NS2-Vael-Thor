"""Shared Falcon Rilfe import for the NS2 weapon builds (Blender).

import_falcon(gltf) -> one joined mesh object in Falcon space (Blender, after glTF import):
forward = -Y (muzzle at Y = -21.64), up = +Z, side = X; units ~ cm-ish (length 48.76).
Faces of the two untextured materials are re-pointed at solid patches painted into the
texture by make_falcon_bakes.py: Material__2 (flat dark grey) and Material__1_ncl1_1
(flat emissive cyan strip -> purple plasma glow).
"""
import bpy

PATCH_UV = {                      # texture pixel centre (x, y from top) / 1024
    "Material__2":        (730 / 1024, 1 - 70 / 1024),
    "Material__1_ncl1_1": (830 / 1024, 1 - 70 / 1024),
}
# reference points in Falcon space
MUZZLE  = (0.0, -21.64, 5.8)
TRIGGER = (0.0, 9.7, 1.5)
GRIP    = (0.0, 11.0, 1.0)        # where the right hand closes (third-person hand attach)

def import_falcon(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    for o in meshes:
        uv = o.data.uv_layers.active
        for poly in o.data.polygons:
            mat = o.data.materials[poly.material_index] if o.data.materials else None
            name = mat.name.split(".")[0] if mat else ""
            if name in PATCH_UV and uv:
                for li in poly.loop_indices:
                    uv.data[li].uv = PATCH_UV[name]
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    falcon = bpy.context.view_layer.objects.active
    mw = falcon.matrix_world.copy()          # keep the glTF root rotation/scale when unparenting
    falcon.parent = None
    falcon.matrix_world = mw
    bpy.ops.object.select_all(action='DESELECT'); falcon.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.data.objects):          # glTF empties
        if o not in before and o is not falcon:
            bpy.data.objects.remove(o)
    falcon.data.materials.clear()
    falcon.name = "falcon"
    for p in falcon.data.polygons: p.use_smooth = True
    return falcon
