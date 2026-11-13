#!/usr/bin/env bash
# Vael'Thor ready room sign: a 3D "VAEL'THOR" model replacing the vanilla "MARINES" sign props
# (VTPalette.lua hides those and places this model at their coords while team 1 is the Vael'Thor).
# -> output/models/vaelthor/signs/vt_join_sign.model (+ .material, .dds)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; MOD="$(cd "$HERE/../../.." && pwd)"
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
FONT="$NS2/core/fonts/MicrogrammaDBolExt.TTF"
SRC="$MOD/source/modelsrc/vaelthor/signs"; MATSRC="$MOD/source/models/vaelthor/signs"; OUT="$MOD/output/models/vaelthor/signs"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$SRC" "$MATSRC" "$OUT"

echo "== texture"
python3 -I "$HERE/make_sign_texture.py" "$NS2" "$SRC/vt_join_sign.tga"
wine "$NS2/utils/nvcompress.exe" -bc1 "$(w "$SRC/vt_join_sign.tga")" "$(w "$OUT/vt_join_sign.dds")" >/dev/null 2>&1
cat > "$MATSRC/vt_join_sign.material" <<'MAT'
shader = "shaders/Emissive.surface_shader"
emissiveMap = "models/vaelthor/signs/vt_join_sign.dds"
normalMap = "materials/dev/dev_normal.dds"
surface = "thin_metal"
MAT
cp "$MATSRC/vt_join_sign.material" "$OUT/"

echo "== model"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_join_sign.py" -- "$FONT" "$SRC/vt_join_sign.tga" \
  "$SRC/vt_join_sign.fbx" "VAEL'THOR" 2>&1 | grep -E "SIZE|EXPORTED|Error|Traceback" | grep -v OpenColorIO || true
echo 'geometry "vt_join_sign.fbx"' > "$SRC/vt_join_sign.model_compile"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  vt_join_sign.model_compile "$(w "$OUT/vt_join_sign.model")" 2>&1 | grep -v radv | grep -E "Num|rror" || true
strings -n 8 "$OUT/vt_join_sign.model" | grep "\.material"
ls -l "$OUT"
