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
