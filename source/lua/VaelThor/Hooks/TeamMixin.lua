-- ============================================================================
-- Vael'Thor Empire - team types per matchup
-- (post-hook of lua/TeamMixin.lua)
--
-- Every entity's team type (TeamMixin:GetTeamType, GetTeamTypeFromTeamIndex) comes from a table that is
-- LOCAL to TeamMixin.lua and filled from kTeam2Type while Shared.lua loads - before the server reads the
-- matchup (Server.lua) or the client receives it (VTMatchup message). So in Vael'Thor vs. Marines the vanilla
-- marines on team 2 reported kAlienTeamType: alien-only damage, alien heal clamping, "organic" hit effects,
-- alien-side target lists.
--
-- Fix: fetch that table through the upvalue of GetTeamTypeFromTeamIndex and publish it as the global
-- kTeamIndexToType, which VT_ApplyMatchup (Hooks/Globals.lua) already patches. If the upvalue can't be found
-- (renamed in a game update), both functions are replaced to read kTeam1Type / kTeam2Type live instead.
-- ============================================================================

if not VT_HookedTeamTypes then
VT_HookedTeamTypes = true

local function FindTeamTypeTable()
    if not (debug and debug.getupvalue and GetTeamTypeFromTeamIndex) then
        return nil
    end
    local i = 1
    while true do
        local name, value = debug.getupvalue(GetTeamTypeFromTeamIndex, i)
        if name == nil then
            return nil
        end
        if name == "kTeamIndexToType" and type(value) == "table" then
            return value
        end
        i = i + 1
    end
end

local teamTypes = FindTeamTypeTable()

if teamTypes then

    kTeamIndexToType = teamTypes
    -- apply a matchup that was set before this file loaded
    teamTypes[kTeam1Index] = kTeam1Type
    teamTypes[kTeam2Index] = kTeam2Type

else

    Shared.Message("[Vael'Thor] TeamMixin team type table not found - using live kTeam1Type/kTeam2Type lookup.")

    local oldGetTeamTypeFromTeamIndex = GetTeamTypeFromTeamIndex
    function GetTeamTypeFromTeamIndex(teamIdx)
        if teamIdx == kTeam1Index then
            return kTeam1Type
        elseif teamIdx == kTeam2Index then
            return kTeam2Type
        end
        return oldGetTeamTypeFromTeamIndex(teamIdx)
    end

    function TeamMixin:GetTeamType()
        return GetTeamTypeFromTeamIndex(self.teamNumber)
    end

end

end -- VT_HookedTeamTypes
