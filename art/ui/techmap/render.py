import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from layout import NODES, EDGES, YSTART
from PIL import Image, ImageDraw
S = 56
img = Image.new('RGB', (15*S, 15*S), (20, 16, 28)); d = ImageDraw.Draw(img)
pos = {n: (x, y + YSTART) for n, x, y in NODES}
assert len(pos) == len(NODES)
for a, b in EDGES:
    (x1, y1), (x2, y2) = pos[a], pos[b]
    d.line([((x1+.5)*S, (y1+.5)*S), ((x2+.5)*S, (y2+.5)*S)], fill=(170, 110, 255), width=2)
for n, (x, y) in pos.items():
    d.rectangle([x*S, y*S, x*S+S-2, y*S+S-2], fill=(60, 40, 90), outline=(220, 200, 255))
    label = n[2:].replace("Upgrade", "").replace("Tech", "")
    for i in range(0, len(label), 8):
        d.text((x*S+3, y*S+3+i//8*11), label[i:i+8], fill=(255, 255, 255))
# overlap check
items = list(pos.items())
for i in range(len(items)):
    for j in range(i+1, len(items)):
        (a, (x1, y1)), (b, (x2, y2)) = items[i], items[j]
        if abs(x1-x2) < 1 and abs(y1-y2) < 1: print("OVERLAP", a, b)
print("max x", max(x for x, y in pos.values())+1, "max y", max(y for x, y in pos.values())+1)
img.save(os.path.join(HERE, 'preview.png'))
