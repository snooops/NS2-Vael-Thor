-- ============================================================================
-- Vael'Thor Empire - Requisition Mandate (faster construction)
-- (post-hook of lua/ConstructMixin.lua)
-- ============================================================================

if not VT_HookedConstructMixin then
VT_HookedConstructMixin = true

local oldConstruct = ConstructMixin.Construct
function ConstructMixin:Construct(elapsedTime, builder)

    if elapsedTime and VT_GetIsVTClass(self)
            and VT_GetIsEdictActive and VT_GetIsEdictActive(kTechId.VTEdictRequisition) then
        elapsedTime = elapsedTime * kVTRequisitionBuildScalar
    end

    return oldConstruct(self, elapsedTime, builder)

end

-- Vael'Thor structures assemble themselves (VTTeam:UpdateAutoConstruction);
-- soldiers can't speed them up by using/building them.
-- Decided by class, not by team: this runs in the client's Predict VM too (Marine:OnUseTarget asks it every
-- frame while E is held and switches back to the weapon on false). A team check there used the default
-- matchup (Vael'Thor = team 1), so team-1 marines in Marines vs. Vael'Thor flickered builder <-> weapon.
local oldGetCanConstruct = ConstructMixin.GetCanConstruct
function ConstructMixin:GetCanConstruct(constructor)
    -- Vael'Thor soldiers never build: neither their own self-assembling
    -- structures nor the map's power nodes (the empire runs on pylons).
    if constructor and (VT_GetIsVTClass(self) or (self:isa("PowerPoint") and VT_GetIsVTClass(constructor))) then
        return false
    end
    return oldGetCanConstruct(self, constructor)
end

end -- VT_HookedConstructMixin
