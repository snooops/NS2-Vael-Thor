#!/usr/bin/env bash
# Warp field (the singularity a Vael'Thor building warps in from) -> output/models/vaelthor/warp/
#   warp_core.model  black event horizon sphere          warp_core.material  (marine shader, all maps black)
#   warp_halo.model  billboard: white photon ring + blue  warp_halo.material  (additive Emissive)
#   warp_disk.model  accretion disk, blue/white streaks   warp_disk.material  (additive Emissive)
# Drawn, scaled and spun by lua/VaelThor/VTBuildingAnim.lua. Geometry: build_warp.py. Preview: work_warp/preview.png
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
HERE="$(cd "$(dirname "$0")" && pwd)"; MOD="$(cd "$HERE/../.." && pwd)"; WORK="$HERE/work_warp"
SRC="$MOD/source/modelsrc/vaelthor/warp"; OUT="$MOD/output/models/vaelthor/warp"; MATSRC="$MOD/source/models/vaelthor/warp"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$SRC" "$OUT" "$MATSRC"

echo "== textures"
python3 -I - "$WORK" <<'PY'
import sys, os, math, random
import numpy as np
from PIL import Image
out = sys.argv[1]
def save(a, name):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, name))
    print("wrote", name)

# halo: radius in horizon units, square half-size 2.4
S = 512; H = 2.4
y, x = np.mgrid[0:S, 0:S]
r = np.hypot((x + 0.5) / S * 2 - 1, (y + 0.5) / S * 2 - 1) * H
ring = np.exp(-((r - 1.04) / 0.045) ** 2)                          # white-hot photon ring just outside the hole
glow = np.exp(-np.maximum(r - 1.0, 0) / 0.32) * (r > 0.98)          # blue glow falling outward
outer = np.clip(1 - (r / H) ** 4, 0, 1)                             # reaches black before the square's edge
white = np.array([1.0, 1.0, 1.0]); blue = np.array([0.30, 0.55, 1.0])
halo = (ring[..., None] * white + 0.75 * glow[..., None] * blue) * outer[..., None]
save(halo, "warp_halo.tga")

# disk: u = angle (512), v = radius inner -> outer (128); streaks that bend with the radius (spiral look)
W, Hd = 512, 128
v, u = np.mgrid[0:Hd, 0:W]
v = (v + 0.5) / Hd; u = (u + 0.5) / W
rng = np.random.default_rng(3)
streak = np.zeros_like(u)
for k in range(14):
    f = int(rng.integers(3, 18)); ph = rng.uniform(0, 2 * np.pi); tw = rng.uniform(1.5, 4.0)
    streak += np.maximum(0, np.sin(2 * np.pi * f * u + ph + tw * v * 2 * np.pi)) ** 6 * rng.uniform(0.3, 1.0)
streak = 0.35 + 0.65 * streak / streak.max()
fall = np.exp(-v / 0.28) * np.clip(v / 0.04, 0, 1) * np.clip((1 - v) / 0.25, 0, 1)   # bright inner edge
mix = np.clip(v * 1.6, 0, 1)[..., None]
col = (1 - mix) * np.array([0.95, 0.97, 1.0]) + mix * np.array([0.15, 0.40, 1.0])
disk = col * (fall * streak)[..., None] * 1.1
save(disk[::-1], "warp_disk.tga")          # image top = v 1 (outer edge), like missile_flame

save(np.zeros((8, 8, 3)), "warp_core.tga")
save(np.zeros((8, 8, 3)), "warp_core_spec.tga")
save(np.zeros((8, 8, 3)), "warp_core_illum.tga")
n = np.zeros((8, 8, 3)); n[:] = (0.5, 0.5, 1.0); save(n, "warp_core_normal.tga")
PY
cd "$WORK"
for t in warp_halo warp_disk warp_core warp_core_spec warp_core_illum; do
    wine "$NS2/utils/nvcompress.exe" -rgb $t.tga "$(w "$OUT/$t.dds")" >/dev/null 2>&1
done
wine "$NS2/utils/nvcompress.exe" -normal -rgb warp_core_normal.tga "$(w "$OUT/warp_core_normal.dds")" >/dev/null 2>&1
cp warp_halo.tga warp_disk.tga warp_core.tga "$SRC/"     # texture proxies: CompileModel derives the material paths

cat > "$MATSRC/warp_core.material" <<'MAT'
shader = "models/marine/marine.surface_shader"
albedoMap = "models/vaelthor/warp/warp_core.dds"
normalMap = "models/vaelthor/warp/warp_core_normal.dds"
emissiveMap = "models/vaelthor/warp/warp_core_illum.dds"
specularMap = "models/vaelthor/warp/warp_core_spec.dds"
surface = "metal"
MAT
for m in warp_halo warp_disk; do
    printf 'shader = "shaders/Emissive.surface_shader"\nemissiveMap = "models/vaelthor/warp/%s.dds"\n' "$m" > "$MATSRC/$m.material"
done
cp "$MATSRC"/*.material "$OUT/"

echo "== geometry"
blender -b --factory-startup --python-exit-code 1 -P "$HERE/build_warp.py" -- "$SRC" "$WORK/preview.png" 2>&1 \
    | grep -E "EXPORTED|PREVIEW|Error|Traceback" | grep -v OpenColor || true

echo "== compile"
cd "$SRC"
for m in warp_core warp_halo warp_disk; do
    echo "geometry \"$m.fbx\"" > "$m.model_compile"
    wine "$NS2/x64/CompileModel.exe" -verbose -material_src "$MOD/source/modelsrc/" -material_dst models \
        "$m.model_compile" "$(w "$OUT/$m.model")" 2>&1 | grep -v radv | grep -E "Num faces|rror" || true
    mat="$(strings -n 8 "$OUT/$m.model" | grep '\.material' | tr '\n' ' ')"
    echo "$m.model -> $mat"
    [ -n "$mat" ] || { echo "ERROR: $m.model has no material (FBX without texture?)"; exit 1; }
done
ls -l "$OUT"
