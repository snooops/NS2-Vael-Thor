#!/usr/bin/env bash
# Sentinel Obelisk beam texture + material -> output/models/vaelthor/beam/
# The beam is drawn as flat strips (DynamicMesh_SetLine: U across the strip, V along it). The vanilla
# ui/laser.material is pure red and lit only in a 1-3 px line of its 64 px width, so on our strip it showed a
# ~5 mm dark-red hairline (invisible in practice). This texture is violet in itself (works whether or not the
# Emissive shader uses vertex colours): bright pink-white core, violet glow over the full width, black edges
# (Emissive is additive: black = transparent). Shader Emissive needs only emissiveMap (same as vanilla laser).
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; WORK="$MOD/art/effects/work_beam"; OUT="$MOD/output/models/vaelthor/beam"
SRC="$MOD/source/models/vaelthor/beam"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
mkdir -p "$WORK" "$OUT" "$SRC"
python3 -I - "$WORK/obelisk_beam.tga" <<'PY'
import sys, math
from PIL import Image
W, H = 64, 128
img = Image.new("RGB", (W, H))
for x in range(W):
    u = (x + 0.5) / W * 2 - 1                     # -1 .. 1 across the strip
    glow = math.exp(-(u / 0.55) ** 2)             # wide violet glow
    core = math.exp(-(u / 0.16) ** 2)             # bright core
    edge = max(0.0, 1 - abs(u) ** 6)              # fade to black at the very edge
    r = (150 * glow + 255 * core) * edge
    g = (60 * glow + 215 * core) * edge
    b = (255 * glow + 255 * core) * edge
    for y in range(H):
        img.putpixel((x, y), (min(255, int(r)), min(255, int(g)), min(255, int(b))))
img.save(sys.argv[1]); print("wrote", sys.argv[1])
PY
wine "$NS2/utils/nvcompress.exe" -rgb "$WORK/obelisk_beam.tga" "$(w "$OUT/obelisk_beam.dds")" >/dev/null 2>&1
cat > "$SRC/obelisk_beam.material" <<'MAT'
shader = "shaders/Emissive.surface_shader"
emissiveMap = "models/vaelthor/beam/obelisk_beam.dds"
MAT
cp "$SRC/obelisk_beam.material" "$OUT/"
grep -q '^emissiveMap' "$OUT/obelisk_beam.material"
ls -l "$OUT"
