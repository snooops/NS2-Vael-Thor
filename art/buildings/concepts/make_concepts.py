"""Vael'Thor building concept renders for Tripo image-to-3D.
Usage: blender -b -P make_concepts.py -- <out_dir> [building ...]

Original design language (matches the Sentinel soldiers): polished chrome + dark gunmetal plating,
angular chamfered shapes, octagonal/hexagonal stepped bases, floating faceted violet crystals and
thin glowing violet seams. One object per image, 3/4 view from slightly above, transparent background
(a white-background copy is made afterwards by the shell script).
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- scene / materials
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 96
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = 1024
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"   # this system's OCIO config only offers Standard
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.35, 0.36, 0.40, 1)
    bg.inputs["Strength"].default_value = 0.6
    global M
    M = {
        "silver": mat("silver", (0.70, 0.72, 0.78), 1.0, 0.24),
        "gun":    mat("gun", (0.10, 0.10, 0.13), 0.85, 0.38),
        "glow":   mat("glow", (0.45, 0.12, 0.85), 0.0, 0.4, emit=(0.50, 0.15, 1.0), strength=2.2),
        "crystal": mat("crystal", (0.32, 0.08, 0.75), 0.0, 0.1, emit=(0.45, 0.12, 1.0), strength=0.5),
    }


def mat(name, color, metal, rough, emit=None, strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def finish(obj, m, bevel=0.0, smooth=False):
    obj.data.materials.append(M[m])
    if bevel > 0:
        b = obj.modifiers.new("bevel", "BEVEL")
        b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def prism(n, r, h, z, m, r_top=None, rot=0.0, x=0.0, y=0.0, bevel=0.03):
    """n-sided prism (or frustum with r_top) standing on z."""
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r if r_top is None else r_top, depth=h,
                                    location=(x, y, z + h / 2), rotation=(0, 0, rot))
    return finish(bpy.context.object, m, bevel)


def bipyramid(r, up, down, z, m="crystal", n=6, x=0.0, y=0.0, tilt=(0, 0, 0)):
    """Faceted crystal: two cones base to base, widest at z."""
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=up, location=(0, 0, up / 2))
    a = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=0, depth=down, location=(0, 0, -down / 2),
                                    rotation=(math.pi, 0, 0))
    b = bpy.context.object
    bpy.ops.object.select_all(action="DESELECT"); a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    a.location = (x, y, z); a.rotation_euler = tilt
    return finish(a, m)


def box(sx, sy, sz, loc, m, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel)


def ring(R, r, z, m="glow", n=48, rot=(0, 0, 0), loc=None, minor_n=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=n, minor_segments=minor_n,
                                     location=loc or (0, 0, z), rotation=rot)
    return finish(bpy.context.object, m, smooth=True)


def seam(n, r, z, rot=0.0):
    """thin glowing band around an n-gon base edge (open band: no caps covering the base top)"""
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r, depth=0.05, end_fill_type="NOTHING",
                                    location=(0, 0, z + 0.025), rotation=(0, 0, rot))
    o = bpy.context.object
    s = o.modifiers.new("thick", "SOLIDIFY"); s.thickness = 0.02
    return finish(o, "glow")


def around(count, radius, phase=0.0):
    for k in range(count):
        a = phase + 2 * math.pi * k / count
        yield a, radius * math.cos(a), radius * math.sin(a)


def plate(w, t, h, a, radius, z0, lean_deg, m="silver", glow=True):
    """Tall plate standing at angle a on a circle, leaning inward by lean_deg; optional glow strip outside."""
    lean = math.radians(lean_deg)
    cx = radius * math.cos(a); cy = radius * math.sin(a)
    rot = (0, -lean, a)                       # local X points outward after the z rotation
    zc = z0 + h / 2 * math.cos(lean)
    off = -h / 2 * math.sin(lean)
    loc = (cx + off * math.cos(a), cy + off * math.sin(a), zc)
    box(t, w, h, loc, m, rot=rot)
    if glow:
        out = t / 2 + 0.012
        g = (loc[0] + out * math.cos(a) * math.cos(lean), loc[1] + out * math.sin(a) * math.cos(lean),
             loc[2] + out * math.sin(lean))
        box(0.02, w * 0.18, h * 0.8, g, "glow", rot=rot, bevel=0)


# ---------------------------------------------------------------- buildings
def nexus():
    prism(8, 3.2, 0.4, 0, "gun", rot=math.pi / 8); seam(8, 3.23, 0.36, math.pi / 8)
    prism(8, 2.6, 0.35, 0.4, "silver", rot=math.pi / 8); seam(8, 2.63, 0.71, math.pi / 8)
    prism(8, 2.0, 0.3, 0.75, "gun", rot=math.pi / 8)
    prism(8, 1.1, 0.25, 1.05, "silver", r_top=0.8, rot=math.pi / 8)
    for a, x, y in around(4, 1.75, math.pi / 4):
        plate(0.9, 0.3, 3.4, a, 1.75, 1.0, 14)
    bipyramid(0.75, 2.3, 1.1, 4.0)
    ring(1.35, 0.06, 4.15)
    for a, x, y in around(6, 2.5, 0.3):
        bipyramid(0.16, 0.45, 0.3, 3.4 + 0.25 * math.sin(3 * a), x=x, y=y, n=4, tilt=(0.3, 0.2, a))


def siphon():
    prism(6, 1.8, 0.3, 0, "gun"); seam(6, 1.82, 0.27)
    prism(6, 1.2, 0.2, 0.3, "silver", r_top=1.0)
    for a, x, y in around(3, 1.35, math.pi / 6):
        plate(0.45, 0.22, 2.7, a, 1.35, 0.25, 22, glow=True)
    prism(6, 0.45, 2.6, 0.5, "silver")
    for z in (1.1, 1.7, 2.3):
        seam(6, 0.48, z)
    prism(8, 0.95, 0.35, 3.0, "gun", rot=math.pi / 8); seam(8, 0.97, 3.32, math.pi / 8)
    prism(8, 0.6, 0.3, 3.35, "silver", r_top=0.35, rot=math.pi / 8)
    bipyramid(0.32, 0.8, 0.35, 4.15, n=4)
    for a, x, y in around(2, 1.0, 0.0):
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.28, depth=1.1, location=(x, y, 1.15))
        finish(bpy.context.object, "crystal", smooth=True)
        prism(8, 0.33, 0.12, 0.55, "silver", x=x, y=y, bevel=0.01)
        prism(8, 0.33, 0.12, 1.7, "silver", x=x, y=y, bevel=0.01)


def pylon():
    prism(6, 0.95, 0.25, 0, "gun"); seam(6, 0.97, 0.22)
    prism(6, 0.62, 0.2, 0.25, "silver", r_top=0.5)
    for a, x, y in around(3, 0.42, math.pi / 2):
        plate(0.5, 0.12, 2.4, a, 0.42, 0.4, -6)
    bipyramid(0.45, 0.95, 0.95, 3.45, n=4)
    for a, x, y in around(3, 0.95, 0.4):
        bipyramid(0.1, 0.28, 0.22, 3.45 + 0.2 * math.cos(a), x=x, y=y, n=4, tilt=(0.4, 0, a))


def chamber():
    prism(8, 2.2, 0.35, 0, "gun", rot=math.pi / 8); seam(8, 2.23, 0.31, math.pi / 8)
    prism(8, 1.5, 0.25, 0.35, "silver", rot=math.pi / 8)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.85, depth=2.2, location=(0, 0, 1.75))
    finish(bpy.context.object, "crystal", smooth=True)
    for z in (0.65, 2.85):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.85, location=(0, 0, z)); o = bpy.context.object
        o.scale = (1, 1, 0.35); finish(o, "crystal", smooth=True)
    for a, x, y in around(4, 1.15, math.pi / 4):
        plate(0.35, 0.25, 2.9, a, 1.15, 0.5, -4)
    prism(8, 1.3, 0.45, 3.2, "silver", r_top=1.0, rot=math.pi / 8); seam(8, 1.32, 3.18, math.pi / 8)
    prism(8, 0.7, 0.3, 3.65, "gun", r_top=0.4, rot=math.pi / 8)
    bipyramid(0.22, 0.6, 0.2, 4.2, n=4)
    box(0.5, 0.9, 0.7, (1.75, 0, 0.7), "gun", rot=(0, math.radians(-20), 0))
    box(0.04, 0.6, 0.35, (1.98, 0, 0.82), "glow", rot=(0, math.radians(-20), 0), bevel=0)


def shield_generator():
    prism(6, 1.7, 0.4, 0, "gun"); seam(6, 1.72, 0.36)
    prism(6, 1.3, 0.15, 0.4, "silver")
    prism(8, 0.35, 1.3, 0.55, "silver", r_top=0.22, rot=math.pi / 8)
    bipyramid(0.32, 0.6, 0.35, 2.1, n=4)
    # lattice dome: upper half of an icosphere turned into glowing struts
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.5, location=(0, 0, 0.55))
    dome = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.05], context="VERTS")
    bm.to_mesh(dome.data); bm.free()
    w = dome.modifiers.new("lattice", "WIREFRAME"); w.thickness = 0.06
    finish(dome, "glow")
    for a, x, y in around(6, 1.5, 0.0):
        prism(4, 0.18, 0.5, 0.45, "silver", x=x, y=y, rot=a + math.pi / 4, r_top=0.1)


def obelisk():
    prism(8, 1.05, 0.3, 0, "gun", rot=math.pi / 8); seam(8, 1.08, 0.27, math.pi / 8)
    prism(8, 0.75, 0.2, 0.3, "silver", rot=math.pi / 8)
    prism(4, 0.55, 3.0, 0.5, "silver", r_top=0.22, rot=math.pi / 4)
    for a, x, y in around(4, 0.0, 0.0):
        # glow strip down the middle of each face
        r = 0.27
        box(0.03, 0.06, 2.6, (r * math.cos(a), r * math.sin(a), 1.95), "glow",
            rot=(0, -math.atan(0.33 / 3.0), a), bevel=0)
    # three prongs rising from the tip and cradling the crystal (turret head)
    for a, x, y in around(3, 0.0, math.pi / 2):
        plate(0.18, 0.1, 1.1, a, 0.3, 3.35, -18, glow=False)
    bipyramid(0.3, 0.55, 0.5, 4.15, n=6)
    ring(0.55, 0.035, 3.75)


def rift_portal():
    prism(6, 2.0, 0.3, 0, "gun"); seam(6, 2.02, 0.27)
    prism(6, 1.6, 0.12, 0.3, "silver"); seam(6, 1.2, 0.4)
    ring(1.55, 0.17, 0, "silver", n=8, rot=(math.radians(90), 0, math.radians(90)), loc=(0, 0, 2.05), minor_n=6)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.4, depth=0.04, location=(0, 0, 2.05),
                                        rotation=(math.radians(90), 0, math.radians(90)))
    finish(bpy.context.object, "glow")
    for side in (-1, 1):
        box(0.35, 0.45, 2.1, (0, side * 1.85, 1.35), "silver", rot=(side * math.radians(-6), 0, 0))
        bipyramid(0.16, 0.45, 0.25, 2.75, x=0, y=side * 1.95, n=4)


def spire():
    prism(8, 1.45, 0.35, 0, "gun", rot=math.pi / 8); seam(8, 1.48, 0.31, math.pi / 8)
    prism(8, 1.0, 0.3, 0.35, "silver", rot=math.pi / 8)
    z, r = 0.65, 0.75
    for i in range(7):
        h = 0.62
        prism(6, r, h, z, "silver" if i % 2 == 0 else "gun", r_top=r * 0.88, rot=math.radians(17 * i))
        seam(6, r * 0.9, z + h - 0.03, rot=math.radians(17 * i))
        z += h; r *= 0.86
    bipyramid(0.38, 1.2, 0.4, z + 0.85, n=6)
    for a, x, y in around(3, 0.75, 0.0):
        bipyramid(0.1, 0.32, 0.22, z + 0.55, x=x, y=y, n=4, tilt=(0.5, 0, a))


BUILDINGS = {
    "nexus": nexus, "siphon": siphon, "pylon": pylon, "synthesis_chamber": chamber,
    "shield_generator": shield_generator, "sentinel_obelisk": obelisk, "rift_portal": rift_portal,
    "psionic_spire": spire,
}


# ---------------------------------------------------------------- camera / lights / render
def frame_and_light():
    sc = bpy.context.scene
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in sc.objects:
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2

    cam_data = bpy.data.cameras.new("cam"); cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
    fov = 2 * math.atan(18 / 50)
    dist = radius / math.sin(fov / 2) * 1.05
    az, el = math.radians(35), math.radians(20)
    direction = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
    cam.location = centre + direction * dist
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()

    for name, d, energy, size in (("key", (0.6, -0.6, 0.9), 700, 4), ("fill", (-0.8, 0.3, 0.4), 250, 6),
                                  ("rim", (-0.2, 0.9, 0.6), 500, 3)):
        ld = bpy.data.lights.new(name, "AREA"); ld.energy = energy; ld.size = size
        lo_ = bpy.data.objects.new(name, ld); sc.collection.objects.link(lo_)
        v = Vector(d).normalized()
        lo_.location = centre + v * (radius * 3 + 4)
        lo_.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()


for name, build in BUILDINGS.items():
    if ONLY and name not in ONLY:
        continue
    reset()
    build()
    frame_and_light()
    bpy.context.scene.render.filepath = os.path.join(OUT, name + "_transparent.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
