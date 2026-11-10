"""Half-size copies of the Exosuit railgun's per-surface impact cinematics for the plasma bolt.

Usage: python3 make_bolt_impact.py <ns2 dir> <out dir> [scale=0.5]
Spark .cinematic (CIN v1) properties are a u32-length-prefixed name followed by [type][count][flag] and the
values: 4 bytes apart when flag == 0, 12 bytes apart (value + key data) when flag == 1. Only the value slots of
size/velocity/radius properties are scaled, each checked to be a sane positive float first; colours, timing,
emission and materials are untouched. Writes <out>/<surface>.cinematic for every surface that has a
cinematics/materials/<surface>/ricochetRailgun.cinematic.
"""
import sys, os, struct, math

NS2, OUT = sys.argv[1], sys.argv[2]
SCALE = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
PROPS = {"Particle Size", "Particle Velocity", "particle_velocity", "max_particle_speed",
         "sphere_outer_radius", "sphere_inner_radius", "Radius"}

def names(d):
    out, i = [], 0
    while i < len(d) - 4:
        n = struct.unpack_from('<I', d, i)[0]
        if 3 <= n <= 40 and i + 4 + n <= len(d):
            s = d[i + 4:i + 4 + n]
            if all(32 <= c < 127 for c in s) and s[:1].isalpha():
                out.append((i, s.decode())); i += 4 + n; continue
        i += 1
    return out

def scale_file(src, dst):
    d = bytearray(open(src, 'rb').read())
    assert d[:3] == b"CIN", src
    changed = skipped = 0
    for p, name in names(bytes(d)):
        if name not in PROPS:
            continue
        base = p + 4 + len(name)
        typ, count, flag = struct.unpack_from('<III', d, base)
        if count < 1 or count > 4 or flag not in (0, 1):
            skipped += 1; continue
        step = 4 if flag == 0 else 12
        for k in range(count):
            off = base + 12 + step * k
            v = struct.unpack_from('<f', d, off)[0]
            if math.isfinite(v) and 0 <= v < 1000:
                struct.pack_into('<f', d, off, v * SCALE); changed += 1
            else:
                skipped += 1
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'wb').write(d)
    return changed, skipped

root = os.path.join(NS2, "cinematics", "materials")
for surface in sorted(os.listdir(root)):
    src = os.path.join(root, surface, "ricochetRailgun.cinematic")
    if os.path.isfile(src):
        c, s = scale_file(src, os.path.join(OUT, surface + ".cinematic"))
        print(f"{surface:12} scaled {c:3} values, skipped {s}")
