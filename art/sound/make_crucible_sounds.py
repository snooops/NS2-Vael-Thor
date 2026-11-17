"""Artificer "Crucible" movement sounds, built from NS2's own mechanical recordings (2026-11-17, second pass: the first,
purely synthesised version sounded toy-like). Sources are cut out of the game's banks by build_sounds.sh
(fsb5_extract.py + ffmpeg -> <work>/src/...), then cut, pitched, time-stretched (sox) and layered here.

Usage: python3 make_crucible_sounds.py <work_dir>        (expects <work_dir>/src/... from build_sounds.sh)
  crucible_step1..3.wav  heavy foot plant: metal footfall + pitched-down marine step + knee-servo chirp + hiss
  crucible_servo.wav     loop: the armory deploy's motor whine, a bit lower
  crucible_hum.wav       loop: ambient generic hum, lower
  crucible_unfold.wav    spawn: the ARC deploy (hydraulics + servo + lock), compressed to ~1.75 s, a bit deeper
  crucible_jump.wav      push-off: hydraulic release hiss + ARC lock thump + clank
  crucible_land.wav      landing: pitched-down metal bash + heavy footfall + short scrape
Source analysis (50 ms windows, tonal vs. noisy): art/sound/analyze_sound.py <wav ...>.
"""
import sys, os, wave, subprocess, tempfile
import numpy as np

SR = 44100
WORK = sys.argv[1]
SRC = os.path.join(WORK, "src")
TMP = tempfile.mkdtemp(prefix="crucible_")


def load(path):
    with wave.open(path) as w:
        assert w.getframerate() == SR and w.getnchannels() == 1
        return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


def sox(rel, start=None, dur=None, effects=()):
    """cut src/<rel> [start, start+dur] and run sox effects (speed / tempo / pitch / filters)"""
    src = os.path.join(SRC, rel)
    out = os.path.join(TMP, "s%d.wav" % np.random.randint(1 << 30))
    cmd = ["sox", src, out]
    if start is not None:
        cmd += ["trim", str(start)] + ([str(dur)] if dur else [])
    cmd += list(effects) + ["rate", "-v", str(SR), "channels", "1"]
    subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)
    return load(out)


def norm(x, peak_db=-1.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def fade(x, fin=0.003, fout=0.03):
    x = x.copy()
    a, b = int(SR * fin), int(SR * fout)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b) ** 2
    return x


def mix(length, *layers):
    """layers: (signal, start seconds, gain)"""
    out = np.zeros(int(SR * length))
    for sig, start, gain in layers:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        if n > 0:
            out[i:i + n] += sig[:n] * gain
    return out


def loopable(x, xfade=0.12):
    n = int(SR * xfade)
    ramp = np.linspace(0, 1, n)
    out = x[:-n].copy()
    out[:n] = x[:n] * ramp + x[-n:] * (1 - ramp)
    return out


def saturate(x, drive=1.6):
    return np.tanh(x * drive) / np.tanh(drive)


M, M2, M3, A3 = "materials", "marine2", "marine3", "amb3"

# ---- steps: three tunings / source combinations
steps = [
    ("step_left_1_metal_layer_1", "footstep_left_1", -600, -500),
    ("step_right_2_metal_layer_2", "footstep_right_2", -500, -700),
    ("step_left_2_metal_layer_6", "footstep_left_1", -700, -400),
]
chirp_src = sox(M2 + "/sentry_deploy.wav", 0.85, 0.16, ["pitch", "-900", "highpass", "300"])
hiss_src = sox(M2 + "/armory_deploy.wav", 2.30, 0.22, ["highpass", "1200"])
for i, (metal, heavy, p1, p2) in enumerate(steps):
    a = sox("%s/%s.wav" % (M, metal), effects=["pitch", str(p1), "lowpass", "6000"])
    b = sox("%s/%s.wav" % (M3, heavy), 0.0, 0.55, ["pitch", str(p2), "lowpass", "3000"])
    x = mix(0.6, (norm(a), 0.0, 0.85), (norm(b), 0.005, 0.75),
            (fade(norm(chirp_src), 0.01, 0.06), 0.035, 0.22),
            (fade(norm(hiss_src), 0.02, 0.1), 0.09, 0.14))
    write(os.path.join(WORK, "crucible_step%d.wav" % (i + 1)), fade(norm(saturate(x, 1.4), -1), 0.0, 0.08))

# ---- servo loop: the armory's motor whine (0.9 - 1.7 s), a bit lower
servo = sox(M2 + "/armory_deploy.wav", 0.85, 0.95, ["pitch", "-300", "highpass", "150", "lowpass", "5000"])
write(os.path.join(WORK, "crucible_servo.wav"), norm(loopable(servo), -3))

# ---- core hum loop
hum = sox(A3 + "/generic hum.wav", effects=["pitch", "-300", "lowpass", "4000"])
write(os.path.join(WORK, "crucible_hum.wav"), norm(loopable(hum, 0.25), -3))

# ---- unfold: the whole ARC deploy, time-compressed (pitch kept), a bit deeper
unfold = sox(M2 + "/arc_deploy.wav", effects=["tempo", "-s", "2.2", "pitch", "-200"])
write(os.path.join(WORK, "crucible_unfold.wav"), fade(norm(unfold, -1), 0.005, 0.15))

# ---- jump: hydraulic release + ARC lock thump + clank
thump = sox(M2 + "/arc_deploy.wav", 2.55, 0.40, ["pitch", "-300"])
release = sox(M2 + "/armory_deploy.wav", 2.28, 0.30, ["highpass", "900"])
clank = sox(M + "/bash.wav", 0.0, 0.35, ["pitch", "-400"])
x = mix(0.75, (fade(norm(release), 0.005, 0.12), 0.0, 0.55), (fade(norm(thump), 0.01, 0.12), 0.02, 0.9),
        (fade(norm(clank), 0.001, 0.1), 0.0, 0.5))
write(os.path.join(WORK, "crucible_jump.wav"), fade(norm(saturate(x, 1.3), -1), 0.0, 0.08))

# ---- land: heavy metal impact
bash = sox(M + "/bash_2.wav", effects=["pitch", "-500", "lowpass", "5000"])
fall = sox(M3 + "/footstep_left_1.wav", 0.0, 0.6, ["pitch", "-800"])
scrape = sox(M + "/metal_scrape.wav", 0.0, 0.35, ["pitch", "-300", "highpass", "400"])
x = mix(1.0, (norm(bash), 0.0, 0.9), (norm(fall), 0.0, 0.8), (fade(norm(scrape), 0.02, 0.15), 0.06, 0.25),
        (fade(norm(chirp_src), 0.01, 0.06), 0.12, 0.18))
write(os.path.join(WORK, "crucible_land.wav"), fade(norm(saturate(x, 1.5), -1), 0.0, 0.12))

print("crucible waves ok (from NS2 recordings)")
