-- ============================================================================
-- VTSpectator - a dead Vael'Thor soldier waiting in the Synthesis Matrix.
--
-- Choose the caste and loadout for the next synthesis in the Synthesis Matrix
-- menu (GUI/GUIVTMatrixMenu.lua; mouse or keys):
--   1 Vanguard   2 Infiltrator   3 Subject   4 Praetor
--   5 cycle tactical module   R cycle primary mod   E cycle secondary
--   Space / SYNTHESIZE button: request synthesis
-- There is no automatic respawn: once the matrix timer (kVTRespawnTime) has run
-- out the player is synthesized only after asking for it. Asking early arms the
-- request so synthesis happens the moment the timer ends. Bots are synthesized
-- automatically. The loadout is remembered per client across lives.
-- ============================================================================

class 'VTSpectator' (MarineSpectator)

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

function VTSpectator:OnCreate()

    MarineSpectator.OnCreate(self)

    self.vtDesiredClass = kVTClass.Vanguard
    self.vtModule       = kVTModule.ShieldBoost
    self.vtPrimaryMod   = kVTPrimaryMod.Standard
    self.vtSecondary    = kVTSecondary.Pistol

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
        else
            return
        end
        self:VT_SavePreferences()
        self:VT_SendLoadoutToOwner()
    end

    -- Runs whether or not the client's moves reach OnProcessMove.
    function VTSpectator:OnUpdate(deltaTime)
        MarineSpectator.OnUpdate(self, deltaTime)
        self:VT_EnsurePreferences()
        if self.vtPrefsLoaded and (Shared.GetTime() >= (self.vtNextLoadoutSync or 0)
                or self.vtSentReadyTime ~= self:VT_GetSynthReadyTime()) then
            self:VT_SendLoadoutToOwner()   -- cheap periodic resync, or the queue timer changed
        end
    end

    -- Time from which the matrix may synthesize this player (0 = not queued).
    function VTSpectator:VT_GetSynthReadyTime()
        local entryTime = self.GetRespawnQueueEntryTime and self:GetRespawnQueueEntryTime()
        return entryTime and (entryTime + kVTRespawnTime) or 0
    end

    -- Checked by VTTeam:UpdateSynthesisMatrix once the timer has run out.
    function VTSpectator:VT_GetWantsSynthesis()
        if self.vtSynthArmed then
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
        Server.SendNetworkMessage(self, "VTMatrixLoadout",
        {
            class     = self.vtDesiredClass,
            module    = self.vtModule,
            primary   = self.vtPrimaryMod,
            secondary = self.vtSecondary,
            readyTime = readyTime,
            armed     = self.vtSynthArmed == true,
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

    MarineSpectator.OnProcessMove(self, input)

end

Shared.LinkClassToMap("VTSpectator", VTSpectator.kMapName, networkVars)
