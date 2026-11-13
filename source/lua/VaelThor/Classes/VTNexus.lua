-- ============================================================================
-- Imperial Nexus and Resource Siphon
--
-- Own classes (subclasses of the vanilla CommandStation / Extractor) with own
-- tech ids (kTechId.VTNexus / VTSiphon, Hooks/TechData.lua), so vanilla marines
-- in a Vael'Thor vs. Marines match keep their normal Command Station and
-- Extractor. Commander login, win conditions and resource collection come from
-- the vanilla base classes (isa("CommandStation") / isa("Extractor") still hold).
--
-- Selected Nexus buttons:
--   main : Requisition Mandate, Relentless Advance, Iron Discipline,
--          Archon's Throne (research), Caste Quotas (sub menu),
--          Upgrade to Nexus Gate (until upgraded)
--   quota: Infiltrator +/-, Subject +/-, Praetor +/-, back
-- ============================================================================

-- Team skins come from the commander's team cosmetic slots and are re-applied every update; they would paint
-- marine textures over the Vael'Thor models. Worse, the skin mixins look the skin up by class name and ASSERT
-- for classes they don't know (ExtractorVariantMixin: "VTSiphon" -> error every frame with an Extractor skin).
-- The Vael'Thor team always reports the defaults vanilla uses for a skinless marine commander
-- (MarineTeam: slot 1 structures, 2 extractors, 3 MACs, 4 ARCs).
if GameInfo and GameInfo.GetTeamCosmeticSlot and not VT_PatchedTeamCosmeticSlot then
    VT_PatchedTeamCosmeticSlot = true
    local kVTTeamSkinDefaults =
    {
        [kTeamCosmeticSlot1] = kDefaultMarineStructureVariant,
        [kTeamCosmeticSlot2] = kDefaultExtractorVariant,
        [kTeamCosmeticSlot3] = kDefaultMarineMacVariant,
        [kTeamCosmeticSlot4] = kDefaultMarineArcVariant,
    }
    local oldGetTeamCosmeticSlot = GameInfo.GetTeamCosmeticSlot
    function GameInfo:GetTeamCosmeticSlot(teamNum, cosmeticSlot)
        local default = kVTTeamSkinDefaults[cosmeticSlot]
        if default ~= nil and kVTTeamIndex ~= kVTNoTeam and VT_GetIsVTTeam(teamNum) then
            return default
        end
        return oldGetTeamCosmeticSlot(self, teamNum, cosmeticSlot)
    end
end

-- Pulsing violet point light for the Vael'Thor building models (client). Shown while the structure is built,
-- alive and powered. Stores the light on self[key]; call VT_DestroyGlowLight from OnDestroy.
if Client then
    local kGlowColor = Color(0.62, 0.25, 1.0)

    -- height: on the unscaled model (scaled by kVTStructureModelScale here)
    function VT_UpdateGlowLight(self, key, height, radius, intensity, speed)
        local on = self:GetIsBuilt() and self:GetIsAlive() and (not self.GetIsPowered or self:GetIsPowered())
        local light = self[key]
        if on and not light then
            light = Client.CreateRenderLight()
            light:SetType(RenderLight.Type_Point)
            light:SetCastsShadows(false)
            light:SetSpecular(false)
            light:SetColor(kGlowColor)
            light:SetRadius(radius)
            self[key] = light
        end
        if light then
            light:SetIsVisible(on)
            if on then
                local pulse = 0.75 + 0.25 * math.sin(Shared.GetTime() * (speed or 2.2) + self:GetId())
                light:SetIntensity(intensity * pulse)
                light:SetCoords(Coords.GetTranslation(self:GetOrigin() + Vector(0, height * kVTStructureModelScale, 0)))
            end
        end
    end

    function VT_DestroyGlowLight(self, key)
        if self[key] then
            Client.DestroyRenderLight(self[key])
            self[key] = nil
        end
    end
end

class 'VTNexus' (CommandStation)

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTNexus, { "CommandStation", "CommandStructure" })

VTNexus.kMapName = kVTMapNames.Nexus

-- Own static model (art/buildings/build_all.sh nexus): 5.0 x 5.0 x 4.2 m, collision = stepped base + frame.
-- Commander entry works like the Hive: look at it, press E, logged in at once. The Command Station's
-- hatch-driven login (animation tags "opened"/"closed") doesn't exist without its animation graph.
kVTNexusModel = PrecacheAsset("models/vaelthor/nexus/nexus.model")

function VTNexus:OnInitialized()
    VTBase.CommandStation.OnInitialized(self)
    self:SetModel(kVTNexusModel)
end

-- No "login" attach point: look at the Nexus from any side and press E to take command (Hive style).
function VTNexus:GetUsablePoints()
    return nil
end

-- The base is wide; allow use from the frame's distance (default 2 m from the eyes).
function VTNexus:GetUseMaxRange()
    return 3.5 * kVTStructureModelScale
end

if Server then

    -- ---- Commander entry: the Alien Hive's rules instead of the Command Station's ----------------------
    -- Hive: "Aliens log in to hive instantly" - no waiting for a hatch-closed animation tag
    function VTNexus:GetWaitForCloseToLogin()
        return false
    end

    -- Command Station: the player must stand inside the chair (GetIsPlayerInside: within 1.05 m of a point
    -- 1.5 m above the origin) - on the Nexus that spot is inside the core crystal, so every login was
    -- rejected right after the "login" sound. Hive: any living team member who used it, wherever they stand.
    function VTNexus:GetIsPlayerValidForCommander(player)
        return player ~= nil and player:isa("Marine") and VTBase.CommandStructure.GetIsPlayerValidForCommander(self, player)
    end

    -- Command Station also kills every other player standing "inside" it on login; the Hive doesn't.
    function VTNexus:LoginPlayer(player, forced)
        return VTBase.CommandStructure.LoginPlayer(self, player, forced)
    end

    -- vanilla sets loginAllowed on the "opened" animation tag (Command Station hatch / Hive); there is none.
    -- The login itself happens on the Nexus' next update (UpdateCommanderLogin), as in vanilla.
    function VTNexus:OnUse(player, elapsedTime, useSuccessTable)
        if not self.occupied then
            self.loginAllowed = true
        end
        VTBase.CommandStation.OnUse(self, player, elapsedTime, useSuccessTable)
    end

    -- Why this player can't take command here (nil = can).
    function VTNexus:VT_GetLoginBlocker(player)
        if not self:GetIsBuilt() or not self:GetIsAlive() then
            return "the Nexus is not built"
        elseif self:GetTeam():GetHasCommander() or self.occupied then
            return "your team already has a commander"
        elseif player:isa("Exo") then
            return "Praetors cannot take command"
        elseif not player:isa("Marine") or not player:GetIsAlive() then
            return "only living soldiers can take command"
        elseif not GetIsUnitActive(self) then
            return "the Nexus is inactive"
        elseif GetGamerules():GetPlayerBannedFromCommand(Server.GetOwner(player):GetUserId()) then
            return "you are banned from command"
        end
        return nil
    end

    function VTNexus:VT_TryLogin(player)
        local blocker = self:VT_GetLoginBlocker(player)
        if blocker then
            return false, blocker
        end
        self.loginAllowed = true
        local result = { useSuccess = true }
        VTBase.CommandStation.OnUse(self, player, 0, result)
        if self.occupied and self.playerIdStartedLogin == player:GetId() then
            return true
        end
        return false, "login refused"
    end

    -- Hive-style entry that doesn't depend on hitting the model with the use trace: pressing E within reach of
    -- a Nexus (its base edge + 1.5 m) starts the login. Called from every caste's OnProcessMove (VTPlayers.lua).
    local kNexusReach = 4.0          -- horizontal, from the Nexus origin (base radius ~2.5 m)
    local kNexusReachUp = 3.0

    function VT_HandleNexusUse(player, input)
        local pressed = bit.band(input.commands, Move.Use) ~= 0
        local wasPressed = player.vtUseHeld
        player.vtUseHeld = pressed
        if not pressed or wasPressed or not player:GetIsAlive() then
            return
        end
        local origin = player:GetOrigin()
        local best, bestDist
        for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", player:GetTeamNumber())) do
            local d = nexus:GetOrigin() - origin
            local horizontal = math.sqrt(d.x * d.x + d.z * d.z)
            if horizontal <= kNexusReach and math.abs(d.y) <= kNexusReachUp and (not best or horizontal < bestDist) then
                best, bestDist = nexus, horizontal
            end
        end
        if not best then
            return
        end
        local ok, reason = best:VT_TryLogin(player)
        if not ok then
            VT_SendMessageToPlayer(player, "Cannot enter the Nexus: " .. reason .. ".")
        end
    end

end

if Client then

    -- core crystal glow instead of the command station screens
    function VTNexus:OnUpdateRender()
        VTBase.CommandStation.OnUpdateRender(self)
        VT_UpdateGlowLight(self, "vtCoreLight", 2.6, 9, 6, 1.6)
    end

    function VTNexus:OnDestroy()
        VT_DestroyGlowLight(self, "vtCoreLight")
        VTBase.CommandStation.OnDestroy(self)
    end

end

function VTNexus:GetMapBlipType()
    return kMinimapBlipType.CommandStation
end

local N = kTechId.None

local kNexusButtons =
{
    kTechId.VTEdictRequisition, kTechId.VTEdictRelentless, kTechId.VTEdictIronDiscipline, kTechId.VTArchonsThrone,
    kTechId.VTQuotaMenu,        N,                         N,                             N,
}

local kQuotaMenuButtons =
{
    kTechId.VTQuotaInfiltratorUp, kTechId.VTQuotaInfiltratorDown, kTechId.VTQuotaSubjectUp, kTechId.VTQuotaSubjectDown,
    kTechId.VTQuotaPraetorUp,     kTechId.VTQuotaPraetorDown,     N,                        kTechId.RootMenu,
}

-- techId -> { quota field name, delta }
kVTQuotaActions =
{
    [kTechId.VTQuotaInfiltratorUp]   = { "Infiltrator",  1 },
    [kTechId.VTQuotaInfiltratorDown] = { "Infiltrator", -1 },
    [kTechId.VTQuotaSubjectUp]       = { "Subject",      1 },
    [kTechId.VTQuotaSubjectDown]     = { "Subject",     -1 },
    [kTechId.VTQuotaPraetorUp]       = { "Praetor",      1 },
    [kTechId.VTQuotaPraetorDown]     = { "Praetor",     -1 },
}

local kEdictMessages =
{
    [kTechId.VTEdictRequisition]    = "VT_MSG_REQUISITION",
    [kTechId.VTEdictRelentless]     = "VT_MSG_RELENTLESS",
    [kTechId.VTEdictIronDiscipline] = "VT_MSG_IRON",
}

function VTNexus:GetTechButtons(techId)
    if techId == kTechId.VTQuotaMenu then
        return kQuotaMenuButtons
    end
    local buttons = table.duplicate and table.duplicate(kNexusButtons) or { unpack(kNexusButtons) }
    if self:GetTechId() ~= kTechId.VTNexusGate then
        buttons[6] = kTechId.VTNexusGateUpgrade
    end
    return buttons
end

local function GetEmpireActionAllowed(techId)

    local info = VT_GetEmpireInfo and VT_GetEmpireInfo()
    if not info then
        return false
    end

    if kEdictMessages[techId] then
        return info:GetEdictReady(techId)
    end

    local quota = kVTQuotaActions[techId]
    if quota then
        local current = info:GetQuota(quota[1])
        local target = current + quota[2]
        return target >= 0 and target <= kVTQuotaMax[quota[1]]
    end

    return nil

end

local oldGetTechAllowed = CommandStation.GetTechAllowed
function VTNexus:GetTechAllowed(techId, techNode, player)

    local allowed, canAfford = oldGetTechAllowed(self, techId, techNode, player)

    local empireAllowed = GetEmpireActionAllowed(techId)
    if empireAllowed ~= nil then
        allowed = allowed and empireAllowed and self:GetIsBuilt() and self:GetIsAlive()
    end

    return allowed, canAfford

end

if Server then

    local oldPerformActivation = CommandStation.PerformActivation
    function VTNexus:PerformActivation(techId, position, normal, commander)

        local info = VT_GetEmpireInfo and VT_GetEmpireInfo()

        if info and GetEmpireActionAllowed(techId) then

            if kEdictMessages[techId] then
                info:IssueEdict(techId)
                VT_AnnounceToTeam(kEdictMessages[techId])
                return true, true
            end

            local quota = kVTQuotaActions[techId]
            if quota then
                info:SetQuota(quota[1], info:GetQuota(quota[1]) + quota[2])
                return true, true
            end

        end

        if oldPerformActivation then
            return oldPerformActivation(self, techId, position, normal, commander)
        end
        return ScriptActor.PerformActivation(self, techId, position, normal, commander)

    end

end

VT_InstallShield(VTNexus, false)
VT_InstallStructureScale(VTNexus, "nexus")
Shared.LinkClassToMap("VTNexus", VTNexus.kMapName, VT_AddShieldNetworkVars({}))

-- ----------------------------------------------------------------------------
-- Resource Siphon
-- ----------------------------------------------------------------------------
class 'VTSiphon' (Extractor)

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTSiphon, { "Extractor", "ResourceTower" })

VTSiphon.kMapName = kVTMapNames.Siphon

function VTSiphon:GetMapBlipType()
    return kMinimapBlipType.Extractor
end

-- Own static model (art/buildings/build_all.sh siphon): 2.3 x 2.6 x 3.2 m over the resource nozzle.
kVTSiphonModel = PrecacheAsset("models/vaelthor/siphon/siphon.model")

function VTSiphon:OnInitialized()
    VTBase.Extractor.OnInitialized(self)
    self:SetModel(kVTSiphonModel)
end

if Client then
    function VTSiphon:OnUpdateRender()
        VT_UpdateGlowLight(self, "vtSiphonLight", 2.9, 5, 3, 2.6)
    end

    function VTSiphon:OnDestroy()
        VT_DestroyGlowLight(self, "vtSiphonLight")
        VTBase.Extractor.OnDestroy(self)
    end
end

VT_InstallShield(VTSiphon, false)
VT_InstallStructureScale(VTSiphon, "siphon")
Shared.LinkClassToMap("VTSiphon", VTSiphon.kMapName, VT_AddShieldNetworkVars({}))
