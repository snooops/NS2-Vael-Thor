-- ============================================================================
-- VTTeam - the Vael'Thor Empire as team 1 (server only).
--
-- Derived from MarineTeam so the engine-level marine team type keeps working,
-- but with its own:
--   * Synthesis Matrix spawning   (no Infantry Portals, caste quotas, loadouts)
--   * Subvention Network          (structure power + psi shield/ammo regen fields)
--   * tech tree
-- ============================================================================

class 'VTTeam' (MarineTeam)

local N = kTechId.None
local kMatrixUpdateInterval = 0.25
local kNoSpawnMessageInterval = 20

-- Caste -> entity class name used for quota counting.
local kCasteClassNames =
{
    Infiltrator = "VTInfiltrator",
    Subject     = "VTSubject",
    Praetor     = "VTPraetor",
}

local kClassToCaste =
{
    [kVTClass.Infiltrator] = "Infiltrator",
    [kVTClass.Subject]     = "Subject",
    [kVTClass.Praetor]     = "Praetor",
}

local kClassTechIds =
{
    [kVTClass.Vanguard]    = kTechId.VTVanguard,
    [kVTClass.Infiltrator] = kTechId.VTInfiltrator,
    [kVTClass.Subject]     = kTechId.VTSubject,
    [kVTClass.Praetor]     = kTechId.VTPraetor,
}

-- ----------------------------------------------------------------------------
-- Messaging
-- ----------------------------------------------------------------------------
function VT_SendMessageToPlayer(player, text)
    Server.SendNetworkMessage(player, "Chat",
            BuildChatMessage(true, "Supreme Archon", -1, kVTTeamIndex, kMarineTeamType, text), true)
end

function VT_AnnounceToTeam(key)
    local gamerules = GetGamerules()
    local team = gamerules and gamerules:GetTeam(kVTTeamIndex)
    if not team then
        return
    end
    local text = VT_GetString(key)
    for _, player in ipairs(team:GetPlayers()) do
        VT_SendMessageToPlayer(player, text)
    end
end

-- ----------------------------------------------------------------------------
-- Setup
-- ----------------------------------------------------------------------------
function VTTeam:Initialize(teamName, teamNumber)

    MarineTeam.Initialize(self, teamName, teamNumber)

    self.respawnEntity = VTVanguard.kMapName
    self.vtNextFieldUpdate = 0
    self.vtNextMatrixUpdate = 0
    self.vtNextAutoBuild = 0
    self.vtLastNoSpawnMessage = 0

end

function VTTeam:GetSpectatorMapName()
    return VTSpectator.kMapName
end

function VTTeam:AddPlayer(player)
    -- Skip MarineTeam's free-Infantry-Portal logic.
    PlayingTeam.AddPlayer(self, player)
end

-- The start location's power node stays OFF for the Vael'Thor (user design: they run on the Subvention field,
-- not on power nodes). MarineTeam:OnResetComplete builds it via GetPowerPointForLocation and then applies the
-- commander's skins; the lookup is hidden for that one call so everything else still runs. Only VTTeam is
-- affected: a vanilla marine team (Vael'Thor vs. Marines) keeps its powered start.
function VTTeam:OnResetComplete()
    local oldGetPowerPointForLocation = GetPowerPointForLocation
    GetPowerPointForLocation = function() return nil end
    local ok, err = pcall(MarineTeam.OnResetComplete, self)
    GetPowerPointForLocation = oldGetPowerPointForLocation
    if not ok then
        error(err)
    end
end

function VTTeam:SpawnInitialStructures(techPoint)

    self.warmupStructures = {}
    self.startTechPoint = techPoint
    self.spawnedInfantryPortal = 0

    -- Nexus + resource siphon; the Nexus is also the first spawn point.
    local tower, nexus = PlayingTeam.SpawnInitialStructures(self, techPoint)

    -- Siphons only work inside the Subvention field: the starting siphon always
    -- gets a free, fully built pylon next to it.
    if tower then
        self:SpawnStartingPylon(tower)
    end

    return tower, nexus

end

-- Pylon footprint used for placement (radius, height of the trace capsule).
local kStartPylonRadius = 0.6
local kStartPylonHeight = 1.0
-- Search rings around the siphon: { min distance, max distance }.
local kStartPylonRanges = { { 2.5, 5 }, { 2.5, 9 }, { 2, 14 } }
-- Search from above the siphon's base, like the vanilla Infantry Portal
-- placement does, so the trace finds floor around the tower.
local kStartPylonSearchLift = Vector(0, 1, 0)

function VTTeam:SpawnStartingPylon(tower)

    local origin = tower:GetOrigin()
    local position

    for _, range in ipairs(kStartPylonRanges) do
        position = GetRandomSpawnForCapsule(kStartPylonHeight, kStartPylonRadius, origin + kStartPylonSearchLift, range[1], range[2], EntityFilterAll())
        if position then
            break
        end
    end

    if not position then
        Shared.Message("[Vael'Thor] Warning: no room for the starting Subvention Pylon next to the Resource Siphon")
        return nil
    end

    local pylon = CreateEntity(VTSubventionPylon.kMapName, position, self:GetTeamNumber())
    if not pylon then
        Shared.Message("[Vael'Thor] Warning: failed to create the starting Subvention Pylon")
        return nil
    end

    SetRandomOrientation(pylon)
    pylon:SetConstructionComplete()

    -- Power the siphon right away instead of waiting for the next field tick.
    if HasMixin(tower, "PowerConsumer") and tower.SetPowerOn then
        tower:SetPowerOn()
    end

    Shared.Message(string.format("[Vael'Thor] Starting Subvention Pylon placed %.1fm from the Resource Siphon",
            (position - origin):GetLength()))

    return pylon

end

function VTTeam:SpawnWarmUpStructures()
end

function VTTeam:CheckForNoIPs()
end

function VTTeam:OnRespawnQueueChanged()
end

function VTTeam:GetTotalInRespawnQueue()
    return self.respawnQueue:GetCount()
end

function VTTeam:GetHasAbilityToRespawn()
    return #self:GetSynthesisHosts() > 0
end

-- ----------------------------------------------------------------------------
-- Tech tree
-- ----------------------------------------------------------------------------
function VTTeam:InitTechTree()

    PlayingTeam.InitTechTree(self)

    local t = self.techTree

    -- Core
    t:AddBuildNode(kTechId.VTNexus,        N, N)
    -- Nexus Gate: an upgraded Nexus still counts as a Nexus for every prereq.
    -- isRequired = true is essential: the team only tracks structure tech ids
    -- that are some node's prereq or marked required (PlayingTeam:TechAdded).
    -- Without it, upgraded Nexuses vanish from the tech tree and everything
    -- needing a Nexus greys out. kTechDataUpgradeTech (TechData) then makes
    -- the gate count towards kTechId.VTNexus.
    t:AddBuildNode(kTechId.VTNexusGate,           N, N, true)
    t:AddTechInheritance(kTechId.VTNexus,  kTechId.VTNexusGate)
    t:AddUpgradeNode(kTechId.VTNexusGateUpgrade,  kTechId.VTNexus, N)
    t:AddBuildNode(kTechId.VTSiphon,             N, N)
    t:AddUpgradeNode(kTechId.Recycle,             N, N)
    t:AddPassive(kTechId.SpawnMarine)
    t:AddPassive(kTechId.CollectResources,        kTechId.VTSiphon)
    t:AddSpecial(kTechId.TwoCommandStations)
    t:AddSpecial(kTechId.ThreeCommandStations)

    -- Structures
    t:AddBuildNode(kTechId.VTSubventionPylon,     N,                          N)
    t:AddBuildNode(kTechId.VTSynthesisChamber,    kTechId.VTNexus,     N)
    t:AddBuildNode(kTechId.VTShieldGenerator,     kTechId.VTSynthesisChamber, N)
    t:AddBuildNode(kTechId.VTRiftPortal,          kTechId.VTAuthorizationTier2, N, true)
    t:AddBuildNode(kTechId.VTSentinelObelisk,     kTechId.VTSynthesisChamber, N)
    t:AddBuildNode(kTechId.VTPsionicSpire,        kTechId.VTAuthorizationTier2, N)

    -- Per-structure upgrades (repeatable, one per structure)
    t:AddUpgradeNode(kTechId.VTResonantPylonUpgrade, kTechId.VTSynthesisChamber, N)
    t:AddUpgradeNode(kTechId.VTAegisArrayUpgrade,    kTechId.VTAuthorizationTier2, N)
    -- Sentinel Obelisk lenses (Trinity only shows on an Obelisk that already has the Prism Lens)
    t:AddUpgradeNode(kTechId.VTObeliskPrismUpgrade,   N, N)
    t:AddUpgradeNode(kTechId.VTObeliskTrinityUpgrade, kTechId.VTAuthorizationTier2, N)
    -- Sentinel Obelisk commander controls (selected Obelisk)
    t:AddTargetedActivation(kTechId.VTObeliskFocus,  N, N)
    t:AddActivation(kTechId.VTObeliskBeams1,         N, N)
    t:AddActivation(kTechId.VTObeliskBeams2,         N, N)
    t:AddActivation(kTechId.VTObeliskBeams3,         N, N)

    -- Nexus: Archon's Throne unlocks the third Directive
    t:AddResearchNode(kTechId.VTArchonsThrone,       kTechId.VTNexus, kTechId.VTAuthorizationTier2)
    t:AddActivation(kTechId.VTEdictIronDiscipline,   kTechId.VTArchonsThrone, N)
    t:AddMenu(kTechId.VTQuotaMenu)

    -- Psionic Spire research
    t:AddResearchNode(kTechId.VTPhaseCloakTech,      kTechId.VTPsionicSpire, N)
    t:AddResearchNode(kTechId.VTNeuralOverrideTech,  kTechId.VTPsionicSpire, N)
    t:AddResearchNode(kTechId.VTPsionicEdictsTech,   kTechId.VTPsionicSpire, N)

    -- Commander support abilities (Assist menu)
    t:AddTargetedActivation(kTechId.VTShieldPulse,   N, N)
    t:AddTargetedActivation(kTechId.VTRiftRecall,    kTechId.VTRiftPortal, N)

    -- Directives and caste quotas (Nexus)
    t:AddActivation(kTechId.VTEdictRequisition,   N, N)
    t:AddActivation(kTechId.VTEdictRelentless,    N, N)
    t:AddActivation(kTechId.VTQuotaInfiltratorUp, N, N)
    t:AddActivation(kTechId.VTQuotaInfiltratorDown, N, N)
    t:AddActivation(kTechId.VTQuotaSubjectUp,     N, N)
    t:AddActivation(kTechId.VTQuotaSubjectDown,   N, N)
    t:AddActivation(kTechId.VTQuotaPraetorUp,     N, N)
    t:AddActivation(kTechId.VTQuotaPraetorDown,   N, N)

    -- Synthesis Chamber research
    t:AddResearchNode(kTechId.VTAuthorizationTier2,  kTechId.VTSynthesisChamber,   N)
    t:AddResearchNode(kTechId.VTAuthorizationTier3,  kTechId.VTAuthorizationTier2, N)
    t:AddResearchNode(kTechId.VTOverchargeTech,      kTechId.VTSynthesisChamber,   N)
    t:AddResearchNode(kTechId.VTPhaseDashTech,       kTechId.VTSynthesisChamber,   N)
    t:AddResearchNode(kTechId.VTTargetingVisorTech,  kTechId.VTShieldGenerator,    N)
    t:AddResearchNode(kTechId.VTShieldOverdriveTech, kTechId.VTAuthorizationTier2, N)
    t:AddResearchNode(kTechId.VTSingularityTech,     kTechId.VTAuthorizationTier3, N)

    -- Plasma Calibration / Shield Matrix (re-used marine upgrade ids so the
    -- engine's damage and armor scaling applies automatically). Prereqs must
    -- have lower tech ids than Weapons1/Armor1, so the Vael'Thor ids can't be
    -- used here; the buttons only exist on the Synthesis Chamber anyway.
    t:AddResearchNode(kTechId.Weapons1, N, N)
    t:AddResearchNode(kTechId.Weapons2, kTechId.Weapons1,       N)
    t:AddResearchNode(kTechId.Weapons3, kTechId.Weapons2,       N)
    t:AddResearchNode(kTechId.Armor1,   N, N)
    t:AddResearchNode(kTechId.Armor2,   kTechId.Armor1,         N)
    t:AddResearchNode(kTechId.Armor3,   kTechId.Armor2,         N)

    -- Items handed out by the matrix
    t:AddBuyNode(kTechId.VTPlasmaCarbine,       N, N)
    t:AddBuyNode(kTechId.VTPsionicBlade,        N, N)
    t:AddBuyNode(kTechId.VTSubjectClaws,        N, N)
    t:AddBuyNode(kTechId.VTSingularityLauncher, kTechId.VTSingularityTech, N)
    t:AddBuyNode(kTechId.Axe,                   N, N)
    t:AddBuyNode(kTechId.Pistol,                N, N)

    -- Orders and doors
    t:AddOrder(kTechId.Defend)
    t:AddBuildNode(kTechId.Door, N, N)
    t:AddActivation(kTechId.DoorOpen)
    t:AddActivation(kTechId.DoorClose)
    t:AddActivation(kTechId.DoorLock)
    t:AddActivation(kTechId.DoorUnlock)

    t:SetComplete()

end

-- Per-structure upgrades are applied to the structure that researched them.
function VTTeam:OnResearchComplete(structure, researchId)

    if structure then
        if researchId == kTechId.VTResonantPylonUpgrade and structure:isa("VTSubventionPylon") then
            structure.vtResonant = true
        elseif researchId == kTechId.VTAegisArrayUpgrade and structure:isa("VTShieldGenerator") then
            structure.vtAegis = true
        elseif researchId == kTechId.VTObeliskPrismUpgrade and structure:isa("VTSentinelObelisk") then
            structure.vtBeamLevel = math.max(structure.vtBeamLevel or 0, 1)
        elseif researchId == kTechId.VTObeliskTrinityUpgrade and structure:isa("VTSentinelObelisk") then
            structure.vtBeamLevel = 2
        elseif researchId == kTechId.VTNexusGateUpgrade and structure:isa("VTNexus") then
            structure:UpgradeToTechId(kTechId.VTNexusGate)
        end
    end

    MarineTeam.OnResearchComplete(self, structure, researchId)

end

-- ----------------------------------------------------------------------------
-- Update
-- ----------------------------------------------------------------------------
local function GetArmorLevel(self)
    local tree = self:GetTechTree()
    if tree then
        if tree:GetHasTech(kTechId.Armor3) then return 3 end
        if tree:GetHasTech(kTechId.Armor2) then return 2 end
        if tree:GetHasTech(kTechId.Armor1) then return 1 end
    end
    return 0
end

function VTTeam:Update(timePassed)

    PROFILE("VTTeam:Update")

    PlayingTeam.Update(self, timePassed)

    local armorLevel = GetArmorLevel(self)
    for _, player in ipairs(GetEntitiesForTeam("Player", self:GetTeamNumber())) do
        if player.UpdateArmorAmount then
            player:UpdateArmorAmount(armorLevel)
        end
    end

    local now = Shared.GetTime()

    if now >= self.vtNextFieldUpdate then
        self.vtNextFieldUpdate = now + kVTFieldUpdateInterval
        self:UpdateSubventionNetwork(kVTFieldUpdateInterval)
    end

    if now >= self.vtNextAutoBuild then
        local elapsed = now - (self.vtLastAutoBuild or now)
        self.vtLastAutoBuild = now
        self.vtNextAutoBuild = now + kVTAutoBuildInterval
        if elapsed > 0 then
            self:UpdateAutoConstruction(math.min(elapsed, 1))
        end
    end

    if now >= self.vtNextMatrixUpdate then
        self.vtNextMatrixUpdate = now + kMatrixUpdateInterval
        self:UpdateCasteCounts()
        self:UpdateEmpireStatus()
        if GetGamerules():GetGameStarted() then
            self:UpdateSynthesisMatrix()
        end
    end

end

-- ----------------------------------------------------------------------------
-- Subvention Network
-- ----------------------------------------------------------------------------
local function RefillAmmo(player)
    for i = 0, player:GetNumChildren() - 1 do
        local child = player:GetChildAtIndex(i)
        if child:isa("ClipWeapon") and child:GetNeedsAmmo(false) then
            child:GiveAmmo(1, false)
        end
    end
end

function VTTeam:UpdateSubventionNetwork(deltaTime)

    PROFILE("VTTeam:UpdateSubventionNetwork")

    local teamNumber = self:GetTeamNumber()
    local now = Shared.GetTime()

    -- Power: structures only function inside the field.
    for _, ent in ipairs(GetEntitiesWithMixinForTeam("PowerConsumer", teamNumber)) do
        if ent:GetRequiresPower() then
            if VT_GetIsPointInField(ent:GetOrigin()) then
                ent:SetPowerOn()
            else
                ent:SetPowerOff()
            end
        end
    end

    -- Every Nexus (gate) is relevant to the whole empire regardless of distance,
    -- so clients know all Nexus Gates for the jump menu (default relevancy is
    -- 40 m). An entity is always relevant to a client when their *include*
    -- masks overlap; structures normally only carry the commander bit
    -- (SetAlwaysRelevantToCommander), so add the team-1 unit bit. Re-applied
    -- every tick in case the engine resets it. Not exposed to the enemy team.
    local empireMask = bit.bor(kRelevantToTeam1Unit, kRelevantToTeam1Commander)
    for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", teamNumber)) do
        local mask = nexus:GetIncludeRelevancyMask()
        if bit.band(mask, empireMask) ~= empireMask then
            nexus:SetIncludeRelevancyMask(bit.bor(mask, empireMask))
        end
    end

    -- Sentinel Obelisks fire only while built and inside the field.
    for _, obelisk in ipairs(GetEntitiesForTeam("VTSentinelObelisk", teamNumber)) do
        obelisk.attachedToBattery = obelisk:GetIsBuilt() and obelisk:GetIsAlive()
                and VT_GetIsPointInField(obelisk:GetOrigin())
    end

    -- Regenerative field: psi shields and plasma cells (ammo). Only the shield
    -- regenerates; armor and health are permanent (Classes/VTShield.lua).
    for _, ent in ipairs(GetEntitiesWithMixinForTeam("Live", teamNumber)) do

        if VT_GetIsEmpireEntity(ent) and VT_GetHasShieldPool(ent) and ent:GetIsAlive() then

            local isPlayer = ent:isa("Player")
            local isBuilt = not HasMixin(ent, "Construct") or ent:GetIsBuilt()

            if isBuilt and not ent.vtShieldReady then
                -- Structures get their full shield when construction completes.
                VT_RefreshShield(ent, true)
                ent.vtShieldReady = true
            elseif isPlayer then
                -- Shield Matrix research raises the max; the new part recharges.
                VT_RefreshShield(ent, false)
            end

            if isBuilt and ent.vtShield < ent.vtMaxShield then

                local burntOut = ent.VT_GetIsShieldBurntOut and ent:VT_GetIsShieldBurntOut()
                local onCreep = now < (ent.vtShieldRegenBlockedUntil or 0)

                -- Shields only recharge out of combat (no damage taken recently,
                -- shield hits count). Players need the field; structures recharge
                -- anywhere after a longer cooldown, a Resonant field speeds it up.
                local lastHit = ent.GetTimeLastDamageTaken and ent:GetTimeLastDamageTaken()
                local delay = isPlayer and kVTFieldRegenDelay or kVTStructureShieldRegenDelay
                local inCombat = lastHit ~= nil and now - lastHit < delay

                local fieldStrength = not burntOut and not onCreep and not inCombat and VT_GetFieldStrengthAt(ent:GetOrigin())
                if not fieldStrength and not isPlayer and not burntOut and not onCreep and not inCombat then
                    fieldStrength = 1
                end
                if fieldStrength then
                    local rate = (isPlayer and kVTFieldPlayerShieldRegen or kVTFieldStructureShieldRegen) * fieldStrength
                    ent.vtShield = math.min(ent.vtMaxShield, ent.vtShield + rate * deltaTime)
                end

            end

        end

    end

    for _, player in ipairs(GetEntitiesForTeam("Player", teamNumber)) do
        if player:GetIsAlive() and now >= (player.vtNextAmmoRefill or 0) and VT_GetIsPointInField(player:GetOrigin()) then
            player.vtNextAmmoRefill = now + kVTFieldAmmoRegenInterval
            RefillAmmo(player)
        end
    end

end

-- ----------------------------------------------------------------------------
-- Self-assembly
-- ----------------------------------------------------------------------------
-- Nearest living soldier within kVTAutoBuildRadius (commanders don't count).
local function GetNearestBuilder(structure, teamNumber)
    local players = GetEntitiesForTeamWithinRange("Player", teamNumber, structure:GetOrigin(), kVTAutoBuildRadius)
    Shared.SortEntitiesByDistance(structure:GetOrigin(), players)
    for _, player in ipairs(players) do
        if player:GetIsAlive() and not player:isa("Commander") then
            return player
        end
    end
    return nil
end

-- Unbuilt structures progress by real time while any soldier is nearby. The
-- rate is fixed: one soldier or ten build equally fast.
function VTTeam:UpdateAutoConstruction(deltaTime)

    PROFILE("VTTeam:UpdateAutoConstruction")

    local teamNumber = self:GetTeamNumber()

    for _, structure in ipairs(GetEntitiesWithMixinForTeam("Construct", teamNumber)) do

        if VT_GetIsEmpireEntity(structure) and not structure:GetIsBuilt() and structure:GetIsAlive() then
            local builder = GetNearestBuilder(structure, teamNumber)
            if builder then
                -- The builder is passed for ghost activation and build score only.
                structure:Construct(deltaTime, builder)
            end
        end

    end

end

-- ----------------------------------------------------------------------------
-- Synthesis Matrix
-- ----------------------------------------------------------------------------
function VTTeam:UpdateCasteCounts()
    local info = VT_GetEmpireInfo()
    if not info then
        return
    end
    for caste, className in pairs(kCasteClassNames) do
        info:SetCount(caste, #GetEntitiesAliveForTeam(className, self:GetTeamNumber()))
    end
end

-- Team status + running research for the top bar (networked through VTEmpireInfo).
function VTTeam:UpdateEmpireStatus()
    local info = VT_GetEmpireInfo()
    if not info then
        return
    end
    local team = self:GetTeamNumber()
    local function CountBuilt(className)
        local n = 0
        for _, ent in ipairs(GetEntitiesForTeam(className, team)) do
            if ent:GetIsBuilt() and ent:GetIsAlive() then
                n = n + 1
            end
        end
        return n
    end
    info:SetStatus(CountBuilt("VTNexus"), CountBuilt("VTSiphon"), CountBuilt("VTSubventionPylon"),
            #GetEntitiesForTeam("VTSpectator", team))

    local research = {}
    for _, ent in ipairs(GetEntitiesWithMixinForTeam("Research", team)) do
        local techId = ent.researchingId
        if techId and techId ~= kTechId.None and ent:GetIsAlive() then
            research[#research + 1] = { techId = techId, progress = ent.researchProgress or 0 }
        end
    end
    info:SetResearch(research)
end

-- Built, alive Nexuses and active (powered) Synthesis Chambers.
function VTTeam:GetSynthesisHosts()

    local hosts = {}
    local teamNumber = self:GetTeamNumber()

    for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", teamNumber)) do
        if nexus:GetIsBuilt() and nexus:GetIsAlive() then
            hosts[#hosts + 1] = nexus
        end
    end

    for _, chamber in ipairs(GetEntitiesForTeam("VTSynthesisChamber", teamNumber)) do
        if GetIsUnitActive(chamber) then
            hosts[#hosts + 1] = chamber
        end
    end

    return hosts

end

-- Returns the caste the player may actually be synthesized as, plus an
-- optional message key explaining a downgrade to Vanguard.
function VTTeam:ResolveCaste(desiredClass)

    local caste = kClassToCaste[desiredClass]
    if not caste then
        return kVTClass.Vanguard
    end

    if not VT_GetMeetsRequirement(kVTClassRequirements[desiredClass]) then
        return kVTClass.Vanguard, "VT_MSG_CASTE_LOCKED"
    end

    local info = VT_GetEmpireInfo()
    if info and info:GetCount(caste) >= info:GetQuota(caste) then
        return kVTClass.Vanguard, "VT_MSG_QUOTA_FULL"
    end

    if self:GetTeamResources() < (kVTCasteCost[caste] or 0) then
        return kVTClass.Vanguard, "VT_MSG_NO_RES"
    end

    return desiredClass

end

local function ValidateChoice(value, requirements, default, rank)
    if value and requirements[value] and VT_GetMeetsRequirement(requirements[value], rank) then
        return value
    end
    return default
end

function VTTeam:SynthesizePlayer(player, host)

    local loadout = player.VT_GetLoadout and player:VT_GetLoadout() or {}
    local rank = VT_GetRankForScore(player.GetScore and player:GetScore() or 0)

    local class, downgradeMessage = self:ResolveCaste(loadout.class or kVTClass.Vanguard)
    local mapName = kVTClassMapNames[class]

    local extents = LookupTechData(kClassTechIds[class], kTechDataMaxExtents)
    local capsuleHeight, capsuleRadius
    if extents then
        capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)
    else
        capsuleHeight, capsuleRadius = player:GetTraceCapsule()
    end

    local hostOrigin = host:GetOrigin()
    local spawnOrigin = GetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, hostOrigin, kVTSpawnMinRange, kVTSpawnMaxRange, EntityFilterAll())
    if not spawnOrigin then
        return false
    end

    local toHost = GetNormalizedVector(hostOrigin + Vector(0, 1, 0) - spawnOrigin)
    local angles = Angles(0, GetYawFromVector(-toHost), 0)

    local extraValues =
    {
        vtModule     = ValidateChoice(loadout.module,    kVTModuleRequirements,     kVTModule.ShieldBoost, rank),
        vtPrimaryMod = ValidateChoice(loadout.primary,   kVTPrimaryModRequirements, kVTPrimaryMod.Standard, rank),
        vtSecondary  = ValidateChoice(loadout.secondary, kVTSecondaryRequirements,  kVTSecondary.Pistol,    rank),
    }

    self:RemovePlayerFromRespawnQueue(player)

    local newPlayer = player:Replace(mapName, self:GetTeamNumber(), false, spawnOrigin, extraValues)

    if not self:RespawnPlayer(newPlayer, spawnOrigin, angles) then
        newPlayer = newPlayer:Replace(newPlayer:GetDeathMapName())
        self:PutPlayerInRespawnQueue(newPlayer)
        return false
    end

    newPlayer:ClearGameEffects()

    -- The new player inherits the spectator's follow-camera distance; reset it
    -- to first person (the vanilla Infantry Portal does the same).
    if newPlayer.SetCameraDistance then
        newPlayer:SetCameraDistance(0)
    end

    local casteCost = kClassToCaste[class] and kVTCasteCost[kClassToCaste[class]] or 0
    if casteCost > 0 then
        self:AddTeamResources(-casteCost)
    end

    if downgradeMessage then
        VT_SendMessageToPlayer(newPlayer, VT_GetString(downgradeMessage))
    end

    newPlayer:TriggerEffects("infantry_portal_spawn")

    return true

end

function VTTeam:UpdateSynthesisMatrix()

    PROFILE("VTTeam:UpdateSynthesisMatrix")

    local queue = self:GetSortedRespawnQueue()
    if #queue == 0 then
        return
    end

    local hosts = self:GetSynthesisHosts()
    local now = Shared.GetTime()

    if #hosts == 0 then
        if now - self.vtLastNoSpawnMessage > kNoSpawnMessageInterval then
            self.vtLastNoSpawnMessage = now
            VT_AnnounceToTeam("VT_MSG_NO_SPAWN")
        end
        return
    end

    -- Copy first: synthesizing modifies the respawn queue.
    local ready = {}
    for _, player in ipairs(queue) do
        if player and player.GetRespawnQueueEntryTime
                and now - player:GetRespawnQueueEntryTime() >= kVTRespawnTime then
            ready[#ready + 1] = player
        end
    end

    for _, player in ipairs(ready) do
        self:SynthesizePlayer(player, hosts[math.random(#hosts)])
        -- Re-count so quotas hold within a single wave.
        self:UpdateCasteCounts()
    end

end

-- ----------------------------------------------------------------------------
-- Starting structures: vanilla spawns a Command Station on the start tech point
-- (TechPoint:SpawnCommandStructure) and an Extractor on the nearest resource
-- point (PlayingTeam's SpawnResourceTower). The empire gets its own Imperial
-- Nexus / Resource Siphon instead (Classes/VTNexus.lua); other teams are untouched.
-- ----------------------------------------------------------------------------
if not VT_HookedStartStructures then
VT_HookedStartStructures = true

local oldSpawnCommandStructure = TechPoint.SpawnCommandStructure
function TechPoint:SpawnCommandStructure(teamNumber)
    if VT_GetIsVTTeam(teamNumber) then
        return CreateEntityForTeam(kTechId.VTNexus, Vector(self:GetOrigin()), teamNumber)
    end
    return oldSpawnCommandStructure(self, teamNumber)
end

local oldSpawnResourceTowerForTeam = ResourcePoint.SpawnResourceTowerForTeam
function ResourcePoint:SpawnResourceTowerForTeam(team, techId)
    if techId == kTechId.Extractor and team and VT_GetIsVTTeam(team:GetTeamNumber()) then
        techId = kTechId.VTSiphon
    end
    return oldSpawnResourceTowerForTeam(self, team, techId)
end

end -- VT_HookedStartStructures
