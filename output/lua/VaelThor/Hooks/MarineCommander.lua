-- ============================================================================
-- Vael'Thor Empire - Supreme Archon (commander) menus
-- (post-hook of lua/MarineCommander.lua)
-- ============================================================================

local N = kTechId.None

local gVTMenuButtons =
{
    [kTechId.BuildMenu] =
    {
        kTechId.VTNexus, kTechId.VTSiphon, kTechId.VTSubventionPylon, kTechId.VTSynthesisChamber,
        kTechId.VTShieldGenerator, kTechId.VTRiftPortal, kTechId.VTSentinelObelisk, kTechId.VTPsionicSpire,
    },

    -- Directives are issued from the Imperial Nexus (select it). The Assist
    -- menu holds the cheap, repeatable support abilities.
    [kTechId.AdvancedMenu] = { N, N, N, N, N, N, N, N },
    [kTechId.AssistMenu]   = { kTechId.VTShieldPulse, kTechId.VTRiftRecall, N, N, N, N, N, N },
}

local gVTMenuIds = {}
for menuId, _ in pairs(gVTMenuButtons) do
    gVTMenuIds[#gVTMenuIds + 1] = menuId
end

-- Only the Vael'Thor commander (Supreme Archon) gets these menus; a vanilla
-- marine commander (Marines vs. Aliens / Vael'Thor vs. Marines) keeps the
-- vanilla ones.
if not VT_HookedMarineCommanderMenus then
VT_HookedMarineCommanderMenus = true

local function GetIsArchon(self)
    return VT_GetIsVTTeam(self:GetTeamNumber())
end

local oldGetButtonTable = MarineCommander.GetButtonTable
function MarineCommander:GetButtonTable()
    if not GetIsArchon(self) then
        return oldGetButtonTable(self)
    end
    return gVTMenuButtons
end

local oldGetMenuIds = MarineCommander.GetMenuIds
function MarineCommander:GetMenuIds()
    if not GetIsArchon(self) then
        return oldGetMenuIds(self)
    end
    return gVTMenuIds
end

local oldGetIsInQuickMenu = MarineCommander.GetIsInQuickMenu
function MarineCommander:GetIsInQuickMenu(techId)
    if not GetIsArchon(self) then
        return oldGetIsInQuickMenu(self, techId)
    end
    return Commander.GetIsInQuickMenu(self, techId)
end

local oldGetQuickMenuTechButtons = MarineCommander.GetQuickMenuTechButtons
function MarineCommander:GetQuickMenuTechButtons(techId)

    if not GetIsArchon(self) then
        return oldGetQuickMenuTechButtons(self, techId)
    end

    local buttons = { kTechId.BuildMenu, kTechId.AdvancedMenu, kTechId.AssistMenu, kTechId.RootMenu }
    local menuButtons = gVTMenuButtons[techId] or { N, N, N, N, N, N, N, N }
    table.copy(menuButtons, buttons, true)
    return buttons

end

end -- VT_HookedMarineCommanderMenus

-- ----------------------------------------------------------------------------
-- Support abilities (server)
-- ----------------------------------------------------------------------------
if Server and not VT_HookedMarineCommanderAbilities then
VT_HookedMarineCommanderAbilities = true

local function GetSoldiers(teamNumber, origin, radius)
    local soldiers = {}
    for _, player in ipairs(GetEntitiesForTeamWithinRange("Player", teamNumber, origin, radius)) do
        if player:GetIsAlive() and not player:isa("Commander") then
            soldiers[#soldiers + 1] = player
        end
    end
    return soldiers
end

-- Shield Pulse: full shields for every soldier around the target point.
local function TriggerShieldPulse(self, position)

    local soldiers = GetSoldiers(self:GetTeamNumber(), position, kVTShieldPulseRadius)
    if #soldiers == 0 then
        return false
    end

    for _, soldier in ipairs(soldiers) do
        VT_SetShield(soldier, soldier.vtMaxShield or 0)   -- psi shield only; armor is permanent
        soldier:TriggerEffects("catpack_pickup")
    end

    return true

end

-- Rift Recall: teleport one soldier next to the nearest active Rift Portal.
local function TriggerRiftRecall(self, position, targetId)

    local teamNumber = self:GetTeamNumber()

    local target = targetId and targetId ~= Entity.invalidId and Shared.GetEntity(targetId)
    if not (target and target:isa("Player") and target:GetTeamNumber() == teamNumber and target:GetIsAlive()
            and not target:isa("Commander")) then
        local nearby = GetSoldiers(teamNumber, position, kVTRiftRecallTargetRange)
        Shared.SortEntitiesByDistance(position, nearby)
        target = nearby[1]
    end

    if not target then
        return false
    end

    local portals = {}
    for _, portal in ipairs(GetEntitiesForTeam("VTRiftPortal", teamNumber)) do
        if GetIsUnitActive(portal) then
            portals[#portals + 1] = portal
        end
    end
    if #portals == 0 then
        return false
    end
    Shared.SortEntitiesByDistance(target:GetOrigin(), portals)

    local height, radius = target:GetTraceCapsule()
    local destination = GetRandomSpawnForCapsule(height, radius, portals[1]:GetOrigin(), 1.5, 4, EntityFilterAll())
    if not destination then
        return false
    end

    target:TriggerEffects("phase_gate_player_teleport")
    target:SetOrigin(destination)
    target:SetVelocity(Vector(0, 0, 0))
    target:TriggerEffects("phase_gate_player_teleport")

    return true

end

local kAbilityHandlers =
{
    [kTechId.VTShieldPulse] = TriggerShieldPulse,
    [kTechId.VTRiftRecall]  = TriggerRiftRecall,
}

-- Focus Beam (selected Sentinel Obelisks): the clicked enemy, or the nearest enemy within 2.5 m of the click.
-- No enemy there = release the focus (the Obelisk picks its targets on its own again).
local kFocusPickRadius = 2.5

local function GetFocusTarget(self, position, trace, targetId)

    local function IsEnemy(ent)
        return ent and HasMixin(ent, "Live") and ent:GetIsAlive() and ent:GetCanTakeDamage()
                and GetAreEnemies(self, ent)
    end

    local target = targetId and targetId ~= Entity.invalidId and Shared.GetEntity(targetId)
    if IsEnemy(target) then
        return target
    end
    if trace and IsEnemy(trace.entity) then
        return trace.entity
    end

    local nearest, nearestDist
    for _, ent in ipairs(GetEntitiesWithMixinWithinRange("Live", position, kFocusPickRadius)) do
        if IsEnemy(ent) then
            local dist = (ent:GetOrigin() - position):GetLengthSquared()
            if not nearestDist or dist < nearestDist then
                nearest, nearestDist = ent, dist
            end
        end
    end
    return nearest

end

local oldProcessTechTreeActionForEntity = MarineCommander.ProcessTechTreeActionForEntity
function MarineCommander:ProcessTechTreeActionForEntity(techNode, position, normal, pickVec, orientation, entity, trace, targetId)

    local techId = techNode:GetTechId()

    if techId == kTechId.VTObeliskFocus then
        if not (entity and entity:isa("VTSentinelObelisk") and entity:GetIsBuilt() and entity:GetIsAlive()) then
            return false, true
        end
        entity:VT_SetFocusTarget(GetFocusTarget(self, position, trace, targetId))
        return true, true     -- keep going: every selected Obelisk gets the same focus
    end

    local handler = kAbilityHandlers[techId]

    if handler then

        if self:GetTeam():GetTeamResources() < GetCostForTech(techId) then
            self:TriggerNotEnoughResourcesAlert()
            return false, false
        end

        local success = handler(self, position, targetId)
        if success then
            self:ProcessSuccessAction(techId)   -- pays the team-resource cost
        end
        return success, false

    end

    return oldProcessTechTreeActionForEntity(self, techNode, position, normal, pickVec, orientation, entity, trace, targetId)

end

end -- VT_HookedMarineCommanderAbilities
