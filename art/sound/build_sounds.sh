#!/usr/bin/env bash
# Vael'Thor sound bank -> output/sound/vaelthor.fev + .fsb + .soundinfo
# Lua event paths: "sound/vaelthor.fev/missile/{launch,flight,explode}" (Praetor homing missile).
#   make_missile_sounds.py  synthesises the WAVs (original sounds, numpy)
#   make_fdp.py             FMOD Designer 4 project from NS2's own hitsounds_client.fdp (fresh GUIDs)
#   fmod_designercl.exe     (NS2 utils, under wine) builds the bank; x64/SoundInfo.exe writes the .soundinfo
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2_VaelThor"; HERE="$MOD/art/sound"; WORK="$HERE/work"; BUILD="$WORK/build"
OUT="$MOD/output/sound"; SRC="$MOD/source/sound"
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/ns2-tools-wine}" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
w(){ echo "Z:$(echo "$1" | sed 's#/#\\#g')"; }
rm -rf "$BUILD"; mkdir -p "$WORK" "$BUILD" "$OUT" "$SRC"

echo "== waves"
python3 -I "$HERE/make_missile_sounds.py" "$WORK"
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
cp "$WORK/vaelthor.fdp" "$WORK"/missile_*.wav "$SRC/"
ls -l "$OUT"
