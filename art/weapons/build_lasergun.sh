#!/usr/bin/env bash
# Praetor laser guns (replace the exo miniguns): output/models/vaelthor/lasergun/
#   lasergun_body.model    housing, power pack, heat sinks, glowing rails/core
#   lasergun_barrel.model  emitter barrel with coils, crystal lens and prongs (slides back on recoil)
# Both share one material (marine.surface_shader, 4-column atlas hull | panels | glow | steel) and one frame:
# origin = muzzle tip, NS2 +Z = barrel direction. Placed + animated by Client.lua (Praetor laser guns).
# Geometry: build_lasergun.py. Preview render: art/weapons/work_lasergun/preview.png
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/weapons"; WORK="$HERE/work_lasergun"
SRC="$MOD/source/modelsrc/vaelthor/lasergun"; OUT="$MOD/output/models/vaelthor/lasergun"; MATSRC="$MOD/source/models/vaelthor/lasergun"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"

echo "== textures"
python3 -I - "$WORK" <<'PY'
import sys, os, math, random
from PIL import Image
out = sys.argv[1]
random.seed(11)
CW, H = 64, 128
W = CW * 4
alb = Image.new("RGB", (W, H)); spec = Image.new("RGBA", (W, H)); emis = Image.new("RGB", (W, H))
for x in range(W):
    col = x // CW
    for y in range(H):
        n = random.uniform(-1, 1)
        if col == 0:      # hull: dark violet-grey armour plate with faint seams
            line = 0.6 if y % 32 in (0, 1) else 1.0
            a = tuple(int(c * line + n * 3) for c in (50, 44, 62)); sp, g, e = (100, 95, 115), 155, (0, 0, 0)
        elif col == 1:    # dark panels / heat sinks
            a = tuple(int(c + n * 2) for c in (22, 20, 28)); sp, g, e = (45, 42, 52), 80, (0, 0, 0)
        elif col == 2:    # psionic glow
            k = 0.85 + 0.15 * math.sin(y / H * math.pi * 6)
            a = (150, 70, 255); sp, g, e = (60, 30, 90), 110, tuple(int(c * k) for c in (205, 115, 255))
        else:             # emitter steel
            a = tuple(int(c + n * 4) for c in (128, 126, 140)); sp, g, e = (175, 175, 190), 220, (0, 0, 0)
        alb.putpixel((x, y), tuple(max(0, min(255, c)) for c in a))
        spec.putpixel((x, y), sp + (g,)); emis.putpixel((x, y), e)
alb.save(os.path.join(out, "lasergun.tga")); spec.save(os.path.join(out, "lasergun_spec.tga"))
emis.save(os.path.join(out, "lasergun_illum.tga"))
Image.new("RGB", (W, H), (128, 128, 255)).save(os.path.join(out, "lasergun_normal.tga"))
print("textures ok")
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -rgb lasergun.tga "$(w "$OUT/lasergun.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb lasergun_spec.tga "$(w "$OUT/lasergun_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb lasergun_illum.tga "$(w "$OUT/lasergun_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 lasergun_normal.tga "$(w "$OUT/lasergun_normal.dds")" >/dev/null 2>&1
cp lasergun.tga "$SRC/lasergun.tga"     # texture proxy: CompileModel derives the material path from it

cat > "$MATSRC/lasergun.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/lasergun/lasergun.dds"
normalMap = "models/vaelthor/lasergun/lasergun_normal.dds"
emissiveMap = "models/vaelthor/lasergun/lasergun_illum.dds"
specularMap = "models/vaelthor/lasergun/lasergun_spec.dds"
surface = "metal"
MAT
cp "$MATSRC/lasergun.material" "$OUT/"

echo "== geometry"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_lasergun.py" -- \
    "$SRC/lasergun_body.fbx" "$SRC/lasergun_barrel.fbx" "$SRC/lasergun.tga" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor

echo "== compile"
cd "$SRC"
for m in lasergun_body lasergun_barrel; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
    echo "$m.model -> $(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
done
ls -l "$OUT"
