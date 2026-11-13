-- ============================================================================
-- Vael'Thor psi shield (Protoss style)
--
-- Every empire soldier and structure has three pools: psi shield -> armor ->
-- health. Only the shield regenerates (VTTeam:UpdateSubventionNetwork); armor
-- and health are never restored (no welding, see Hooks/WeldableMixin.lua).
--
-- Damage flow (server only; Hooks/DamageTypes.lua wraps GetDamageByType):
--   VT_ModifyDamage scalars -> vanilla rules -> ModifyDamageTakenPostRules (this
--   file: the shield absorbs 1:1, the rest goes on to the armor/health split)
--   -> the absorbed amount is returned as vanilla "overshieldDamage", so hit
--   numbers, hit sounds, the combat timer and alerts still work while armor and
--   health stay untouched.
-- Bile Bomb respects the shield (soldiers: handled in Hooks/DamageTypes.lua; structures: absorbed here).
-- gVTShieldBypass stays as a switch for future shield-piercing damage; nothing sets it at the moment.
--
-- Fields vtShield / vtMaxShield are networked (VT_AddShieldNetworkVars). The
-- purple hit shell is drawn client side (Client.lua UpdateShieldGlows).
-- ============================================================================

kVTShieldNetworkVars =
{
    vtShield    = "float (0 to 4000 by 0.25)",
    vtMaxShield = "float (0 to 4000 by 1)",
}

function VT_AddShieldNetworkVars(networkVars)
    for name, def in pairs(kVTShieldNetworkVars) do
        networkVars[name] = def
    end
    return networkVars
end

gVTShieldBypass   = false
gVTShieldAbsorbed = 0

kVTShieldGlowMaterial     = PrecacheAsset("cinematics/vaelthor/shield/psi_shield.material")
kVTShieldGlowViewMaterial = PrecacheAsset("cinematics/vaelthor/shield/psi_shield_view.material")
if Client then
    Shared.PrecacheSurfaceShader("cinematics/vaelthor/shield/psi_shield.surface_shader")
    Shared.PrecacheSurfaceShader("cinematics/vaelthor/shield/psi_shield_view.surface_shader")
end

-- Shield Matrix I-III (own research ids).
function VT_GetShieldMatrixLevel(entity)
    if GetHasTech(entity, kTechId.VTShieldMatrix3, true) then return 3 end
    if GetHasTech(entity, kTechId.VTShieldMatrix2, true) then return 2 end
    if GetHasTech(entity, kTechId.VTShieldMatrix1, true) then return 1 end
    return 0
end

-- Plasma Calibration I-III (own research ids; damage scaling in Hooks/DamageTypes.lua).
function VT_GetPlasmaCalibrationLevel(entity)
    if GetHasTech(entity, kTechId.VTPlasmaCalibration3, true) then return 3 end
    if GetHasTech(entity, kTechId.VTPlasmaCalibration2, true) then return 2 end
    if GetHasTech(entity, kTechId.VTPlasmaCalibration1, true) then return 1 end
    return 0
end

function VT_ComputeMaxShield(entity)
    local base = kVTMaxShield[entity:GetClassName()]
    if not base then
        return 0
    end
    if entity:isa("Player") then
        base = base + VT_GetShieldMatrixLevel(entity) * kVTShieldPerUpgradeLevel
    end
    return base
end

function VT_GetHasShieldPool(entity)
    return entity ~= nil and entity.vtMaxShield ~= nil
end

-- Refresh the max (Shield Matrix research); optionally fill the shield.
function VT_RefreshShield(entity, fill)
    local maxShield = VT_ComputeMaxShield(entity)
    entity.vtMaxShield = maxShield
    if fill then
        entity.vtShield = maxShield
    else
        entity.vtShield = math.min(entity.vtShield or 0, maxShield)
    end
end

function VT_SetShield(entity, amount)
    if VT_GetHasShieldPool(entity) then
        entity.vtShield = Clamp(amount, 0, entity.vtMaxShield or 0)
    end
end

-- ----------------------------------------------------------------------------
-- Class installer
-- ----------------------------------------------------------------------------
local Shield_ = {}

function Shield_:VT_GetShield()
    return self.vtShield or 0
end

function Shield_:VT_GetMaxShield()
    return self.vtMaxShield or 0
end

-- Runs after the damage-type rules, before the armor/health split (GetDamageByType).
function Shield_:ModifyDamageTakenPostRules(damageTable, attacker, doer, damageType, hitPoint)

    if Server and not gVTShieldBypass and damageTable.damage > 0 and (self.vtShield or 0) > 0
            and VT_GetIsEmpireEntity(self) then

        local absorbed = math.min(self.vtShield, damageTable.damage)
        self.vtShield = self.vtShield - absorbed
        damageTable.damage = damageTable.damage - absorbed
        gVTShieldAbsorbed = gVTShieldAbsorbed + absorbed

    end

    return damageTable.damage, damageTable.armorFractionUsed, damageTable.healthPerArmor

end

-- cls: the class table. fillOnInit: players start with a full shield; structures
-- get theirs when construction is complete (VTTeam:UpdateSubventionNetwork).
function VT_InstallShield(cls, fillOnInit)

    for name, func in pairs(Shield_) do
        cls[name] = func
    end

    local baseOnCreate = cls.OnCreate
    function cls:OnCreate(...)
        baseOnCreate(self, ...)
        self.vtShield = 0
        self.vtMaxShield = 0
    end

    if fillOnInit then
        local baseOnInitialized = cls.OnInitialized
        function cls:OnInitialized(...)
            if baseOnInitialized then
                baseOnInitialized(self, ...)
            end
            if Server then
                VT_RefreshShield(self, true)
                self.vtShieldReady = true
            end
        end
    end

end

