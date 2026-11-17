#!/usr/bin/env bash
# Praetor (I) shoulder missile pod -> output/models/vaelthor/lasergun/missile_pod.model
# Shares the laser gun atlas/material (models/vaelthor/lasergun/lasergun.material): run build_lasergun.sh first.
# Geometry: build_missilepod.py (origin = launch point, +Z = launch direction). Placed + animated by Client.lua.
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/weapons"; WORK="$HERE/work_missilepod"
SRC="$MOD/source/modelsrc/vaelthor/lasergun"; OUT="$MOD/output/models/vaelthor/lasergun"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK"
test -f "$SRC/lasergun.tga" && test -f "$OUT/lasergun.material" || { echo "run build_lasergun.sh first"; exit 1; }

blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_missilepod.py" -- \
    "$SRC/missile_pod.fbx" "$SRC/lasergun.tga" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor
cd "$SRC"
for m in missile_pod; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
    echo "$m.model -> $(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
done
ls -l "$OUT"/missile_pod*
