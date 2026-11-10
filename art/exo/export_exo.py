"""Export an exo-rigged model (armature + mesh with slots robot/minigun) to FBX for CompileModel.

Usage: blender -b --factory-startup -P export_exo.py -- <rigged.blend> <out.fbx> <body.tga> <minigun_proxy.tga>
CompileModel names each material after its diffuse texture path relative to -material_src, so the proxy
<modelsrc>/marine/exosuit/minigun.tga makes the gun faces use the game's models/marine/exosuit/minigun.material.
Bone axes as in skeleton/export_rigged.py (primary X, secondary Y).
"""
import bpy, sys
BLEND, OUT_FBX, BODY_TGA, GUN_TGA = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
mesh = next(o for o in sc.objects if o.type == 'MESH')
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)

def textured(mat, path):
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(path)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
assert [m.name for m in mesh.data.materials][:2] == ["robot", "minigun"], [m.name for m in mesh.data.materials]
textured(mesh.data.materials[0], BODY_TGA)
textured(mesh.data.materials[1], GUN_TGA)

for o in sc.objects: o.select_set(o in (arm, mesh))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=OUT_FBX, use_selection=True, object_types={'ARMATURE', 'MESH'},
                         apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                         axis_forward='-Z', axis_up='Y',
                         primary_bone_axis='X', secondary_bone_axis='Y',
                         use_armature_deform_only=False, add_leaf_bones=False,
                         armature_nodetype='NULL', bake_anim=False,
                         mesh_smooth_type='FACE', use_tspace=True, path_mode='ABSOLUTE')
print("EXPORTED", OUT_FBX)
