-- ============================================================================
-- Vael'Thor Empire - hacked Shades stop cloaking (post-hook of lua/Shade.lua)
--
-- The hack makes structures inactive through GetIsUnitActive, but
-- Shade:UpdateCloaking (every 0.2 s, TriggerCloak on everything within 17 m)
-- never asks. While hacked (vtHackedUntil, Classes/VTHackMarker.lua) a Shade:
--   * cloaks nothing (its units lose the cloak ~0.6 s later),
--   * reveals everything in its field the moment it is hacked (TriggerUncloak
--     holds 2.5 s and beats other Shades' cloaking),
--   * can't fire Shade Ink.
-- ============================================================================

if Shade and not VT_HookedShade then
VT_HookedShade = true

local function GetIsHacked(shade)
    return shade.vtHackedUntil ~= nil and shade.vtHackedUntil > Shared.GetTime()
end

if Server then

    local oldUpdateCloaking = Shade.UpdateCloaking
    function Shade:UpdateCloaking()
        if GetIsHacked(self) then
            return self:GetIsAlive()          -- keep the timed callback alive, cloak nothing
        end
        return oldUpdateCloaking(self)
    end

    -- called by VT_MarkHacked
    function Shade:VT_OnHacked()
        for _, cloakable in ipairs(GetEntitiesWithMixinForTeamWithinRange("Cloakable", self:GetTeamNumber(), self:GetOrigin(), Shade.kCloakRadius)) do
            if cloakable.TriggerUncloak then
                cloakable:TriggerUncloak()
            end
        end
    end

end

local oldPerformActivation = Shade.PerformActivation
function Shade:PerformActivation(techId, position, normal, commander)
    if techId == kTechId.ShadeInk and GetIsHacked(self) then
        return false, true
    end
    return oldPerformActivation(self, techId, position, normal, commander)
end

end -- VT_HookedShade
