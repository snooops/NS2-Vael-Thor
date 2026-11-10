-- ============================================================================
-- Vael'Thor Empire - plasma bolt impact effects
-- (post-hook of lua/DamageEffects.lua)
--
-- Vanilla hit effects resolve the doer by entity id on the client, but a bolt
-- is destroyed in the same tick it hits, so its effects never played. Instead
-- the server sends VTBoltImpact (Classes/VTNetwork.lua) to nearby players and
-- each client triggers these two effects locally (Client.lua):
--   * vt_plasmabolt_impact: the Exosuit railgun's per-surface impact at half size
--                           (cinematics/vaelthor/bolt_impact/, art/weapons/make_bolt_impact.py)
--                           + the railgun's per-surface ricochet sound
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

local sounds = {}
for _, s in ipairs({ { "metal", "metal" }, { "organic", "organic" }, { "infestation", "organic" }, { "rock", "rock" },
                     { "thin_metal", "thin_metal" }, { "door", "door" }, { "electronic", "electronic" }, { "armor", "armor" } }) do
    sounds[#sounds + 1] = { sound = "sound/NS2.fev/materials/" .. s[2] .. "/ricochet", surface = s[1],
                            world_space = true, done = true }
end

-- Praetor splash bolts: the full-size vanilla railgun impact + a bigger scorch.
local splashImpacts = {}
for _, surface in ipairs(kImpactSurfaces) do
    splashImpacts[#splashImpacts + 1] = { player_cinematic = "cinematics/materials/" .. surface .. "/ricochetRailgun.cinematic",
                                          surface = surface, done = true }
end
splashImpacts[#splashImpacts + 1] = { player_cinematic = "cinematics/materials/metal/ricochetRailgun.cinematic", done = true }

GetEffectManager():AddEffectData("VaelThorBoltEffects", {
    vt_plasmabolt_splash = { vtBoltSplashEffects = splashImpacts, vtBoltSplashSounds = sounds },
    vt_plasmabolt_splash_decal = { vtBoltSplashDecal = {
        { decal = "cinematics/vfx_materials/decals/railgun_hole_02.material", scale = 0.5, done = true },
    } },
    vt_plasmabolt_impact = { vtBoltImpactEffects = impacts, vtBoltSoundEffects = sounds },
    vt_plasmabolt_decal  = { vtBoltDecalEffects = {
        { decal = "cinematics/vfx_materials/decals/railgun_hole_02.material", scale = 0.25, done = true },
    } },
})

end -- VT_HookedDamageEffects
