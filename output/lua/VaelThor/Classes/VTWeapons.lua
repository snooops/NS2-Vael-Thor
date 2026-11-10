-- ============================================================================
-- Vael'Thor Empire - weapons (prototyped on marine weapon models)
--
-- Damage changes are expressed through GetVTDamageScalar(target), which the
-- central damage hook (Hooks/DamageTypes.lua) applies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Faster weapon switching (Vanguard weapons): the draw animation and the
-- "deploy_end" tag that makes a clip weapon usable are driven by the
-- catalyst_speed animation input, which Marine:OnUpdateAnimationInput takes from
-- weapon:GetCatalystSpeedBase(). While the weapon is being drawn it reports
-- kVTDrawSpeedScalar; afterwards its normal speed (e.g. the carbine's slower fire).
-- ----------------------------------------------------------------------------
local function InstallFastDraw(cls)
    local baseSpeed = cls.GetCatalystSpeedBase
    local baseOnDraw = cls.OnDraw
    function cls:OnDraw(player, previousWeaponMapName)
        baseOnDraw(self, player, previousWeaponMapName)
        self.vtDrawTime = Shared.GetTime()
    end
    function cls:GetCatalystSpeedBase()
        local drawing
        if self.GetIsDeployed then
            drawing = not self:GetIsDeployed()
        else
            drawing = Shared.GetTime() - (self.vtDrawTime or 0) < kVTKnifeDrawTime / kVTDrawSpeedScalar
        end
        if drawing then
            return kVTDrawSpeedScalar
        end
        return baseSpeed and baseSpeed(self) or 1
    end
end

-- ----------------------------------------------------------------------------
-- Plasma bolt: the carbine's projectile (predicted, no gravity). A glowing
-- tapered tube (models/vaelthor/bolt/, art/weapons/build_plasma_bolt.sh) with
-- a purple point light, blaster style. Damage = kRifleDamage x the carbine's
-- scalar at the moment it was fired (Overcharge included), applied by the
-- central damage hook through GetVTDamageScalar.
-- ----------------------------------------------------------------------------
Script.Load("lua/Weapons/PredictedProjectile.lua")

-- ---- hit debugging ("vt_hitdebug", cheats): every bolt's fate, server truth vs. client prediction ----------
-- Server: what each bolt really did (unit hit + damage + distance / world / expired), printed to the shooter's
-- console. Client: where the client's own prediction saw the same bolt end. Compare the two lists.
VT_HitDebugServer = false
VT_HitDebugClient = false
local function DebugName(ent)
    return ent and (ent.GetClassName and ent:GetClassName() or "?") or "world"
end

if Server then
    Event.Hook("Console_vt_hitdebug", function(client)
        if not Shared.GetCheatsEnabled() then
            ServerAdminPrint(client, "[Vael'Thor] vt_hitdebug requires cheats 1")
            return
        end
        VT_HitDebugServer = not VT_HitDebugServer
        ServerAdminPrint(client, "[Vael'Thor] server hit debug " .. (VT_HitDebugServer and "ON" or "OFF"))
    end)
end

if Client then
    Event.Hook("Console_vt_hitdebug", function()
        VT_HitDebugClient = not VT_HitDebugClient
        Shared.Message("[Vael'Thor] client hit debug " .. (VT_HitDebugClient and "ON" or "OFF"))
    end)

    -- the client's predicted bolt: report its first impact once
    local kBoltModel = "models/vaelthor/bolt/plasma_bolt.model"
    local baseMove = ProjectileController.Move
    function ProjectileController:Move(deltaTime, velocity)
        local impact, hitEntity, normal, endPoint = baseMove(self, deltaTime, velocity)
        if VT_HitDebugClient and impact and not self.vtDebugReported and self.modelName == kBoltModel
                and not Shared.GetIsRunningPrediction() then
            self.vtDebugReported = true
            local player = Client.GetLocalPlayer()
            local dist = player and endPoint and (endPoint - player:GetEyePos()):GetLength() or 0
            Shared.Message(string.format("[client] bolt #%d predicted: %s at %.1f m", self.projectileId or -1,
                    DebugName(hitEntity), dist))
        end
        return impact, hitEntity, normal, endPoint
    end
end

class 'VTPlasmaBolt' (PredictedProjectile)

VTPlasmaBolt.kMapName            = "vt_plasmabolt"
VTPlasmaBolt.kModelName          = PrecacheAsset("models/vaelthor/bolt/plasma_bolt.model")
VTPlasmaBolt.kRadius             = kVTCarbineBoltRadius
VTPlasmaBolt.kClearOnImpact      = true
VTPlasmaBolt.kClearOnEnemyImpact = true

local kBoltLightColor = Color(0.70, 0.30, 1.0)

local boltNetworkVars = {}
AddMixinNetworkVars(TeamMixin, boltNetworkVars)

function VTPlasmaBolt:OnCreate()
    PredictedProjectile.OnCreate(self)
    InitMixin(self, DamageMixin)
    self.vtDamageScalar = kVTCarbineDamageScalar
    -- defaults = carbine; the Praetor miniguns override these on the server entity
    self.vtBaseDamage = kRifleDamage
    self.vtDamageType = kRifleDamageType
    self.vtWeaponTechId = kTechId.VTPlasmaCarbine
    self.vtDeathIcon = kDeathMessageIcon.Rifle
    self.vtSplashRadius = 0          -- Praetor bolts: splash damage around the impact
    self.vtSplashDamage = 0
    if Server then
        self:AddTimedCallback(VTPlasmaBolt.TimeUp, kVTCarbineBoltLifetime)
    end
end

function VTPlasmaBolt:GetVTDamageScalar(target)
    return self.vtDamageScalar or kVTCarbineDamageScalar
end

function VTPlasmaBolt:GetDamageType()
    return self.vtDamageType or kRifleDamageType
end

function VTPlasmaBolt:GetIsAffectedByWeaponUpgrades()
    return true          -- Plasma Calibration (Weapons1-3)
end

function VTPlasmaBolt:GetWeaponTechId()
    return self.vtWeaponTechId or kTechId.VTPlasmaCarbine
end

function VTPlasmaBolt:GetDeathIconIndex()
    return self.vtDeathIcon or kDeathMessageIcon.Rifle
end

if Client then

    -- Purple light travelling with the bolt (lights up walls as it passes).
    function VTPlasmaBolt:OnInitialized()
        PredictedProjectile.OnInitialized(self)
        self.vtLight = Client.CreateRenderLight()
        self.vtLight:SetType(RenderLight.Type_Point)
        self.vtLight:SetCastsShadows(false)
        self.vtLight:SetSpecular(false)
        self.vtLight:SetColor(kBoltLightColor)
        self.vtLight:SetIntensity(kVTCarbineBoltLightIntensity)
        self.vtLight:SetRadius(kVTCarbineBoltLightRadius)
        self.vtLight:SetCoords(Coords.GetTranslation(self:GetOrigin()))
    end

    function VTPlasmaBolt:OnUpdate(deltaTime)
        PredictedProjectile.OnUpdate(self, deltaTime)
        if self.vtLight then
            self.vtLight:SetCoords(Coords.GetTranslation(self:GetOrigin()))
        end
    end

    function VTPlasmaBolt:OnDestroy()
        if self.vtLight then
            Client.DestroyRenderLight(self.vtLight)
            self.vtLight = nil
        end
        PredictedProjectile.OnDestroy(self)
    end

end

if Server then

    -- Impact effect for everyone near the hit (see Hooks/DamageEffects.lua): surface + normal from a short
    -- trace along the flight path, since the projectile controller passes no surface.
    local function SendImpact(self, owner, targetHit, hitPoint, direction, normal)
        local trace = Shared.TraceRay(hitPoint - direction * 0.3, hitPoint + direction * 0.5,
                CollisionRep.Damage, PhysicsMask.Bullets, EntityFilterTwo(self, owner))
        local surface = trace.fraction < 1 and trace.surface or ""
        if targetHit then
            surface = GetIsAlienUnit(targetHit) and "organic" or "metal"
        end
        if surface == "" or not rawget(kHitEffectSurface, surface) then
            surface = "metal"
        end
        local n = (trace.fraction < 1 and trace.normal) or normal or -direction
        local message =
        {
            posx = hitPoint.x, posy = hitPoint.y, posz = hitPoint.z,
            nx = Clamp(n.x, -1, 1), ny = Clamp(n.y, -1, 1), nz = Clamp(n.z, -1, 1),
            surface = kHitEffectSurface[surface],
            decal = targetHit == nil and trace.fraction < 1,
            splash = (self.vtSplashRadius or 0) > 0,
        }
        for _, player in ipairs(GetEntitiesWithinRange("Player", hitPoint, kHitEffectRelevancyDistance)) do
            Server.SendNetworkMessage(player, "VTBoltImpact", message, false)
        end
    end

    local function DebugReport(self, text)
        local owner = self:GetOwner()
        local client = owner and owner.GetClient and owner:GetClient()
        if client then
            ServerAdminPrint(client, string.format("[server] bolt #%d %s", self.projectileId or -1, text))
        end
    end

    function VTPlasmaBolt:ProcessHit(targetHit, surface, normal, hitPoint)
        local owner = self:GetOwner()
        local direction = GetNormalizedVector(self:GetVelocity())
        if VT_HitDebugServer then
            local dist = owner and hitPoint and (hitPoint - owner:GetEyePos()):GetLength() or 0
            local health = targetHit and HasMixin(targetHit, "Live") and targetHit:GetHealth() or nil
            self.vtDebugHit = { name = DebugName(targetHit), dist = dist, health = health, target = targetHit }
        end
        if targetHit ~= owner then
            self:DoDamage(self.vtBaseDamage or kRifleDamage, targetHit, hitPoint, direction, surface or "metal", false, false)
            -- splash (Praetor): every other enemy in range, falloff to the edge, walls block
            local radius = self.vtSplashRadius or 0
            if radius > 0 then
                local victims = {}
                for _, e in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", GetEnemyTeamNumber(self:GetTeamNumber()), hitPoint, radius)) do
                    if e ~= targetHit then victims[#victims + 1] = e end
                end
                if #victims > 0 then
                    RadiusDamage(victims, hitPoint, radius, self.vtSplashDamage, self)
                end
            end
            SendImpact(self, owner, targetHit, hitPoint, direction, normal)
        end
        if VT_HitDebugServer and self.vtDebugHit then
            local h = self.vtDebugHit
            if h.health and h.target and HasMixin(h.target, "Live") then
                local after = h.target:GetIsAlive() and h.target:GetHealth() or 0
                DebugReport(self, string.format("HIT %s at %.1f m, health %.0f -> %.0f", h.name, h.dist, h.health, after))
            else
                DebugReport(self, string.format("hit %s at %.1f m", h.name, h.dist))
            end
        end
        DestroyEntity(self)
    end

    function VTPlasmaBolt:TimeUp()
        if VT_HitDebugServer then
            DebugReport(self, "expired without hitting anything")
        end
        DestroyEntity(self)
        return false
    end

end

Shared.LinkClassToMap("VTPlasmaBolt", VTPlasmaBolt.kMapName, boltNetworkVars)

-- ----------------------------------------------------------------------------
-- Plasma Carbine (Rifle): fires VTPlasmaBolt projectiles - 15% slower than the
-- marine rifle, 15% more damage per hit, visible blaster bolts. With the
-- Overcharge Core it fires slower, heavier bolts: shots inside
-- kVTOverchargeFireDelay are suppressed, each bolt that does fire hits for
-- kVTOverchargeDamageScalar x damage.
-- ----------------------------------------------------------------------------
class 'VTPlasmaCarbine' (Rifle)

VTPlasmaCarbine.kMapName = kVTMapNames.Carbine

local carbineNetworkVars =
{
    vtOvercharged = "boolean",
}

-- Models: "Falcon Rilfe" by pocolov (CC-BY-4.0, see CREDITS.txt), built by art/fab/falcon_rifle/build_falcon.sh.
-- World model via kTechDataModel (Hooks/TechData.lua); the view model keeps the vanilla rifle arms + animations.
kVTCarbineWorldModel = PrecacheAsset("models/vaelthor/falcon/falcon.model")
local kCarbineViewModel = PrecacheAsset("models/vaelthor/falcon/falcon_view.model")

function VTPlasmaCarbine:GetViewModelName(sex, variant)
    return kCarbineViewModel
end

function VTPlasmaCarbine:OnCreate()
    Rifle.OnCreate(self)      -- ClipWeapon.OnCreate fills clip/ammo from the overrides below
    self.vtOvercharged = false
    self.vtLastBoltTime = 0
    self.vtRechargeProgress = 0
end

-- ---- Energy cell: the clip *is* the energy, there is no reserve ------------
function VTPlasmaCarbine:GetClipSize()
    return kVTCarbineEnergy
end

function VTPlasmaCarbine:GetMaxClips()
    return 0
end

function VTPlasmaCarbine:CanReload()
    return false
end

function VTPlasmaCarbine:GetNeedsAmmo(includeClip)
    return false   -- no ammo packs / field magazine refills: energy recharges itself
end

-- Called every move by the owning soldier, so the cell also recharges while holstered.
-- Server-only: the clip is networked anyway, and predicting the recharge on the client (with a
-- non-networked progress counter and a field check that can briefly disagree) made the energy
-- counter jitter and snap back on every server update. Firing is still predicted as usual.
function VTPlasmaCarbine:VT_UpdateEnergy(player, deltaTime)

    if not Server then
        return
    end

    -- Rifle skins would override the Falcon's material slots with rifle textures: keep the default.
    if self.rifleVariant ~= nil and self.rifleVariant ~= kDefaultRifleVariant then
        self.rifleVariant = kDefaultRifleVariant
    end

    if self.clip >= kVTCarbineEnergy then
        self.vtRechargeProgress = 0
        return
    end

    local sinceShot = Shared.GetTime() - (self.timeAttackFired or 0)
    if sinceShot < kVTCarbineRechargeDelay or not VT_GetIsPointInField(player:GetOrigin()) then
        self.vtRechargeProgress = 0
        return
    end

    self.vtRechargeProgress = (self.vtRechargeProgress or 0) + deltaTime * kVTCarbineRechargeRate
    local rounds = math.floor(self.vtRechargeProgress)
    if rounds > 0 then
        self.clip = math.min(kVTCarbineEnergy, self.clip + rounds)
        self.vtRechargeProgress = self.vtRechargeProgress - rounds
    end

end

function VTPlasmaCarbine:SetVTOvercharged(overcharged)
    self.vtOvercharged = overcharged == true
end

function VTPlasmaCarbine:GetVTDamageScalar(target)
    return self.vtOvercharged and kVTOverchargeDamageScalar or kVTCarbineDamageScalar
end

-- Rate of fire: the rifle fires on the "shoot" tags of its fire animation, so it is slowed through the
-- animation speed (the same input the Catalyst Pack speeds up; cat packs still stack on top).
function VTPlasmaCarbine:GetCatalystSpeedBase()
    return kVTCarbineFireRateScalar
end

-- Overcharge Core: heavy bolts at most every kVTOverchargeFireDelay. Gated here (not in FirePrimary) so a
-- suppressed shot costs no energy.
function VTPlasmaCarbine:GetIsAllowedToShoot(player)
    if not Rifle.GetIsAllowedToShoot(self, player) then
        return false
    end
    return not self.vtOvercharged or Shared.GetTime() - (self.timeAttackFired or 0) >= kVTOverchargeFireDelay
end

local kBoltSound = PrecacheAsset("sound/NS2.fev/marine/heavy/railgun_quick_fire")

function VTPlasmaCarbine:GetSpread()
    return Rifle.GetSpread(self) * kVTCarbineSpreadScalar
end

-- Plasma bolt instead of hitscan bullets: aim from the eye (spread as the rifle), launch from the gun.
function VTPlasmaCarbine:FirePrimary(player)

    self.fireTime = Shared.GetTime()

    local viewCoords = player:GetViewAngles():GetCoords()
    local eyePos = player:GetEyePos()
    local direction = self:CalculateSpreadDirection(viewCoords, player)
    local filter = EntityFilterTwo(player, self)

    -- aim point: what the crosshair (plus spread) is on
    local aimTrace = Shared.TraceRay(eyePos, eyePos + direction * 150, CollisionRep.Damage, PhysicsMask.Bullets, filter)
    local aimPoint = aimTrace.endPoint

    -- muzzle: right of and below the eye (same convention as the HMG barrel point), kept out of walls
    local muzzle = eyePos + viewCoords.zAxis * 0.55 - viewCoords.xAxis * 0.13 - viewCoords.yAxis * 0.16
    local muzzleTrace = Shared.TraceRay(eyePos, muzzle, CollisionRep.Damage, PhysicsMask.Bullets, filter)
    local startPoint = muzzleTrace.fraction < 1 and eyePos or muzzle

    local toAim = aimPoint - startPoint
    local boltDir = toAim:GetLengthSquared() > 1 and GetNormalizedVector(toAim) or direction

    local bolt = player:CreatePredictedProjectile("VTPlasmaBolt", startPoint, boltDir * kVTCarbineBoltSpeed, 0, 0, 0)
    if bolt then   -- server entity
        bolt.vtDamageScalar = self:GetVTDamageScalar()
    end

    StartSoundEffectOnEntity(kBoltSound, player, 0.6, player)

end

-- No machine-gun loop, orange muzzle flash or brass casings: each bolt brings its own sound and light.
if Client then
    function VTPlasmaCarbine:OnClientPrimaryAttackStart()
    end
    function VTPlasmaCarbine:OnClientPrimaryAttacking(deltaTime)
    end
    function VTPlasmaCarbine:OnClientPrimaryAttackEnd()
    end
end

-- Third-person animation: the marine animation graph only knows vanilla weapon names.
function VTPlasmaCarbine:OverrideWeaponName()
    return "rifle"
end

InstallFastDraw(VTPlasmaCarbine)

Shared.LinkClassToMap("VTPlasmaCarbine", VTPlasmaCarbine.kMapName, carbineNetworkVars)

-- ----------------------------------------------------------------------------
-- Psionic Blade (Axe). Right-click releases the Infiltrator's hack pulse.
-- ----------------------------------------------------------------------------
class 'VTPsionicBlade' (Axe)

VTPsionicBlade.kMapName = kVTMapNames.Blade

-- Dual wrist-mounted psionic blades (Zealot style), art/weapons/build_psi_blades.sh:
--   first person: vanilla axe arms + animations with a blade on each wrist (blades_view.model)
--   third person: the blades are part of cyber_player.model (face set 1), shown by Client.lua while this
--                 weapon is active; the weapon's own world model is an invisible stub.
local kBladesNullModel = PrecacheAsset("models/vaelthor/blades/blades_null.model")
local kBladesViewModel = PrecacheAsset("models/vaelthor/blades/blades_view.model")

function VTPsionicBlade:OnInitialized()
    Axe.OnInitialized(self)
    self:SetModel(kBladesNullModel)
end

function VTPsionicBlade:GetViewModelName(sex, variant)
    return kBladesViewModel
end

-- The Infiltrator's main weapon.
function VTPsionicBlade:GetHUDSlot()
    return kPrimaryWeaponSlot
end

function VTPsionicBlade:GetIsDroppable()
    return false
end

-- Axe skins must not override the blade materials (see Hooks/Cosmetics.lua too).
function VTPsionicBlade:ProcessMoveOnWeapon(player, input)
    Axe.ProcessMoveOnWeapon(self, player, input)
    if Server and self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
        self.axeVariant = kDefaultAxeVariant
    end
end

if Client then
    function VTPsionicBlade:OnUpdateRender()
        if self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
            self.axeVariant = kDefaultAxeVariant
            self.dirtySkinState = true
        end
        Axe.OnUpdateRender(self)
    end
end

function VTPsionicBlade:GetVTDamageScalar(target)
    return kVTBladeDamage / kAxeDamage
end

function VTPsionicBlade:GetHasSecondary(player)
    return true
end

function VTPsionicBlade:OnSecondaryAttack(player)
    if not self.vtSecondaryHeld then
        self.vtSecondaryHeld = true
        if Server and player and player.VT_TriggerHack then
            player:VT_TriggerHack()
        end
    end
end

function VTPsionicBlade:OnSecondaryAttackEnd(player)
    self.vtSecondaryHeld = false
end

-- Third-person animation: the marine animation graph only knows vanilla weapon names.
function VTPsionicBlade:OverrideWeaponName()
    return "axe"
end

Shared.LinkClassToMap("VTPsionicBlade", VTPsionicBlade.kMapName, {})

-- ----------------------------------------------------------------------------
-- Psionic Knife (Axe): the Vanguard's melee weapon. Axe swing, range and damage;
-- procedural knife model with a glowing psionic edge (art/weapons/build_knife.sh),
-- world model via kTechDataModel, view model = vanilla axe arms + animations.
-- ----------------------------------------------------------------------------
class 'VTPsionicKnife' (Axe)

VTPsionicKnife.kMapName = kVTMapNames.Knife

local kKnifeWorldModel = PrecacheAsset("models/vaelthor/knife/knife.model")
local kKnifeViewModel  = PrecacheAsset("models/vaelthor/knife/knife_view.model")

function VTPsionicKnife:OnInitialized()
    Axe.OnInitialized(self)            -- sets the vanilla axe model
    self:SetModel(kKnifeWorldModel)
end

function VTPsionicKnife:GetViewModelName(sex, variant)
    return kKnifeViewModel
end

function VTPsionicKnife:GetIsDroppable()
    return false
end

-- Structure breaker: extra damage against structures only (see kVTKnifeStructureDamageScalar).
function VTPsionicKnife:GetVTDamageScalar(target)
    if target and target.GetReceivesStructuralDamage and target:GetReceivesStructuralDamage(kAxeDamageType) then
        return kVTKnifeStructureDamageScalar
    end
    return 1
end

-- Axe skins would override the knife's material slots: keep the default.
function VTPsionicKnife:ProcessMoveOnWeapon(player, input)
    Axe.ProcessMoveOnWeapon(self, player, input)
    if Server and self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
        self.axeVariant = kDefaultAxeVariant
    end
end

-- Client side too: with the default variant AxeVariantMixin removes overrides instead of applying a skin.
if Client then
    function VTPsionicKnife:OnUpdateRender()
        if self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
            self.axeVariant = kDefaultAxeVariant
            self.dirtySkinState = true
        end
        Axe.OnUpdateRender(self)
    end
end

-- Third-person animation: the marine animation graph only knows vanilla weapon names.
function VTPsionicKnife:OverrideWeaponName()
    return "axe"
end

InstallFastDraw(VTPsionicKnife)

Shared.LinkClassToMap("VTPsionicKnife", VTPsionicKnife.kMapName, {})

-- ----------------------------------------------------------------------------
-- Bio-Construct Claws (Axe) for the Subject: longer reach, heavy damage.
-- ----------------------------------------------------------------------------
class 'VTSubjectClaws' (Axe)

VTSubjectClaws.kMapName = kVTMapNames.Claws

function VTSubjectClaws:GetVTDamageScalar(target)
    return kVTClawsDamage / kAxeDamage
end

function VTSubjectClaws:GetRange()
    return kVTClawsRange
end

function VTSubjectClaws:GetIsDroppable()
    return false
end

-- Claws: knuckle plate + three curved claws per hand (art/weapons/build_subject_claws.sh).
-- First person: vanilla axe arms/animations with claws on both wrists; third person: face set 1 of
-- mecha_player.model, shown by Client.lua; the weapon's own world model is the invisible blade stub.
local kClawsViewModel = PrecacheAsset("models/vaelthor/claws/claws_view.model")
local kClawsNullModel = PrecacheAsset("models/vaelthor/blades/blades_null.model")

function VTSubjectClaws:OnInitialized()
    Axe.OnInitialized(self)
    self:SetModel(kClawsNullModel)
end

function VTSubjectClaws:GetViewModelName(sex, variant)
    return kClawsViewModel
end

function VTSubjectClaws:ProcessMoveOnWeapon(player, input)
    Axe.ProcessMoveOnWeapon(self, player, input)
    if Server and self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
        self.axeVariant = kDefaultAxeVariant
    end
end

if Client then
    function VTSubjectClaws:OnUpdateRender()
        if self.axeVariant ~= nil and self.axeVariant ~= kDefaultAxeVariant then
            self.axeVariant = kDefaultAxeVariant
            self.dirtySkinState = true
        end
        Axe.OnUpdateRender(self)
    end
end

-- Third-person animation: the marine animation graph only knows vanilla weapon names.
function VTSubjectClaws:OverrideWeaponName()
    return "axe"
end

Shared.LinkClassToMap("VTSubjectClaws", VTSubjectClaws.kMapName, {})

-- ----------------------------------------------------------------------------
-- Singularity bolt: a mini gravity anomaly. Slows (electrifies) enemy players
-- in range and pulls light units toward its centre.
-- ----------------------------------------------------------------------------
class 'VTSingularityBolt' (Grenade)

VTSingularityBolt.kMapName = kVTMapNames.SingularityBolt
-- PredictedProjectile reads these statics through _G[className].
VTSingularityBolt.kModelName         = Grenade.kModelName
VTSingularityBolt.kRadius            = Grenade.kRadius
VTSingularityBolt.kDetonateRadius    = Grenade.kDetonateRadius
VTSingularityBolt.kMinLifeTime       = Grenade.kMinLifeTime
VTSingularityBolt.kClearOnImpact     = Grenade.kClearOnImpact
VTSingularityBolt.kClearOnEnemyImpact= Grenade.kClearOnEnemyImpact
VTSingularityBolt.kNeedsHitEntity    = Grenade.kNeedsHitEntity
VTSingularityBolt.kMinVelocityToMove = Grenade.kMinVelocityToMove

function VTSingularityBolt:GetWeaponTechId()
    return kTechId.VTSingularityLauncher
end

if Server then

    function VTSingularityBolt:Detonate(targetHit)

        local origin = self:GetOrigin()
        local enemyTeam = GetEnemyTeamNumber(self:GetTeamNumber())

        for _, target in ipairs(GetEntitiesForTeamWithinRange("Player", enemyTeam, origin, kVTSingularityRadius)) do

            if target:GetIsAlive() then

                local toTarget = target:GetOrigin() - origin
                self:DoDamage(kVTSingularityDamage, target, target:GetOrigin(), GetNormalizedVector(toTarget), "none")

                if target.SetElectrified then
                    target:SetElectrified(kVTSingularitySlowDuration)
                end

                if target.GetMass and target:GetMass() <= kVTSingularityPullMaxMass
                        and target.GetVelocity and target.SetVelocity and toTarget:GetLength() > 0.5 then
                    local pull = GetNormalizedVector(-toTarget) * kVTSingularityPull + Vector(0, 1.5, 0)
                    target:SetVelocity(target:GetVelocity() + pull)
                end

            end

        end

        local params = { surface = GetSurfaceFromEntity(targetHit) }
        params[kEffectHostCoords] = Coords.GetLookIn(origin, self:GetCoords().zAxis)
        self:TriggerEffects("pulse_grenade_explode", params)

        DestroyEntity(self)

    end

end

Shared.LinkClassToMap("VTSingularityBolt", VTSingularityBolt.kMapName, {})

-- ----------------------------------------------------------------------------
-- Singularity Launcher (Grenade Launcher) firing singularity bolts.
-- ----------------------------------------------------------------------------
class 'VTSingularityLauncher' (GrenadeLauncher)

VTSingularityLauncher.kMapName = kVTMapNames.Singularity

-- Fixed first-person model: the vanilla grenade launcher view with the Vanguard's own arms
-- (art/weapons/build_vanguard_view_arms.sh). Also avoids the skin lookup kViewModels[sex][variant], which
-- misses for robotic marine skins because the castes force the default variant server-side.
local kSingularityViewModel = PrecacheAsset("models/vaelthor/singularity/singularity_view.model")

function VTSingularityLauncher:GetViewModelName(sex, variant)
    return kSingularityViewModel
end

function VTSingularityLauncher:ShootGrenade(player)

    self:TriggerEffects("grenadelauncher_attack")

    if Server or (Client and Client.GetIsControllingPlayer()) then

        local viewCoords = player:GetViewCoords()
        local eyePos = player:GetEyePos()
        local floorAim = 1 - math.min(viewCoords.zAxis.y, 0)

        local startPointTrace = Shared.TraceCapsule(eyePos, eyePos + viewCoords.zAxis * floorAim * GrenadeLauncher.kLauncherBarrelDist,
                VTSingularityBolt.kRadius + 0.0001, 0, CollisionRep.Move, PhysicsMask.PredictedProjectileGroup, EntityFilterTwo(self, player))

        player:CreatePredictedProjectile("VTSingularityBolt", startPointTrace.endPoint, viewCoords.zAxis * GrenadeLauncher.kGrenadeSpeed,
                GrenadeLauncher.kGrenadeBounce, GrenadeLauncher.kGrenadeFriction, nil, PhysicsMask.GLGrenadeGroup)

    end

end

function VTSingularityLauncher:GetIsAffectedByWeaponUpgrades()
    return false
end

-- Occupies the sidearm slot so it can be carried next to the Plasma Carbine.
function VTSingularityLauncher:GetHUDSlot()
    return kSecondaryWeaponSlot
end

-- Third-person animation: the marine animation graph only knows vanilla weapon names.
function VTSingularityLauncher:OverrideWeaponName()
    return "grenadelauncher"
end

InstallFastDraw(VTSingularityLauncher)

Shared.LinkClassToMap("VTSingularityLauncher", VTSingularityLauncher.kMapName, {})

-- ----------------------------------------------------------------------------
-- Echo Scan (Builder tablet), Infiltrator weapon slot 2. Hold fire to scan: the
-- owner's networked vtEchoScanning flag (set in VTInfiltrator:OnProcessMove)
-- makes every Vael'Thor client outline the enemy players, structures and eggs
-- inside the cone through walls (Client.lua, UpdateEchoScan); after release
-- they fade out over kVTEchoScanFadeTime. Replaces the marine commander scan.
-- ----------------------------------------------------------------------------
class 'VTEchoPulse' (Builder)

VTEchoPulse.kMapName = kVTMapNames.EchoPulse

local kEchoScanStartSound = PrecacheAsset("sound/NS2.fev/marine/commander/scan")

-- Fixed view model, like every other Vael'Thor weapon. Builder looks it up as kViewModels[marineType][variant];
-- the castes force variant = default server-side, so a robotic (BMAC) marine type resolved bigmac[default] = nil
-- there while the client predicted a real model -> server and predict VM disagreed on the model and the client
-- logged "welder_view.animation_graph ... no node found for 16 in layer 1" every update while the scanner was out.
local kEchoPulseViewModel = PrecacheAsset("models/marine/welder/welder_view.model")

function VTEchoPulse:GetViewModelName(sex, variant)
    return kEchoPulseViewModel
end

function VTEchoPulse:GetHUDSlot()
    return kSecondaryWeaponSlot   -- 2 (the Infiltrator carries no pistol)
end

function VTEchoPulse:GetIsDroppable()
    return false
end

local function GetIsScanning(weapon)
    local owner = weapon:GetParent()
    return owner ~= nil and owner.vtEchoScanning == true
end

-- Builder hum (marine/welder/scan) only while scanning; audible to everyone near.
function VTEchoPulse:ProcessMoveOnWeapon(player, input)
    Weapon.ProcessMoveOnWeapon(self, player, input)
    if Server then
        local playing = self.loopingFireSound:GetIsPlaying()
        local scanning = player.vtEchoScanning == true
        if scanning and not playing then
            self.loopingFireSound:Start()
        elseif not scanning and playing then
            self.loopingFireSound:Stop()
        end
    end
end

-- Scan ping on press. Scanning gives the Infiltrator away, like hacking does.
function VTEchoPulse:OnEchoScanStart(player)
    StartSoundEffectOnEntity(kEchoScanStartSound, player)
    if player.vtAbilityActiveEnd and player.VT_GetAbilityActive and player:VT_GetAbilityActive() then
        player.vtAbilityActiveEnd = Shared.GetTime()
    end
    if player.TriggerUncloak then
        player:TriggerUncloak()
    end
end

function VTEchoPulse:OnPrimaryAttack(player)
    -- Held fire is read from the move in VTInfiltrator:OnProcessMove; keep the
    -- Infiltrator uncloaked for as long as it lasts.
    if Server and player.TriggerUncloak then
        player:TriggerUncloak()
    end
end

function VTEchoPulse:OnDrawClient()
    Weapon.OnDrawClient(self)
    self.playEffect = false
end

-- Tablet scan beam while scanning (owner flag is networked, so this works in
-- the render VM and for other players' third-person view too).
function VTEchoPulse:OnUpdateRender()
    self.playEffect = self:GetIsActive() and GetIsScanning(self)
    Builder.OnUpdateRender(self)
end

-- for marine thirdperson pose: the builder pose (tablet held up)
function VTEchoPulse:OverrideWeaponName()
    return "builder"
end

Shared.LinkClassToMap("VTEchoPulse", VTEchoPulse.kMapName, {})

-- ----------------------------------------------------------------------------
-- Praetor plasma minigun (Minigun): the carbine's blaster rules on the exo guns.
-- Each l_shoot / r_shoot animation tag earns kVTPraetorFireRateScalar / kVTPraetorBoltBatch fire credit;
-- a full credit launches one VTPlasmaBolt worth kVTPraetorBoltBatch minigun bullets x kVTPraetorBoltDamageScalar
-- (Heavy damage, like the minigun). DPS = vanilla x 0.85 x 1.15 with a third of the projectiles.
-- Spin-up, heat and overheat stay vanilla (heat follows self.shooting). No orange muzzle flash, no shells.
-- ----------------------------------------------------------------------------
class 'VTPlasmaMinigun' (Minigun)

VTPlasmaMinigun.kMapName = "vt_plasmaminigun"

local kMinigunBoltSound = PrecacheAsset("sound/NS2.fev/marine/heavy/railgun_quick_fire")

-- Same barrel point on server and predicting client (vanilla's differs for the local player).
local function GetBoltStart(self, player)
    local eye = player:GetEyePos()
    local view = player:GetViewCoords()
    local side = self:GetIsLeftSlot() and 1 or -1
    return eye + view.zAxis * 0.9 + view.xAxis * (0.45 * side) + view.yAxis * -0.17
end

local function FireBolt(self, player)

    self.shooting = true             -- (no gatling spin loop: the bolts carry their own sound)

    self.vtFireCredit = (self.vtFireCredit or 0) + kVTPraetorFireRateScalar / kVTPraetorBoltBatch
    if self.vtFireCredit < 1 then
        return
    end
    self.vtFireCredit = self.vtFireCredit - 1

    -- Shared Praetor energy pool (VTPraetor:VT_UpdateEnergy recharges it). Server-authoritative: the client
    -- only reads the networked value to stop firing when empty. Spending it in client prediction too made the
    -- HUD sawtooth (each server update reset vtEnergy, and replayed moves don't re-fire the animation tags).
    if player.vtEnergy then
        if player.vtEnergy < kVTPraetorEnergyPerBolt then
            self.vtFireCredit = 0
            return
        end
        if Server then
            player.vtEnergy = player.vtEnergy - kVTPraetorEnergyPerBolt
            player.vtLastBoltTime = Shared.GetTime()
        end
    end

    local view = player:GetViewAngles():GetCoords()
    local eyePos = player:GetEyePos()
    local direction = CalculateSpread(view, Math.Radians(kVTPraetorSpread), NetworkRandom)
    local filter = EntityFilterTwo(player, self)
    local aim = Shared.TraceRay(eyePos, eyePos + direction * 150, CollisionRep.Damage, PhysicsMask.Bullets, filter).endPoint

    local start = GetBoltStart(self, player)
    if Shared.TraceRay(eyePos, start, CollisionRep.Damage, PhysicsMask.Bullets, filter).fraction < 1 then
        start = eyePos
    end
    local toAim = aim - start
    local boltDir = toAim:GetLengthSquared() > 1 and GetNormalizedVector(toAim) or direction

    local bolt = player:CreatePredictedProjectile("VTPlasmaBolt", start, boltDir * kVTCarbineBoltSpeed, 0, 0, 0)
    if bolt then   -- server entity
        bolt.vtBaseDamage = kMinigunDamage * kVTPraetorBoltBatch
        bolt.vtDamageScalar = kVTPraetorBoltDamageScalar
        bolt.vtDamageType = kMinigunDamageType
        bolt.vtWeaponTechId = kTechId.Minigun
        bolt.vtDeathIcon = kDeathMessageIcon.Minigun
        bolt.vtSplashRadius = kVTPraetorSplashRadius
        bolt.vtSplashDamage = kMinigunDamage * kVTPraetorBoltBatch * kVTPraetorSplashDamage
    end

    StartSoundEffectOnEntity(kMinigunBoltSound, player, 0.35, player)

end

-- Only the shoot tags matter: the vanilla spin-up/spin-down sounds and the overheat tags are dropped.
function VTPlasmaMinigun:OnTag(tagName)
    local isShootTag = (self:GetIsLeftSlot() and tagName == "l_shoot") or (not self:GetIsLeftSlot() and tagName == "r_shoot")
    if isShootTag then
        local player = self:GetParent()
        if self.minigunAttacking and player then
            FireBolt(self, player)
        end
    end
end

-- No gatling tail sound / spin loop to stop.
function VTPlasmaMinigun:OnPrimaryAttackEnd(player)
    self.vtFireCredit = 0
    self.shooting = false
    self.minigunAttacking = false
end

-- No overheating: heat stays at 0 (the heat UI just reads 0).
function VTPlasmaMinigun:ProcessMoveOnWeapon(player, input)
    self.heatAmount = 0
    self.overheated = false
end

if Client then
    -- no orange muzzle flashes: the bolts bring their own purple light
    function VTPlasmaMinigun:OnClientPrimaryAttacking()
    end
    -- no brass casings
    function VTPlasmaMinigun:OnUpdateRender()
        Minigun.OnUpdateRender(self)
        if self.shellsCinematic then
            self.shellsCinematic:SetIsActive(false)
        end
    end
end

Shared.LinkClassToMap("VTPlasmaMinigun", VTPlasmaMinigun.kMapName, {})
