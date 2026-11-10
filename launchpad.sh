#!/usr/bin/env bash
# Start NS2 Launch Pad on Linux so it sees the running (native) Steam client.
# Launch Pad is a Windows program: under plain wine it has no Steam. Run through Proton in the NS2 prefix
# (compatdata/4920) with the NS2 app id, Proton's lsteamclient bridges the Steam API to Linux Steam.
# Steam must be running and logged in. Projects are on drive X: (= $HOME) in that prefix, e.g. X:\Dokumente\NS2 mod
set -euo pipefail
STEAM="$HOME/.local/share/Steam"
NS2="$STEAM/steamapps/common/Natural Selection 2"
PROTON="${PROTON:-$STEAM/compatibilitytools.d/GE-Proton11-7/proton}"   # same Proton the game uses
pgrep -x steam >/dev/null || pgrep -f "ubuntu12_32/steam" >/dev/null || { echo "Steam is not running - start it first"; exit 1; }
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
export STEAM_COMPAT_DATA_PATH="$STEAM/steamapps/compatdata/4920"
export SteamAppId=4920 SteamGameId=4920
cd "$NS2"
exec "$PROTON" run "$NS2/LaunchPad.exe" "$@"
