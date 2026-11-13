-- ============================================================================
-- Vael'Thor Empire - network messages (registered in every VM)
-- ============================================================================

-- Client -> server: jump from a connected pylon to a Nexus Gate.
Shared.RegisterNetworkMessage("VTNexusTeleport",
{
    pylonId = "entityid",
    gateId  = "entityid",
})

-- Server -> owning client: the dead player's Synthesis Matrix choices. While a
-- dead player follows a teammate in first person, Client.GetLocalPlayer() is
-- that teammate, so the HUD can't read the VTSpectator's fields directly.
Shared.RegisterNetworkMessage("VTMatrixLoadout",
{
    class     = "integer (0 to 15)",
    module    = "integer (0 to 15)",
    primary   = "integer (0 to 15)",
    secondary = "integer (0 to 15)",
    readyTime = "float",       -- when synthesis becomes possible (0 = not queued yet)
    armed     = "boolean",     -- the player asked to be synthesized
})

-- Client -> server: a Synthesis Matrix menu choice (GUIVTMatrixMenu: clicks and
-- keys, sent as a message so it works in every spectator camera mode).
-- 1-4 caste, 5 module, 6 primary mod, 7 secondary, 8 toggle "synthesize me",
-- 9-11 cycle module / primary / secondary backwards (VTSpectator:VT_ApplyChoice).
Shared.RegisterNetworkMessage("VTMatrixChoice",
{
    choice = "integer (1 to 11)",
})

-- Server -> players near a plasma bolt impact: play the impact locally
-- (the bolt entity is already gone, so vanilla hit effects can't resolve it).
Shared.RegisterNetworkMessage("VTBoltImpact",
{
    posx = "float", posy = "float", posz = "float",
    -- unit normal; the engine range tops out one step below the max, so leave headroom above 1.0
    nx = "float (-1.02 to 1.02 by 0.01)", ny = "float (-1.02 to 1.02 by 0.01)", nz = "float (-1.02 to 1.02 by 0.01)",
    surface = "enum kHitEffectSurface",
    decal = "boolean",
    splash = "boolean",     -- Praetor bolt: full-size impact + bigger scorch
})

-- Server -> client on connect: the faction matchup of this map (kVTMatchup).
Shared.RegisterNetworkMessage("VTMatchup",
{
    matchup = "integer (1 to 3)",
})
