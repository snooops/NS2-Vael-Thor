# Vael'Thor Empire — Natural Selection 2 faction mod

> *"We did not arrive to negotiate or share resources. We came to rule."*

The Vael'Thor are an ancient bio-mechanical species ruled by the Supreme Archon, a totalitarian empire
that strips worlds for raw material. This mod replaces the marine team with them. Where the TSA uses
industrial pragmatism and the Kharaa mutate, the Vael'Thor use **plasma weapons, energy shields,
antimatter and psionics**.

- **Type:** Custom game mode, pure Lua (the Launch Pad Builder isn't needed)
- **Runs on:** the server (`tag_support = "Must be run on Server"`)
- **Team:** replaces team 1 (marines). The aliens are unchanged.
- **Changes:** see [CHANGELOG.md](CHANGELOG.md) for what changed when, and why.

> **Current state (2026-11-03): pre-alpha, published on the Steam Workshop** as item
> [3833055653](https://steamcommunity.com/sharedfiles/filedetails/?id=3833055653). The Workshop copy is the
> upload from 16:48; later changes (Subject sprint / wall hold, Bile Bomb, building hitboxes, visible Obelisk
> beams) aren't uploaded yet.
> - **Confirmed in-game:** joining the Vael'Thor team no longer crashes; the Vael'Thor top bar; the Praetor
>   cockpit removal; bots playing the castes; `vt_class`; switching to Vael'Thor vs. Marines by vote (the map
>   reloads into the new matchup); Launch Pad publishing on Linux (`launchpad.sh`).
> - **Next to test:** the building hitboxes (fixed today: they were lying on their side; check with
>   `sv_tests 1` + `collision server`), Sentinel Obelisk beams (fixed today: they were a red hairline, now an
>   own violet texture), Subject sprint / wall hold, Vanguard first-person arms, Bile Bomb vs. the psi shield,
>   Vael'Thor vs. Marines gameplay (team types, marine turrets), plasma bolt hit registration (`vt_hitdebug`).
> - Most other features are implemented but still 🔧 (see the tables and
>   [Not polished or fine-tuned yet](#not-polished-or-fine-tuned-yet)).

---

## Status legend

Every feature in this README has one of these markers:

| Marker | Meaning |
|---|---|
| ✅ | Tested in-game and working |
| 🟡 | Playable, but numbers or feel are first-pass and **not fine-tuned** |
| 🔧 | Implemented but **not yet verified in-game** |
| 🎨 | Uses **placeholder art** (vanilla marine model, sound or effect) |

> **Balance note:** every cost, timer and damage value in this mod is a first pass. Nothing has been
> balanced in real matches yet, so read **🟡 for all numbers**, even where a feature carries a different marker.

---

## Core mechanics

| Feature | Description | Status |
|---|---|---|
| **Imperial Nexus** | The command chair, spawn point and field source. It can be built **anywhere** (25 res). Snapping to a tech point is optional. The empire falls when every Nexus is destroyed. **Taking command works like the Alien Hive:** look at it from any side (or stand within ~1.5 m of its base) and press **E**; a chat message explains a refusal. | 🟡 🔧 (own model and Hive-style entry) |
| **Subvention field** | Pylons (11 m) and the Nexus (16 m) project a field. Structures only work inside it. Siphons (extractors) ignore room power. Power nodes can't be built, and the start room's power node stays off. | 🟡 |
| **Proximity auto-build** | Structures inside a field build themselves. There is no welder and no marine "use to build". | 🟡 |
| **Psi shield (Protoss style)** | Third pool in front of armor and health. **Only the shield regenerates**; armor and health are permanent and nothing can be welded. Players regenerate 4/s inside a field after 3 s out of combat; structures 10/s anywhere after 6 s. Absorbed hits still give hit numbers. A purple shell flashes on every shield hit and stops once the shield is 0. | 🔧 |
| **Bile Bomb** | Hits the psi shield first. Against soldiers 10 % of the raw bile damage drains the shield, the rest removes armor; it never touches health. Against structures the shield absorbs the bile first, the remainder takes vanilla bile damage. | 🔧 |
| **Infestation** | Drains the psi shield of empire structures (30/s) instead of their armor and blocks its regeneration while they stand on creep. | 🔧 |
| **Nexus Gate** | A Nexus upgrade (20 res / 45 s). Any soldier can press **E** on any Pylon and teleport to the gate (8 s cooldown). | 🟡 |
| **Synthesis Matrix** | Dead players pick caste and loadout in a clickable menu (or keys 1–5 / R / E; B hides it) and respawn with SYNTHESIZE / Space once the 9 s timer is over. No automatic respawn (bots excepted). | ✅ (menu + manual respawn, #1) |
| **Caste quotas** | The commander sets how many Infiltrators, Subjects and Praetors are allowed (defaults 2/2/1, max 3/4/2). If a caste is full, locked or unaffordable, the player spawns as a Vanguard. | 🟡 |
| **Authorization rank** | Personal score unlocks loadout tiers: rank II at 15 points, rank III at 40. | 🟡 |
| **No sprint, no flashlight** | Sprinting is removed for every caste (the Subject uses Shift for its sprint burst / wall hold instead). The flashlight key toggles the Targeting Visor instead. Praetors can't eject. | 🟡 |
| **Vael'Thor HUD** | Replaces the marine HUD with a "psionic crystal" design: vitals, shield, burnout, ability chips, weapon energy and directives. The corner minimap is removed, but the full map (C) still works. | 🔧 |
| **Vael'Thor top bar** | Replaces the marine top bar for the whole team: resources + income/min, Nexus / Siphon / Pylon counts, soldiers in the Synthesis Matrix, caste counts vs. quota. | ✅ |
| **Research panel** | Under the top bar: up to three running researches with progress bar, % and time left, visible to every soldier. | 🔧 |
| **Crosshairs** | Own crosshair per weapon (spread shards, reach indicators, drop marks, scan cone, Praetor spread ring with energy arcs) and a hit marker. | 🔧 |
| **Unit status** | Aimed-at friendly units show a violet psi-shield bar and the shield value; bars and names in Vael'Thor colours. | 🔧 |
| **Map icons** | Original top-down icons for all structures and castes on the full map and the commander minimap, violet team colours, your own arrow shows your caste. | 🔧 |
| **Commander HUD** | Violet commander frames (build panel, tabs, tooltip, resources, selection panel, logout, alerts, minimap frame) and 51 own icons for every Vael'Thor structure, upgrade, research, directive, ability, caste and weapon. | 🔧 |
| **Bots** | Bots can play the VT castes. Debug command: `vt_botclass <class> [count]`. | ✅ (BotAim crash fixed) |

---

## Faction matchups

The server can run three matchups. Players pick one through **Vote faction matchup** in the vote menu, and admins can use `sv_vt_matchup <1|2|3>`. The choice is stored in `VaelThorConfig.json` next to `ServerConfig.json` (the game deletes unknown keys from `ServerConfig.json`). If no round is running, the map reloads right away; otherwise the new matchup starts with the next map.

| # | Matchup | Team 1 | Team 2 | Status |
|---|---|---|---|---|
| 1 | **Vael'Thor vs. Aliens** (default) | Vael'Thor Empire | Kharaa | 🟡 |
| 2 | **Marines vs. Aliens** | vanilla Marines | Kharaa | 🔧 the mod stays dormant |
| 3 | **Vael'Thor vs. Marines** | Vael'Thor Empire | vanilla Marines (marine team type) | ✅ switching by vote · 🔧 gameplay experimental |

- The Imperial Nexus and Resource Siphon are their own classes and tech ids (`VTNexus` / `VTSiphon`), so vanilla marines keep the normal Command Station and Extractor.
- Plasma Calibration / Shield Matrix reuse the vanilla Weapons/Armor upgrades. Only Vael'Thor players see the Vael'Thor names (a per-viewer locale override).
- In matchup 3, map power nodes belong to the marines (team 2). The Vael'Thor can destroy them, like the aliens do.


| Caste | Role | HP / Armor / Psi shield | Unlock | Synth cost |
|---|---|---|---|---|
| **Vanguard Legionnaire** | Core infantry, no quota | 80 / 40 / 50 | — | free |
| **Infiltrator** | Scout, assassin, saboteur | 85 / 20 / 35, +12 % speed | — | 4 team res |
| **Subject** (Bio-Construct) | Melee war-beast | 320 / 80 / 100, +15 % speed | Authorization Tier II | 8 team res |
| **Praetor** | Heavy elite (exo chassis) | 150 / exo armor / 200 | Authorization Tier III | 25 team res |

Shield Matrix I–III adds +15 max psi shield per level (armor stays fixed).

### Vanguard Legionnaire
| Feature | Status |
|---|---|
| **Plasma Carbine**: no clip, 80 energy that recharges only inside a field (0.5 s delay, then 16/s). Fires predicted plasma bolts at 80 m/s. Fire rate is ×0.85 of the rifle, damage ×1.15, spread 2.1° (rifle 2.8°). | 🔧 bolts, impacts and sound unverified · hit registration under investigation (`vt_hitdebug`) · 🟡 recharge feel (fixed jitter) |
| Carbine model: "Falcon Rilfe" by pocolov (CC-BY-4.0) | 🔧 hand position re-fixed after an in-game report and not re-checked |
| **Psionic Knife** melee: procedural model, ×2 damage vs. structures | 🔧 |
| **Fast weapon switch** (×1.5 draw speed) | 🔧 |
| Module: **Shield Boost** (20 s cooldown) | 🟡 |
| Module: **Phase Dash**, a 7 m directional teleport (8 s cooldown) | 🟡 |
| Module: **Shield Overdrive** (rank II): full shields and +20 % speed for 5 s, then 8 s without shields | 🟡 |
| Primary mod: **Overcharge Core** (rank II): slower, ×1.9 armor-breaking bolts | 🟡 |
| Secondary: **Singularity Launcher** (rank III): gravity anomaly that slows and pulls light units together (25 dmg, 4.5 m) | 🟡 🎨 (grenade model) |
| Player model: "Silver Sentinel" (chrome with purple strips) | 🔧 rigged model not yet tested |
| **First-person arms**: the Silver Sentinel's own chrome arms on the carbine, knife and Singularity Launcher (marine animations) | 🔧 |

### Infiltrator
| Feature | Status |
|---|---|
| **Cloak field (B)**: 100 % invisible for 10 s (15 s with Phase Cloak), 15 s cooldown. Attacking, hacking, scanning, taking damage or touching an enemy breaks it. A parasited Infiltrator can't cloak. | 🔧 |
| **Psionic Blades**: wrist blades in the style of Zealot blades, 45 dmg | 🔧 · 🎨 swings with axe animations, the left blade just rides the left hand (no dual-wield anims) |
| **Hack (RMB with blades)**: pulse that disables enemy structures within 7 m for 10 s (9 m / 15 s with Neural Override), 35 s cooldown | 🟡 |
| Hacked **Shades** lose their cloak field and can't fire Ink | 🔧 |
| **Echo Scanner** (slot 2): hold to scan a 30 m / ±35° cone through walls. It outlines enemies for the whole team and reveals cloaked targets. | 🔧 |
| Player model: "Cyber Sentinel" (teal recoloured to purple) | 🔧 |

### Subject (Bio-Construct)
| Feature | Status |
|---|---|
| **Bio-Construct Claws**: 60 dmg, 1.6 m range | 🔧 · 🎨 axe animations |
| **Dodge**: double-tap a direction (9 m/s burst, 1 s cooldown) | 🟡 |
| **Double jump**: one extra jump in mid-air | 🟡 |
| **Skulk-style wall climb**: walls and ceilings, 2 s stamina, jump to push off. The camera stays upright. | 🔧 reworked recently |
| **Sprint** (Shift on the ground): 3 s at 14 m/s (~42 m) with full control (steer with keys and mouse, jump), 8 s cooldown from the start | 🔧 |
| **Wall hold** (hold Shift while climbing): stays in place without sliding, climb stamina kept full | 🔧 |
| Player model: "Mecha Sentinel" drawn at 1.3× scale | 🔧 |

### Praetor
| Feature | Status |
|---|---|
| **Gatling-Plasma cannons**: dual miniguns fire bolt batches (3× minigun damage ×1.15) with 1.8 m splash, fire rate ×1.275 of the vanilla minigun, 5° spread. Silent except for the shot sound, and they don't overheat. | 🔧 |
| **Energy**: 100, shared by both guns, 1 per bolt. Inside a field it recharges like the carbine (0.5 s delay, 16/s); outside a field it slowly regenerates when out of combat (full in 60 s, 3 s after the last shot). Shown in the HUD weapon panel and the crosshair arcs. | 🔧 |
| **Teleport Dash (B)**: 12 m blink, costs 20 energy, 10 s cooldown | 🟡 🔧 |
| **Movement**: no exo thrusters (no Shift boosts, no Space hover); Space is a normal jump | 🔧 |
| **No exo HUD**: cockpit frame and screens, rings, info bars and fuel bar are hidden | ✅ (cockpit) · 🔧 (rest) |
| Player model: "Titan Sentinel" on the exosuit skeleton | 🔧 |

---

## Structures

| Structure | Cost | Build | HP / Armor / Psi shield | Size (W × D × H) | Notes | Status |
|---|---|---|---|---|---|---|
| Imperial Nexus | 25 | — | vanilla CS / 800 | 5.0 × 5.0 × 4.2 m | Build anywhere, field 16 m, Hive-style commander entry | 🟡 🔧 |
| Resource Siphon | 10 | 11 s | vanilla / 500 | 2.3 × 2.6 × 3.2 m | Needs the field, not room power | 🟡 🔧 |
| Subvention Pylon | 8 | 8 s | 700 / 100 / 250 | 1.4 × 1.7 × 3.2 m | Field 11 m, gate entry point | 🟡 🔧 |
| Synthesis Chamber | 15 | 18 s | 1600 / 300 / 500 | 2.4 × 2.4 × 2.6 m | Spawn point and main research | 🟡 🔧 |
| Shield Generator | 12 | 14 s | 1100 / 250 / 400 | 3.3 × 3.3 × 2.4 m | Halves ranged and artillery damage to structures within 9 m | 🟡 🔧 |
| Sentinel Obelisk | 12 | 10 s | 600 / 150 / 200 | 1.9 × 1.9 × 3.8 m | Psionic beam turret: steady violet beam(s) from its crystal head, 33 DPS base, 20 m (from the head), fires 360°, needs no battery. Lenses split it into 2-3 beams; the commander can focus a target and pick the beam count | 🟡 🔧 |
| Rift Portal | 15 | 15 s | 1500 / 200 / 450 | 3.3 × 2.6 × 3.0 m | Two-way teleport; ring and pillars solid, membrane and centre open to walk in | 🟡 🔧 |
| Psionic Spire | 25 | 20 s | 1800 / 300 / 550 | 2.3 × 2.3 × 5.0 m | Psionic research only (no buy menu) | 🟡 🔧 |

Structures get their full psi shield when construction completes. All eight use **own models** (generated in
Tripo from our concept renders in `art/buildings/concepts/`) with violet glow textures and a pulsing violet light
while built and powered. Marine team skins are ignored for the Vael'Thor team.

**Hitboxes** follow the models: 12-120 convex pieces per building (gaps between prongs, struts and legs stay
open). Until 2026-11-03 every building hitbox was lying on its side in-game (see the changelog). 🔧 not yet
re-checked in-game.

---

## Tech tree

`[cost res / time]`; the marker after each node is its polish status.

```
Imperial Nexus  [25]  (build anywhere)                                   🟡
├── Upgrade: Nexus Gate  [20 / 45s]  → teleport from any Pylon            🟡
├── Directive: Requisition Mandate  [10]  +75% build speed 30s, CD 90s    🟡
├── Directive: Relentless Advance   [15]  +20% damage 20s, CD 120s        🟡
├── Caste Quotas menu (Infiltrator / Subject / Praetor ±1)                🟡
├── Assist: Shield Pulse  [3]  refill shields in 6 m, CD 8s               🟡
├── Resource Siphon                                                       🟡
├── Subvention Pylon  [8]                                                 🟡
│   └── Upgrade: Resonant Pylon  [10 / 30s]  field 11→15 m, +50% regen    🟡
│         (needs Synthesis Chamber)
│
└── Synthesis Chamber  [15]                                               🟡
    ├── Plasma Calibration I → II → III  (weapons 1-3, vanilla cost)      🟡
    ├── Shield Matrix I → II → III       (+15 max psi shield, vanilla cost) 🔧
    ├── Overcharge Core       [20 / 60s]  Vanguard primary, rank II       🟡
    ├── Phase Dash Module     [15 / 45s]  Vanguard module                 🟡
    ├── Shield Generator  [12]                                            🟡
    │   └── Targeting Visor   [20 / 60s]  vision mode, all castes         🔧
    ├── Sentinel Obelisk  [12]  steady psionic beam                       🔧
    │   ├── Focus Beam (commander: lock beam 1 on a clicked enemy)        🔧
    │   ├── Single / Split Beam: 1 / 2 / 3 beams (by installed lens)      🔧
    │   ├── Upgrade: Prism Lens    [10 / 30s]  up to 2 beams              🔧
    │   │     1 beam 115%, 2 beams 90% each
    │   └── Upgrade: Trinity Lens  [15 / 45s]  up to 3 beams, needs Tier II 🔧
    │         1 beam 130%, 2 beams 90% each, 3 beams 70% each
    │
    └── Authorization Tier II  [20 / 60s]  → unlocks SUBJECT caste        🟡
        ├── Shield Overdrive Module [20 / 60s]  Vanguard, rank II         🟡
        ├── Upgrade: Aegis Array  [15 / 40s]  (on Shield Generator)       🟡
        │     aura also halves ranged damage to soldiers
        ├── Archon's Throne  [30 / 75s]  (researched at the Nexus)        🟡
        │   └── Directive: Iron Discipline  [15]  -23% dmg taken 20s     🟡
        ├── Rift Portal  [15]                                             🟡
        │   └── Assist: Rift Recall  [4]  pull soldier to nearest Rift   🟡
        ├── Psionic Spire  [25]                                           🟡
        │   ├── Phase Cloak       [15 / 45s]  cloak 10 → 15 s             🔧
        │   ├── Neural Override   [20 / 60s]  hack 9 m / 15 s             🟡
        │   └── Psionic Edicts    [25 / 60s]  directives +50% / -25% CD   🟡
        │
        └── Authorization Tier III  [35 / 90s]  → unlocks PRAETOR caste   🟡
            └── Singularity Launcher [25 / 75s]  Vanguard secondary, rank III  🟡🎨
```

**Loadout gates** (Synthesis Matrix):

| Choice | Personal rank | Team research |
|---|---|---|
| Shield Boost module | I | — |
| Phase Dash module | I | Phase Dash Module |
| Shield Overdrive module | II | Shield Overdrive Module |
| Overcharge Core | II | Overcharge Core |
| Singularity Launcher | III | Singularity Launcher |
| Subject caste | — | Authorization Tier II |
| Praetor caste | — | Authorization Tier III |

---

## Not polished or fine-tuned yet

The open work in one list.

**Confirmed in-game so far**
- No crash when joining the Vael'Thor team (the Pylon field pulse was the cause and is removed)
- Vael'Thor top bar, Praetor cockpit removal, bots playing the castes (BotAim fix), `vt_class`
- Faction matchup switching by vote: the map reloads into Vael'Thor vs. Marines (seen in `log.txt`)
- No more Resource Siphon skin error spam
- Publishing to the Steam Workshop from Linux with `launchpad.sh`

**Never verified in-game**
- The `sv_vt_matchup` admin command, and the matchup being sent to clients (the vote itself works)
- Marines vs. Aliens with the mod loaded: commander menus, HUD/minimap, tech names, Command Station and Extractor all vanilla
- Vael'Thor vs. Marines: marine team on team 2, power nodes given to team 2, warmup structures, starting personal resources
- The Nexus and Siphon as own classes (`Classes/VTNexus.lua`): starting spawn, commander building, Nexus Gate upgrade, minimap blips and skins
- Psi shield layer: absorption, regen, the purple hit shell (custom shader), the HUD's third bar, the Bile Bomb rule and infestation shield drain
- Rigged player models for all four castes (Silver, Cyber, Mecha and Titan Sentinel)
- Third-person arm poses (`OverrideWeaponName`) for the carbine, blades, claws and Singularity Launcher
- Plasma bolts: projectiles, impact effects and decals, the Praetor splash, and the shot sound path (`marine/heavy/railgun_quick_fire`, inferred from the fev)
- Psionic Knife model and balance, and fast weapon switching
- Cloak (always 100 %), Echo Scan stealth detection, the Shade hack
- Subject claws model and the Skulk-style wall climb
- Targeting Visor
- The new Vael'Thor HUD and the Synthesis Matrix while spectating
- The fix for weapon textures under BMAC variants (variant forced to default)
- Everything else from 2026-11-03 (see [CHANGELOG.md](CHANGELOG.md)):
  - structure models and their new hitboxes (`sv_tests 1`, then `collision server`), Hive-style Nexus entry
  - Sentinel Obelisk beams (visibility fixed: they used a red hairline texture), lenses, Focus Beam, beam
    sound; 360° targeting; no idle ping
  - Subject sprint (3 s, steerable) and wall hold; Bile Bomb vs. the psi shield
  - Vanguard first-person arms; the Vael'Thor start room staying unpowered
  - Vael'Thor vs. Marines: team types, vanilla Sentry/ARC targeting, Obelisk targeting marines
  - research panel, crosshairs, unit status shield, map icons, commander icons and theme, Praetor energy /
    dash / jump changes

**Known rough edges**
- **Vael'Thor vs. Marines** still has vanilla screens that assume team 2 is the aliens: team-2 colours stay alien orange, some game-end, alert and commander-help texts, and the bot team brains. Expect an in-game fix pass. Team types (damage rules, hit effects) and the vanilla Sentry/ARC targeting are fixed for this matchup; the Predict VM still uses the default matchup.
- The Predict VM never receives the matchup message (it keeps the default). This should be harmless because Vael'Thor prediction code is class-based, but it hasn't been verified.
- **Plasma bolt hit registration** feels unreliable; measure with `vt_hitdebug` before changing the weapon.
- **Map:** other players' soldiers all show the same soldier icon (they share the vanilla Marine blip type,
  which alien bots rely on); only your own arrow shows your caste.
- **Commander HUD:** build-button backgrounds and highlights, the production queue and the minimap buttons
  still use the vanilla marine look; the layout itself is unchanged (recolour only).
- **Structures:** the Sentinel Obelisk's beam sound is the vanilla nanoshield hum (no own sound bank yet); spores don't confuse it (only stuns halve its damage); a destroyed structure falls over as one rigid piece.
- **No dual-wield or claw animations.** Blades and claws reuse the axe animation, so the left weapon only follows the left hand.
- The **Singularity Launcher** uses the grenade model.
- The **Psionic Blade view model** still swings like an axe.
- **First-person arms:** only the Vanguard has its own arms; Infiltrator (blades, Echo Scanner) and Subject (claws) still show the marine arms.
- The **Robot** model is still built but unused, and it still uses the old moved-joint rigging (it distorts in-game).
- `kVTCloakMovementPenalty` no longer does anything since the cloak became always 100 %.
- The Vanguard secondary slot is labelled "None", but the enum still says `Pistol`.
- **Balance:** every number above is first pass. The psi shield adds a whole extra pool to every unit, so HP, armor and shield values need a retune together.
- The Shield Boost module still uses the cyan vanilla nano shield shell, which can overlap the purple psi shell.

---

## Development

```
NS2 mod/
├── mod.settings            Launch Pad project (publish_id = Workshop item)
├── launchpad.sh            starts Launch Pad through Proton so it sees Steam
├── source/lua/VaelThor/    Lua source (edit here)
│   ├── Classes/            players, weapons, structures, spectator, network
│   ├── Hooks/              post-hooks into vanilla files (TechData, Globals, HUD, ...)
│   ├── GUI/                HUD, gate menu, visor
│   └── VTTeam.lua          the tech tree
├── output/                 what the game loads (lua, models, ui, cinematics)
├── art/                    asset pipelines (Blender/Python/wine scripts per model)
│   ├── buildings/          structure concepts, GLBs and the shared build (build_all.sh)
│   ├── ui/                 HUD, crosshair, map icon and commander icon/theme textures
│   └── effects/            Obelisk beam texture (build_obelisk_beam.sh); field pulse ring (unused)
├── README.md
└── CHANGELOG.md            what changed when, and why
```

**Workflow**
1. Edit `source/lua/VaelThor/...` and copy it to `output/lua/`.
2. Syntax-check with `luajit -b <file> /dev/null`.
3. Launch NS2 with `-game "X:\Dokumente\NS2 mod\output"` (Proton), start a local server, then run `cheats 1`.
4. The log is `log.txt` in the Proton prefix under `Natural Selection 2/`.
5. Publish with Launch Pad: start it with `./launchpad.sh` (Steam must be running). Plain `wine` doesn't see
   Steam; the script runs it through the game's Proton prefix. The Workshop id is kept in `mod.settings`
   (`publish_id`), so every publish updates the same item.

**Debug console commands**
- `vt_class <vanguard|infiltrator|subject|praetor>`: switch your own caste (cheats)
- `vt_hitdebug`: print every plasma bolt's fate, server vs. client prediction (cheats)
- `spawn vt_subventionpylon` / `create VTSubventionPylon`: vanilla cheat spawns work with the Vael'Thor names
- `vt_model <sentinel|cyber|mecha|titan>`: preview a player model
- `vt_robot [yaw]` / `vt_robot_clear`: static robot prop
- `vt_botclass <class> [count]`: spawn bots as a caste (cheats)
- Engine debug views (after `sv_tests 1`): `collision [server|predict]` draws the collision shapes,
  `hitboxes`, `extents`

**Model pipeline (short version):** `x64/CompileModel.exe` and `utils/nvcompress.exe` run under plain `wine`.
Player meshes are deformed onto the **unchanged** marine or exo skeleton, because moving the joints distorts the
animations. View models swap only the weapon face set inside the vanilla binary
(`art/weapons/replace_view_weapon.py`); the arms (face set 0) are swapped the same way for caste arms
(`art/weapons/build_vanguard_view_arms.sh`). Each model has its own `build_*.sh` under `art/`.

**Structure pipeline:** `art/buildings/build_all.sh [names]` turns the Tripo GLBs in `art/buildings/glb/` into
static models (decimate, scale, model-following collision: a watertight voxel copy cut into thin slices and
separate pieces, one convex hull each, max 120 per building, all bound to one root bone and made
bone-relative after compiling with `fix_solid_space.py`; NS2 textures,
preview render). Lessons that cost a crash or a broken feature:
- Collision solids must be parented to a bone, or the engine never places them, and they must be stored
  relative to that bone (the engine places them at bone x solid); CompileModel writes them in model space,
  which turned every building hitbox on its side until `fix_solid_space.py` was added.
- Check what a borrowed vanilla asset really contains: `ui/laser.dds` is a red 1-3 px hairline, which made
  the Obelisk beams invisible.
- Custom server settings don't survive in `ServerConfig.json` (unknown keys are deleted on load); the mod
  keeps its own `VaelThorConfig.json`.
- Every material needs all maps its shader requires (`super_emissive`: albedo, emissive, normal, specular),
  otherwise the client crashes when it is drawn.
- Vanilla behaviour tied to a model's animations or attach points (Command Station login, Phase Gate deploy,
  Sentry muzzle) has to be replaced in Lua for static models.

**UI textures and icons:** `art/ui/` (`build_crosshair.sh`, `minimap/build_minimap_atlas.sh`,
`commander/build_command_icons.sh`, `commander/build_commander_theme.sh`). The icon atlases extend the vanilla
ones (vanilla cells keep their pixel positions).

---

## Credits

- Plasma Carbine model: **"Falcon Rilfe"** by [pocolov](https://sketchfab.com/pocolov), licensed under
  [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/). It was re-textured, rescaled and rigged onto the
  NS2 rifle models. See `output/CREDITS.txt`.
- Player models: Fab assets (Tripo AI), re-rigged for NS2.
- Structure models: generated in Tripo from our own concept renders (`art/buildings/concepts/`).
- Crosshairs, map icons and commander icons: original, drawn procedurally for this mod.
- Natural Selection 2 © Unknown Worlds Entertainment.
