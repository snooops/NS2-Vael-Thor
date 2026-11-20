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

-- Vael'Thor soldiers never pick up weapons (marine weapons on the ground, auto pickup or E). These merge with
-- MarineActionFinderMixin's finders; NS2 runs the class method first and keeps ITS return value, so nil wins
-- (also hides the client's pickup prompt).
function Shared_:GetNearbyPickupableWeapon()
    return nil
end

function Shared_:FindNearbyAutoPickupWeapon()
    return nil
end

function Shared_:ShouldAutopickupWeapons()
    return false
end

function Shared_:ShouldAutopickupBetterWeapons()
    return false
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

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTVanguard, { "Marine" })

VTVanguard.kMapName = kVTMapNames.Vanguard

local vanguardNetworkVars = AddVTNetworkVars({})

function VTVanguard:OnCreate()
    VTBase.Marine.OnCreate(self)
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
    VTBase.Marine.OnProcessMove(self, input)
    local carbine = self:GetWeapon(VTPlasmaCarbine.kMapName)
    if carbine and carbine.VT_UpdateEnergy then
        carbine:VT_UpdateEnergy(self, input.time)
    end
    if Server then
        VT_UpdateVoice(self)   -- "taking fire" / "carbine drained" lines (Classes/VTVoice.lua)
    end
end

-- Order complete: the soldier's own "Objective secured" instead of the marine voice. Client-only and heard only by
-- this player, like vanilla (OrderSelfMixin calls it on the owning client); automatic orders stay silent here.
if Client then
    function VTVanguard:OnOrderSelfComplete(orderType)
        if not PlayerUI_GetTypeAutoOrderOrPheromone(orderType) then
            VT_PlayVoice(self, "done")
        end
    end
end

function VTVanguard:GetMaxSpeed(possible)
    local speed = VTBase.Marine.GetMaxSpeed(self, possible)
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
                VT_PlayVoice(self, "dash")
            end

        elseif self.vtModule == kVTModule.ShieldOverdrive then

            VT_SetShield(self, self:VT_GetMaxShield())
            self.vtAbilityActiveEnd = now + kVTOverdriveDuration
            self.vtShieldBurnoutEnd = now + kVTOverdriveDuration + kVTOverdriveBurnout
            self:VT_StartCooldown(kVTOverdriveCooldown)
            self:TriggerEffects("catpack_pickup")
            VT_PlayVoice(self, "overdrive", { force = true })

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

-- The Vanguard's module ability (Shield Boost / Phase Dash / Shield Overdrive) is on right-click instead of B
-- (TertiaryAttack): none of the Vanguard's weapons has a secondary attack (carbine, knife and Singularity
-- Launcher all report GetHasSecondary false), so the button is free. Defined after InstallShared, which would
-- otherwise overwrite these with the shared B handlers.
function VTVanguard:SecondaryAttack()
    if not self.secondaryAttackLastFrame and Server and self:GetIsAlive()
            and self:VT_GetAbilityReady() and self.VT_UseAbility then
        self:VT_UseAbility()
    end
    VTBase.Marine.SecondaryAttack(self) -- still reaches a weapon secondary, should one ever be added
end

function VTVanguard:TertiaryAttack()
end

InstallNoSprint(VTVanguard)
InstallNoFlashlight(VTVanguard)
VT_InstallShield(VTVanguard, true)
Shared.LinkClassToMap("VTVanguard", VTVanguard.kMapName, vanguardNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Infiltrator: cloaking field (B), Psionic Blade, hack pulse (blade right-click)
-- ----------------------------------------------------------------------------
class 'VTInfiltrator' (Marine)

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTInfiltrator, { "Marine" })

VTInfiltrator.kMapName = kVTMapNames.Infiltrator

local infiltratorNetworkVars = AddVTNetworkVars({
    vtEchoScanning = "boolean",   -- Echo Scan held: every VT client draws this cone's contacts
    vtHackReadyTime = "time",     -- networked for the HUD's hack cooldown line
    vtCloakEnergy = string.format("float (0 to %d by 0.0625)", kVTCloakEnergy),   -- cloak field energy (HUD)
})
AddMixinNetworkVars(CloakableMixin, infiltratorNetworkVars)

function VTInfiltrator:OnCreate()
    VTBase.Marine.OnCreate(self)
    InitMixin(self, CloakableMixin)
    InitVTFields(self)
    self.vtHackReadyTime = 0
    self.vtEchoScanning = false
    self.vtCloakEnergy = kVTCloakEnergy
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
    return VTBase.Marine.GetMaxSpeed(self, possible) * kVTInfiltratorSpeedScalar
end

-- Used by CloakableMixin: moving normally strips most of the cloak (alien
-- camouflage rule). An active cloaking field is far less sensitive to speed.
function VTInfiltrator:GetSpeedScalar()
    local scalar = VTBase.Marine.GetSpeedScalar(self)
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

-- Cloak energy (server): the active field drains it and collapses at 0; inside a Subvention field the energy
-- recharges while not cloaked. Nothing else restores it.
local kCloakFieldOpen = 3600      -- the field has no duration of its own: "until toggled off / drained"
if Server then
    function VTInfiltrator:VT_UpdateCloakEnergy(deltaTime)
        if self:VT_GetAbilityActive() then
            local drain = VT_GetTeamHasTech("VTPhaseCloakTech") and kVTPhaseCloakDrainPerSecond or kVTCloakDrainPerSecond
            self.vtCloakEnergy = math.max(0, self.vtCloakEnergy - drain * deltaTime)
            if self.vtCloakEnergy <= 0 then
                self.vtAbilityActiveEnd = Shared.GetTime()
                if self.TriggerUncloak then self:TriggerUncloak() end
            end
        elseif self.vtCloakEnergy < kVTCloakEnergy and self:GetIsAlive() and VT_GetIsPointInField(self:GetOrigin()) then
            self.vtCloakEnergy = math.min(kVTCloakEnergy, self.vtCloakEnergy + kVTCloakRechargeRate * deltaTime)
        end
    end
end

function VTInfiltrator:OnProcessMove(input)
    if Server then
        -- Shift toggles the cloak field (press edge). InstallNoSprint records vtShiftHeld before stripping it.
        local shift = self.vtShiftHeld == true
        if shift and not self.vtCloakKeyWasDown and self:GetIsAlive() then
            self:VT_UseAbility()
        end
        self.vtCloakKeyWasDown = shift
        self:VT_UpdateCloakEnergy(input.time)
    end
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

    VTBase.Marine.OnProcessMove(self, input)
end

function VTInfiltrator:PrimaryAttack()
    if self:VT_GetAbilityActive() then
        -- ambush: the first hit within kVTAmbushWindow deals double damage (shared, so predicted numbers match)
        self.vtAmbushUntil = Shared.GetTime() + kVTAmbushWindow
        if Server then
            self.vtAbilityActiveEnd = Shared.GetTime()
        end
        if self.TriggerUncloak then
            self:TriggerUncloak()
        end
    end
    VTBase.Marine.PrimaryAttack(self)
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

    -- Shift toggles the cloak field (no cooldown); it runs on cloak energy (VT_UpdateCloakEnergy).
    function VTInfiltrator:VT_UseAbility()
        if self:VT_GetAbilityActive() then
            self.vtAbilityActiveEnd = Shared.GetTime()
            if self.TriggerUncloak then self:TriggerUncloak() end
            return
        end
        if self:VT_GetIsParasited() then
            VT_SendMessageToPlayer(self, "Cloak field blocked: you are parasited.")
            return
        end
        if self.vtCloakEnergy < kVTCloakMinEnergy then
            VT_SendMessageToPlayer(self, "Cloak field needs energy: recharge it near a pylon or Nexus.")
            return
        end
        self.vtAbilityActiveEnd = Shared.GetTime() + kCloakFieldOpen
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

-- The cloak field is on Shift (VTInfiltrator:OnProcessMove), not on B. Defined after InstallShared, which would
-- otherwise install the shared B handler.
function VTInfiltrator:TertiaryAttack()
end
InstallNoSprint(VTInfiltrator)
InstallNoFlashlight(VTInfiltrator)
VT_InstallShield(VTInfiltrator, true)
Shared.LinkClassToMap("VTInfiltrator", VTInfiltrator.kMapName, infiltratorNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Subject (Bio-Construct): oversized war-beast, claws only.
-- ----------------------------------------------------------------------------
class 'VTSubject' (Marine)

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTSubject, { "Marine" })

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
    VTBase.Marine.OnCreate(self)
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

-- Player model: the "Stalker", an original Blender model (chitin predator, forearm blades, toe claws for the wall
-- climb) on the marine skeleton (art/subject/build_stalker.sh); face set 1 = blades + talons (wrist weapon toggle in
-- Client.lua). Drawn at kVTSubjectModelScale (OnAdjustModelCoords). The old Mecha Sentinel is still built (vt_model mecha).
kVTSubjectPlayerModel = PrecacheAsset("models/vaelthor/stalker/stalker_player.model")

function VTSubject:GetVariantModel()
    return kVTSubjectPlayerModel
end

function VTSubject:GetArmorAmount(armorLevels)
    return kVTSubjectArmor
end

function VTSubject:GetMaxSpeed(possible)
    return VTBase.Marine.GetMaxSpeed(self, possible) * kVTSubjectSpeedScalar
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

-- isolation: vanilla behaviour for everything not overridden below (Baseline/Freeze.lua)
VT_FreezeClass(VTPraetor, { "Exo" })

VTPraetor.kMapName = kVTMapNames.Praetor

local praetorNetworkVars = AddVTNetworkVars({
    -- also the Artificer's (subclass) bigger core: the range covers both pools
    vtEnergy = string.format("float (0 to %d by 0.0625)", math.max(kVTPraetorEnergy, kVTArtificerEnergy)),
    -- homing missile lock (right click), for the own crosshair only
    vtMissileLockId = "private entityid",
    vtMissileLockFraction = "private float (0 to 1 by 0.05)",
    vtNextMissileTime = "time",              -- missile cooldown end: own crosshair / HUD; all clients kick the pod
})
-- Normal Marine-style jump instead of the exo's thruster hover (Exo has no JumpMoveMixin).
AddMixinNetworkVars(JumpMoveMixin, praetorNetworkVars)

function VTPraetor:OnCreate()
    VTBase.Exo.OnCreate(self)
    -- Exos can't launch predicted projectiles; the plasma miniguns need it (Marine.lua does the same).
    InitMixin(self, PredictedProjectileShooterMixin)
    InitMixin(self, JumpMoveMixin)
    InitVTFields(self)
    self.layout = "MinigunMinigun"
    self.vtEnergy = self:VT_GetMaxEnergy()
    self.vtLastBoltTime = 0
    self.vtMissileLockId = Entity.invalidId
    self.vtMissileLockFraction = 0
    self.vtMissileHeld = false
    self.vtMissileFiredThisHold = false
    self.vtNextMissileTime = 0
end

-- Player model: Fab "Titan Sentinel" rigged to the Exosuit dual-minigun skeleton, keeping the exo's own
-- minigun geometry (art/fab/titan_sentinel/build_titan.sh); borrows exosuit_mm's animations and attach points.
kVTPraetorPlayerModel = PrecacheAsset("models/vaelthor/titan/titan_player.model")

-- Vanilla dual-minigun graphs + first-person view model. Since the 2026-11-17 game update (modular exo) these come
-- from kExoWeaponRightLeftComboModels (Weapons/ModularExo_Data.lua); Exo.kDualAnimationGraph is gone.
local function GetDualMinigunModelData()
    local data = kExoWeaponRightLeftComboModels and kExoArmTypes and kExoWeaponRightLeftComboModels[kExoArmTypes.Minigun]
    data = data and data[kExoArmTypes.Minigun] or {}
    return
    {
        worldAnimGraph = data.worldAnimGraph or "models/marine/exosuit/exosuit_mm.animation_graph",
        viewModel      = data.viewModel      or "models/marine/exosuit/exosuit_mm_view.model",
        viewAnimGraph  = data.viewAnimGraph  or "models/marine/exosuit/exosuit_mm_view.animation_graph",
    }
end
local kVTPraetorModelData = GetDualMinigunModelData()
PrecacheAsset(kVTPraetorModelData.worldAnimGraph)
PrecacheAsset(kVTPraetorModelData.viewModel)
PrecacheAsset(kVTPraetorModelData.viewAnimGraph)

-- Exo:InitExoModel picks the vanilla model by arm modules; the Praetor is always dual minigun.
-- ExoWeaponHolder:GetViewModelName/GetAnimationGraphName read the player's viewModelName/viewModelGraphName
-- (2026-11-17 update): without them the holder has no view model -> no shoot tags -> the guns never fire.
function VTPraetor:InitExoModel()
    self.hasDualGuns = true
    self:SetModel(kVTPraetorPlayerModel, kVTPraetorModelData.worldAnimGraph)
    self.viewModelName = kVTPraetorModelData.viewModel
    self.viewModelGraphName = kVTPraetorModelData.viewAnimGraph
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
    VTBase.Exo.HandleButtons(self, input)
end

-- Energy pool for the plasma miniguns, homing missiles and Teleport Dash (server only; spent per bolt in
-- VTPlasmaMinigun's FireBolt). Recharges everywhere at kVTPraetorRechargeRate, kVTPraetorRechargeDelay after the
-- last shot (vtLastBoltTime: bolts, missiles and Teleport Dash).
-- Pool size / recharge are methods so the Artificer (subclass) can bring its bigger, slower core.
function VTPraetor:VT_GetMaxEnergy()
    return kVTPraetorEnergy
end

function VTPraetor:VT_GetEnergyRecharge()
    return kVTPraetorRechargeRate, kVTPraetorRechargeDelay
end

function VTPraetor:VT_UpdateEnergy(deltaTime)
    local maxEnergy = self:VT_GetMaxEnergy()
    if not Server or self.vtEnergy >= maxEnergy then
        return
    end
    local rate, delay = self:VT_GetEnergyRecharge()
    if Shared.GetTime() - (self.vtLastBoltTime or 0) < delay then
        return
    end
    self.vtEnergy = math.min(maxEnergy, self.vtEnergy + deltaTime * rate)
end

function VTPraetor:OnProcessMove(input)
    VTBase.Exo.OnProcessMove(self, input)
    self:VT_UpdateEnergy(input.time)
    if Server then
        self:VT_UpdateMissile(input.time)
    end
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
        if not self.viewModelName then
            self:InitExoModel()
        end
        weaponHolder:SetWeapons(VTPlasmaMinigun.kMapName, VTPlasmaMinigun.kMapName)
        -- Networked as "string (15)" ("vt_plasmaminigun" has 16) and compared with "minigun" by the dual-fire
        -- lock (CheckDualFiring): report the vanilla name. The arm entities stay VTPlasmaMinigun.
        weaponHolder.weaponMapNameLeft = "minigun"
        weaponHolder.weaponMapNameRight = "minigun"
        weaponHolder.weaponSetupName = "minigun+minigun"   -- pre-2026-11-17 holder looked the view model up by this
        if weaponHolder:GetIsActive() then
            self:SetViewModel(self.viewModelName, weaponHolder)
        end
        if not self:isa("VTArtificer") then           -- the Crucible has no cockpit (no deploy light)
            weaponHolder:TriggerEffects("exo_login")
        end
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

-- ---- homing missiles (right click) ---------------------------------------------------------------------------
-- Left click fires both plasma miniguns (vanilla dual-fire lock forced on, see ExoWeaponHolder:CheckDualFiring
-- below); right click no longer reaches the weapon holder. Hold right click: VT_UpdateMissile (server, every move)
-- locks the enemy closest to the crosshair and launches a VTHomingMissile (Classes/VTWeapons.lua) once the lock is
-- complete, then every kVTMissileRefireDelay while it holds. No lock, no missile (user 2026-11-17).
-- own sound bank: art/sound/build_sounds.sh -> output/sound/vaelthor.fev
local kMissileLaunchSound = PrecacheAsset("sound/vaelthor.fev/missile/launch")

function VTPraetor:SecondaryAttack()
    self.vtMissileHeld = true
end

function VTPraetor:SecondaryAttackEnd()
    self.vtMissileHeld = false
    self.vtMissileFiredThisHold = false
end

if Server then

    local function GetIsLockable(self, entity, eye)
        if not (entity:GetIsAlive() and entity:GetCanTakeDamage()) then return false end
        if HasMixin(entity, "Cloakable") and entity:GetIsCloaked() then return false end
        local trace = Shared.TraceRay(eye, entity:GetEngagementPoint(), CollisionRep.LOS, PhysicsMask.Bullets, EntityFilterAll())
        return trace.fraction >= 0.99
    end

    -- Enemy closest to the crosshair within lockAngle (keepAngle for the current target), range, line of sight,
    -- not cloaked. Defaults: the missile lock. Also used by the Praetor II beam (VTPraetor2).
    function VTPraetor:VT_FindAutoTarget(current, lockAngle, keepAngle, range)
        local eye = self:GetEyePos()
        local forward = self:GetViewCoords().zAxis
        local lockCos = math.cos(math.rad(lockAngle or kVTMissileLockAngle))
        local keepCos = math.cos(math.rad(keepAngle or kVTMissileKeepAngle))
        local best, bestCos
        local enemies = GetEntitiesWithMixinForTeamWithinRange("Live", GetEnemyTeamNumber(self:GetTeamNumber()), eye,
                range or kVTMissileLockRange)
        for _, entity in ipairs(enemies) do
            local toTarget = entity:GetEngagementPoint() - eye
            local dist = toTarget:GetLength()
            if dist > 1 then
                local c = forward:DotProduct(toTarget / dist)
                if c >= (entity == current and keepCos or lockCos) and (not bestCos or c > bestCos)
                        and GetIsLockable(self, entity, eye) then
                    best, bestCos = entity, c
                end
            end
        end
        return best
    end

    function VTPraetor:VT_UpdateMissile(deltaTime)
        if not self.vtMissileHeld or not self:GetIsAlive() then
            self.vtMissileLockId = Entity.invalidId
            self.vtMissileLockFraction = 0
            return
        end
        local current = Shared.GetEntity(self.vtMissileLockId)
        local target = self:VT_FindAutoTarget(current)
        if target ~= current then
            self.vtMissileLockId = target and target:GetId() or Entity.invalidId
            self.vtMissileLockFraction = 0
        end
        if target then
            self.vtMissileLockFraction = math.min(1, self.vtMissileLockFraction + deltaTime / kVTMissileLockTime)
            if self.vtMissileLockFraction >= 1 then
                self:VT_FireMissile(target)
            end
        end
    end

    -- target: the locked entity (only VT_UpdateMissile calls this, with a completed lock). True when it launched.
    function VTPraetor:VT_FireMissile(target)
        local now = Shared.GetTime()
        if now < self.vtNextMissileTime or self:GetIsWebbed() then
            return false
        end
        if self.vtEnergy < kVTMissileEnergyCost then
            if not self.vtMissileWarned or now - self.vtMissileWarned > 2 then
                self.vtMissileWarned = now
                VT_SendMessageToPlayer(self, string.format("Homing missile needs %d energy.", kVTMissileEnergyCost))
            end
            return false
        end
        self.vtEnergy = self.vtEnergy - kVTMissileEnergyCost
        self.vtLastBoltTime = now                       -- counts as a shot for the recharge delay
        self.vtNextMissileTime = now + kVTMissileRefireDelay
        self.vtMissileFiredThisHold = true

        local view = self:GetViewCoords()
        local eye = self:GetEyePos()
        -- launch from the right-shoulder pod (Client.lua draws it at the same point), slightly up when homing
        local anchor = self:GetAttachPointIndex("Exosuit_UpprTorso") >= 0
                and self:GetAttachPointCoords("Exosuit_UpprTorso").origin or eye
        if (anchor - eye):GetLengthSquared() > 4 then
            anchor = eye                -- model coords not ready (identity attach coords = map origin)
        end
        local start = anchor + view.yAxis * kVTShoulderMountUp - view.xAxis * kVTShoulderMountRight
                + view.zAxis * kVTShoulderMountForward
        local clear = Shared.TraceRay(eye, start, CollisionRep.Damage, PhysicsMask.Bullets, EntityFilterAll())
        if clear.fraction < 1 then
            start = eye + view.zAxis * 0.3
        end
        local direction = target and GetNormalizedVector(view.zAxis + view.yAxis * 0.25) or view.zAxis

        local missile = CreateEntity(VTHomingMissile.kMapName, start, self:GetTeamNumber())
        if missile then
            missile:SetOwner(self)
            missile:VT_Launch(direction, target)
        end
        -- no predictor: missiles launch on the server only, the Praetor must hear its own launch too
        StartSoundEffectOnEntity(kMissileLaunchSound, self, 1)
        return true
    end

end

-- Left click fires both arms: the vanilla dual-fire lock (an Exo client option) is always on for the Praetor.
if ExoWeaponHolder and ExoWeaponHolder.CheckDualFiring and not VT_HookedPraetorDualFire then
    VT_HookedPraetorDualFire = true
    local oldCheckDualFiring = ExoWeaponHolder.CheckDualFiring
    function ExoWeaponHolder:CheckDualFiring()
        local parent = self:GetParent()
        if parent and parent:isa("VTPraetor") then
            return true
        end
        return oldCheckDualFiring(self)
    end
end

-- The exo view model's animation tags: footsteps for the local player ("view_step"), the hydraulic deploy sound
-- ("deploy_start") and the cockpit screen dissolve ("deploy_end"). None of them for the Artificer's Crucible.
if ExoWeaponHolder and ExoWeaponHolder.OnTag and not VT_HookedArtificerTags then
    VT_HookedArtificerTags = true
    local oldOnTag = ExoWeaponHolder.OnTag
    local kSkip = { view_step = true, deploy_start = true, deploy_end = true }
    function ExoWeaponHolder:OnTag(tagName)
        if kSkip[tagName] then
            local parent = self:GetParent()
            if parent and parent:isa("VTArtificer") then
                return
            end
        end
        return oldOnTag(self, tagName)
    end
end

function VTPraetor:GetMapBlipType()
    return kMinimapBlipType.Exo
end

InstallNoFlashlight(VTPraetor)

-- Exo chassis armor without the vanilla armor levels (Shield Matrix raises the shield instead).
function VTPraetor:GetArmorAmount(armorLevels)
    return VTBase.Exo.GetArmorAmount(self, 0)
end

VT_InstallShield(VTPraetor, true)
Shared.LinkClassToMap("VTPraetor", VTPraetor.kMapName, praetorNetworkVars, true)

-- ----------------------------------------------------------------------------
-- Praetor II (TEST class, 2026-11-17): a Praetor whose right click is a steady psionic beam instead of homing
-- missiles. Only reachable with "vt_class praetor2" (cheats); not in the Synthesis Matrix menu, no caste stock.
-- Subclass of VTPraetor, so everything else (laser guns, energy, Teleport Dash, HUD) is the Praetor's.
-- Hold right click: the enemy closest to the crosshair (kVTBeamAngle, kVTBeamRange, line of sight, not cloaked)
-- is targeted automatically and kept while it stays inside kVTBeamKeepAngle; kVTBeamDPS is dealt every
-- kVTBeamTickInterval through the right arm weapon (so kills are credited and Plasma Calibration applies) and
-- kVTBeamEnergyPerSecond is drained from the Praetor pool. vtBeamTargetId is networked to everyone: the clients
-- draw the beam (Client.lua, Obelisk beam strips) from in front of the Praetor's chest to the target.
-- ----------------------------------------------------------------------------
class 'VTPraetor2' (VTPraetor)

VTPraetor2.kMapName = kVTMapNames.Praetor2

local praetor2NetworkVars =
{
    vtBeamTargetId = "entityid",
}

function VTPraetor2:OnCreate()
    VTPraetor.OnCreate(self)
    -- the map name "vt_praetor2" has no TechData entry: use the Praetor's (health, extents, icon, name)
    self.techId = kTechId.VTPraetor
    if Server then
        -- LiveMixin read the health while the tech id was still None (default 100): apply the Praetor's
        local maxHealth = LookupTechData(kTechId.VTPraetor, kTechDataMaxHealth, self.maxHealth)
        self:SetMaxHealth(maxHealth)
        self.health = maxHealth
    end
    self.vtBeamTargetId = Entity.invalidId
    self.vtBeamHeld = false
    self.vtBeamDamage = 0
    self.vtNextBeamTick = 0
end

function VTPraetor2:SecondaryAttack()
    self.vtBeamHeld = true
end

function VTPraetor2:SecondaryAttackEnd()
    self.vtBeamHeld = false
end

-- Beam numbers as a method: the Artificer (subclass) uses the same beam as its weaker left-click defense beam.
local kPraetor2Beam =
{
    dps = kVTBeamDPS, range = kVTBeamRange, angle = kVTBeamAngle, keepAngle = kVTBeamKeepAngle,
    energyPerSecond = kVTBeamEnergyPerSecond, minEnergy = kVTBeamMinEnergy,
}
function VTPraetor2:VT_GetBeamParams()
    return kPraetor2Beam
end

if Server then

    local function GetBeamDoer(self)
        local holder = self:GetWeapon(ExoWeaponHolder.kMapName)
        local weapon = holder and Shared.GetEntity(holder.rightWeaponId)
        return weapon and HasMixin(weapon, "Damage") and weapon or nil
    end

    -- replaces the missile lock (called from VTPraetor:OnProcessMove every move)
    function VTPraetor2:VT_UpdateMissile(deltaTime)
        local beam = self:VT_GetBeamParams()
        local target
        if self.vtBeamHeld and self:GetIsAlive() and self.vtEnergy >= beam.minEnergy then
            target = self:VT_FindAutoTarget(Shared.GetEntity(self.vtBeamTargetId), beam.angle, beam.keepAngle, beam.range)
        end
        self.vtBeamTargetId = target and target:GetId() or Entity.invalidId
        if not target then
            self.vtBeamDamage = 0
            return
        end

        local now = Shared.GetTime()
        self.vtEnergy = math.max(0, self.vtEnergy - beam.energyPerSecond * deltaTime)
        self.vtLastBoltTime = now                 -- the beam counts as firing for the recharge delay
        self.vtBeamDamage = self.vtBeamDamage + beam.dps * deltaTime
        if now < self.vtNextBeamTick then
            return
        end
        self.vtNextBeamTick = now + kVTBeamTickInterval

        local doer = GetBeamDoer(self)
        if doer and self.vtBeamDamage > 0 then
            local point = target:GetEngagementPoint()
            local direction = GetNormalizedVector(point - self:GetEyePos())
            -- surface "none": no impact effect per tick (the clients draw the beam and its glow)
            doer:DoDamage(self.vtBeamDamage, target, point, direction, "none", false, false)
        end
        self.vtBeamDamage = 0
    end

end

-- shield, network vars and the Praetor's installs (shared, flashlight, shield) are inherited from VTPraetor
Shared.LinkClassToMap("VTPraetor2", VTPraetor2.kMapName, praetor2NetworkVars, true)

-- ----------------------------------------------------------------------------
-- Artificer (CONCEPT class, 2026-11-17): a walking drone factory. Only reachable with "vt_class artificer" (cheats);
-- not in the Synthesis Matrix menu, no caste stock. Built on the Praetor II (Praetor chassis, energy, shoulder beam
-- emitter), but:
--   * bigger, slower core: kVTArtificerEnergy, kVTArtificerRechargeRate; tankier (health x kVTArtificerHealthScalar,
--     shield kVTMaxShield.VTArtificer) and slower (kVTArtificerSpeedScalar)
--   * LEFT click: the shoulder beam as a weak auto-aim defense beam (kVTArtificerBeam*); the arm guns stay silent
--   * 1 / 2 / 3: queue a Wasp / Lancer / Sapper drone (paid from the core when ordered); 4: cancel the last order
--     (refund). One drone is fabricated at a time; it launches when its build time is up and the bay has room
--     (kVTArtificerMaxDrones alive).
--   * Shift + 1 / 2 / 3: cycle that drone type's directive (Escort / Hunt / Siege / Focus)
--   * RIGHT click: mark the enemy closest to the crosshair (again on the same target / on nothing: clear the mark)
--   * B (Swarm Command): for kVTArtificerSwarmDuration every drone attacks the mark, whatever its directive
-- The drones (VTDrone, Classes/VTDrones.lua) read the directives / mark / swarm from their owner every think.
-- HUD: GUI/GUIVTDroneBay.lua (bay panel, drone + mark markers), GUIVTPlayerHUD chips.
-- ----------------------------------------------------------------------------
-- The Crucible's sounds (played on clients by VTCrucible.lua). Precached HERE, in shared code: sound indices come
-- from the server's precache list, so a sound precached only on the client has no index and
-- Client.CreateSoundEffect returns nil (2026-11-17: "attempt to index local 'sound'" every frame).
kVTCrucibleSounds =
{
    steps  = { PrecacheAsset("sound/vaelthor.fev/crucible/step1"), PrecacheAsset("sound/vaelthor.fev/crucible/step2"),
               PrecacheAsset("sound/vaelthor.fev/crucible/step3") },
    servo  = PrecacheAsset("sound/vaelthor.fev/crucible/servo"),
    hum    = PrecacheAsset("sound/vaelthor.fev/crucible/hum"),
    unfold = PrecacheAsset("sound/vaelthor.fev/crucible/unfold"),
    jump   = PrecacheAsset("sound/vaelthor.fev/crucible/jump"),    -- played via effects (Hooks/DamageEffects.lua)
    land   = PrecacheAsset("sound/vaelthor.fev/crucible/land"),
}

class 'VTArtificer' (VTPraetor2)

VTArtificer.kMapName = kVTMapNames.Artificer

local kQueueSlotType = string.format("private integer (0 to %d)", kVTDroneTypeCount)
local kDroneCountType = string.format("private integer (0 to %d)", kVTArtificerMaxDrones + 2)
local kDirectiveType = string.format("private integer (1 to %d)", #kVTDroneDirectiveNames)

local artificerNetworkVars =
{
    vtMarkId        = "private entityid",
    vtBuildStart    = "private time",
    vtBuildEnd      = "private time",
    vtBayFull       = "private boolean",       -- the order at the head is done but the bay has no room
    vtSpawnTime     = "time",                  -- all clients: the Crucible's unfold animation (VTCrucible.lua)
}
for i = 1, kVTArtificerQueueSize do
    artificerNetworkVars["vtQueue" .. i] = kQueueSlotType
end
for t = 1, kVTDroneTypeCount do
    artificerNetworkVars["vtDirective" .. t] = kDirectiveType
    artificerNetworkVars["vtDrones" .. t] = kDroneCountType
end

function VTArtificer:OnCreate()
    VTPraetor2.OnCreate(self)
    -- no exo deploy (camera bounce from below, 1.4 s input lock, cockpit light): the Crucible unfolds instead
    self.creationTime = Shared.GetTime() - kExosuitDeployDuration - 1
    self.vtSpawnTime = Shared.GetTime()
    -- no exo cockpit hum (the Crucible's core hums instead, VTCrucible.lua)
    if Server and self.idleSound2D then
        self.idleSound2D:Stop()
    end
    self.vtEnergy = kVTArtificerEnergy
    if Server then
        local maxHealth = math.floor(self:GetMaxHealth() * kVTArtificerHealthScalar + 0.5)
        self:SetMaxHealth(maxHealth)
        self.health = maxHealth
    end
    self.vtMarkId = Entity.invalidId
    self.vtBuildStart = 0
    self.vtBuildEnd = 0
    self.vtBayFull = false
    for i = 1, kVTArtificerQueueSize do
        self["vtQueue" .. i] = 0
    end
    for t = 1, kVTDroneTypeCount do
        self["vtDirective" .. t] = kVTDroneTypes[t].directive
        self["vtDrones" .. t] = 0
    end
    self.vtFactoryKeys = 0
    self.vtMarkHeld = false
    self.vtNextDroneSlot = 0
end

-- The Titan underneath must never render (VTCrucible.lua draws the Crucible). VTCrucible's override materials only
-- take once the render model is ready, so the Titan showed for a few frames at spawn. The opacity system is applied
-- by BaseModelMixin the moment the render model is created: hiddenAmount 1 makes the marine / exosuit shaders
-- alpha-test every pixel away (their dissolve effect).
function VTArtificer:OnInitialized()
    VTPraetor2.OnInitialized(self)
    if Client then
        self:SetOpacity(0, "vtCrucible")
    end
end

-- First person: the exo's view model (cockpit, minigun arms, deploy animation) must never show - the Crucible draws
-- its own (crucible_view.model, Client.lua). Override materials only take once the model has loaded, which is after
-- the deploy started; ViewModel:OnAdjustModelCoords asks the parent instead, every frame from the first: put the
-- model 100 m behind the camera. Its camera FOV (the view zone's) is kept.
function VTArtificer:ModifyViewModelCoords(coords)
    coords.origin = coords.origin + Vector(0, 0, -100)
    return coords
end

-- the Crucible has its own steps (VTCrucible.lua): no exo footsteps (other players' view of the world model)
if Client then
    function VTArtificer:TriggerFootstep()
    end
end

-- eye at the Crucible's height (the exo's 2.3 m looked down from above the dome); also the beam / mark origin
function VTArtificer:GetMaxViewOffsetHeight()
    return kVTCrucible.eyeHeight
end

-- first person: the camera rises with the unfolding body (instead of the exo's bounce)
function VTArtificer:PlayerCameraCoordsAdjustment(cameraCoords)
    cameraCoords = VTPraetor2.PlayerCameraCoordsAdjustment(self, cameraCoords)
    local u = VT_GetCrucibleUnfold(self)
    if u < 1 and self:GetIsAlive() then
        local e = 1 - (1 - u) * (1 - u) * (1 - u)          -- ease out
        cameraCoords.origin.y = cameraCoords.origin.y - kVTCrucible.unfoldDrop * (1 - e)
    end
    return cameraCoords
end

function VTArtificer:VT_GetMaxEnergy()
    return kVTArtificerEnergy
end

function VTArtificer:VT_GetEnergyRecharge()
    return kVTArtificerRechargeRate, kVTArtificerRechargeDelay
end

local kArtificerBeam =
{
    dps = kVTArtificerBeamDPS, range = kVTArtificerBeamRange, angle = kVTArtificerBeamAngle,
    keepAngle = kVTArtificerBeamKeepAngle, energyPerSecond = kVTArtificerBeamEnergyPerSecond, minEnergy = kVTBeamMinEnergy,
}
function VTArtificer:VT_GetBeamParams()
    return kArtificerBeam
end

function VTArtificer:GetMaxSpeed(possible)
    return VTPraetor2.GetMaxSpeed(self, possible) * kVTArtificerSpeedScalar
end

-- left click = defense beam (the plasma miniguns never get the attack)
function VTArtificer:PrimaryAttack()
    self.vtBeamHeld = true
end

function VTArtificer:PrimaryAttackEnd()
    self.vtBeamHeld = false
end

-- right click = mark (press edge, server)
function VTArtificer:SecondaryAttack()
    if not self.vtMarkHeld then
        self.vtMarkHeld = true
        if Server then
            self:VT_MarkTarget()
        end
    end
end

function VTArtificer:SecondaryAttackEnd()
    self.vtMarkHeld = false
end

-- ---- queue helpers (shared: the HUD reads them on the client) ------------------------------------------------
function VTArtificer:VT_GetQueueLength()
    for i = 1, kVTArtificerQueueSize do
        if (self["vtQueue" .. i] or 0) == 0 then
            return i - 1
        end
    end
    return kVTArtificerQueueSize
end

function VTArtificer:VT_GetDroneCount()
    local n = 0
    for t = 1, kVTDroneTypeCount do
        n = n + (self["vtDrones" .. t] or 0)
    end
    return n
end

-- 0..1 progress of the order at the head of the queue (nil: idle)
function VTArtificer:VT_GetBuildProgress()
    if (self.vtQueue1 or 0) == 0 then
        return nil
    end
    local span = math.max(0.01, self.vtBuildEnd - self.vtBuildStart)
    return Clamp((Shared.GetTime() - self.vtBuildStart) / span, 0, 1)
end

function VTArtificer:VT_GetMark()
    local mark = self.vtMarkId and self.vtMarkId ~= Entity.invalidId and Shared.GetEntity(self.vtMarkId) or nil
    if mark and HasMixin(mark, "Live") and mark:GetIsAlive() then
        return mark
    end
    return nil
end

-- 1-4: drone type keys, Shift: directive modifier
local kFactoryKeys = { Move.Weapon1, Move.Weapon2, Move.Weapon3, Move.Weapon4 }
local kFactoryKeyMask = bit.bor(Move.Weapon1, Move.Weapon2, Move.Weapon3, Move.Weapon4, Move.Weapon5)

function VTArtificer:HandleButtons(input)
    local commands = input.commands
    if Server then
        local held = bit.band(commands, kFactoryKeyMask)
        local pressed = bit.band(held, bit.bnot(self.vtFactoryKeys or 0))
        self.vtFactoryKeys = held
        if pressed ~= 0 and self:GetIsAlive() then
            local shift = bit.band(commands, Move.MovementModifier) ~= 0
            for key, flag in ipairs(kFactoryKeys) do
                if bit.band(pressed, flag) ~= 0 then
                    if key == 4 then
                        self:VT_CancelLastOrder()
                    elseif shift then
                        self:VT_CycleDirective(key)
                    else
                        self:VT_OrderDrone(key)
                    end
                end
            end
        end
    end
    -- the number keys never reach the weapon switch
    input.commands = bit.band(commands, bit.bnot(kFactoryKeyMask))
    VTPraetor2.HandleButtons(self, input)
end

if Server then

    function VTArtificer:VT_OrderDrone(droneType)
        local spec = kVTDroneTypes[droneType]
        local length = self:VT_GetQueueLength()
        if length >= kVTArtificerQueueSize then
            VT_SendMessageToPlayer(self, "Fabrication queue full.")
            return
        end
        if self.vtEnergy < spec.cost then
            VT_SendMessageToPlayer(self, string.format("%s drone needs %d energy.", spec.name, spec.cost))
            return
        end
        local now = Shared.GetTime()
        self.vtEnergy = self.vtEnergy - spec.cost
        self.vtLastBoltTime = now                       -- spending pauses the recharge
        self["vtQueue" .. (length + 1)] = droneType
        if length == 0 then
            self.vtBuildStart = now
            self.vtBuildEnd = now + spec.buildTime
        end
    end

    function VTArtificer:VT_CancelLastOrder()
        local length = self:VT_GetQueueLength()
        if length == 0 then
            return
        end
        local droneType = self["vtQueue" .. length]
        self["vtQueue" .. length] = 0
        self.vtEnergy = math.min(kVTArtificerEnergy, self.vtEnergy + kVTDroneTypes[droneType].cost)
        if length == 1 then
            self.vtBuildStart, self.vtBuildEnd, self.vtBayFull = 0, 0, false
        end
    end

    function VTArtificer:VT_CycleDirective(droneType)
        local key = "vtDirective" .. droneType
        self[key] = (self[key] % #kVTDroneDirectiveNames) + 1
    end

    function VTArtificer:VT_MarkTarget()
        local current = self:VT_GetMark()
        local target = self:VT_FindAutoTarget(nil, kVTArtificerMarkAngle, kVTArtificerMarkAngle, kVTArtificerMarkRange)
        if not target or target == current then
            self.vtMarkId = Entity.invalidId
        else
            self.vtMarkId = target:GetId()
        end
    end

    -- B: Swarm Command
    function VTArtificer:VT_UseAbility()
        if not self:VT_GetMark() then
            VT_SendMessageToPlayer(self, "Swarm Command needs a marked target (right click).")
            return
        end
        if self:VT_GetDroneCount() == 0 then
            VT_SendMessageToPlayer(self, "Swarm Command: no drones in the field.")
            return
        end
        self.vtAbilityActiveEnd = Shared.GetTime() + kVTArtificerSwarmDuration
        self:VT_StartCooldown(kVTArtificerSwarmCooldown)
    end

    function VTArtificer:VT_GetSwarmActive()
        return self:VT_GetAbilityActive() and self:VT_GetMark() ~= nil
    end

    -- Launch point: out of the Crucible's furnace iris (VTCrucible.lua: core at 1.5 m), a bit above it.
    function VTArtificer:VT_GetDroneLaunchPoint()
        local point = self:GetOrigin() + Vector(0, 1.95, 0)
        local eye = self:GetEyePos()
        local trace = Shared.TraceRay(eye, point, CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
        return trace.fraction < 1 and (eye + (point - eye) * math.max(0, trace.fraction - 0.15)) or point
    end

    local function UpdateDroneCounts(self)
        local counts = {}
        local myId = self:GetId()
        for _, drone in ientitylist(Shared.GetEntitiesWithClassname("VTDrone")) do
            if drone.vtOwnerId == myId and drone:GetIsAlive() then
                local t = drone.vtDroneType
                counts[t] = (counts[t] or 0) + 1
            end
        end
        for t = 1, kVTDroneTypeCount do
            self["vtDrones" .. t] = math.min(kVTArtificerMaxDrones + 2, counts[t] or 0)
        end
    end

    local function UpdateFabrication(self)
        UpdateDroneCounts(self)
        local mark = self.vtMarkId ~= Entity.invalidId and Shared.GetEntity(self.vtMarkId)
        if mark ~= nil and not (mark and HasMixin(mark, "Live") and mark:GetIsAlive()) then
            self.vtMarkId = Entity.invalidId              -- the mark died / left relevancy
        end
        local droneType = self.vtQueue1 or 0
        if droneType == 0 then
            self.vtBayFull = false
            return
        end
        local now = Shared.GetTime()
        if now < self.vtBuildEnd then
            return
        end
        if self:VT_GetDroneCount() >= kVTArtificerMaxDrones then
            self.vtBayFull = true                         -- done, waits for room
            return
        end
        self.vtBayFull = false
        local drone = CreateEntity(VTDrone.kMapName, self:VT_GetDroneLaunchPoint(), self:GetTeamNumber())
        if drone then
            self.vtNextDroneSlot = (self.vtNextDroneSlot + 1) % kVTArtificerMaxDrones
            drone:VT_Setup(self, droneType, self.vtNextDroneSlot)
            self["vtDrones" .. droneType] = (self["vtDrones" .. droneType] or 0) + 1
        end
        -- pop the head, start the next order
        for i = 1, kVTArtificerQueueSize - 1 do
            self["vtQueue" .. i] = self["vtQueue" .. (i + 1)]
        end
        self["vtQueue" .. kVTArtificerQueueSize] = 0
        local nextType = self.vtQueue1
        if nextType ~= 0 then
            self.vtBuildStart = now
            self.vtBuildEnd = now + kVTDroneTypes[nextType].buildTime
        else
            self.vtBuildStart, self.vtBuildEnd = 0, 0
        end
    end

    -- called by VTPraetor:OnProcessMove (server) every move: the defense beam, then the factory
    function VTArtificer:VT_UpdateMissile(deltaTime)
        VTPraetor2.VT_UpdateMissile(self, deltaTime)
        if self:GetIsAlive() then
            UpdateFabrication(self)
        end
        self:VT_UpdateHitboxes()          -- the Crucible's hitboxes follow the player (below)
    end

end

-- ---- hitboxes: the Crucible's shape instead of the hidden Titan -------------------------------------------------
-- The Titan model's own hitboxes move to the ragdoll physics group (bullets, melee, spit, grenades and flames all
-- ignore it); kinematic boxes in the player group, owned by this entity, take their place (like the Babbler
-- hitbox): hull (two boxes, 45 degrees apart = the octagon), belly pods, dome, iris, pincers + emitter, and a thigh
-- and shin box per leg in its rest pose (the client's gait swings the feet +-0.4 m around it). Updated every move on
-- the server, every server tick (OnUpdate) and every frame on clients (VTCrucible.lua). Movement collision is the player capsule, unchanged.
-- Not lag-compensated (the engine rewinds model hitboxes only): at the Artificer's speed a high-ping shooter may
-- be off by a few decimetres.
local kCrucibleBoxes =      -- local centre, half extents, yaw (radians)
{
    { Vector(0, 0.85, 0),      Vector(0.50, 0.22, 0.50), 0 },
    { Vector(0, 0.85, 0),      Vector(0.50, 0.22, 0.50), math.pi / 4 },
    { Vector(0, 0.60, 0),      Vector(0.40, 0.08, 0.40), 0 },
    { Vector(0, 1.27, -0.04),  Vector(0.33, 0.19, 0.33), 0 },
    { Vector(0, 1.55, -0.04),  Vector(0.28, 0.11, 0.28), 0 },
    { Vector(0, 1.05, 0.72),   Vector(0.62, 0.17, 0.30), 0 },
}
local kThighHalf, kShinHalf = 0.08, 0.065

local function BoxCoords(origin, zAxis, yHint)
    local c = Coords.GetIdentity()
    c.origin = origin
    c.zAxis = zAxis
    local y = yHint - zAxis * zAxis:DotProduct(yHint)
    if y:GetLengthSquared() < 1e-6 then y = Vector(1, 0, 0) end
    y:Normalize()
    c.yAxis = y
    c.xAxis = y:CrossProduct(zAxis)
    return c
end

-- every box as { coords, half extents } in world space
function VTArtificer:VT_GetHitboxShapes()
    local body = Angles(0, self:GetAngles().yaw, 0):GetCoords()
    body.origin = self:GetOrigin()
    local shapes = {}
    for _, b in ipairs(kCrucibleBoxes) do
        local c = Angles(0, b[3], 0):GetCoords()
        local world = Coords.GetIdentity()
        world.xAxis = body:TransformVector(c.xAxis)
        world.yAxis = body:TransformVector(c.yAxis)
        world.zAxis = body:TransformVector(c.zAxis)
        world.origin = body:TransformPoint(b[1])
        shapes[#shapes + 1] = { world, b[2] }
    end
    for _, leg in ipairs(VT_GetCrucibleLegs()) do
        local hip = body:TransformPoint(leg.hip)
        local foot = body:TransformPoint(leg.hip + leg.out * kVTCrucible.footReach - Vector(0, kVTCrucible.hipHeight - 0.1, 0))
        local knee, ankle = VT_CrucibleKnee(hip, foot)
        for _, part in ipairs({ { hip, knee, kThighHalf }, { knee, ankle, kShinHalf } }) do
            local from, to, half = part[1], part[2], part[3]
            local length = (to - from):GetLength()
            shapes[#shapes + 1] = { BoxCoords((from + to) * 0.5, GetNormalizedVector(to - from), Vector(0, 1, 0)),
                                    Vector(half, half, length * 0.5) }
        end
    end
    return shapes
end

function VTArtificer:VT_DestroyHitboxes()
    for _, box in ipairs(self.vtHitboxes or {}) do
        Shared.DestroyCollisionObject(box)
    end
    self.vtHitboxes = nil
end

function VTArtificer:VT_UpdateHitboxes()
    if not self:GetIsAlive() then
        self:VT_DestroyHitboxes()
        return
    end
    -- the hidden Titan's hitboxes: out of every damage trace (re-applied: the group is reset on (re)spawn)
    if self.vtTitanGroupSet ~= self:GetId() then
        self:SetPhysicsGroup(PhysicsGroup.RagdollGroup)
        self.vtTitanGroupSet = self:GetId()
    end
    local shapes = self:VT_GetHitboxShapes()
    if not self.vtHitboxes then
        self.vtHitboxes = {}
        for i, shape in ipairs(shapes) do
            local box = Shared.CreatePhysicsBoxBody(false, shape[2], 0, shape[1])
            box:SetGroup(PhysicsGroup.PlayerGroup)
            box:SetEntity(self)
            box:SetPhysicsType(CollisionObject.Kinematic)
            self.vtHitboxes[i] = box
        end
    end
    for i, shape in ipairs(shapes) do
        self.vtHitboxes[i]:SetCoords(shape[1])
    end
end

-- Every server tick as well, not only per move: an Artificer without a controlling client (spawned with "spawn",
-- a lagging player) gets no moves - its hitboxes stayed with the Titan in the first test (2026-11-17).
function VTArtificer:OnUpdate(deltaTime)
    VTPraetor2.OnUpdate(self, deltaTime)
    if Server then
        self:VT_UpdateHitboxes()
    end
end

function VTArtificer:OnDestroy()
    self:VT_DestroyHitboxes()
    VTPraetor2.OnDestroy(self)
end

function VTArtificer:OnKill(attacker, doer, point, direction)
    self:VT_DestroyHitboxes()
    if VTPraetor2.OnKill then
        VTPraetor2.OnKill(self, attacker, doer, point, direction)
    end
end

-- network vars and installs (shared, flashlight, shield) are inherited from VTPraetor / VTPraetor2
Shared.LinkClassToMap("VTArtificer", VTArtificer.kMapName, artificerNetworkVars, true)
