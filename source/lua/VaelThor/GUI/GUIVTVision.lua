-- ============================================================================
-- GUIVTVision - Targeting Visor (replaces the flashlight on every caste).
--
-- Needs the Shield Generator research VTTargetingVisorTech. The flashlight key
-- (the key aliens use for alien vision) toggles it. While on:
--   * a faint violet tint over the screen,
--   * every enemy (players, structures, eggs) in the player's OWN line of
--     sight within kVTVisorRange gets the exosuit HUD's targeting reticle,
--     (units with ANY cloak, partial or full, are never marked)
--     pulsing, plus a purple through-the-outline-renderer outline,
--   * the mark closest to the crosshair gets the exosuit lock-on crosshair.
-- Purely client-side and personal: nothing is shared with the team.
-- ============================================================================

class 'GUIVTVision' (GUIScript)

local kSheet               = PrecacheAsset("ui/exosuit_HUD1.dds")
local kReticleCoords       = { 185, 0, 354, 184 }    -- exosuit HUD targeting reticle
local kLockCoords          = { 495, 403, 639, 547 }  -- exosuit HUD lock-on crosshair
local kToggleSound         = PrecacheAsset("sound/NS2.fev/common/light")   -- the flashlight click

local kTintColor           = Color(0.55, 0.25, 1.0, 0.09)
local kMarkColor           = Color(0.80, 0.55, 1.0, 1)
local kLockRadius          = 80      -- px from screen centre for the lock-on crosshair
local kOutlineColor        = kEquipmentOutlineColor and kEquipmentOutlineColor.Fuchsia or 2

local function CoordsSize(c)
    return Vector(c[3] - c[1], c[4] - c[2], 0)
end

local function GetVisorPlayer()
    if not Client.GetIsControllingPlayer() then
        return nil
    end
    local player = Client.GetLocalPlayer()
    if not player or player:GetTeamNumber() ~= kVTTeamIndex or not player:GetIsAlive()
            or player:isa("Commander") or not (player:isa("Marine") or player:isa("Exo")) then
        return nil
    end
    if not VT_GetTeamHasTech("VTTargetingVisorTech") then
        return nil
    end
    return player
end

function GUIVTVision:Initialize()

    self.updateInterval = 0     -- every frame: marks follow moving targets
    self.enabled = false
    self.marks = {}             -- pooled reticle items
    self.outlined = {}          -- entityId -> model

    self.tint = GUIManager:CreateGraphicItem()
    self.tint:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.tint:SetPosition(Vector(0, 0, 0))
    self.tint:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))
    self.tint:SetColor(kTintColor)
    self.tint:SetLayer(kGUILayerPlayerHUD - 2)
    self.tint:SetIsVisible(false)

    self.lock = GUIManager:CreateGraphicItem()
    self.lock:SetTexture(kSheet)
    self.lock:SetTexturePixelCoordinates(GUIUnpackCoords(kLockCoords))
    self.lock:SetLayer(kGUILayerPlayerHUDForeground1)
    self.lock:SetIsVisible(false)

end

function GUIVTVision:ClearOutlines()
    for entityId, model in pairs(self.outlined) do
        local entity = Shared.GetEntity(entityId)
        if entity and entity.GetRenderModel and entity:GetRenderModel() == model then
            EquipmentOutline_RemoveModel(model)
        end
        self.outlined[entityId] = nil
    end
end

function GUIVTVision:Uninitialize()
    self:ClearOutlines()
    for _, item in ipairs(self.marks) do
        GUI.DestroyItem(item)
    end
    self.marks = {}
    if self.tint then GUI.DestroyItem(self.tint); self.tint = nil end
    if self.lock then GUI.DestroyItem(self.lock); self.lock = nil end
end

function GUIVTVision:OnResolutionChanged(oldX, oldY, newX, newY)
    local enabled = self.enabled
    self:Uninitialize()
    self:Initialize()
    self.enabled = enabled
end

function GUIVTVision:SendKeyEvent(key, down)
    if down and GetIsBinding(key, "ToggleFlashlight") and GetVisorPlayer()
            and not (GetIsTextBeingEntered and GetIsTextBeingEntered()) then
        self.enabled = not self.enabled
        StartSoundEffect(kToggleSound)
    end
    return false
end

local function GetFreeMark(self, index)
    local item = self.marks[index]
    if not item then
        item = GUIManager:CreateGraphicItem()
        item:SetTexture(kSheet)
        item:SetTexturePixelCoordinates(GUIUnpackCoords(kReticleCoords))
        item:SetLayer(kGUILayerPlayerHUDForeground1)
        self.marks[index] = item
    end
    item:SetIsVisible(true)
    return item
end

-- Any cloak at all hides a unit from the visor: GetIsCloaked() is only true once
-- fully cloaked, so also check the networked cloakingDesired flag and the
-- client-side fraction (moving camouflage, a Shade fading in, partial cloak).
local function GetHasAnyCloak(entity)
    return HasMixin(entity, "Cloakable")
            and (entity:GetIsCloaked() or entity.cloakingDesired or (entity:GetCloakFraction() or 0) > 0)
end

local function GetIsInSight(player, eyePos, entity, point)
    if GetHasAnyCloak(entity) then
        return false
    end
    local trace = Shared.TraceRay(eyePos, point, CollisionRep.LOS, PhysicsMask.All, EntityFilterOne(player))
    return trace.fraction == 1 or trace.entity == entity
end

function GUIVTVision:Update(deltaTime)

    PROFILE("GUIVTVision:Update")

    local player = GetVisorPlayer()
    local active = self.enabled and player ~= nil
    self.tint:SetIsVisible(active)

    local used = 0
    local seen = {}
    local lockPos, lockDist, lockScale = nil, math.huge, 1

    if active then

        local now = Shared.GetTime()
        local pulse = 0.85 + 0.15 * math.sin(now * 6)
        local eyePos = player:GetEyePos()
        local viewDir = player:GetViewCoords().zAxis
        local centre = Vector(Client.GetScreenWidth() / 2, Client.GetScreenHeight() / 2, 0)
        local enemyTeam = GetEnemyTeamNumber(player:GetTeamNumber())

        for _, entity in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, eyePos, kVTVisorRange)) do

            local point = entity.GetModelOrigin and entity:GetModelOrigin() or entity:GetOrigin()
            local toEntity = point - eyePos
            local distance = math.max(toEntity:GetLength(), 0.5)

            if entity:GetIsAlive() and viewDir:DotProduct(toEntity) > 0 and GetIsInSight(player, eyePos, entity, point) then

                -- exosuit HUD reticle, sized by model extents and distance, pulsing
                local scalar = 0.6
                if entity.GetModelExtents then
                    local _, max = entity:GetModelExtents()
                    scalar = Clamp(max:GetLength() / distance * 8, 0.25, 3)
                end
                local size = CoordsSize(kReticleCoords) * scalar * pulse
                local screenPos = Client.WorldToScreen(point)
                used = used + 1
                local item = GetFreeMark(self, used)
                item:SetSize(size)
                item:SetPosition(screenPos - size / 2)
                local fade = 1 - Clamp((distance / kVTVisorRange - 0.8) / 0.2, 0, 1)   -- fade out at max range
                item:SetColor(Color(kMarkColor.r, kMarkColor.g, kMarkColor.b, 0.9 * fade))

                local toCentre = (screenPos - centre):GetLength()
                if toCentre < lockDist then
                    lockPos, lockDist, lockScale = screenPos, toCentre, scalar
                end

                -- purple outline (the Echo Scan's red outline wins on shared targets)
                local entityId = entity:GetId()
                local model = entity.GetRenderModel and entity:GetRenderModel()
                if model and not (VT_GetIsEchoContact and VT_GetIsEchoContact(entityId)) then
                    if self.outlined[entityId] and self.outlined[entityId] ~= model then
                        EquipmentOutline_RemoveModel(self.outlined[entityId])
                    end
                    EquipmentOutline_AddModel(model, kOutlineColor)
                    self.outlined[entityId] = model
                    seen[entityId] = true
                end

            end

        end

    end

    for i = used + 1, #self.marks do
        self.marks[i]:SetIsVisible(false)
    end

    -- drop outlines of targets no longer in sight
    for entityId, model in pairs(self.outlined) do
        if not seen[entityId] then
            local entity = Shared.GetEntity(entityId)
            if entity and entity.GetRenderModel and entity:GetRenderModel() == model
                    and not (VT_GetIsEchoContact and VT_GetIsEchoContact(entityId)) then
                EquipmentOutline_RemoveModel(model)
            end
            self.outlined[entityId] = nil
        end
    end

    -- exosuit lock-on crosshair on the mark nearest the screen centre
    if lockPos and lockDist < kLockRadius then
        local size = CoordsSize(kLockCoords) * lockScale * (0.75 + 0.25 * ((math.sin(Shared.GetTime() * 7) + 1) / 2))
        self.lock:SetSize(size)
        self.lock:SetPosition(lockPos - size / 2)
        self.lock:SetColor(kMarkColor)
        self.lock:SetIsVisible(true)
    else
        self.lock:SetIsVisible(false)
    end

end

function GUIVTVision:GetIsActive()
    return self.enabled and GetVisorPlayer() ~= nil
end
