-- ============================================================================
-- Vael'Thor Empire - no exo eject badge for the Praetor (post-hook of lua/GUIExoEject.lua).
-- Since the 2026-11-17 game update every Exo shows "Hold G to eject"; the Praetor is a caste, not a pilot in a
-- suit (VTPraetor:GetCanEject = false, Drop is filtered). Its ability is on the Vael'Thor HUD.
-- ============================================================================
if GUIExoEject and not VT_HookedGUIExoEject then
VT_HookedGUIExoEject = true

local oldUpdate = GUIExoEject.Update
function GUIExoEject:Update(...)
    local result = oldUpdate(self, ...)
    local player = Client.GetLocalPlayer()
    if player and player:isa("VTPraetor") then
        if self.button then
            self.button:SetIsVisible(false)
        end
        if self.abilityButton then
            self.abilityButton:SetIsVisible(false)
        end
    end
    return result
end

end -- VT_HookedGUIExoEject
