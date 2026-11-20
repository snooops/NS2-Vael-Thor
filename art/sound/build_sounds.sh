#!/usr/bin/env bash
# Vael'Thor sound bank -> output/sound/vaelthor.fev + .fsb + .soundinfo
# Lua event paths: "sound/vaelthor.fev/missile/{launch,flight,explode}" (Praetor homing missile),
#                  "sound/vaelthor.fev/crucible/{step1-3,servo,hum,unfold,jump,land}" (Artificer Crucible),
#                  "sound/vaelthor.fev/vanguard/<line>_NN" (Vanguard voice, art/sound/voice/vanguard, Classes/VTVoice.lua).
#   make_missile_sounds.py  synthesises the missile WAVs (original sounds, numpy)
#   make_crucible_sounds.py builds the Crucible WAVs from NS2's own mechanical recordings (cut out of the game's
#                           banks with fsb5_extract.py + ffmpeg, processed with sox)
#   make_fdp.py             FMOD Designer 4 project from NS2's own hitsounds_client.fdp (fresh GUIDs)
#   fmod_designercl.exe     (NS2 utils, under wine) builds the bank; x64/SoundInfo.exe writes the .soundinfo
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/sound"; WORK="$HERE/work"; BUILD="$WORK/build"
OUT="$MOD/output/sound"; SRC="$MOD/source/sound"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
rm -rf "$BUILD"; mkdir -p "$WORK" "$BUILD" "$OUT" "$SRC"

echo "== source recordings (NS2's own banks -> wav, for the Crucible sounds)"
D="$NS2/ns2/sound"; SRCW="$WORK/src"; rm -rf "$SRCW"
python3 -I "$HERE/fsb5_extract.py" "$D/materials.fsb" extract "$SRCW/materials" step_left_1_metal step_left_2_metal step_right_2_metal bash metal_scrape >/dev/null
python3 -I "$HERE/fsb5_extract.py" "$D/marine_2.fsb" extract "$SRCW/marine2" arc_deploy sentry_deploy armory_deploy >/dev/null
python3 -I "$HERE/fsb5_extract.py" "$D/marine_3.fsb" extract "$SRCW/marine3" footstep_left_1 footstep_right_2 >/dev/null
python3 -I "$HERE/fsb5_extract.py" "$D/ambient_3.fsb" extract "$SRCW/amb3" "generic hum" >/dev/null
find "$SRCW" -name "*.mp3" -print0 | while IFS= read -r -d '' f; do
    ffmpeg -v quiet -y -i "$f" -ac 1 -ar 44100 "${f%.mp3}.wav" || true
done
echo "== waves"
python3 -I "$HERE/make_missile_sounds.py" "$WORK"
python3 -I "$HERE/make_crucible_sounds.py" "$WORK"
echo "== voice lines"
for d in "$HERE"/voice/*/; do cp "$d"*.wav "$WORK/"; done
echo "== project"
python3 -I "$HERE/make_fdp.py" "$NS2/assets/soundsrc/hitsounds_client.fdp" "$WORK/vaelthor.fdp"
echo "== build"
cd "$WORK"
wine "$NS2/utils/fmod_designercl.exe" -pc -b "$(w "$BUILD")" "$(w "$WORK/vaelthor.fdp")" 2>&1 \
    | grep -viE "radv|Qt: Untested" || true
ls -l "$BUILD"
test -f "$BUILD/vaelthor.fev"
cp "$BUILD"/vaelthor.fev "$BUILD"/*.fsb "$OUT/"
echo "== soundinfo"
cd "$OUT"
wine "$NS2/x64/SoundInfo.exe" "$(w "$OUT/vaelthor.fev")" "$(w "$OUT")\\" 2>&1 | grep -viE "radv" || true
cp "$WORK/vaelthor.fdp" "$WORK"/missile_*.wav "$WORK"/crucible_*.wav "$SRC/"   # voice WAVs stay in art/sound/voice
ls -l "$OUT"
