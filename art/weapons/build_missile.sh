#!/usr/bin/env bash
# Praetor homing missile (VTHomingMissile): rocket model + exhaust flame model -> output/models/vaelthor/missile/
#   missile.model        body, marine.surface_shader, 4-column atlas (hull | panels | psionic glow | warhead steel)
#   missile_flame.model  exhaust plume, additive Emissive (black = invisible); scaled per frame by the client
#                        (launch burst + flicker, see VTHomingMissile in source/lua/VaelThor/Classes/VTWeapons.lua)
# Geometry: build_missile.py. Preview render: art/weapons/work_missile/preview.png
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/weapons"; WORK="$HERE/work_missile"
SRC="$MOD/source/modelsrc/vaelthor/missile"; OUT="$MOD/output/models/vaelthor/missile"; MATSRC="$MOD/source/models/vaelthor/missile"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"

echo "== textures"
python3 -I - "$WORK" <<'PY'
import sys, os, math, random
from PIL import Image
out = sys.argv[1]
random.seed(7)
# ---- rocket atlas: 4 columns of 64 px, 128 px tall (v = around the body)
CW, H = 64, 128
W = CW * 4
alb = Image.new("RGB", (W, H)); spec = Image.new("RGBA", (W, H)); emis = Image.new("RGB", (W, H))
for x in range(W):
    col, cx = divmod(x, CW)
    for y in range(H):
        n = random.uniform(-1, 1)
        if col == 0:      # hull: dark violet-grey metal, faint lengthwise panel lines every 16 px
            line = 0.55 if y % 32 in (0, 1) else 1.0
            a = tuple(int(c * line + n * 3) for c in (46, 40, 58))
            sp, g, e = (95, 90, 110), 150, (0, 0, 0)
        elif col == 1:    # dark panels / seams
            a = tuple(int(c + n * 2) for c in (20, 18, 26))
            sp, g, e = (40, 38, 48), 70, (0, 0, 0)
        elif col == 2:    # psionic glow
            k = 0.85 + 0.15 * math.sin(y / H * math.pi * 4)
            a = (150, 70, 255)
            sp, g, e = (60, 30, 90), 110, tuple(int(c * k) for c in (200, 110, 255))
        else:             # warhead steel
            a = tuple(int(c + n * 4) for c in (120, 118, 132))
            sp, g, e = (170, 170, 185), 215, (0, 0, 0)
        alb.putpixel((x, y), tuple(max(0, min(255, c)) for c in a))
        spec.putpixel((x, y), sp + (g,))
        emis.putpixel((x, y), e)
alb.save(os.path.join(out, "missile.tga")); spec.save(os.path.join(out, "missile_spec.tga"))
emis.save(os.path.join(out, "missile_illum.tga"))
Image.new("RGB", (W, H), (128, 128, 255)).save(os.path.join(out, "missile_normal.tga"))

# ---- flame: u across (gaussian), v along (image top = v 1 = nozzle: white-hot -> violet -> black)
FW, FH = 64, 128
fl = Image.new("RGB", (FW, FH))
for y in range(FH):
    t = y / (FH - 1)                          # 0 nozzle .. 1 plume end
    fade = (1 - t) ** 1.4
    hot = max(0.0, 1 - t / 0.28) ** 1.5       # white core near the nozzle
    for x in range(FW):
        u = (x + 0.5) / FW * 2 - 1
        width = 0.35 + 0.65 * (1 - t)         # narrows toward the end
        g = math.exp(-(u / (0.55 * width)) ** 2)
        core = math.exp(-(u / (0.18 * width)) ** 2) * hot
        edge = max(0.0, 1 - abs(u) ** 8)
        r = (170 * g * fade + 255 * core) * edge
        gg = (60 * g * fade + 225 * core) * edge
        b = (255 * g * fade + 255 * core) * edge
        fl.putpixel((x, y), (min(255, int(r)), min(255, int(gg)), min(255, int(b))))
fl.save(os.path.join(out, "missile_flame.tga"))
print("textures ok")
PY

cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -rgb missile.tga "$(w "$OUT/missile.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb missile_spec.tga "$(w "$OUT/missile_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb missile_illum.tga "$(w "$OUT/missile_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 missile_normal.tga "$(w "$OUT/missile_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb missile_flame.tga "$(w "$OUT/missile_flame.dds")" >/dev/null 2>&1
# texture proxies: CompileModel derives each mesh's material from its texture path below -material_src
cp missile.tga "$SRC/missile.tga"; cp missile_flame.tga "$SRC/missile_flame.tga"

cat > "$MATSRC/missile.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/missile/missile.dds"
normalMap = "models/vaelthor/missile/missile_normal.dds"
emissiveMap = "models/vaelthor/missile/missile_illum.dds"
specularMap = "models/vaelthor/missile/missile_spec.dds"
surface = "metal"
MAT
cat > "$MATSRC/missile_flame.material" <<'MAT'
shader = "shaders/Emissive.surface_shader"
emissiveMap = "models/vaelthor/missile/missile_flame.dds"
MAT
cp "$MATSRC/missile.material" "$MATSRC/missile_flame.material" "$OUT/"

echo "== geometry"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_missile.py" -- \
    "$SRC/missile.fbx" "$SRC/missile.tga" "$SRC/missile_flame.fbx" "$SRC/missile_flame.tga" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor

echo "== compile"
cd "$SRC"
for m in missile missile_flame; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num|rror" || true
    echo "$m.model -> $(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
done
ls -l "$OUT"
