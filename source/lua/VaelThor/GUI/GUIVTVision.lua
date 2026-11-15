-- ============================================================================
-- GUIVTVision - Targeting Visor (replaces the flashlight on every caste).
--
-- Free for every Vael'Thor soldier (no research since 2026-11-15). The flashlight
-- key (the key aliens use for alien vision) toggles it. While on:
--   * a violet heat scanner: the screen effect shaders/VTHeatVision.screenfx (a
--     violet rework of the alien vision shader) darkens and desaturates the world
--     to violet and makes every entity glow as a heat signature, with a slow
--     scanline; a plain violet tint is the fallback if the effect can't be created,
--   * every enemy (players, structures, eggs) in the player's OWN line of sight
--     within kVTVisorRange gets a purple through-the-walls outline (units with
--     ANY cloak, partial or full, are never marked).
-- No reticles / lock-on circles any more. Purely client-side and personal.
-- ============================================================================

class 'GUIVTVision' (GUIScript)

local kToggleSound         = PrecacheAsset("sound/NS2.fev/common/light")   -- the flashlight click
local kHeatVisionEffect    = "shaders/VTHeatVision.screenfx"
local kFadeTime            = 0.2     -- s, effect fade in / out

local kTintColor           = Color(0.55, 0.25, 1.0, 0.18)   -- fallback without the screen effect
local kOutlineColor        = kEquipmentOutlineColor and kEquipmentOutlineColor.Fuchsia or 2

-- one screen effect per client session (like vanilla Player.screenEffects.darkVision)
local function GetHeatVisionEffect()
    if VT_HeatVisionEffect == nil then
        local ok, effect = pcall(Client.CreateScreenEffect, kHeatVisionEffect)
        VT_HeatVisionEffect = (ok and effect) or false
        if VT_HeatVisionEffect then
            VT_HeatVisionEffect:SetActive(false)
        else
            Shared.Message("[Vael'Thor] visor: heat vision effect unavailable, using the plain tint")
        end
    end
    return VT_HeatVisionEffect or nil
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
    return player
end

function GUIVTVision:Initialize()

    self.updateInterval = 0     -- every frame: outlines follow moving targets, effect fades
    self.enabled = false
    self.outlined = {}          -- entityId -> model
    self.fade = 0
    self.startTime = 0

    self.tint = GUIManager:CreateGraphicItem()
    self.tint:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.tint:SetPosition(Vector(0, 0, 0))
    self.tint:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))
    self.tint:SetColor(kTintColor)
    self.tint:SetLayer(kGUILayerPlayerHUD - 2)
    self.tint:SetIsVisible(false)

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
    local effect = GetHeatVisionEffect()
    if effect then
        effect:SetActive(false)
    end
    if self.tint then GUI.DestroyItem(self.tint); self.tint = nil end
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
        if self.enabled then
            self.startTime = Shared.GetTime()
        end
        StartSoundEffect(kToggleSound)
    end
    return false
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
    local now = Shared.GetTime()

    -- heat scanner screen effect, faded in / out (the tint only if the effect is unavailable)
    self.fade = Clamp(self.fade + (active and 1 or -1) * deltaTime / kFadeTime, 0, 1)
    local effect = GetHeatVisionEffect()
    if effect then
        effect:SetActive(self.fade > 0)
        effect:SetParameter("amount", self.fade)
        effect:SetParameter("startTime", self.startTime)
        effect:SetParameter("time", now)
        self.tint:SetIsVisible(false)
    else
        self.tint:SetIsVisible(active)
    end

    local seen = {}

    if active then

        local eyePos = player:GetEyePos()
        local viewDir = player:GetViewCoords().zAxis
        local enemyTeam = GetEnemyTeamNumber(player:GetTeamNumber())

        for _, entity in ipairs(GetEntitiesWithMixinForTeamWithinRange("Live", enemyTeam, eyePos, kVTVisorRange)) do

            local point = entity.GetModelOrigin and entity:GetModelOrigin() or entity:GetOrigin()
            local toEntity = point - eyePos

            if entity:GetIsAlive() and viewDir:DotProduct(toEntity) > 0 and GetIsInSight(player, eyePos, entity, point) then

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

end

function GUIVTVision:GetIsActive()
    return self.enabled and GetVisorPlayer() ~= nil
end
