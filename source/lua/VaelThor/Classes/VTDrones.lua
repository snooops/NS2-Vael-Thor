-- ============================================================================
-- VTDrone - the Artificer's combat drones (CONCEPT 2026-11-17, see VTArtificer in Classes/VTPlayers.lua).
--
-- One entity class, three types (kVTDroneTypes in Hooks/Globals.lua, networked vtDroneType):
--   1 Wasp   - fast, fragile, short beam; default directive Hunt
--   2 Lancer - slow, long beam from a high standoff; default directive Escort
--   3 Sapper - armoured bomb: flies into its target and detonates (Structural: double vs structures);
--              also bursts (half damage) when shot down
--
-- Server-driven like the homing missile (not predicted): every tick the drone picks a target from its owner's
-- directive for its type (Escort / Hunt / Siege / Focus, Swarm Command overrides to the mark), flies to an attack
-- position (straight when the way is clear, else along navmesh path points, sliding along walls) and fires.
-- Clients see the networked position; they draw the model (bob + bank), a small light and the beam (Obelisk beam
-- strips, VT_BeamFx). Enemies hit drones through a kinematic sphere body in the Babbler physics group (like the
-- Babbler hitbox: bullets and melee hit it, player movement and own predicted plasma bolts pass through).
-- Drones self-destruct when their Artificer dies or is gone.
-- ============================================================================
Script.Load("lua/Mixins/BaseModelMixin.lua")
Script.Load("lua/Mixins/ClientModelMixin.lua")

class 'VTDrone' (ScriptActor)

VTDrone.kMapName = kVTMapNames.Drone

for _, spec in ipairs(kVTDroneTypes) do
    spec.modelIndex = PrecacheAsset(spec.model)
end
local kExplodeSound = PrecacheAsset("sound/vaelthor.fev/missile/explode")

local kThinkInterval   = 0.25    -- s between target choices
local kPathInterval    = 0.6     -- s between navmesh path queries
local kDamageTick      = 0.1     -- s between beam damage ticks
local kEscortHeight    = 2.6     -- m above the Artificer's feet
local kEscortRadius    = 1.7     -- m (Lancers ride an outer ring)
local kSeparation      = 1.1     -- m: drones push apart closer than this
local kTurnRate        = 8       -- 1/s facing blend

local kTypeColors =
{
    Color(1.00, 0.55, 0.95),     -- Wasp: pink
    Color(0.62, 0.48, 1.00),     -- Lancer: violet
    Color(1.00, 0.62, 0.35),     -- Sapper: amber
}
VT_DroneTypeColors = kTypeColors

local networkVars =
{
    vtDroneType     = string.format("integer (1 to %d)", kVTDroneTypeCount),
    vtOwnerId       = "entityid",
    vtBeamTargetId  = "entityid",
    vtSlot          = string.format("integer (0 to %d)", kVTArtificerMaxDrones),
}
AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ClientModelMixin, networkVars)
AddMixinNetworkVars(TeamMixin, networkVars)
AddMixinNetworkVars(LiveMixin, networkVars)

function VTDrone:OnCreate()
    ScriptActor.OnCreate(self)
    -- moving entity: every tick on the server, every frame on clients (ScriptActor default is 0.25 s / 0.1 s)
    self:SetUpdates(true, kRealTimeUpdateRate)
    InitMixin(self, BaseModelMixin)
    InitMixin(self, ClientModelMixin)
    InitMixin(self, TeamMixin)
    InitMixin(self, LiveMixin)
    InitMixin(self, DamageMixin)
    self.vtDroneType = 1
    self.vtOwnerId = Entity.invalidId
    self.vtBeamTargetId = Entity.invalidId
    self.vtSlot = 0
    self.vtVelocity = Vector(0, 0, 0)
    self.vtTargetId = Entity.invalidId
    self.vtNextThink = 0
    self.vtNextPath = 0
    self.vtNextDamage = 0
    self.vtBeamDamage = 0
end

function VTDrone:VT_GetSpec()
    return kVTDroneTypes[self.vtDroneType] or kVTDroneTypes[1]
end

local function CreateHitBox(self)
    if self.vtHitBox then return end
    local spec = self:VT_GetSpec()
    self.vtHitBox = Shared.CreatePhysicsSphereBody(false, spec.radius, 0, self:GetCoords())
    self.vtHitBox:SetGroup(PhysicsGroup.BabblerGroup)
    self.vtHitBox:SetEntity(self)
    self.vtHitBox:SetPhysicsType(CollisionObject.Kinematic)
    self.vtHitBox:SetTriggeringEnabled(true)
end

local function DestroyHitBox(self)
    if self.vtHitBox then
        Shared.DestroyCollisionObject(self.vtHitBox)
        self.vtHitBox = nil
    end
end

function VTDrone:OnInitialized()
    ScriptActor.OnInitialized(self)
    if Client then
        -- the type is networked with the first state
        self:SetModel(self:VT_GetSpec().model)
        CreateHitBox(self)
        local light = Client.CreateRenderLight()
        light:SetType(RenderLight.Type_Point)
        light:SetCastsShadows(false)
        light:SetSpecular(false)
        light:SetColor(kTypeColors[self.vtDroneType] or kTypeColors[1])
        light:SetRadius(2.2)
        light:SetIntensity(3)
        light:SetCoords(Coords.GetTranslation(self:GetOrigin()))
        self.vtLight = light
        self.vtClientSpawn = Shared.GetTime()
    end
end

function VTDrone:OnDestroy()
    DestroyHitBox(self)
    if Client then
        if self.vtLight then
            Client.DestroyRenderLight(self.vtLight)
            self.vtLight = nil
        end
        if self.vtBeamFx and VT_BeamFx then
            VT_BeamFx.Destroy(self.vtBeamFx)
            self.vtBeamFx = nil
        end
    end
    ScriptActor.OnDestroy(self)
end

-- ---- damage doer (beams, Sapper blast) ------------------------------------------------------------------------
function VTDrone:GetVTDamageScalar(target)
    return 1
end

function VTDrone:GetDamageType()
    return kDamageType[self:VT_GetSpec().damageType] or kDamageType.Normal
end

function VTDrone:GetIsAffectedByWeaponUpgrades()
    return true          -- Plasma Calibration I-III
end

function VTDrone:GetWeaponTechId()
    return kTechId.Minigun
end

function VTDrone:GetDeathIconIndex()
    return kDeathMessageIcon.Minigun
end

-- ---- as a target ------------------------------------------------------------------------------------------------
function VTDrone:GetDestroyOnKill()
    return true
end

function VTDrone:GetSendDeathMessageOverride()
    return false
end

-- armed: alien structures that prefer attackers (Hydra / Whip target cache) treat drones as threats
function VTDrone:GetCanGiveDamageOverride()
    return true
end

function VTDrone:GetCanBeHealed()
    return false
end

function VTDrone:GetEngagementPoint()
    return self:GetOrigin()
end

function VTDrone:GetCanBeUsed(player, useSuccessTable)
    useSuccessTable.useSuccess = false
end

if Client then

    -- hover bob + bank into the turn (render only)
    function VTDrone:OnAdjustModelCoords(coords)
        local t = Shared.GetTime() + self:GetId() * 0.37
        local bob = 0.05 * math.sin(t * 2.6)
        local roll = 0.12 * math.sin(t * 1.3)
        local c, s = math.cos(roll), math.sin(roll)
        local out = Coords.GetIdentity()
        out.origin = coords.origin + coords.yAxis * bob
        out.xAxis = coords.xAxis * c + coords.yAxis * s
        out.yAxis = coords.yAxis * c - coords.xAxis * s
        out.zAxis = coords.zAxis
        -- launch: grow out of the bay over 0.4 s
        local age = Shared.GetTime() - (self.vtClientSpawn or 0)
        if age < 0.4 then
            local k = 0.3 + 0.7 * age / 0.4
            out.xAxis = out.xAxis * k
            out.yAxis = out.yAxis * k
            out.zAxis = out.zAxis * k
        end
        return out
    end

    local kBeamOffset = 0.3      -- beam starts this far in front of the drone's centre

    function VTDrone:OnUpdateRender()
        local origin = self:GetOrigin()
        if self.vtHitBox then
            self.vtHitBox:SetCoords(self:GetCoords())
        end
        local spec = self:VT_GetSpec()
        local targetId = self.vtBeamTargetId
        local target = self:GetIsAlive() and targetId ~= Entity.invalidId and Shared.GetEntity(targetId) or nil
        if target and not target.GetEngagementPoint then target = nil end
        if self.vtLight then
            local pulse = 0.85 + 0.15 * math.sin(Shared.GetTime() * 9 + self:GetId())
            self.vtLight:SetCoords(Coords.GetTranslation(origin))
            self.vtLight:SetIntensity((target and 6 or 3) * pulse)
        end
        if not VT_BeamFx then return end
        if target then
            self.vtBeamFx = self.vtBeamFx or VT_BeamFx.Create()
            local player = Client.GetLocalPlayer()
            local camera = player and player.GetCameraViewCoords and player:GetCameraViewCoords()
            local endPoint = VT_BeamFx.GetEndPoint(target, player, camera)
            local start = origin + GetNormalizedVector(endPoint - origin) * kBeamOffset
            VT_BeamFx.Update(self.vtBeamFx, start, endPoint, self:GetId(), camera and camera.origin or origin,
                    spec.beamWidth or 0.4)
        elseif self.vtBeamFx then
            VT_BeamFx.SetVisible(self.vtBeamFx, false)
        end
    end

end

if Server then

    -- owner, type index, escort slot
    function VTDrone:VT_Setup(owner, droneType, slot)
        self.vtDroneType = droneType
        self.vtSlot = slot or 0
        self.vtOwnerId = owner:GetId()
        self:SetOwner(owner)
        local spec = self:VT_GetSpec()
        self:SetModel(spec.model)
        self:SetMaxHealth(spec.health)
        self:SetHealth(spec.health)
        self:SetMaxArmor(0)
        self:SetArmor(0)
        local forward = owner:GetViewCoords().zAxis
        self.vtVelocity = Vector(forward.x, 0, forward.z) * 2 + Vector(0, 2, 0)
        self.vtFacing = GetNormalizedVector(Vector(forward.x, 0, forward.z))
        CreateHitBox(self)
    end

    local function GetOwnerArtificer(self)
        local owner = Shared.GetEntity(self.vtOwnerId)
        if owner and owner:isa("VTArtificer") and owner:GetIsAlive() then
            return owner
        end
        return nil
    end

    local function IsValidTarget(self, entity, enemyTeam)
        if not entity or not HasMixin(entity, "Live") or not entity:GetIsAlive() or not entity:GetCanTakeDamage() then
            return false
        end
        if not HasMixin(entity, "Team") or entity:GetTeamNumber() ~= enemyTeam then
            return false
        end
        if HasMixin(entity, "Cloakable") and entity:GetIsCloaked() then
            return false
        end
        return true
    end

    local function IsStructure(entity)
        return entity.GetReceivesStructuralDamage and entity:GetReceivesStructuralDamage() or false
    end

    -- nearest valid enemy (to `from`) within radius of `center` passing `accept`
    local function FindNearest(self, center, radius, from, enemyTeam, accept)
        local best, bestDist
        for _, entity in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, center, radius)) do
            if IsValidTarget(self, entity, enemyTeam) and (not accept or accept(entity)) then
                local d = (entity:GetOrigin() - from):GetLengthSquared()
                if not bestDist or d < bestDist then
                    best, bestDist = entity, d
                end
            end
        end
        return best
    end

    local function IsPlayerTarget(entity) return entity:isa("Player") end

    -- Escort: whatever threatens the Artificer (players first), nearest to the Artificer
    local function FindEscortTarget(self, owner, enemyTeam)
        local center = owner:GetOrigin()
        return FindNearest(self, center, kVTDroneEscortRadius, center, enemyTeam, IsPlayerTarget)
                or FindNearest(self, center, kVTDroneEscortRadius, center, enemyTeam, nil)
    end

    function VTDrone:VT_PickTarget(owner)
        local enemyTeam = GetEnemyTeamNumber(self:GetTeamNumber())
        local ownerOrigin = owner:GetOrigin()
        local mark = owner:VT_GetMark()
        if mark and (not IsValidTarget(self, mark, enemyTeam) or (mark:GetOrigin() - ownerOrigin):GetLength() > kVTArtificerLeash) then
            mark = nil
        end
        if mark and owner:VT_GetSwarmActive() then
            return mark                                   -- Swarm Command: everything at the mark
        end

        local directive = owner["vtDirective" .. self.vtDroneType] or kVTDroneDirective.Escort
        local current = Shared.GetEntity(self.vtTargetId)
        local currentValid = current and IsValidTarget(self, current, enemyTeam)
                and (current:GetOrigin() - ownerOrigin):GetLength() <= kVTArtificerLeash

        if directive == kVTDroneDirective.Focus then
            if mark then return mark end
        elseif directive == kVTDroneDirective.Hunt then
            if currentValid and current:isa("Player") then return current end
            local target = FindNearest(self, ownerOrigin, kVTDroneSeekRadius, self:GetOrigin(), enemyTeam, IsPlayerTarget)
            if target then return target end
        elseif directive == kVTDroneDirective.Siege then
            if currentValid and IsStructure(current) then return current end
            local target = FindNearest(self, ownerOrigin, kVTDroneSeekRadius, self:GetOrigin(), enemyTeam, IsStructure)
            if target then return target end
        end
        -- Escort, or nothing for the directive: guard the Artificer
        if currentValid and (current:GetOrigin() - ownerOrigin):GetLength() <= kVTDroneEscortRadius then
            return current
        end
        return FindEscortTarget(self, owner, enemyTeam)
    end

    local function GroundBelow(point)
        local trace = Shared.TraceRay(point, point - Vector(0, 8, 0), CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
        return trace.fraction < 1 and (trace.endPoint + Vector(0, 0.1, 0)) or point
    end

    local function IsClear(self, from, to)
        local spec = self:VT_GetSpec()
        local trace = Shared.TraceCapsule(from, to, spec.radius * 0.8, 0, CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
        return trace.fraction >= 1
    end

    -- next point to fly to on the way to goal: the goal itself when the way is clear, else a navmesh path point
    function VTDrone:VT_GetWaypoint(goal)
        local origin = self:GetOrigin()
        if IsClear(self, origin, goal) then
            self.vtPath = nil
            return goal
        end
        local now = Shared.GetTime()
        -- time-boxed: an unreachable goal must not cost a path query every tick
        if now >= self.vtNextPath then
            self.vtNextPath = now + kPathInterval
            self.vtPathGoal = goal
            local points = PointArray()
            local reachable = Pathing.GetPathPoints(GroundBelow(origin), GroundBelow(goal), points)
            self.vtPath = nil
            if reachable and #points > 0 then
                local path = {}
                for i = 1, #points do
                    path[i] = points[i] + Vector(0, 1.3, 0)
                end
                self.vtPath, self.vtPathIndex = path, 1
            end
        end
        local path = self.vtPath
        if not path then
            return goal
        end
        -- skip points we reached or can already see past
        while self.vtPathIndex < #path do
            local p = path[self.vtPathIndex]
            local next = path[self.vtPathIndex + 1]
            if (p - origin):GetLengthXZ() < 1.0 or IsClear(self, origin, next) then
                self.vtPathIndex = self.vtPathIndex + 1
            else
                break
            end
        end
        return path[self.vtPathIndex]
    end

    -- escort ring around the Artificer: slot angle + slow orbit
    function VTDrone:VT_GetEscortPoint(owner)
        local spec = self:VT_GetSpec()
        local angle = self.vtSlot * (2 * math.pi / kVTArtificerMaxDrones) + Shared.GetTime() * 0.35
        local radius = kEscortRadius + (self.vtDroneType == 2 and 0.8 or 0)
        local height = kEscortHeight + (self.vtDroneType - 1) * 0.25
        local center = owner:GetOrigin() + Vector(0, height, 0)
        local point = center + Vector(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local trace = Shared.TraceRay(center, point, CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
        if trace.fraction < 1 then
            point = center + (point - center) * math.max(0, trace.fraction - 0.2)
        end
        return point
    end

    -- where to hold while attacking: standoff distance from the target, above it, circling slowly
    function VTDrone:VT_GetAttackPoint(target)
        local spec = self:VT_GetSpec()
        local aim = target:GetEngagementPoint()
        if spec.standoff <= 0 then
            return aim                                      -- Sapper: ram it
        end
        local away = self:GetOrigin() - aim
        away.y = 0
        if away:GetLengthSquared() < 0.01 then away = Vector(1, 0, 0) end
        away:Normalize()
        local orbit = 0.35 * math.sin(Shared.GetTime() * 0.5 + self:GetId())
        local c, s = math.cos(orbit), math.sin(orbit)
        away = Vector(away.x * c - away.z * s, 0, away.x * s + away.z * c)
        local point = aim + away * spec.standoff + Vector(0, spec.hover, 0)
        local trace = Shared.TraceRay(aim, point, CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
        if trace.fraction < 1 then
            point = aim + (point - aim) * math.max(0, trace.fraction - 0.1)
        end
        return point
    end

    local function HasLineOfFire(self, from, target, point)
        local team = self:GetTeamNumber()
        local filter = function(test)
            return test == self or (HasMixin(test, "Team") and test:GetTeamNumber() == team)
        end
        local trace = Shared.TraceRay(from, point, CollisionRep.Damage, PhysicsMask.Bullets, filter)
        return trace.fraction >= 0.99 or trace.entity == target
    end

    -- Sapper blast (also its death burst at half strength)
    function VTDrone:VT_Detonate(scale)
        if self.vtDetonated then return end
        self.vtDetonated = true
        local spec = self:VT_GetSpec()
        local origin = self:GetOrigin()
        local enemyTeam = GetEnemyTeamNumber(self:GetTeamNumber())
        local victims = GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, origin, spec.blastRadius)
        if #victims > 0 then
            RadiusDamage(victims, origin, spec.blastRadius, spec.blastDamage * (scale or 1), self)
        end
        self.vtSplashEffect = true
        if VT_SendBoltImpact then
            VT_SendBoltImpact(self, self:GetOwner(), nil, origin, Vector(0, -1, 0), Vector(0, 1, 0))
        end
        StartSoundEffectAtOrigin(kExplodeSound, origin)
    end

    function VTDrone:OnKill(attacker, doer, point, direction)
        DestroyHitBox(self)
        self.vtBeamTargetId = Entity.invalidId
        if self.vtDroneType == 3 then
            self:VT_Detonate(0.5)
        else
            self.vtSplashEffect = false
            if VT_SendBoltImpact then
                VT_SendBoltImpact(self, self:GetOwner(), nil, self:GetOrigin(), Vector(0, -1, 0), Vector(0, 1, 0))
            end
        end
    end

    local function Fire(self, target, deltaTime)
        local spec = self:VT_GetSpec()
        local origin = self:GetOrigin()
        local aim = target:GetEngagementPoint()
        local distance = (aim - origin):GetLength()

        if spec.blastDamage then                            -- Sapper: contact fuse
            if distance <= spec.range then
                self:VT_Detonate(1)
                DestroyEntity(self)
                return true
            end
            return false
        end

        if distance > spec.range or not HasLineOfFire(self, origin, target, aim) then
            self.vtBeamTargetId = Entity.invalidId
            self.vtBeamDamage = 0
            return false
        end
        self.vtBeamTargetId = target:GetId()
        self.vtBeamDamage = self.vtBeamDamage + spec.dps * deltaTime
        local now = Shared.GetTime()
        if now >= self.vtNextDamage then
            self.vtNextDamage = now + kDamageTick
            self:DoDamage(self.vtBeamDamage, target, aim, GetNormalizedVector(aim - origin), "none", false, false)
            self.vtBeamDamage = 0
        end
        return false
    end

    local function FlyTo(self, goal, deltaTime, faceTarget)
        local spec = self:VT_GetSpec()
        local origin = self:GetOrigin()
        local waypoint = self:VT_GetWaypoint(goal)
        local toGoal = waypoint - origin
        local dist = toGoal:GetLength()
        -- slow down near the final goal only (path points are flown through)
        local final = waypoint == goal
        local speed = spec.speed * (final and Clamp(dist / 1.5, 0, 1) or 1)
        local desired = dist > 0.05 and toGoal * (speed / dist) or Vector(0, 0, 0)

        -- keep apart from other drones
        for _, other in ipairs(GetEntitiesWithinRange("VTDrone", origin, kSeparation)) do
            if other ~= self then
                local push = origin - other:GetOrigin()
                local d = push:GetLength()
                if d > 0.01 then
                    desired = desired + push * ((kSeparation - d) / d * 2.5)
                end
            end
        end

        local dv = desired - self.vtVelocity
        local maxDv = spec.accel * deltaTime
        if dv:GetLength() > maxDv then
            dv = GetNormalizedVector(dv) * maxDv
        end
        self.vtVelocity = self.vtVelocity + dv

        -- move with world collision, sliding along what we hit (two tries)
        local position = origin
        local remaining = self.vtVelocity * deltaTime
        for _ = 1, 2 do
            if remaining:GetLengthSquared() < 1e-8 then break end
            local trace = Shared.TraceCapsule(position, position + remaining, spec.radius * 0.8, 0,
                    CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
            if trace.fraction >= 1 then
                position = position + remaining
                break
            end
            position = trace.endPoint
            local n = trace.normal
            remaining = remaining * (1 - trace.fraction)
            remaining = remaining - n * remaining:DotProduct(n)
            self.vtVelocity = self.vtVelocity - n * self.vtVelocity:DotProduct(n)
        end

        -- face the target while attacking, else the flight direction
        local face = faceTarget and (faceTarget - position) or Vector(self.vtVelocity.x, 0, self.vtVelocity.z)
        if face:GetLengthSquared() > 0.01 then
            face:Normalize()
            local current = self.vtFacing or face
            self.vtFacing = GetNormalizedVector(current + (face - current) * Clamp(kTurnRate * deltaTime, 0, 1))
        end
        if not self.vtFacing or self.vtFacing:GetLengthSquared() < 0.5 then
            self.vtFacing = Vector(0, 0, 1)
        end
        self:SetCoords(Coords.GetLookIn(position, self.vtFacing))
        if self.vtHitBox then
            self.vtHitBox:SetCoords(self:GetCoords())
        end
    end

    function VTDrone:OnUpdate(deltaTime)
        if ScriptActor.OnUpdate then ScriptActor.OnUpdate(self, deltaTime) end
        if self.vtDetonated or not self:GetIsAlive() or deltaTime <= 0 then
            return
        end
        local owner = GetOwnerArtificer(self)
        if not owner then
            self:Kill(nil, nil, self:GetOrigin())          -- no Artificer, no drone
            return
        end

        local now = Shared.GetTime()
        if now >= self.vtNextThink then
            self.vtNextThink = now + kThinkInterval
            local target = self:VT_PickTarget(owner)
            self.vtTargetId = target and target:GetId() or Entity.invalidId
        end
        local target = Shared.GetEntity(self.vtTargetId)
        if target and not (HasMixin(target, "Live") and target:GetIsAlive()) then
            target = nil
            self.vtTargetId = Entity.invalidId
        end

        if target then
            FlyTo(self, self:VT_GetAttackPoint(target), deltaTime, target:GetEngagementPoint())
            if Fire(self, target, deltaTime) then
                return                                      -- the Sapper is gone
            end
        else
            self.vtBeamTargetId = Entity.invalidId
            self.vtBeamDamage = 0
            FlyTo(self, self:VT_GetEscortPoint(owner), deltaTime, nil)
        end
    end

end

Shared.LinkClassToMap("VTDrone", VTDrone.kMapName, networkVars)
