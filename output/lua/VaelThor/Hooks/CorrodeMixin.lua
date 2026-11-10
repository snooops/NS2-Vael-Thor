-- ============================================================================
-- Vael'Thor Empire - infestation vs. the psi shield
-- (post-hook of lua/CorrodeMixin.lua)
--
-- Vanilla drains 30 armor per second from marine structures standing on
-- infestation (kCorrodeMarineStructureArmorOnInfestation). Empire armor is never
-- restored, so for empire structures the creep eats the regenerating psi shield
-- instead and blocks its regeneration while they stand on it (VTTeam).
-- Armor and health are left alone. Power nodes keep the vanilla behaviour.
-- ============================================================================

if not VT_HookedCorrodeMixin then
VT_HookedCorrodeMixin = true

local oldCorrodeOnInfestation = CorrodeMixin.CorrodeOnInfestation
function CorrodeMixin:CorrodeOnInfestation()

    if not (VT_GetHasShieldPool and VT_GetHasShieldPool(self) and VT_GetIsEmpireEntity(self)) then
        return oldCorrodeOnInfestation(self)
    end

    if self.updateInitialInfestationCorrodeState and GetIsPointOnInfestation(self:GetOrigin()) then
        self:SetGameEffectMask(kGameEffect.OnInfestation, true)
        self.updateInitialInfestationCorrodeState = false
    end

    if self:GetGameEffectMask(kGameEffect.OnInfestation) and self:GetCanTakeDamage()
            and (not HasMixin(self, "GhostStructure") or not self:GetIsGhostStructure()) then

        self:SetCorroded()
        self.vtShieldRegenBlockedUntil = Shared.GetTime() + kVTInfestationRegenBlock
        if (self.vtShield or 0) > 0 then
            self.vtShield = math.max(0, self.vtShield - kInfestationCorrodeDamagePerSecond)
        end

    end

    return true -- keep the 1 s timer running

end

end -- VT_HookedCorrodeMixin
