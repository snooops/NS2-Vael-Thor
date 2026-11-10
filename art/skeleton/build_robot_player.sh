#!/usr/bin/env bash
# Rigged robot player model: marine skeleton + robot mesh -> output/models/vaelthor/robot/robot_player.model
# Usage:
#   ./build_robot_player.sh          full run: re-import marine, fit skeleton, auto-weight, export, compile
#   ./build_robot_player.sh export   only export robot_rigged.blend + compile (use after editing the rig by hand)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"
SK="$MOD/art/skeleton"; SRC="$MOD/source/modelsrc/vaelthor/robot"; OUT="$MOD/output/models/vaelthor/robot"
MARINE="$NS2/ns2/models/marine/male/male.model"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "FIT|AUTO|ROBOT|SAVED|EXPORTED|CHECK|Error|Traceback" | grep -v OpenColorIO || true; }
mkdir -p "$SRC" "$OUT"

if [ "${1:-full}" != "export" ]; then
  echo "== import marine reference"
  B "$SK/import_ns2_marine.py" -- "$MARINE" "$SK/marine_reference.blend"
  echo "== fit skeleton + weights"
  B "$SK/rig_robot.py" -- "$SK/marine_reference.blend" "$MOD/art/robot/robot_lowpoly.blend" "$SK/robot_rigged.blend" "$SK"
fi

echo "== export FBX"
B "$SK/export_rigged.py" -- "$SK/robot_rigged.blend" "$SRC/robot_player.fbx" "$SRC/robot.tga"

echo "== model_compile (marine bone order + marine animations)"
{
  echo 'geometry "robot_player.fbx"'
  echo 'animation_model "models/marine/male/male.model"'
  echo 'bone_order_override'; echo '{'
  python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$MARINE')[0]): print(i, '\"%s\"' % b['name'])"
  echo '}'
} > "$SRC/robot_player.model_compile"

echo "== compile"
TMP="$(mktemp -d)"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  robot_player.model_compile "$(w "$TMP/robot_player.model")" 2>&1 | grep -v radv
echo "== add marine hitboxes / ragdoll / attach points"
python3 -I "$SK/splice_marine_chunks.py" "$TMP/robot_player.model" "$MARINE" "$OUT/robot_player.model"
rm -rf "$TMP"
