"""Export a static (unrigged) mesh with one textured material to FBX for CompileModel.
Usage: blender -b --factory-startup -P export_static.py -- <in.blend> <out.fbx> <material.tga>"""
import bpy, sys
BLEND, OUT_FBX, TGA = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
ob = next(o for o in sc.objects if o.type == 'MESH')
mat = ob.data.materials[0]; mat.use_nodes = True
nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(TGA)
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
for o in sc.objects: o.select_set(o is ob)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.fbx(filepath=OUT_FBX, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                         axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_tspace=True, path_mode='ABSOLUTE')
print("EXPORTED", OUT_FBX)
