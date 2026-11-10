-- ============================================================================
-- VTSpectator - a dead Vael'Thor soldier waiting in the Synthesis Matrix.
--
-- Choose the caste and loadout for the next synthesis while waiting:
--   1 Vanguard   2 Infiltrator   3 Subject   4 Praetor
--   5 cycle tactical module   R cycle primary mod   E cycle secondary
-- The choice is remembered per client across lives.
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

    -- choice: 1-4 caste, 5 cycle module, 6 cycle primary mod, 7 cycle secondary.
    -- Fed by OnProcessMove (own camera) and by the VTMatrixChoice message (while
    -- following a teammate in first person, when moves don't carry the keys).
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
        if self.vtPrefsLoaded and Shared.GetTime() >= (self.vtNextLoadoutSync or 0) then
            self:VT_SendLoadoutToOwner()   -- cheap periodic resync
        end
    end

    -- Mirror the choices to the owning client for the HUD (see VTMatrixLoadout).
    function VTSpectator:VT_SendLoadoutToOwner()
        if not self:GetClient() then
            return
        end
        Server.SendNetworkMessage(self, "VTMatrixLoadout",
        {
            class     = self.vtDesiredClass,
            module    = self.vtModule,
            primary   = self.vtPrimaryMod,
            secondary = self.vtSecondary,
        }, true)
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

function VTSpectator:OnProcessMove(input)

    if Server then

        local commands = input.commands
        local last = self.vtLastCommands or 0
        local function Pressed(bitMask)
            return bit.band(commands, bitMask) ~= 0 and bit.band(last, bitMask) == 0
        end

        local keys = { Move.Weapon1, Move.Weapon2, Move.Weapon3, Move.Weapon4, Move.Weapon5, Move.Reload, Move.Use }
        for choice, bitMask in ipairs(keys) do
            if Pressed(bitMask) then
                self:VT_ApplyChoice(choice)
                break
            end
        end

        self.vtLastCommands = commands

    end

    -- These keys belong to the matrix menu, not to spectator camera modes.
    input.commands = bit.band(input.commands, bit.bnot(kChoiceMask))

    MarineSpectator.OnProcessMove(self, input)

end

Shared.LinkClassToMap("VTSpectator", VTSpectator.kMapName, networkVars)
