-- ============================================================================
-- Vael'Thor commander HUD theme: the marine commander GUI with violet textures
-- (output/ui/vaelthor/commander/*.dds, art/ui/commander/build_commander_theme.sh - hue-shifted copies with
-- identical layout, so all of vanilla's pixel coordinates still fit).
--
-- Only for viewers on the Vael'Thor team: vanilla marines (Vael'Thor vs. Marines) share the marine team type
-- and keep their look. The commander GUI scripts read their texture constants when they initialise (on
-- login), so the constants are switched per viewer every frame (VT_UpdateCommanderTheme from Client.lua);
-- the two scripts that pick their texture inside Initialize (selection panel, minimap frame) are re-textured
-- right after it. Icons: Hooks/TechTreeButtons.lua (extended ui/buildmenu.dds).
-- ============================================================================

local kVTDir = "ui/vaelthor/commander/"
local kVTFrame = PrecacheAsset(kVTDir .. "marine_commander_textures.dds")
local kVTLogout = PrecacheAsset(kVTDir .. "marine_commander_logout.dds")
local kVTTabs = PrecacheAsset(kVTDir .. "marine_commander_tabs.dds")
local kVTAlertBadge = PrecacheAsset(kVTDir .. "commander_alert_badge.dds")
local kMarineFrame = "ui/marine_commander_textures.dds"

-- class name, field, Vael'Thor texture
local kConstantSwaps =
{
    { "GUICommanderButtonsMarines", "kBackgroundTexture",        kVTFrame },
    { "GUICommanderButtons",        "kMarineTabBackgroundTexture", kVTTabs },
    { "GUICommanderTooltip",        "kMarineBackgroundTexture",  kVTFrame },
    { "GUIResourceDisplay",         "kBackgroundTextureMarine",  kVTFrame },
    { "GUICommanderLogout",         "kLogoutMarineTextureName",  kVTLogout },
    { "GUICommanderAlerts",         "kAlertBadgeTextureName",    kVTAlertBadge },
}
local kOriginals = {}      -- "Class.field" -> vanilla value

local kVTHealthBar = Color(0.95, 0.45, 0.75, 1)
local kVTArmorBar  = Color(0.72, 0.50, 1.00, 1)
local kOriginalBarColors

local function LocalIsVT()
    return VT_GetLocalIsVTTeam and VT_GetLocalIsVTTeam()
end

local function UpdateConstants(vt)
    for _, swap in ipairs(kConstantSwaps) do
        local cls = rawget(_G, swap[1])
        if cls then
            local key = swap[1] .. "." .. swap[2]
            if kOriginals[key] == nil and cls[swap[2]] ~= swap[3] then
                kOriginals[key] = cls[swap[2]]
            end
            local want = vt and swap[3] or kOriginals[key]
            if want ~= nil and cls[swap[2]] ~= want then
                cls[swap[2]] = want
            end
        end
    end

    -- selection panel health / armor bars (keyed by team type; marine = cyan)
    if GUISelectionPanel and GUISelectionPanel.kHealthBarColors then
        if not kOriginalBarColors then
            kOriginalBarColors = { GUISelectionPanel.kHealthBarColors[kMarineTeamType],
                                   GUISelectionPanel.kArmorBarColors[kMarineTeamType] }
        end
        GUISelectionPanel.kHealthBarColors[kMarineTeamType] = vt and kVTHealthBar or kOriginalBarColors[1]
        GUISelectionPanel.kArmorBarColors[kMarineTeamType] = vt and kVTArmorBar or kOriginalBarColors[2]
    end
end

-- selection panel: picks GUISelectionPanel.kSelectionTextureMarines inside Initialize (it resets the constant
-- there first), so its items are re-textured right after
local function WrapSelectionPanel()
    if not GUISelectionPanel or VT_WrappedSelectionPanel then
        return
    end
    VT_WrappedSelectionPanel = true
    local base = GUISelectionPanel.Initialize
    function GUISelectionPanel:Initialize(...)
        local result = base(self, ...)
        if LocalIsVT() and self.textureName == kMarineFrame then
            self.textureName = kVTFrame
            for _, name in ipairs({ "background", "healthIcon", "armorIcon", "energyIcon", "researchBarBg" }) do
                if self[name] then
                    self[name]:SetTexture(kVTFrame)
                end
            end
        end
        return result
    end
end

-- minimap frame: file-local texture, re-applied whenever the HUD detail setting changes
local function WrapMinimapFrame()
    if not GUIMinimapFrame or VT_WrappedMinimapFrameTheme then
        return
    end
    VT_WrappedMinimapFrameTheme = true
    local base = GUIMinimapFrame.Update
    function GUIMinimapFrame:Update(deltaTime)
        local result = base(self, deltaTime)
        local frame = self.minimapFrame
        if frame and LocalIsVT() and self.cachedHudDetail ~= kHUDMode.Minimal then
            if self.vtThemedDetail ~= self.cachedHudDetail then
                frame:SetTexture(kVTFrame)
                self.vtThemedDetail = self.cachedHudDetail
            end
        elseif frame and self.vtThemedDetail ~= nil then
            frame:SetTexture(self.cachedHudDetail == kHUDMode.Minimal and "ui/transparent.dds" or kMarineFrame)
            self.vtThemedDetail = nil
        end
        return result
    end
end

function VT_UpdateCommanderTheme()
    if LocalIsVT() then
        VT_Breadcrumb("commander_theme", "commander theme: switching textures to Vael'Thor")
    end
    UpdateConstants(LocalIsVT())
    WrapSelectionPanel()
    WrapMinimapFrame()
end
