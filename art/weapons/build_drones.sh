#!/usr/bin/env bash
# Artificer drones (concept class) -> output/models/vaelthor/drones/drone_{wasp,lancer,sapper}.model
# Shares the laser gun atlas/material (models/vaelthor/lasergun/lasergun.material): run build_lasergun.sh first.
# Geometry: build_drones.py (origin = drone centre, +Z = flight direction). Used by VTDrone (Classes/VTDrones.lua).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/weapons"; WORK="$HERE/work_drones"
SRC="$MOD/source/modelsrc/vaelthor/lasergun"; OUT="$MOD/output/models/vaelthor/drones"
LASER_OUT="$MOD/output/models/vaelthor/lasergun"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$OUT"
test -f "$SRC/lasergun.tga" && test -f "$LASER_OUT/lasergun.material" || { echo "run build_lasergun.sh first"; exit 1; }

blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_drones.py" -- \
    "$SRC/drone_wasp.fbx" "$SRC/drone_lancer.fbx" "$SRC/drone_sapper.fbx" "$SRC/lasergun.tga" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor
cd "$SRC"
for m in drone_wasp drone_lancer drone_sapper; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
    echo "$m.model -> $(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
done
ls -l "$OUT"
