-- ============================================================================
-- Vael'Thor Empire - shared utility functions
-- (post-hook of lua/NS2Utility.lua)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Infiltrator hack: hacked enemy structures count as inactive. Almost every
-- structure behaviour (whips, crags, hydras, hives, tunnels...) checks
-- GetIsUnitActive() first, so this single hook disables them. Server-only
-- state; clients keep showing the structure normally.
-- ----------------------------------------------------------------------------
if not VT_HookedNS2Utility then
VT_HookedNS2Utility = true

local oldGetIsUnitActive = GetIsUnitActive
function GetIsUnitActive(unit, debug)
    if unit and unit.vtHackedUntil and unit.vtHackedUntil > Shared.GetTime() then
        return false
    end
    return oldGetIsUnitActive(unit, debug)
end

function VT_GetIsHacked(unit)
    return unit ~= nil and unit.vtHackedUntil ~= nil and unit.vtHackedUntil > Shared.GetTime()
end

-- ----------------------------------------------------------------------------
-- Subvention Network
-- ----------------------------------------------------------------------------
local function IsActiveSource(ent)
    return ent:GetIsAlive() and (not HasMixin(ent, "Construct") or ent:GetIsBuilt())
end

-- NOTE: no kVT* constants may be read at load time in this file. On the
-- client NS2Utility.lua is loaded before TechTreeConstants.lua (where the
-- constants are defined), so everything here must look them up when called.
local function GetMaxPylonRadius()
    return math.max(kVTFieldRadiusPylon, kVTResonantFieldRadius)
end

-- Returns field strength at a point: nil (outside), 1 (field) or
-- kVTResonantRegenScalar (inside a Resonant Pylon's field).
function VT_GetFieldStrengthAt(origin)

    local strength

    for _, pylon in ipairs(GetEntitiesForTeamWithinRange("VTSubventionPylon", kVTTeamIndex, origin, GetMaxPylonRadius())) do
        if IsActiveSource(pylon) then
            local radius = pylon.GetVTFieldRadius and pylon:GetVTFieldRadius() or kVTFieldRadiusPylon
            if (pylon:GetOrigin() - origin):GetLength() <= radius then
                if pylon.vtResonant then
                    return kVTResonantRegenScalar
                end
                strength = 1
            end
        end
    end

    if not strength then
        for _, nexus in ipairs(GetEntitiesForTeamWithinRange("VTNexus", kVTTeamIndex, origin, kVTFieldRadiusNexus)) do
            if IsActiveSource(nexus) then
                return 1
            end
        end
    end

    return strength

end

function VT_GetIsPointInField(origin)
    return VT_GetFieldStrengthAt(origin) ~= nil
end

-- Structures are protected by any active Shield Generator; soldiers only by
-- generators upgraded with the Aegis Array.
function VT_GetIsShieldGenProtected(entity)
    local isPlayer = entity:isa("Player")
    for _, gen in ipairs(GetEntitiesForTeamWithinRange("VTShieldGenerator", kVTTeamIndex, entity:GetOrigin(), kVTShieldGenRadius)) do
        if GetIsUnitActive(gen) and (not isPlayer or gen.vtAegis) then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Directives
-- ----------------------------------------------------------------------------
function VT_GetIsEdictActive(techId)
    local info = VT_GetEmpireInfo and VT_GetEmpireInfo()
    if not info then
        return false
    end
    return info:GetEdictEndTime(techId) > Shared.GetTime()
end

-- ----------------------------------------------------------------------------
-- Loadout / caste availability (used by server spawning and client HUD)
-- ----------------------------------------------------------------------------
function VT_GetTeamHasTech(techName)
    if not techName then
        return true
    end
    local techId = kTechId[techName]
    if Server then
        local gamerules = GetGamerules and GetGamerules()
        local team = gamerules and gamerules:GetTeam(kVTTeamIndex)
        local tree = team and team.GetTechTree and team:GetTechTree()
        return tree ~= nil and tree:GetHasTech(techId)
    else
        local player = Client.GetLocalPlayer()
        return player ~= nil and GetHasTech(player, techId, true)
    end
end

-- requirement = { rank = n, tech = "TechIdName" }
function VT_GetMeetsRequirement(requirement, rank)
    if not requirement then
        return true
    end
    if requirement.rank and (rank or 1) < requirement.rank then
        return false
    end
    return VT_GetTeamHasTech(requirement.tech)
end

-- ----------------------------------------------------------------------------
-- Nexus Gate network
-- ----------------------------------------------------------------------------
function VT_GetIsActiveNexusGate(entity)
    return entity ~= nil and entity:isa("VTNexus") and entity:GetTechId() == kTechId.VTNexusGate
            and entity:GetIsBuilt() and entity:GetIsAlive() and VT_GetIsVTEntity(entity)
end

-- Any built pylon on the map can send a soldier to any active Nexus Gate.
-- Returns (hasGates, destinations sorted by distance from the pylon).
function VT_GetGateJumpOptions(pylon)

    if not (pylon and pylon:isa("VTSubventionPylon") and IsActiveSource(pylon)) then
        return false, {}
    end

    local destinations = {}
    for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", kVTTeamIndex)) do
        if VT_GetIsActiveNexusGate(nexus) then
            destinations[#destinations + 1] = nexus
        end
    end
    Shared.SortEntitiesByDistance(pylon:GetOrigin(), destinations)

    return #destinations > 0, destinations

end


-- ----------------------------------------------------------------------------
-- Echo Scan cone (shared by the server's detection and the clients' outlines):
-- calls fn(entity) for every living enemy unit/structure inside the scanner's cone.
-- ----------------------------------------------------------------------------
function VT_ForEachInEchoCone(scanner, fn)
    local eyePos = scanner:GetEyePos()
    local viewDir = scanner:GetViewCoords().zAxis
    local minDot = math.cos(math.rad(kVTEchoPulseHalfAngle))
    local enemyTeam = GetEnemyTeamNumber(scanner:GetTeamNumber())
    for _, entity in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, eyePos, kVTEchoPulseRange)) do
        if entity:GetIsAlive() then
            local point = HasMixin(entity, "Target") and entity:GetEngagementPoint() or entity:GetOrigin()
            local toEntity = point - eyePos
            local dist = toEntity:GetLength()
            if dist < 1 or toEntity:DotProduct(viewDir) / dist >= minDot then
                fn(entity)
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- HUD inventory icons are looked up by tech id in a fixed table; Vael'Thor
-- weapons borrow the icon of the marine weapon they are prototyped on (without
-- this the Plasma Carbine showed the "unknown" skull icon in slot 1).
-- ----------------------------------------------------------------------------
local kVTInventoryIconAlias
local oldGetTexCoordsForTechId = GetTexCoordsForTechId
function GetTexCoordsForTechId(techId)
    kVTInventoryIconAlias = kVTInventoryIconAlias or
    {
        [kTechId.VTPlasmaCarbine]       = kTechId.Rifle,
        [kTechId.VTPsionicBlade]        = kTechId.Axe,
        [kTechId.VTSubjectClaws]        = kTechId.Axe,
        [kTechId.VTPsionicKnife]        = kTechId.Axe,
        [kTechId.VTSingularityLauncher] = kTechId.GrenadeLauncher,
        [kTechId.VTEchoPulse]           = kTechId.Welder,
    }
    return oldGetTexCoordsForTechId(kVTInventoryIconAlias[techId] or techId)
end

end -- VT_HookedNS2Utility
