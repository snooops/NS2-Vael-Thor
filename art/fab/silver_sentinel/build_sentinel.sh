#!/usr/bin/env bash
# Silver Sentinel -> NS2 player model rigged to the marine skeleton.
#   ./build_sentinel.sh          full run (A-pose, textures, fit + weights, export, compile)
#   ./build_sentinel.sh export   only export work/sentinel_rigged.blend + compile (after manual rig edits)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"
HERE="$MOD/art/fab/silver_sentinel"; WORK="$HERE/work"; SK="$MOD/art/skeleton"; ROB="$MOD/art/robot"
SRC="$MOD/source/modelsrc/vaelthor/sentinel"; OUT="$MOD/output/models/vaelthor/sentinel"
MARINE="$NS2/ns2/models/marine/male/male.model"
TEXBASE="$HERE/Silver_Sentinel_0123153528_texture_fbx/Silver_Sentinel_0123153528_texture"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "POSE|SIZE|FIT|FACING|AUTO|ROBOT|SAVED|EXPORTED|CHECK|Error|Traceback" | grep -v OpenColorIO || true; }
mkdir -p "$WORK" "$SRC" "$OUT"

if [ "${1:-full}" != "export" ]; then
  cp "$TEXBASE.png" "$WORK/bake_albedo.png"; cp "${TEXBASE}_metallic.png" "$WORK/bake_metallic.png"
  cp "${TEXBASE}_roughness.png" "$WORK/bake_roughness.png"; cp "${TEXBASE}_normal.png" "$WORK/bake_normal.png"
  [ -f "$SK/marine_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$MARINE" "$SK/marine_reference.blend"
  echo "== T-pose -> marine A-pose"
  B "$HERE/prepare_sentinel.py" -- "$HERE/biped/Character_output.fbx" "$SK/marine_reference.blend" "$WORK" "$WORK/sentinel_apose.blend" "$WORK"
  echo "== fit marine skeleton + weights"
  VT_NOFIT=1 B "$SK/rig_robot.py" -- "$SK/marine_reference.blend" "$WORK/sentinel_apose.blend" "$WORK/sentinel_rigged.blend" "$WORK"
  echo "== textures"
  python3 -I "$ROB/make_ns2_textures.py" "$WORK" "$WORK/tga" sentinel purple
  cd "$WORK/tga"
  wine "$NS2/utils/nvcompress.exe" -bc1 sentinel.tga "$(w "$OUT/sentinel.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc3 sentinel_spec.tga "$(w "$OUT/sentinel_spec.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -normal -bc1 sentinel_normal.tga "$(w "$OUT/sentinel_normal.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc1 sentinel_illum.tga "$(w "$OUT/sentinel_illum.dds")" >/dev/null 2>&1
  cp "$WORK/tga/sentinel.tga" "$SRC/sentinel.tga"   # texture path the FBX material points at
  mkdir -p "$MOD/source/models/vaelthor/sentinel"
  cat > "$MOD/source/models/vaelthor/sentinel/sentinel.material" <<'EOF'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/sentinel/sentinel.dds"
normalMap = "models/vaelthor/sentinel/sentinel_normal.dds"
emissiveMap = "models/vaelthor/sentinel/sentinel_illum.dds"
specularMap = "models/vaelthor/sentinel/sentinel_spec.dds"
surface = "metal"
EOF
  cp "$MOD/source/models/vaelthor/sentinel/sentinel.material" "$OUT/"
fi

echo "== export FBX"
B "$SK/export_rigged.py" -- "$WORK/sentinel_rigged.blend" "$SRC/sentinel_player.fbx" "$SRC/sentinel.tga"

echo "== compile"
{
  echo 'geometry "sentinel_player.fbx"'
  echo 'animation_model "models/marine/male/male.model"'
  echo 'bone_order_override'; echo '{'
  python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$MARINE')[0]): print(i, '\"%s\"' % b['name'])"
  echo '}'
} > "$SRC/sentinel_player.model_compile"
TMP="$(mktemp -d)"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  sentinel_player.model_compile "$(w "$TMP/sentinel_player.model")" 2>&1 | grep -v radv
python3 -I "$SK/splice_marine_chunks.py" "$TMP/sentinel_player.model" "$MARINE" "$OUT/sentinel_player.model"
rm -rf "$TMP"
strings -n 8 "$OUT/sentinel_player.model" | grep "\.material"
