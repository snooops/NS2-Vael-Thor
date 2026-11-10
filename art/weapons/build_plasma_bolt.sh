#!/usr/bin/env bash
# Plasma bolt model + material for the Vanguard carbine projectile (VTPlasmaBolt).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/weapons"; WORK="$HERE/work_bolt"
SRC="$MOD/source/modelsrc/vaelthor/bolt"; OUT="$MOD/output/models/vaelthor/bolt"; MATSRC="$MOD/source/models/vaelthor/bolt"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"
python3 -I - "$WORK" <<'PY'
import sys, os
from PIL import Image
out = sys.argv[1]; W, H = 32, 128
emis = Image.new("RGB", (W, H)); px = emis.load()
for y in range(H):
    v = 1 - y / (H - 1)                     # image top = UV v 1 = head
    k = v ** 1.6                            # bright head, fading trail
    core = (1.00, 0.86, 1.00); edge = (0.55, 0.12, 1.00)
    c = [edge[i] + (core[i] - edge[i]) * min(1, k * 1.3) for i in range(3)]
    for x in range(W):
        px[x, y] = tuple(int(255 * min(1, ch * (0.25 + 0.75 * k))) for ch in c)
emis.save(os.path.join(out, "plasma_bolt.tga"))
Image.new("RGB", (W, H), (8, 2, 14)).save(os.path.join(out, "plasma_bolt_albedo.tga"))
Image.new("RGBA", (W, H), (0, 0, 0, 0)).save(os.path.join(out, "plasma_bolt_spec.tga"))
Image.new("RGB", (W, H), (128, 128, 255)).save(os.path.join(out, "plasma_bolt_normal.tga"))
Image.new("RGB", (W, H), (255, 255, 255)).save(os.path.join(out, "plasma_bolt_opacity.tga"))
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -rgb plasma_bolt.tga "$(w "$OUT/plasma_bolt_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 plasma_bolt_albedo.tga "$(w "$OUT/plasma_bolt.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 plasma_bolt_spec.tga "$(w "$OUT/plasma_bolt_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 plasma_bolt_normal.tga "$(w "$OUT/plasma_bolt_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 plasma_bolt_opacity.tga "$(w "$OUT/plasma_bolt_opacity.dds")" >/dev/null 2>&1
cp plasma_bolt.tga "$SRC/plasma_bolt.tga"
cat > "$MATSRC/plasma_bolt.material" <<'MAT'
shader = "shaders/super_emissive.surface_shader"
albedoMap = "models/vaelthor/bolt/plasma_bolt.dds"
emissiveMap = "models/vaelthor/bolt/plasma_bolt_illum.dds"
normalMap = "models/vaelthor/bolt/plasma_bolt_normal.dds"
specularMap = "models/vaelthor/bolt/plasma_bolt_spec.dds"
opacityMap = "models/vaelthor/bolt/plasma_bolt_opacity.dds"
MAT
cp "$MATSRC/plasma_bolt.material" "$OUT/"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_plasma_bolt.py" -- "$SRC/plasma_bolt.fbx" "$SRC/plasma_bolt.tga" 2>&1 | grep -E "EXPORTED|Error|Traceback" | grep -v OpenColor
echo 'geometry "plasma_bolt.fbx"' > "$SRC/plasma_bolt.model_compile"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  plasma_bolt.model_compile "$(w "$OUT/plasma_bolt.model")" 2>&1 | grep -v radv | grep -E "Num|rror" || true
ls -l "$OUT"; strings -n 8 "$OUT/plasma_bolt.model" | grep "\.material"
