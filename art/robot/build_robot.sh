#!/usr/bin/env bash
# Full pipeline: robot.fbx (high-poly) -> NS2 robot.model + DDS textures + material.
# Usage: ./build_robot.sh [path/to/robot.fbx] [target_tris]
set -euo pipefail
IN="${1:-$HOME/Downloads/robot.fbx}"; TRIS="${2:-15000}"
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"
ART="$MOD/art/robot"; SRC="$MOD/source/modelsrc/vaelthor/robot"; OUT="$MOD/output/models/vaelthor/robot"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$SRC" "$OUT"

echo "== 1/4 Blender: decimate, bake, export"
blender -b --factory-startup --python-exit-code 1 -P "$ART/convert_robot.py" -- "$IN" "$ART" "$SRC" "$TRIS" \
  2>&1 | grep -E "HIGH|LOW|BAKED|EXPORTED|DONE|Error|Traceback" | grep -v OpenColorIO

echo "== 2/4 textures"
python3 -I "$ART/make_ns2_textures.py" "$ART" "$ART/tga"
cd "$ART/tga"
wine "$NS2/utils/nvcompress.exe" -bc1 robot.tga "$(w "$OUT/robot.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 robot_spec.tga "$(w "$OUT/robot_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 robot_normal.tga "$(w "$OUT/robot_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 robot_illum.tga "$(w "$OUT/robot_illum.dds")" >/dev/null 2>&1

echo "== 3/4 CompileModel"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst "models" \
  robot.model_compile "$(w "$OUT/robot.model")" 2>&1 | grep -v radv

echo "== 4/4 material"
cp "$MOD/source/models/vaelthor/robot/robot.material" "$OUT/"
ls -la "$OUT"
