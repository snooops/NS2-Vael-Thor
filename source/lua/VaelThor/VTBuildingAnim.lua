-- ============================================================================
-- VTBuildingAnim (client) - idle animations of the Vael'Thor buildings.
--
-- The building models are static (no skeleton / animation graph). Their moving parts are built a second time as
-- their own models (art/buildings/build_all.sh: models/vaelthor/<name>/<name>_<group>.model, pivots in
-- VTBuildingParts.lua) and drawn here every frame, while face set 1 of the building model (the same parts, kept
-- there for collision and the commander's placement ghost) gets an invisible material.
--
-- Groups:
--   core   the main crystal: spins about its own axis and floats up and down
--   orbit  the small floating crystals: circle slowly around the building axis, bobbing
--   halo   the glowing ring: wobbles (precessing tilt) and floats with the core
--   dome   the Shield Generator's lattice: turns slowly
-- "Active" = built, alive and powered (the same rule as the glow light, VT_UpdateGlowLight): the motion ramps up
-- over ~1.5 s and down again when power is lost. Inactive crystals sink a little; while under construction they
-- sit lower still and rise with the build progress. Faster while busy: Nexus with a commander inside, research
-- running (Nexus, Synthesis Chamber, Psionic Spire), Obelisk firing.
--
-- Warp-in (Classes/VTWarpField.lua): while a building is a warp field its whole model is hidden (face set 0 too)
-- and a small singularity hovers in its place (art/effects/build_warp.sh): black core, white-hot photon ring
-- billboarded to the camera, a spinning blue/white accretion disk and a blue light. It grows with the warp
-- progress. Degenerating (vtWarpStability < 1, nobody near): it shrinks, shakes, flickers and its disk tumbles.
-- Warped in: flash, the core collapses and the building appears. Collapsed (the entity disappears while the field
-- was nearly gone): the singularity implodes with a flash.
-- ============================================================================

Script.Load("lua/VaelThor/VTBuildingParts.lua")

local kHiddenMaterial = PrecacheAsset("models/vaelthor/blades/blades_hidden.material")
local kGhostMaterial = PrecacheAsset("cinematics/vfx_materials/ghoststructure.material")   -- GhostStructureMixin
local kAnimFaceSet = 1
local kBaseFaceSet = 0

local kWarpCoreModel = PrecacheAsset("models/vaelthor/warp/warp_core.model")
local kWarpHaloModel = PrecacheAsset("models/vaelthor/warp/warp_halo.model")
local kWarpDiskModel = PrecacheAsset("models/vaelthor/warp/warp_disk.model")
local kWarpLightColor = Color(0.55, 0.75, 1.0)
local kWarpFlashTime = 0.6      -- s: warped in
local kWarpCollapseTime = 0.7   -- s: implosion after the field was lost
local kWarpTilt = math.rad(14)  -- accretion disk tilt

local kClasses =
{
    VTNexus = "nexus", VTSiphon = "siphon", VTSubventionPylon = "pylon", VTSynthesisChamber = "chamber",
    VTShieldGenerator = "shieldgen", VTSentinelObelisk = "obelisk", VTPsionicSpire = "spire",
}

-- per group: spin (rad/s about the vertical axis), bob (m), bobSpeed, sink (m when inactive), build (m extra
-- sink at 0% built), wobble (rad tilt)
local kGroupSettings =
{
    core  = { spin = 0.7,  bob = 0.07, bobSpeed = 1.6, sink = 0.15, build = 0.25 },
    orbit = { spin = -0.3, bob = 0.09, bobSpeed = 1.1, sink = 0.10, build = 0.20 },
    halo  = { spin = 0,    bob = 0.05, bobSpeed = 1.6, sink = 0.08, build = 0.15, wobble = math.rad(6) },
    dome  = { spin = 0.12, bob = 0,    bobSpeed = 0,   sink = 0,    build = 0 },
}
local kBoostScalar = 2.5        -- spin multiplier while busy
local kRampTime = 1.5           -- s from rest to full motion

local models = {}               -- precached model names per building
for name, groups in pairs(kVTBuildingPartPivots) do
    models[name] = {}
    for group in pairs(groups) do
        models[name][group] = PrecacheAsset(string.format("models/vaelthor/%s/%s_%s.model", name, name, group))
    end
end

local states = {}               -- entity id -> { parts = { group -> RenderModel }, level, boost, spin = {}, ... }

local function IsActive(ent)
    return ent:GetIsBuilt() and ent:GetIsAlive() and (not ent.GetIsPowered or ent:GetIsPowered())
end

local function IsBusy(ent)
    if ent.occupied then return true end                                         -- Nexus: commander inside
    if ent.researchingId and ent.researchingId ~= kTechId.None and ent.researchingId ~= kTechId.Recycle then
        return true
    end
    if ent.vtBeamTarget1 and ent.vtBeamTarget1 ~= Entity.invalidId then return true end   -- Obelisk firing
    return false
end

local function NewModel(model)
    local m = Client.CreateRenderModel(RenderScene.Zone_Default)
    m:SetModel(model)
    return m
end

-- ---- warp field -------------------------------------------------------------
local function CreateWarp()
    local w = { core = NewModel(kWarpCoreModel), halo = NewModel(kWarpHaloModel), disk = NewModel(kWarpDiskModel),
                spin = math.random() * 2 * math.pi }
    local light = Client.CreateRenderLight()
    light:SetType(RenderLight.Type_Point)
    light:SetCastsShadows(false)
    light:SetSpecular(false)
    light:SetColor(kWarpLightColor)
    light:SetRadius(6)
    w.light = light
    return w
end

local function DestroyWarp(w)
    Client.DestroyRenderModel(w.core)
    Client.DestroyRenderModel(w.halo)
    Client.DestroyRenderModel(w.disk)
    Client.DestroyRenderLight(w.light)
end

local function Scaled(c, r)
    c.xAxis, c.yAxis, c.zAxis = c.xAxis * r, c.yAxis * r, c.zAxis * r
    return c
end

-- one frame of the singularity. radius: event horizon (m); coreScale: core size relative to it (flash/implosion);
-- chaos 0..1: degeneration (shake, flicker, tumbling disk); glowOn: halo + disk shown; light: intensity.
-- Flicker = the glow parts switched off for single frames (no material parameters needed).
local function DrawWarp(w, centre, radius, coreScale, chaos, glowOn, light, now, dt, visible)
    w.spin = w.spin + dt * (2.5 + 1.5 * radius / 0.36 + 8 * chaos * math.sin(now * 9 + w.spin))
    if chaos > 0 then
        centre = centre + Vector(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (0.12 * chaos)
    end

    local core = Coords.GetIdentity()
    core.origin = centre
    w.core:SetCoords(Scaled(core, radius * coreScale))

    local player = Client.GetLocalPlayer()
    local cam = player and player.GetCameraViewCoords and player:GetCameraViewCoords()
    local toCam = cam and cam.origin - centre or Vector(0, 0, 1)
    if toCam:GetLength() < 0.01 then toCam = Vector(0, 0, 1) end
    local haloCoords = Scaled(Coords.GetLookIn(centre, GetNormalizedVector(toCam)), radius)
    w.halo:SetCoords(haloCoords)

    local tilt = kWarpTilt + chaos * math.rad(30) * math.sin(now * 6.3)
    local p = now * 0.7 + w.spin * 0.05
    local disk = Angles(tilt * math.cos(p), w.spin, tilt * math.sin(p)):GetCoords()
    disk.origin = centre
    w.disk:SetCoords(Scaled(disk, radius))

    local flicker = chaos > 0 and math.random() < chaos * 0.35
    local glow = visible ~= false and glowOn and not flicker
    w.core:SetIsVisible(visible ~= false and coreScale > 0.001)
    w.halo:SetIsVisible(glow)
    w.disk:SetIsVisible(glow)

    w.light:SetIsVisible(visible ~= false)
    w.light:SetCoords(Coords.GetTranslation(centre))
    w.light:SetIntensity(flicker and light * 0.35 or light)
end

local function WarpCentre(ent, name)
    local h = Clamp((kVTStructureModelHeights[name] or 3) * kVTStructureModelScale * 0.45, 0.9, 1.5)
    return ent:GetOrigin() + Vector(0, h, 0)
end

local dying = {}                -- collapsing / flashing warp fields that no longer follow an entity
local lastFrameTime

local function CreateState(name)
    local st = { name = name, parts = {}, level = 0, boost = 0, spin = {} }
    for group, model in pairs(models[name]) do
        local m = Client.CreateRenderModel(RenderScene.Zone_Default)
        m:SetModel(model)
        st.parts[group] = m
        st.spin[group] = math.random() * 2 * math.pi
    end
    return st
end

-- placed-but-not-started ghost structures: the parts get the same see-through overlay as the building
local function SetGhost(st, ghost)
    if ghost == (st.ghostMaterials ~= nil) then return end
    if ghost then
        st.ghostMaterials = {}
        for group, m in pairs(st.parts) do
            st.ghostMaterials[group] = AddMaterial(m, kGhostMaterial)
        end
    else
        for group, mat in pairs(st.ghostMaterials) do
            RemoveMaterial(st.parts[group], mat)
        end
        st.ghostMaterials = nil
    end
end

local function DestroyState(st)
    for _, m in pairs(st.parts) do
        Client.DestroyRenderModel(m)
    end
    st.parts = {}
    if st.warp then
        -- the field was lost (the server removes the structure at 0 stability): implode where it was
        if st.warping and (st.stability or 1) < 0.2 and st.warpCentre then
            StartSoundEffectAtOrigin(kVTWarpCollapseSound, st.warpCentre)
            table.insert(dying, { warp = st.warp, centre = st.warpCentre, radius = st.warpRadius or 0.2,
                                  start = Shared.GetTime(), duration = kWarpCollapseTime, collapse = true })
        else
            DestroyWarp(st.warp)
        end
        st.warp = nil
    end
end

-- base (scaled building coords) * local
local function Compose(base, loc)
    local c = Coords.GetIdentity()
    c.xAxis = base:TransformVector(loc.xAxis)
    c.yAxis = base:TransformVector(loc.yAxis)
    c.zAxis = base:TransformVector(loc.zAxis)
    c.origin = base:TransformPoint(loc.origin)
    return c
end

-- face set 1 (the animated parts' static copies) is always hidden; face set 0 (the building) while warping
local function HideParts(ent, st, now, warping)
    local model = ent:GetRenderModel()
    if not model or not model:GetReadyForOverrideMaterials() then return end
    if st.model ~= model then
        st.model, st.hideTime, st.baseHidden = model, nil, false
    end
    if warping ~= st.baseHidden then
        if warping then
            model:SetOverrideMaterial(kBaseFaceSet, kHiddenMaterial)
        else
            model:RemoveOverrideMaterial(kBaseFaceSet)
        end
        st.baseHidden = warping
    end
    if now - (st.hideTime or -10) > 1 then           -- re-applied now and then (skins / material resets)
        model:SetOverrideMaterial(kAnimFaceSet, kHiddenMaterial)
        if st.baseHidden then
            model:SetOverrideMaterial(kBaseFaceSet, kHiddenMaterial)
        end
        st.hideTime = now
    end
end

local function UpdateWarp(ent, st, now, dt, warping, visible)
    if warping then
        st.warp = st.warp or CreateWarp()
        local progress = ent:GetBuiltFraction()
        local stability = ent.vtWarpStability or 1
        local chaos = 1 - stability
        local radius = (0.16 + 0.2 * progress) * (0.5 + 0.5 * stability) * (1 + 0.04 * math.sin(now * 5))
        st.stability, st.warpRadius = stability, radius
        st.warpCentre = WarpCentre(ent, st.name)
        DrawWarp(st.warp, st.warpCentre, radius, 1, chaos, true, (3 + 4 * progress) * (0.4 + 0.6 * stability), now, dt,
                 visible)
    elseif st.warp then
        if st.warping and ent:GetIsBuilt() then
            -- warped in: flash, the singularity lets go of the building
            StartSoundEffectAtOrigin(kVTWarpInSound, st.warpCentre or ent:GetOrigin())
            table.insert(dying, { warp = st.warp, centre = st.warpCentre or WarpCentre(ent, st.name),
                                  radius = st.warpRadius or 0.36, start = now, duration = kWarpFlashTime })
        else
            DestroyWarp(st.warp)
        end
        st.warp = nil
    end
    st.warping = warping
end

local function UpdateDying(now, dt)
    for i = #dying, 1, -1 do
        local d = dying[i]
        local t = (now - d.start) / d.duration
        if t >= 1 then
            DestroyWarp(d.warp)
            table.remove(dying, i)
        elseif d.collapse then
            -- implosion: shrinks with growing shake and flicker, a last flash at the end
            local r = d.radius * (1 - t * t)
            local flash = t > 0.8 and (1 - t) / 0.2 * 14 or 2
            DrawWarp(d.warp, d.centre, math.max(r, 0.01), 1, 0.5 + 0.5 * t, t <= 0.8, flash, now, dt)
        else
            -- warp-in flash: the core collapses, ring and disk blow outward and vanish, bright light
            DrawWarp(d.warp, d.centre, d.radius * (1 + 2.5 * t), math.max(0, 1 - 2 * t) / (1 + 2.5 * t), 0, t < 0.6,
                     18 * (1 - t), now, dt)
        end
    end
end

local function UpdateBuilding(ent, st, now, dt)
    local warping = VT_GetIsWarping(ent)
    HideParts(ent, st, now, warping)
    local visible = ent:GetIsVisible()          -- also while dying: the crystals sink as the motion stops
    UpdateWarp(ent, st, now, dt, warping, visible)
    for _, m in pairs(st.parts) do
        m:SetIsVisible(visible and not warping)
    end
    if not visible or warping then return end
    SetGhost(st, ent.GetIsGhostStructure ~= nil and ent:GetIsGhostStructure())

    local ramp = dt / kRampTime
    st.level = Clamp(st.level + (IsActive(ent) and ramp or -ramp), 0, 1)
    st.boost = Clamp(st.boost + (IsBusy(ent) and ramp or -ramp), 0, 1)
    local level = st.level * st.level * (3 - 2 * st.level)                    -- smoothstep: eases in and out
    local built = ent.GetBuiltFraction and ent:GetBuiltFraction() or 1
    local speed = level * (1 + (kBoostScalar - 1) * st.boost)

    local s = kVTStructureModelScale
    local base = ent:GetCoords()
    base.xAxis, base.yAxis, base.zAxis = base.xAxis * s, base.yAxis * s, base.zAxis * s

    local phase = ent:GetId() * 1.7
    for group, m in pairs(st.parts) do
        local cfg = kGroupSettings[group] or kGroupSettings.core
        st.spin[group] = st.spin[group] + dt * cfg.spin * speed
        local bobPhase = (group == "halo") and "core" or group                  -- the ring floats with the crystal
        local bob = cfg.bob * level * math.sin(now * cfg.bobSpeed + phase + (bobPhase == "orbit" and 1.3 or 0))
        local lift = bob - cfg.sink * (1 - level) - cfg.build * (1 - built)
        local loc
        if cfg.wobble then
            local p = now * 0.8 * (0.3 + speed) + phase
            loc = Angles(cfg.wobble * level * math.cos(p), st.spin[group], cfg.wobble * level * math.sin(p)):GetCoords()
        else
            loc = Angles(0, st.spin[group], 0):GetCoords()
        end
        loc.origin = kVTBuildingPartPivots[st.name][group] + Vector(0, lift, 0)
        m:SetCoords(Compose(base, loc))
    end
end

local function UpdateBuildings()
    local now = Shared.GetTime()
    local seen = {}
    for className, name in pairs(kClasses) do
        if models[name] then
            for _, ent in ientitylist(Shared.GetEntitiesWithClassname(className)) do
                local id = ent:GetId()
                seen[id] = true
                local st = states[id]
                if not st then
                    st = CreateState(name)
                    states[id] = st
                end
                local dt = math.min(0.1, now - (st.lastTime or now))
                st.lastTime = now
                UpdateBuilding(ent, st, now, dt)
            end
        end
    end
    for id, st in pairs(states) do
        if not seen[id] then
            DestroyState(st)
            states[id] = nil
        end
    end
    UpdateDying(now, math.min(0.1, now - (lastFrameTime or now)))
    lastFrameTime = now
end

Event.Hook("UpdateRender", UpdateBuildings)

-- The moving parts of a building (Client.lua: the psi shield hit glow covers them too). Empty while warping.
function VT_GetBuildingPartModels(ent)
    local st = states[ent:GetId()]
    local models = {}
    if st and not st.warping then
        for _, m in pairs(st.parts) do
            table.insert(models, m)
        end
    end
    return models
end
