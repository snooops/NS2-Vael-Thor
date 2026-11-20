#!/usr/bin/env bash
# Subject "Stalker" (original Blender model, art/subject/build_stalker.py) -> NS2 player model on the marine skeleton.
#   ./build_stalker.sh            full run (model + bake, textures, rig, export, compile)
#   ./build_stalker.sh export     only export work/stalker_rigged.blend + compile (after manual rig edits)
# Output: output/models/vaelthor/stalker/stalker_player.model, face set 0 = body (stalker.material),
# face set 1 = forearm blades + finger talons (stalker_blades.material, hidden by Client.lua while the claws aren't out).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"
HERE="$MOD/art/subject"; WORK="$HERE/work"; SK="$MOD/art/skeleton"; ROB="$MOD/art/robot"
SRC="$MOD/source/modelsrc/vaelthor/stalker"; OUT="$MOD/output/models/vaelthor/stalker"; MATSRC="$MOD/source/models/vaelthor/stalker"
MARINE="$NS2/ns2/models/marine/male/male.model"
BAKE="${VT_BAKE:-2048}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){  # blender, filtered log; stops the build when the script fails
  local log; log="$(mktemp)"
  if ! blender -b --factory-startup --python-exit-code 1 -P "$@" > "$log" 2>&1; then
    grep -v OpenColorIO "$log" | tail -20; rm -f "$log"; echo "blender step failed: $1"; exit 1
  fi
  grep -E "RIGID|STALKER|BAKED|PREVIEW|FIT|AUTO|ROBOT|SAVED|EXPORTED" "$log" || true; rm -f "$log"
}
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"

if [ "${1:-full}" != "export" ]; then
  echo "== model + bake (${BAKE}px)"
  B "$HERE/build_stalker.py" -- "$WORK" "$BAKE"
  test -f "$WORK/stalker_apose.blend"
  [ -f "$SK/marine_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$MARINE" "$SK/marine_reference.blend"
  echo "== rig (marine skeleton unchanged, automatic weights)"
  VT_NOFIT=1 B "$SK/rig_robot.py" -- "$SK/marine_reference.blend" "$WORK/stalker_apose.blend" "$WORK/stalker_rigged.blend" "$WORK"
  echo "== rigid parts (blades, plates, claws, tail) 100% on their bone"
  B "$SK/apply_rigid_weights.py" -- "$WORK/stalker_rigged.blend"
  echo "== textures"
  python3 -I "$ROB/make_ns2_textures.py" "$WORK" "$WORK/tga" stalker baked
  cd "$WORK/tga"
  wine "$NS2/utils/nvcompress.exe" -bc1 stalker.tga "$(w "$OUT/stalker.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc3 stalker_spec.tga "$(w "$OUT/stalker_spec.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -normal -bc1 stalker_normal.tga "$(w "$OUT/stalker_normal.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc1 stalker_illum.tga "$(w "$OUT/stalker_illum.dds")" >/dev/null 2>&1
  # texture paths the FBX materials point at (they name the two NS2 materials)
  cp "$WORK/tga/stalker.tga" "$SRC/stalker.tga"; cp "$WORK/tga/stalker.tga" "$SRC/stalker_blades.tga"
  for m in stalker stalker_blades; do
    cat > "$MATSRC/$m.material" <<'EOF'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/stalker/stalker.dds"
normalMap = "models/vaelthor/stalker/stalker_normal.dds"
emissiveMap = "models/vaelthor/stalker/stalker_illum.dds"
specularMap = "models/vaelthor/stalker/stalker_spec.dds"
surface = "organic"
EOF
  done
  sed -i 's/surface = "organic"/surface = "metal"/' "$MATSRC/stalker_blades.material"
  cp "$MATSRC/"*.material "$OUT/"
fi

echo "== export FBX (2 material slots -> 2 face sets)"
B "$SK/export_rigged.py" -- "$WORK/stalker_rigged.blend" "$SRC/stalker_player.fbx" "$SRC/stalker.tga" "$SRC/stalker_blades.tga"

echo "== compile"
{
  echo 'geometry "stalker_player.fbx"'
  echo 'animation_model "models/marine/male/male.model"'
  echo 'bone_order_override'; echo '{'
  python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$MARINE')[0]): print(i, '\"%s\"' % b['name'])"
  echo '}'
} > "$SRC/stalker_player.model_compile"
TMP="$(mktemp -d)"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  stalker_player.model_compile "$(w "$TMP/stalker_player.model")" 2>&1 | grep -v radv | tail -5
python3 -I "$SK/splice_marine_chunks.py" "$TMP/stalker_player.model" "$MARINE" "$OUT/stalker_player.model"
rm -rf "$TMP"
strings -n 8 "$OUT/stalker_player.model" | grep "\.material"
ls -l "$OUT"
