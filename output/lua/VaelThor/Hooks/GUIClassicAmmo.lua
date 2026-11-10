-- ============================================================================
-- Vael'Thor Empire - hide the crosshair ammo readout (post-hook of lua/GUIClassicAmmo.lua).
-- Weapon energy/ammo is on the Vael'Thor HUD (GUI/GUIVTPlayerHUD.lua).
-- ============================================================================
if GUIClassicAmmo and not VT_HookedClassicAmmo then
VT_HookedClassicAmmo = true
local oldUpdate = GUIClassicAmmo.Update
function GUIClassicAmmo:Update(...)
    local result = oldUpdate(self, ...)
    if Client.GetLocalClientTeamNumber() == kVTTeamIndex and self.ammoText then
        self.ammoText:SetIsVisible(false)
    end
    return result
end
end -- VT_HookedClassicAmmo
