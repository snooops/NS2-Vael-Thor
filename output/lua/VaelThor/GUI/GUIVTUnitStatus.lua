-- ============================================================================
-- Vael'Thor look for the aimed-at unit status (vanilla GUIUnitStatus / UnitStatusMixin).
--
--   * data: PlayerUI_GetStatusInfoForUnit is wrapped so units with a psi shield (vtShield / vtMaxShield,
--     networked, Classes/VTShield.lua) carry VTShieldFraction, and their "health/armor" text gets the shield
--     value appended - only for viewers on the Vael'Thor team, aliens keep the vanilla numbers.
--   * look: GUIUnitStatus:UpdateUnitStatusBlip is wrapped; for Vael'Thor viewers the bars, name and status
--     backdrop of friendly / neutral units are recoloured violet (vanilla keys them by team type, marine blue)
--     and a violet shield bar is drawn above the health bar (child of it, so it hides with it).
-- GUIUnitStatus is only loaded once the HUD creates it, so the wrapping is applied lazily (VT_InstallUnitStatusLook).
-- ============================================================================

local kShieldBarTex = PrecacheAsset("ui/vaelthor/hud_bar.dds")
local kShieldBarTexW, kShieldBarTexH = 256, 24

local kColHealth     = Color(0.95, 0.32, 0.58, 1)
local kColHealthBg   = Color(0.30, 0.08, 0.20, 0.85)
local kColArmor      = Color(0.72, 0.68, 0.84, 1)
local kColArmorBg    = Color(0.18, 0.15, 0.26, 0.85)
local kColShield     = Color(0.72, 0.42, 1.00, 1)
local kColShieldBg   = Color(0.20, 0.10, 0.32, 0.85)
local kColName       = Color(0.86, 0.70, 1.00, 1)
local kColStatusTint = Color(0.85, 0.60, 1.00, 1)

local function LocalIsVT()
    return VT_GetLocalIsVTTeam and VT_GetLocalIsVTTeam()
end

-- ---- data ----------------------------------------------------------------------
local function WrapStatusInfo()
    if not PlayerUI_GetStatusInfoForUnit or VT_WrappedStatusInfo then
        return
    end
    VT_WrappedStatusInfo = true
    local base = PlayerUI_GetStatusInfoForUnit
    function PlayerUI_GetStatusInfoForUnit(player, unit)
        local state = base(player, unit)
        if state and unit.vtMaxShield and unit.vtMaxShield > 0 and LocalIsVT() and not GetAreEnemies(player, unit) then
            local shield = math.max(0, unit.vtShield or 0)
            state.VTShieldFraction = Clamp(shield / unit.vtMaxShield, 0, 1)
            if state.HealthAndArmorFraction and state.HealthAndArmorFraction ~= "" then
                state.HealthAndArmorFraction = string.format("%s  |  %d psi", state.HealthAndArmorFraction, math.ceil(shield))
            end
        end
        return state
    end
end

-- ---- look ----------------------------------------------------------------------
local function EnsureShieldBar(blip)
    if blip.VTShieldBarBg then
        return
    end
    VT_Breadcrumb("unitstatus_bar", "unit status: creating a shield bar")
    local size = blip.HealthBarBg:GetSize()
    local h = math.max(2, math.floor(size.y * 0.6))
    local bg = GUIManager:CreateGraphicItem()
    bg:SetTexture(kShieldBarTex)
    bg:SetSize(Vector(size.x, h, 0))
    bg:SetPosition(Vector(0, -h - GUIScale(2), 0))
    bg:SetColor(kColShieldBg)
    bg:SetLayer(kGUILayerPlayerNameTags)
    local fill = GUIManager:CreateGraphicItem()
    fill:SetTexture(kShieldBarTex)
    fill:SetSize(Vector(size.x, h, 0))
    fill:SetColor(kColShield)
    fill:SetBlendTechnique(GUIItem.Add)
    bg:AddChild(fill)
    blip.HealthBarBg:AddChild(bg)
    blip.VTShieldBarBg, blip.VTShieldBar, blip.VTShieldW, blip.VTShieldH = bg, fill, size.x, h
end

local function ApplyLook(self, blipIndex)
    local blip = self.activeBlipList and self.activeBlipList[blipIndex]
    local data = self.activeStatusInfo and self.activeStatusInfo[blipIndex]
    if not blip or not data then
        return
    end

    local vt = LocalIsVT()
    local enemyPlayer = data.IsPlayer and not data.IsFriend
    if vt and not enemyPlayer then
        blip.HealthBar:SetColor(kColHealth)
        blip.HealthBarBg:SetColor(kColHealthBg)
        blip.ArmorBar:SetColor(kColArmor)
        blip.ArmorBarBg:SetColor(kColArmorBg)
        if data.IsFriend then
            blip.NameText:SetColor(kColName)
            local status = blip.statusBg
            if status then
                status:SetColor(kColStatusTint)
            end
        end
    end

    local frac = vt and data.VTShieldFraction
    if frac then
        EnsureShieldBar(blip)
        blip.VTShieldBarBg:SetIsVisible(true)
        blip.VTShieldBar:SetIsVisible(frac > 0.002)
        blip.VTShieldBar:SetSize(Vector(blip.VTShieldW * frac, blip.VTShieldH, 0))
        blip.VTShieldBar:SetTexturePixelCoordinates(0, 0, kShieldBarTexW * frac, kShieldBarTexH)
    elseif blip.VTShieldBarBg then
        blip.VTShieldBarBg:SetIsVisible(false)
    end
end

local function WrapUnitStatus()
    if not GUIUnitStatus or VT_WrappedUnitStatus then
        return
    end
    VT_WrappedUnitStatus = true
    local base = GUIUnitStatus.UpdateUnitStatusBlip
    function GUIUnitStatus:UpdateUnitStatusBlip(blipIndex, ...)
        base(self, blipIndex, ...)
        ApplyLook(self, blipIndex)
    end
end

function VT_InstallUnitStatusLook()
    WrapStatusInfo()
    WrapUnitStatus()
end
