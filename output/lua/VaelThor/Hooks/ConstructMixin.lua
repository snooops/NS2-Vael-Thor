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

-- No vanilla construction hologram (ConstructMixin client: build.material added to every marine-type structure
-- while underConstruction): a Vael'Thor building is hidden while it warps in, the singularity is drawn instead
-- (VTBuildingAnim.lua). The hologram is an extra material layer, so it showed through the hidden model.
if Client then
    local oldOnConstructUpdate = ConstructMixin.OnConstructUpdate
    function ConstructMixin:OnConstructUpdate(deltaTime)
        if VT_GetIsVTClass(self) then
            if self.buildMaterial then
                local model = self:GetRenderModel()
                if model then
                    model:RemoveMaterial(self.buildMaterial)
                end
                Client.DestroyRenderMaterial(self.buildMaterial)
                self.buildMaterial = nil
            end
            if self.underConstruction or not self.constructionComplete then
                return kUpdateIntervalLow
            end
            return false
        end
        return oldOnConstructUpdate(self, deltaTime)
    end
end

end -- VT_HookedConstructMixin
