-- ============================================================================
-- Vael'Thor Empire - no corner minimap
-- (post-hook of lua/Hud/Marine/GUIMarineHUD.lua)
--
-- Only for Vael'Thor players: vanilla marines (Marines vs. Aliens, Vael'Thor vs.
-- Marines) keep the normal marine HUD and minimap. The HUD re-reads the "minimap" advanced option on every
-- Update (and options changes rewrite kHudMapEnabled), so force it off right
-- before Initialize/Update instead of setting it once. The location name and
-- the full map (C) are untouched; the Echo Pulse is the team's intel instead.
-- ============================================================================

if GUIMarineHUD and not VT_HookedMarineHUD then
VT_HookedMarineHUD = true

local function GetLocalIsVT()
    return kVTTeamIndex ~= kVTNoTeam and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end

local oldInitialize = GUIMarineHUD.Initialize
function GUIMarineHUD:Initialize(...)
    if GetLocalIsVT() then
        GUIMarineHUD.kHudMapEnabled = false
    end
    return oldInitialize(self, ...)
end

local oldUpdate = GUIMarineHUD.Update
function GUIMarineHUD:Update(...)
    local isVT = GetLocalIsVT()
    if isVT then
        GUIMarineHUD.kHudMapEnabled = false
    end
    local result = oldUpdate(self, ...)
    -- The Vael'Thor have their own HUD (GUI/GUIVTPlayerHUD.lua): keep the marine one hidden.
    if isVT and self:GetIsVisible() then
        self:SetIsVisible(false)
    end
    return result
end

end -- VT_HookedMarineHUD
