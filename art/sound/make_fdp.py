"""FMOD Designer 4 project for the Vael'Thor sound bank, derived from NS2's own assets/soundsrc/hitsounds_client.fdp
(same file format/version the NS2 build of fmod_designercl expects). Every GUID is regenerated.

Usage: python3 make_fdp.py <hitsounds_client.fdp> <out.fdp>
Result: project "vaelthor", event group "missile", 3D simple events (Lua: "sound/vaelthor.fev/missile/<event>"),
one sound bank "vaelthor" with the WAVs next to the .fdp.
"""
import sys, uuid, copy
import xml.etree.ElementTree as ET

SRC, OUT = sys.argv[1], sys.argv[2]
PROJECT, GROUP = "vaelthor", "missile"
# event, wav, oneshot, 3D min / max distance (m), volume dB
EVENTS = [
    ("launch",  "missile_launch.wav",  True,  3.0, 60.0, -30.0),   # user 2026-11-17: launch -30 dB, the others stay
    ("flight",  "missile_flight.wav",  False, 2.0, 35.0, -5.0),
    ("explode", "missile_explode.wav", True,  4.0, 80.0,  0.0),
]


def new_guid():
    return "{%s}" % uuid.uuid4()


def set_text(elem, tag, value):
    child = elem.find(tag)
    assert child is not None, tag
    child.text = str(value)


tree = ET.parse(SRC)
root = tree.getroot()
for g in root.iter("guid"):          # nothing may collide with the vanilla project
    g.text = new_guid()
set_text(root, "name", PROJECT)
set_text(root, "currentbank", PROJECT)

# ---- sound definitions (one per event)
master = root.find("sounddeffolder")
simple = next(f for f in master.findall("sounddeffolder") if f.findtext("name") == "__simpleevent_sounddef__")
defs = simple.findall("sounddef")
template = copy.deepcopy(defs[0])
for d in defs:
    simple.remove(d)
def_names = {}
for i, (ev, wav, *_rest) in enumerate(EVENTS):
    d = copy.deepcopy(template)
    name = "/__simpleevent_sounddef__/%s_%d" % (ev, i)
    def_names[ev] = name
    set_text(d, "name", name)
    set_text(d, "guid", new_guid())
    wf = d.find("waveform")
    set_text(wf, "filename", wav)
    set_text(wf, "soundbankname", PROJECT)
    simple.append(d)

# ---- events
groups = root.findall("eventgroup")
group = groups[0]
for extra in groups[1:]:
    root.remove(extra)
set_text(group, "name", GROUP)
simple_events = group.findall("simpleevent")
template = copy.deepcopy(simple_events[0])
for se in simple_events:
    group.remove(se)
for ev, wav, oneshot, dmin, dmax, vol in EVENTS:
    se = copy.deepcopy(template)
    e = se.find("event")
    set_text(e, "name", ev)
    set_text(e, "guid", new_guid())
    sound = e.find("layer").find("sound")
    set_text(sound, "name", def_names[ev])
    set_text(sound, "loopmode", 1 if oneshot else 0)      # 1 = oneshot, 0 = loop and cut off
    set_text(e, "mode", "x_3d")
    set_text(e, "rolloff", "Logarithmic")
    set_text(e, "mindistance", dmin)
    set_text(e, "maxdistance", dmax)
    set_text(e, "oneshot", "Yes" if oneshot else "No")
    set_text(e, "volume_db", vol)
    set_text(e, "pitch", 0)
    set_text(e, "maxplaybacks", 16)
    set_text(e, "headrelative", "World_relative")
    set_text(se, "bankname", PROJECT)
    group.append(se)

# ---- sound bank with the three waveforms
bank = root.find("soundbank")
set_text(bank, "name", PROJECT)
waves = bank.findall("waveform")
template = copy.deepcopy(waves[0])
index = list(bank).index(waves[0])
for w in waves:
    bank.remove(w)
for i, (ev, wav, *_rest) in enumerate(EVENTS):
    w = copy.deepcopy(template)
    set_text(w, "filename", wav)
    set_text(w, "guid", new_guid())
    bank.insert(index + i, w)

tree.write(OUT, encoding="utf-8", xml_declaration=False)
print("wrote", OUT, "events:", ", ".join("%s/%s/%s" % (PROJECT, GROUP, e[0]) for e in EVENTS))
