# Changelog

All notable changes to the Vael'Thor Empire mod. Newest first. Each entry says **what** changed and, where
there was one, **why**. Status markers as in the README: ✅ tested in-game · 🔧 not yet verified in-game.
Balance numbers are always first pass.

---

## 2026-11-20

### Added
- 🔧 **Vanguard voice lines** (recorded by a friend of the user, script `docs/unit_voice_lines.md`). 41 takes cut
  from the recording, run through the Vanguard effect chain (deeper pitch, octave layer, shimmer, short "radio
  helmet" reverb), mono WAVs in `art/sound/voice/vanguard/`. `art/sound/build_sounds.sh` builds one 3D event per
  take into the mod's bank (`sound/vaelthor.fev/vanguard/<line>_NN`, 3-40 m, -3 dB; the bank grows 1 → 7.5 MB, PCM
  kept so the confirmed missile / Crucible sounds don't change). New `Classes/VTVoice.lua` plays a random take
  (never the same one twice in a row) with per-line chance and cooldown and a 2.2 s "don't talk over yourself"
  guard. Triggers: synthesized (spawn), commander order (one ordered soldier acknowledges, `MarineCommander:
  OrderEntities`), order complete (only that player hears it, like vanilla), kill 40 %, taking damage 35 % / 12 s,
  carbine drained outside a field, Phase Dash / Shield Overdrive, death (at the spot; vanilla marine death scream
  silenced for voiced castes).
- 🔧 **Voice menu (Z / X) for the Vanguard.** Vanilla picks the menu by class name and had none for the Vael'Thor
  classes (empty menu, voice keys did nothing). `Hooks/VoiceOver.lua`: left Need Shield Pulse / Request Arms / Need
  Orders / Raising Structure / Ping, right Taunt / Covering / Follow Me / Advance / Hostiles / Acknowledged. The
  vanilla voice ids are reused (key binds, send limit, commander alerts keep working); the server swaps in the
  caste's own line (`CreateVoiceMessage` in `Server.lua`).

### Changed
- 🔧 **New Subject player model: the "Stalker"** (user picked it from three original concepts, `art/subject/concepts/`:
  Shackled / Stalker / Graft; replaces the Tripo "Mecha Sentinel", which is still built and viewable with
  `vt_model mecha`). Original Blender model built on the marine joint positions: chitin carapace with glowing seams,
  eyeless swept-back crest, dorsal crystal blades, tail; forearm blades + finger talons as face set 1 (the existing
  third-person claws toggle in `Client.lua`). Legs with a mechanical exo-frame (user request): hip actuator, outer
  struts, knee / ankle hinges centred on the marine pivots, bracketed thigh and calf pistons. Bird feet (user
  request, raptor-like): scaled shank with front scutes and spur, three segmented forward toes with scutes, pads and
  hooked talons, a back toe (wall grip). ~21k tris, 2048 px maps baked from the procedural materials.
  Pipeline `art/subject/build_stalker.sh`: model + Cycles bakes, `rig_robot.py` on the unchanged marine skeleton,
  new `art/skeleton/apply_rigid_weights.py` (every part except the flesh body rides 100 % on its bone; bone heat
  fails on this mesh), `export_rigged.py` now keeps several material slots (= face sets) when given several
  textures, `make_ns2_textures.py` gained a `baked` glow mode. `art/skeleton/pose_preview.py` renders pose tests.
  Still drawn at `kVTSubjectModelScale` 1.3.

## 2026-11-18

### Added
- ✅ **Artificer is the fifth caste** (user request; was a cheats-only concept class via `vt_class artificer`).
  The commander buys Artificers like the other castes: Nexus > Castes > **Requisition Artificer, 40 res**
  (`kVTCasteCost.Artificer`, new tech id `VTBuyArtificer`), needs Authorization Tier III like the Praetor
  (`kVTClassRequirements`). Each purchase adds one to the stock (`VTEmpireInfo` stockArtificer / countArtificer),
  synthesizing as Artificer uses one up. Spawn menu (`GUIVTMatrixMenu`): fifth card (cards 245 → 196 px wide),
  click only (key 5 stays the tactical module), choice id 15 (`VTMatrixChoice` range 1-15, cards carry their
  choice id now). Crucible portrait (`art/ui/make_caste_portraits.sh` renders it via `build_crucible.py`'s new
  portrait argument; atlas 1024 → 2048 px wide), commander icons Artificer + Requisition Artificer
  (`make_command_icons.py`, cells 9/10 of row 22), top bar "ART n" (castes column 190 → 230 px, resources 200 →
  160). Praetor live count no longer includes Artificers / Praetor II (subclasses).
- ✅ **Warp-in construction** (user design, Protoss style; replaces the plain proximity auto-build). A placed
  Vael'Thor building is a warp field: a small singularity (black event horizon, white-hot photon ring, spinning
  blue/white accretion disk, blue light) hovering where the building will stand, growing with the progress. It
  warps in while a soldier is within `kVTAutoBuildRadius` (11 m, as before). With nobody near, `vtWarpStability`
  (networked) drains over `kVTWarpCollapseTime` 10 s: the field shrinks, shakes, flickers and its disk tumbles; a
  soldier coming back restores it (`kVTWarpRecoverScalar` 2× as fast). At 0 the field collapses (implosion + flash,
  power-down sound): the structure is removed, the cost is lost, the commander gets a message. Warp fields are
  indestructible (`GetCanTakeDamageOverride`). Warped in: flash, portal sound, the building appears and its crystals
  rise. **No blueprint stage:** vanilla ghost-structure mode is switched off on creation, so there's no 75% cancel
  refund and enemies no longer cancel placements. New: `Classes/VTWarpField.lua` (shared rules, `VT_InstallWarpField`
  on all 7 structures, `VT_AddWarpNetworkVars`), `VTTeam:UpdateAutoConstruction` (stability + collapse), client
  visuals in `VTBuildingAnim.lua` (building fully hidden while warping), models `art/effects/build_warp.sh` →
  `models/vaelthor/warp/warp_{core,halo,disk}.model`. Known limits: the hidden building's collision is there during
  the warp (the space is reserved); bots may keep shooting indestructible warp fields.
  First in-game test (Pylon): only the black core showed, plus the vanilla blue construction hologram over the
  hidden building. Fixed: no `hiddenAmount` material parameter on the Emissive ring/disk any more (the only
  difference to the working missile flame; flicker = parts hidden for single frames), the warp parts' visibility
  is set in one place (UpdateWarp overrode the flicker), and `Hooks/ConstructMixin.lua` removes the vanilla
  `build.material` hologram from Vael'Thor structures.
  Second test: still only the core. **Cause:** the ring and disk are flat, so CompileModel gave them a
  zero-thickness bounding box (model chunk 17: centre + half extents; halo z = 0, disk y = 0) and the engine never
  drew them (the working missile flame is two crossed planes = real depth). `build_warp.py` now adds two tiny
  triangles off the plane on a black texel (invisible with additive Emissive) → boxes 2.4 / 3.2 on every axis.
  Third test: still only the core. **Real cause** (found with the new log lines + `vt_warptest`, which showed
  the parts were placed and visible): halo and disk had an EMPTY material name in the compiled model. `build_warp.py`
  rewired their Blender materials to an additive preview shader before the FBX export, so the export carried no
  texture and CompileModel assigned no material. Preview wiring now happens after the export, and
  `build_warp.sh` fails if a model has no material. (The bounding-box depth from the second fix stays; it may or
  may not have mattered.)
  ✅ The warp field look was confirmed in-game by the user after this fix; the diagnostics (log lines,
  `vt_warptest`) are removed again.
- ✅ **Building animations** (user request). The crystals, rings and the Shield Generator dome move:
  main crystal spins and floats, small crystals circle the building, rings wobble with a precessing tilt, the
  lattice dome turns. Motion ramps up over 1.5 s when the building is built + alive + powered (same rule as the
  glow light) and down again without power; inactive crystals sink a little, under construction they sit lower and
  rise with the build progress. Faster while busy (commander in the Nexus, research running, Obelisk firing).
  **How:** the models stay static. `make_concepts.py` tags the moving objects (`anim("core"|"orbit"|"halo"|"dome")`),
  `export_concepts.py` exports them as `<concept>_parts/<group>.glb` + pivots, `prepare_building.py` keeps them in
  the building as face set 1 (`<name>_anim.material`; collision and the commander ghost unchanged) and exports
  each group around its pivot → `models/vaelthor/<name>/<name>_<group>.model`. `build_all.sh` generates
  `lua/VaelThor/VTBuildingParts.lua` (pivots). New client file `VTBuildingAnim.lua` (loaded from Client.lua) draws
  the parts every frame and hides face set 1 with the invisible blades material (same trick as the Crucible).
  Ghost structures get the see-through overlay on the parts too. Known limit: the moving parts are separate
  render models, so outlines / hive sight / hit flashes don't include them.

### Changed
- ✅ **Building models: original Blender designs instead of Tripo** (user decision). All eight structures (Nexus,
  Siphon, Pylon, Synthesis Chamber, Shield Generator, Sentinel Obelisk, Psionic Spire, unused Rift Portal) now use
  the procedural designs from `art/buildings/concepts/make_concepts.py`, which so far only served as Tripo input
  renders. New `concepts/export_concepts.py` joins each design into one mesh (modifiers applied, sharp edges
  > 35°) with UVs on a 2×2 material atlas (silver, gunmetal, glow seams, crystal) and writes
  `art/buildings/procedural/<concept>.glb` + `<concept>_maps/` (basecolor, rm, flat normal, explicit emissive:
  seams 0.9, crystals 0.35). `build_all.sh` runs the export first and builds from there; `build_building.sh` uses
  the `_maps/` folder when present (512 px textures) and otherwise still handles Tripo GLBs. Same heights as
  before, so glow lights, the Obelisk head, health bars and the 0.8 scale need no change; footprints differ by
  ≤ 0.2 m (README table updated). 0.8k-3.7k tris per building (Tripo: 10k-15k). Collision hulls are regenerated
  from the new meshes (18-114 per building; the Shield Generator dome is a strut lattice → 114).
  **Why:** the user prefers the hand-made look over the Tripo reinterpretations. The Tripo GLBs stay in
  `art/buildings/glb/` but are unused.

### Fixed
- ✅ **Artificer psi shield hit glow showed the Titan's shape** (user report with screenshot): the purple shell is
  an added material layer (`Client.lua` UpdateShieldGlow) and was put on the player's render model - for the
  Artificer the hidden Titan, where added layers still render. It now goes on the Crucible's parts instead
  (`VT_GetCrucibleRenderModels`, VTCrucible.lua). The buildings' moving parts get the shell too now
  (`VT_GetBuildingPartModels`, VTBuildingAnim.lua); before, only the static body flashed.
- `build_building.sh` still pointed at the old `~/Dokumente/NS2 mod` folder; it now resolves the repo from its own
  location. `make_concepts.py` only renders when run directly, so it can be imported.

---

## 2026-11-17

### Added — Artificer (concept class)
- ✅ **Crucible look** (user's pick from the concept round, `art/artificer/concepts/`): the Artificer is drawn as a
  six-legged crab foundry built in Blender (`art/artificer/build_crucible.sh` → `models/vaelthor/crucible/`: body
  with furnace dome, open iris, pincers, emitter, belly Sapper pods; spinning crystal core; thigh / shin / foot).
  **Why not Tripo:** a mechanical design is cleaner built directly, and rigid parts can be animated without a
  skeleton. `VTCrucible.lua` (client, new file) hides the Titan and places the parts every frame: procedural tripod
  gait (feet stay planted, step in an arc when too far off, two alternating tripods), two-bone IK with upward
  knees, body bob, core spin / pulse / flare on drone launch. The defense beam fires from the Crucible's emitter,
  drones launch from the iris, the laser guns are gone. Hitboxes are still the Titan's (2.4 m exo capsule).
- ✅ **Crucible spawn animation** (user: the spawn still showed the exo animation). **Why:** the exo deploy (camera
  bouncing up from below, 1.4 s input lock, cockpit light `exo_login`) belongs to a pilot climbing into a suit. The
  Artificer skips it (`creationTime` set into the past, no `exo_login`) and the Crucible unfolds instead
  (`kVTCrucible.unfoldTime` 1.3 s from the networked `vtSpawnTime`, so it plays only at spawn): resting on its
  belly with the legs folded under the hull, tripod 1 then tripod 2 lift and plant at their rest points, the body
  rises 0.55 m, the core grows and flares. First person: the camera rises with the body, eased, no bounce.
- ✅ **Crucible sounds** (user request "new movement sounds"): own synthesised sounds
  (`art/sound/make_crucible_sounds.py`, new event group `crucible` in the Vael'Thor bank; `make_fdp.py` now builds
  several groups): 3 foot-plant variants (thud + metallic clank + hydraulic hiss; one per landing tripod, random
  variant), a servo whine loop while walking, a quiet furnace hum loop from the core, and an unfold sound at spawn.
  The gait now also runs in first person (sounds; the body is just not drawn). The exo's sounds are off for the
  Artificer: footsteps (world model + `view_step` tag), the cockpit idle hum, the hydraulic deploy sound
  (`deploy_start`) and the cockpit screen dissolve (`deploy_end`).
  Fix after the first test (script error every frame, `VTCrucible.lua:88 attempt to index local 'sound'`): the
  sounds were precached only on the client; sound indices come from the server's precache list, so they had none
  and `Client.CreateSoundEffect` returned nil. Now precached in shared code (`kVTCrucibleSounds`, VTPlayers.lua);
  a missing sound is skipped silently.
- ✅ **Crucible sounds, second pass** (user: the synthesised ones sounded "lol"; wanted authentic, mechanical,
  robotic). Now built from NS2's own mechanical recordings: `art/sound/fsb5_extract.py` (new, minimal FSB5 reader)
  cuts samples out of the game's banks, ffmpeg decodes them, `make_crucible_sounds.py` cuts / pitches /
  time-stretches (sox) and layers them: steps = metal footfall + heavy marine step (pitched down) + sentry servo
  chirp + armory hydraulic hiss; servo loop = armory deploy motor whine; hum = ambient generic hum; unfold = the
  ARC deploy compressed to 1.75 s. New jump (hydraulic release + ARC lock thump + clank) and land (pitched-down
  metal bash + heavy footfall + scrape) replace the exo's: `Hooks/DamageEffects.lua` puts an empty "stop"
  component for VTArtificer first in every vanilla jump / land / footstep block with an Exo entry and adds the
  Crucible's own jump / land block.
  User: all Crucible sounds −30 dB, then (inaudible) +15 dB and +6 dB back: net −9 dB (`make_fdp.py`: steps −15,
  servo −23, hum −27, unfold −13, jump −13, land −12 dB); the missile sounds are unchanged.
- ✅ **First-person spawn no longer the exo's** (user: "still looks like an exo"): the exo view model (cockpit, arms,
  deploy animation) showed until its override materials loaded. `VTArtificer:ModifyViewModelCoords` (asked by
  ViewModel:OnAdjustModelCoords every frame) moves it 100 m behind the camera from the first frame; its FOV stays.
- ✅ **Artificer first person + HUD clean-up** (user, with a screenshot: camera too high for the model, HUD
  overloaded, the beam came out of a shoulder cannon). Eye height 1.5 m instead of the exo's 2.3 m
  (`kVTCrucible.eyeHeight`, `GetMaxViewOffsetHeight`). New `crucible_view.model` built in camera space: emitter
  turret at the bottom centre, pincer forearms from the lower corners; the defense beam starts at its tip, the
  Praetor II shoulder emitter is gone for the Artificer. Drone Bay rebuilt compact (one slim panel: drones, queue
  pips, core energy + bar; per card name / count / build bar / directive / cost; key help only for 8 s after
  spawning, then short notices for directive changes and a full bay; the mark readout lives on the world marker).
  No weapon panel and no defense-beam chip for the Artificer; vitals rows moved down so the caste name no longer
  overlaps INTEGRITY (all castes); Swarm Command state shortened ("NO MARK").
- ✅ **Titan visible for a moment at spawn** (user report). **Why:** the override materials that hide it only take
  once the render model is ready. The Artificer now also sets its opacity to 0 on the client (`SetOpacity`,
  applied by BaseModelMixin when the render model is created): the marine / exosuit shaders' `hiddenAmount`
  alpha-tests every pixel away from the first frame.
- ✅ **Crucible hitboxes** (user request: "hitbox to the real model"): the hidden Titan's model hitboxes move to
  the ragdoll physics group (no bullet / melee / projectile / flame trace hits them); 18 kinematic boxes in the
  player group, owned by the Artificer, follow the Crucible instead: hull (two boxes 45° apart), belly pods, dome,
  iris, pincers + emitter, thigh + shin per leg in the rest pose. Updated every move (server) and every frame
  (clients). Leg geometry + IK moved to `kVTCrucible` / `VT_CrucibleKnee` (Hooks/Globals.lua), shared with the gait.
  Movement collision (player capsule) unchanged. Not lag-compensated.
  Fix after the first test: the boxes were only updated per move, and the test dummy (`spawn vt_artificer`, no
  client) never gets moves, so its server kept the Titan hitboxes. Now also every server tick (`OnUpdate`).
- ✅ **Crucible gait reworked** after the first in-game test (user: "forward and backward is a bit off"). **Why:**
  feet aimed 0.28 s of velocity ahead (~1.5 m at full speed, beyond the 1.45 m leg reach) and both tripods fell
  behind together, so one waited while overstretched. Now a gait clock alternates the tripods while moving, the
  step time shrinks with speed so the stride stays ≤ 0.85 m, feet land half a stride ahead (symmetric around the
  hip; offline sim: max hip-foot 1.31 m at every speed), velocity comes from the smoothed position change, and the
  body dips with each push-off and leans slightly into the movement. Standing / turning keeps the tidy-up steps.
- ✅ **Artificer**, a drone-factory caste on the Praetor chassis, only via `vt_class artificer` (cheats), not in
  the Synthesis Matrix menu. **Why:** a tanky alternative to the Praetor that fights through drones instead of
  its own guns. 400-energy core; LMB = weak auto-aim defense beam; 1/2/3 queue Wasp / Lancer / Sapper drones,
  4 cancels the last order; Shift + 1/2/3 cycles each type's directive (Escort / Hunt / Siege / Focus); RMB marks
  a target; B = Swarm Command (every drone at the mark for 8 s). Max 6 drones, they die with the Artificer.
- ✅ **`VTDrone`** (`Classes/VTDrones.lua`, new file: restart NS2): server-driven flying entity (straight flight or
  navmesh path points, wall sliding, separation), beam damage through the drone as doer (owner gets the kill),
  Sapper contact blast (Structural), Babbler-style kinematic sphere hitbox, client light + beam strips.
- ✅ **Drone Bay HUD** (`GUI/GUIVTDroneBay.lua`, new file): bay panel with per-type cards, queue pips, mark
  readout, world mark frame and drone markers with health bars. Player HUD chips: Swarm Command, defense beam,
  "FABRICATOR CORE" energy panel.
- 🔧 **Drone models** `art/weapons/build_drones.sh` → `models/vaelthor/drones/drone_{wasp,lancer,sapper}.model`.

### Changed
- Praetor energy pool size / recharge are methods now (`VT_GetMaxEnergy`, `VT_GetEnergyRecharge`) and the networked
  `vtEnergy` range covers the Artificer's 400; the Praetor II beam numbers come from `VT_GetBeamParams`;
  `VT_BeamFx.Update` takes an optional width scale. No behaviour change for Praetor / Praetor II.

### Fixed (NS2 update, build 345 / 26730580)
- ✅ **Praetor had no guns** after the modular-exo update: `ExoWeaponHolder` now takes the view model from
  `player.viewModelName` / `viewModelGraphName` (set in `Exo:InitExoModel`, which the Praetor overrides) and
  `Exo.kDualAnimationGraph` is gone. `VTPraetor:InitExoModel` sets both from `kExoWeaponRightLeftComboModels`;
  the holder reports `"minigun"` (15-char network string, dual-fire lock). New `Hooks/GUIExoEject.lua` hides the
  new "Hold G to eject" badge for the Praetor.
- ✅ **Commander icons**: vanilla `ui/buildmenu.dds` grew from 16 to 18 rows; the mod atlas is rebuilt on the new
  one and the VT rows start at `kVTFirstRow` = 18 (`Hooks/TechTreeButtons.lua`, `make_command_icons.py` reads the
  vanilla row count).
- ✅ **Outline colours / Echo Scan fade**: vanilla `ui/marine_outline_lookup.dds` has 6 bands now (new Orange);
  the mod lookup is rebuilt at 384 px and the fade uses `kEquipmentOutlineColorCount`.
- 🔧 **"| 800 psi" repeated across the screen** above structures: vanilla now caches the unit status text; the
  psi suffix is stripped before it is appended (`GUI/GUIVTUnitStatus.lua`).
- `Baseline/VanillaReference.lua` regenerated (244 balance values changed); the extractor reads
  `kMaxRelevancyDistance` from `Globals.lua`.

### Changed — Praetor rework
- ✅ **Laser guns instead of miniguns**: own models (`art/weapons/build_lasergun.sh`: body + sliding emitter
  barrel), drawn by `Client.lua` at the exo muzzle attach points in first person (view-model zone = camera space)
  and on the Titan; the vanilla minigun face sets are hidden. Recoil per bolt (kick, barrel slide, muzzle light).
  The guns converge on the crosshair target; first-person guns sit 20% of the screen height lower.
- ✅ **Firing**: left click fires both guns alternately, immediately (timer in `ProcessMoveOnWeapon` instead of the
  minigun spin-up animation), 8.5 bolts/s per gun, no spread; bolts start at the gun muzzles
  (`kVTPraetorBolt*`). No big splash impact effect per bolt any more (FPS); splash damage unchanged.
- ✅ **Homing missiles on right click**: hold to lock the enemy closest to the crosshair (0.15 s), launches only
  with a lock, 1.8 s cooldown, 140 direct + 40 splash, 12 energy (`kVTMissile*`). Own rocket model with an
  animated exhaust flame + launch burst (`art/weapons/build_missile.sh`), lock brackets and a cooldown arc in the
  crosshair, HUD row.
- ✅ **Shoulder missile pod** (`art/weapons/build_missilepod.sh`) on the right shoulder / upper right of the
  screen; missiles start there (`kVTShoulderMount*`), the pod kicks back on launch.
- ✅ **Own sound bank** `output/sound/vaelthor.fev` (`art/sound/build_sounds.sh`: synthesised WAVs, FMOD Designer
  project built with NS2's `fmod_designercl.exe`): missile launch (−30 dB), flight loop, explosion.
- 🔧 **Energy**: recharges everywhere (no pylon needed) at 16/s, 0.2 s after the last shot / missile / dash.

### Changed — Infiltrator
- ✅ **Ambush**: an attack started while the cloak field is active opens a 0.5 s window; the first hit inside it
  deals +150% damage (`kVTAmbushDamageScalar` 2.5, `kVTAmbushWindow`; `Hooks/DamageTypes.lua`). Blade vs players
  out of cloak: 125.
- ✅ **Psionic Blade reach +50%**: `VTPsionicBlade:GetRange` = the axe's reach × `kVTBladeRangeScalar` 1.5.
- ✅ **Cloak field runs on energy**: Shift toggles it (B does nothing for the Infiltrator), no cooldown. It drains
  10/s from a 100 pool (Phase Cloak: 15 s on a full pool) and collapses at 0; needs 10 to switch on. The energy
  recharges only inside a Subvention field (pylon / Nexus), 10/s, while not cloaked (`kVTCloak*`).
- ✅ **Infiltrator HUD**: crosshair shows the hack recharge (pips above, pulsing when ready) and the cloak energy
  (pips below); the bottom-right panel shows CLOAK ENERGY like the Vanguard's carbine energy.

### Added
- ✅ **Praetor II (test class)**: `vt_class praetor2` only (cheats), not in the Synthesis Matrix menu, no stock.
  A Praetor with a steady auto-targeting psi beam on right click (60 DPS, 20 energy/s, `kVTBeam*`) from a
  shoulder beam emitter with a spinning focus ring (`art/weapons/build_beamemitter.sh`).

---

## 2026-11-15

### Added
- **Steam Workshop update** of item 3833055653 (uploaded 15:09, git tag `workshop-2026-11-15-3`): no impact
  cinematic for carbine bolts.
- **Steam Workshop update** of item 3833055653 (uploaded 14:47, git tag `workshop-2026-11-15-2`): auto-synthesis,
  spawn selection, Vanguard ability on right-click.
- 🔧 **Auto-synthesis on the death screen**: every death starts a countdown (matrix timer, at least
  `kVTAutoSpawnMinDelay` = 5 s, so warmup isn't instant) and the player respawns automatically. Any mouse click
  while dead stops it; then SYNTHESIZE / Space works as before (`VTSpectator:VT_GetAutoSynthTime`).
- 🔧 **Spawn selection**: the Synthesis Matrix menu has a SPAWN AT row (left / right click) to pick a built Nexus
  by location, or any host (random Nexus or active Synthesis Chamber, the old behaviour). Remembered across
  lives; falls back to any host if that Nexus is gone. Names come from the server (`VTMatrixLoadout.spawnName`).
- **Steam Workshop update** of item 3833055653 (uploaded 12:53, git tag `workshop-2026-11-15`): the Obelisk
  limit, the Obelisk placement without facing and the map arrow fix.

### Changed
- 🔧 **Plasma Carbine 15 damage per bolt** (Vanguard, no upgrades): `kVTCarbineDamageScalar` 1.15 → 1.5 × the
  rifle's 10 (was 11.5). With the ×0.85 fire rate that is ~128% of the marine rifle's DPS (was ~98%). Plasma
  Calibration I-III: 16.5 / 18 / 19.5. Overcharge bolts unchanged (×1.9 = 19), Praetor unchanged.
- 🔧 **Targeting Visor free and a violet heat scanner**: no Shield Generator research any more (every soldier,
  flashlight key). New look: own screen effect `shaders/VTHeatVision.*` (violet rework of the alien vision shader)
  darkens the world to violet and makes every unit glow as a heat signature with a slow scanline; the exosuit
  reticles and the lock-on circle are gone, enemy outlines stay. Plain violet tint as fallback.
- 🔧 **Castes are bought by the commander instead of quotas**: Nexus > Castes has Requisition Infiltrator (4 res),
  Subject (8, needs Tier II) and Praetor (25, needs Tier III). Each purchase adds one lifeform to the empire's stock
  (`VTEmpireInfo` stock fields, max 15 per caste); synthesizing a player as that caste uses it up, it doesn't come
  back on death. No quotas and no team-res cost at synthesis any more, so the commander controls the res flow.
  Without stock the player spawns as a Vanguard. Matrix menu cards show "available: N", the top bar
  "CASTES AVAILABLE".
- 🔧 **Synthesis Matrix menu closed on death**: B opens it; a hint box on the left of the death screen says
  "[B] SYNTHESIS MATRIX" and shows the synthesis status / auto-synthesis countdown. Clicks only stop the
  auto-synthesis while the menu is open (with it closed they belong to the spectator camera).
- 🔧 **Psionic Blade = Psionic Knife damage** (Infiltrator): 45 flat → the knife's scalars (50 per swing vs
  players, 100 vs structures), and a wider hit cone: melee box 1.0 × 1.2 m instead of the axe's 0.5 × 0.8
  (`kVTBladeMeleeWidth/Height`).
- 🔧 **Infiltrator +20% movement speed**: `kVTInfiltratorSpeedScalar` 1.12 → 1.344 (× marine speed).
- 🔧 **No weapon swapping between the factions**: Vael'Thor weapons (Plasma Carbine, Singularity Launcher)
  are no longer droppable, so they vanish with a dead soldier instead of lying on the ground for marines. Vael'Thor
  soldiers can't pick up any weapon (no E pickup, no auto pickup, no prompt).
- 🔧 **No impact cinematic for Vanguard carbine bolts** (FPS drops under sustained fire, one cinematic per
  bolt): only the ricochet sound and the small scorch decal remain (`Hooks/DamageEffects.lua`). Praetor splash
  bolts keep their impact.
- 🔧 **Vanguard ability on right-click** instead of B (Shield Boost / Phase Dash / Shield Overdrive): none of
  the Vanguard's weapons has a secondary attack. HUD chip shows `[RMB]`. Infiltrator and Praetor keep B.
- ✅ **Sentinel Obelisk limit**: 1 Obelisk per built Nexus at Authorization Tier I, 2 with Tier II, 3 with Tier III
  (`VT_CheckObeliskLimit`, `Hooks/Globals.lua`). Unbuilt Obelisks count; unbuilt or destroyed Nexuses don't.
  Losing a Nexus keeps existing Obelisks and only blocks new ones. The supply cost inherited from the vanilla
  Sentry (15, which capped the team at 13 Obelisks) is gone, so the limit is the only cap.
- ✅ **Sentinel Obelisk placement** no longer asks the commander for a facing. It fires all-round with its own
  target selector, so the direction step inherited from the vanilla Sentry did nothing.

### Fixed
- 🔧 **Server script error flood from marine weapons on the ground** (playtest 2026-11-15, 20 players: ~26,000
  errors of `WeaponOwnerMixin.lua:415: assertion failed!`, Vanguards, Infiltrators and Subjects alike). A Vael'Thor
  soldier walking over a dropped marine welder tried to auto-pick it up every tick: the welder replaces the axe in
  slot 3, but the Psionic Knife there can't be dropped, so the pickup failed and repeated (also with E). Already
  fixed by "no weapon swapping between the factions" above (Vael'Thor soldiers never pick up weapons); the
  playtest server still ran the 15:09 upload.
- 🔧 **Dead Vael'Thor players couldn't go to the ready room** (playtest: 35× `Team.lua:520: Player isn't on
  team!`). The ready room respawned a dead soldier as a Vael'Thor spectator, which puts itself back on the
  Vael'Thor team, so the respawn failed and the player stayed a dead Vael'Thor. Dead Vael'Thor players now become
  normal ready room players (`Hooks/ReadyRoomTeam.lua`).
- 🔧 **8 "Invalid/no effect type specified for effect!" errors per map load**: the Praetor and Vanguard bolt
  effects shared one ricochet sound table, and the effect manager converts each entry in place, so the second
  effect found them already converted. Each effect gets its own table now (`Hooks/DamageEffects.lua`); the
  sounds played before too.
- 🔧 **Shots over cover hit the cover**: plasma bolts start at a muzzle point below the eye, so peeking over a
  structure the eye saw the target but the bolt hit the structure. If the muzzle's line to the aim point is blocked
  short of it, the bolt now starts at the eye (`GetClearBoltStart`, Vanguard carbine and Praetor).
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
