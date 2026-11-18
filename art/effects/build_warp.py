"""Warp field (singularity) geometry -> FBX for CompileModel. Used by build_warp.sh.
Usage: blender -b --factory-startup -P build_warp.py -- <src_dir> <preview.png|->

All sizes in units of the event horizon radius (1.0); the client scales the parts every frame.
  warp_core   black sphere r = 1 (marine shader, black maps: the hole itself)
  warp_halo   flat square 2 x 2.4 wide, normal = NS2 +Z (Blender -Y): billboarded towards the camera by the
              client; the radial texture is the white-hot photon ring at r = 1 with a blue glow falling outward
  warp_disk   flat annulus r 1.25 .. 3.2 in the NS2 XZ plane (Blender XY), u = angle, v = radius: the accretion
              disk, streaky blue/white texture, spun by the client
Halo and disk use the additive Emissive shader (black = invisible) and are two-sided.
Frame: NS2 +Z = Blender -Y, NS2 +Y = Blender +Z (axis_forward='-Z', axis_up='Y' like every other VT model).
"""
import bpy, bmesh, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, PREVIEW = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def material(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(os.path.join(SRC, name + ".tga"))
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0 if name == "warp_core" else 4
    if name == "warp_core":
        bsdf.inputs["Roughness"].default_value = 1; bsdf.inputs["Specular IOR Level"].default_value = 0
    return m


def mesh_object(name, verts, faces, uvs, two_sided, depth_axis, depth, black_uv):
    me = bpy.data.meshes.new(name)
    if two_sided:
        n = len(verts)
        faces = faces + [tuple(reversed(f)) for f in faces]
        uvs = uvs + [tuple(reversed(u)) for u in uvs]
    # A flat mesh compiles to a zero-thickness bounding box (model chunk 17) and the engine never drew it (first
    # in-game test: only the core showed). Two tiny triangles off the plane, on a black texel (= invisible with
    # the additive Emissive shader), give the box real depth.
    for side in (-1, 1):
        base = len(verts)
        for dx, dy in ((0, 0), (0.002, 0), (0, 0.002)):
            v = [dx, dy, 0.0]
            v[depth_axis] = side * depth
            if depth_axis == 2:
                v[0], v[1] = dx, dy
            elif depth_axis == 1:
                v[0], v[2] = dx, dy
            verts.append(tuple(v))
        faces.append((base, base + 1, base + 2))
        uvs.append((black_uv, black_uv, black_uv))
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    li = 0
    for poly, fuv in zip(me.polygons, uvs):
        for k, loop in enumerate(poly.loop_indices):
            uv.data[loop].uv = fuv[k]
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
    ob.data.materials.append(material(name))
    return ob


def export(ob):
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(SRC, ob.name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_tspace=True,
                             path_mode="ABSOLUTE")
    print("EXPORTED", path)


# ---- core: smooth black sphere
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0)
core = bpy.context.object; core.name = "warp_core"
for p in core.data.polygons:
    p.use_smooth = True
core.data.materials.append(material("warp_core"))

# ---- halo: square in the Blender XZ plane (normal -Y = NS2 +Z)
H = 2.4
halo = mesh_object("warp_halo", [(-H, 0, -H), (H, 0, -H), (H, 0, H), (-H, 0, H)], [(0, 1, 2, 3)],
                   [((0, 0), (1, 0), (1, 1), (0, 1))], True, 1, H, (0.002, 0.002))

# ---- disk: annulus in the Blender XY plane
R0, R1, N = 1.25, 3.2, 72
verts, faces, uvs = [], [], []
for k in range(N + 1):                      # seam duplicated so u runs 0..1 without wrapping back
    a = 2 * math.pi * k / N
    verts += [(R0 * math.cos(a), R0 * math.sin(a), 0), (R1 * math.cos(a), R1 * math.sin(a), 0)]
for k in range(N):
    i = 2 * k
    faces.append((i, i + 2, i + 3, i + 1))
    u0, u1 = k / N, (k + 1) / N
    uvs.append(((u0, 0), (u1, 0), (u1, 1), (u0, 1)))
disk = mesh_object("warp_disk", verts, faces, uvs, True, 2, R1, (0.5, 0.998))

for ob in (core, halo, disk):
    export(ob)

if PREVIEW != "-":
    # preview only, AFTER the export: additive like the game's Emissive shader (black = see-through). Doing this
    # before the export disconnected the Principled BSDF, so the FBX had no texture and CompileModel gave halo and
    # disk an EMPTY material - the engine drew nothing (cost three in-game tests, 2026-11-18).
    for ob in (halo, disk):
        nt = ob.data.materials[0].node_tree
        tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(tex.outputs["Color"], em.inputs["Color"]); em.inputs["Strength"].default_value = 3
        nt.links.new(em.outputs[0], add.inputs[0]); nt.links.new(tr.outputs[0], add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs["Surface"])
    # quick look: disk tilted, halo facing the camera, black background
    disk.rotation_euler = (math.radians(-20), 0, 0)
    cam_d = bpy.data.cameras.new("c"); cam = bpy.data.objects.new("c", cam_d); sc.collection.objects.link(cam)
    sc.camera = cam; cam.location = (0, -12, 0); cam.rotation_euler = (math.radians(90), 0, 0)
    sc.render.engine = "CYCLES"; sc.cycles.samples = 32
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", PREVIEW)
