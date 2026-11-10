-- ============================================================================
-- GUIVTTopBar - Vael'Thor replacement for the marine top bar (hidden for the Vael'Thor team in Client.lua).
-- Shown to every member of the Vael'Thor team (soldiers, dead soldiers in the Synthesis Matrix, commander).
--
--   top row:   RESOURCES (+income/min) | NEXUS | SIPHONS | PYLONS | IN MATRIX | CASTES Inf/Sub/Pra vs quota
--   below:     RESEARCH - up to three running researches/upgrades: name, progress bar, %, time left
--
-- Data comes from VTEmpireInfo (always relevant, filled by VTTeam:UpdateEmpireStatus on the server), so it
-- covers structures anywhere on the map. Textures: the HUD's ui/vaelthor/hud_*.dds, tinted here.
-- ============================================================================

class 'GUIVTTopBar' (GUIScript)

local kPanelTex = PrecacheAsset("ui/vaelthor/hud_panel.dds")
local kBarTex   = PrecacheAsset("ui/vaelthor/hud_bar.dds")
local kBarTexW, kBarTexH = 256, 24

local kColPanel  = Color(1, 1, 1, 0.92)
local kColLabel  = Color(0.62, 0.52, 0.78, 1)
local kColValue  = Color(0.92, 0.85, 1.00, 1)
local kColIncome = Color(0.55, 1.00, 0.85, 1)
local kColWarn   = Color(1.00, 0.55, 0.55, 1)
local kColFull   = Color(1.00, 0.85, 1.00, 1)
local kColEnergy = Color(0.78, 0.45, 1.00, 1)
local kColEmpty  = Color(0.22, 0.12, 0.34, 0.75)

local kTopY = 12
local kBarW, kBarH = 820, 46
-- column widths of the top row (sum = kBarW - 2 * kPad)
local kPad = 22
local kColumns = { { "res", 200 }, { "nexus", 92 }, { "siphons", 98 }, { "pylons", 92 }, { "matrix", 104 }, { "castes", 190 } }
local kResW, kResRowH, kResHeadH = 470, 24, 26
local kMaxRows = 3

local kCastes = { { "Infiltrator", "INF" }, { "Subject", "SUB" }, { "Praetor", "PRA" } }

local function S(x, y) return GUIScale(Vector(x, y, 0)) end

function GUIVTTopBar:Graphic(parent, tex, w, h, x, y, color, layer)
    local item = GUIManager:CreateGraphicItem()
    if tex then item:SetTexture(tex) end
    item:SetSize(S(w, h))
    item:SetPosition(S(x, y))
    item:SetColor(color or Color(1, 1, 1, 1))
    item:SetLayer(layer or kGUILayerPlayerHUD)
    if parent then parent:AddChild(item) else self.roots[#self.roots + 1] = item end
    return item
end

function GUIVTTopBar:Text(parent, font, x, y, alignX, color)
    local t = GUIManager:CreateTextItem()
    t:SetFontName(font)
    t:SetScale(GetScaledVector())
    GUIMakeFontScale(t)
    t:SetTextAlignmentX(alignX or GUIItem.Align_Min)
    t:SetTextAlignmentY(GUIItem.Align_Center)
    t:SetPosition(S(x, y))
    t:SetColor(color or kColValue)
    t:SetLayer(kGUILayerPlayerHUDForeground3)
    parent:AddChild(t)
    return t
end

local function SetBar(bar, frac, color)
    frac = Clamp(frac or 0, 0, 1)
    bar.fill:SetIsVisible(frac > 0.002)
    bar.fill:SetSize(S(bar.w * frac, bar.h))
    bar.fill:SetTexturePixelCoordinates(0, 0, kBarTexW * frac, kBarTexH)
    if color then bar.fill:SetColor(color) end
end

function GUIVTTopBar:Initialize()

    self.updateInterval = 0.1
    self.roots = {}

    -- ---- top row
    self.bar = self:Graphic(nil, kPanelTex, kBarW, kBarH, 0, 0, kColPanel)
    self.bar:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.bar:SetPosition(S(-kBarW / 2, kTopY))
    self.cells = {}
    local x = kPad
    for _, col in ipairs(kColumns) do
        local name, w = col[1], col[2]
        self.cells[name] = {
            label = self:Text(self.bar, Fonts.kAgencyFB_Tiny, x, 14, nil, kColLabel),
            value = self:Text(self.bar, Fonts.kAgencyFB_Small, x, 31, nil, kColValue),
        }
        x = x + w
    end
    self.cells.res.label:SetText("RESOURCES")
    self.cells.nexus.label:SetText("NEXUS")
    self.cells.siphons.label:SetText("SIPHONS")
    self.cells.pylons.label:SetText("PYLONS")
    self.cells.matrix.label:SetText("IN MATRIX")
    self.cells.castes.label:SetText("CASTES / QUOTA")

    -- ---- research panel (height follows the number of rows)
    self.research = self:Graphic(nil, kPanelTex, kResW, kResHeadH + kResRowH, 0, 0, kColPanel)
    self.research:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.research:SetPosition(S(-kResW / 2, kTopY + kBarH + 6))
    self.researchHead = self:Text(self.research, Fonts.kAgencyFB_Tiny, 18, 14, nil, kColLabel)
    self.researchHead:SetText("RESEARCH")
    self.rows = {}
    for i = 1, kMaxRows do
        local y = kResHeadH + (i - 1) * kResRowH + kResRowH / 2 - 2
        local back = self:Graphic(self.research, kBarTex, 150, 9, 210, y - 4, kColEmpty, kGUILayerPlayerHUDForeground1)
        local fill = self:Graphic(self.research, kBarTex, 150, 9, 210, y - 4, kColEnergy, kGUILayerPlayerHUDForeground2)
        self.rows[i] = {
            name = self:Text(self.research, Fonts.kAgencyFB_Small, 18, y, nil, kColValue),
            bar  = { back = back, fill = fill, w = 150, h = 9 },
            info = self:Text(self.research, Fonts.kAgencyFB_Small, kResW - 18, y, GUIItem.Align_Max, kColLabel),
        }
    end

    self.visible = true
    self:SetVisible(false)

end

function GUIVTTopBar:Uninitialize()
    for _, item in ipairs(self.roots or {}) do
        GUI.DestroyItem(item)
    end
    self.roots = {}
end

function GUIVTTopBar:OnResolutionChanged()
    self:Uninitialize()
    self:Initialize()
end

function GUIVTTopBar:SetVisible(visible)
    if self.visible == visible then return end
    self.visible = visible
    for _, item in ipairs(self.roots) do
        item:SetIsVisible(visible)
    end
end

-- Any member of the Vael'Thor team (also while dead or commanding).
function VT_GetLocalIsVTTeam()
    return kVTTeamIndex ~= kVTNoTeam and Client.GetLocalClientTeamNumber() == kVTTeamIndex
end

local function TechName(techId)
    local key = LookupTechData(techId, kTechDataDisplayName, EnumToString(kTechId, techId))
    return string.upper(Locale.ResolveString(key) or key)
end

local function FormatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function GUIVTTopBar:UpdateTopRow(info)
    local res = math.floor(PlayerUI_GetTeamResources and PlayerUI_GetTeamResources() or 0)
    local income = info.statusSiphons * kTeamResourcePerTick * 60 / kResourceTowerResourceInterval
    self.cells.res.value:SetText(string.format("%d   +%d/min", res, income))
    self.cells.res.value:SetColor(income > 0 and kColValue or kColWarn)

    self.cells.nexus.value:SetText(tostring(info.statusNexus))
    self.cells.nexus.value:SetColor(info.statusNexus > 0 and kColValue or kColWarn)
    self.cells.siphons.value:SetText(tostring(info.statusSiphons))
    self.cells.pylons.value:SetText(tostring(info.statusPylons))
    self.cells.matrix.value:SetText(tostring(info.statusMatrix))
    self.cells.matrix.value:SetColor(info.statusMatrix > 0 and kColIncome or kColValue)

    local parts = {}
    local anyFull = false
    for _, c in ipairs(kCastes) do
        local count, quota = info:GetCount(c[1]), info:GetQuota(c[1])
        parts[#parts + 1] = string.format("%s %d/%d", c[2], count, quota)
        anyFull = anyFull or (quota > 0 and count >= quota)
    end
    self.cells.castes.value:SetText(table.concat(parts, "   "))
    self.cells.castes.value:SetColor(anyFull and kColFull or kColValue)
end

function GUIVTTopBar:UpdateResearch(info)
    local list = info:GetResearch()
    self.research:SetIsVisible(#list > 0)
    if #list == 0 then return end
    self.research:SetSize(S(kResW, kResHeadH + #list * kResRowH + 6))
    for i, row in ipairs(self.rows) do
        local r = list[i]
        row.name:SetIsVisible(r ~= nil)
        row.info:SetIsVisible(r ~= nil)
        row.bar.back:SetIsVisible(r ~= nil)
        if r then
            row.name:SetText(TechName(r.techId))
            SetBar(row.bar, r.progress, kColEnergy)
            local total = LookupTechData(r.techId, kTechDataResearchTimeKey, 0)
            if total > 0 then
                row.info:SetText(string.format("%3d%%   %s", math.floor(r.progress * 100), FormatTime((1 - r.progress) * total)))
            else
                row.info:SetText(string.format("%3d%%", math.floor(r.progress * 100)))
            end
        else
            row.bar.fill:SetIsVisible(false)
        end
    end
end

function GUIVTTopBar:Update(deltaTime)
    PROFILE("GUIVTTopBar:Update")
    local info = VT_GetEmpireInfo and VT_GetEmpireInfo()
    local show = info ~= nil and VT_GetLocalIsVTTeam() and not MainMenu_GetIsOpened()
    self:SetVisible(show)
    if not show then return end
    self:UpdateTopRow(info)
    self:UpdateResearch(info)
end
