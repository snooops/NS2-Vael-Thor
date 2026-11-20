"""Export the rigged robot (armature + skinned mesh) to FBX for CompileModel.

Usage: blender -b --factory-startup -P export_rigged.py -- <robot_rigged.blend> <out.fbx> <texture_proxy.tga> [<slot1.tga> ...]
With extra textures the mesh keeps its material slots: slot i gets texture i, so each slot compiles into its own
NS2 material / face set (e.g. the Subject's claws as face set 1).
Bones are exported with primary axis X / secondary Y so every FBX joint frame equals the NS2/Max frame.
"""
import bpy, sys, os
args = sys.argv[sys.argv.index("--") + 1:]
BLEND, OUT_FBX, TGA = args[:3]
EXTRA = args[3:]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
mesh = next(o for o in sc.objects if o.type == 'MESH')
arm.name = "robot_skeleton"
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)

# material whose diffuse texture path is <modelsrc>/vaelthor/robot/robot.tga -> models/vaelthor/robot/robot.material
def proxy(tga, name=None):
    mat = bpy.data.materials.new(name or os.path.splitext(os.path.basename(tga))[0])
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(tga)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat
if EXTRA:
    slots = [TGA] + EXTRA
    assert len(mesh.data.materials) == len(slots), "mesh has %d material slots, %d textures given" % (len(mesh.data.materials), len(slots))
    for i, tga in enumerate(slots):
        mesh.data.materials[i] = proxy(tga)
else:
    mesh.data.materials.clear(); mesh.data.materials.append(proxy(TGA, "robot"))

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
