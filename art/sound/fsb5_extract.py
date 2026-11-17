"""Minimal FSB5 reader for NS2's own sound banks (MPEG / PCM samples) - list or extract samples by name.

Usage: python3 fsb5_extract.py <bank.fsb> list
       python3 fsb5_extract.py <bank.fsb> extract <out_dir> [name_substring ...]
MPEG samples are written as .mp3 (raw frames; decode with ffmpeg), PCM16 as .wav.
Used to build the Artificer's Crucible sounds from NS2's own recordings (art/sound/make_crucible_sounds.py).
"""
import sys, os, struct, wave

FREQ = {1: 8000, 2: 11000, 3: 11025, 4: 16000, 5: 22050, 6: 24000, 7: 32000, 8: 44100, 9: 48000}


def read(path):
    data = open(path, "rb").read()
    assert data[:4] == b"FSB5", "not FSB5"
    version, count, shdr_size, name_size, data_size, mode = struct.unpack_from("<6I", data, 4)
    hdr = 0x3C if version == 1 else 0x40
    pos = hdr
    samples = []
    for _ in range(count):
        raw, = struct.unpack_from("<Q", data, pos); pos += 8
        nxt = raw & 1
        freq = FREQ.get((raw >> 1) & 0xF, 44100)
        chans = ((raw >> 5) & 1) + 1
        off = ((raw >> 6) & 0x0FFFFFFF) * 16
        n = (raw >> 34) & 0x3FFFFFFF
        while nxt:
            chunk, = struct.unpack_from("<I", data, pos); pos += 4
            nxt = chunk & 1
            size = (chunk >> 1) & 0xFFFFFF
            ctype = (chunk >> 25) & 0x7F
            if ctype == 2:
                chans = data[pos]
            elif ctype == 4:
                freq, = struct.unpack_from("<I", data, pos)
            pos += size
        samples.append({"freq": freq, "chans": chans, "off": off, "n": n})
    name_start = hdr + shdr_size
    if name_size:
        for i, s in enumerate(samples):
            o, = struct.unpack_from("<I", data, name_start + 4 * i)
            end = data.index(b"\0", name_start + o)
            s["name"] = data[name_start + o:end].decode("latin-1")
    data_start = name_start + name_size
    for i, s in enumerate(samples):
        end = samples[i + 1]["off"] if i + 1 < len(samples) else data_size
        s["data"] = data[data_start + s["off"]:data_start + end]
        s.setdefault("name", "sample%d" % i)
    return mode, samples


if __name__ == "__main__":
    mode, samples = read(sys.argv[1])
    if sys.argv[2] == "list":
        for s in samples:
            print("%-48s %6.2fs %dch %d" % (s["name"], s["n"] / s["freq"], s["chans"], s["freq"]))
    else:
        out = sys.argv[3]; os.makedirs(out, exist_ok=True)
        want = sys.argv[4:]
        for s in samples:
            if want and not any(w.lower() in s["name"].lower() for w in want):
                continue
            base = os.path.join(out, s["name"].replace("/", "_"))
            if mode == 11:         # MPEG
                open(base + ".mp3", "wb").write(s["data"])
            elif mode == 2:        # PCM16
                with wave.open(base + ".wav", "wb") as w:
                    w.setnchannels(s["chans"]); w.setsampwidth(2); w.setframerate(s["freq"]); w.writeframes(s["data"])
            else:
                print("unsupported mode", mode); break
        print("extracted to", out)
