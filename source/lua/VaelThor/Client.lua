-- ============================================================================
-- Vael'Thor Empire - client entry point
-- ============================================================================

-- Faction matchup of this map (sent by the server on connect, Server.lua).
Script.Load("lua/VaelThor/VTMatchupVote.lua")
Client.HookNetworkMessage("VTMatchup", function(message)
    VT_ApplyMatchup(message.matchup)
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
Script.Load("lua/VaelThor/GUI/GUIVTGateMenu.lua")
Script.Load("lua/VaelThor/GUI/GUIVTMatrixMenu.lua")
Script.Load("lua/VaelThor/GUI/GUIVTVision.lua")
Script.Load("lua/VaelThor/GUI/GUIVTPlayerHUD.lua")
Script.Load("lua/VaelThor/GUI/GUIVTCrosshair.lua")
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
            VT_TopBarScript = manager:CreateGUIScript("VaelThor/GUI/GUIVTTopBar")
        end
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
    SetShieldMaterial(glow, "model", "material", model, kVTShieldGlowMaterial, intensity)

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
-- Infiltrator blades (cyber_player.model), Subject claws (mecha_player.model).
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
-- vanilla marines (Vael'Thor vs. Marines) keep theirs. The bar's own hide switch is also driven by the
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
-- runs from full red at its centre (u = 288/320, what vanilla samples for red)
-- to black at its end. The composite is additive, so sliding a model's
-- "outline" parameter along that gradient fades its outline out.
-- ----------------------------------------------------------------------------
local kEchoFadeUStart = 288.5 / 320
local kEchoFadeUEnd   = 319.5 / 320
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
