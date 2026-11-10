"""Export armature + one mesh with N material slots to FBX for CompileModel; each slot gets a texture whose path
(relative to -material_src) names its .material (e.g. <modelsrc>/marine/hands/hands.tga -> models/marine/hands/hands.material).

Usage: blender -b --factory-startup -P export_multi.py -- <rigged.blend> <out.fbx> <slot0.tga> [<slot1.tga> ...]
"""
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
BLEND, OUT_FBX, TGAS = args[0], args[1], args[2:]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
mesh = next(o for o in sc.objects if o.type == 'MESH')
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
assert len(mesh.data.materials) == len(TGAS), ([m.name for m in mesh.data.materials], TGAS)
for mat, tga in zip(mesh.data.materials, TGAS):
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(tga)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
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
