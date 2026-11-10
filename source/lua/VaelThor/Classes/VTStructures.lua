-- ============================================================================
-- Vael'Thor structures (prototyped on marine structure models)
--   Subvention Pylon   -> Sentry Battery  (projects the Subvention field)
--   Synthesis Chamber  -> Arms Lab        (spawn point + research)
--   Shield Generator   -> Observatory     (ranged damage reduction aura)
--   Rift Portal        -> Phase Gate      (two-way teleport network)
-- The Imperial Nexus and Resource Siphon live in Classes/VTNexus.lua.
-- Every structure has a psi shield (Classes/VTShield.lua), filled on completion.
--
-- Power: structures that require power are switched on/off by VTTeam
-- depending on whether they stand inside the Subvention field.
-- ============================================================================

local N = kTechId.None

-- ----------------------------------------------------------------------------
-- Subvention Pylon
-- ----------------------------------------------------------------------------
class 'VTSubventionPylon' (SentryBattery)

VTSubventionPylon.kMapName = kVTMapNames.Pylon

local pylonNetworkVars =
{
    vtResonant = "boolean",     -- Resonant Pylon upgrade completed
}

function VTSubventionPylon:OnCreate()
    SentryBattery.OnCreate(self)
    self.vtResonant = false
end

function VTSubventionPylon:GetRequiresPower()
    return false
end

-- The pylon *is* the power source. Without this it reports unpowered (map
-- power nodes ignore the empire), and PowerConsumerMixin:GetCanBeUsed then
-- blocks every "use" - no E prompt for gate jumps.
function VTSubventionPylon:GetIsPowered()
    return true
end

function VTSubventionPylon:GetVTFieldRadius()
    return self.vtResonant and kVTResonantFieldRadius or kVTFieldRadiusPylon
end

-- Range ring when the pylon is selected (ScriptActor:GetVisualRadius).
function VTSubventionPylon:GetVisualRadius()
    return self:GetVTFieldRadius()
end

function VTSubventionPylon:GetTechButtons(techId)
    return { self.vtResonant and N or kTechId.VTResonantPylonUpgrade, N, N, N, N, N, N, N }
end

function VTSubventionPylon:GetMapBlipType()
    return kMinimapBlipType.SentryBattery
end

-- Own static model (art/buildings/build_all.sh pylon): 1.4 x 1.7 x 3.2 m, floating crystal over three fins.
kVTPylonModel = PrecacheAsset("models/vaelthor/pylon/pylon.model")

function VTSubventionPylon:OnInitialized()
    SentryBattery.OnInitialized(self)
    self:SetModel(kVTPylonModel)
end

if Client then
    function VTSubventionPylon:OnUpdateRender()
        VT_UpdateGlowLight(self, "vtCrystalLight", 2.6, 6, 4, 1.8)
    end

    function VTSubventionPylon:OnDestroy()
        VT_DestroyGlowLight(self, "vtCrystalLight")
        SentryBattery.OnDestroy(self)
    end
end

-- ---- Nexus Gate jumps: press E on a pylon connected to a Nexus Gate --------
function VTSubventionPylon:GetCanBeUsed(player, useSuccessTable)
    local allowed = self:GetIsBuilt() and player and VT_GetIsVTEntity(player) and player:GetIsAlive()
            and not player:isa("Commander")
    if allowed then
        local hasGates = VT_GetGateJumpOptions(self)
        allowed = hasGates
    end
    if not allowed then
        useSuccessTable.useSuccess = false
    end
end

function VTSubventionPylon:GetCanBeUsedConstructed(byPlayer)
    return true
end

-- Allow gate jumps in the pre-game and warmup phases too (the engine blocks
-- "use" before the round starts unless the entity opts in).
function VTSubventionPylon:GetUseAllowedBeforeGameStart()
    return true
end

function VTSubventionPylon:GetCanBeUsedDuringWarmup()
    return true
end

if Client then
    function VTSubventionPylon:OnUse(player, elapsedTime, useSuccessTable)
        if not Shared.GetIsRunningPrediction() and Client.GetLocalPlayer() == player and VT_OpenGateMenu then
            VT_OpenGateMenu(self)
        end
    end
end

VT_InstallShield(VTSubventionPylon, false)
Shared.LinkClassToMap("VTSubventionPylon", VTSubventionPylon.kMapName, VT_AddShieldNetworkVars(pylonNetworkVars))

-- ----------------------------------------------------------------------------
-- Synthesis Chamber
-- ----------------------------------------------------------------------------
class 'VTSynthesisChamber' (ArmsLab)

VTSynthesisChamber.kMapName = kVTMapNames.Chamber

local function NextLevel(self, level1, level2, level3)
    if GetHasTech(self, level2, true) then
        return level3
    elseif GetHasTech(self, level1, true) then
        return level2
    end
    return level1
end

function VTSynthesisChamber:GetTechButtons(techId)
    return
    {
        NextLevel(self, kTechId.Weapons1, kTechId.Weapons2, kTechId.Weapons3),
        NextLevel(self, kTechId.Armor1, kTechId.Armor2, kTechId.Armor3),
        kTechId.VTAuthorizationTier2,
        kTechId.VTAuthorizationTier3,
        kTechId.VTOverchargeTech,
        kTechId.VTSingularityTech,
        kTechId.VTPhaseDashTech,
        kTechId.VTShieldOverdriveTech,
    }
end

function VTSynthesisChamber:GetMapBlipType()
    return kMinimapBlipType.ArmsLab
end

-- Own static model (Tripo, art/fab/synthesis_chamber/build_chamber.sh): 2.05 x 2.08 x 2.6 m, three convex
-- collision hulls (base slab / vat / cap) compiled in. No animation graph: the Arms Lab's deploy/flinch
-- animations and its hologram don't apply.
kVTChamberModel = PrecacheAsset("models/vaelthor/chamber/chamber.model")

function VTSynthesisChamber:OnInitialized()
    ArmsLab.OnInitialized(self)
    self:SetModel(kVTChamberModel)
end

if Client then

    -- Instead of the Arms Lab hologram: a slowly pulsing violet light inside the vat (VT_UpdateGlowLight, VTNexus.lua).
    function VTSynthesisChamber:OnUpdateRender()
        VT_UpdateGlowLight(self, "vtVatLight", 1.3, 5, 4)
    end

    function VTSynthesisChamber:OnDestroy()
        VT_DestroyGlowLight(self, "vtVatLight")
        ArmsLab.OnDestroy(self)
    end

end

VT_InstallShield(VTSynthesisChamber, false)
Shared.LinkClassToMap("VTSynthesisChamber", VTSynthesisChamber.kMapName, VT_AddShieldNetworkVars({}))

-- ----------------------------------------------------------------------------
-- Shield Generator
-- ----------------------------------------------------------------------------
class 'VTShieldGenerator' (Observatory)

VTShieldGenerator.kMapName = kVTMapNames.ShieldGen

local shieldGenNetworkVars =
{
    vtAegis = "boolean",        -- Aegis Array upgrade completed
}

function VTShieldGenerator:OnCreate()
    Observatory.OnCreate(self)
    self.vtAegis = false
end

function VTShieldGenerator:GetTechButtons(techId)
    return { self.vtAegis and N or kTechId.VTAegisArrayUpgrade, kTechId.VTTargetingVisorTech, N, N, N, N, N, N }
end

function VTShieldGenerator:GetMapBlipType()
    return kMinimapBlipType.Observatory
end

-- Own static model (art/buildings/build_all.sh shieldgen): 3.3 x 3.3 x 2.4 m lattice dome over an emitter.
kVTShieldGenModel = PrecacheAsset("models/vaelthor/shieldgen/shieldgen.model")

function VTShieldGenerator:OnInitialized()
    Observatory.OnInitialized(self)
    self:SetModel(kVTShieldGenModel)
end

if Client then
    function VTShieldGenerator:OnUpdateRender()
        VT_UpdateGlowLight(self, "vtEmitterLight", 1.6, 6, 4, 2.0)
    end

    function VTShieldGenerator:OnDestroy()
        VT_DestroyGlowLight(self, "vtEmitterLight")
        Observatory.OnDestroy(self)
    end
end

if Server then
    -- No distress beacon / scans: the generator only projects its aura.
    function VTShieldGenerator:PerformActivation(techId, position, normal, commander)
        return ScriptActor.PerformActivation(self, techId, position, normal, commander)
    end
end

VT_InstallShield(VTShieldGenerator, false)
Shared.LinkClassToMap("VTShieldGenerator", VTShieldGenerator.kMapName, VT_AddShieldNetworkVars(shieldGenNetworkVars))

-- ----------------------------------------------------------------------------
-- Rift Portal
-- ----------------------------------------------------------------------------
class 'VTRiftPortal' (PhaseGate)

VTRiftPortal.kMapName = kVTMapNames.Rift

function VTRiftPortal:GetMapBlipType()
    return kMinimapBlipType.PhaseGate
end

-- Own static model (art/buildings/build_all.sh rift): 3.3 x 2.6 x 3.0 m gate ring on a pad. Collision is only
-- the low pad: players must reach its centre (within 0.5 m of the origin) to teleport.
kVTRiftModel = PrecacheAsset("models/vaelthor/rift/rift.model")

function VTRiftPortal:OnInitialized()
    PhaseGate.OnInitialized(self)
    self:SetModel(kVTRiftModel)
end

-- vanilla sets 'deployed' on the deploy animation's "deploy_end" tag, and only deployed gates link/teleport
function VTRiftPortal:OnConstructionComplete()
    self.deployed = true
end

function VTRiftPortal:GetIsDeployed()
    return self:GetIsBuilt()
end

if Client then
    function VTRiftPortal:OnUpdateRender()
        PhaseGate.OnUpdateRender(self)
        VT_UpdateGlowLight(self, "vtRiftLight", 1.5, 6, 4, 3.0)
    end

    function VTRiftPortal:OnDestroy()
        VT_DestroyGlowLight(self, "vtRiftLight")
        PhaseGate.OnDestroy(self)
    end
end

VT_InstallShield(VTRiftPortal, false)
Shared.LinkClassToMap("VTRiftPortal", VTRiftPortal.kMapName, VT_AddShieldNetworkVars({}))

-- ----------------------------------------------------------------------------
-- Sentinel Obelisk (Sentry): psionic beam turret powered by the Subvention field.
-- The vanilla sentry looks for a Sentry Battery within 4 m; that check is
-- disabled here and VTTeam:UpdateSubventionNetwork sets attachedToBattery
-- from the field instead.
--
-- Steady beams instead of bullets (server, every kVTObeliskTickInterval):
--   * up to vtBeamCount beams, each on a DIFFERENT target; the count is limited by the per-structure lenses
--     (vtBeamLevel 0 = 1 beam, Prism Lens = 2, Trinity Lens = 3) and chosen by the commander (Single/Split).
--   * each beam deals kVTObeliskBeamDPS x kVTObeliskBeamScalars[level][count] per second, so splitting
--     trades single-target damage for coverage even if fewer targets are in range.
--   * beam 1 goes to the commander's focus target (Focus Beam, Hooks/MarineCommander.lua) while it is
--     attackable; otherwise targets are kept while valid and refilled from the vanilla target selector.
-- Beam targets are networked (vtBeamTarget1-3) and drawn on the client as violet beams with the vanilla laser
-- material (ui/laser.material, Emissive shader) - no new material assets.
-- ----------------------------------------------------------------------------
class 'VTSentinelObelisk' (Sentry)

VTSentinelObelisk.kMapName = kVTMapNames.Obelisk

local kMaxBeams = 3

-- Beam sound: a vanilla looping event (custom sounds would need an own FMOD bank): the nanoshield energy hum.
-- Alternative with an electric crackle: "sound/NS2.fev/marine/welder/weld" (welder loop).
local kBeamLoopSound = PrecacheAsset("sound/NS2.fev/marine/commander/nano_loop")

local obeliskNetworkVars =
{
    vtBeamLevel   = "integer (0 to 2)",     -- 0 none, 1 Prism Lens, 2 Trinity Lens
    vtBeamCount   = "integer (1 to 3)",     -- commander's choice (clamped to the level)
    vtFocusId     = "entityid",
    vtBeamTarget1 = "entityid",
    vtBeamTarget2 = "entityid",
    vtBeamTarget3 = "entityid",
}

function VTSentinelObelisk:OnCreate()
    Sentry.OnCreate(self)
    -- Never run Sentry's battery search (it only runs when this time is past).
    self.lastBatteryCheckTime = math.huge
    -- No idle scan "ping": Sentry's client timer plays sentry_scan when
    -- timeLastAttackEffect + kTargetScanDelay + kPingInterval has passed; with this instance override it never does.
    self.kTargetScanDelay = math.huge
    -- Sentry's server-side loop sound entity (parented, networked): the beam hum instead of the gun loop.
    if Server and self.attackSound then
        self.attackSound:SetAsset(kBeamLoopSound)
    end
    self.vtBeamLevel = 0
    self.vtBeamCount = 1
    self.vtFocusId = Entity.invalidId
    for i = 1, kMaxBeams do
        self["vtBeamTarget" .. i] = Entity.invalidId
    end
end

function VTSentinelObelisk:GetMapBlipType()
    return kMinimapBlipType.Sentry
end

-- Own static model (art/buildings/build_all.sh obelisk): 1.9 x 1.9 x 3.8 m, crystal head in three prongs.
-- The vanilla sentry aims and fires from attach points (fxnode_sentrymuzzle / fxnode_eye) and turns its
-- barrel with pose parameters; the obelisk fires from its crystal head and doesn't need to turn.
kVTObeliskModel = PrecacheAsset("models/vaelthor/obelisk/obelisk.model")
local kObeliskHeadHeight = 3.3

function VTSentinelObelisk:OnInitialized()
    Sentry.OnInitialized(self)
    self:SetModel(kVTObeliskModel)
    if Server then
        VT_InitObeliskTargeting(self)
    end
end

if Server then

    -- Own target selector instead of Sentry's:
    --  * target lists by the ENEMY team's type. Sentry hard-codes kMarineStaticTargets/kMarineMobileTargets
    --    (= alien-type entities), so in Vael'Thor vs. Marines the Obelisk never targeted the marines.
    --  * an explicit enemy check: the Vael'Thor team is marine-typed as well, so the marine-type lists also
    --    contain our own soldiers and structures.
    --  * no PitchTargetFilter (all-round fire): it measures the angle against the sentry's facing with atan2,
    --    so anything behind it (180 deg) was rejected = front half only. Cloaked targets stay out.
    function VT_InitObeliskTargeting(self)

        local old = self.targetSelector
        if old then
            for _, targetType in ipairs(old.targetTypeList) do
                targetType:DetachSelector(old)      -- idempotent; its destroy callback detaches again later
            end
        end

        local enemyTeam = GetEnemyTeamNumber(self:GetTeamNumber())
        -- same source as TeamMixin:GetTeamType(), which the target lists filter on (its table is file-local)
        local enemyType = GetTeamTypeFromTeamIndex(enemyTeam)
        local targetTypes
        if enemyType == kMarineTeamType then
            targetTypes = { kAlienStaticTargets, kAlienMobileTargets }     -- lists of marine-type entities
        else
            targetTypes = { kMarineStaticTargets, kMarineMobileTargets }   -- lists of alien-type entities
        end

        local obelisk = self
        self.targetSelector = TargetSelector():Init(
            self,
            kVTObeliskRange,
            true,
            targetTypes,
            { CloakTargetFilter(), function(target) return GetAreEnemies(obelisk, target) end },
            { function(target) return target:isa("Player") end })

    end

end

-- All-round vision (vanilla sentry: 160 deg). Used by the line-of-sight check of the target selector
-- (GetCanSeeEntity) and by the commander's vision cone.
function VTSentinelObelisk:GetFov()
    return 360
end

local function ObeliskHead(self)
    return self:GetOrigin() + Vector(0, kObeliskHeadHeight, 0)
end

-- Range and line-of-sight checks of the target selector start here (vanilla: 0.8 m above the origin).
function VTSentinelObelisk:GetEyePos()
    return ObeliskHead(self)
end

function VTSentinelObelisk:GetBarrelPoint()
    return ObeliskHead(self)
end

function VTSentinelObelisk:GetLaserAttachCoords()
    local coords = self:GetCoords()
    coords.origin = ObeliskHead(self)
    return coords
end

-- BaseModelMixin falls back to this for attach points the model doesn't have (as for the vanilla Mine):
-- every sentry node (muzzle, eye/laser) is the crystal head.
function VTSentinelObelisk:GetAttachPointOriginHardcoded(name)
    return ObeliskHead(self)
end

-- Number of beams actually fired: the commander's choice, limited by the installed lenses.
function VTSentinelObelisk:VT_GetBeamCount()
    return math.max(1, math.min(self.vtBeamCount or 1, (self.vtBeamLevel or 0) + 1))
end

-- Damage of each beam relative to the base (kVTObeliskBeamScalars).
function VTSentinelObelisk:VT_GetBeamScalar()
    local row = kVTObeliskBeamScalars[self.vtBeamLevel or 0] or kVTObeliskBeamScalars[0]
    return row[self:VT_GetBeamCount()] or row[#row]
end

-- ---------------------------------------------------------------- commander
local kBeamButtons = { kTechId.VTObeliskBeams1, kTechId.VTObeliskBeams2, kTechId.VTObeliskBeams3 }
local kBeamButtonCount =
{
    [kTechId.VTObeliskBeams1] = 1,
    [kTechId.VTObeliskBeams2] = 2,
    [kTechId.VTObeliskBeams3] = 3,
}

function VTSentinelObelisk:GetTechButtons(techId)

    local level = self.vtBeamLevel or 0
    local upgrade = N
    if level == 0 then
        upgrade = kTechId.VTObeliskPrismUpgrade
    elseif level == 1 then
        upgrade = kTechId.VTObeliskTrinityUpgrade
    end

    -- beam count buttons only once there is a choice (Prism Lens or better)
    local buttons = { kTechId.VTObeliskFocus, N, N, N, upgrade, N, N, N }
    if level >= 1 then
        for count = 1, level + 1 do
            buttons[count + 1] = kBeamButtons[count]
        end
    end
    return buttons

end

function VTSentinelObelisk:GetTechAllowed(techId, techNode, player)

    local allowed, canAfford = ScriptActor.GetTechAllowed(self, techId, techNode, player)
    local level = self.vtBeamLevel or 0

    local count = kBeamButtonCount[techId]
    if count then
        -- the active setting is shown greyed out
        allowed = allowed and self:GetIsBuilt() and count <= level + 1 and count ~= self:VT_GetBeamCount()
    elseif techId == kTechId.VTObeliskFocus then
        allowed = allowed and self:GetIsBuilt()
    elseif techId == kTechId.VTObeliskPrismUpgrade then
        allowed = allowed and level == 0
    elseif techId == kTechId.VTObeliskTrinityUpgrade then
        allowed = allowed and level == 1
    end

    return allowed, canAfford

end

if Server then

    function VTSentinelObelisk:PerformActivation(techId, position, normal, commander)

        local count = kBeamButtonCount[techId]
        if count then
            if count > (self.vtBeamLevel or 0) + 1 then
                return false, true
            end
            self.vtBeamCount = count
            self.vtNextBeamTick = 0          -- re-target right away
            return true, true
        end

        return ScriptActor.PerformActivation(self, techId, position, normal, commander)

    end

    -- Called by the commander's Focus Beam (nil = release the focus).
    function VTSentinelObelisk:VT_SetFocusTarget(target)
        self.vtFocusId = target and target:GetId() or Entity.invalidId
        self.vtNextBeamTick = 0
    end

    -- ------------------------------------------------------------- beams
    local function GetLiveEntity(id)
        local ent = id and id ~= Entity.invalidId and Shared.GetEntity(id)
        if ent and HasMixin(ent, "Live") and ent:GetIsAlive() then
            return ent
        end
        return nil
    end

    local function SelectTargets(self, maxBeams)

        local targets, used = {}, {}
        local function Add(target)
            if target and not used[target:GetId()] and #targets < maxBeams then
                used[target:GetId()] = true
                targets[#targets + 1] = target
            end
        end

        -- 1. commander focus (kept while alive and nearby; only fired at while attackable)
        local focus = GetLiveEntity(self.vtFocusId)
        if self.vtFocusId ~= Entity.invalidId then
            local leash = kVTObeliskRange * kVTObeliskFocusLeash
            if not focus or (focus:GetOrigin() - self:GetOrigin()):GetLengthSquared() > leash * leash then
                self.vtFocusId = Entity.invalidId
                focus = nil
            end
        end
        if focus and self.targetSelector:ValidateTarget(focus) then
            Add(focus)
        end

        -- 2. keep the previous targets while they stay valid (no beam hopping)
        for _, id in ipairs(self.vtPrevTargetIds or {}) do
            local target = GetLiveEntity(id)
            if target and self.targetSelector:ValidateTarget(target) then
                Add(target)
            end
        end

        -- 3. fill up with new targets (vanilla priorities: players first)
        if #targets < maxBeams then
            for _, target in ipairs(self.targetSelector:AcquireTargets(maxBeams + kMaxBeams)) do
                Add(target)
            end
        end

        local ids = {}
        for i, target in ipairs(targets) do
            ids[i] = target:GetId()
        end
        self.vtPrevTargetIds = ids

        return targets

    end

    -- Replaces Sentry's bullet salvo update (no bullets, no fire loop sound, no battery search).
    function VTSentinelObelisk:OnUpdate(deltaTime)

        ScriptActor.OnUpdate(self, deltaTime)

        local now = Shared.GetTime()

        -- stun (Sentry:OnStun -> Confuse) wears off here; vanilla's spore check is local to Sentry.lua
        if self.confused and self.timeConfused and self.timeConfused < now then
            self.confused = false
        end

        if now < (self.vtNextBeamTick or 0) then
            return
        end
        self.vtNextBeamTick = now + kVTObeliskTickInterval

        -- capped: no damage burst after the Obelisk slept or was idle
        local elapsed = math.min(now - (self.vtLastBeamTick or now), kVTObeliskTickInterval * 2.5)
        self.vtLastBeamTick = now

        local targets = {}
        if GetIsUnitActive(self) and self.attachedToBattery and self.deployed then
            targets = SelectTargets(self, self:VT_GetBeamCount())
        else
            self.vtPrevTargetIds = nil
        end

        for i = 1, kMaxBeams do
            self["vtBeamTarget" .. i] = targets[i] and targets[i]:GetId() or Entity.invalidId
        end
        self.attacking = #targets > 0
        self.target = targets[1]

        -- one beam loop per Obelisk while any beam is firing
        local sound = self.attackSound
        if sound then
            if self.attacking and not sound:GetIsPlaying() then
                sound:Start()
            elseif not self.attacking and sound:GetIsPlaying() then
                sound:Stop()
            end
        end

        if #targets == 0 or elapsed <= 0 then
            return
        end

        local damage = kVTObeliskBeamDPS * self:VT_GetBeamScalar() * elapsed
        if self.confused then
            damage = damage * kVTObeliskConfusedScalar
        end

        local head = ObeliskHead(self)
        for _, target in ipairs(targets) do
            local point = target:GetEngagementPoint()
            local direction = GetNormalizedVector(point - head)
            self.targetDirection = direction
            -- surface "none": no impact effects every tick (the client draws the beam and its glow instead)
            self:DoDamage(damage, target, point, direction, "none", false, false)
        end

    end

end

if Client then

    -- Own beam texture (art/effects/build_obelisk_beam.sh): violet glow over the full strip width with a bright
    -- core, coloured in the texture itself; Emissive shader, emissiveMap only (like vanilla ui/laser.material,
    -- which is a red 1-3 px hairline and made the beam practically invisible).
    local kBeamMaterial = PrecacheAsset("models/vaelthor/beam/obelisk_beam.material")
    local kBeamColorStart = Color(1, 1, 1, 1)          -- near white: the texture carries the colour
    local kBeamColorEnd   = Color(0.85, 0.85, 0.85, 1)
    local kBeamWidth = 0.09                            -- half width: the strip is 18 cm wide
    local kImpactLightColor = Color(0.7, 0.35, 1.0, 1)

    local function CreateBeamFx()
        local fx = { meshes = {} }
        for i = 1, 2 do            -- camera-facing strip + the same strip turned 90 degrees
            local mesh = DynamicMesh_Create()
            mesh:SetMaterial(kBeamMaterial)
            fx.meshes[i] = mesh
        end
        fx.light = Client.CreateRenderLight()
        fx.light:SetType(RenderLight.Type_Point)
        fx.light:SetCastsShadows(false)
        fx.light:SetColor(kImpactLightColor)
        fx.light:SetRadius(1.6)
        fx.light:SetIntensity(6)
        return fx
    end

    local function SetBeamFxVisible(fx, visible)
        if fx.visible == visible then
            return
        end
        fx.visible = visible
        for _, mesh in ipairs(fx.meshes) do
            mesh:SetIsVisible(visible)
        end
        fx.light:SetIsVisible(visible)
    end

    local function DestroyBeamFx(fx)
        for _, mesh in ipairs(fx.meshes) do
            DynamicMesh_Destroy(mesh)
        end
        Client.DestroyRenderLight(fx.light)
    end

    -- Strips facing the viewer: a strip that contains the beam axis is seen edge-on from any point on that axis,
    -- and the target's own camera sits almost on it (the beam ends at its body) - so the old fixed cross of two
    -- strips was invisible to the player being shot. Each frame the strip is turned around the beam axis towards
    -- the camera; the second pair is the same strip turned 90 degrees, for volume when seen from the side.
    local function GetBeamCoords(startPoint, direction, cameraPos)
        local toCamera = cameraPos - startPoint
        local side = direction:CrossProduct(toCamera)
        if side:GetLengthSquared() < 1e-6 then
            side = direction:CrossProduct(Vector(0, 1, 0))
            if side:GetLengthSquared() < 1e-6 then side = Vector(1, 0, 0) end
        end
        side:Normalize()
        local facing = Coords.GetIdentity()
        facing.origin = startPoint
        facing.zAxis = direction
        facing.xAxis = side
        facing.yAxis = direction:CrossProduct(side)
        local turned = Coords.GetIdentity()
        turned.origin = startPoint
        turned.zAxis = direction
        turned.xAxis = facing.yAxis
        turned.yAxis = -side
        return facing, turned
    end

    local function UpdateBeamFx(fx, startPoint, endPoint, index, cameraPos)

        local toEnd = endPoint - startPoint
        local length = toEnd:GetLength()
        if length < 0.1 then
            SetBeamFxVisible(fx, false)
            return
        end
        local direction = toEnd / length

        local coords, crossed = GetBeamCoords(startPoint, direction, cameraPos)

        -- a steady beam with a slight shimmer
        local t = Shared.GetTime()
        local shimmer = 1 + 0.12 * math.sin(t * 37 + index * 2.1) + 0.06 * math.sin(t * 91 + index)

        DynamicMesh_SetLine(fx.meshes[1], coords,  kBeamWidth * shimmer, length, kBeamColorStart, kBeamColorEnd)
        DynamicMesh_SetLine(fx.meshes[2], crossed, kBeamWidth * shimmer * 0.6, length, kBeamColorStart, kBeamColorEnd)

        local lightCoords = Coords.GetIdentity()
        lightCoords.origin = endPoint - direction * 0.3
        fx.light:SetCoords(lightCoords)
        fx.light:SetIntensity(5 + 2 * shimmer)

        SetBeamFxVisible(fx, true)

    end

    -- Where the beam ends on its target. For the local player in first person it ends a bit below and in front
    -- of the camera (its chest as seen from its own eyes), so the player sees the beam come in instead of
    -- having it drawn into the eye.
    local function GetBeamEndPoint(target, localPlayer, cameraCoords)
        if target == localPlayer and cameraCoords and not (target.GetIsThirdPerson and target:GetIsThirdPerson()) then
            local forward = Vector(cameraCoords.zAxis.x, 0, cameraCoords.zAxis.z)
            if forward:GetLengthSquared() > 1e-6 then forward:Normalize() end
            return cameraCoords.origin + forward * 0.35 - Vector(0, 0.35, 0)
        end
        return target:GetEngagementPoint()
    end

    local function UpdateBeams(self)

        self.vtBeamFx = self.vtBeamFx or {}
        local active = GetIsUnitActive(self) and self.attachedToBattery
        local head = ObeliskHead(self)
        local localPlayer = Client.GetLocalPlayer()
        local cameraCoords = localPlayer and localPlayer.GetCameraViewCoords and localPlayer:GetCameraViewCoords()
        local cameraPos = cameraCoords and cameraCoords.origin or (head + Vector(0, 2, 0))

        for i = 1, kMaxBeams do
            local id = self["vtBeamTarget" .. i]
            local target = active and id ~= Entity.invalidId and Shared.GetEntity(id)
            local fx = self.vtBeamFx[i]
            if target and target.GetEngagementPoint then
                if not fx then
                    if VT_Breadcrumb then VT_Breadcrumb("obelisk_beam", "obelisk beam: creating first beam meshes") end
                    fx = CreateBeamFx()
                    self.vtBeamFx[i] = fx
                end
                if target == localPlayer and VT_Breadcrumb then
                    VT_Breadcrumb("obelisk_beam_self", "obelisk beam: drawing a beam on the local player")
                end
                UpdateBeamFx(fx, head, GetBeamEndPoint(target, localPlayer, cameraCoords), i, cameraPos)
            elseif fx then
                SetBeamFxVisible(fx, false)
            end
        end

    end

    -- Replaces Sentry's client update: no barrel swing, no muzzle flash / shell effects.
    function VTSentinelObelisk:OnUpdate(deltaTime)
        ScriptActor.OnUpdate(self, deltaTime)
    end

    function VTSentinelObelisk:OnUpdateRender()
        if Sentry.OnUpdateRender then
            Sentry.OnUpdateRender(self)
        end
        VT_UpdateGlowLight(self, "vtHeadLight", kObeliskHeadHeight, 5, 4, 2.4)
        UpdateBeams(self)
    end

    function VTSentinelObelisk:OnDestroy()
        VT_DestroyGlowLight(self, "vtHeadLight")
        for _, fx in pairs(self.vtBeamFx or {}) do
            DestroyBeamFx(fx)
        end
        self.vtBeamFx = nil
        Sentry.OnDestroy(self)
    end
end

VT_InstallShield(VTSentinelObelisk, false)
Shared.LinkClassToMap("VTSentinelObelisk", VTSentinelObelisk.kMapName, VT_AddShieldNetworkVars(obeliskNetworkVars))

-- ----------------------------------------------------------------------------
-- Psionic Spire (Prototype Lab): psionic research.
-- ----------------------------------------------------------------------------
class 'VTPsionicSpire' (PrototypeLab)

VTPsionicSpire.kMapName = kVTMapNames.Spire

function VTPsionicSpire:GetTechButtons(techId)
    return
    {
        kTechId.VTPhaseCloakTech, kTechId.VTNeuralOverrideTech, kTechId.VTPsionicEdictsTech, N,
        N, N, N, N,
    }
end

function VTPsionicSpire:GetMapBlipType()
    return kMinimapBlipType.PrototypeLab
end

-- Own static model (Tripo, art/fab/psionic_spire/build_spire.sh): 2.33 x 2.33 x 5.0 m, collision = base slab,
-- tapering tower, crystal crown. No animation graph (the Prototype Lab's login/scan pose parameters only run
-- once its deploy animation has finished, which never happens here).
kVTSpireModel = PrecacheAsset("models/vaelthor/spire/spire.model")

function VTPsionicSpire:OnInitialized()
    PrototypeLab.OnInitialized(self)
    self:SetModel(kVTSpireModel)
end

-- Research building only: no Prototype Lab buy menu (jetpacks / exosuits) on E.
function VTPsionicSpire:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

if Client then

    -- glow in the crystal crown
    function VTPsionicSpire:OnUpdateRender()
        VT_UpdateGlowLight(self, "vtCrownLight", 4.5, 7, 5, 1.2)
    end

    function VTPsionicSpire:OnDestroy()
        VT_DestroyGlowLight(self, "vtCrownLight")
        PrototypeLab.OnDestroy(self)
    end

end

VT_InstallShield(VTPsionicSpire, false)
Shared.LinkClassToMap("VTPsionicSpire", VTPsionicSpire.kMapName, VT_AddShieldNetworkVars({}))
