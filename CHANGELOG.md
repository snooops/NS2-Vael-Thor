# Changelog

All notable changes to the Vael'Thor Empire mod. Newest first. Each entry says **what** changed and, where
there was one, **why**. Status markers as in the README: ✅ tested in-game · 🔧 not yet verified in-game.
Balance numbers are always first pass.

---

## 2026-11-15

### Changed
- ✅ **Sentinel Obelisk placement** no longer asks the commander for a facing. It fires all-round with its own
  target selector, so the direction step inherited from the vanilla Sentry did nothing.

### Fixed
- ✅ **Own arrow on the map (C) stayed Vael'Thor** after switching from the Vael'Thor to the aliens via the ready
  room. The map re-sets its icon atlas every time it opens, and the mod forgot there that it had put a caste icon
  on the arrow, so it never restored the vanilla arrow on a team switch (`GUI/GUIVTMinimap.lua`).

## 2026-11-14

### Added
- **Steam Workshop update** of item 3833055653 (uploaded 17:48, git tag `workshop-2026-11-14-2`): the fix for the
  stuck blue HUD squares.
- **Steam Workshop update** of item 3833055653 (uploaded 15:50, git tag `workshop-2026-11-14`): everything since the
  2026-11-03 16:48 upload. The Workshop description now names the GPL-3.0 license and links the GitHub
  source (`mod.settings`).
- **Vael'Thor tech map (J)** (`Hooks/GUITechMap.lua`): J showed the marine tech tree, because vanilla picks the
  layout by team type and the Vael'Thor are marine-type. Vael'Thor players (and their commander) now get their own
  map in violet: Nexus with Siphon, Pylon (Resonant Pylon) and Nexus Gate (Nexus Recall) on top, then the
  Synthesis Chamber (Phase Dash, Overcharge, Plasma Calibration 1–3, Shield Matrix 1–3, Shield Generator with
  Targeting Visor / Aegis Array, Sentinel Obelisk with Prism / Trinity Lens), Authorization Tier 2 (Archon's
  Throne → Iron Discipline, Shield Overdrive, Psionic Spire with its three researches) and Tier 3 (Singularity
  Tech → Launcher). Researched, available and running research are shown like vanilla. Marines keep the vanilla
  map. The Lua layout is generated: edit `art/ui/techmap/layout.py`, run `gen.py`, check with `render.py`
  (`preview.png`). ✅

### Changed
- **Psionic Knife damage ×2 against players** (25 → 50 per swing; `kVTKnifePlayerDamageScalar` in
  `Hooks/Globals.lua`). A biomass-1 skulk (95 effective HP) now dies to two swings without Plasma Calibration
  (biomass 2 still two, from biomass 3 three; marine: 7 → 4 swings). Structures unchanged at 100 per swing. ✅
  *Why:* requested: the knife should two-hit a fresh skulk.
- **Vanguard: no right-click melee.** The Plasma Carbine no longer has the vanilla rifle butt attack
  (`VTPlasmaCarbine:GetHasSecondary` returns false, `Classes/VTWeapons.lua`). ✅ *Why:* requested; it was just
  the marine melee.
- **Synthesis Matrix menu in warmup too** (`VTTeam.lua`, `VT_GetRespawnTime` in `Hooks/Globals.lua`): vanilla
  warmup respawns every dead player instantly. Dead Vael'Thor now get the Synthesis Matrix menu in warmup as well
  and pick their caste and loadout; SYNTHESIZE works right away (no matrix timer during warmup), bots still
  respawn on their own. ✅ *Why:* requested; the instant respawn skipped the death menu.

### Fixed
- **Blue squares stuck on screen** (`Hooks/GUIMarineHUD.lua`): after returning from the main menu (or a new
  spawn) more and more translucent blue rectangles covered the view. They are the vanilla marine HUD boot-up
  animation (10 random squares that fade out over a second), but the fade only runs while the HUD script
  updates, and the marine HUD is hidden for the Vael'Thor, so it never updates. The animation now only plays on a
  visible HUD. Marines had it too: the mod hid the HUD directly (past ClientUI) and never showed it again, so a
  HUD hidden once by a stale team check stayed hidden for a Marine. The HUD's visibility is now decided again for
  every new local player by that player's team. ✅
- **Wrong network message ids in the Predict VM** (`Hooks/Hitreg.lua`): the client's Predict VM never got the
  real matchup and instead read other messages as `VTMatchup` (272 in one game, in bursts during combat). Each
  corrupt value reset it to the default matchup, flipping its `kVTTeamIndex` and team types at random. Cause:
  network message ids follow the registration order, and vanilla `Hitreg.lua` registers its `hitreg` debug
  message only on the server and the client. In the Predict VM every message registered after it had an id one
  lower (server = client = 108 messages, Predict 107, `hitreg` missing at position 99), so it decoded
  `VTBoltImpact` (sent on every plasma bolt hit) as `VTMatchup`, and all five Vael'Thor messages were shifted.
  The Predict VM now registers the same `hitreg` message in the same place. Confirmed by logging the registration
  order in every VM: 108 / hitreg at 99 everywhere afterwards, the Predict VM gets the real matchup, no corrupt
  messages in combat. As a safety net `VTMatchup` carries two 16-bit check values and both client VMs ignore a
  message that fails them; the server no longer sends it to bots. ✅
  *Lesson:* every mod network message must be registered in the same order in all three VMs, including Predict.
- **Chat names, kill feed and team colours of the Vael'Thor on team 2** (`VTPalette.lua`): in Marines vs. Vael'Thor
  the Vael'Thor's chat names were alien orange. Vanilla `GetColorForTeamNumber` / `GetColorForPlayer` assume
  team 2 = aliens. The Vael'Thor team is now violet by team number (chat names, kill feed, `PlayerUI_GetTeamColor`).
  The message text keeps the vanilla chat colour, like marine and alien messages. ✅
- **Dead Vael'Thor came back as marines in Marines vs. Vael'Thor** (`Classes/VTSpectator.lua`): after `kill` in
  warmup a Vanguard respawned as a vanilla Marine on team 1, still with parts of the Vael'Thor UI. Vanilla
  `MarineSpectator` (base of the Synthesis Matrix spectator) forces team 1 in `OnCreate` and `OnInitialized`, so a
  dead soldier of the team-2 empire landed in the marines' respawn queue: instant Marine respawn in warmup, Infantry
  Portal queue in a round. The spectator now goes back to the Vael'Thor team after both vanilla calls. ✅
  *Why:* matchup 3 moved the Vael'Thor to team 2 (2026-11-13).
- **Vael'Thor looked like aliens in parts of the UI in Marines vs. Vael'Thor** (`Hooks/Player_Client.lua`): damage
  numbers and world texts were alien orange instead of violet. Vanilla `PlayerUI_IsOnMarineTeam` /
  `PlayerUI_IsOnAlienTeam` compare the team *number* with the team *type*, so the Vael'Thor on team 2 counted as
  aliens. The Vael'Thor team now always counts as marine-type. This also gives them the marine chat style, the
  marine countdown logo, no floating location text (the Vael'Thor HUD shows it) and the marine minimap arrow colour.
  ✅ (damage number colour; the other effects not checked yet) *Why:* matchup 3 moved the Vael'Thor to team 2 (2026-11-13).
- **Vael'Thor commander broken in Marines vs. Vael'Thor** (`Hooks/GUIProduction.lua`): vanilla
  `Commander:SetupHud` passes the commander's team *type* (marine = 1) to `GUIProduction:SetTeam` as a team *index*.
  With the Vael'Thor on team 2 the client has no TeamInfo for team 1, so the research strip errored
  (`GUIProduction.lua:277`, every frame) and `SetupHud` stopped halfway: the commander click manager, tooltip and
  the rest of the HUD setup never ran. The strip now reads TeamInfo from the commander's own team and keeps the
  marine-style look. ✅ *Why:* matchup 3 moved the Vael'Thor to team 2 (2026-11-13).

---

## 2026-11-13

### Added
- **Vael'Thor colours instead of marine blue** (`VTPalette.lua`, `Hooks/GUIWorldText.lua`):
  - **Vael'Thor vs. Aliens:** on every client the marine-type colours become violet: chat names and text, name tags,
    scoreboard, team messages, voice chat names, end screen, unit status names, world texts (including the vanilla
    GUIs' own copies of those colours). Re-applied every second because some GUIs load lazily.
  - **Every matchup, for Vael'Thor players:** the use prompt (the "E", "Start Commanding", pickup hints, its progress
    bar) and the damage numbers / world texts are violet. A damage-number colour picked in the advanced options is
    kept. In Vael'Thor vs. Marines the rest stays marine blue, since real marines share the marine team type. ✅
- **Team name "Vael'Thor"** instead of "Frontiersmen" in the scoreboard and everywhere else vanilla shows the team-1
  name (locale key `NAME_TEAM_1`, overridden in `Strings.lua` for everyone; in Vael'Thor vs. Marines team 2 is called
  "Frontiersmen"). `kVTFactionName` is now "Vael'Thor" (was "Vael'Thor Empire"). The ready room's "N players" marker
  above the team-1 door is violet in Vael'Thor vs. Aliens, and the glowing 3D "MARINES" sign above it is replaced by a violet 3D "VAEL'THOR" whenever team 1 is the
  Vael'Thor: the vanilla sign props (`marine_join`, `join_marine`, `join_text_01` models) are hidden and
  `models/vaelthor/signs/vt_join_sign.model` is placed at their coords (incl. scale). The model is built by
  `art/ui/signs/build_join_sign.sh` in the vanilla model's frame: extruded, bevelled text in the vanilla sign font
  (Microgramma Bold Extended, ships with NS2), bevels and sides mapped to a bright violet bar, fronts to a dark
  violet fill, 50% larger than the vanilla letters. Vanilla re-shows props on every local spawn
  (`SetCommanderPropState`), so the vanilla sign is re-hidden every second and right after that call. ✅
- **Isolation from other mods** (instead of a "team 3", which NS2 can't do: team 3 is the spectator team and
  everything assumes two playing teams). Balance and gameplay mods for marines no longer reach the Vael'Thor:
  - **Vanilla snapshot:** a second entry `lua/entry/VaelThorBaseline.entry` (Priority 1000, loads before every other
    mod) hooks the vanilla marine class, mixin, balance, tech data and damage files and stores a copy right after
    each one loads (`Baseline/`).
  - **Frozen behaviour:** every Vael'Thor class gets frozen copies of the marine methods it inherits
    (`VT_FreezeClass`, `Baseline/Freeze.lua`): copies of the vanilla functions that keep the vanilla file-local
    constants and read vanilla balance values and vanilla marine-only mixins. Explicit base calls go through
    `VTBase.Marine...`. Methods shared with a both-teams base (Player, Weapon, ...) still follow mods of that base.
  - **Own numbers:** Vael'Thor tech entries are cloned from the *vanilla* marine entries, and the code that builds
    on marine values reads them through `VT_Vanilla(...)`. Plasma Calibration / Shield Matrix have their own tech ids
    (cost, time and damage scaling of the marine Weapons/Armor 1–3 no longer apply).
  - Alien-side effects on soldiers (parasite, web, stun, corrosion) stay shared on purpose: alien mods may change
    what aliens do to anyone.
  - **Check:** `vt_isolation` lists what other mods changed and whether it reaches the Vael'Thor;
    `vt_isolation_selftest` (cheats) patches marine code like a mod would and checks the Vael'Thor stay vanilla.
  ✅

### Removed
- **Rift Portal** (a reskinned Phase Gate). The empire's mobility now runs only through the pylons and Nexus Gates.
  Getting to the front fast means building a gated Nexus there (25 + 20 res) on purpose, and the Nexus Gate becomes
  the high-value target for aliens to hunt. **Rift Recall** became **Nexus Recall** (Assist menu, 4 res, 20 s
  cooldown, unlocked by a Nexus Gate): it pulls the targeted soldier to the nearest active Nexus Gate. The Tier 2 build
  slot is free again. The rift model and art stay in the repo (`art/buildings/`, `output/models/vaelthor/rift/`) but
  are no longer loaded. ✅ *Why:* two teleport networks blurred the faction's identity, and the pylons are meant to
  be its infrastructure.

### Changed
- **Matchup 3 is now "Marines vs. Vael'Thor"** (was "Vael'Thor vs. Marines"): vanilla marines are team 1 and the
  Vael'Thor team 2, so the marines get the vanilla marine side of every map (start, power nodes, ready room door).
  `kVTMatchup.MarinesVsVT` keeps the value 3, so a stored `VaelThorConfig.json` stays valid. `kVTTeamIndex` is
  1 in Vael'Thor vs. Aliens and 2 here; `NS2Gamerules:BuildTeam` builds `VTTeam` for whichever slot that is. The
  former team-2-marine fixes are gone (power nodes are team 1's again) or now apply to the Vael'Thor: a
  marine-type team 2 gets the marine starting personal resources at round start and when joining. Team names
  follow the team (`NAME_TEAM_2` = "Vael'Thor" here). 🔧
- **Ready room shows both factions correctly:** the 3D "VAEL'THOR" sign replaces the sign above the Vael'Thor
  team's door: the "MARINES" sign in Vael'Thor vs. Aliens, the "ALIENS" sign (`alien_join`, `join_alien`,
  `join_text_05`) in Marines vs. Vael'Thor, where "MARINES" stays. The sign is fitted into each vanilla model's
  own frame (centre, letter height, front plane), so it also fits the 2x `join_marine` and the alien signs. ✅
  The "N players" marker is violet over the Vael'Thor door and vanilla over the other in every matchup. 🔧
- **Map (C) and scoreboard follow the Vael'Thor team, not team 1:** the Vael'Thor's scoreboard column and map
  blips/icons are violet, the other team's vanilla. Vanilla picks map blip teams by team number (team 2 = Alien*),
  so in Marines vs. Vael'Thor the Alien* blip colours are the violet ones. Fixes mixed-up colours in that mode
  (Vael'Thor map and scoreboard alien orange, marines' violet): clients start in the default matchup and get the
  real one a moment after connecting, and the map colours were applied once in that moment and never undone.
  Now everything is re-done whenever the Vael'Thor team changes (the scoreboard is rebuilt then). 🔧
- **Fix: marines' building flickered in Marines vs. Vael'Thor** (holding E switched between builder and weapon):
  the client's Predict VM never got the matchup, kept the default (Vael'Thor = team 1) and predicted the team-1
  marines as Vael'Thor soldiers, who can't build. The build check (`Hooks/ConstructMixin.lua`) now goes by class
  (`VT_GetIsVTClass`: the mod's own `VT…` classes) instead of team, so it no longer depends on the matchup at
  all. `VTMatchup` is also hooked in the Predict VM (`Classes/VTNetwork.lua`, logs a `predict: matchup` line)
  and re-sent on every team join. ✅
- **Singularity pull fixed: a real vortex.** It used to give each enemy a single 7 m/s shove on detonation, which ground
  friction and the target's own movement cancelled almost at once, so nobody was pulled in. The anomaly now stays
  active for 1.5 s (`kVTSingularityPullDuration`, model hidden) at a point 0.4 m off the surface it hit. Every
  0.05 s it steers each light enemy in 4.5 m (mass ≤ 200: skulk, lerk, gorge, fade; not onos) toward its centre at
  up to 8 m/s, with a small lift so ground friction doesn't eat the pull, and holds them within 0.6 m of the core.
  Damage and slow still apply once, at detonation. A second pulse effect marks the collapse. ✅
- **Singularity Launcher runs on energy.** No ammo, no reserve and no reload animation anymore: each shot takes
  17 energy (`kVTSingularityEnergyCost`) from the Plasma Carbine's energy cell, the same pool that recharges inside
  the Subvention field. A shot also restarts the cell's 0.5 s recharge delay. Without 17 energy the launcher doesn't
  fire at all. The launcher's own clip stays full, so its animations show loaded shells. The HUD shows the shared
  energy ("ENERGY x / 80 – 17 per shot", red below one shot), and the crosshair pips count the affordable shots
  (4 at full energy). ✅ *Why:* one energy economy for the Vanguard instead of separate grenade ammo.
- **Singularity Launcher: impact fuse.** The singularity bolt now detonates on its first contact with anything (wall,
  floor, enemy, friendly structure or soldier) instead of bouncing like a vanilla grenade until it touches an enemy
  or its timer runs out. Client prediction stops at the impact too (`kClearOnImpact`). Only enemies are affected,
  as before. ✅ *Why:* bouncing grenades didn't fit a gravity anomaly and were hard to place.
- **Nexus Gate menu (pylon jump) redesigned** in the style of the Synthesis Matrix menu: dimmed screen, solid panel
  with the crystal frame, a mouse cursor and one clickable row per active Nexus Gate (sector, live distance,
  integrity in red below 50%). Keys 1–9 still work; Esc, right click or a click outside the panel cancels. While the
  8 s jump cooldown runs (a client-side estimate, the server's timer isn't networked), the menu shows
  "Gate recharging" and doesn't send jumps. The shared look moved to `GUI/VTGUIStyle.lua` (palette, framed boxes,
  text fitting), which the death menu now uses too. ✅
- **Synthesis Matrix menu, second pass** (feedback on #1): more opaque (solid dark panel and card bodies under the
  crystal frames, plus a dimmed screen behind the menu). Clicks now arrive through a MouseTracker listener, which
  runs before the other GUI scripts, and the cursor is kept visible while the menu is open. Every text is shortened
  with "..." to fit its box, and the panel is wider (1100 × 760). Each caste card shows a **portrait** of its in-game
  model: `art/ui/make_caste_portraits.sh` renders the rigged player models with their purple in-game textures in
  Blender (`render_caste_portrait.py`) into `output/ui/vaelthor/caste_portraits.dds`. ✅
- **All Vael'Thor buildings 20% smaller**, done in Lua without rebuilding the models: `kVTStructureModelScale = 0.8`
  (`Hooks/Globals.lua`). `VT_InstallStructureScale` shrinks each building's model in `OnAdjustModelCoords`, so
  rendering, attachment points and the model origin all scale with it. The obelisk head height (targeting, beam
  origin), the glow lights, the health bars (scaled model height + 0.4 m), the Nexus use range and the commander's
  ghost preview (`Hooks/GhostModelUI.lua`) were scaled by hand. The engine shrinks the collision hulls too
  (checked with `collision server`). ✅ *Why:* the buildings felt too big.
- **Synthesis Matrix menu and manual respawn** ([#1](https://github.com/snooops/NS2-Vael-Thor/issues/1)): dead
  soldiers are no longer synthesized automatically when the 9 s timer ends. A new menu like the alien evolve menu
  (`GUI/GUIVTMatrixMenu.lua`) opens on death with a mouse cursor: four caste cards (quota, cost, lock state,
  description of the selected caste), three loadout rows (left/right click cycles) and a **SYNTHESIZE** button.
  Clicking it (or Space) before the timer ends *arms* the request, and synthesis happens as soon as the timer runs out.
  Click again to cancel. B hides/shows the menu, and the keys 1–5 / R / E still work. Bots are synthesized
  automatically. The old text menu in `GUIVTHud` is removed (it keeps only the cloak tint). All choices now go
  through the `VTMatrixChoice` message (choices 8–11 added), and `VTMatrixLoadout` also carries the ready time
  and armed flag. ✅ *Why:* players want to decide when to respawn and pick their class from a real menu.

---

## 2026-11-03

### Open issues
- **Hit registration** of plasma bolts feels unreliable ("most shots not recognized"). No bug was found in a
  code review, so `vt_hitdebug` was added to measure it (see Added). Waiting for test output.
- ~~**Building hitboxes not re-checked in-game**~~ Resolved: confirmed in-game on 2026-11-13 (with the 20 %
  building scale, collision included).
- **Obelisk beam visibility not re-checked in-game** after the texture fix (see Fixed). Check as an alien being
  shot and as a Vael'Thor watching; `log.txt` logs "obelisk beam: drawing a beam on the local player" once.

### Added
- **Published on the Steam Workshop** as item 3833055653 ("Very very very pre-alpha", uploaded 16:48; the later
  changes of this day are not uploaded yet); `mod.settings` keeps the id. ✅ *Why:* first public release.
- **`launchpad.sh`**: starts Launch Pad through the game's Proton prefix with the NS2 app id, so it finds the
  running Linux Steam client. ✅ *Why:* under plain `wine` Launch Pad reported `m_steamInitialized=false` and
  couldn't publish.
- **Subject sprint**: Shift on the ground starts a 3 s sprint at 14 m/s (~42 m; earlier passes were limited by
  distance, 7 m then 12 m), 8 s cooldown counted from the start (5 s after the sprint ends). Full control: the
  direction follows the held movement keys relative to the view (view forward if none) every tick, on the ground
  and in the air, so the player steers with keys and mouse and can jump without losing the burst. No ground
  friction during the burst; grabbing a wall ends it; after it the speed drops to run speed once on the ground.
  No dodge while bursting. HUD chip `[SHIFT] SPRINT`. 🔧
  *Why:* user design (steering and jumping added on request).
- **Subject wall hold**: holding Shift while climbing keeps the Subject in place (no movement, no sliding) and
  keeps the climb stamina full, so it can hang indefinitely and has a full climb when it lets go. 🔧
  *Why:* user design.
- **Vanguard first-person arms are the Vanguard's own** (Silver Sentinel chrome arms with the violet glow)
  instead of the marine arms, on the Plasma Carbine, Psionic Knife and Singularity Launcher. The arms are cut from
  the player model (from just below the shoulder down), fitted onto the first-person skeleton by joint positions
  (hand, each finger segment, forearm, upper arm) and swapped into the view models; weapon geometry, skeleton
  and animations are unchanged. New tools `art/weapons/build_view_arms.py` + `replace_view_arms.py`, build script
  `art/weapons/build_vanguard_view_arms.sh` (also run by the carbine and knife builds). The Singularity Launcher
  now has its own fixed view model. 🔧
  *Why:* user request; a Vanguard looked down at marine arms.
- **Own models for all eight structures** (Nexus, Resource Siphon, Subvention Pylon, Synthesis Chamber,
  Shield Generator, Sentinel Obelisk, Rift Portal, Psionic Spire). Generated in Tripo from our own concept
  renders, decimated to 10–15k triangles, with their own convex collision, violet-glowing textures, a pulsing
  violet light and the new model as the commander's placement ghost. 🔧
  *Why:* every structure used a vanilla marine model as a placeholder.
- **Concept renders** for the eight structures (`art/buildings/concepts/`), drawn procedurally in Blender in
  one design language (chrome and gunmetal, stepped bases, floating violet crystals, glowing seams), used as
  Tripo input. *Why:* importing StarCraft buildings was requested; their assets are Blizzard's and can't be
  used, so original designs in a similar spirit were made instead.
- **Shared building pipeline** `art/buildings/build_all.sh` (one list with height, triangle budget and
  collision bands per building; the bands were replaced by model-following hulls later the same day, see
  Fixed). *Why:* each new building was a copy of the last build script.
- **Vael'Thor top bar** for the whole team (soldiers, dead soldiers, commander): resources + income per
  minute, Nexus / Siphon / Pylon counts, soldiers waiting in the Synthesis Matrix, caste counts vs. quota.
  ✅ (bar shown and liked) *Why:* the marine top bar showed marine data (resource towers, supply, infantry
  portals) in marine blue.
- **Research panel** under the top bar: up to three running researches/upgrades with progress bar, percent and
  time left. 🔧 *Why:* players had no way to see what the commander is researching.
- **Crosshairs per weapon** (`GUI/GUIVTCrosshair.lua`): carbine shards on the live spread + energy pips,
  knife/blades/claws that react when an enemy is in reach, Singularity drop marks (10/20/30 m), Echo Scanner
  brackets on the real 70° cone, Praetor 5° spread ring with energy arcs, plus a hit marker. 🔧
  *Why:* the Vael'Thor weapons showed a blank vanilla crosshair.
- **Unit status in Vael'Thor colours + psi shield**: aimed-at friendly units show a violet shield bar above
  health/armor and the shield value in the numbers. 🔧 *Why:* the shield (the main defence layer) was
  invisible there, and the bars were marine blue.
- **Map icons** (full map C, commander minimap): original top-down icons for all structures and castes,
  violet team colours, your own arrow shows your caste. Blip types stay vanilla. 🔧
  *Why:* the map showed marine icons; vanilla blip types are kept because alien bots rank their targets by them.
- **Commander icons**: 51 original icons for every Vael'Thor structure, upgrade, research, directive,
  commander ability, caste, quota button and weapon; Plasma Calibration / Shield Matrix get own icons for
  Vael'Thor viewers only. Shipped as an extended `ui/buildmenu.dds` (vanilla icons unchanged). 🔧
  *Why:* every Vael'Thor tech borrowed a marine icon.
- **Commander HUD theme**: the marine commander frames recoloured to violet (build panel, tabs, tooltip,
  resource display, selection panel, logout button, alert badge, minimap frame), only for Vael'Thor commanders. 🔧
  *Why:* first step of the commander HUD rework.
- **Pylon field pulse** (commander only): every 25 s a violet ring expands from each Pylon to the edge of its
  field, then rings contract at the structures it powers. Removed again the same day: it crashed the client
  (see Removed).
  *Why:* replaces the power node pulse (see Removed) with the Vael'Thor equivalent.
- **Praetor energy pool**: 100 energy shared by both plasma miniguns (1 per bolt), shown in the HUD weapon
  panel. Recharges like the Vanguard's carbine inside a field (0.5 s delay, 16/s); outside a field it slowly
  regenerates when out of combat (full in 60 s, 3 s after the last shot). 🔧
  *Why:* requested; the miniguns had no resource limit, and the slow regen keeps a Praetor away from a
  field from being stuck empty.
- **Normal jump for the Praetor**. 🔧 *Why:* the exo thruster hover was removed (see Removed).
- **Console commands**: `vt_class <caste>` switches your own caste (cheats); `vt_hitdebug` prints every
  plasma bolt's fate from server and client (cheats). ✅ `vt_class` *Why:* testing castes required dying and
  the Synthesis Matrix; hit registration needed data instead of guesses.

### Changed
- **Bile Bomb respects the psi shield.** It used to skip the shield entirely. Soldiers: the bile amount
  (10 % of the raw bile damage, unchanged) now drains the shield first and only the rest removes armor; still
  never health. Structures: the shield absorbs the bile first, the remainder takes the vanilla bile rules. 🔧
  *Why:* user design; the shield should protect against everything.
- **The Vael'Thor start location's power node stays off** at round start (vanilla marines get it built for
  free). The Vael'Thor run on the Subvention field; their commander skins etc. are still applied. A vanilla marine
  team in Vael'Thor vs. Marines keeps its powered start. 🔧
  *Why:* user request.
- **Nexus commander entry works like the Alien Hive**: look at the Nexus from any side and press **E**,
  also by pressing E within ~1.5 m of its base. A chat message explains a refusal. ✅
  *Why:* nobody could take command. The vanilla Command Station only accepts a commander standing *inside*
  it (within 1 m of a point 1.5 m above its centre), which on the Nexus model is inside the core crystal. Its
  login also depended on hatch animation tags that a static model doesn't have.
- **Praetor fire rate +50 %** (×1.275 of the vanilla minigun). 🔧 *Why:* requested.
- **Praetor Teleport Dash**: range 10 → 12 m (+20 %), now costs 20 energy. 🔧 *Why:* requested.
- **Plasma Carbine spread −25 %** (2.8° → 2.1°). 🔧 *Why:* requested.
- **Praetor HUD**: the weapon panel shows "PLASMA MINIGUNS" and the energy instead of "EXOWEAPONHOLDER". 🔧
- **Psionic Spire is research-only**: E no longer opens the Prototype Lab buy menu (jetpacks / exosuits). 🔧
  *Why:* the Spire inherited the vanilla buy menu by accident.
- **Rift Portal** counts as deployed once built. **Sentinel Obelisk** aims and fires from its crystal head. 🔧 (Rift Portal removed 2026-11-13)
  *Why:* both vanilla behaviours depended on animations / attach points the new static models don't have.
- **Team skins are ignored for the Vael'Thor team** (structures, extractors, MACs, ARCs). 🔧
  *Why:* a commander's marine skins would paint marine textures over the Vael'Thor models.
- **Sentinel Obelisk fires steady psionic beams instead of bullets.** One violet beam from the crystal head deals
  33.3 damage per second (the vanilla sentry's sustained damage), range 20 m, damage applied every 0.1 s. Beams
  stay on their target while it is valid instead of hopping. Stuns halve the damage. Fires in all directions
  (360°): the vanilla sentry only targeted its front half and saw within a 160° cone. Targets are picked by
  the enemy team's type (aliens, or vanilla marines in Vael'Thor vs. Marines) with an explicit enemy check, so
  it never targets its own team. 🔧
  *Why:* user design; a beam fits the psionic faction better than a sentry gun.
- **Sentinel Obelisk is silent while idle**: the vanilla sentry's scan ping every ~5.5 s is gone. 🔧
  *Why:* user request; the turret ping doesn't fit the Obelisk.
- **Sentinel Obelisk beam sound**: a looping energy hum (vanilla nanoshield loop `marine/commander/nano_loop`)
  plays at the Obelisk while any of its beams fires and stops with the beams. 🔧
  *Why:* user request; the beams were silent. A vanilla loop is used because custom sounds need an own FMOD bank.
- **Obelisk lenses** (per-structure upgrades, like the Aegis Array): **Prism Lens** [10 res / 30 s] allows 2
  beams, **Trinity Lens** [15 res / 45 s, needs the Prism Lens and Authorization Tier II] allows 3. Each beam
  hits a different target. Damage per beam (relative to the base): no lens 100%; Prism 115% (1 beam) or 90%
  each (2); Trinity 130% (1), 90% each (2), 70% each (3). The damage depends on the chosen beam count, not on
  how many enemies are in range. 🔧
  *Why:* user design (Trinity numbers given by the user; the Prism step is our interpolation).
- **Obelisk commander controls**: **Focus Beam** (click an enemy: beam 1 locks on it while it is attackable,
  released when it dies, goes beyond 30 m or the ground is clicked) and **Single / Split Beam** buttons to pick 1-3
  beams. Six new commander icons. 🔧
  *Why:* user design; the commander can trade coverage for single-target damage.

### Fixed
- **Sentinel Obelisk beam was practically invisible** (noticed as a Gorge being shot). It used the vanilla
  `ui/laser.material`, whose texture is pure red and lit only in a 1-3 px line of its 64 px width: on the beam
  strip that is a ~5 mm dark-red hairline. Now an own texture (`art/effects/build_obelisk_beam.sh` ->
  `models/vaelthor/beam/obelisk_beam.material`, Emissive shader like the vanilla laser): violet glow over the
  whole 18 cm strip with a bright core, coloured in the texture itself. The strips are also turned towards the
  viewer's camera every frame, and for the player being shot the beam ends just below and in front of the view.
  🔧
  *Why:* user report. (A first guess, that the target sees the beam edge-on, was checked and is not the cause.)
- **Building hitboxes were lying on their side** (all eight Vael'Thor structures, since the models were
  imported). The engine places a collision solid relative to its bone (bone x solid, the vanilla convention);
  CompileModel wrote our solids already in model space and the root bone carries a bind rotation, so every hitbox
  was turned 90 degrees: the height pointed along +x and half of it was under the floor. Shots went through the
  visible building and hit invisible geometry next to it. `art/buildings/fix_solid_space.py` rewrites the solids
  bone-relative right after compiling (now part of `build_building.sh`); all eight models are fixed. ✅
  (confirmed in-game 2026-11-13)
  *Why:* user report ("structures still use the hitboxes of the original marine buildings"). This probably also
  caused the earlier Nexus use-trace failures.
- **Building hitboxes follow the actual models.** Each structure had 2-3 convex hulls, one per height band,
  which filled every gap (between the Obelisk's prongs, the Shield Generator's lattice struts, the Siphon's legs)
  and left the Rift Portal's ring without any collision. Now `art/buildings/prepare_building.py` (`auto` mode)
  builds a watertight 4 cm voxel copy, cuts it into 0.3-0.4 m slices, splits each slice into its separate pieces
  and gives every piece its own convex hull; hulls that are mostly empty space are split further. 12-120 hulls
  per building (vanilla Hive: 174). Rift Portal: the ring and pillars are solid, the portal membrane and the
  walk-in column at the centre stay open so players can still reach the teleport spot. Collision preview:
  `art/buildings/preview_collision.py`. ✅ (confirmed in-game 2026-11-13)
  *Why:* user request; shots hit empty air next to buildings or passed through solid parts.
- **Client crash when joining the Vael'Thor team.** The game closed right after connecting, without a script
  error in `log.txt`. Gone after removing the Pylon field pulse (see Removed), which was the cause. ✅
  The one-time `[Vael'Thor] ...` breadcrumb log lines stay, to pin down any future hard crash.
- **Faction matchup didn't stick** (vote passed, map reloaded, still Vael'Thor vs. Aliens). The setting was
  saved in `ServerConfig.json`, and the game deletes every key it doesn't know from that file when it loads it.
  The matchup now lives in its own file `VaelThorConfig.json` (same folder as `ServerConfig.json`). ✅
  (`log.txt`: after the vote the server loaded "Vael'Thor vs. Marines")
- **Vael'Thor vs. Marines: the vanilla marines counted as aliens internally.** Every entity's team type comes
  from a table local to `TeamMixin.lua`, filled before the mod applies the matchup, so the old patch in
  `VT_ApplyMatchup` never reached it. Team-2 marines took alien-only damage, had alien heal limits, showed
  "organic" hit effects and played alien effect variants. `Hooks/TeamMixin.lua` now gets the real table and the
  matchup patches it (fallback if a game update renames it: live lookup + a log line). 🔧
- **Vael'Thor vs. Marines: vanilla Sentries and ARCs had no targets.** They only look at alien-type entities; with
  the type fix the Vael'Thor (marine-typed) were invisible to them. In that matchup they now use the marine-type
  target lists plus an enemy check (`Hooks/TargetSelectors.lua`). Other matchups are unchanged. 🔧
- **Resource Siphon error spam** (`ExtractorVariantMixin.lua:77: assertion failed`, ~180,000 times, log grew to
  ~900 MB). The Extractor skin lookup didn't know the class `VTSiphon`. ✅ (gone after restart)
- **Echo Scanner animation errors** (`welder_view.animation_graph ... no node found for 16`). With a robotic
  (BMAC) marine skin the server and client chose different scanner view models; the scanner now has a fixed
  view model like every other Vael'Thor weapon. 🔧
- **Plasma bolt impact network warnings** (normal `nx/ny/nz` outside −1.01..0.99). The field range now has
  headroom above 1.0. 🔧
- **Praetor energy display jumping** while firing: energy is now spent only on the server. 🔧
  *Why:* client prediction lowered the value and each server update reset it.
- **Marine top bar still visible**: the scoreboard kept re-enabling it every frame. ✅
- **Exo HUD parts still visible on the Praetor** (fuel bar, rotating rings): the hide now targets the live
  HUD instances instead of a file hook that never took effect. 🔧
- **Structure collision**: collision solids are bound to a root bone; unbound solids were never placed in the
  world (players and bullets passed through, the Nexus couldn't be used). ✅ Only half the fix: the bound
  solids were then placed rotated onto their side, fixed later the same day (see the first entry above).
- **Map icons on the full map**: the C map is a subclass of the minimap and needed its own hook. 🔧
- **Field pulse materials** lacked the normal/specular maps their shader requires (the game warned at load).
  (Field pulse removed the same day, see Removed.)

### Removed
- **Pylon field pulse** (code `Classes/VTFieldPulse.lua` and the ring model/materials in
  `models/vaelthor/pulse/`). Pylons no longer have a pulse effect; the vanilla power node pulse stays hidden. ✅
  *Why:* it caused the client crash when joining the Vael'Thor team (confirmed: the crash is gone without it).
  The build script in `art/effects/` is kept in case it comes back.
- **Power node pulse** for the Vael'Thor (and for everyone in Vael'Thor vs. Aliens). 🔧
  *Why:* the Vael'Thor don't use power nodes.
- **Exo HUD on the Praetor**: cockpit frame and screens, rotating rings, info bars, fuel bar and the exo
  crosshair. ✅ (cockpit) *Why:* exo information doesn't apply to the Praetor.
- **Praetor thrusters**: both the Shift boosts and the Space hover. 🔧 *Why:* requested.
- **Marine top bar** for the Vael'Thor team (replaced by the Vael'Thor top bar).

---

## 2026-11-01 – 2026-11-02 — initial development

Summary of the work before this changelog existed (details in the README):
- Vael'Thor Empire replaces the marines: Imperial Nexus (build anywhere), Subvention field (Pylons/Nexus
  power structures), proximity auto-build, Nexus Gate, Synthesis Matrix respawn with caste and loadout choice,
  caste quotas, authorization ranks, directives.
- Four castes with own rigged player models (Silver, Cyber, Mecha and Titan Sentinel): Vanguard (Plasma
  Carbine, Psionic Knife, modules, Singularity Launcher), Infiltrator (cloak, psionic blades, hack, Echo
  Scanner), Subject (claws, dodge, double jump, wall climb), Praetor (plasma miniguns, Teleport Dash).
- Psi shield as a third damage pool, Vael'Thor HUD, Targeting Visor, faction matchup vote, bot support.
