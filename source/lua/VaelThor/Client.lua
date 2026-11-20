-- ============================================================================
-- Vael'Thor Empire - client entry point
-- ============================================================================

-- Faction matchup of this map (sent by the server on connect, Server.lua).
Script.Load("lua/VaelThor/VTMatchupVote.lua")
Script.Load("lua/VaelThor/VTPalette.lua")
Client.HookNetworkMessage("VTMatchup", function(message)
    if not VT_GetIsValidMatchupMessage(message) then
        return   -- see Classes/VTNetwork.lua: never act on a corrupt matchup message
    end
    VT_ApplyMatchup(message.matchup)
    VT_ApplyPalette()
end)

-- One-time log lines before risky first steps of the client hooks: a hard crash ends the log, so its last
-- breadcrumb names the step that crashed.
local vtBreadcrumbs = {}
function VT_Breadcrumb(key, text)
    if not vtBreadcrumbs[key] then
        vtBreadcrumbs[key] = true
        Shared.Message("[Vael'Thor] " .. text)
    end
end

Script.Load("lua/VaelThor/GUI/GUIVTHud.lua")
Script.Load("lua/VaelThor/GUI/VTGUIStyle.lua")
Script.Load("lua/VaelThor/GUI/GUIVTGateMenu.lua")
Script.Load("lua/VaelThor/GUI/GUIVTMatrixMenu.lua")
Script.Load("lua/VaelThor/GUI/GUIVTVision.lua")
Script.Load("lua/VaelThor/GUI/GUIVTPlayerHUD.lua")
Script.Load("lua/VaelThor/GUI/GUIVTCrosshair.lua")
Script.Load("lua/VaelThor/GUI/GUIVTDroneBay.lua")
Script.Load("lua/VaelThor/VTCrucible.lua")      -- the Artificer's Crucible body + legs
Script.Load("lua/VaelThor/VTBuildingAnim.lua")  -- building idle animations (crystals, rings, dome)
Script.Load("lua/VaelThor/GUI/GUIVTTopBar.lua")
Script.Load("lua/VaelThor/GUI/GUIVTUnitStatus.lua")
Script.Load("lua/VaelThor/GUI/GUIVTMinimap.lua")
Script.Load("lua/VaelThor/GUI/GUIVTCommanderTheme.lua")

local hud, gateMenu
Event.Hook("UpdateClient", function()
    if not hud then
        local manager = GetGUIManager and GetGUIManager()
        if manager then
            hud = manager:CreateGUIScript("VaelThor/GUI/GUIVTHud")
            gateMenu = manager:CreateGUIScript("VaelThor/GUI/GUIVTGateMenu")
            VT_MatrixMenu = manager:CreateGUIScript("VaelThor/GUI/GUIVTMatrixMenu")
            VT_VisionScript = manager:CreateGUIScript("VaelThor/GUI/GUIVTVision")
            VT_PlayerHUD = manager:CreateGUIScript("VaelThor/GUI/GUIVTPlayerHUD")
            VT_CrosshairScript = manager:CreateGUIScript("VaelThor/GUI/GUIVTCrosshair")
            VT_DroneBayScript = manager:CreateGUIScript("VaelThor/GUI/GUIVTDroneBay")
            VT_TopBarScript = manager:CreateGUIScript("VaelThor/GUI/GUIVTTopBar")
        end
    end
end)

-- Team palette (VTPalette.lua): vanilla GUI classes load lazily, so re-apply now and then.
-- Use prompt ("E", "Start Commanding", pickup hints, its progress bar): MarineActionFinderMixin
-- tints it marine blue when the player is created; recolour it for Vael'Thor players.
local nextPaletteUpdate = 0
Event.Hook("UpdateClient", function()
    local now = Shared.GetTime()
    if now >= nextPaletteUpdate then
        nextPaletteUpdate = now + 1
        VT_ApplyPalette()
    end
    local player = Client.GetLocalPlayer()
    local icon = player and player.actionIconGUI
    if icon and player.vtActionIconColored ~= icon and VT_GetIsVTEntity(player) then
        icon:SetColor(kVTFontColor)
        player.vtActionIconColored = icon
    end
end)

-- ----------------------------------------------------------------------------
-- Hacked structures: pulsing green glow + green light, visible to everyone.
-- ----------------------------------------------------------------------------
local kHackLightIntensity = 6
local kHackLightRadius    = 4
local kHackLightOffset    = Vector(0, 1.2, 0)

local hackGlows = {}   -- targetId -> { model, material, light }

local function RemoveGlow(targetId, glow)

    if glow.material then
        local target = Shared.GetEntity(targetId)
        local model = target and target.GetRenderModel and target:GetRenderModel()
        if model and model == glow.model then
            RemoveMaterial(model, glow.material)
        else
            -- Model is gone with its entity; just free the material.
            Client.DestroyRenderMaterial(glow.material)
        end
    end

    if glow.light then
        Client.DestroyRenderLight(glow.light)
    end

    hackGlows[targetId] = nil

end

local function UpdateHackGlows()

    local active = {}

    for _, marker in ientitylist(Shared.GetEntitiesWithClassname("VTHackMarker")) do

        local target = marker:GetIsActive() and marker:GetTarget()
        local model = target and target.GetRenderModel and target:GetRenderModel()

        if model then

            local targetId = target:GetId()
            active[targetId] = true

            local glow = hackGlows[targetId]
            if glow and glow.model ~= model then
                -- Render model was rebuilt: re-apply on the new one.
                RemoveGlow(targetId, glow)
                glow = nil
            end

            if not glow then
                local light = Client.CreateRenderLight()
                light:SetType(RenderLight.Type_Point)
                light:SetCastsShadows(false)
                light:SetSpecular(false)
                light:SetColor(kVTHackLightColor)
                light:SetIntensity(kHackLightIntensity)
                light:SetRadius(kHackLightRadius)

                glow = { model = model, material = AddMaterial(model, kVTHackGlowMaterial), light = light }
                hackGlows[targetId] = glow
            end

            glow.light:SetCoords(Coords.GetTranslation(target:GetOrigin() + kHackLightOffset))

        end

    end

    for targetId, glow in pairs(hackGlows) do
        if not active[targetId] then
            RemoveGlow(targetId, glow)
        end
    end

end

Event.Hook("UpdateRender", UpdateHackGlows)

-- ----------------------------------------------------------------------------
-- Psi shield hit shell (Classes/VTShield.lua): when an empire soldier's or
-- structure's networked shield drops, a purple shell flashes over the model and
-- fades out over kVTShieldGlowFadeTime. No shell once the shield is 0, so hits
-- on armor / health show none. The local first-person player gets it on the
-- view model instead.
-- ----------------------------------------------------------------------------
local kShieldGlowClasses =
{
    "Player", "VTNexus", "VTSiphon", "VTSubventionPylon", "VTSynthesisChamber",
    "VTShieldGenerator", "VTSentinelObelisk", "VTPsionicSpire",
}
local kShieldHitThreshold = 0.5   -- ignore network quantization noise

local shieldGlows = {}   -- entityId -> { last, hitTime, model, material, viewModel, viewMaterial }

local function ClearShieldMaterial(glow, modelKey, materialKey)
    local material = glow[materialKey]
    if material then
        local model = glow[modelKey]
        -- The render model may be gone with its entity; then just free the material.
        if not (model and pcall(RemoveMaterial, model, material)) then
            Client.DestroyRenderMaterial(material)
        end
    end
    glow[modelKey] = nil
    glow[materialKey] = nil
end

local function SetShieldMaterial(glow, modelKey, materialKey, model, materialName, intensity)
    if glow[modelKey] ~= model then
        ClearShieldMaterial(glow, modelKey, materialKey)
    end
    if model and intensity > 0 then
        if not glow[materialKey] then
            glow[modelKey] = model
            glow[materialKey] = AddMaterial(model, materialName)
        end
        glow[materialKey]:SetParameter("intensity", intensity)
    else
        ClearShieldMaterial(glow, modelKey, materialKey)
    end
end

-- glow.extra: model -> material on render models we draw ourselves (Crucible parts, building parts)
-- modelsGone: the entity disappeared - VTCrucible / VTBuildingAnim (UpdateRender hooks registered earlier) have
-- already destroyed those models this frame, so only the materials are freed
local function SetShieldMaterialOnModels(glow, models, intensity, modelsGone)
    glow.extra = glow.extra or {}
    local wanted = {}
    if intensity > 0 then
        for _, m in ipairs(models) do
            wanted[m] = true
            if not glow.extra[m] then
                glow.extra[m] = AddMaterial(m, kVTShieldGlowMaterial)
            end
            glow.extra[m]:SetParameter("intensity", intensity)
        end
    end
    for m, material in pairs(glow.extra) do
        if not wanted[m] then
            if modelsGone or not pcall(RemoveMaterial, m, material) then
                Client.DestroyRenderMaterial(material)
            end
            glow.extra[m] = nil
        end
    end
end

local function UpdateShieldGlow(ent, now, localPlayer, seen)

    if ent:GetTeamNumber() ~= kVTTeamIndex or not VT_GetHasShieldPool(ent) or not ent:GetIsAlive() then
        return
    end

    local id = ent:GetId()
    if seen[id] then
        return
    end
    seen[id] = true

    local shield = ent.vtShield or 0
    local glow = shieldGlows[id]
    if not glow then
        glow = { last = shield }
        shieldGlows[id] = glow
    end
    if shield < glow.last - kShieldHitThreshold then
        glow.hitTime = now
    end
    glow.last = shield

    local intensity = 0
    if shield > 0 and glow.hitTime then
        intensity = 1 - (now - glow.hitTime) / kVTShieldGlowFadeTime
    end
    intensity = Clamp(intensity, 0, 1)

    local firstPerson = ent == localPlayer and ent.GetIsThirdPerson and not ent:GetIsThirdPerson()
    local model = not firstPerson and ent.GetRenderModel and ent:GetRenderModel() or nil
    -- Artificer: the Titan model is hidden under the Crucible (VTCrucible.lua) - an added material still shows on
    -- it, so the shell goes on the Crucible's parts instead
    local extra = {}
    if ent:isa("VTArtificer") then
        model = nil
        extra = VT_GetCrucibleRenderModels and VT_GetCrucibleRenderModels(ent) or {}
    elseif VT_GetBuildingPartModels and not ent:isa("Player") then
        extra = VT_GetBuildingPartModels(ent)       -- the moving crystals / rings / dome
    end
    SetShieldMaterial(glow, "model", "material", model, kVTShieldGlowMaterial, intensity)
    SetShieldMaterialOnModels(glow, extra, intensity)

    local viewModel
    if firstPerson and ent.GetViewModelEntity then
        local viewEnt = ent:GetViewModelEntity()
        viewModel = viewEnt and viewEnt:GetRenderModel()
    end
    SetShieldMaterial(glow, "viewModel", "viewMaterial", viewModel, kVTShieldGlowViewMaterial, intensity)

end

local function UpdateShieldGlows()

    PROFILE("VaelThor:UpdateShieldGlows")

    local now = Shared.GetTime()
    local localPlayer = Client.GetLocalPlayer()
    local seen = {}

    for _, className in ipairs(kShieldGlowClasses) do
        for _, ent in ientitylist(Shared.GetEntitiesWithClassname(className)) do
            UpdateShieldGlow(ent, now, localPlayer, seen)
        end
    end

    for id, glow in pairs(shieldGlows) do
        if not seen[id] then
            ClearShieldMaterial(glow, "model", "material")
            ClearShieldMaterial(glow, "viewModel", "viewMaterial")
            SetShieldMaterialOnModels(glow, {}, 0, true)
            shieldGlows[id] = nil
        end
    end

end

Event.Hook("UpdateRender", UpdateShieldGlows)

-- ----------------------------------------------------------------------------
-- Plasma bolt impacts (server -> nearby players; Hooks/DamageEffects.lua):
-- half-size railgun impact + ricochet at the hit, small scorch decal on walls.
-- ----------------------------------------------------------------------------
Client.HookNetworkMessage("VTBoltImpact", function(message)
    local position = Vector(message.posx, message.posy, message.posz)
    local normal = Vector(message.nx, message.ny, message.nz)
    if normal:GetLengthSquared() < 0.01 then normal = Vector(0, 1, 0) end
    normal:Normalize()
    local surface = EnumToString(kHitEffectSurface, message.surface)

    GetEffectManager():TriggerEffects(message.splash and "vt_plasmabolt_splash" or "vt_plasmabolt_impact",
            { [kEffectHostCoords] = Coords.GetTranslation(position + normal * 0.02), [kEffectSurface] = surface })

    if message.decal then
        -- decal frame: yAxis = surface normal (as vanilla HandleImpactDecal)
        local coords = Coords.GetTranslation(position)
        coords.yAxis = normal
        local side = math.abs(normal.y) < 0.95 and Vector(0, 1, 0) or Vector(1, 0, 0)
        coords.xAxis = GetNormalizedVector(normal:CrossProduct(side))
        coords.zAxis = GetNormalizedVector(coords.xAxis:CrossProduct(normal))
        GetEffectManager():TriggerEffects(message.splash and "vt_plasmabolt_splash_decal" or "vt_plasmabolt_decal",
                { [kEffectHostCoords] = coords, [kEffectSurface] = surface })
    end
end)

-- ----------------------------------------------------------------------------
-- Wrist weapons (third person): face set 1 of the caste's player model -
-- Infiltrator blades (cyber_player.model), Subject forearm blades + talons (stalker_player.model).
-- Visible while that weapon is active, otherwise covered by a fully transparent
-- override material. Re-applied every second in case a skin update cleared the
-- overrides.
-- ----------------------------------------------------------------------------
local kBladesFaceSet = 1
local kBladesHiddenMaterial = PrecacheAsset("models/vaelthor/blades/blades_hidden.material")
local bladeStates = {}   -- entityId -> { model, shown, time }
local kWristWeapons = { VTInfiltrator = "VTPsionicBlade", VTSubject = "VTSubjectClaws" }

local function UpdateInfiltratorBlades()
    local now = Shared.GetTime()
    local seen = {}
    for casteClass, weaponClass in pairs(kWristWeapons) do
    for _, infiltrator in ientitylist(Shared.GetEntitiesWithClassname(casteClass)) do
        local model = infiltrator:GetRenderModel()
        if model and model:GetReadyForOverrideMaterials() then
            local id = infiltrator:GetId()
            seen[id] = true
            local weapon = infiltrator:GetActiveWeapon()
            local show = infiltrator:GetIsAlive() and weapon ~= nil and weapon:isa(weaponClass)
            local st = bladeStates[id]
            if not st or st.model ~= model or st.shown ~= show or now - st.time > 1 then
                if show then
                    model:RemoveOverrideMaterial(kBladesFaceSet)
                else
                    model:SetOverrideMaterial(kBladesFaceSet, kBladesHiddenMaterial)
                end
                bladeStates[id] = { model = model, shown = show, time = now }
            end
        end
    end
    end
    for id in pairs(bladeStates) do
        if not seen[id] then bladeStates[id] = nil end
    end
end

Event.Hook("UpdateRender", UpdateInfiltratorBlades)

-- ----------------------------------------------------------------------------
-- Praetor laser guns (art/weapons/build_lasergun.sh) instead of the exo miniguns. The minigun geometry is hidden
-- with the transparent override material (Titan world model: face set 1; exo first-person view model: face set 0,
-- turret + arm mount). Each arm gets a client render model pair - body + emitter barrel, origin = muzzle tip -
-- anchored every frame at the exo's muzzle attach point (child of the arm / wrist bone, so it follows the
-- animation but never the barrel spin). Recoil per bolt: the gun kicks back and up, the barrel slides back further
-- into its shroud, and a violet light flashes at the muzzle; all ease out over ~0.2 s.
-- Own guns kick on every bolt (VTPlasmaMinigun's FireBolt stamps vtShotTime on the client); other Praetors' guns
-- kick at kGunAutoKickInterval while their arm's networked "shooting" flag is set.
-- ----------------------------------------------------------------------------
local kLaserBodyModel   = PrecacheAsset("models/vaelthor/lasergun/lasergun_body.model")
local kLaserBarrelModel = PrecacheAsset("models/vaelthor/lasergun/lasergun_barrel.model")
local kViewGunFaceSet, kWorldGunFaceSet = 0, 1
local kViewMuzzles  = { "fxnode_l_minigun_muzzle", "fxnode_r_minigun_muzzle" }    -- left, right
local kWorldMuzzles = { "fxnode_l_minigun_muzzle", "fxnode_r_minigun_muzzle1" }
local kGunKickBack      = 0.05     -- m, whole gun
local kGunBarrelSlide   = 0.09     -- m, barrel on top of the gun kick
local kGunKickPitch     = math.rad(3)
local kGunKickDecay     = 16       -- 1/s, exponential ease-out
local kGunAutoKickInterval = 0.11  -- s, other Praetors (no per-bolt info on remote clients)
local kGunFlashColor    = Color(0.80, 0.40, 1.0)
local kGunFlashIntensity, kGunFlashRadius = 6, 3

local kCameraSpace = Coords.GetIdentity()
local gunStates = {}       -- praetor id -> { world = {gun, gun}, view = {gun, gun}, hideTime, worldModel }
local viewOverride = nil   -- render model whose face set 0 we hid
local viewOverrideTime = nil

local function CreateGun(zone)
    local gun = {}
    gun.body = Client.CreateRenderModel(zone)
    gun.body:SetModel(kLaserBodyModel)
    gun.barrel = Client.CreateRenderModel(zone)
    gun.barrel:SetModel(kLaserBarrelModel)
    if zone == RenderScene.Zone_ViewModel then
        gun.body:SetCastsShadows(false)
        gun.barrel:SetCastsShadows(false)
    end
    gun.light = Client.CreateRenderLight()
    gun.light:SetType(RenderLight.Type_Point)
    gun.light:SetCastsShadows(false)
    gun.light:SetSpecular(false)
    gun.light:SetColor(kGunFlashColor)
    gun.light:SetRadius(kGunFlashRadius)
    gun.light:SetIntensity(0)
    return gun
end

local function DestroyGun(gun)
    Client.DestroyRenderModel(gun.body)
    Client.DestroyRenderModel(gun.barrel)
    Client.DestroyRenderLight(gun.light)
end

local function HideGun(gun)
    gun.body:SetIsVisible(false)
    gun.barrel:SetIsVisible(false)
    gun.light:SetIntensity(0)
end

-- Muzzle frame from an attach point: the attach axis closest to the aim direction becomes the barrel axis
-- (attach point axis conventions differ between the view and world models), up = the aim frame's up.
-- The barrel points from the attach point at aimPoint (same space as the attach point): the bolts fly from the
-- muzzles to the point under the crosshair, so the guns converge on it too (on screen a barrel aimed there runs
-- from the muzzle to the crosshair, along the bolt).
-- dropPx/focalPx (first person only): move the gun down by dropPx screen pixels at its own depth.
local function GetMuzzleCoords(model, attachName, aim, aimPoint, dropPx, focalPx)
    if not model or model:GetAttachPointIndex(attachName) < 0 then
        return nil
    end
    local origin = model:GetAttachPointCoords(attachName).origin
    if dropPx and focalPx and origin.z > 0 then
        origin = origin - aim.yAxis * (dropPx * origin.z / focalPx)
    end
    local forward = aimPoint - origin
    if forward:GetLengthSquared() < 0.01 or forward:DotProduct(aim.zAxis) <= 0 then
        forward = aim.zAxis
    end
    return Coords.GetLookIn(origin, GetNormalizedVector(forward), aim.yAxis)
end

-- First-person guns sit kGunScreenDrop of the screen height lower than the exo arm muzzles (user 2026-11-17: they
-- looked like they were mounted at the head). Bolts start lower to match: kVTPraetorBoltUp (Globals).
local kGunScreenDrop = 0.20

-- Focal length (px) of the view model zone: ViewModel:OnAdjustModelCoords sets its horizontal FOV to
-- GetScreenAdjustedFov(model camera FOV or 65 deg, 1900 / 1200).
local function GetViewZoneFocal(viewModel)
    local fov = math.rad(65)
    if viewModel.GetNumModelCameras and viewModel:GetNumModelCameras() > 0 then
        fov = viewModel:GetModelCamera(0):GetFov()
    end
    fov = GetScreenAdjustedFov(fov, 1900 / 1200)
    return Client.GetScreenWidth() * 0.5 / math.tan(fov * 0.5)
end

-- Distance to what the local crosshair is on, smoothed (the guns' convergence point).
local kGunConvergeMin, kGunConvergeMax, kGunConvergeRemote = 2.5, 60, 20
local gunAimDistance, gunAimTime = kGunConvergeRemote, nil
local function UpdateLocalAimDistance(player, now)
    local eye = player:GetEyePos()
    local forward = player:GetViewCoords().zAxis
    local trace = Shared.TraceRay(eye, eye + forward * kGunConvergeMax, CollisionRep.Damage, PhysicsMask.Bullets,
            EntityFilterOne(player))
    local target = Clamp(trace.fraction * kGunConvergeMax, kGunConvergeMin, kGunConvergeMax)
    local dt = gunAimTime and math.min(0.1, now - gunAimTime) or 0.1
    gunAimTime = now
    gunAimDistance = gunAimDistance + (target - gunAimDistance) * math.min(1, dt * 12)
    return gunAimDistance
end

-- toWorld: for guns in the view model zone (camera space), the camera's world coords - the muzzle light is a
-- world light.
local function PlaceGun(gun, muzzle, kick, toWorld)
    if not muzzle then
        HideGun(gun)
        return
    end
    local t = math.tan(kGunKickPitch * kick)
    local z = GetNormalizedVector(muzzle.zAxis + muzzle.yAxis * t)
    local y = GetNormalizedVector(muzzle.yAxis - muzzle.zAxis * t)
    local coords = Coords.GetIdentity()
    coords.xAxis, coords.yAxis, coords.zAxis = muzzle.xAxis, y, z
    coords.origin = muzzle.origin - z * (kGunKickBack * kick)
    gun.body:SetCoords(coords)
    local barrel = Coords.GetIdentity()
    barrel.xAxis, barrel.yAxis, barrel.zAxis = coords.xAxis, coords.yAxis, coords.zAxis
    barrel.origin = coords.origin - z * (kGunBarrelSlide * kick)
    gun.barrel:SetCoords(barrel)
    gun.body:SetIsVisible(true)
    gun.barrel:SetIsVisible(true)
    local flashPoint = muzzle.origin + muzzle.zAxis * 0.1
    if toWorld then
        flashPoint = toWorld:TransformPoint(flashPoint)
    end
    gun.light:SetCoords(Coords.GetTranslation(flashPoint))
    gun.light:SetIntensity(kGunFlashIntensity * kick * kick)
end

-- 1 right after a shot, easing to 0
local function GetKick(lastShot, now)
    local t = now - (lastShot or -10)
    if t < 0 or t > 0.4 then return 0 end
    return math.exp(-t * kGunKickDecay)
end

local function GetArmWeapons(praetor)
    local holder = praetor.GetWeapon and praetor:GetWeapon(ExoWeaponHolder.kMapName)
    if not holder then return nil, nil end
    return Shared.GetEntity(holder.leftWeaponId), Shared.GetEntity(holder.rightWeaponId)
end

local function SetFaceSetHidden(model, faceSet, hidden)
    if model and model:GetReadyForOverrideMaterials() then
        if hidden then
            model:SetOverrideMaterial(faceSet, kBladesHiddenMaterial)
        else
            model:RemoveOverrideMaterial(faceSet)
        end
    end
end

local function UpdatePraetorGuns()
    local now = Shared.GetTime()
    local localPlayer = Client.GetLocalPlayer()
    local seen = {}
    local viewModelToHide = nil

    for _, praetor in ientitylist(Shared.GetEntitiesWithClassname("VTPraetor")) do
        local id = praetor:GetId()
        seen[id] = true
        local st = gunStates[id]
        if not st then
            st = { world = { CreateGun(RenderScene.Zone_Default), CreateGun(RenderScene.Zone_Default) }, lastShot = {} }
            gunStates[id] = st
        end

        local alive = praetor:GetIsAlive()
        local isLocal = praetor == localPlayer
        local firstPerson = isLocal and not praetor:GetIsThirdPerson()
        local noGuns = praetor:isa("VTArtificer")      -- the Crucible (VTCrucible.lua) carries no guns

        -- recoil timing per arm
        local weapons = { GetArmWeapons(praetor) }
        for side = 1, 2 do
            local weapon = weapons[side]
            if isLocal then
                st.lastShot[side] = weapon and weapon.vtShotTime or st.lastShot[side]
            elseif weapon and weapon.shooting and now - (st.lastShot[side] or -10) >= kGunAutoKickInterval then
                st.lastShot[side] = now
            end
        end

        -- world guns (everyone else, or yourself in third person); vanilla miniguns hidden on the Titan
        local worldModel = praetor:GetRenderModel()
        if worldModel and (st.worldModel ~= worldModel or now - (st.hideTime or 0) > 1) then
            SetFaceSetHidden(worldModel, kWorldGunFaceSet, true)
            st.worldModel, st.hideTime = worldModel, now
        end
        local aim = praetor:GetViewCoords()
        local aimDistance = isLocal and UpdateLocalAimDistance(praetor, now) or kGunConvergeRemote
        local worldAimPoint = praetor:GetEyePos() + aim.zAxis * aimDistance
        for side = 1, 2 do
            if alive and not firstPerson and worldModel and not noGuns then
                PlaceGun(st.world[side], GetMuzzleCoords(praetor, kWorldMuzzles[side], aim, worldAimPoint), GetKick(st.lastShot[side], now))
            else
                HideGun(st.world[side])
            end
        end

        -- first-person guns in the view model zone
        if firstPerson and alive then
            local viewModel = praetor:GetViewModelEntity()
            if viewModel and viewModel:GetRenderModel() then
                viewModelToHide = viewModel:GetRenderModel()
                if not st.view then
                    st.view = { CreateGun(RenderScene.Zone_ViewModel), CreateGun(RenderScene.Zone_ViewModel) }
                end
                local focal = GetViewZoneFocal(viewModel)
                for side = 1, 2 do
                    -- the view model zone is camera space (ViewModel:OnAdjustModelCoords = inverse model camera):
                    -- forward +Z, up +Y, whatever the world view direction
                    if noGuns then HideGun(st.view[side]) else PlaceGun(st.view[side], GetMuzzleCoords(viewModel, kViewMuzzles[side], kCameraSpace,
                            Vector(0, 0, aimDistance), kGunScreenDrop * Client.GetScreenHeight(), focal),
                            GetKick(st.lastShot[side], now), aim) end
                end
            end
        end
        if st.view and not (firstPerson and alive and viewModelToHide) then
            HideGun(st.view[1]); HideGun(st.view[2])
        end
    end

    -- the first-person minigun geometry: hidden while we are a Praetor, restored afterwards. Only touch a render
    -- model that is still the local view model's current one (an old one may already be destroyed).
    if viewOverride ~= viewModelToHide then
        if viewOverride and not viewModelToHide and localPlayer and localPlayer.GetViewModelEntity then
            local viewModel = localPlayer:GetViewModelEntity()
            if viewModel and viewModel:GetRenderModel() == viewOverride then
                SetFaceSetHidden(viewOverride, kViewGunFaceSet, false)
            end
        end
        viewOverride = viewModelToHide
        viewOverrideTime = nil
    end
    if viewModelToHide and (not viewOverrideTime or now - viewOverrideTime > 1) then
        SetFaceSetHidden(viewModelToHide, kViewGunFaceSet, true)
        viewOverrideTime = now
    end

    for id, st in pairs(gunStates) do
        if not seen[id] then
            DestroyGun(st.world[1]); DestroyGun(st.world[2])
            if st.view then DestroyGun(st.view[1]); DestroyGun(st.view[2]) end
            gunStates[id] = nil
        end
    end
end

Event.Hook("UpdateRender", UpdatePraetorGuns)

-- ----------------------------------------------------------------------------
-- Praetor II (test class) psionic beam from a shoulder emitter (art/weapons/build_beamemitter.sh: body + focus
-- ring, origin = lens tip, laser gun material). The emitter sits on the Titan's right shoulder (world zone, anchored
-- at the Exosuit_UpprTorso attach point) and, for the shooter in first person, peeks in from the upper right of
-- the screen (view model zone). It aims at the beam target (else straight ahead); the focus ring spins up while the
-- beam fires. The beam (Sentinel Obelisk strips, VT_BeamFx from Classes/VTStructures.lua) starts at the lens: in
-- first person at the world point on the screen ray through the view-zone lens (the zones have different FOVs).
-- A looping hum (vanilla nanoshield loop, like the Obelisk) plays on the Praetor while the beam is on.
-- ----------------------------------------------------------------------------
local kEmitterModel     = PrecacheAsset("models/vaelthor/lasergun/beam_emitter.model")
local kEmitterRingModel = PrecacheAsset("models/vaelthor/lasergun/beam_emitter_ring.model")
local kPraetorBeamSound = PrecacheAsset("sound/NS2.fev/marine/commander/nano_loop")
local kCrucibleViewModel = PrecacheAsset("models/vaelthor/crucible/crucible_view.model")
local kCrucibleViewEmitter = Vector(0, -0.25, 0.76)    -- emitter tip in camera space (build_crucible.py VIEW_EMITTER_TIP)
-- world: lens tip relative to the upper torso attach point, in the Praetor's view frame (x = left); shared with the
-- server (missile spawn point of the Praetor's pod), Hooks/Globals.lua
local kEmitterUp, kEmitterRight, kEmitterForward = kVTShoulderMountUp, kVTShoulderMountRight, kVTShoulderMountForward
-- first person: lens tip on screen (fractions of width / height right of / above the centre) and its depth (m)
local kViewEmitterScreenX, kViewEmitterScreenY, kViewEmitterDepth = 0.30, 0.20, 0.75
local kRingSpinIdle, kRingSpinFiring = 1.0, 14.0     -- rad/s
local beamStates = {}   -- praetor id -> { fx, sound, playing, world = {body, ring}, view = {body, ring}, spin }

local function CreateEmitter(zone)
    local e = { body = Client.CreateRenderModel(zone), ring = Client.CreateRenderModel(zone) }
    e.body:SetModel(kEmitterModel)
    e.ring:SetModel(kEmitterRingModel)
    if zone == RenderScene.Zone_ViewModel then
        e.body:SetCastsShadows(false)
        e.ring:SetCastsShadows(false)
    end
    return e
end

local function DestroyEmitter(e)
    Client.DestroyRenderModel(e.body)
    Client.DestroyRenderModel(e.ring)
end

local function SetEmitterVisible(e, visible)
    e.body:SetIsVisible(visible)
    e.ring:SetIsVisible(visible)
end

local function PlaceEmitter(e, tip, aimPoint, up, spin)
    local forward = aimPoint - tip
    if forward:GetLengthSquared() < 0.01 then forward = Vector(0, 0, 1) end
    local coords = Coords.GetLookIn(tip, GetNormalizedVector(forward), up)
    e.body:SetCoords(coords)
    local c, s = math.cos(spin), math.sin(spin)
    local ring = Coords.GetIdentity()
    ring.origin, ring.zAxis = coords.origin, coords.zAxis
    ring.xAxis = coords.xAxis * c + coords.yAxis * s
    ring.yAxis = coords.yAxis * c - coords.xAxis * s
    e.ring:SetCoords(ring)
    SetEmitterVisible(e, true)
end

-- World focal length (px) of the current camera, measured with WorldToScreen.
local function GetWorldFocal(camera)
    local p = Client.WorldToScreen(camera.origin + camera.zAxis * 10 + camera.xAxis)
    local f = math.abs(p.x - Client.GetScreenWidth() * 0.5) * 10
    return f > 1 and f or Client.GetScreenWidth() * 0.5
end

local function UpdatePraetorBeams()
    if not VT_BeamFx then return end
    local now = Shared.GetTime()
    local localPlayer = Client.GetLocalPlayer()
    local cameraCoords = localPlayer and localPlayer.GetCameraViewCoords and localPlayer:GetCameraViewCoords()
    local seen = {}
    for _, praetor in ientitylist(Shared.GetEntitiesWithClassname("VTPraetor2")) do
        local id = praetor:GetId()
        seen[id] = true
        local st = beamStates[id]
        if not st then
            st = { fx = VT_BeamFx.Create(), world = CreateEmitter(RenderScene.Zone_Default), spin = 0, lastTime = now }
            st.sound = Client.CreateSoundEffect(Shared.GetSoundIndex(kPraetorBeamSound))
            st.sound:SetParent(id)
            beamStates[id] = st
        end

        local alive = praetor:GetIsAlive()
        local targetId = praetor.vtBeamTargetId
        local target = alive and targetId and targetId ~= Entity.invalidId and Shared.GetEntity(targetId) or nil
        if target and not target.GetEngagementPoint then target = nil end
        local firing = target ~= nil       -- (target must be nil, not false: "false ~= nil" drew a beam to false)
        local dt = math.min(0.1, now - st.lastTime)
        st.lastTime = now
        st.spin = st.spin + dt * (firing and kRingSpinFiring or kRingSpinIdle)

        local view = praetor:GetViewCoords()
        local firstPerson = praetor == localPlayer and not praetor:GetIsThirdPerson()
        local targetPoint = target and VT_BeamFx.GetEndPoint(target, localPlayer, cameraCoords)
        local beamStart

        -- the Artificer's Crucible fires from its own emitter under the eyes (VTCrucible.lua), no shoulder emitter
        local crucibleTip = praetor:isa("VTArtificer") and VT_GetCrucibleEmitterPoint and VT_GetCrucibleEmitterPoint(praetor)
        if crucibleTip then
            SetEmitterVisible(st.world, false)
            beamStart = crucibleTip
        -- world emitter on the right shoulder (others, or yourself in third person)
        elseif alive and not firstPerson and not praetor:isa("VTArtificer") then
            local anchor = praetor:GetAttachPointIndex("Exosuit_UpprTorso") >= 0
                    and praetor:GetAttachPointCoords("Exosuit_UpprTorso").origin or praetor:GetEyePos()
            local tip = anchor + view.yAxis * kEmitterUp - view.xAxis * kEmitterRight + view.zAxis * kEmitterForward
            PlaceEmitter(st.world, tip, targetPoint or (praetor:GetEyePos() + view.zAxis * 20), view.yAxis, st.spin)
            beamStart = tip
        else
            SetEmitterVisible(st.world, false)
        end

        -- Artificer in first person: crucible_view.model (camera space: emitter turret at the bottom centre, pincers
        -- from the lower corners) in the view model zone, bobbing with the gait; the beam starts at its emitter
        -- tip. No shoulder emitter.
        local crucibleView = alive and firstPerson and cameraCoords and praetor:isa("VTArtificer")
        if crucibleView then
            local viewModel = praetor:GetViewModelEntity()
            if viewModel then
                if not st.crucible then
                    st.crucible = Client.CreateRenderModel(RenderScene.Zone_ViewModel)
                    st.crucible:SetModel(kCrucibleViewModel)
                    st.crucible:SetCastsShadows(false)
                end
                local speed = praetor:GetVelocity():GetLengthXZ()
                local bob = math.min(speed / 5, 1) * 0.012 * math.sin(now * 13)
                local c = Coords.GetIdentity()
                c.origin = Vector(0, bob, 0)
                st.crucible:SetCoords(c)
                st.crucible:SetIsVisible(true)
                local tip = kCrucibleViewEmitter + Vector(0, bob, 0)
                local fView = GetViewZoneFocal(viewModel)
                local fWorld = GetWorldFocal(cameraCoords)
                local d = 1.0
                local k = fView / fWorld * d / tip.z
                beamStart = cameraCoords.origin + cameraCoords.zAxis * d
                        + cameraCoords.xAxis * (tip.x * k) + cameraCoords.yAxis * (tip.y * k)
            end
            if st.view then SetEmitterVisible(st.view, false) end
        elseif st.crucible then
            st.crucible:SetIsVisible(false)
        end

        -- first-person emitter in the view model zone (camera space: +Z forward, +Y up, +X left)
        if alive and firstPerson and cameraCoords and not crucibleView then
            local viewModel = praetor:GetViewModelEntity()
            if viewModel then
                st.view = st.view or CreateEmitter(RenderScene.Zone_ViewModel)
                local fView = GetViewZoneFocal(viewModel)
                local fWorld = GetWorldFocal(cameraCoords)
                local z = kViewEmitterDepth
                local tip = Vector(-kViewEmitterScreenX * Client.GetScreenWidth() * z / fView,
                        kViewEmitterScreenY * Client.GetScreenHeight() * z / fView, z)
                local aim
                if targetPoint then
                    -- the target as it appears on screen, expressed in the view zone's projection
                    local l = cameraCoords:GetInverse():TransformPoint(targetPoint)
                    local k = fWorld / fView
                    aim = Vector(l.x * k, l.y * k, math.max(l.z, 0.5))
                else
                    aim = Vector(0, 0, gunAimDistance or 20)
                end
                PlaceEmitter(st.view, tip, aim, Vector(0, 1, 0), st.spin)
                -- beam start: the world point on the screen ray through the lens tip, 1 m out
                local d = 1.0
                local k = fView / fWorld * d / z
                beamStart = cameraCoords.origin + cameraCoords.zAxis * d
                        + cameraCoords.xAxis * (tip.x * k) + cameraCoords.yAxis * (tip.y * k)
            end
        elseif st.view and not crucibleView then
            SetEmitterVisible(st.view, false)
        end

        if firing and beamStart then
            local cameraPos = cameraCoords and cameraCoords.origin or praetor:GetEyePos()
            -- the Artificer's defense beam is a thin one
            VT_BeamFx.Update(st.fx, beamStart, targetPoint, 1, cameraPos, praetor:isa("VTArtificer") and 0.55 or 1)
            if not st.playing then st.sound:Start(); st.playing = true end
        else
            VT_BeamFx.SetVisible(st.fx, false)
            if st.playing then st.sound:Stop(); st.playing = false end
        end
    end
    for id, st in pairs(beamStates) do
        if not seen[id] then
            VT_BeamFx.Destroy(st.fx)
            Client.DestroySoundEffect(st.sound)
            DestroyEmitter(st.world)
            if st.view then DestroyEmitter(st.view) end
            if st.crucible then Client.DestroyRenderModel(st.crucible) end
            beamStates[id] = nil
        end
    end
end

Event.Hook("UpdateRender", UpdatePraetorBeams)

-- ----------------------------------------------------------------------------
-- Praetor (I) shoulder missile pod (art/weapons/build_missilepod.sh, origin = launch point): same mount as the
-- Praetor II emitter - right shoulder in the world, upper right of the screen in first person - aimed at the
-- missile lock (own Praetor) or straight ahead. Every launch (vtNextMissileTime moves forward, networked to all)
-- kicks the pod back and up and flashes a violet light at the tubes. The server spawns the missiles at the same
-- world point (VTPraetor:VT_FireMissile).
-- ----------------------------------------------------------------------------
local kMissilePodModel = PrecacheAsset("models/vaelthor/lasergun/missile_pod.model")
local kPodKickBack, kPodKickPitch, kPodKickDecay = 0.10, math.rad(7), 9
local podStates = {}    -- praetor id -> { world, view, light, lastNext, launchTime }

local function CreatePod(zone)
    local model = Client.CreateRenderModel(zone)
    model:SetModel(kMissilePodModel)
    if zone == RenderScene.Zone_ViewModel then
        model:SetCastsShadows(false)
    end
    return model
end

local function PlacePod(model, tip, aimPoint, up, kick)
    local forward = aimPoint - tip
    if forward:GetLengthSquared() < 0.01 then forward = Vector(0, 0, 1) end
    local coords = Coords.GetLookIn(tip, GetNormalizedVector(forward), up)
    local t = math.tan(kPodKickPitch * kick)
    local z = GetNormalizedVector(coords.zAxis + coords.yAxis * t)
    local y = GetNormalizedVector(coords.yAxis - coords.zAxis * t)
    coords.zAxis, coords.yAxis = z, y
    coords.origin = tip - z * (kPodKickBack * kick)
    model:SetCoords(coords)
    model:SetIsVisible(true)
end

local function UpdatePraetorPods()
    local now = Shared.GetTime()
    local localPlayer = Client.GetLocalPlayer()
    local cameraCoords = localPlayer and localPlayer.GetCameraViewCoords and localPlayer:GetCameraViewCoords()
    local seen = {}
    for _, praetor in ientitylist(Shared.GetEntitiesWithClassname("VTPraetor")) do
        if not praetor:isa("VTPraetor2") then          -- Praetor II carries the beam emitter instead
            local id = praetor:GetId()
            seen[id] = true
            local st = podStates[id]
            if not st then
                st = { world = CreatePod(RenderScene.Zone_Default), lastNext = praetor.vtNextMissileTime or 0 }
                st.light = Client.CreateRenderLight()
                st.light:SetType(RenderLight.Type_Point)
                st.light:SetCastsShadows(false)
                st.light:SetSpecular(false)
                st.light:SetColor(Color(0.85, 0.4, 1.0))
                st.light:SetRadius(3)
                st.light:SetIntensity(0)
                podStates[id] = st
            end
            local nextTime = praetor.vtNextMissileTime or 0
            if nextTime > (st.lastNext or 0) + 0.05 then
                st.launchTime = now                      -- a missile just left
            end
            st.lastNext = nextTime
            local kick = 0
            if st.launchTime and now - st.launchTime < 0.6 then
                kick = math.exp(-(now - st.launchTime) * kPodKickDecay)
            end

            local alive = praetor:GetIsAlive()
            local view = praetor:GetViewCoords()
            local firstPerson = praetor == localPlayer and not praetor:GetIsThirdPerson()
            local lockId = praetor.vtMissileLockId
            local lockTarget = lockId and lockId ~= Entity.invalidId and Shared.GetEntity(lockId) or nil
            local lockPoint = lockTarget and lockTarget.GetEngagementPoint and lockTarget:GetEngagementPoint() or nil
            local flashPoint

            if alive and not firstPerson then
                local anchor = praetor:GetAttachPointIndex("Exosuit_UpprTorso") >= 0
                        and praetor:GetAttachPointCoords("Exosuit_UpprTorso").origin or praetor:GetEyePos()
                local tip = anchor + view.yAxis * kEmitterUp - view.xAxis * kEmitterRight + view.zAxis * kEmitterForward
                PlacePod(st.world, tip, lockPoint or (praetor:GetEyePos() + view.zAxis * 20), view.yAxis, kick)
                flashPoint = tip + view.zAxis * 0.15
            else
                st.world:SetIsVisible(false)
            end

            if alive and firstPerson and cameraCoords then
                local viewModel = praetor:GetViewModelEntity()
                if viewModel then
                    st.view = st.view or CreatePod(RenderScene.Zone_ViewModel)
                    local fView = GetViewZoneFocal(viewModel)
                    local fWorld = GetWorldFocal(cameraCoords)
                    local z = kViewEmitterDepth
                    local tip = Vector(-kViewEmitterScreenX * Client.GetScreenWidth() * z / fView,
                            kViewEmitterScreenY * Client.GetScreenHeight() * z / fView, z)
                    local aim
                    if lockPoint then
                        local l = cameraCoords:GetInverse():TransformPoint(lockPoint)
                        local k = fWorld / fView
                        aim = Vector(l.x * k, l.y * k, math.max(l.z, 0.5))
                    else
                        aim = Vector(0, 0, gunAimDistance or 20)
                    end
                    PlacePod(st.view, tip, aim, Vector(0, 1, 0), kick)
                    local k = fView / fWorld * 1.0 / z
                    flashPoint = cameraCoords.origin + cameraCoords.zAxis * 1.0
                            + cameraCoords.xAxis * (tip.x * k) + cameraCoords.yAxis * (tip.y * k)
                end
            elseif st.view then
                st.view:SetIsVisible(false)
            end

            if flashPoint and kick > 0.01 then
                st.light:SetCoords(Coords.GetTranslation(flashPoint))
                st.light:SetIntensity(8 * kick)
            else
                st.light:SetIntensity(0)
            end
        end
    end
    for id, st in pairs(podStates) do
        if not seen[id] then
            Client.DestroyRenderModel(st.world)
            if st.view then Client.DestroyRenderModel(st.view) end
            Client.DestroyRenderLight(st.light)
            podStates[id] = nil
        end
    end
end

Event.Hook("UpdateRender", UpdatePraetorPods)

-- ----------------------------------------------------------------------------
-- Praetor: no exosuit cockpit. The first-person exo view model (exosuit_mm_view) has
-- face set 0 = the minigun arms; 1-7 = cockpit frame + lid, screen, and the small
-- in-world armor/heat panels. Those get the fully transparent override material.
-- The thruster fuel bar (GUIExoThruster) is hidden through ClientUI's visibility API.
-- Re-applied every second in case a skin update cleared the overrides.
-- ----------------------------------------------------------------------------
local kExoCockpitFaceSets = { 1, 2, 3, 4, 5, 6, 7 }
local praetorCockpit = { model = nil, time = 0 }
local praetorHudHidden = nil
local praetorHudTime = 0

-- Vanilla crosshair (GUICrosshair has no SetIsVisible, so ClientUI can't hide it): wrap the live
-- instance's Update and hide its crosshair + reload dial while GUIVTCrosshair draws ours. The vanilla
-- hit marker goes with it (ours has its own). Re-wrapped automatically if the script is recreated.
local function WrapVanillaCrosshair(script)
    if script.vtWrappedUpdate then
        return
    end
    local baseUpdate = script.Update
    script.vtWrappedUpdate = true
    script.Update = function(self, deltaTime)
        baseUpdate(self, deltaTime)
        if VT_GetShowsOwnCrosshair and VT_GetShowsOwnCrosshair() then
            self.crosshairs:SetIsVisible(false)
            if self.reloadDial then
                self.reloadDial:SetIsVisible(false)
            end
        end
    end
end

-- GUIExoHUD (rings, info bars, skulk reticles, status icons): the file hook on the class did not take
-- effect in-game, so the live script instance gets a wrapped Update instead. Only the centre crosshair
-- (the exo's only crosshair) stays for the Praetor; vanilla Exos are untouched.
local function StripExoHUD(script)
    if script.vtWrappedUpdate then
        return
    end
    local baseUpdate = script.Update
    script.vtWrappedUpdate = true
    script.Update = function(self, deltaTime)
        baseUpdate(self, deltaTime)
        local player = Client.GetLocalPlayer()
        local praetor = player ~= nil and player:isa("VTPraetor")
        if not praetor and not self.vtStripped then
            return
        end
        local full = not praetor and Client.GetHudDetail() == kHUDMode.Full
        for _, item in ipairs({ self.innerRing, self.outerRing, self.leftInfoBar, self.rightInfoBar, self.staticRing }) do
            item:SetIsVisible(full)
        end
        -- the exo's centre crosshair: replaced by GUIVTCrosshair
        self.crosshair:SetIsVisible(not praetor)
        if praetor then
            self.targetcrosshair:SetIsVisible(false)
            for i = 1, #self.targets do
                self.targets[i]:SetIsVisible(false)
            end
        end
        if self.playerStatusIcons and self.playerStatusIcons.SetIsVisible then
            self.playerStatusIcons:SetIsVisible(not praetor)
        end
        self.vtStripped = praetor
    end
end

-- The marine top bar (team res, RTs, supply, dead, IPs) is replaced by GUIVTTopBar for the Vael'Thor team;
-- vanilla marines (Marines vs. Vael'Thor) keep theirs. The bar's own hide switch is also driven by the
-- scoreboard, which sets it to "scoreboard open?" on every update (GUIScoreboard) and so un-hid the bar again:
-- the live instance's SetIsHiddenOverride is wrapped so the Vael'Thor hide always wins, and it is re-checked
-- every frame.
local function WrapVanillaTopBar(bar)
    if bar.vtWrappedHide then
        return
    end
    bar.vtWrappedHide = true
    local baseSetHidden = bar.SetIsHiddenOverride
    bar.SetIsHiddenOverride = function(self, hidden)
        local forceHidden = VT_GetLocalIsVTTeam and VT_GetLocalIsVTTeam()
        baseSetHidden(self, hidden or forceHidden)
    end
end

local function UpdateVanillaTopBar()
    local bar = ClientUI.GetScript("Hud2/topBar/GUIHudTopBarForLocalTeam")
    if not bar or not bar.SetIsHiddenOverride then
        return
    end
    WrapVanillaTopBar(bar)
    local hide = VT_GetLocalIsVTTeam and VT_GetLocalIsVTTeam() or false
    if hide and bar.visHideOverride ~= true then
        bar:SetIsHiddenOverride(true)
    elseif not hide and bar.vtHiddenByVT and bar.visHideOverride == true then
        bar:SetIsHiddenOverride(false)        -- left the Vael'Thor team: give the bar back
    end
    bar.vtHiddenByVT = hide
end

local function UpdatePraetorCockpit()
    UpdateVanillaTopBar()
    VT_InstallUnitStatusLook()      -- violet unit status + psi shield bar (GUI/GUIVTUnitStatus.lua), lazy
    VT_InstallMinimapLook()         -- Vael'Thor map icons + violet team colours (GUI/GUIVTMinimap.lua), lazy
    VT_UpdateCommanderTheme()       -- violet commander HUD textures for Vael'Thor viewers (GUI/GUIVTCommanderTheme.lua)
    local player = Client.GetLocalPlayer()
    local isPraetor = player ~= nil and player:isa("VTPraetor")
    local now = Shared.GetTime()

    local vanillaCrosshair = ClientUI.GetScript("GUICrosshair")
    if vanillaCrosshair then
        WrapVanillaCrosshair(vanillaCrosshair)
    end

    local exoHud = isPraetor and ClientUI.GetScript("Hud/Marine/GUIExoHUD")
    if exoHud then
        StripExoHUD(exoHud)
    end

    if isPraetor ~= praetorHudHidden or now - praetorHudTime > 1 then
        ClientUI.SetScriptVisibility("GUIExoThruster", "VTPraetor", not isPraetor)
        praetorHudHidden = isPraetor
        praetorHudTime = now
    end

    if not isPraetor then
        praetorCockpit.model = nil
        return
    end
    local viewEnt = player.GetViewModelEntity and player:GetViewModelEntity()
    local model = viewEnt and viewEnt:GetRenderModel()
    if model and model:GetReadyForOverrideMaterials()
            and (praetorCockpit.model ~= model or now - praetorCockpit.time > 1) then
        for _, faceSet in ipairs(kExoCockpitFaceSets) do
            model:SetOverrideMaterial(faceSet, kBladesHiddenMaterial)
        end
        praetorCockpit.model = model
        praetorCockpit.time = now
    end
end

Event.Hook("UpdateRender", UpdatePraetorCockpit)

-- Synthesis Matrix state of this client's dead player (read by GUIVTMatrixMenu;
-- while spectating a teammate the local player is that teammate, so the menu
-- can't read the VTSpectator's fields directly).
VT_MatrixLoadout = nil
Client.HookNetworkMessage("VTMatrixLoadout", function(message)
    VT_MatrixLoadout =
    {
        vtDesiredClass = message.class,
        vtModule       = message.module,
        vtPrimaryMod   = message.primary,
        vtSecondary    = message.secondary,
        readyTime      = message.readyTime,
        armed          = message.armed,
        autoTime       = message.autoTime,
        spawnName      = message.spawnName,
        spawnCount     = message.spawnCount,
    }
end)

-- ----------------------------------------------------------------------------
-- Echo Scan: every frame, each scanning Vael'Thor Infiltrator's cone (from its
-- networked eye position and view angles) is checked against enemy players,
-- structures and eggs. Contacts are outlined through walls with the marine-side
-- outline renderer; when a contact stops being in a held cone its outline fades
-- over kVTEchoScanFadeTime and is removed.
--
-- Fade: the mod ships ui/marine_outline_lookup.dds (art/ui/) whose red band
-- runs from full red at its centre (x = 288, what vanilla samples for red)
-- to black at its end (x = 319). The composite is additive, so sliding a model's
-- "outline" parameter along that gradient fades its outline out. The lookup is
-- 64 px per band: 5 bands (320 px) before the 2026-11-17 game update, 6 (384 px,
-- + Orange) since, so u is taken from vanilla's band count.
-- ----------------------------------------------------------------------------
local kEchoLookupWidth = 64 * (kEquipmentOutlineColorCount or 6)
local kEchoFadeUStart = 288.5 / kEchoLookupWidth
local kEchoFadeUEnd   = 319.5 / kEchoLookupWidth
local kEchoOutlineRed = kEquipmentOutlineColor and kEquipmentOutlineColor.Red or 4

local echoContacts = {}   -- entityId -> { lastSeen, model }

local function ClearEchoOutline(entry)
    if entry.model then
        EquipmentOutline_RemoveModel(entry.model)
        entry.model = nil
    end
end

-- Cloaked units are no longer filtered out: the server detects (uncloaks) everything in a held cone,
-- see VTInfiltrator:VT_UpdateEchoDetection.
local function GetIsEchoTarget(entity)
    return entity:GetIsAlive()
end

local function MarkContactsInCone(scanner, enemyTeam, now)
    VT_ForEachInEchoCone(scanner, function(entity)
        local entry = echoContacts[entity:GetId()]
        if not entry then
            entry = {}
            echoContacts[entity:GetId()] = entry
        end
        entry.lastSeen = now
    end)
end

local function UpdateEchoScan()

    local now = Shared.GetTime()
    local myTeam = Client.GetLocalClientTeamNumber()

    if myTeam == kVTTeamIndex then
        local enemyTeam = GetEnemyTeamNumber(myTeam)
        for _, scanner in ientitylist(Shared.GetEntitiesWithClassname("VTInfiltrator")) do
            if scanner.vtEchoScanning and scanner:GetTeamNumber() == myTeam and scanner:GetIsAlive() then
                MarkContactsInCone(scanner, enemyTeam, now)
            end
        end
    end

    for entityId, entry in pairs(echoContacts) do

        local entity = Shared.GetEntity(entityId)
        local fade = 1 - (now - entry.lastSeen) / kVTEchoScanFadeTime    -- 1 while in a held cone
        local model = fade > 0 and entity and GetIsEchoTarget(entity)
                and entity.GetRenderModel and entity:GetRenderModel()

        if model then
            if entry.model ~= model then
                -- first frame, or the model was rebuilt (evolve, lifeform change)
                ClearEchoOutline(entry)
                entry.model = model
            end
            -- re-applied every frame so other systems can't strip the mask mid-reveal
            EquipmentOutline_AddModel(model, kEchoOutlineRed)
            fade = math.min(fade, 1)
            model:SetMaterialParameter("outline", kEchoFadeUStart + (1 - fade) * (kEchoFadeUEnd - kEchoFadeUStart))
        else
            ClearEchoOutline(entry)
            echoContacts[entityId] = nil
        end

    end

end

Event.Hook("UpdateRender", UpdateEchoScan)

function VT_GetIsEchoContact(entityId)
    return echoContacts[entityId] ~= nil
end

function VT_GetEchoRevealActive()
    return next(echoContacts) ~= nil
end

-- The outline renderer stops at 38 m for players (60 m for commanders). While
-- a reveal is running use the long range so the whole team sees the contacts.
if EquipmentOutline_SyncCamera and not VT_HookedOutlineCamera then
    VT_HookedOutlineCamera = true
    local oldSyncCamera = EquipmentOutline_SyncCamera
    function EquipmentOutline_SyncCamera(rendercamera, forCommander)
        oldSyncCamera(rendercamera, forCommander or VT_GetEchoRevealActive())
    end
end

-- ----------------------------------------------------------------------------
-- Debug: "vt_gatecheck" prints what this client knows about the gate network.
-- ----------------------------------------------------------------------------
Event.Hook("Console_vt_gatecheck", function()

    local player = Client.GetLocalPlayer()
    if not player then
        Shared.Message("[Vael'Thor] no local player")
        return
    end

    local gates = 0
    for _, nexus in ipairs(GetEntitiesForTeam("VTNexus", kVTTeamIndex)) do
        Shared.Message(string.format("[Vael'Thor] Nexus %d: techId=%s built=%s alive=%s gate=%s dist=%.1f",
                nexus:GetId(), EnumToString(kTechId, nexus:GetTechId()), tostring(nexus:GetIsBuilt()),
                tostring(nexus:GetIsAlive()), tostring(VT_GetIsActiveNexusGate(nexus)),
                (nexus:GetOrigin() - player:GetOrigin()):GetLength()))
        if VT_GetIsActiveNexusGate(nexus) then
            gates = gates + 1
        end
    end

    local pylons = GetEntitiesForTeamWithinRange("VTSubventionPylon", kVTTeamIndex, player:GetOrigin(), 5)
    Shared.SortEntitiesByDistance(player:GetOrigin(), pylons)
    local pylon = pylons[1]
    if pylon then
        local canUse = GetPlayerCanUseEntity(player, pylon)
        Shared.Message(string.format("[Vael'Thor] nearest pylon %d: built=%s powered=%s usable=%s gates known=%d",
                pylon:GetId(), tostring(pylon:GetIsBuilt()), tostring(pylon:GetIsPowered()), tostring(canUse), gates))
    else
        Shared.Message(string.format("[Vael'Thor] no pylon within 5 m (gates known=%d)", gates))
    end

end)

-- ----------------------------------------------------------------------------
-- Art test: "vt_model <name> [yaw]" places a static copy of a mod model 3 m in
-- front of you, facing you (optional extra yaw in degrees). "vt_model" alone
-- lists the names. "vt_model_clear" removes all placed copies.
-- Models must be precached at load time, so only the names below work; add new
-- ones to kVTPreviewModels.
-- ----------------------------------------------------------------------------
local kVTPreviewModels = {
    robot          = PrecacheAsset("models/vaelthor/robot/robot.model"),
    robot_player   = PrecacheAsset("models/vaelthor/robot/robot_player.model"),
    sentinel       = PrecacheAsset("models/vaelthor/sentinel/sentinel_player.model"),
    cyber          = PrecacheAsset("models/vaelthor/cyber/cyber_player.model"),
    mecha          = PrecacheAsset("models/vaelthor/mecha/mecha_player.model"),
    stalker        = PrecacheAsset("models/vaelthor/stalker/stalker_player.model"),
    titan          = PrecacheAsset("models/vaelthor/titan/titan_player.model"),
    marine         = PrecacheAsset("models/marine/male/male.model"),
}
local vtPreviewModels = {}

local function VT_PlaceModel(name, yawArg)

    local modelName = name and kVTPreviewModels[name]
    if not modelName then
        local names = {}
        for k in pairs(kVTPreviewModels) do table.insert(names, k) end
        table.sort(names)
        Shared.Message("[Vael'Thor] usage: vt_model <" .. table.concat(names, "|") .. "> [yaw]")
        return
    end

    local player = Client.GetLocalPlayer()
    if not player then
        Shared.Message("[Vael'Thor] no local player")
        return
    end

    local extraYaw = math.rad(tonumber(yawArg) or 0)
    local viewYaw = player:GetViewAngles().yaw
    local forward = Vector(math.sin(viewYaw), 0, math.cos(viewYaw))
    local origin = player:GetOrigin() + forward * 3

    -- snap to the floor below the spot
    local trace = Shared.TraceRay(origin + Vector(0, 1, 0), origin - Vector(0, 5, 0),
            CollisionRep.Move, PhysicsMask.Movement, EntityFilterAll())
    if trace.fraction < 1 then
        origin = trace.endPoint
    end

    local coords = Angles(0, viewYaw + math.pi + extraYaw, 0):GetCoords()
    coords.origin = origin

    local model = Client.CreateRenderModel(RenderScene.Zone_Default)
    model:SetModel(modelName)
    model:SetCoords(coords)
    model:SetIsVisible(true)
    table.insert(vtPreviewModels, model)
    Shared.Message(string.format("[Vael'Thor] %s placed (%d total)", name, #vtPreviewModels))

end

local function VT_ClearModels()
    for _, model in ipairs(vtPreviewModels) do
        Client.DestroyRenderModel(model)
    end
    vtPreviewModels = {}
    Shared.Message("[Vael'Thor] preview models removed")
end

Event.Hook("Console_vt_model", VT_PlaceModel)
Event.Hook("Console_vt_model_clear", VT_ClearModels)
-- old names
Event.Hook("Console_vt_robot", function(yawArg) VT_PlaceModel("robot", yawArg) end)
Event.Hook("Console_vt_robot_clear", VT_ClearModels)
