-- ============================================================================
-- Vael'Thor Empire - detach the empire from the map's power nodes
-- (post-hook of lua/PowerPoint.lua)
--
-- Vael'Thor structures are powered by the Subvention Network instead
-- (see VTTeam:UpdateSubventionNetwork), so power points must never claim them.
-- ============================================================================

if not VT_HookedPowerPoint then
VT_HookedPowerPoint = true

local oldGetCanPower = PowerPoint.GetCanPower
function PowerPoint:GetCanPower(consumer)
    if VT_GetIsVTEntity(consumer) then
        return false
    end
    return oldGetCanPower(self, consumer)
end

-- Power nodes always belong to team 1 in vanilla. In Vael'Thor vs. Marines the
-- marines are team 2 and need them (the empire runs on pylons and treats them
-- as enemy structures, like the aliens do).
if Server then
    local oldOnInitialized = PowerPoint.OnInitialized
    function PowerPoint:OnInitialized(...)
        oldOnInitialized(self, ...)
        if VT_GetMatchup() == kVTMatchup.VTvsMarines then
            self:SetTeamNumber(kTeam2Index)
        end
    end
end

-- The power nodes' impulse (a blue wave every 25 s plus an effect at the structures they power) means nothing
-- to the Vael'Thor: hidden for Vael'Thor viewers, and for everyone in Vael'Thor vs. Aliens, where no team uses
-- power nodes. Vanilla marines (Vael'Thor vs. Marines) keep it. Pylons have no pulse of their own (removed: crash on joining).
if Client then
    local function HideImpulse()
        if VT_GetLocalIsVTTeam and VT_GetLocalIsVTTeam() then
            return true
        end
        return VT_GetMatchup and VT_GetMatchup() == kVTMatchup.VTvsAliens
    end

    local oldCreateImpulseEffect = PowerPoint.CreateImpulseEffect
    function PowerPoint:CreateImpulseEffect(...)
        if HideImpulse() then
            self.lastImpulseEffect = Shared.GetTime()     -- keep vanilla's 25 s timer running, show nothing
            return
        end
        return oldCreateImpulseEffect(self, ...)
    end

    local oldCreateImpulseStructureEffect = PowerPoint.CreateImpulseStructureEffect
    function PowerPoint:CreateImpulseStructureEffect(...)
        if HideImpulse() then
            return
        end
        return oldCreateImpulseStructureEffect(self, ...)
    end
end

end -- VT_HookedPowerPoint
