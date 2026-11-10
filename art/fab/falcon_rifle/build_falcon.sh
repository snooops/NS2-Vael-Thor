#!/usr/bin/env bash
# Falcon Rilfe (Vanguard Plasma Carbine): third-person world model + first-person view model.
# "Falcon Rilfe" by pocolov, CC-BY-4.0 - see license.txt and the mod's CREDITS.txt.
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"
HERE="$MOD/art/fab/falcon_rifle"; WORK="$HERE/work"; WPN="$MOD/art/weapons"; SK="$MOD/art/skeleton"; ROB="$MOD/art/robot"
SRC="$MOD/source/modelsrc/vaelthor/falcon"; OUT="$MOD/output/models/vaelthor/falcon"; MATSRC="$MOD/source/models/vaelthor/falcon"
HANDSPROXY="$MOD/source/modelsrc/marine/hands/hands.tga"
RIFLE="$NS2/ns2/models/marine/rifle/rifle.model"; RIFLEVIEW="$NS2/ns2/models/marine/rifle/rifle_view.model"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "FALCON|HANDS|JOINED|SAVED|EXPORTED|Error|Traceback" | grep -v OpenColorIO || true; }
order(){ python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$1')[0]): print(i, '\"%s\"' % b['name'])"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC" "$(dirname "$HANDSPROXY")"

echo "== textures"
python3 -I "$HERE/make_falcon_bakes.py" "$HERE/textures/01___Default_baseColor.jpeg" "$WORK"
python3 -I "$ROB/make_ns2_textures.py" "$WORK" "$WORK/tga" falcon accent
cd "$WORK/tga"
wine "$NS2/utils/nvcompress.exe" -bc1 falcon.tga "$(w "$OUT/falcon.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 falcon_spec.tga "$(w "$OUT/falcon_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 falcon_normal.tga "$(w "$OUT/falcon_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 falcon_illum.tga "$(w "$OUT/falcon_illum.dds")" >/dev/null 2>&1
cp falcon.tga "$SRC/falcon.tga"; cp falcon.tga "$SRC/falcon_view.tga"     # material names for CompileModel
[ -f "$HANDSPROXY" ] || python3 -I -c "from PIL import Image; Image.new('RGB', (4, 4), (120, 110, 100)).save('$HANDSPROXY')"
cat > "$MATSRC/falcon.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/falcon/falcon.dds"
normalMap = "models/vaelthor/falcon/falcon_normal.dds"
emissiveMap = "models/vaelthor/falcon/falcon_illum.dds"
specularMap = "models/vaelthor/falcon/falcon_spec.dds"
surface = "metal"
MAT
cat > "$MATSRC/falcon_view.material" <<'MAT'
shader = "shaders/WeaponView_emissive.surface_shader"
albedoMap = "models/vaelthor/falcon/falcon.dds"
normalMap = "models/vaelthor/falcon/falcon_normal.dds"
emissiveMap = "models/vaelthor/falcon/falcon_illum.dds"
specularMap = "models/vaelthor/falcon/falcon_spec.dds"
darken = 0
MAT
cp "$MATSRC/falcon.material" "$MATSRC/falcon_view.material" "$OUT/"

echo "== world model"
[ -f "$WPN/rifle_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$RIFLE" "$WPN/rifle_reference.blend"
B "$WPN/build_falcon_world.py" -- "$WPN/rifle_reference.blend" "$HERE/scene.gltf" "$WORK/falcon_world.blend" "$WORK"
B "$WPN/export_multi.py" -- "$WORK/falcon_world.blend" "$SRC/falcon.fbx" "$SRC/falcon.tga"
{ echo 'geometry "falcon.fbx"'; echo 'bone_order_override'; echo '{'; order "$RIFLE"; echo '}'; } > "$SRC/falcon.model_compile"

echo "== view model"
[ -f "$WPN/rifle_view_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$RIFLEVIEW" "$WPN/rifle_view_reference.blend"
B "$WPN/build_falcon_view.py" -- "$WPN/rifle_view_reference.blend" "$HERE/scene.gltf" "$WORK/falcon_view.blend" "$WORK"
B "$WPN/export_multi.py" -- "$WORK/falcon_view.blend" "$SRC/falcon_view.fbx" "$HANDSPROXY" "$SRC/falcon_view.tga"
{ echo 'geometry "falcon_view.fbx"'; echo 'animation_model "models/marine/rifle/rifle_view.model"'
  echo 'bone_order_override'; echo '{'; order "$RIFLEVIEW"; echo '}'; } > "$SRC/falcon_view.model_compile"

echo "== compile"
TMP="$(mktemp -d)"
cd "$SRC"
for m in falcon falcon_view; do
  wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
    $m.model_compile "$(w "$TMP/$m.model")" 2>&1 | grep -v radv | grep -E "Num|rror|arn" || true
done
python3 -I "$SK/splice_marine_chunks.py" "$TMP/falcon.model" "$RIFLE" "$OUT/falcon.model"
python3 -I "$SK/splice_marine_chunks.py" "$TMP/falcon_view.model" "$RIFLEVIEW" "$OUT/falcon_view.model"
"$MOD/art/weapons/build_vanguard_view_arms.sh" carbine    # Vanguard's own arms instead of the marine arms
rm -rf "$TMP"
for m in falcon falcon_view; do echo "$m:"; strings -n 8 "$OUT/$m.model" | grep "\.material"; done
