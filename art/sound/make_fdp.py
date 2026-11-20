"""FMOD Designer 4 project for the Vael'Thor sound bank, derived from NS2's own assets/soundsrc/hitsounds_client.fdp
(same file format/version the NS2 build of fmod_designercl expects). Every GUID is regenerated.

Usage: python3 make_fdp.py <hitsounds_client.fdp> <out.fdp>
Result: project "vaelthor", event groups "missile" and "crucible", 3D simple events
(Lua: "sound/vaelthor.fev/<group>/<event>"), one sound bank "vaelthor" with the WAVs next to the .fdp.
"""
import sys, os, glob, uuid, copy
import xml.etree.ElementTree as ET

SRC, OUT = sys.argv[1], sys.argv[2]
PROJECT = "vaelthor"
# group, event, wav, oneshot, 3D min / max distance (m), volume dB
EVENTS = [
    ("missile",  "launch",  "missile_launch.wav",  True,  3.0, 60.0, -30.0),   # user 2026-11-17: launch -30 dB, the others stay
    ("missile",  "flight",  "missile_flight.wav",  False, 2.0, 35.0, -5.0),
    ("missile",  "explode", "missile_explode.wav", True,  4.0, 80.0,  0.0),
    # Artificer "Crucible" (art/sound/make_crucible_sounds.py, lua/VaelThor/VTCrucible.lua); user 2026-11-17: all -30 dB, then +15 and +6 dB back (net -9 dB)
    ("crucible", "step1",   "crucible_step1.wav",  True,  2.0, 30.0, -15.0),
    ("crucible", "step2",   "crucible_step2.wav",  True,  2.0, 30.0, -15.0),
    ("crucible", "step3",   "crucible_step3.wav",  True,  2.0, 30.0, -15.0),
    ("crucible", "servo",   "crucible_servo.wav",  False, 2.0, 18.0, -23.0),
    ("crucible", "hum",     "crucible_hum.wav",    False, 1.5, 12.0, -27.0),
    ("crucible", "unfold",  "crucible_unfold.wav", True,  3.0, 40.0, -13.0),
    ("crucible", "jump",    "crucible_jump.wav",   True,  2.0, 30.0, -13.0),
    ("crucible", "land",    "crucible_land.wav",   True,  2.0, 35.0, -12.0),
]
# Unit voice lines (art/sound/voice/<caste>/<caste>_<line>_NN.wav, copied next to the .fdp by build_sounds.sh):
# one 3D oneshot event per take, "sound/vaelthor.fev/<caste>/<line>_NN" (Classes/VTVoice.lua picks the takes).
VOICE_CASTES = ["vanguard"]
for caste in VOICE_CASTES:
    for wav in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(OUT)), caste + "_*.wav"))):
        name = os.path.basename(wav)[len(caste) + 1:-4]
        EVENTS.append((caste, name, os.path.basename(wav), True, 3.0, 40.0, -3.0))

GROUPS = []
for e in EVENTS:
    if e[0] not in GROUPS:
        GROUPS.append(e[0])


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
for i, (grp, ev, wav, *_rest) in enumerate(EVENTS):
    d = copy.deepcopy(template)
    name = "/__simpleevent_sounddef__/%s_%s_%d" % (grp, ev, i)
    def_names[(grp, ev)] = name
    set_text(d, "name", name)
    set_text(d, "guid", new_guid())
    wf = d.find("waveform")
    set_text(wf, "filename", wav)
    set_text(wf, "soundbankname", PROJECT)
    simple.append(d)

# ---- events
groups = root.findall("eventgroup")
group_template = copy.deepcopy(groups[0])
event_template = copy.deepcopy(group_template.findall("simpleevent")[0])
for se in group_template.findall("simpleevent"):
    group_template.remove(se)
insert_at = list(root).index(groups[0])
for g in groups:
    root.remove(g)
group_elems = {}
for gi, grp in enumerate(GROUPS):
    g = copy.deepcopy(group_template)
    set_text(g, "name", grp)
    for guid in g.iter("guid"):
        guid.text = new_guid()
    root.insert(insert_at + gi, g)
    group_elems[grp] = g
template = event_template
for grp, ev, wav, oneshot, dmin, dmax, vol in EVENTS:
    group = group_elems[grp]
    se = copy.deepcopy(template)
    e = se.find("event")
    set_text(e, "name", ev)
    set_text(e, "guid", new_guid())
    sound = e.find("layer").find("sound")
    set_text(sound, "name", def_names[(grp, ev)])
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
for i, (grp, ev, wav, *_rest) in enumerate(EVENTS):
    w = copy.deepcopy(template)
    set_text(w, "filename", wav)
    set_text(w, "guid", new_guid())
    bank.insert(index + i, w)

tree.write(OUT, encoding="utf-8", xml_declaration=False)
print("wrote", OUT, "events:", ", ".join("%s/%s/%s" % (PROJECT, e[0], e[1]) for e in EVENTS))
