#!/usr/bin/env bash
# Psionic Knife (Vanguard melee): procedural model in the vanilla axe's world + view frames.
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/weapons"; WORK="$HERE/work_knife"; SK="$MOD/art/skeleton"
SRC="$MOD/source/modelsrc/vaelthor/knife"; OUT="$MOD/output/models/vaelthor/knife"; MATSRC="$MOD/source/models/vaelthor/knife"
HANDSPROXY="$MOD/source/modelsrc/marine/hands/hands.tga"
AXE="$NS2/ns2/models/marine/axe/axe.model"; AXEVIEW="$NS2/ns2/models/marine/axe/axe_view.model"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "SAVED|JOINED|EXPORTED|TRIS|Error|Traceback" | grep -v OpenColorIO || true; }
order(){ python3 -I -c "
import sys; sys.path.insert(0, '$SK')
from ns2_model import read_bones
for i, b in enumerate(read_bones('$1')[0]): print(i, '\"%s\"' % b['name'])"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC" "$(dirname "$HANDSPROXY")"

echo "== textures (atlas: steel | psionic glow | grip | guard)"
python3 -I - "$WORK" <<'PY'
import sys, os
from PIL import Image
out = sys.argv[1]; S = 128
regions = [  # albedo, spec rgb, gloss, emissive
    ((92, 96, 108),  (150, 155, 165), 210, (0, 0, 0)),        # blade steel
    ((150, 60, 255), (60, 30, 90),    120, (170, 70, 255)),   # psionic glow
    ((18, 17, 22),   (20, 20, 24),     60, (0, 0, 0)),        # grip
    ((42, 42, 50),   (90, 90, 100),   160, (0, 0, 0)),        # guard / pommel
]
alb = Image.new("RGB", (S, S)); spec = Image.new("RGBA", (S, S)); emis = Image.new("RGB", (S, S))
for i, (a, sp, g, e) in enumerate(regions):
    for x in range(i * S // 4, (i + 1) * S // 4):
        for y in range(S):
            alb.putpixel((x, y), a); spec.putpixel((x, y), sp + (g,)); emis.putpixel((x, y), e)
alb.save(os.path.join(out, "knife.tga")); spec.save(os.path.join(out, "knife_spec.tga"))
emis.save(os.path.join(out, "knife_illum.tga")); Image.new("RGB", (S, S), (128, 128, 255)).save(os.path.join(out, "knife_normal.tga"))
PY
cd "$WORK"
wine "$NS2/utils/nvcompress.exe" -rgb knife.tga "$(w "$OUT/knife.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb knife_spec.tga "$(w "$OUT/knife_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -rgb knife_illum.tga "$(w "$OUT/knife_illum.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -rgb knife_normal.tga "$(w "$OUT/knife_normal.dds")" >/dev/null 2>&1
cp knife.tga "$SRC/knife.tga"; cp knife.tga "$SRC/knife_view.tga"
[ -f "$HANDSPROXY" ] || python3 -I -c "from PIL import Image; Image.new('RGB', (4, 4), (120, 110, 100)).save('$HANDSPROXY')"
cat > "$MATSRC/knife.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/knife/knife.dds"
normalMap = "models/vaelthor/knife/knife_normal.dds"
emissiveMap = "models/vaelthor/knife/knife_illum.dds"
specularMap = "models/vaelthor/knife/knife_spec.dds"
surface = "metal"
MAT
cat > "$MATSRC/knife_view.material" <<'MAT'
shader = "shaders/WeaponView_emissive.surface_shader"
albedoMap = "models/vaelthor/knife/knife.dds"
normalMap = "models/vaelthor/knife/knife_normal.dds"
emissiveMap = "models/vaelthor/knife/knife_illum.dds"
specularMap = "models/vaelthor/knife/knife_spec.dds"
darken = 0
MAT
cp "$MATSRC/knife.material" "$MATSRC/knife_view.material" "$OUT/"

echo "== models"
[ -f "$HERE/axe_view_reference.blend" ] || B "$SK/import_ns2_marine.py" -- "$AXEVIEW" "$HERE/axe_view_reference.blend"
B "$HERE/build_knife.py" -- "$HERE/axe_view_reference.blend" "$WORK/knife_world.blend" "$WORK/knife_view.blend" "$WORK"
B "$HERE/export_static.py" -- "$WORK/knife_world.blend" "$SRC/knife.fbx" "$SRC/knife.tga"
echo 'geometry "knife.fbx"' > "$SRC/knife.model_compile"

echo "== compile"
TMP="$(mktemp -d)"; cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  knife.model_compile "$(w "$TMP/knife.model")" 2>&1 | grep -v radv | grep -E "Num|rror" || true
python3 -I "$SK/splice_marine_chunks.py" "$TMP/knife.model" "$AXE" "$OUT/knife.model"
rm -rf "$TMP"
# View model: the vanilla axe_view.model with only the axe geometry swapped for the knife. The arms keep their
# exact bind pose incl. the 0.849 shoulder scale, which a Blender round trip loses (-> stretched fingers).
python3 -I "$HERE/replace_view_weapon.py" "$AXEVIEW" 1 "$WORK/knife_view_tris.json" axe_root_bone \
  models/vaelthor/knife/knife_view.material "$OUT/knife_view.model"
"$HERE/build_vanguard_view_arms.sh" knife    # Vanguard's own arms instead of the marine arms
for m in knife knife_view; do echo "$m:"; strings -n 8 "$OUT/$m.model" | grep "\.material"; done
