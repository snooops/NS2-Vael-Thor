#!/usr/bin/env bash
# Pylon field pulse ring -> output/models/vaelthor/pulse/pulse_ring.model + four brightness materials
# (pulse_ring_100/60/35/15.material, swapped at runtime for a stepped fade; see Classes/VTFieldPulse.lua)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/effects"; WORK="$HERE/work_pulse"
SRC="$MOD/source/modelsrc/vaelthor/pulse"; OUT="$MOD/output/models/vaelthor/pulse"; MATSRC="$MOD/source/models/vaelthor/pulse"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"; cd "$WORK"
python3 -I - "$WORK" <<'PY'
import sys, os, math
from PIL import Image
out = sys.argv[1]; W, H = 64, 32
for level in (100, 60, 35, 15):
    k = level / 100
    emis = Image.new("RGB", (W, H)); alpha = Image.new("L", (W, H))
    for y in range(H):
        v = y / (H - 1)
        fall = math.exp(-((v - 0.5) / 0.22) ** 2)            # soft band across v
        c = (int(170 * fall * k), int(80 * fall * k), int(255 * fall * k))
        for x in range(W):
            emis.putpixel((x, y), c); alpha.putpixel((x, y), 255 if fall * k > 0.08 else 0)
    emis.save(os.path.join(out, f"pulse_ring_{level}.tga")); alpha.save(os.path.join(out, f"pulse_ring_{level}_opacity.tga"))
Image.new("RGB", (4, 4), (0, 0, 0)).save(os.path.join(out, "pulse_black.tga"))
Image.new("RGB", (4, 4), (128, 128, 255)).save(os.path.join(out, "pulse_flat_normal.tga"))   # super_emissive needs
Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(os.path.join(out, "pulse_no_spec.tga"))          # normal + specular maps
PY
for level in 100 60 35 15; do
  wine "$NS2/utils/nvcompress.exe" -rgb pulse_ring_$level.tga "$(w "$OUT/pulse_ring_$level.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -rgb pulse_ring_${level}_opacity.tga "$(w "$OUT/pulse_ring_${level}_opacity.dds")" >/dev/null 2>&1
  cat > "$MATSRC/pulse_ring_$level.material" <<MAT
shader = "shaders/super_emissive.surface_shader"
albedoMap = "models/vaelthor/pulse/pulse_black.dds"
emissiveMap = "models/vaelthor/pulse/pulse_ring_$level.dds"
opacityMap = "models/vaelthor/pulse/pulse_ring_${level}_opacity.dds"
normalMap = "models/vaelthor/pulse/pulse_flat_normal.dds"
specularMap = "models/vaelthor/pulse/pulse_no_spec.dds"
MAT
  cp "$MATSRC/pulse_ring_$level.material" "$OUT/"
done
wine "$NS2/utils/nvcompress.exe" -rgb pulse_black.tga "$(w "$OUT/pulse_black.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -rgb pulse_flat_normal.tga "$(w "$OUT/pulse_flat_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb pulse_no_spec.tga "$(w "$OUT/pulse_no_spec.dds")" >/dev/null 2>&1
# the compiled model's material = models/vaelthor/pulse/pulse_ring.material (full brightness)
cp "$MATSRC/pulse_ring_100.material" "$MATSRC/pulse_ring.material"; cp "$MATSRC/pulse_ring.material" "$OUT/"
cp pulse_ring_100.tga "$SRC/pulse_ring.tga"
blender -b --factory-startup -P "$HERE/make_pulse_ring.py" -- "$WORK/pulse_ring.blend" "$SRC/pulse_ring.tga" 2>&1 | grep -E "SAVED|Error" | grep -v OpenColorIO
blender -b --factory-startup -P "$MOD/art/weapons/export_static.py" -- "$WORK/pulse_ring.blend" "$SRC/pulse_ring.fbx" "$SRC/pulse_ring.tga" 2>&1 | grep -E "EXPORTED|Error" | grep -v OpenColorIO
echo 'geometry "pulse_ring.fbx"' > "$SRC/pulse_ring.model_compile"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  pulse_ring.model_compile "$(w "$OUT/pulse_ring.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
strings -n 8 "$OUT/pulse_ring.model" | grep "\.material"
ls "$OUT"
# every material must exist on disk with all maps the shader requires (a missing one crashed the client)
for f in "$OUT"/pulse_ring*.material; do
  for key in albedoMap emissiveMap opacityMap normalMap specularMap; do
    grep -q "^$key" "$f" || { echo "MISSING $key in $f"; exit 1; }
  done
done
echo "materials ok"
