-- ============================================================================
-- Vael'Thor castes. All prototyped on marine models:
--   Vanguard / Infiltrator / Subject  -> Marine subclasses
--   Praetor                           -> Exo subclass (dual minigun chassis)
--
-- Every caste has one active ability on TertiaryAttack (default key: B).
-- Loadout (vtModule / vtPrimaryMod / vtSecondary) is passed in as entity
-- extra values by VTTeam when the player is synthesized.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Shared caste behaviour
-- ----------------------------------------------------------------------------
local function AddVTNetworkVars(networkVars)
    networkVars.vtAbilityReadyTime = "time"
    networkVars.vtAbilityActiveEnd = "time"
    networkVars.vtModule           = "enum kVTModule"
    networkVars.vtPrimaryMod       = "enum kVTPrimaryMod"
    networkVars.vtSecondary        = "enum kVTSecondary"
    VT_AddShieldNetworkVars(networkVars)   -- psi shield (Classes/VTShield.lua)
    return networkVars
end

local function InitVTFields(self)
    self.vtAbilityReadyTime = 0
    self.vtAbilityActiveEnd = 0
    self.vtModule           = kVTModule.ShieldBoost
    self.vtPrimaryMod       = kVTPrimaryMod.Standard
    self.vtSecondary        = kVTSecondary.Pistol
    self.vtShieldBurnoutEnd = 0
end

-- Short-range directional teleport along the view direction (horizontal).
function VT_PerformBlink(player, distance)

    local viewCoords = player:GetViewCoords()
    local direction = Vector(viewCoords.zAxis.x, 0, viewCoords.zAxis.z)
    if direction:GetLength() < 0.01 then
        return false
    end
    direction:Normalize()

    local height, radius = player:GetTraceCapsule()
    local offset = Vector(0, height * 0.5 + radius + 0.05, 0)
    local startPoint = player:GetOrigin() + offset

    local trace = Shared.TraceCapsule(startPoint, startPoint + direction * distance, radius, height,
            CollisionRep.Move, PhysicsMask.Movement, EntityFilterOne(player))

    if (trace.endPoint - startPoint):GetLength() < 1 then
        return false
    end

    player:SetOrigin(trace.endPoint - direction * 0.1 - offset)
    player:TriggerEffects("phase_gate_player_teleport")
    return true

end

local Shared_ = {}

function Shared_:GetDeathMapName()
    return VTSpectator.kMapName
end

function Shared_:GetMapBlipType()
    return kMinimapBlipType.Marine
end

function Shared_:VT_GetAbilityReady()
    return Shared.GetTime() >= (self.vtAbilityReadyTime or 0)
end

function Shared_:VT_GetAbilityCooldownRemaining()
    return math.max(0, (self.vtAbilityReadyTime or 0) - Shared.GetTime())
end

function Shared_:VT_GetAbilityActive()
    return Shared.GetTime() < (self.vtAbilityActiveEnd or 0)
end

function Shared_:VT_StartCooldown(seconds)
    self.vtAbilityReadyTime = Shared.GetTime() + seconds
end

-- Press-edge of TertiaryAttack triggers the caste ability (server authoritative).
function Shared_:TertiaryAttack()
    if not self.tertiaryAttackLastFrame and Server and self:GetIsAlive()
            and self:VT_GetAbilityReady() and self.VT_UseAbility then
        self:VT_UseAbility()
    end
end

function Shared_:TertiaryAttackEnd()
end

function Shared_:VT_GetIsShieldBurntOut()
    return Shared.GetTime() < (self.vtShieldBurnoutEnd or 0)
end

-- No personal resources: the empire pays for everything from team resources.
if Server then
    function Shared_:AddResources(amount)
        return 0
    end
    function Shared_:SetResources(amount)
        self.resources = 0
    end
end

local function InstallShared(cls)
    for name, func in pairs(Shared_) do
        cls[name] = func
    end
end

-- ----------------------------------------------------------------------------
-- No sprinting for Vael'Thor infantry (marine-based castes). The sprint key is
-- removed from the input before SprintMixin reads it, and the sprint state is
-- always reported as off so the sprint speed bonus never applies. Class
-- methods win over the merged SprintMixin methods (class runs first and its
-- return value is used).
-- ----------------------------------------------------------------------------
local kNoSprintMask = bit.bnot(Move.MovementModifier)

local function StripSprintInput(input)
    input.commands = bit.band(input.commands, kNoSprintMask)
end

local function InstallNoSprint(cls)

    function cls:GetIsSprinting()
        return false
    end

    function cls:GetSprintingScalar()
        return 0
    end

    local baseOnProcessMove = cls.OnProcessMove
    function cls:OnProcessMove(input)
        -- Shift itself stays readable for caste abilities (Subject: sprint burst / wall hold).
        self.vtShiftHeld = bit.band(input.commands, Move.MovementModifier) ~= 0
        StripSprintInput(input)
        baseOnProcessMove(self, input)
    end

end

-- ----------------------------------------------------------------------------
-- No flashlight: the flashlight key toggles the Targeting Visor instead (a
-- client-side vision mode, GUI/GUIVTVision.lua). The key is removed from the
-- move before Marine:HandleButtons / Exo:OnProcessMove read it, and the light
-- is pinned off.
-- ----------------------------------------------------------------------------
local kNoFlashlightMask = bit.bnot(Move.ToggleFlashlight)
local function InstallNoFlashlight(cls)
    function cls:SetFlashlightOn(state)
        self.flashlightOn = false
    end
    function cls:GetFlashlightOn()
        return false
    end
    local baseOnProcessMove = cls.OnProcessMove
    function cls:OnProcessMove(input)
        input.commands = bit.band(input.commands, kNoFlashlightMask)
        -- No marine skins for Vael'Thor soldiers (own models). A robotic (BMAC) marine variant made
        -- MarineVariantMixin swap the first-person hands material into slot kBmacMaterialViewIndices["Axe"]
        -- = 1, which in our view models is the weapon -> robot-arm texture on knife/blades/claws.
        if Server and self.variant ~= nil and self.variant ~= kDefaultMarineVariant then
            self.variant = kDefaultMarineVariant
        end
        -- E near a Nexus takes command (Classes/VTNexus.lua), independent of the use trace
        if Server and VT_HandleNexusUse then
            VT_HandleNexusUse(self, input)
        end
        baseOnProcessMove(self, input)
    end
end

-- Armor is fixed per caste and never restored: Shield Matrix I-III (Armor1-3)
-- raises the max psi shield instead (VT_ComputeMaxShield), so GetArmorAmount
-- ignores the vanilla armor levels.

-- ----------------------------------------------------------------------------
-- Vanguard (Legionnaire)
-- ----------------------------------------------------------------------------
class 'VTVanguard' (Marine)

VTVanguard.kMapName = kVTMapNames.Vanguard

local vanguardNetworkVars = AddVTNetworkVars({})

function VTVanguard:OnCreate()
    Marine.OnCreate(self)
    InitVTFields(self)
end

-- Prototype player model: Fab "Silver Sentinel" rigged to the marine skeleton; it borrows all
-- animations from models/marine/male/male.model (see art/skeleton/, art/fab/silver_sentinel/).
-- The older robot model (models/vaelthor/robot/robot_player.model) is still built but unused.
kVTVanguardPlayerModel = PrecacheAsset("models/vaelthor/sentinel/sentinel_player.model")

function VTVanguard:GetVariantModel()
    return kVTVanguardPlayerModel
end

function VTVanguard:GetArmorAmount(armorLevels)
    return kVTVanguardArmor
end

function VTVanguard:OnProcessMove(input)
    Marine.OnProcessMove(self, input)
    local carbine = self:GetWeapon(VTPlasmaCarbine.kMapName)
    if carbine and carbine.VT_UpdateEnergy then
        carbine:VT_UpdateEnergy(self, input.time)
    end
end

function VTVanguard:GetMaxSpeed(possible)
    local speed = Marine.GetMaxSpeed(self, possible)
    if not possible and self.vtModule == kVTModule.ShieldOverdrive and self:VT_GetAbilityActive() then
        speed = speed * kVTOverdriveSpeedScalar
    end
    return speed
end

if Server then

    function VTVanguard:InitWeapons()

        Player.InitWeapons(self)

        local carbine = self:GiveItem(VTPlasmaCarbine.kMapName)
        if carbine and carbine.SetVTOvercharged then
            carbine:SetVTOvercharged(self.vtPrimaryMod == kVTPrimaryMod.Overcharge)
        end

        -- No pistol: the only sidearm a Vanguard can carry is the
        -- Singularity Launcher (rank III loadout).
        local quickSwitchMapName = VTPsionicKnife.kMapName
        if self.vtSecondary == kVTSecondary.Singularity then
            self:GiveItem(VTSingularityLauncher.kMapName)
            quickSwitchMapName = VTSingularityLauncher.kMapName
        end
        self:GiveItem(VTPsionicKnife.kMapName)

        self:SetQuickSwitchTarget(quickSwitchMapName)
        self:SetActiveWeapon(VTPlasmaCarbine.kMapName)

    end

    function VTVanguard:VT_UseAbility()

        local now = Shared.GetTime()

        if self.vtModule == kVTModule.PhaseDash then

            if VT_PerformBlink(self, kVTPhaseDashDistance) then
                self:VT_StartCooldown(kVTPhaseDashCooldown)
            end

        elseif self.vtModule == kVTModule.ShieldOverdrive then

            VT_SetShield(self, self:VT_GetMaxShield())
            self.vtAbilityActiveEnd = now + kVTOverdriveDuration
            self.vtShieldBurnoutEnd = now + kVTOverdriveDuration + kVTOverdriveBurnout
            self:VT_StartCooldown(kVTOverdriveCooldown)
            self:TriggerEffects("catpack_pickup")

            self:AddTimedCallback(function(player)
                if player:GetIsAlive() then
                    VT_SetShield(player, 0)
                end
                return false
            end, kVTOverdriveDuration)

        else -- Shield Boost

            if self.ActivateNanoShield then
                self:ActivateNanoShield()
            end
            self:VT_StartCooldown(kVTShieldBoostCooldown)

        end

    end

end

InstallShared(VTVanguard)
InstallNoSprint(VTVanguard)
InstallNoFlashlight(VTVanguard)
VT_InstallShield(VTVanguard, true)
Shared.LinkClassToMap("VTVanguard", VTVanguard.kMapName, vanguardNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Infiltrator: cloaking field (B), Psionic Blade, hack pulse (blade right-click)
-- ----------------------------------------------------------------------------
class 'VTInfiltrator' (Marine)

VTInfiltrator.kMapName = kVTMapNames.Infiltrator

local infiltratorNetworkVars = AddVTNetworkVars({
    vtEchoScanning = "boolean",   -- Echo Scan held: every VT client draws this cone's contacts
    vtHackReadyTime = "time",     -- networked for the HUD's hack cooldown line
})
AddMixinNetworkVars(CloakableMixin, infiltratorNetworkVars)

function VTInfiltrator:OnCreate()
    Marine.OnCreate(self)
    InitMixin(self, CloakableMixin)
    InitVTFields(self)
    self.vtHackReadyTime = 0
    self.vtEchoScanning = false
end

-- Player model: Fab "Cyber Sentinel" rigged to the marine skeleton (art/fab/cyber_sentinel/build_cyber.sh),
-- teal strips recoloured to Vael'Thor purple; borrows the marine animations like the Vanguard.
kVTInfiltratorPlayerModel = PrecacheAsset("models/vaelthor/cyber/cyber_player.model")

function VTInfiltrator:GetVariantModel()
    return kVTInfiltratorPlayerModel
end

function VTInfiltrator:GetArmorAmount(armorLevels)
    return kVTInfiltratorArmor
end

function VTInfiltrator:GetMaxSpeed(possible)
    return Marine.GetMaxSpeed(self, possible) * kVTInfiltratorSpeedScalar
end

-- Used by CloakableMixin: moving normally strips most of the cloak (alien
-- camouflage rule). An active cloaking field is far less sensitive to speed.
function VTInfiltrator:GetSpeedScalar()
    local scalar = Marine.GetSpeedScalar(self)
    if self:VT_GetAbilityActive() then
        scalar = scalar * kVTCloakMovementPenalty
    end
    return scalar
end

-- Cloak field = 100% cloak (Hooks/CloakableMixin.lua); any reveal ends the field.
-- A parasited Infiltrator can't cloak at all (the aliens tagged him).
function VTInfiltrator:VT_GetIsParasited()
    return self.GetIsParasited ~= nil and self:GetIsParasited()
end

function VTInfiltrator:GetCanCloakOverride()
    return not self:VT_GetIsParasited()
end

function VTInfiltrator:VT_GetForceFullCloak()
    return self:GetIsAlive() and self:VT_GetAbilityActive() and not self:VT_GetIsParasited()
end

if Server then
    function VTInfiltrator:VT_OnUncloakTriggered()
        if self:VT_GetAbilityActive() then
            self.vtAbilityActiveEnd = Shared.GetTime()
        end
    end
end

-- Echo Scan reveals stealth: every 0.2 s while scanning, everything in the cone is detected like a vanilla
-- Observatory scan (DetectableMixin -> CloakableMixin uncloaks it; detection lapses 1.5 s after the last refresh).
local kEchoDetectInterval = 0.2
if Server then
    function VTInfiltrator:VT_UpdateEchoDetection()
        local now = Shared.GetTime()
        if now < (self.vtNextEchoDetect or 0) then return end
        self.vtNextEchoDetect = now + kEchoDetectInterval
        VT_ForEachInEchoCone(self, function(entity)
            if HasMixin(entity, "Detectable") then
                entity:SetDetected(true)
            end
            if HasMixin(entity, "LOS") then
                entity:SetIsSighted(true, self)
            end
            if HasMixin(entity, "Cloakable") and entity.TriggerUncloak then
                entity:TriggerUncloak()
            end
        end)
    end
end

function VTInfiltrator:OnProcessMove(input)
    -- Parasite reveals: an active field collapses at once.
    if Server and self:VT_GetAbilityActive() and self:VT_GetIsParasited() then
        self.vtAbilityActiveEnd = Shared.GetTime()
        if self.TriggerUncloak then self:TriggerUncloak() end
    end
    -- Keep the cloak trigger alive while the field is active.
    if self:VT_GetAbilityActive() and self.TriggerCloak then
        self:TriggerCloak()
    end

    -- Echo Scan: on exactly while the scanner is out and fire is held.
    local weapon = self:GetActiveWeapon()
    local scanning = self:GetIsAlive() and weapon ~= nil and weapon:isa("VTEchoPulse")
            and bit.band(input.commands, Move.PrimaryAttack) ~= 0
    if scanning and not self.vtEchoScanning and Server and weapon.OnEchoScanStart then
        weapon:OnEchoScanStart(self)
    end
    self.vtEchoScanning = scanning
    if scanning and Server then
        self:VT_UpdateEchoDetection()
    end

    Marine.OnProcessMove(self, input)
end

function VTInfiltrator:PrimaryAttack()
    if self:VT_GetAbilityActive() then
        if Server then
            self.vtAbilityActiveEnd = Shared.GetTime()
        end
        if self.TriggerUncloak then
            self:TriggerUncloak()
        end
    end
    Marine.PrimaryAttack(self)
end

if Server then

    function VTInfiltrator:InitWeapons()

        Player.InitWeapons(self)

        -- No pistol: slot 1 Psionic Blades, slot 2 Echo Scanner.
        self:GiveItem(VTPsionicBlade.kMapName)
        self:GiveItem(VTEchoPulse.kMapName)

        self:SetQuickSwitchTarget(VTEchoPulse.kMapName)
        self:SetActiveWeapon(VTPsionicBlade.kMapName)

    end

    function VTInfiltrator:VT_UseAbility()
        if self:VT_GetIsParasited() then
            VT_SendMessageToPlayer(self, "Cloak field blocked: you are parasited.")
            return
        end
        local duration = VT_GetTeamHasTech("VTPhaseCloakTech") and kVTPhaseCloakDuration or kVTCloakDuration
        self.vtAbilityActiveEnd = Shared.GetTime() + duration
        self:VT_StartCooldown(kVTCloakCooldown)
    end

    function VTInfiltrator:VT_TriggerHack()

        local now = Shared.GetTime()
        if now < self.vtHackReadyTime or not self:GetIsAlive() then
            return false
        end
        self.vtHackReadyTime = now + kVTHackCooldown

        local origin = self:GetOrigin()
        local enemyTeam = GetEnemyTeamNumber(self:GetTeamNumber())
        local hacked = 0

        local override = VT_GetTeamHasTech("VTNeuralOverrideTech")
        local radius = override and kVTNeuralOverrideRadius or kVTHackRadius
        local duration = override and kVTNeuralOverrideDuration or kVTHackDuration

        for _, target in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, origin, radius)) do
            if not target:isa("Player") and target:GetIsAlive() then
                VT_MarkHacked(target, now + duration)
                hacked = hacked + 1
            end
        end

        local params = {}
        params[kEffectHostCoords] = Coords.GetTranslation(origin)
        self:TriggerEffects("pulse_grenade_explode", params)

        -- Hacking reveals the infiltrator.
        self.vtAbilityActiveEnd = now
        if self.TriggerUncloak then
            self:TriggerUncloak()
        end

        return hacked > 0

    end

end

InstallShared(VTInfiltrator)
InstallNoSprint(VTInfiltrator)
InstallNoFlashlight(VTInfiltrator)
VT_InstallShield(VTInfiltrator, true)
Shared.LinkClassToMap("VTInfiltrator", VTInfiltrator.kMapName, infiltratorNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Subject (Bio-Construct): oversized war-beast, claws only.
-- ----------------------------------------------------------------------------
class 'VTSubject' (Marine)

VTSubject.kMapName = kVTMapNames.Subject

local subjectNetworkVars = AddVTNetworkVars({})
-- Predicted movement state for dodge / double jump.
subjectNetworkVars.vtAirJumpsUsed   = "private compensated integer (0 to 3)"
subjectNetworkVars.vtDodgeReadyTime = "private compensated time"
-- Claw climb (predicted like the dodge)
subjectNetworkVars.vtClimbing     = "compensated boolean"
subjectNetworkVars.vtClimbStamina = "private compensated float (0 to 10 by 0.01)"
-- Sprint burst (Shift on the ground), predicted like the dodge
subjectNetworkVars.vtSprintReadyTime = "private compensated time"
subjectNetworkVars.vtSprintEndTime   = "private compensated time"

function VTSubject:OnCreate()
    Marine.OnCreate(self)
    InitVTFields(self)
    self.vtAirJumpsUsed = 0
    self.vtDodgeReadyTime = 0
    self.vtClimbing = false
    self.vtClimbStamina = kVTClimbStamina
    self.vtSprintReadyTime = 0
    self.vtSprintEndTime = 0
end

-- ---- Sprint burst / wall hold (Shift) ------------------------------------------------------------------
-- Shift is read in InstallNoSprint's OnProcessMove wrapper (vtShiftHeld) before the vanilla sprint is
-- stripped from the move. On the ground a fresh press starts a sprint of kVTSubjectSprintDuration seconds
-- without ground friction. Full control: every move the horizontal velocity is
-- kVTSubjectSprintSpeed along the held movement keys relative to the current view (view forward if none), on
-- the ground and in the air, so the player steers with keys and mouse and can jump (vertical velocity is
-- untouched). Grabbing a wall ends it; back on the ground after the burst the speed drops to run speed.
-- Held while climbing, Shift hangs on the wall: no movement, no sliding, and the climb stamina is kept full.
function VTSubject:VT_GetIsSprintBursting()
    return Shared.GetTime() < (self.vtSprintEndTime or 0)
end

function VTSubject:VT_GetIsWallHolding()
    return self.vtClimbing == true and self.vtShiftHeld == true
end

function VTSubject:VT_GetSprintCooldownRemaining()
    return math.max(0, (self.vtSprintReadyTime or 0) - Shared.GetTime())
end

function VTSubject:VT_StartSprint()
    local now = Shared.GetTime()
    self.vtSprintEndTime = now + kVTSubjectSprintDuration
    self.vtSprintReadyTime = now + kVTSubjectSprintCooldown
end

-- Horizontal sprint direction for this move: held movement keys relative to the view, view forward if none.
local function GetSprintSteerDirection(self, input)
    local x, z = input.move.x, input.move.z
    if x == 0 and z == 0 then
        z = 1
    end
    local direction = Angles(0, self:GetViewAngles().yaw, 0):GetCoords():TransformVector(Vector(x, 0, z))
    direction.y = 0
    direction:Normalize()
    return direction
end

-- No ground friction during the burst (it would eat most of the 7 m) or while hanging on a wall.
function VTSubject:GetFriction(input, velocity)
    if self:VT_GetIsSprintBursting() or self:VT_GetIsWallHolding() then
        return Vector(0, 0, 0)
    end
    return GroundMoveMixin.GetFriction(self, input, velocity)
end

-- ---- Double jump --------------------------------------------------------
function VTSubject:GetCanJump()
    if self:GetIsOnGround() or self:GetIsOnLadder() or self.vtClimbing then
        return true
    end
    -- JumpMoveMixin only calls this on a fresh press of the jump key.
    return self.vtAirJumpsUsed < kVTSubjectAirJumps
end

function VTSubject:ModifyJump(input, velocity, jumpVelocity)
    if self.vtClimbing then
        -- Push off the surface (walls: away from it; ceilings: drop down), keep the air jump.
        local n = self.vtClimbNormal or Vector(0, 0, 0)
        velocity.x = velocity.x + n.x * kVTClimbKickSpeed
        velocity.z = velocity.z + n.z * kVTClimbKickSpeed
        if n.y < -0.5 then jumpVelocity.y = 0 end
        self.vtClimbing = false
        return
    end
    if not self:GetIsOnGround() and not self:GetIsOnLadder() then
        -- Air jump: DoJump replaces vertical velocity, keeping momentum.
        self.vtAirJumpsUsed = self.vtAirJumpsUsed + 1
    end
end

-- Land at full speed: no marine landing slowdown.
function VTSubject:GetSlowOnLand()
    return false
end

-- ---- Dodge: double-tap a direction key ------------------------------------
-- Returns the local direction of a movement key pressed this move, if any.
local function GetNewTapDirection(previousMove, move)
    if move.z > 0 and previousMove.z <= 0 then return 0, 1 end
    if move.z < 0 and previousMove.z >= 0 then return 0, -1 end
    if move.x > 0 and previousMove.x <= 0 then return 1, 0 end
    if move.x < 0 and previousMove.x >= 0 then return -1, 0 end
    return nil
end

function VTSubject:VT_PerformDodge(velocity, localX, localZ)

    -- Horizontal direction relative to where the Subject is looking.
    local yawCoords = Angles(0, self:GetViewAngles().yaw, 0):GetCoords()
    local direction = yawCoords:TransformVector(Vector(localX, 0, localZ))
    direction.y = 0
    direction:Normalize()

    velocity.x = direction.x * kVTDodgeSpeed
    velocity.z = direction.z * kVTDodgeSpeed
    velocity.y = math.max(velocity.y, kVTDodgeUpSpeed)

    -- Same airborne bookkeeping as a regular jump (animation + effects).
    self.onGround = false
    self.jumping = true
    self.timeGroundTouched = Shared.GetTime()

    self.vtDodgeReadyTime = Shared.GetTime() + kVTDodgeCooldown

end

-- ---- Claw climb: Skulk-style wall walking ---------------------------------------
-- Same switches as Skulk.lua: while vtClimbing the Subject counts as grounded (ground acceleration at run
-- speed), has no gravity and moves in full 3D along its view (look up the wall and walk). It attaches when it
-- collides with a wall or ceiling (normal.y < 0.5), re-checks the surface every move and drops off when there
-- is none, when crouching, or when the climb stamina (kVTClimbStamina) runs out. Jump pushes off the surface.
-- Own short probes instead of WallMovementMixin: its feelers scale with max(extents), ~1.25 m for this capsule.
local kClimbProbeDirs = {}
for i = 0, 7 do
    local a = i / 8 * math.pi * 2
    kClimbProbeDirs[#kClimbProbeDirs + 1] = Vector(math.cos(a), 0, math.sin(a))
end
kClimbProbeDirs[#kClimbProbeDirs + 1] = Vector(0, 1, 0)           -- ceiling

function VTSubject:VT_FindClimbSurface()
    local _, radius = self:GetTraceCapsule()
    local origin = self:GetOrigin()
    for _, h in ipairs({ 1.0, 0.35, 1.6 }) do
        local start = origin + Vector(0, h, 0)
        for i, dir in ipairs(kClimbProbeDirs) do
            local reach = (i == #kClimbProbeDirs) and (0.5 + kVTClimbReach) or (radius + kVTClimbReach)
            local trace = Shared.TraceRay(start, start + dir * reach, CollisionRep.Move, PhysicsMask.Movement, EntityFilterOne(self))
            if trace.fraction < 1 and trace.normal.y < 0.5 then
                return trace.normal
            end
        end
    end
    return nil
end

local function GetCanStartClimb(self)
    return self:GetIsAlive() and not self:GetCrouching() and self.vtClimbStamina >= kVTClimbMinStamina
            and Shared.GetTime() - (self.timeOfLastJump or 0) > 0.25
end

function VTSubject:OnWorldCollision(normal, impactForce, newVelocity)
    if not self.vtClimbing and normal and normal.y < 0.5 and GetCanStartClimb(self) then
        self.vtClimbing = true
        self.vtClimbNormal = Vector(normal)
    end
end

function VTSubject:PreUpdateMove(input, runningPrediction)
    if self.vtClimbing then
        local normal = self:VT_FindClimbSurface()
        if normal and not self:GetCrouching() and self.vtClimbStamina > 0 and self:GetIsAlive() then
            self.vtClimbNormal = normal
            if self.vtShiftHeld then
                self.vtClimbStamina = kVTClimbStamina      -- wall hold: no drain, climb is reset to full
            else
                self.vtClimbStamina = math.max(0, self.vtClimbStamina - input.time)
            end
        else
            self.vtClimbing = false
        end
    elseif self:GetIsOnGround() then
        self.vtClimbStamina = math.min(kVTClimbStamina, self.vtClimbStamina + kVTClimbStaminaRegen * input.time)
    end
end

function VTSubject:OverrideUpdateOnGround(onGround)
    return onGround or self.vtClimbing
end

function VTSubject:ModifyGravityForce(gravityTable)
    if self.vtClimbing then
        gravityTable.gravity = 0
    end
end

function VTSubject:GetPerformsVerticalMove()
    return self.vtClimbing == true
end

function VTSubject:GetMoveSpeedIs2D()
    return not self.vtClimbing
end

function VTSubject:GetCanStep()
    return not self.vtClimbing
end

function VTSubject:ModifyVelocity(input, velocity, deltaTime)

    local now = Shared.GetTime()

    local shiftPressed = self.vtShiftHeld and not self.vtShiftWasHeld
    self.vtShiftWasHeld = self.vtShiftHeld

    if self.vtClimbing then              -- wall walking: no dodge / air-jump bookkeeping
        self.vtPreviousMove = Vector(input.move)
        self.vtSprintEndTime = 0
        if self.vtShiftHeld then         -- wall hold: stay exactly where we are
            velocity.x, velocity.y, velocity.z = 0, 0, 0
            input.move.x, input.move.y, input.move.z = 0, 0, 0
        end
        return
    end

    -- Sprint burst (steerable, on the ground and in the air)
    if shiftPressed and self:GetIsOnGround() and now >= (self.vtSprintReadyTime or 0) and self:GetIsAlive() then
        self:VT_StartSprint()
    end
    if self:VT_GetIsSprintBursting() then
        local direction = GetSprintSteerDirection(self, input)
        velocity.x = direction.x * kVTSubjectSprintSpeed
        velocity.z = direction.z * kVTSubjectSprintSpeed
        self.vtSprintNeedsSlowdown = true
    elseif self.vtSprintNeedsSlowdown and self:GetIsOnGround() then
        -- burst over and on the ground: back to run speed at once instead of gliding on
        -- (a burst that ends mid-jump keeps its momentum until the landing)
        local maxSpeed = self:GetMaxSpeed()
        local speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
        if speed > maxSpeed then
            velocity.x = velocity.x * maxSpeed / speed
            velocity.z = velocity.z * maxSpeed / speed
        end
        self.vtSprintNeedsSlowdown = false
    end

    if self:GetIsOnGround() then
        self.vtAirJumpsUsed = 0
    end

    local previousMove = self.vtPreviousMove or Vector(0, 0, 0)
    local tapX, tapZ = GetNewTapDirection(previousMove, input.move)
    self.vtPreviousMove = Vector(input.move)

    if tapX then

        local isDoubleTap = self.vtLastTapX == tapX and self.vtLastTapZ == tapZ
                and now - (self.vtLastTapTime or 0) <= kVTDodgeTapWindow

        if isDoubleTap and self:GetIsOnGround() and now >= self.vtDodgeReadyTime and not self:VT_GetIsSprintBursting() then
            self:VT_PerformDodge(velocity, tapX, tapZ)
            self.vtLastTapTime = 0
        else
            self.vtLastTapX, self.vtLastTapZ, self.vtLastTapTime = tapX, tapZ, now
        end

    end

end

-- Player model: Fab "Mecha Sentinel" rigged to the marine skeleton (art/fab/mecha_sentinel/build_mecha.sh),
-- orange visor recoloured to Vael'Thor purple; drawn at kVTSubjectModelScale (OnAdjustModelCoords).
kVTSubjectPlayerModel = PrecacheAsset("models/vaelthor/mecha/mecha_player.model")

function VTSubject:GetVariantModel()
    return kVTSubjectPlayerModel
end

function VTSubject:GetArmorAmount(armorLevels)
    return kVTSubjectArmor
end

function VTSubject:GetMaxSpeed(possible)
    return Marine.GetMaxSpeed(self, possible) * kVTSubjectSpeedScalar
end

function VTSubject:OnAdjustModelCoords(modelCoords)
    modelCoords.xAxis = modelCoords.xAxis * kVTSubjectModelScale
    modelCoords.yAxis = modelCoords.yAxis * kVTSubjectModelScale
    modelCoords.zAxis = modelCoords.zAxis * kVTSubjectModelScale
    return modelCoords
end

-- Bio-constructs cannot use or pick up imperial weaponry.
function VTSubject:GetCanDropWeapon()
    return false
end

if Server then

    function VTSubject:InitWeapons()
        Player.InitWeapons(self)
        self:GiveItem(VTSubjectClaws.kMapName)
        self:SetActiveWeapon(VTSubjectClaws.kMapName)
    end

end

InstallShared(VTSubject)
InstallNoSprint(VTSubject)
InstallNoFlashlight(VTSubject)
VT_InstallShield(VTSubject, true)
Shared.LinkClassToMap("VTSubject", VTSubject.kMapName, subjectNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Praetor: heavy elite on the dual-minigun exo chassis. Teleport Dash (B).
-- Cannot leave its armour (no eject).
-- ----------------------------------------------------------------------------
class 'VTPraetor' (Exo)

VTPraetor.kMapName = kVTMapNames.Praetor

local praetorNetworkVars = AddVTNetworkVars({
    vtEnergy = string.format("float (0 to %d by 0.0625)", kVTPraetorEnergy),
})
-- Normal Marine-style jump instead of the exo's thruster hover (Exo has no JumpMoveMixin).
AddMixinNetworkVars(JumpMoveMixin, praetorNetworkVars)

function VTPraetor:OnCreate()
    Exo.OnCreate(self)
    -- Exos can't launch predicted projectiles; the plasma miniguns need it (Marine.lua does the same).
    InitMixin(self, PredictedProjectileShooterMixin)
    InitMixin(self, JumpMoveMixin)
    InitVTFields(self)
    self.layout = "MinigunMinigun"
    self.vtEnergy = kVTPraetorEnergy
    self.vtLastBoltTime = 0
end

-- Player model: Fab "Titan Sentinel" rigged to the Exosuit dual-minigun skeleton, keeping the exo's own
-- minigun geometry (art/fab/titan_sentinel/build_titan.sh); borrows exosuit_mm's animations and attach points.
kVTPraetorPlayerModel = PrecacheAsset("models/vaelthor/titan/titan_player.model")

-- Exo:InitExoModel picks the vanilla model by layout; the Praetor is always dual minigun.
function VTPraetor:InitExoModel()
    self.hasDualGuns = true
    self:SetModel(kVTPraetorPlayerModel, Exo.kDualAnimationGraph)
    self.lastExoLayout = self.layout
end

function VTPraetor:HandleButtons(input)
    -- no Drop; no Shift (MovementModifier = the exo's horizontal/strafe/back thruster boosts)
    input.commands = bit.band(input.commands, bit.bnot(bit.bor(Move.Drop, Move.MovementModifier)))
    -- Exo skins override the world model's material slots with exosuit textures, which would paint
    -- them onto the Titan. Keep the default variant (also leaves the first-person arms vanilla).
    if Server and self.exoVariant ~= kDefaultExoVariant then
        self.exoVariant = kDefaultExoVariant
    end
    Exo.HandleButtons(self, input)
end

-- Energy pool for the plasma miniguns (server only; spent per bolt in VTPlasmaMinigun's FireBolt).
-- Inside a field: fast recharge like the carbine. Outside: slow regeneration, only out of combat.
function VTPraetor:VT_UpdateEnergy(deltaTime)
    if not Server or self.vtEnergy >= kVTPraetorEnergy then
        return
    end
    local sinceBolt = Shared.GetTime() - (self.vtLastBoltTime or 0)
    local rate = 0
    if VT_GetIsPointInField(self:GetOrigin()) then
        if sinceBolt >= kVTPraetorRechargeDelay then
            rate = kVTPraetorRechargeRate
        end
    elseif sinceBolt >= kVTPraetorSlowRechargeDelay and not self:GetIsInCombat() then
        rate = kVTPraetorSlowRechargeRate
    end
    if rate > 0 then
        self.vtEnergy = math.min(kVTPraetorEnergy, self.vtEnergy + deltaTime * rate)
    end
end

function VTPraetor:OnProcessMove(input)
    Exo.OnProcessMove(self, input)
    self:VT_UpdateEnergy(input.time)
end

-- No exo thrusters at all (Space hover, Shift boosts): Space is a plain jump via JumpMoveMixin.
function VTPraetor:GetIsThrusterAllowed()
    return false
end

function VTPraetor:GetCanJump()
    return self:GetIsOnGround()
end

-- No ejecting: the Praetor is a caste, not a pilot in a suit.
function VTPraetor:EjectExo()
end

function VTPraetor:GetCanEject()
    return false
end

if Server then

    -- Plasma miniguns instead of the vanilla miniguns (Classes/VTWeapons.lua).
    function VTPraetor:InitWeapons()
        Player.InitWeapons(self)
        local weaponHolder = self:GetWeapon(ExoWeaponHolder.kMapName) or self:GiveItem(ExoWeaponHolder.kMapName, false)
        weaponHolder:SetWeapons(VTPlasmaMinigun.kMapName, VTPlasmaMinigun.kMapName)
        -- The holder looks up its view model + animation graph by "<leftMapName>+<rightMapName>"; ours isn't in
        -- its tables (no view model, no animation graph -> no shoot tags -> no guns). Use the vanilla setup.
        weaponHolder.weaponSetupName = "minigun+minigun"
        if weaponHolder:GetIsActive() then
            self:SetViewModel(weaponHolder:GetViewModelName(), weaponHolder)
        end
        weaponHolder:TriggerEffects("exo_login")
        self.inventoryWeight = weaponHolder:GetInventoryWeight(self)
        self:SetActiveWeapon(ExoWeaponHolder.kMapName)
    end

    function VTPraetor:VT_UseAbility()
        if self.vtEnergy < kVTPraetorDashEnergyCost then
            VT_SendMessageToPlayer(self, string.format("Teleport Dash needs %d energy.", kVTPraetorDashEnergyCost))
            return
        end
        if VT_PerformBlink(self, kVTPraetorDashDistance) then
            -- paid from the gun energy; counts as a shot for the recharge delay
            self.vtEnergy = self.vtEnergy - kVTPraetorDashEnergyCost
            self.vtLastBoltTime = Shared.GetTime()
            self:VT_StartCooldown(kVTPraetorDashCooldown)
        end
    end

end

InstallShared(VTPraetor)

function VTPraetor:GetMapBlipType()
    return kMinimapBlipType.Exo
end

InstallNoFlashlight(VTPraetor)

-- Exo chassis armor without the vanilla armor levels (Shield Matrix raises the shield instead).
function VTPraetor:GetArmorAmount(armorLevels)
    return Exo.GetArmorAmount(self, 0)
end

VT_InstallShield(VTPraetor, true)
Shared.LinkClassToMap("VTPraetor", VTPraetor.kMapName, praetorNetworkVars, true)
