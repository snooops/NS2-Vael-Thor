-- ============================================================================
-- Vael'Thor Empire - server entry point
-- ============================================================================

Script.Load("lua/VaelThor/VTTeam.lua")
Script.Load("lua/VaelThor/Hooks/TargetSelectors.lua")
Script.Load("lua/VaelThor/Baseline/Isolation.lua")   -- console command vt_isolation

-- ----------------------------------------------------------------------------
-- Faction matchup (VTMatchupVote.lua). Read from the mod's own config file once
-- per map load, before NS2Gamerules builds the teams.
-- Not in ServerConfig.json: the game deletes every key it doesn't know from that
-- file when it loads it (ConfigFileUtility CheckConfig/removekeys), so a stored
-- "vt_matchup" was gone again after the map reload.
-- ----------------------------------------------------------------------------
local kVTConfigFile = "VaelThorConfig.json"
local kVTDefaultConfig = { matchup = kVTDefaultMatchup }

function VT_LoadMatchupSetting()
    local config = LoadConfigFile(kVTConfigFile, kVTDefaultConfig, true)
    return config and tonumber(config.matchup)
end

function VT_SaveMatchupSetting(matchup)
    SaveConfigFile(kVTConfigFile, { matchup = matchup })
end

local function LoadMatchup()
    VT_ApplyMatchup(VT_LoadMatchupSetting())
end
LoadMatchup()
-- Also on every map load, in case the server keeps its Lua state between maps.
Event.Hook("MapPreLoad", LoadMatchup)
Script.Load("lua/VaelThor/VTMatchupVote.lua")

-- Team 1 becomes the Vael'Thor Empire unless the match is vanilla; in Vael'Thor
-- vs. Marines team 2 is a vanilla MarineTeam (both teams are marine type then,
-- so team 1 is recognised as the first team built).
local oldBuildTeam = NS2Gamerules.BuildTeam
function NS2Gamerules:BuildTeam(teamType)

    local matchup = VT_GetMatchup()
    if matchup == kVTMatchup.MarinesVsAliens then
        return oldBuildTeam(self, teamType)
    end

    if teamType == kMarineTeamType and not self.team1 then
        return VTTeam()
    end
    if matchup == kVTMatchup.VTvsMarines then
        return MarineTeam()
    end
    return oldBuildTeam(self, teamType)

end

-- Vanilla MakeTechEnt passes the team *type* as the team number, which is only
-- right for marines on team 1. Warmup armory/proto lab for marines on team 2:
function MarineTeam:SpawnWarmUpStructures()
    local techPoint = self.startTechPoint
    if techPoint and not (Shared.GetCheatsEnabled() and MarineTeam.gSandboxMode) and #self.warmupStructures == 0 then
        local teamNumber = self:GetTeamNumber()
        self.warmupStructures[#self.warmupStructures + 1] = MakeTechEnt(techPoint, AdvancedArmory.kMapName, 3.5, -2, teamNumber)
        self.warmupStructures[#self.warmupStructures + 1] = MakeTechEnt(techPoint, PrototypeLab.kMapName, -3.5, 2, teamNumber)
    end
end

-- Vanilla gives team 2 the alien starting personal resources.
local oldResetTeam = MarineTeam.ResetTeam
function MarineTeam:ResetTeam(...)
    local result = { oldResetTeam(self, ...) }
    if self:GetTeamNumber() == kTeam2Index then
        for _, player in ipairs(GetEntitiesForTeam("Player", kTeam2Index)) do
            player:SetResources(kMarineInitialIndivRes)
        end
    end
    return unpack(result)
end

-- Clients learn the matchup on connect (team colours/types, Vael'Thor HUDs, locale).
Event.Hook("ClientConnect", function(client)
    Server.SendNetworkMessage(client, "VTMatchup", { matchup = VT_GetMatchup() }, true)
end)

-- ----------------------------------------------------------------------------
-- Nexus Gate jumps (requested by the client gate menu). Everything is
-- re-validated here; the client only picks the destination.
-- ----------------------------------------------------------------------------
local function OnNexusTeleport(client, message)

    local player = client and client:GetControllingPlayer()
    if not (player and VT_GetIsVTEntity(player) and player:GetIsAlive() and not player:isa("Commander")) then
        return
    end

    local now = Shared.GetTime()
    if now < (player.vtNextGateJump or 0) then
        return
    end

    local pylon = Shared.GetEntity(message.pylonId)
    if not (pylon and pylon:isa("VTSubventionPylon")) then
        return
    end
    if (pylon:GetOrigin() - player:GetOrigin()):GetLength() > kVTGateUseRange then
        return
    end

    local connected, destinations = VT_GetGateJumpOptions(pylon)
    if not connected then
        return
    end

    local gate
    for _, destination in ipairs(destinations) do
        if destination:GetId() == message.gateId then
            gate = destination
            break
        end
    end
    if not gate then
        return
    end

    local height, radius = player:GetTraceCapsule()
    local arrival = GetRandomSpawnForCapsule(height, radius, gate:GetOrigin(),
            kVTGateArrivalMinRange, kVTGateArrivalMaxRange, EntityFilterAll())
    if not arrival then
        VT_SendMessageToPlayer(player, "No room to materialize at that Nexus Gate.")
        return
    end

    player.vtNextGateJump = now + kVTGateTeleportCooldown

    player:TriggerEffects("phase_gate_player_teleport")
    player:SetOrigin(arrival)
    player:SetVelocity(Vector(0, 0, 0))
    player:TriggerEffects("phase_gate_player_teleport")

end
Server.HookNetworkMessage("VTNexusTeleport", OnNexusTeleport)

-- Matrix menu keys sent by the HUD while the dead player follows a teammate.
Server.HookNetworkMessage("VTMatrixChoice", function(client, message)
    local spectator = client and client:GetControllingPlayer()
    if spectator and spectator.VT_ApplyChoice then
        spectator:VT_ApplyChoice(message.choice)
    end
end)

-- Debug helper: "vt_status" prints quotas, counts and directive timers.
Event.Hook("Console_vt_status", function(client)
    local info = VT_GetEmpireInfo()
    if not info then
        Shared.Message("[Vael'Thor] no empire info entity")
        return
    end
    local now = Shared.GetTime()
    Shared.Message(string.format("[Vael'Thor] Infiltrator %d/%d  Subject %d/%d  Praetor %d/%d",
            info:GetCount("Infiltrator"), info:GetQuota("Infiltrator"),
            info:GetCount("Subject"), info:GetQuota("Subject"),
            info:GetCount("Praetor"), info:GetQuota("Praetor")))
    Shared.Message(string.format("[Vael'Thor] Requisition active %.0fs, ready in %.0fs | Relentless active %.0fs, ready in %.0fs",
            math.max(0, info.requisitionEnd - now), math.max(0, info.requisitionReady - now),
            math.max(0, info.relentlessEnd - now), math.max(0, info.relentlessReady - now)))
end)

-- Parses "vanguard" etc. into a kVTClass value; returns class, display name.
local function VT_ParseClassArg(className)
    local name = className and (className:sub(1, 1):upper() .. className:sub(2):lower())
    return name and rawget(kVTClass, name), name
end

-- Stores the class in the client's loadout (kept across respawns, still subject
-- to quota/res/tech on respawn) and swaps the player to it now if alive.
local function VT_SetPlayerClass(player, client, class)

    local prefs = client.vtLoadout or {}
    prefs.class = class
    client.vtLoadout = prefs

    if player.VT_LoadPreferences then
        -- waiting in the Synthesis Matrix queue
        player:VT_LoadPreferences()
        if player.VT_SendLoadoutToOwner then
            player:VT_SendLoadoutToOwner()
        end
        return player
    elseif player:GetIsAlive() and player:GetMapName() ~= kVTClassMapNames[class] then
        return player:Replace(kVTClassMapNames[class], player:GetTeamNumber(), false, player:GetOrigin(),
        {
            vtModule     = player.vtModule,
            vtPrimaryMod = player.vtPrimaryMod,
            vtSecondary  = player.vtSecondary,
        })
    end
    return player

end

-- Debug helper (cheats): "vt_botclass <vanguard|infiltrator|subject|praetor> [count]"
-- Bots never open the loadout menu, so they always synthesize as Vanguards. This
-- sets the class for bots via VT_SetPlayerClass.
Event.Hook("Console_vt_botclass", function(client, className, countArg)

    if not Shared.GetCheatsEnabled() then
        Shared.Message("[Vael'Thor] vt_botclass requires cheats 1")
        return
    end

    local class, name = VT_ParseClassArg(className)
    if not class then
        Shared.Message("[Vael'Thor] usage: vt_botclass <vanguard|infiltrator|subject|praetor> [count]")
        return
    end
    local limit = tonumber(countArg) or math.huge

    local changed = 0
    for _, player in ipairs(GetEntitiesForTeam("Player", kVTTeamIndex)) do
        if changed >= limit then break end
        local botClient = player:GetClient()
        if botClient and botClient:GetIsVirtual() then
            VT_SetPlayerClass(player, botClient, class)
            changed = changed + 1
        end
    end

    Shared.Message(string.format("[Vael'Thor] %d bot(s) set to %s", changed, name))

end)

-- Debug helper (cheats): "vt_class <vanguard|infiltrator|subject|praetor>"
-- Switches the calling player's caste immediately (bypasses quota/res/tech).
-- While dead, it just selects the caste in the Synthesis Matrix.
Event.Hook("Console_vt_class", function(client, className)

    if not client then
        return
    end
    if not Shared.GetCheatsEnabled() then
        ServerAdminPrint(client, "[Vael'Thor] vt_class requires cheats 1")
        return
    end

    local class, name = VT_ParseClassArg(className)
    if not class then
        ServerAdminPrint(client, "[Vael'Thor] usage: vt_class <vanguard|infiltrator|subject|praetor>")
        return
    end

    local player = client:GetControllingPlayer()
    if not player or player:GetTeamNumber() ~= kVTTeamIndex or player:GetIsCommander() then
        ServerAdminPrint(client, "[Vael'Thor] vt_class: join the Vael'Thor team first (and leave the Nexus)")
        return
    end

    VT_SetPlayerClass(player, client, class)
    ServerAdminPrint(client, string.format("[Vael'Thor] caste set to %s", name))

end)

Shared.Message(string.format("[Vael'Thor] Empire loaded. Faction matchup: %s (vote menu or sv_vt_matchup to change).",
        kVTMatchupNames[VT_GetMatchup()]))
