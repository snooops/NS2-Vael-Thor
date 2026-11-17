-- ============================================================================
-- VTCrucible (client) - the Artificer's look: the "Crucible" crab foundry (user's pick 2026-11-17).
--
-- The Artificer is still an exo-chassis player (hitboxes, collision and movement from the Titan model). On every
-- client this file hides that model and draws the Crucible from rigid parts (art/artificer/build_crucible.sh):
--   body   at the player's origin, turned with the player's yaw, bobbing slightly with each step
--   core   the crystal in the furnace iris: spins, pulses, flares when a drone launches or the beam fires
--   legs   6 x (thigh, shin, foot), placed by a procedural tripod gait + two-bone IK. Feet stay planted on the
--          ground (trace down) and step in an arc. Two tripods (left front, right middle, left rear | the others).
--          Moving: a gait clock alternates the tripods (one swings while the other stands, duty factor 1/2); the
--          step time shrinks with speed so a stride never exceeds kMaxStride, and a swinging foot lands half a
--          stride ahead of its rest point - so the standing tripod ends half a stride behind it, symmetric
--          around the hip in both directions. Standing / turning on the spot: feet more than kSettleDistance off
--          tidy up, one tripod at a time. Knees always bend upwards.
--          Velocity = smoothed position change (works the same for every player, not only the local one).
-- Spawn: the Crucible unfolds (kVTCrucible.unfoldTime, from the networked vtSpawnTime): it rests on its belly with
-- the legs folded under the hull, the tripods unfold one after the other, the body rises, the core grows and flares.
-- Hidden in first person (vanilla also hides your own world model there; the dome would cover the screen).
-- VT_GetCrucibleEmitterPoint(player): world tip of the beam emitter, for the defense beam (Client.lua).
-- ============================================================================

local kBodyModel  = PrecacheAsset("models/vaelthor/crucible/crucible_body.model")
local kCoreModel  = PrecacheAsset("models/vaelthor/crucible/crucible_core.model")
local kThighModel = PrecacheAsset("models/vaelthor/crucible/crucible_thigh.model")
local kShinModel  = PrecacheAsset("models/vaelthor/crucible/crucible_shin.model")
local kFootModel  = PrecacheAsset("models/vaelthor/crucible/crucible_foot.model")
local kHiddenMaterial = PrecacheAsset("models/vaelthor/blades/blades_hidden.material")
-- own sounds (art/sound/make_crucible_sounds.py): a step per landing tripod, servo whine while walking, core hum,
-- unfold at spawn. The exo's footsteps / idle hum / deploy sound are switched off (VTArtificer, VTPlayers.lua).
-- precached in shared code (kVTCrucibleSounds, Classes/VTPlayers.lua): client-only sound precaches get no index
local kStepSounds  = kVTCrucibleSounds.steps
local kServoSound  = kVTCrucibleSounds.servo
local kHumSound    = kVTCrucibleSounds.hum
local kUnfoldSound = kVTCrucibleSounds.unfold
local kStepMinInterval = 0.07          -- s: feet landing together make one step sound

-- leg geometry: kVTCrucible (Hooks/Globals.lua, shared with the hitboxes), in sync with build_crucible.py
local kHipHeight = kVTCrucible.hipHeight
local kFootReach = kVTCrucible.footReach
local kCoreOffset = Vector(0, 1.50, -0.04)
local kEmitterTip = Vector(0, 0.93, 0.90)
local kTitanFaceSets = { 0, 1 }         -- Titan body + the exo minigun arms

-- gait
local kMaxStride      = 0.85            -- m the body may travel per step (foot swings +-half of it around rest)
local kStepTimeWalk   = 0.30            -- s per swing at walking pace ...
local kStepTimeMin    = 0.13            -- ... never faster than this
local kSettleTime     = 0.22            -- s per tidy-up step when standing / turning
local kSettleDistance = 0.12            -- standing still: feet tidy up past this
local kMoveSpeed      = 0.35            -- m/s: above this the gait clock runs
local kStepHeight     = 0.20
local kSnapDistance   = 3.0             -- teleport / spawn: put the feet down at once

local kCoreColor = Color(0.65, 0.30, 1.0)

local states = {}                       -- entity id -> state

local legs = VT_GetCrucibleLegs()   -- { hip, out, tripod } per leg

local function NewModel(name)
    local m = Client.CreateRenderModel(RenderScene.Zone_Default)
    m:SetModel(name)
    return m
end

local function CreateState()
    local st = { body = NewModel(kBodyModel), core = NewModel(kCoreModel), legs = {}, spin = 0, flare = 0 }
    for i = 1, #legs do
        st.legs[i] = { thigh = NewModel(kThighModel), shin = NewModel(kShinModel), foot = NewModel(kFootModel) }
    end
    st.light = Client.CreateRenderLight()
    st.light:SetType(RenderLight.Type_Point)
    st.light:SetCastsShadows(false)
    st.light:SetSpecular(false)
    st.light:SetColor(kCoreColor)
    st.light:SetRadius(4)
    st.light:SetIntensity(5)
    st.servo = Client.CreateSoundEffect(Shared.GetSoundIndex(kServoSound))
    st.hum = Client.CreateSoundEffect(Shared.GetSoundIndex(kHumSound))
    return st
end

local function SetLoop(sound, on, entityId)
    if not sound then
        return                                   -- sound event unknown (bank not loaded): stay silent, no error spam
    end
    if on and not sound.vtPlaying then
        sound:SetParent(entityId)
        sound:Start()
        sound.vtPlaying = true
    elseif not on and sound.vtPlaying then
        sound:Stop()
        sound.vtPlaying = false
    end
end

local function DestroyState(st)
    Client.DestroyRenderModel(st.body)
    Client.DestroyRenderModel(st.core)
    for _, leg in ipairs(st.legs) do
        Client.DestroyRenderModel(leg.thigh)
        Client.DestroyRenderModel(leg.shin)
        Client.DestroyRenderModel(leg.foot)
    end
    Client.DestroyRenderLight(st.light)
    if st.servo then Client.DestroySoundEffect(st.servo) end
    if st.hum then Client.DestroySoundEffect(st.hum) end
end

local function SetVisible(st, visible)
    if st.visible == visible then return end
    st.visible = visible
    st.body:SetIsVisible(visible)
    st.core:SetIsVisible(visible)
    for _, leg in ipairs(st.legs) do
        leg.thigh:SetIsVisible(visible)
        leg.shin:SetIsVisible(visible)
        leg.foot:SetIsVisible(visible)
    end
    st.light:SetIsVisible(visible)
end

-- the Titan underneath: every face set gets the invisible material (re-applied now and then: skins reset it)
local function HideTitan(player, st, now)
    local model = player:GetRenderModel()
    if model and model:GetReadyForOverrideMaterials() and (st.titan ~= model or now - (st.titanTime or 0) > 1) then
        for _, faceSet in ipairs(kTitanFaceSets) do
            model:SetOverrideMaterial(faceSet, kHiddenMaterial)
        end
        st.titan, st.titanTime = model, now
    end
end

local function BodyCoords(player)
    local coords = Angles(0, player:GetAngles().yaw, 0):GetCoords()
    coords.origin = player:GetOrigin()
    return coords
end

-- ground under a point (or the point itself when there is none within reach)
local function Ground(point)
    local trace = Shared.TraceRay(point + Vector(0, 1.0, 0), point - Vector(0, 1.6, 0),
            CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
    if trace.fraction < 1 then
        return trace.endPoint
    end
    return point - Vector(0, 0.6, 0)
end

-- coords for a segment model: origin at p0, +Z towards p1, +Y the upper side
local function SegmentCoords(p0, p1)
    local z = GetNormalizedVector(p1 - p0)
    local up = Vector(0, 1, 0) - z * z.y
    if up:GetLengthSquared() < 1e-6 then up = Vector(1, 0, 0) end
    up:Normalize()
    local c = Coords.GetIdentity()
    c.origin = p0
    c.zAxis = z
    c.yAxis = up
    c.xAxis = up:CrossProduct(z)
    return c
end

local Knee = VT_CrucibleKnee         -- two-bone IK (Hooks/Globals.lua)

-- seconds per swing at this speed: walking cadence, quicker when running so the stride stays <= kMaxStride
local function StepTime(speed)
    return Clamp(kMaxStride / math.max(speed, 0.01), kStepTimeMin, kStepTimeWalk)
end

local function StartStep(foot, target, duration, now)
    foot.from, foot.to = foot.pos, target
    foot.stepStart, foot.stepDuration = now, duration
end

-- returns the number of feet in the air
local function UpdateGait(st, body, velocity, now)
    local flat = Vector(velocity.x, 0, velocity.z)
    local speed = flat:GetLength()
    local moving = speed > kMoveSpeed
    local stepTime = moving and StepTime(speed) or kSettleTime
    -- land half a stride ahead: the stride is what the body covers while the other tripod swings
    local lead = moving and flat * (stepTime * 0.5) or Vector(0, 0, 0)

    -- swing in progress, landing point keeps tracking the body
    local lifting = { false, false }
    local inAir = 0
    for i, leg in ipairs(legs) do
        local foot = st.feet[i]
        local rest = body:TransformPoint(leg.hip + leg.out * kFootReach - Vector(0, kHipHeight, 0))
        foot.target = Ground(rest + lead)
        if (foot.target - foot.pos):GetLength() > kSnapDistance then
            foot.pos, foot.stepStart = foot.target, nil          -- teleport / respawn
        end
        if foot.stepStart then
            local t = (now - foot.stepStart) / foot.stepDuration
            if t >= 1 then
                foot.pos, foot.stepStart = foot.target, nil
                foot.planted = now
                st.landed[#st.landed + 1] = foot.pos
            else
                foot.to = foot.target
                local e = t * t * (3 - 2 * t)
                local lift = math.sin(t * math.pi) * kStepHeight
                foot.pos = foot.from + (foot.to - foot.from) * e + Vector(0, lift, 0)
                lifting[leg.tripod] = true
                inAir = inAir + 1
            end
        end
    end

    if moving then
        -- gait clock: phase 0 -> tripod 1 lifts, phase 0.5 -> tripod 2 lifts; one full cycle = two swings
        local previous = st.phase
        if not previous then
            -- start with the tripod that is furthest off
            local off = { 0, 0 }
            for i, leg in ipairs(legs) do
                off[leg.tripod] = off[leg.tripod] + (st.feet[i].target - st.feet[i].pos):GetLength()
            end
            st.phase = off[1] >= off[2] and -0.001 or 0.499
            previous = st.phase
        end
        st.phase = previous + (now - (st.phaseTime or now)) / (2 * stepTime)
        for tripod, at in ipairs({ 0, 0.5 }) do
            local crossed = math.floor(st.phase - at) > math.floor(previous - at)
            if crossed and not lifting[tripod] then
                for i, leg in ipairs(legs) do
                    if leg.tripod == tripod and not st.feet[i].stepStart then
                        StartStep(st.feet[i], st.feet[i].target, stepTime, now)
                        inAir = inAir + 1
                    end
                end
                lifting[tripod] = true
            end
        end
    else
        st.phase = nil
        -- standing / turning: tidy up, one tripod at a time, the worse one first
        if not lifting[1] and not lifting[2] then
            local off = { 0, 0 }
            local worst = { 0, 0 }
            for i, leg in ipairs(legs) do
                local d = (st.feet[i].target - st.feet[i].pos):GetLength()
                off[leg.tripod] = off[leg.tripod] + d
                worst[leg.tripod] = math.max(worst[leg.tripod], d)
            end
            local tripod = off[1] >= off[2] and 1 or 2
            if worst[tripod] > kSettleDistance then
                for i, leg in ipairs(legs) do
                    local foot = st.feet[i]
                    if leg.tripod == tripod and now - (foot.planted or 0) > 0.08 then
                        StartStep(foot, foot.target, kSettleTime, now)
                        inAir = inAir + 1
                    end
                end
            end
        end
    end
    st.phaseTime = now
    return inAir, moving and stepTime or nil
end

-- spawn: foot positions while unfolding (u 0..1). Tripod 1 unfolds first, then tripod 2; each foot lifts from
-- its folded spot under the hull and plants at its rest position.
local function UnfoldFeet(body, u)
    local feet = {}
    for i, leg in ipairs(legs) do
        local folded = Ground(body:TransformPoint(leg.hip + leg.out * 0.18 - Vector(0, kHipHeight, 0)))
        local rest = Ground(body:TransformPoint(leg.hip + leg.out * kFootReach - Vector(0, kHipHeight, 0)))
        local start = leg.tripod == 1 and 0.05 or 0.30
        local t = Clamp((u - start) / 0.45, 0, 1)
        local e = t * t * (3 - 2 * t)
        feet[i] = folded + (rest - folded) * e + Vector(0, math.sin(t * math.pi) * 0.35, 0)
    end
    return feet
end

local function PlaceLegs(st, body)
    for i, leg in ipairs(legs) do
        local hip = body:TransformPoint(leg.hip)
        local foot = st.unfoldFeet and st.unfoldFeet[i] or st.feet[i].pos
        local knee, ankle = Knee(hip, foot)
        local m = st.legs[i]
        m.thigh:SetCoords(SegmentCoords(hip, knee))
        m.shin:SetCoords(SegmentCoords(knee, ankle))
        local outward = body:TransformVector(leg.out)
        local fc = Coords.GetLookIn(ankle, outward, Vector(0, 1, 0))
        m.foot:SetCoords(fc)
    end
end

function VT_GetCrucibleEmitterPoint(player)
    local st = player and states[player:GetId()]
    if st and st.bodyCoords and st.visible then
        return st.bodyCoords:TransformPoint(kEmitterTip)
    end
    return nil
end

local function UpdateCrucibles()
    local now = Shared.GetTime()
    local localPlayer = Client.GetLocalPlayer()
    local seen = {}
    for _, player in ientitylist(Shared.GetEntitiesWithClassname("VTArtificer")) do
        local id = player:GetId()
        seen[id] = true
        local st = states[id]
        if not st then
            st = CreateState()
            states[id] = st
        end
        local dt = math.min(0.1, now - (st.lastTime or now))
        st.lastTime = now

        HideTitan(player, st, now)
        local firstPerson = player == localPlayer and not player:GetIsThirdPerson()
        local alive = player:GetIsAlive() and not player:GetIsDestroyed()
        if not alive then
            SetVisible(st, false)
            st.feet = nil                        -- re-plant when alive again
            st.bodyCoords = nil
            st.phase, st.lastOrigin, st.velocity = nil, nil, nil
            SetLoop(st.servo, false, id)
            SetLoop(st.hum, false, id)
        else
            -- the gait (and its sounds) runs in first person too; only the drawing is skipped there
            st.landed = {}
            local body = BodyCoords(player)
            local unfold = VT_GetCrucibleUnfold(player)
            if unfold < 1 then
                st.feet = nil                    -- the gait takes over from the rest pose once unfolded
            end
            if not st.feet and unfold >= 1 then
                st.feet = {}
                for i, leg in ipairs(legs) do
                    st.feet[i] = { pos = Ground(body:TransformPoint(leg.hip + leg.out * kFootReach - Vector(0, kHipHeight, 0))),
                                   tripod = leg.tripod, planted = now }
                end
            end
            -- velocity from the position change (smoothed): the same for local, predicted and remote players
            local origin = player:GetOrigin()
            if st.lastOrigin and dt > 0 then
                local raw = (origin - st.lastOrigin) / dt
                if raw:GetLength() > 20 then raw = Vector(0, 0, 0) end   -- teleport
                st.velocity = (st.velocity or raw) + (raw - (st.velocity or raw)) * math.min(1, dt * 12)
            end
            st.lastOrigin = origin
            local velocity = st.velocity or Vector(0, 0, 0)
            local stepping = 0
            if unfold < 1 then
                st.unfoldFeet = UnfoldFeet(body, unfold)
            else
                st.unfoldFeet = nil
                stepping = UpdateGait(st, body, velocity, now)
            end

            -- body: dips twice per gait cycle (each tripod's push-off), leans a little into the movement
            local flat = Vector(velocity.x, 0, velocity.z)
            local speed = flat:GetLength()
            local dip = st.phase and -0.035 * math.abs(math.sin(st.phase * 2 * math.pi)) or 0
            local target = (stepping > 0 and not st.phase) and -0.03 or dip
            st.bob = (st.bob or 0) + (target - (st.bob or 0)) * math.min(1, dt * 14)
            local leanAmount = math.min(speed / 6, 1) * 0.06                  -- up to ~3.5 degrees
            local leanDir = speed > 0.05 and flat / speed or Vector(0, 0, 0)
            st.lean = (st.lean or Vector(0, 0, 0)) + (leanDir * leanAmount - (st.lean or Vector(0, 0, 0))) * math.min(1, dt * 6)
            local shown = Coords.GetIdentity()
            local up = GetNormalizedVector(Vector(0, 1, 0) + st.lean)
            shown.zAxis = GetNormalizedVector(body.zAxis - up * body.zAxis:DotProduct(up))
            shown.yAxis = up
            shown.xAxis = up:CrossProduct(shown.zAxis)
            shown.origin = body.origin + Vector(0, st.bob + 0.012 * math.sin(now * 2.2 + id), 0)
            if unfold < 1 then
                -- rises off its belly once the legs have a grip (second half of the unfold)
                local r = Clamp((unfold - 0.3) / 0.7, 0, 1)
                r = 1 - (1 - r) * (1 - r) * (1 - r)
                shown.origin = shown.origin - Vector(0, kVTCrucible.unfoldDrop * (1 - r), 0)
                if not st.spawnFlared then st.flare, st.spawnFlared = 1, true end
            else
                st.spawnFlared = nil
            end
            st.body:SetCoords(shown)
            st.bodyCoords = shown

            -- core: spin, pulse, flare on launches (vtNextDroneSlot is server-only: watch the drone count instead)
            local beamOn = player.vtBeamTargetId and player.vtBeamTargetId ~= Entity.invalidId
            local drones = player.VT_GetDroneCount and player:VT_GetDroneCount() or 0
            if st.lastDrones and drones > st.lastDrones then st.flare = 1 end
            st.lastDrones = drones
            st.flare = math.max(0, st.flare - dt * 1.5)
            st.spin = st.spin + dt * (1.2 + (beamOn and 4 or 0) + st.flare * 10)
            local core = Angles(0, st.spin, 0):GetCoords()
            local s = (1 + 0.08 * math.sin(now * 3) + 0.25 * st.flare) * Clamp(unfold / 0.6, 0.05, 1)
            core.xAxis, core.yAxis, core.zAxis = core.xAxis * s, core.yAxis * s, core.zAxis * s
            core.origin = shown:TransformPoint(kCoreOffset)
            local rotated = Coords.GetIdentity()
            rotated.xAxis = shown:TransformVector(core.xAxis)
            rotated.yAxis = shown:TransformVector(core.yAxis)
            rotated.zAxis = shown:TransformVector(core.zAxis)
            rotated.origin = core.origin
            st.core:SetCoords(rotated)
            st.light:SetCoords(Coords.GetTranslation(core.origin + Vector(0, 0.3, 0)))
            st.light:SetIntensity(4 + 2 * math.sin(now * 3) + (beamOn and 3 or 0) + 12 * st.flare)

            PlaceLegs(st, shown)
            SetVisible(st, not firstPerson)
            if firstPerson then st.bodyCoords = nil end   -- no world emitter point while the body is hidden

            -- sounds
            if player.vtSpawnTime and st.unfoldPlayedFor ~= player.vtSpawnTime then
                st.unfoldPlayedFor = player.vtSpawnTime
                if now - player.vtSpawnTime < 0.5 then
                    StartSoundEffectAtOrigin(kUnfoldSound, origin)
                end
            end
            if #st.landed > 0 and now - (st.lastStepSound or 0) > kStepMinInterval then
                local p = Vector(0, 0, 0)
                for _, q in ipairs(st.landed) do p = p + q end
                StartSoundEffectAtOrigin(kStepSounds[math.random(1, #kStepSounds)], p / #st.landed)
                st.lastStepSound = now
            end
            if st.phase or stepping > 0 then st.lastMoving = now end
            SetLoop(st.servo, unfold >= 1 and now - (st.lastMoving or -10) < 0.25, id)
            SetLoop(st.hum, true, id)
        end
        -- hitboxes follow on the client too (predicted hits, effects)
        if player.VT_UpdateHitboxes then
            player:VT_UpdateHitboxes()
        end
    end
    for id, st in pairs(states) do
        if not seen[id] then
            DestroyState(st)
            states[id] = nil
        end
    end
end

Event.Hook("UpdateRender", UpdateCrucibles)
