-- ============================================================================
-- Vael'Thor Empire - plasma bolt impact effects
-- (post-hook of lua/DamageEffects.lua)
--
-- Vanilla hit effects resolve the doer by entity id on the client, but a bolt
-- is destroyed in the same tick it hits, so its effects never played. Instead
-- the server sends VTBoltImpact (Classes/VTNetwork.lua) to nearby players and
-- each client triggers these two effects locally (Client.lua):
--   * vt_plasmabolt_impact: (Vanguard carbine) only the ricochet sound - its half-size railgun impact cinematic
--                           (cinematics/vaelthor/bolt_impact/) was removed for FPS (2026-11-15)
--   * vt_plasmabolt_decal:  the railgun scorch mark, small
-- ============================================================================

if GetEffectManager and not VT_HookedDamageEffects then
VT_HookedDamageEffects = true

local kImpactSurfaces = { "armor", "door", "electronic", "flame", "flesh", "glass", "infestation",
                          "membrane", "metal", "organic", "rock", "thin_metal" }

local impacts = {}
for _, surface in ipairs(kImpactSurfaces) do
    impacts[#impacts + 1] = { player_cinematic = "cinematics/vaelthor/bolt_impact/" .. surface .. ".cinematic",
                              surface = surface, done = true }
end
-- surfaces without a railgun impact (robot, umbra, ethereal, ...): metal
impacts[#impacts + 1] = { player_cinematic = "cinematics/vaelthor/bolt_impact/metal.cinematic", done = true }

-- A new table per effect: the effect manager bakes each component in place (moves `sound` to `asset`), so a
-- component shared by two effects logged "Invalid/no effect type specified for effect!" 8x per map load.
local function MakeRicochetSounds()
    local sounds = {}
    for _, s in ipairs({ { "metal", "metal" }, { "organic", "organic" }, { "infestation", "organic" }, { "rock", "rock" },
                         { "thin_metal", "thin_metal" }, { "door", "door" }, { "electronic", "electronic" }, { "armor", "armor" } }) do
        sounds[#sounds + 1] = { sound = "sound/NS2.fev/materials/" .. s[2] .. "/ricochet", surface = s[1],
                                world_space = true, done = true }
    end
    return sounds
end

-- Praetor splash bolts: the full-size vanilla railgun impact + a bigger scorch.
local splashImpacts = {}
for _, surface in ipairs(kImpactSurfaces) do
    splashImpacts[#splashImpacts + 1] = { player_cinematic = "cinematics/materials/" .. surface .. "/ricochetRailgun.cinematic",
                                          surface = surface, done = true }
end
splashImpacts[#splashImpacts + 1] = { player_cinematic = "cinematics/materials/metal/ricochetRailgun.cinematic", done = true }

GetEffectManager():AddEffectData("VaelThorBoltEffects", {
    vt_plasmabolt_splash = { vtBoltSplashEffects = splashImpacts, vtBoltSplashSounds = MakeRicochetSounds() },
    vt_plasmabolt_splash_decal = { vtBoltSplashDecal = {
        { decal = "cinematics/vfx_materials/decals/railgun_hole_02.material", scale = 0.5, done = true },
    } },
    -- Vanguard carbine bolts: no impact cinematic any more (user report 2026-11-15: FPS drops under sustained
    -- fire, one cinematic per bolt); the ricochet sound and the small scorch decal stay. `impacts` is kept for a
    -- possible cheaper effect later.
    vt_plasmabolt_impact = { vtBoltSoundEffects = MakeRicochetSounds() },
    vt_plasmabolt_decal  = { vtBoltDecalEffects = {
        { decal = "cinematics/vfx_materials/decals/railgun_hole_02.material", scale = 0.25, done = true },
    } },
})

end -- VT_HookedDamageEffects

-- ----------------------------------------------------------------------------
-- Artificer (Crucible): own jump / land sounds instead of the exo's (it is an Exo subclass, and effect components
-- match classnames with isa). Effect blocks are evaluated independently and "done" only ends its own block, so in
-- every vanilla jump / land / footstep block that has an Exo component an empty "stop" component for VTArtificer
-- is put FIRST (empty asset + done = the vanilla way to say "nothing, stop here"); the Crucible's sounds come in
-- their own block. Footsteps are the Crucible's own (VTCrucible.lua). Sounds precached in kVTCrucibleSounds.
-- ----------------------------------------------------------------------------
do
    local manager = GetEffectManager()
    local data = manager and manager.data
    if data and not VT_PatchedArtificerEffects then
        VT_PatchedArtificerEffects = true
        manager:AddEffectData("VaelThorArtificerStop", {
            vt_artificer_stop_template = { stop = { { sound = "", classname = "VTArtificer", done = true } } },
        })
        local template = data.vt_artificer_stop_template
        local stop = template and template[1] and template[1][1]
        data.vt_artificer_stop_template = nil
        local patched = 0
        if stop then
            for _, effectName in ipairs({ "jump", "land", "footstep" }) do
                for _, block in ipairs(data[effectName] or {}) do
                    for _, component in ipairs(block) do
                        if component.classname == "Exo" then
                            table.insert(block, 1, stop)
                            patched = patched + 1
                            break
                        end
                    end
                end
            end
        end
        manager:AddEffectData("VaelThorArtificerEffects", {
            jump = { vtArtificerJump = { { player_sound = "sound/vaelthor.fev/crucible/jump", classname = "VTArtificer", done = true } } },
            land = { vtArtificerLand = { { player_sound = "sound/vaelthor.fev/crucible/land", classname = "VTArtificer", done = true } } },
        })
        if patched == 0 then
            Shared.Message("[Vael'Thor] warning: no exo jump/land/footstep effect blocks found to silence for the Artificer")
        end
    end
end
