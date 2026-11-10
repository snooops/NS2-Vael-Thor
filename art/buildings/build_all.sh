#!/usr/bin/env bash
# Builds every Vael'Thor building model from art/buildings/glb/<concept>.glb (Tripo, generated from the
# concept renders in art/buildings/concepts/). Usage: build_all.sh [model names...]  (default: all)
#   name      glb                   height  tris   collision: auto:<slice m>[:<clear centre radius m>] = model-following
#                                                  hulls (prepare_building.py auto_hulls); legacy "a-b,c-d" height bands
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILDINGS=(
  "nexus     nexus                 4.2  15000  auto:0.35"
  "chamber   synthesis_chamber     2.6  12000  auto:0.3"
  "spire     psionic_spire         5.0  12000  auto:0.4"
  "pylon     pylon                 3.2  10000  auto:0.35"
  "siphon    siphon                3.2  12000  auto:0.35"
  "shieldgen shield_generator      2.4  12000  auto:0.3"
  "obelisk   sentinel_obelisk      3.8  10000  auto:0.35"
  "rift      rift_portal           3.0  12000  auto:0.3:0.6:0.95@1.72"  # walk-in column + portal membrane kept free, ring solid
)
for line in "${BUILDINGS[@]}"; do
  read -r name glb height tris bands <<<"$line"
  if [ $# -gt 0 ] && [[ ! " $* " =~ " $name " ]]; then continue; fi
  echo "########## $name"
  "$HERE/build_building.sh" "$name" "$HERE/glb/$glb.glb" "$height" "$tris" "$bands"
done
