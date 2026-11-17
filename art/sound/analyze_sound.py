"""List loudness / tonality (T tonal, N noise, m mixed) / peak frequency per 50 ms window of WAV files (picks source
segments for make_crucible_sounds.py). Usage: python3 analyze_sound.py <wav ...>"""
import sys, wave, numpy as np
def load(p):
    w = wave.open(p); x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0; return x, w.getframerate()
for p in sys.argv[1:]:
    x, sr = load(p)
    win = int(sr * 0.05)
    rows = []
    for i in range(0, len(x) - win, win):
        seg = x[i:i + win] * np.hanning(win)
        rms = np.sqrt(np.mean(seg ** 2))
        spec = np.abs(np.fft.rfft(seg)) + 1e-9
        f = np.fft.rfftfreq(win, 1 / sr)
        flat = np.exp(np.mean(np.log(spec))) / np.mean(spec)          # 0 tonal .. 1 noise
        cent = np.sum(f * spec) / np.sum(spec)
        peak = f[np.argmax(spec * (f > 60))]
        rows.append((i / sr, rms, flat, cent, peak))
    print("%s  %.2fs  peak rms %.3f" % (p.split("/")[-1], len(x) / sr, max(r[1] for r in rows)))
    line = ""
    for t, rms, flat, cent, peak in rows:
        if rms > 0.01:
            kind = "T" if flat < 0.12 else ("N" if flat > 0.35 else "m")
            line += "%.2f:%s%.0f/%d " % (t, kind, rms * 100, peak)
    print("   ", line[:1200])
