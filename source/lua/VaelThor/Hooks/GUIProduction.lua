-- ============================================================================
-- Vael'Thor Empire - commander research/production strip (post-hook of lua/GUIProduction.lua).
--
-- Vanilla Commander:SetupHud calls production:SetTeam(self:GetTeamType()), i.e. it passes the
-- team TYPE (marine = 1) as a team INDEX, and GUIProduction uses that one number twice:
-- for the TeamInfo lookup and for the look ("TeamIndex == kTeam1Index" = marine buttons,
-- icons, colours). That only works while marines sit on team 1. In "Marines vs. Vael'Thor"
-- the Vael'Thor commander is team 2 (MarineCommander, type marine); the client has no TeamInfo
-- for team 1, UpdateTech indexed nil and SetupHud aborted halfway (no click manager, no
-- tooltip, an error every frame).
-- Fix: keep TeamIndex (= the look, marine style) and read TeamInfo from the real team
-- (self.vtInfoTeam). Spectators pass real team indices and are left alone.
-- ============================================================================
if GUIProduction and not VT_HookedGUIProduction then
VT_HookedGUIProduction = true

local function GetTeamInfo(teamIndex)
    return teamIndex and GetEntitiesForTeam("TeamInfo", teamIndex)[1]
end

local oldSetTeam = GUIProduction.SetTeam
function GUIProduction:SetTeam(teamIndex, ...)
    self.vtInfoTeam = nil
    local localTeam = Client.GetLocalClientTeamNumber()
    if teamIndex ~= localTeam and localTeam == kVTTeamIndex then
        self.vtInfoTeam = localTeam      -- own commander strip: data from our team, marine look
    end
    return oldSetTeam(self, teamIndex, ...)
end

-- updateState is file-local in GUIProduction.lua; get it from the vanilla UpdateTech.
local updateState
do
    local i = 1
    while true do
        local name, value = debug.getupvalue(GUIProduction.UpdateTech, i)
        if not name then break end
        if name == "updateState" then updateState = value end
        i = i + 1
    end
end

local oldUpdateTech = GUIProduction.UpdateTech
if updateState then

    -- Copy of vanilla UpdateTech; only the TeamInfo lookup differs (+ nil guard).
    function GUIProduction:UpdateTech(onChange)
        local teamInfo = GetTeamInfo(self.vtInfoTeam or self.TeamIndex)
        if not teamInfo then return end
        local techActive, techOwned = teamInfo:GetTeamTechTreeInfo()
        if techActive ~= self.PrevTechActive or techOwned ~= self.PrevTechOwned then
            local relevantIdMask, relevantTechIds = teamInfo:GetRelevantTech()
            for _, techId in ipairs(relevantTechIds) do
                local mask = relevantIdMask[EnumToString(kTechId, techId)]
                local isActive = bit.band(techActive, mask) > 0
                local isOwned = bit.band(techOwned, mask) > 0
                local stateChanged = updateState(self, techId, isActive, isOwned)
                if stateChanged and onChange then
                    onChange(self, techId)
                end
            end
            self.PrevTechActive = techActive
            self.PrevTechOwned = techOwned
        end
    end

else

    Shared.Message("[Vael'Thor] GUIProduction: updateState not found, team-2 research strip stays empty")
    function GUIProduction:UpdateTech(...)
        if self.vtInfoTeam or not GetTeamInfo(self.TeamIndex) then return end
        return oldUpdateTech(self, ...)
    end

end

end -- VT_HookedGUIProduction
