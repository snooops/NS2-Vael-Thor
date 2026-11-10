#!/usr/bin/env bash
# Tripo GLB -> static NS2 Vael'Thor building: output/models/vaelthor/<name>/<name>.model (+ material, DDS, collision)
# Usage: build_building.sh <name> <in.glb> <height_m> <target_tris> <collision_bands>
#   collision: "auto:<slice_m>[:<clear_radius_m>]" (model-following hulls) or legacy height bands "0-0.15,0.13-1"
# Writes a preview render to art/buildings/work/<name>/<name>_preview.png
set -euo pipefail
NAME="$1"; GLB="$(realpath "$2")"; HEIGHT="$3"; TRIS="$4"; BANDS="$5"
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/buildings"; WORK="$HERE/work/$NAME"
SRC="$MOD/source/modelsrc/vaelthor/$NAME"; OUT="$MOD/output/models/vaelthor/$NAME"
MATSRC="$MOD/source/models/vaelthor/$NAME"; SK="$MOD/art/skeleton"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
B(){ blender -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "TRIS|SIZE|HULL|SAVED|EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColorIO || true; }
mkdir -p "$WORK/tga" "$SRC" "$OUT" "$MATSRC"

echo "== textures"
rm -f "$WORK"/basecolor.* "$WORK"/rm.* "$WORK"/normal.*     # always from the current GLB
B "$HERE/extract_textures.py" -- "$GLB" "$WORK"
python3 -I "$HERE/make_building_textures.py" "$(ls "$WORK"/basecolor.*)" "$(ls "$WORK"/rm.*)" "$(ls "$WORK"/normal.*)" \
    "$WORK/tga" "$NAME" 2048
cd "$WORK/tga"
wine "$NS2/utils/nvcompress.exe" -bc1 "$NAME.tga" "$(w "$OUT/$NAME.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc3 "${NAME}_spec.tga" "$(w "$OUT/${NAME}_spec.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -normal -bc1 "${NAME}_normal.tga" "$(w "$OUT/${NAME}_normal.dds")" >/dev/null 2>&1
wine "$NS2/utils/nvcompress.exe" -bc1 "${NAME}_illum.tga" "$(w "$OUT/${NAME}_illum.dds")" >/dev/null 2>&1
cp "$NAME.tga" "$SRC/$NAME.tga"     # texture path the FBX material points at -> models/vaelthor/<name>/<name>.material
cat > "$MATSRC/$NAME.material" <<MAT
shader = "models/marine/marine.surface_shader"
surface = "metal"
albedoMap = "models/vaelthor/$NAME/$NAME.dds"
normalMap = "models/vaelthor/$NAME/${NAME}_normal.dds"
emissiveMap = "models/vaelthor/$NAME/${NAME}_illum.dds"
specularMap = "models/vaelthor/$NAME/${NAME}_spec.dds"
MAT
cp "$MATSRC/$NAME.material" "$OUT/"

echo "== mesh + collision"
B "$HERE/prepare_building.py" -- "$GLB" "$SRC" "$NAME" "$SRC/$NAME.tga" "$HEIGHT" "$TRIS" "$BANDS"
printf 'geometry "%s.fbx"\nphysics "%s_physics.fbx"\n' "$NAME" "$NAME" > "$SRC/$NAME.model_compile"

echo "== compile"
cd "$SRC"
wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
  "$NAME.model_compile" "$(w "$OUT/$NAME.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
# Solids must be bone-relative (engine: bone_world * solid); CompileModel writes them in model space and the root
# bone has a bind rotation, which put every hitbox on its side in-game.
python3 -I "$HERE/fix_solid_space.py" "$OUT/$NAME.model"
python3 -I -c "
import sys; sys.path.insert(0, '$SK'); import ns2_model as m
import struct
d = open('$OUT/$NAME.model', 'rb').read(); ch = m.chunks(d)
assert 5 in ch, 'no collision chunk (5) - physics import failed'
s = ch[5][0]; n = struct.unpack_from('<I', d, s)[0]; o = s + 4; bones = []
ln = struct.unpack_from('<I', d, o)[0]; bones.append(struct.unpack_from('<i', d, o + 4 + ln)[0])
assert bones[0] == 0, 'collision solids not bound to the root bone (%d)' % bones[0]
print('collision ok: %d solids on bone 0, %d bones' % (n, struct.unpack_from('<I', d, ch[6][0])[0]))"
strings -n 8 "$OUT/$NAME.model" | grep "\.material"

echo "== preview"
B "$HERE/preview_building.py" -- "$SRC/${NAME}_prepared.blend" "$NAME" "$WORK/tga" "$WORK/${NAME}_preview.png"
