"""Original Blender concept buildings (make_concepts.py) -> GLB + texture maps for build_building.sh.
Usage: blender -b --factory-startup -P export_concepts.py -- <out_dir> [concept ...]

The in-game buildings use these hand-made procedural designs directly (no Tripo). Per concept:
  <out_dir>/<concept>.glb          one joined mesh, modifiers applied, UVs pointing at a 2x2 material atlas
  <out_dir>/<concept>_maps/        basecolor.png, rm.png (G rough, B metal), normal.png (flat), emissive.png
  <out_dir>/<concept>_parts/       <group>.glb per animated part group (make_concepts.anim: core, orbit, halo,
                                   dome) + parts.json {group: pivot [x, y, z]} in concept (Blender) coordinates.
                                   <concept>.glb then holds only the static body.
The atlas cells: silver | gunmetal / glow seams | crystal. Each face's UVs sit inside its material's cell
(inset, so mipmaps don't bleed), colours are the concept materials converted to sRGB.
"""
import bpy, sys, os, math, json
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_concepts as mc

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(argv[0]); ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)

ATLAS = 512
CELLS = {"silver": (0, 1), "gun": (1, 1), "glow": (0, 0), "crystal": (1, 0)}   # (col, row), row 0 = bottom (UV v)
INSET = 0.30                                                                   # of a cell, on each side


def srgb(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def principled(m):
    p = m.node_tree.nodes["Principled BSDF"]
    get = lambda k: p.inputs[k].default_value
    base = tuple(get("Base Color"))[:3]
    emit = tuple(get("Emission Color"))[:3]
    return base, float(get("Metallic")), float(get("Roughness")), emit, float(get("Emission Strength"))


def write_maps(path):
    os.makedirs(path, exist_ok=True)
    half = ATLAS // 2
    imgs = {k: np.zeros((ATLAS, ATLAS, 3)) for k in ("basecolor", "rm", "normal", "emissive")}
    imgs["normal"][:] = (0.5, 0.5, 1.0)
    for name, (cx, cy) in CELLS.items():
        base, metal, rough, emit, strength = principled(mc.M[name])
        # image rows go top-down, UV v bottom-up
        ys = slice((1 - cy) * half, (2 - cy) * half); xs = slice(cx * half, (cx + 1) * half)
        imgs["basecolor"][ys, xs] = srgb(base)
        imgs["rm"][ys, xs] = (1.0, rough, metal)
        # seams glow fully, crystals softly (same split as the old Tripo conversion: panels 0.22, seams 0.9)
        glow = 0.9 if name == "glow" else (0.35 if strength > 0 else 0.0)
        imgs["emissive"][ys, xs] = srgb(emit) * glow
    from PIL import Image
    for k, a in imgs.items():
        Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(path, k + ".png"))


def bake_to_one_mesh(concept, objs):
    sc = bpy.context.scene
    dg = bpy.context.evaluated_depsgraph_get()
    import bmesh
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for o in objs:
        ev = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
        me.transform(o.matrix_world)
        mname = o.data.materials[0].name.split(".")[0] if o.data.materials else "silver"
        cx, cy = CELLS[mname]
        u0, v0 = (cx + INSET) / 2, (cy + INSET) / 2
        span = (1 - 2 * INSET) / 2
        tmp = bmesh.new(); tmp.from_mesh(me)
        tuv = tmp.loops.layers.uv.verify()
        # spread the face's corners a little inside the cell so the mesh has proper (non-degenerate) UVs
        for f in tmp.faces:
            n = len(f.loops)
            for i, l in enumerate(f.loops):
                a = 2 * math.pi * i / n
                l[tuv].uv = (u0 + span * (0.5 + 0.5 * math.cos(a)), v0 + span * (0.5 + 0.5 * math.sin(a)))
        tmp.to_mesh(me); tmp.free()
        bm.from_mesh(me)   # appends; UV layer by name "UVMap" matches the verify() layer
        bpy.data.meshes.remove(me)
    out_me = bpy.data.meshes.new(concept); bm.to_mesh(out_me); bm.free()
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    ob = bpy.data.objects.new(concept, out_me); sc.collection.objects.link(ob)
    # flat-shaded hard surfaces, smooth only where faces meet at shallow angles (crystal tubes, rings)
    out_me.set_sharp_from_angle(angle=math.radians(35))
    mat = bpy.data.materials.new(concept); out_me.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in out_me.polygons)
    return ob, tris


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_materials="NONE",
                              export_yup=True)


for concept, build in mc.BUILDINGS.items():
    if ONLY and concept not in ONLY:
        continue
    mc.reset()
    build()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    groups = {}
    for o in meshes:
        groups.setdefault(o.get("vt_anim"), []).append(o)
    pdir = os.path.join(OUT, concept + "_parts")
    if os.path.isdir(pdir):
        import shutil; shutil.rmtree(pdir)
    pivots = {}
    for group in sorted(g for g in groups if g):
        ob, tris = bake_to_one_mesh(concept + "_" + group, groups[group])
        vs = [v.co for v in ob.data.vertices]
        lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
        centre = [(lo[i] + hi[i]) / 2 for i in range(3)]
        # the core spins about its own centre, the rest (orbiting crystals, rings, dome) about the building axis
        pivots[group] = centre if group == "core" else [0.0, 0.0, centre[2]]
        os.makedirs(pdir, exist_ok=True)
        export(ob, os.path.join(pdir, group + ".glb"))
        bpy.data.objects.remove(ob, do_unlink=True)
        print("PART", concept, group, "tris", tris, "pivot", ["%.2f" % c for c in pivots[group]])
    if pivots:
        with open(os.path.join(pdir, "parts.json"), "w") as f:
            json.dump(pivots, f, indent=1)
    ob, tris = bake_to_one_mesh(concept, groups[None])
    glb = os.path.join(OUT, concept + ".glb")
    export(ob, glb)
    write_maps(os.path.join(OUT, concept + "_maps"))
    print("EXPORTED", concept, "tris", tris, "->", glb)
