-- ============================================================================
-- Vael'Thor Empire - vanilla marine turrets in Vael'Thor vs. Marines (server)
-- (loaded from Server.lua, after the game's TargetCache.lua)
--
-- The vanilla Sentry and ARC pick targets from kMarineStaticTargets / kMarineMobileTargets, i.e. entities of
-- the ALIEN team type. In Vael'Thor vs. Marines their enemy is the Vael'Thor team, which is marine-typed, so
-- they would never find a target. When the owner's enemy team is marine-typed, the selector is pointed at the
-- marine-type lists (kAlienStaticTargets / kAlienMobileTargets) and gets an explicit enemy check, since those
-- lists then also contain the turret's own team. Other matchups are left untouched.
-- The Sentinel Obelisk has its own selector (VT_InitObeliskTargeting, Classes/VTStructures.lua).
-- ============================================================================

if not VT_HookedTargetSelectors then
VT_HookedTargetSelectors = true

local function GetEnemyIsMarineTyped(owner)
    local enemyTeam = GetEnemyTeamNumber(owner:GetTeamNumber())
    return GetTeamTypeFromTeamIndex(enemyTeam) == kMarineTeamType
end

-- Re-attaches an existing TargetSelector to the marine-type target lists (in place, so the destroy callback
-- registered by TargetSelector:Init detaches the new lists later).
function VT_PointSelectorAtMarineEnemies(selector, owner)

    for _, targetType in ipairs(selector.targetTypeList) do
        targetType:DetachSelector(selector)
    end

    local targetTypes = { kAlienStaticTargets, kAlienMobileTargets }   -- lists of marine-type entities
    selector.targetTypeList = targetTypes
    selector.targetTypeMap = {}
    for _, targetType in ipairs(targetTypes) do
        selector.targetTypeMap[targetType] = targetType:AttachSelector(selector)
    end

    local filters = {}
    for _, filter in ipairs(selector.filters or {}) do
        filters[#filters + 1] = filter
    end
    filters[#filters + 1] = function(target) return GetAreEnemies(owner, target) end
    selector.filters = filters

end

local function WrapOnInitialized(cls, className)
    local old = cls.OnInitialized
    cls.OnInitialized = function(self, ...)
        old(self, ...)
        -- exact class only: subclasses such as the Sentinel Obelisk set up their own targeting
        if self:GetClassName() == className and self.targetSelector and GetEnemyIsMarineTyped(self) then
            VT_PointSelectorAtMarineEnemies(self.targetSelector, self)
        end
    end
end

WrapOnInitialized(Sentry, "Sentry")
WrapOnInitialized(ARC, "ARC")

end -- VT_HookedTargetSelectors
