-- ============================================================================
-- VTEmpireInfo - networked, always-relevant empire state:
-- caste quotas, live caste counts and Directive timers.
-- ============================================================================

class 'VTEmpireInfo' (Entity)

VTEmpireInfo.kMapName = kVTMapNames.EmpireInfo

local networkVars =
{
    quotaInfiltrator  = "integer (0 to 8)",
    quotaSubject      = "integer (0 to 8)",
    quotaPraetor      = "integer (0 to 8)",

    countInfiltrator  = "integer (0 to 16)",
    countSubject      = "integer (0 to 16)",
    countPraetor      = "integer (0 to 16)",

    requisitionEnd    = "time",
    requisitionReady  = "time",
    relentlessEnd     = "time",
    relentlessReady   = "time",
    ironEnd           = "time",
    ironReady         = "time",

    -- team status for the Vael'Thor top bar (GUI/GUIVTTopBar.lua); clients can't count structures that
    -- aren't relevant to them, so the server does (VTTeam:UpdateEmpireStatus)
    statusNexus       = "integer (0 to 15)",
    statusSiphons     = "integer (0 to 31)",
    statusPylons      = "integer (0 to 63)",
    statusMatrix      = "integer (0 to 31)",    -- dead soldiers waiting in the Synthesis Matrix
    -- up to three running researches / upgrades (most advanced first)
    research1Id       = "enum kTechId",
    research1Progress = "float (0 to 1 by 0.01)",
    research2Id       = "enum kTechId",
    research2Progress = "float (0 to 1 by 0.01)",
    research3Id       = "enum kTechId",
    research3Progress = "float (0 to 1 by 0.01)",
}

VTEmpireInfo.kMaxResearchSlots = 3

function VTEmpireInfo:OnCreate()

    Entity.OnCreate(self)

    self.quotaInfiltrator = kVTQuotaDefaults.Infiltrator
    self.quotaSubject     = kVTQuotaDefaults.Subject
    self.quotaPraetor     = kVTQuotaDefaults.Praetor

    self.countInfiltrator = 0
    self.countSubject     = 0
    self.countPraetor     = 0

    self.requisitionEnd   = 0
    self.requisitionReady = 0
    self.relentlessEnd    = 0
    self.relentlessReady  = 0
    self.ironEnd          = 0
    self.ironReady        = 0

    self.statusNexus      = 0
    self.statusSiphons    = 0
    self.statusPylons     = 0
    self.statusMatrix     = 0
    for i = 1, VTEmpireInfo.kMaxResearchSlots do
        self["research" .. i .. "Id"] = kTechId.None
        self["research" .. i .. "Progress"] = 0
    end

    if Server then
        self:SetPropagate(Entity.Propagate_Always)
        self:SetUpdates(false)
    end

end

function VTEmpireInfo:GetQuota(casteName)
    return self["quota" .. casteName] or 0
end

function VTEmpireInfo:GetCount(casteName)
    return self["count" .. casteName] or 0
end

-- { { techId, progress }, ... } of the running researches, most advanced first
function VTEmpireInfo:GetResearch()
    local list = {}
    for i = 1, VTEmpireInfo.kMaxResearchSlots do
        local techId = self["research" .. i .. "Id"]
        if techId and techId ~= kTechId.None then
            list[#list + 1] = { techId = techId, progress = self["research" .. i .. "Progress"] or 0 }
        end
    end
    return list
end

-- techId -> { end field, ready field, duration, cooldown }
local kEdicts =
{
    [kTechId.VTEdictRequisition]    = { "requisitionEnd", "requisitionReady", kVTRequisitionDuration,    kVTRequisitionCooldown },
    [kTechId.VTEdictRelentless]     = { "relentlessEnd",  "relentlessReady",  kVTRelentlessDuration,     kVTRelentlessCooldown },
    [kTechId.VTEdictIronDiscipline] = { "ironEnd",        "ironReady",        kVTIronDisciplineDuration, kVTIronDisciplineCooldown },
}

function VT_GetIsEdict(techId)
    return kEdicts[techId] ~= nil
end

function VTEmpireInfo:GetEdictEndTime(techId)
    local edict = kEdicts[techId]
    return edict and self[edict[1]] or 0
end

function VTEmpireInfo:GetEdictReadyTime(techId)
    local edict = kEdicts[techId]
    return edict and self[edict[2]] or 0
end

function VTEmpireInfo:GetEdictReady(techId)
    return Shared.GetTime() >= self:GetEdictReadyTime(techId)
end

if Server then

    function VTEmpireInfo:SetQuota(casteName, value)
        local field = "quota" .. casteName
        self[field] = Clamp(value, 0, kVTQuotaMax[casteName] or 8)
    end

    function VTEmpireInfo:SetCount(casteName, value)
        self["count" .. casteName] = Clamp(value, 0, 16)
    end

    function VTEmpireInfo:SetStatus(nexus, siphons, pylons, matrix)
        self.statusNexus   = Clamp(nexus, 0, 15)
        self.statusSiphons = Clamp(siphons, 0, 31)
        self.statusPylons  = Clamp(pylons, 0, 63)
        self.statusMatrix  = Clamp(matrix, 0, 31)
    end

    -- research: list of { techId, progress }, any length (sorted and cut here)
    function VTEmpireInfo:SetResearch(research)
        table.sort(research, function(a, b) return a.progress > b.progress end)
        for i = 1, VTEmpireInfo.kMaxResearchSlots do
            local r = research[i]
            self["research" .. i .. "Id"] = r and r.techId or kTechId.None
            self["research" .. i .. "Progress"] = r and Clamp(r.progress, 0, 1) or 0
        end
    end

    function VTEmpireInfo:IssueEdict(techId)
        local edict = kEdicts[techId]
        if not edict then
            return
        end
        local duration, cooldown = edict[3], edict[4]
        if VT_GetTeamHasTech("VTPsionicEdictsTech") then
            duration = duration * kVTPsionicEdictsDurationScalar
            cooldown = cooldown * kVTPsionicEdictsCooldownScalar
        end
        local now = Shared.GetTime()
        self[edict[1]] = now + duration
        self[edict[2]] = now + cooldown
    end

end

-- The single empire info entity (created lazily by the server).
local cachedInfoId = Entity.invalidId
function VT_GetEmpireInfo()

    -- No empire in a vanilla match (Marines vs. Aliens): never create one.
    if not VT_GetIsVTActive() then
        return nil
    end

    local cached = cachedInfoId ~= Entity.invalidId and Shared.GetEntity(cachedInfoId)
    if cached and cached:isa("VTEmpireInfo") then
        return cached
    end

    -- Entries can be nil while entities are destroyed during a round reset.
    for _, info in ientitylist(Shared.GetEntitiesWithClassname("VTEmpireInfo")) do
        if info then
            cachedInfoId = info:GetId()
            return info
        end
    end

    if Server then
        -- Entity creation can be refused while the round is resetting; callers
        -- handle nil and the next update simply tries again.
        local info = Server.CreateEntity(VTEmpireInfo.kMapName)
        if info then
            cachedInfoId = info:GetId()
        end
        return info
    end

    return nil

end

Shared.LinkClassToMap("VTEmpireInfo", VTEmpireInfo.kMapName, networkVars)
