#!/usr/bin/env bash
# Psionic blades (Infiltrator, Zealot style): textures/materials, first-person view model (vanilla axe arms +
# animations, blades on both wrists), invisible weapon world model, and the wrist blades in cyber_player.model.
#   ./build_psi_blades.sh          everything
#   ./build_psi_blades.sh player   only (re)append the blades to output/models/vaelthor/cyber/cyber_player.model
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/weapons"; WORK="$HERE/work_blades"
OUT="$MOD/output/models/vaelthor/blades"; MATSRC="$MOD/source/models/vaelthor/blades"; SRC="$MOD/source/modelsrc/vaelthor/blades"
AXEVIEW="$NS2/ns2/models/marine/axe/axe_view.model"; CYBER="$MOD/output/models/vaelthor/cyber/cyber_player.model"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$OUT" "$MATSRC" "$SRC"
RH=RHand_MiddlBase,RHand_RingBase,RHand_PointrBase,RHand_PinkyBase; LH=LHand_MiddlBase,LHand_RingBase,LHand_PointrBase,LHand_PinkyBase

player() {
  if strings -n 8 "$CYBER" | grep -q "blades/blades.material"; then echo "cyber_player.model already has blades"; return; fi
  python3 -I "$HERE/build_psi_blades.py" "$CYBER" RArm_Wrist01 RArm_Elbow LArm_Wrist02 LArm_Elbow \
    "RArm_Wrist01,$RH" "LArm_Wrist02,$LH" "$WORK/blades_player_tris.json"
  python3 -I "$HERE/append_faceset.py" "$CYBER" "$WORK/blades_player_tris.json" models/vaelthor/blades/blades.material "$CYBER.tmp"
  mv "$CYBER.tmp" "$CYBER"
}
if [ "${1:-all}" = "player" ]; then player; exit 0; fi

echo "== textures"
python3 -I - "$WORK" <<'PY'
import sys, os
from PIL import Image
out = sys.argv[1]; S = 64
def atlas(left, right, mode="RGB"):
    im = Image.new(mode, (S, S))
    for x in range(S):
        for y in range(S):
            im.putpixel((x, y), left if x < S // 2 else right)
    return im
atlas((40, 38, 48), (205, 150, 255)).save(os.path.join(out, "blades.tga"))
atlas((90, 90, 100, 150), (120, 80, 160, 200), "RGBA").save(os.path.join(out, "blades_spec.tga"))
atlas((0, 0, 0), (215, 120, 255)).save(os.path.join(out, "blades_illum.tga"))
Image.new("RGB", (S, S), (128, 128, 255)).save(os.path.join(out, "blades_normal.tga"))
Image.new("RGB", (S, S), (0, 0, 0)).save(os.path.join(out, "blades_hidden_opacity.tga"))
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -bc1 blades.tga "$(w "$OUT/blades.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 blades_spec.tga "$(w "$OUT/blades_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 blades_illum.tga "$(w "$OUT/blades_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 blades_normal.tga "$(w "$OUT/blades_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 blades_hidden_opacity.tga "$(w "$OUT/blades_hidden_opacity.dds")" >/dev/null 2>&1
cat > "$MATSRC/blades.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/blades/blades.dds"
normalMap = "models/vaelthor/blades/blades_normal.dds"
emissiveMap = "models/vaelthor/blades/blades_illum.dds"
specularMap = "models/vaelthor/blades/blades_spec.dds"
surface = "metal"
MAT
cat > "$MATSRC/blades_view.material" <<'MAT'
shader = "shaders/WeaponView_emissive.surface_shader"
albedoMap = "models/vaelthor/blades/blades.dds"
normalMap = "models/vaelthor/blades/blades_normal.dds"
emissiveMap = "models/vaelthor/blades/blades_illum.dds"
specularMap = "models/vaelthor/blades/blades_spec.dds"
darken = 0
MAT
cat > "$MATSRC/blades_hidden.material" <<'MAT'
shader = "shaders/super_emissive.surface_shader"
albedoMap = "models/vaelthor/blades/blades.dds"
emissiveMap = "models/vaelthor/blades/blades_hidden_opacity.dds"
normalMap = "models/vaelthor/blades/blades_normal.dds"
specularMap = "models/vaelthor/blades/blades_spec.dds"
opacityMap = "models/vaelthor/blades/blades_hidden_opacity.dds"
MAT
cp "$MATSRC/"*.material "$OUT/"

echo "== first-person view model"
python3 -I "$HERE/build_psi_blades.py" "$AXEVIEW" RHand_Wrist RArm_Elbow LHand_Wrist LArm_Elbow \
  "RHand_Wrist,$RH" "LHand_Wrist,$LH" "$WORK/blades_view_tris.json"
python3 -I "$HERE/replace_view_weapon.py" "$AXEVIEW" 1 "$WORK/blades_view_tris.json" RHand_Wrist \
  models/vaelthor/blades/blades_view.material "$OUT/blades_view.model"

echo "== invisible weapon world model (the blades live on the player model's wrists)"
cp "$WORK/blades.tga" "$SRC/blades_hidden.tga"
blender -b --factory-startup --python-exit-code 1 --python-expr "
import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new('null'); me.from_pydata([(0,0,0),(0.001,0,0),(0,0,0.001)], [], [(0,1,2)])
uv = me.uv_layers.new(name='UVMap'); me.update()
ob = bpy.data.objects.new('null', me); bpy.context.scene.collection.objects.link(ob)
me.materials.append(bpy.data.materials.new('blades_hidden'))
bpy.ops.wm.save_as_mainfile(filepath='$WORK/blades_null.blend')" >/dev/null 2>&1
blender -b --factory-startup --python-exit-code 1 -P "$HERE/export_static.py" -- "$WORK/blades_null.blend" "$SRC/blades_null.fbx" "$SRC/blades_hidden.tga" 2>&1 | grep -E "EXPORTED|Error"
echo 'geometry "blades_null.fbx"' > "$SRC/blades_null.model_compile"
cd "$SRC" && wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  blades_null.model_compile "$(w "$OUT/blades_null.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true

echo "== player model wrists"
player
for m in blades_view blades_null; do echo "$m:"; strings -n 8 "$OUT/$m.model" | grep "\.material"; done
strings -n 8 "$CYBER" | grep "\.material"
