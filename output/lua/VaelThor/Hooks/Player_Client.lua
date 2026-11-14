-- ============================================================================
-- Vael'Thor Empire - team-type UI checks (post-hook of lua/Player_Client.lua, client).
--
-- Vanilla PlayerUI_IsOnMarineTeam / PlayerUI_IsOnAlienTeam compare the local team NUMBER with
-- the team TYPE (kMarineTeamType = 1, kAlienTeamType = 2). In "Marines vs. Vael'Thor" the
-- Vael'Thor (a marine-type faction) are team 2, so vanilla treated them as aliens: orange
-- damage numbers and world texts (GUIWorldText), alien chat style (GUIChat), alien countdown
-- logo, the floating location text and the alien minimap arrow colour.
-- The Vael'Thor team (kVTTeamIndex) now always counts as marine-type, never as alien.
-- ============================================================================
if PlayerUI_IsOnMarineTeam and not VT_HookedPlayerUITeam then
VT_HookedPlayerUITeam = true

local function LocalIsVTTeam()
    local player = Client.GetLocalPlayer()
    return player ~= nil and HasMixin(player, "Team") and kVTTeamIndex ~= nil
        and player:GetTeamNumber() == kVTTeamIndex
end

local oldIsOnMarineTeam = PlayerUI_IsOnMarineTeam
function PlayerUI_IsOnMarineTeam(...)
    if LocalIsVTTeam() then return true end
    return oldIsOnMarineTeam(...)
end

local oldIsOnAlienTeam = PlayerUI_IsOnAlienTeam
function PlayerUI_IsOnAlienTeam(...)
    if LocalIsVTTeam() then return false end
    return oldIsOnAlienTeam(...)
end

end -- VT_HookedPlayerUITeam
