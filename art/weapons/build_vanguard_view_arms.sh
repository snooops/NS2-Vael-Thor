#!/usr/bin/env bash
# Vanguard first-person arms: the Silver Sentinel's own arms (cut from sentinel_player.model, re-bound to the view
# skeleton by joint positions, build_view_arms.py) replace the marine arms (face set 0) of the Vanguard's view
# models. Weapon geometry, skeleton and animations stay byte-exact (replace_view_arms.py).
#   ./build_vanguard_view_arms.sh [carbine] [knife] [singularity]     (default: all three)
# carbine/knife are processed IN PLACE on their built view models (safe to repeat: the fit only reads the
# skeleton); build_falcon.sh and build_knife.sh call this at their end. The Singularity Launcher view model is
# made from the vanilla grenadelauncher_view.model.
set -euo pipefail
NS2="$HOME/.steam/steam/steamapps/common/Natural Selection 2"
MOD="$HOME/Dokumente/NS2 mod"; HERE="$MOD/art/weapons"; WORK="$HERE/work_arms"
PLAYER="$MOD/output/models/vaelthor/sentinel/sentinel_player.model"
MAT="models/vaelthor/sentinel/sentinel_view.material"
mkdir -p "$WORK" "$MOD/output/models/vaelthor/singularity" "$MOD/source/models/vaelthor/sentinel"

# First-person material: same textures as the player model, view shader with emissive (all four maps present).
cat > "$MOD/source/models/vaelthor/sentinel/sentinel_view.material" <<'MAT'
shader = "shaders/WeaponView_emissive.surface_shader"
albedoMap = "models/vaelthor/sentinel/sentinel.dds"
normalMap = "models/vaelthor/sentinel/sentinel_normal.dds"
specularMap = "models/vaelthor/sentinel/sentinel_spec.dds"
emissiveMap = "models/vaelthor/sentinel/sentinel_illum.dds"
darken = 0
MAT
cp "$MOD/source/models/vaelthor/sentinel/sentinel_view.material" "$MOD/output/models/vaelthor/sentinel/"
for k in albedoMap normalMap specularMap emissiveMap; do
  grep -q "^$k" "$MOD/output/models/vaelthor/sentinel/sentinel_view.material" || { echo "missing $k"; exit 1; }
done

arms(){  # <src view model> <out view model> <name>
  python3 -I "$HERE/build_view_arms.py" "$PLAYER" "$1" "$WORK/arms_$3.json"
  python3 -I "$HERE/replace_view_arms.py" "$1" "$WORK/arms_$3.json" "$MAT" "$2.tmp" && mv "$2.tmp" "$2"
}
for w in "${@:-carbine knife singularity}"; do for x in $w; do
  case "$x" in
    carbine)     f="$MOD/output/models/vaelthor/falcon/falcon_view.model"; arms "$f" "$f" carbine ;;
    knife)       f="$MOD/output/models/vaelthor/knife/knife_view.model";   arms "$f" "$f" knife ;;
    singularity) arms "$NS2/ns2/models/marine/grenadelauncher/grenadelauncher_view.model" \
                      "$MOD/output/models/vaelthor/singularity/singularity_view.model" singularity ;;
    *) echo "unknown: $x"; exit 1 ;;
  esac
done; done
