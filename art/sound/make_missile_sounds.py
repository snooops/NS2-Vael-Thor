"""Praetor homing missile sounds (synthesised, original): launch, flight loop, explosion -> 44.1 kHz mono 16-bit WAV.

Usage: python3 make_missile_sounds.py <out_dir>
  missile_launch.wav   ~0.9 s  ignition thump + rising exhaust whoosh + psionic shimmer sweep
  missile_flight.wav   1.0 s   seamless loop: rocket roar with flutter + quiet psionic hum
  missile_explode.wav  ~1.6 s  deep boom + debris crackle + falling psionic sizzle
"""
import sys, os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(1729)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def band(noise, lo, hi):
    """Band-pass white noise in the frequency domain (soft edges)."""
    spec = np.fft.rfft(noise)
    f = np.fft.rfftfreq(len(noise), 1 / SR)
    mask = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec * mask, len(noise))


def swept_band(noise, lo0, lo1, hi0, hi1, chunks=48):
    """Band-pass with edges moving linearly over time (overlap-added chunks)."""
    n = len(noise)
    out = np.zeros(n)
    win_len = 2 * n // chunks
    hop = win_len // 2
    window = np.hanning(win_len)
    for i in range(0, n - hop, hop):
        seg = noise[i:i + win_len]
        if len(seg) < win_len:
            seg = np.pad(seg, (0, win_len - len(seg)))
        k = min(1.0, i / n)
        filtered = band(seg, lo0 + (lo1 - lo0) * k, hi0 + (hi1 - hi0) * k) * window
        end = min(n, i + win_len)
        out[i:end] += filtered[:end - i]
    return out


def sweep(t, f0, f1, curve=1.0):
    """Sine with frequency gliding f0 -> f1 over the duration."""
    k = (t / t[-1]) ** curve
    freq = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def norm(x, peak_db=-1.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path, f"{len(x) / SR:.2f}s")


def launch():
    t = t_axis(0.9)
    thump = sweep(t, 70, 32, 0.5) * np.exp(-t / 0.09) * 1.0
    attack = np.minimum(1, t / 0.012)
    whoosh = swept_band(rng.standard_normal(len(t)), 300, 1400, 2500, 7000) * attack * np.exp(-t / 0.32) * 1.6
    crack = band(rng.standard_normal(len(t)), 1500, 9000) * np.exp(-t / 0.025) * 1.2
    shimmer = (sweep(t, 520, 1500, 0.7) + 0.6 * sweep(t, 790, 2100, 0.7)) \
        * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t)) * attack * np.exp(-t / 0.28) * 0.35
    x = norm(thump + whoosh + crack + shimmer)
    fade = np.ones(len(t)); fade[-2000:] = np.linspace(1, 0, 2000)
    return x * fade


def flight():
    # 1 s loop; tones use whole numbers of cycles per second, noise is crossfaded end -> start
    n = SR
    t = np.arange(n) / SR
    extra = SR // 4
    noise = rng.standard_normal(n + extra)
    roar = band(noise, 60, 900) * 1.0
    hiss = band(noise, 1200, 5000) * 0.45
    flutter = 1 + 0.18 * np.sin(2 * np.pi * 23 * np.arange(n + extra) / SR)
    body = (roar + hiss) * flutter
    loop = body[:n].copy()
    fade = np.linspace(0, 1, extra)
    loop[:extra] = loop[:extra] * fade + body[n:n + extra] * (1 - fade)   # wraps seamlessly
    hum = (np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 331 * t)) * (0.75 + 0.25 * np.sin(2 * np.pi * 6 * t))
    x = loop / np.max(np.abs(loop)) + 0.12 * hum
    return norm(x, -3.0)


def explode():
    t = t_axis(1.6)
    attack = np.minimum(1, t / 0.004)
    boom = band(rng.standard_normal(len(t)), 25, 400) * attack * np.exp(-t / 0.35) * 2.2
    thump = sweep(t, 60, 28, 0.4) * np.exp(-t / 0.18) * 1.2
    blast = band(rng.standard_normal(len(t)), 400, 6000) * attack * np.exp(-t / 0.08) * 1.4
    # debris crackle: sparse short clicks, thinning out
    crackle = np.zeros(len(t))
    for _ in range(140):
        at = int(abs(rng.normal(0.18, 0.25)) * SR)
        if at < len(t) - 400:
            click = rng.standard_normal(300) * np.exp(-np.arange(300) / 40)
            crackle[at:at + 300] += click * np.exp(-at / SR / 0.5)
    crackle = band(crackle, 1500, 10000) * 0.6
    sizzle = sweep(t, 950, 180, 0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t)) * np.exp(-t / 0.45) * 0.3
    x = norm(boom + thump + blast + crackle + sizzle)
    fade = np.ones(len(t)); fade[-4000:] = np.linspace(1, 0, 4000)
    return x * fade


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    write(os.path.join(out, "missile_launch.wav"), launch())
    write(os.path.join(out, "missile_flight.wav"), flight())
    write(os.path.join(out, "missile_explode.wav"), explode())
