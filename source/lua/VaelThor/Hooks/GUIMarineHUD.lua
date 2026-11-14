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

-- The hide above bypasses ClientUI, so nothing ever showed the HUD again: if it was hidden once (a stale team
-- number while switching teams or matchups) the same script stayed hidden for a Marine. Decide again for every
-- new local player, by that player's team, and give the HUD back to ClientUI's verdict for non-Vael'Thor.
local oldOnLocalPlayerChanged = GUIMarineHUD.OnLocalPlayerChanged
function GUIMarineHUD:OnLocalPlayerChanged(newPlayer, ...)
    local isVT = kVTTeamIndex ~= kVTNoTeam and newPlayer and newPlayer:GetTeamNumber() == kVTTeamIndex
    local visible = not isVT and ClientUI.GetScriptVisibility("Hud/Marine/GUIMarineHUD")
    if self:GetIsVisible() ~= visible then
        self:SetIsVisible(visible)
    end
    return oldOnLocalPlayerChanged(self, newPlayer, ...)
end

-- The boot-up animation spawns random blue squares that only fade out in Update, and GUIManager never updates
-- a hidden script: on a hidden HUD (always for the Vael'Thor) they stayed on screen forever and piled up with
-- every new local player (respawn, leaving the main menu). Only play it on a visible HUD.
local oldTriggerInitAnimations = GUIMarineHUD.TriggerInitAnimations
function GUIMarineHUD:TriggerInitAnimations(...)
    local player = Client.GetLocalPlayer()
    if not self:GetIsVisible() or GetLocalIsVT()
            or (player and kVTTeamIndex ~= kVTNoTeam and player:GetTeamNumber() == kVTTeamIndex) then
        return
    end
    return oldTriggerInitAnimations(self, ...)
end

end -- VT_HookedMarineHUD
