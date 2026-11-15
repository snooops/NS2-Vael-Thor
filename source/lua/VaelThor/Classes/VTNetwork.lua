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
    autoTime  = "float",       -- when automatic synthesis happens (0 = stopped by a click / not queued)
    spawnName = "string (64)", -- chosen spawn Nexus ("" = any host)
    spawnCount = "integer (0 to 15)",  -- built Nexuses to choose from
})

-- Client -> server: a Synthesis Matrix menu choice (GUIVTMatrixMenu: clicks and
-- keys, sent as a message so it works in every spectator camera mode).
-- 1-4 caste, 5 module, 6 primary mod, 7 secondary, 8 toggle "synthesize me",
-- 9-11 cycle module / primary / secondary backwards, 12 stop auto-synthesis,
-- 13 / 14 next / previous spawn Nexus (VTSpectator:VT_ApplyChoice).
Shared.RegisterNetworkMessage("VTMatrixChoice",
{
    choice = "integer (1 to 14)",
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

-- Server -> client on connect and on every team join: the faction matchup of this map (kVTMatchup).
-- Safety net: the message carries two 16-bit check values derived from the matchup and receivers apply it only if
-- both match (random bits pass ~1 in 4 billion). Until 2026-11-14 the Predict VM's message ids were shifted by one
-- (vanilla registers "hitreg" only on server/client; fixed in Hooks/Hitreg.lua), so it decoded VTBoltImpact as
-- VTMatchup and every corrupt value reset it to the default matchup (kVTTeamIndex AND team types).
Shared.RegisterNetworkMessage("VTMatchup",
{
    matchup = "integer (1 to 3)",
    check1  = "integer (0 to 65535)",
    check2  = "integer (0 to 65535)",
})

local function MatchupChecks(matchup)
    return (0x5A17 + matchup * 7919) % 65536, (0xC3A9 + matchup * 104729) % 65536
end

function VT_MakeMatchupMessage(matchup)
    local c1, c2 = MatchupChecks(matchup)
    return { matchup = matchup, check1 = c1, check2 = c2 }
end

function VT_GetIsValidMatchupMessage(message)
    if message == nil or not VT_GetIsValidMatchup(message.matchup) then
        return false
    end
    local c1, c2 = MatchupChecks(message.matchup)
    return message.check1 == c1 and message.check2 == c2
end

-- The Predict VM (client-side prediction of the local player: use/build, weapons, movement) runs the shared
-- code with its own globals and starts with the default matchup like every VM, so it needs the real one too
-- (team-based checks like VT_GetIsVTEntity, team types). Logs only real changes and, now and then, how many
-- invalid messages were ignored.
if Predict and not VT_HookedPredictMatchup then
    VT_HookedPredictMatchup = true
    local ignored = 0
    Predict.HookNetworkMessage("VTMatchup", function(message)
        if not VT_GetIsValidMatchupMessage(message) then
            ignored = ignored + 1
            if ignored == 1 or ignored % 100 == 0 then
                Shared.Message(string.format("[Vael'Thor] predict: ignored %d invalid VTMatchup message(s)", ignored))
            end
            return
        end
        if message.matchup ~= VT_GetMatchup() then
            VT_ApplyMatchup(message.matchup)
            Shared.Message(string.format("[Vael'Thor] predict: matchup %s (Vael'Thor team %s)",
                    tostring(kVTMatchupNames[message.matchup]), tostring(kVTTeamIndex)))
        end
    end)
end
