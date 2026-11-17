#!/usr/bin/env bash
# Artificer "Crucible" models -> output/models/vaelthor/crucible/
#   crucible_body / crucible_core / crucible_thigh / crucible_shin / crucible_foot .model + crucible.material
# Rigid parts placed and animated by lua/VaelThor/VTCrucible.lua (procedural tripod gait, no skeleton).
# Geometry: build_crucible.py. Preview: art/artificer/work_crucible/preview.png
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/artificer"; WORK="$HERE/work_crucible"
SRC="$MOD/source/modelsrc/vaelthor/crucible"; OUT="$MOD/output/models/vaelthor/crucible"; MATSRC="$MOD/source/models/vaelthor/crucible"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"

echo "== textures (8 columns: chrome | gunmetal | dark | glow | crystal | unused)"
python3 -I - "$WORK" <<'PY'
import sys, os, math, random
from PIL import Image
out = sys.argv[1]
random.seed(7)
CW, H, N = 32, 64, 8
W = CW * N
alb = Image.new("RGB", (W, H)); spec = Image.new("RGBA", (W, H)); emis = Image.new("RGB", (W, H))
for x in range(W):
    col = x // CW
    for y in range(H):
        n = random.uniform(-1, 1)
        if col == 0:      # chrome: bright, very glossy
            a = tuple(int(c + n * 4) for c in (168, 170, 184)); sp, g, e = (225, 225, 235), 235, (0, 0, 0)
        elif col == 1:    # gunmetal plate
            a = tuple(int(c + n * 3) for c in (40, 38, 50)); sp, g, e = (110, 105, 125), 170, (0, 0, 0)
        elif col == 2:    # dark joints / cables
            a = tuple(int(c + n * 2) for c in (16, 13, 22)); sp, g, e = (40, 36, 48), 90, (0, 0, 0)
        elif col == 3:    # psionic glow
            k = 0.85 + 0.15 * math.sin(y / H * math.pi * 4)
            a = (150, 70, 255); sp, g, e = (60, 30, 90), 110, tuple(int(c * k) for c in (210, 120, 255))
        elif col == 4:    # crystal: deep violet, softly lit from inside
            a = (95, 35, 200); sp, g, e = (200, 170, 255), 240, (120, 50, 230)
        else:
            a, sp, g, e = (128, 128, 128), (100, 100, 100), 128, (0, 0, 0)
        alb.putpixel((x, y), tuple(max(0, min(255, c)) for c in a))
        spec.putpixel((x, y), sp + (g,)); emis.putpixel((x, y), e)
alb.save(os.path.join(out, "crucible.tga")); spec.save(os.path.join(out, "crucible_spec.tga"))
emis.save(os.path.join(out, "crucible_illum.tga"))
Image.new("RGB", (W, H), (128, 128, 255)).save(os.path.join(out, "crucible_normal.tga"))
print("textures ok")
PY
cd "$WORK"
for t in crucible crucible_spec crucible_illum; do
    wine "$NS2/utils/nvcompress.exe" -rgb $t.tga "$(w "$OUT/$t.dds")" >/dev/null 2>&1
done
wine "$NS2/utils/nvcompress.exe" -normal -bc1 crucible_normal.tga "$(w "$OUT/crucible_normal.dds")" >/dev/null 2>&1
cp crucible.tga "$SRC/crucible.tga"     # texture proxy: CompileModel derives the material path from it

# every map the shader needs (a missing map crashes the client when rendered)
cat > "$MATSRC/crucible.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/crucible/crucible.dds"
normalMap = "models/vaelthor/crucible/crucible_normal.dds"
emissiveMap = "models/vaelthor/crucible/crucible_illum.dds"
specularMap = "models/vaelthor/crucible/crucible_spec.dds"
surface = "metal"
MAT
cp "$MATSRC/crucible.material" "$OUT/crucible.material"

echo "== geometry"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_crucible.py" -- "$SRC" "$SRC/crucible.tga" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor

echo "== compile"
cd "$SRC"
for m in crucible_body crucible_core crucible_thigh crucible_shin crucible_foot crucible_view; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
    echo "$m.model -> $(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
done
for k in albedoMap normalMap emissiveMap specularMap; do grep -q "^$k" "$OUT/crucible.material" || { echo "material lacks $k"; exit 1; }; done
ls -l "$OUT"
