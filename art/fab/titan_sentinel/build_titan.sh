#!/usr/bin/env bash
# Titan Sentinel (Praetor) -> NS2 model on the Exosuit (dual minigun) skeleton, keeping the exo's miniguns.
#   ./build_titan.sh          full run (exo pose, textures, weights, export, compile)
#   ./build_titan.sh export   only export work/titan_rigged.blend + compile (after manual rig edits)
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"
HERE="$MOD/art/fab/titan_sentinel"; WORK="$HERE/work"; EXO="$MOD/art/exo"; SK="$MOD/art/skeleton"; ROB="$MOD/art/robot"
SRC="$MOD/source/modelsrc/vaelthor/titan"; OUT="$MOD/output/models/vaelthor/titan"
GUNPROXY="$MOD/source/modelsrc/marine/exosuit/minigun.tga"
EXOMODEL="$NS2/ns2/models/marine/exosuit/exosuit_mm.model"
TEXBASE="$HERE/Titan_Sentinel_0120121726_texture"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "POSE|SIZE|FIT|FACING|SPLIT|AUTO|ROBOT|JOINED|SAVED|EXPORTED|CHECK|Error|Traceback" | grep -v OpenColorIO || true; }
mkdir -p "$WORK" "$SRC" "$OUT" "$(dirname "$GUNPROXY")"

if [ "${1:-full}" != "export" ]; then
  cp "$TEXBASE.png" "$WORK/bake_albedo.png"; cp "${TEXBASE}_metallic.png" "$WORK/bake_metallic.png"
  cp "${TEXBASE}_roughness.png" "$WORK/bake_roughness.png"; cp "${TEXBASE}_normal.png" "$WORK/bake_normal.png"
  [ -f "$EXO/exo_mm_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$EXOMODEL" "$EXO/exo_mm_reference.blend" "$EXO"
  echo "== T-pose -> exosuit pose"
  B "$HERE/prepare_titan.py" -- "$HERE/Character_output.fbx" "$EXO/exo_mm_reference.blend" "$WORK" "$WORK/titan_exopose.blend" "$WORK"
  echo "== exo skeleton weights + miniguns"
  B "$EXO/rig_exo.py" -- "$EXO/exo_mm_reference.blend" "$WORK/titan_exopose.blend" "$WORK/titan_rigged.blend" "$WORK"
  echo "== textures"
  python3 -I "$ROB/make_ns2_textures.py" "$WORK" "$WORK/tga" titan teal orange
  cd "$WORK/tga"
  wine "$NS2/utils/nvcompress.exe" -bc1 titan.tga "$(w "$OUT/titan.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc3 titan_spec.tga "$(w "$OUT/titan_spec.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -normal -bc1 titan_normal.tga "$(w "$OUT/titan_normal.dds")" >/dev/null 2>&1
  wine "$NS2/utils/nvcompress.exe" -bc1 titan_illum.tga "$(w "$OUT/titan_illum.dds")" >/dev/null 2>&1
  cp "$WORK/tga/titan.tga" "$SRC/titan.tga"     # texture path the FBX material points at
  [ -f "$GUNPROXY" ] || python3 -I -c "from PIL import Image; Image.new('RGB', (4, 4), (90, 90, 95)).save('$GUNPROXY')"
  mkdir -p "$MOD/source/models/vaelthor/titan"
  cat > "$MOD/source/models/vaelthor/titan/titan.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/titan/titan.dds"
normalMap = "models/vaelthor/titan/titan_normal.dds"
emissiveMap = "models/vaelthor/titan/titan_illum.dds"
specularMap = "models/vaelthor/titan/titan_spec.dds"
surface = "metal"
MAT
  cp "$MOD/source/models/vaelthor/titan/titan.material" "$OUT/"
fi

echo "== export FBX"
B "$EXO/export_exo.py" -- "$WORK/titan_rigged.blend" "$SRC/titan_player.fbx" "$SRC/titan.tga" "$GUNPROXY"

echo "== compile"
{
  echo 'geometry "titan_player.fbx"'
  echo 'animation_model "models/marine/exosuit/exosuit_mm.model"'
  echo 'bone_order_override'; echo '{'
  python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$EXOMODEL')[0]): print(i, '\"%s\"' % b['name'])"
  echo '}'
} > "$SRC/titan_player.model_compile"
TMP="$(mktemp -d)"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  titan_player.model_compile "$(w "$TMP/titan_player.model")" 2>&1 | grep -v radv
# hitboxes / ragdoll / attach points (weapon mounts!) from the exo
python3 -I "$SK/splice_marine_chunks.py" "$TMP/titan_player.model" "$EXOMODEL" "$OUT/titan_player.model"
rm -rf "$TMP"
strings -n 8 "$OUT/titan_player.model" | grep "\.material"
