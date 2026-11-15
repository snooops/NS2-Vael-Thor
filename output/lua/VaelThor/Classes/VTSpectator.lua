-- ============================================================================
-- VTSpectator - a dead Vael'Thor soldier waiting in the Synthesis Matrix.
--
-- Choose the caste and loadout for the next synthesis in the Synthesis Matrix
-- menu (GUI/GUIVTMatrixMenu.lua; mouse or keys):
--   1 Vanguard   2 Infiltrator   3 Subject   4 Praetor
--   5 cycle tactical module   R cycle primary mod   E cycle secondary
--   Space / SYNTHESIZE button: request synthesis
--   SPAWN AT row: which built Nexus to be synthesized at (or any host)
-- Auto-synthesis: every death starts it; the player is synthesized once the
-- matrix timer (kVTRespawnTime) has run out, but not before kVTAutoSpawnMinDelay.
-- Any mouse click in the menu stops it (choice 12); from then on the player is
-- synthesized only after asking for it. Asking early arms the request so
-- synthesis happens the moment the timer ends. Bots are synthesized
-- automatically. The loadout and the spawn Nexus are remembered per client
-- across lives.
-- ============================================================================

class 'VTSpectator' (MarineSpectator)

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTSpectator, { "MarineSpectator" })

VTSpectator.kMapName = kVTMapNames.Spectator

local networkVars =
{
    vtDesiredClass = "enum kVTClass",
    vtModule       = "enum kVTModule",
    vtPrimaryMod   = "enum kVTPrimaryMod",
    vtSecondary    = "enum kVTSecondary",
}

local function Cycle(value, enumTable)
    local count = GetEnumCount(enumTable)
    return (value % count) + 1
end

local function CycleBack(value, enumTable)
    local count = GetEnumCount(enumTable)
    return ((value - 2) % count) + 1
end

-- Vanilla MarineSpectator forces team 1 in OnCreate AND OnInitialized. In Marines vs. Vael'Thor the empire is
-- team 2: a dead soldier became a team-1 spectator, landed in the MARINES' respawn queue and came back as a
-- vanilla Marine on team 1 (instantly in warmup via PlayingTeam:RespawnAllDeadPlayer, at an Infantry Portal in a
-- round). Put the spectator back on the Vael'Thor team after each vanilla call (server decides; the team number
-- is networked).
local function SetVTTeam(self)
    if Server and (kVTTeamIndex == kTeam1Index or kVTTeamIndex == kTeam2Index) then
        self:SetTeamNumber(kVTTeamIndex)
    end
end

function VTSpectator:OnCreate()

    VTBase.MarineSpectator.OnCreate(self)
    SetVTTeam(self)

    self.vtDesiredClass = kVTClass.Vanguard
    self.vtModule       = kVTModule.ShieldBoost
    self.vtPrimaryMod   = kVTPrimaryMod.Standard
    self.vtSecondary    = kVTSecondary.Pistol

end

function VTSpectator:OnInitialized()
    VTBase.MarineSpectator.OnInitialized(self)
    SetVTTeam(self)
end

if Server then

    function VTSpectator:VT_LoadPreferences()
        local client = self:GetClient()
        local prefs = client and client.vtLoadout
        if prefs then
            self.vtDesiredClass = prefs.class     or self.vtDesiredClass
            self.vtModule       = prefs.module    or self.vtModule
            self.vtPrimaryMod   = prefs.primary   or self.vtPrimaryMod
            self.vtSecondary    = prefs.secondary or self.vtSecondary
            self.vtSpawnNexusId = prefs.spawnNexus or self.vtSpawnNexusId
        end
        self.vtPrefsLoaded = client ~= nil
    end

    function VTSpectator:VT_SavePreferences()
        local client = self:GetClient()
        if client then
            client.vtLoadout =
            {
                class     = self.vtDesiredClass,
                module    = self.vtModule,
                primary   = self.vtPrimaryMod,
                secondary = self.vtSecondary,
                spawnNexus = self.vtSpawnNexusId,
            }
        end
    end

    -- Preferences live on the client object, which may not be attached yet when
    -- the spectator is created; load them lazily, before anything reads them.
    function VTSpectator:VT_EnsurePreferences()
        if not self.vtPrefsLoaded then
            self:VT_LoadPreferences()
            if self.vtPrefsLoaded then
                self:VT_SendLoadoutToOwner()
            end
        end
    end

    local kChoiceClasses = { kVTClass.Vanguard, kVTClass.Infiltrator, kVTClass.Subject, kVTClass.Praetor }

    -- Built, living Nexuses of the team in a stable order (entity id): the spawn choices besides "any host".
    local function GetSpawnNexuses(teamNumber)
        local list = {}
        for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", teamNumber)) do
            if nexus:GetIsAlive() and nexus:GetIsBuilt() then
                list[#list + 1] = nexus
            end
        end
        table.sort(list, function(a, b) return a:GetId() < b:GetId() end)
        return list
    end

    -- The chosen spawn Nexus if it is still a valid host, else nil (= any host, the vanilla-style random pick).
    function VTSpectator:VT_GetSpawnNexus()
        local id = self.vtSpawnNexusId
        if not id or id == Entity.invalidId then
            return nil
        end
        local nexus = Shared.GetEntity(id)
        if nexus and nexus:isa("VTNexus") and nexus:GetTeamNumber() == self:GetTeamNumber()
                and nexus:GetIsAlive() and nexus:GetIsBuilt() then
            return nexus
        end
        return nil
    end

    -- step +1 / -1 through: any host, Nexus 1, Nexus 2, ...
    function VTSpectator:VT_CycleSpawnNexus(step)
        local list = GetSpawnNexuses(self:GetTeamNumber())
        local current = self:VT_GetSpawnNexus()
        local index = 0
        for i, nexus in ipairs(list) do
            if nexus == current then index = i end
        end
        index = (index + step) % (#list + 1)
        self.vtSpawnNexusId = list[index] and list[index]:GetId() or Entity.invalidId
    end

    local function GetSpawnName(nexus, list)
        if not nexus then
            return ""
        end
        local name = nexus.GetLocationName and nexus:GetLocationName() or ""
        if name == "" then
            for i, other in ipairs(list) do
                if other == nexus then name = "Nexus " .. i end
            end
        end
        return string.sub(name, 1, 60)
    end

    -- choice: 1-4 caste, 5 cycle module, 6 cycle primary mod, 7 cycle secondary,
    -- 8 toggle the synthesis request, 9-11 cycle module/primary/secondary back.
    -- Fed by the VTMatrixChoice message from GUIVTMatrixMenu.
    function VTSpectator:VT_ApplyChoice(choice)
        self:VT_EnsurePreferences()
        if kChoiceClasses[choice] then
            self.vtDesiredClass = kChoiceClasses[choice]
        elseif choice == 5 then
            self.vtModule = Cycle(self.vtModule, kVTModule)
        elseif choice == 6 then
            self.vtPrimaryMod = Cycle(self.vtPrimaryMod, kVTPrimaryMod)
        elseif choice == 7 then
            self.vtSecondary = Cycle(self.vtSecondary, kVTSecondary)
        elseif choice == 8 then
            self.vtSynthArmed = not self.vtSynthArmed
        elseif choice == 9 then
            self.vtModule = CycleBack(self.vtModule, kVTModule)
        elseif choice == 10 then
            self.vtPrimaryMod = CycleBack(self.vtPrimaryMod, kVTPrimaryMod)
        elseif choice == 11 then
            self.vtSecondary = CycleBack(self.vtSecondary, kVTSecondary)
        elseif choice == 12 then
            self.vtAutoStopped = true
        elseif choice == 13 or choice == 14 then
            self:VT_CycleSpawnNexus(choice == 13 and 1 or -1)
        else
            return
        end
        self:VT_SavePreferences()
        self:VT_SendLoadoutToOwner()
    end

    -- Runs whether or not the client's moves reach OnProcessMove.
    function VTSpectator:OnUpdate(deltaTime)
        VTBase.MarineSpectator.OnUpdate(self, deltaTime)
        self:VT_EnsurePreferences()
        if self.vtPrefsLoaded and (Shared.GetTime() >= (self.vtNextLoadoutSync or 0)
                or self.vtSentReadyTime ~= self:VT_GetSynthReadyTime()) then
            self:VT_SendLoadoutToOwner()   -- cheap periodic resync, or the queue timer changed
        end
    end

    -- Time from which the matrix may synthesize this player (0 = not queued).
    function VTSpectator:VT_GetSynthReadyTime()
        local entryTime = self.GetRespawnQueueEntryTime and self:GetRespawnQueueEntryTime()
        return entryTime and (entryTime + VT_GetRespawnTime()) or 0
    end

    -- When auto-synthesis happens (0 = stopped by a click, or not queued yet).
    function VTSpectator:VT_GetAutoSynthTime()
        local entryTime = self.GetRespawnQueueEntryTime and self:GetRespawnQueueEntryTime()
        if self.vtAutoStopped or not entryTime then
            return 0
        end
        return math.max(entryTime + VT_GetRespawnTime(), entryTime + kVTAutoSpawnMinDelay)
    end

    -- Checked by VTTeam:UpdateSynthesisMatrix once the timer has run out.
    function VTSpectator:VT_GetWantsSynthesis()
        if self.vtSynthArmed then
            return true
        end
        local autoTime = self:VT_GetAutoSynthTime()
        if autoTime > 0 and Shared.GetTime() >= autoTime then
            return true
        end
        local client = self:GetClient()
        return client ~= nil and client:GetIsVirtual()   -- bots can't click
    end

    function VTSpectator:VT_SetSynthArmed(armed)
        self.vtSynthArmed = armed == true
    end

    -- Mirror the choices to the owning client for the HUD (see VTMatrixLoadout).
    function VTSpectator:VT_SendLoadoutToOwner()
        local client = self:GetClient()
        if not client or client:GetIsVirtual() then
            return
        end
        local readyTime = self:VT_GetSynthReadyTime()
        local list = GetSpawnNexuses(self:GetTeamNumber())
        Server.SendNetworkMessage(self, "VTMatrixLoadout",
        {
            class     = self.vtDesiredClass,
            module    = self.vtModule,
            primary   = self.vtPrimaryMod,
            secondary = self.vtSecondary,
            readyTime = readyTime,
            armed     = self.vtSynthArmed == true,
            autoTime  = self:VT_GetAutoSynthTime(),
            spawnName = GetSpawnName(self:VT_GetSpawnNexus(), list),
            spawnCount = math.min(#list, 15),
        }, true)
        self.vtSentReadyTime = readyTime
        self.vtNextLoadoutSync = Shared.GetTime() + 2
    end

    function VTSpectator:VT_GetLoadout()
        self:VT_EnsurePreferences()
        return
        {
            class     = self.vtDesiredClass,
            module    = self.vtModule,
            primary   = self.vtPrimaryMod,
            secondary = self.vtSecondary,
        }
    end

end

if Server then
    -- No personal resources for the empire (see VTPlayers.lua).
    function VTSpectator:AddResources(amount)
        return 0
    end
    function VTSpectator:SetResources(amount)
        self.resources = 0
    end
end

local kChoiceMask = bit.bor(Move.Weapon1, Move.Weapon2, Move.Weapon3, Move.Weapon4, Move.Weapon5, Move.Reload, Move.Use)

-- The menu keys are caught client-side by GUIVTMatrixMenu and sent as
-- VTMatrixChoice messages (that works in every camera mode).
function VTSpectator:OnProcessMove(input)

    -- These keys belong to the matrix menu, not to spectator camera modes.
    input.commands = bit.band(input.commands, bit.bnot(kChoiceMask))

    VTBase.MarineSpectator.OnProcessMove(self, input)

end

Shared.LinkClassToMap("VTSpectator", VTSpectator.kMapName, networkVars)
