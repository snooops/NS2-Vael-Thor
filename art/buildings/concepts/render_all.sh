#!/usr/bin/env bash
# Renders every Vael'Thor building concept (or the ones named) for Tripo image-to-3D.
# Output per building: <name>_transparent.png (alpha) and <name>.png (light grey background).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
blender -b -P "$HERE/make_concepts.py" -- "$HERE" "$@" 2>&1 | grep -E "^rendered|Traceback|Error:" | grep -v OpenColorIO || true
for f in "$HERE"/*_transparent.png; do
    python3 -I -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA')
bg = Image.new('RGBA', im.size, (236, 236, 240, 255)); bg.alpha_composite(im)
bg.convert('RGB').save(sys.argv[2])" "$f" "${f%_transparent.png}.png"
done
