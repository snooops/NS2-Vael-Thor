#!/usr/bin/env bash
# Subject claws: knuckle plate + three curved claws per hand (build_psi_blades.py style "claws").
# First person = vanilla axe arms/animations (replace_view_weapon.py), third person = face set on mecha_player.model.
# The weapon world model (blades_null.model) and the hiding material come from build_psi_blades.sh.
#   ./build_subject_claws.sh          everything
#   ./build_subject_claws.sh player   only (re)append the claws to output/models/vaelthor/mecha/mecha_player.model
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/weapons"; WORK="$HERE/work_claws"
OUT="$MOD/output/models/vaelthor/claws"; MATSRC="$MOD/source/models/vaelthor/claws"
AXEVIEW="$NS2/ns2/models/marine/axe/axe_view.model"; MECHA="$MOD/output/models/vaelthor/mecha/mecha_player.model"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$OUT" "$MATSRC"
RH=RHand_MiddlBase,RHand_RingBase,RHand_PointrBase,RHand_PinkyBase; LH=LHand_MiddlBase,LHand_RingBase,LHand_PointrBase,LHand_PinkyBase

player() {
  if strings -n 8 "$MECHA" | grep -q "claws/claws.material"; then echo "mecha_player.model already has claws"; return; fi
  python3 -I "$HERE/build_psi_blades.py" "$MECHA" RArm_Wrist01 RArm_Elbow LArm_Wrist02 LArm_Elbow \
    "RArm_Wrist01,$RH" "LArm_Wrist02,$LH" "$WORK/claws_player_tris.json" claws
  python3 -I "$HERE/append_faceset.py" "$MECHA" "$WORK/claws_player_tris.json" models/vaelthor/claws/claws.material "$MECHA.tmp"
  mv "$MECHA.tmp" "$MECHA"
}
if [ "${1:-all}" = "player" ]; then player; exit 0; fi

echo "== textures (atlas: knuckle plate | claw steel)"
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
atlas((34, 30, 40), (120, 108, 150)).save(os.path.join(out, "claws.tga"))
atlas((80, 80, 90, 140), (170, 160, 200, 220), "RGBA").save(os.path.join(out, "claws_spec.tga"))
atlas((0, 0, 0), (70, 25, 110)).save(os.path.join(out, "claws_illum.tga"))
Image.new("RGB", (S, S), (128, 128, 255)).save(os.path.join(out, "claws_normal.tga"))
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -bc1 claws.tga "$(w "$OUT/claws.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 claws_spec.tga "$(w "$OUT/claws_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 claws_illum.tga "$(w "$OUT/claws_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 claws_normal.tga "$(w "$OUT/claws_normal.dds")" >/dev/null 2>&1
cat > "$MATSRC/claws.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/claws/claws.dds"
normalMap = "models/vaelthor/claws/claws_normal.dds"
emissiveMap = "models/vaelthor/claws/claws_illum.dds"
specularMap = "models/vaelthor/claws/claws_spec.dds"
surface = "metal"
MAT
cat > "$MATSRC/claws_view.material" <<'MAT'
shader = "shaders/WeaponView_emissive.surface_shader"
albedoMap = "models/vaelthor/claws/claws.dds"
normalMap = "models/vaelthor/claws/claws_normal.dds"
emissiveMap = "models/vaelthor/claws/claws_illum.dds"
specularMap = "models/vaelthor/claws/claws_spec.dds"
darken = 0
MAT
cp "$MATSRC/"*.material "$OUT/"

echo "== first-person view model"
python3 -I "$HERE/build_psi_blades.py" "$AXEVIEW" RHand_Wrist RArm_Elbow LHand_Wrist LArm_Elbow \
  "RHand_Wrist,$RH" "LHand_Wrist,$LH" "$WORK/claws_view_tris.json" claws
python3 -I "$HERE/replace_view_weapon.py" "$AXEVIEW" 1 "$WORK/claws_view_tris.json" RHand_Wrist \
  models/vaelthor/claws/claws_view.material "$OUT/claws_view.model"

echo "== player model wrists"
player
strings -n 8 "$OUT/claws_view.model" | grep "\.material"; strings -n 8 "$MECHA" | grep "\.material"
