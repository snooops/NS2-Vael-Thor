-- ============================================================================
-- Vael'Thor Empire - no repairs for anything of the empire
-- (post-hook of lua/WeldableMixin.lua)
--
-- Nothing of the empire can be welded (structures, soldiers, Praetors): armor
-- and health are permanent; only the psi shield recharges, after a cooldown
-- without damage (Classes/VTShield.lua, VTTeam:UpdateSubventionNetwork).
-- Power nodes are excluded (VT_GetIsEmpireEntity) and stay weldable.
-- ============================================================================

if not VT_HookedWeldableMixin then
VT_HookedWeldableMixin = true

local oldGetCanBeWelded = WeldableMixin.GetCanBeWelded
function WeldableMixin:GetCanBeWelded(doer)
    if VT_GetIsEmpireEntity and VT_GetIsEmpireEntity(self) then
        return false
    end
    return oldGetCanBeWelded(self, doer)
end

end -- VT_HookedWeldableMixin
