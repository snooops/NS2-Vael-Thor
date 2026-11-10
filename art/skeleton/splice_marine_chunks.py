"""Copy hitbox/ragdoll/attach-point chunks from a marine model into a compiled model with the same bone order.
Usage: python3 splice_marine_chunks.py <compiled.model> <marine.model> <out.model>"""
import sys, struct
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from ns2_model import chunks, read_bones
SRC, MAR, OUT = sys.argv[1:4]
a = open(SRC, "rb").read(); m = open(MAR, "rb").read()
ba, _, _ = read_bones(SRC); bm, _, _ = read_bones(MAR)
assert [(b["name"], b["parent"]) for b in ba] == [(b["name"], b["parent"]) for b in bm], "bone order differs - splice unsafe"
ca, cm = chunks(a), chunks(m)
FROM_MARINE = {5, 13, 14, 15, 16}
order = [1, 2, 3, 6, 4, 16, 5, 14, 15, 13, 17, 18, 19]
out = bytearray(a[:4])
for cid in order:
    src, tbl = (m, cm) if cid in FROM_MARINE else (a, ca)
    if cid not in tbl: continue
    s, sz = tbl[cid]; out += struct.pack("<II", cid, sz) + src[s:s + sz]
open(OUT, "wb").write(out)
print("spliced", OUT, sorted((k, v[1]) for k, v in chunks(bytes(out)).items()))
