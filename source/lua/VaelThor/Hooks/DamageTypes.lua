-- ============================================================================
-- Vael'Thor Empire - damage rules
-- (post-hook of lua/DamageTypes.lua)
--
-- One central place for every Vael'Thor damage modifier:
--   * Relentless Advance edict   : +20% damage dealt by the empire
--   * weapon-specific scalars     : doer:GetVTDamageScalar(target) (Overcharge Core...)
--   * Shield Generator            : -50% ranged damage to protected structures
--   * psi shield layer + Bile Bomb rule (see GetDamageByType below; bile respects the shield)
-- Applied in Client and Server so predicted damage numbers stay consistent.
-- ============================================================================

function VT_ModifyDamage(target, attacker, doer, damage)

    if not damage or damage <= 0 then
        return damage
    end

    local scalar = 1

    if VT_GetIsVTEntity(attacker) then

        if VT_GetIsEdictActive and VT_GetIsEdictActive(kTechId.VTEdictRelentless) then
            scalar = scalar * kVTRelentlessDamageScalar
        end

        if doer and doer.GetVTDamageScalar then
            scalar = scalar * doer:GetVTDamageScalar(target)
        end

    end

    -- Iron Discipline: imperial soldiers take less damage.
    if VT_GetIsEmpireEntity(target) and target:isa("Player")
            and VT_GetIsEdictActive and VT_GetIsEdictActive(kTechId.VTEdictIronDiscipline) then
        scalar = scalar * kVTIronDisciplineDamageScalar
    end

    -- Shield Generator (structures) / Aegis Array (also soldiers): ranged damage.
    if VT_GetIsEmpireEntity(target) and attacker and attacker.GetOrigin then

        local distance = (attacker:GetOrigin() - target:GetOrigin()):GetLength()
        if distance > kVTShieldGenMeleeRange and VT_GetIsShieldGenProtected and VT_GetIsShieldGenProtected(target) then
            scalar = scalar * kVTShieldGenDamageScalar
        end

    end

    return damage * scalar

end

if not VT_HookedDamageTypes then
VT_HookedDamageTypes = true

-- Plasma Calibration: the Vael'Thor have their own upgrade ids, so the vanilla
-- Weapons1-3 scaling (and any mod changing it) never applies to them.
local oldGetUpgradedDamageScalar = NS2Gamerules_GetUpgradedDamageScalar
function NS2Gamerules_GetUpgradedDamageScalar(attacker, weaponTechId)
    if VT_GetIsVTEntity(attacker) then
        local level = VT_GetPlasmaCalibrationLevel and VT_GetPlasmaCalibrationLevel(attacker) or 0
        return kVTPlasmaCalibrationScalars[level] or 1
    end
    return oldGetUpgradedDamageScalar(attacker, weaponTechId)
end

local function GetIsBileBomb(doer)
    return doer ~= nil and doer.GetTechId ~= nil and doer:GetTechId() == kTechId.BileBomb
end

local oldGetDamageByType = GetDamageByType
function GetDamageByType(target, attacker, doer, damage, damageType, hitPoint, weapon)

    local rawDamage = damage
    if target and attacker then
        damage = VT_ModifyDamage(target, attacker, doer, damage)
    end

    -- Bile Bomb respects the psi shield. Soldiers: kVTBileArmorFraction of the raw
    -- bile damage drains the shield first, the rest hits armor; never health.
    -- Structures: the shield absorbs first (ModifyDamageTakenPostRules below), the
    -- remainder takes the vanilla bile rules.
    local isBile = target ~= nil and GetIsBileBomb(doer) and VT_GetIsEmpireEntity(target)
    if isBile and target:isa("Player") then
        if not CanEntityDoDamageTo(attacker, target, Shared.GetCheatsEnabled(), Shared.GetDevMode(), GetFriendlyFire(), damageType) then
            return 0, 0, 0, 0
        end
        local amount = (rawDamage or 0) * kVTBileArmorFraction
        local shieldUsed = math.min(target.vtShield or 0, amount)
        if Server and shieldUsed > 0 then
            target.vtShield = target.vtShield - shieldUsed     -- client: prediction only, the server owns the pool
        end
        local armorUsed = math.min(target:GetArmor(), amount - shieldUsed)
        -- shieldUsed goes out as vanilla "overshield" damage like any other shield hit
        return armorUsed, armorUsed, 0, shieldUsed
    end

    -- Psi shield: absorbed in ModifyDamageTakenPostRules (Classes/VTShield.lua) and
    -- handed back as vanilla "overshield" damage: counts for hit numbers, sounds and
    -- the combat timer, but LiveMixin only subtracts armorUsed / healthUsed.
    gVTShieldBypass = false
    gVTShieldAbsorbed = 0
    local finalDamage, armorUsed, healthUsed, overshieldDamage = oldGetDamageByType(target, attacker, doer, damage, damageType, hitPoint, weapon)
    gVTShieldBypass = false
    local absorbed = gVTShieldAbsorbed or 0
    gVTShieldAbsorbed = 0

    return finalDamage, armorUsed, healthUsed, (overshieldDamage or 0) + absorbed

end

end -- VT_HookedDamageTypes
