-- ============================================================================
-- GUIVTDroneBay - the Artificer's drone control interface (see VTArtificer in Classes/VTPlayers.lua and VTDrone in
-- Classes/VTDrones.lua). Global VT_DroneBayScript, created in Client.lua.
--
-- Compact pass (2026-11-17, user: "the HUD is a bit overloaded, make it more clean"):
--   bottom centre: one slim panel
--     header  - drones in the field / bay size, the fabrication queue as coloured pips, core energy + thin bar
--               (the Artificer has no weapon panel: the core energy lives here)
--     3 cards - per drone type: key + name, alive count (+ orders), build bar while it is in production,
--               directive (coloured) and cost (red if the core can't pay)
--   one notice line above the panel: the key help for the first seconds after spawning, then short notices
--   (directive changed + what it means, bay full)
--   in the world: a pulsing frame on the mark, a small type-coloured marker + health bar over every own drone
-- Same psionic crystal textures as GUIVTPlayerHUD (ui/vaelthor/hud_*.dds).
-- ============================================================================

class 'GUIVTDroneBay' (GUIScript)

local kPanelTex = PrecacheAsset("ui/vaelthor/hud_panel.dds")
local kChipTex  = PrecacheAsset("ui/vaelthor/hud_chip.dds")
local kBarTex   = PrecacheAsset("ui/vaelthor/hud_bar.dds")
local kBarTexW, kBarTexH = 256, 24

local kColPanel  = Color(1, 1, 1, 0.92)
local kColBody   = Color(0.07, 0.03, 0.12, 0.72)
local kColText   = Color(0.88, 0.80, 1.00, 1)
local kColDim    = Color(0.62, 0.52, 0.78, 1)
local kColEnergy = Color(0.78, 0.45, 1.00, 1)
local kColEmpty  = Color(0.22, 0.12, 0.34, 0.75)
local kColReady  = Color(0.55, 1.00, 0.85, 1)
local kColWarn   = Color(1.00, 0.42, 0.42, 1)
local kColMark   = Color(1.00, 0.30, 0.38, 1)

-- directive colours: Escort, Hunt, Siege, Focus
local kDirectiveColors =
{
    Color(0.55, 0.85, 1.00, 1),
    Color(1.00, 0.55, 0.85, 1),
    Color(1.00, 0.70, 0.35, 1),
    Color(1.00, 0.35, 0.40, 1),
}

local kPad = 12
local kCardW, kCardH, kCardGap = 168, 64, 8
local kHeaderH = 40
local kPanelW = kPad * 2 + kCardW * 3 + kCardGap * 2
local kPanelH = kHeaderH + kCardH + 10
local kBottomMargin = 20
local kMaxMarkers = 10
local kHelpTime = 8           -- s after spawning that the key help shows
local kNoticeTime = 2.5
local kHelpText = "[1-3] BUILD    [SHIFT + 1-3] ORDERS    [4] CANCEL    [RMB] MARK    [B] SWARM"

local function S(x, y) return GUIScale(Vector(x, y, 0)) end

local function TypeColor(t, alpha)
    local c = VT_DroneTypeColors and VT_DroneTypeColors[t] or kColEnergy
    return Color(c.r, c.g, c.b, alpha or 1)
end

local function WithAlpha(c, a) return Color(c.r, c.g, c.b, a) end

function GUIVTDroneBay:Item(parent, tex, x, y, w, h, color, layer)
    local item = GUIManager:CreateGraphicItem()
    if tex then item:SetTexture(tex) end
    item:SetSize(S(w, h))
    item:SetPosition(S(x, y))
    item:SetColor(color or Color(1, 1, 1, 1))
    item:SetLayer(layer or kGUILayerPlayerHUD)
    if parent then
        parent:AddChild(item)
    else
        self.roots[#self.roots + 1] = item
    end
    return item
end

function GUIVTDroneBay:Text(parent, x, y, alignX, color)
    local t = GUIManager:CreateTextItem()
    t:SetFontName(Fonts.kAgencyFB_Small)
    t:SetScale(GetScaledVector())
    GUIMakeFontScale(t)
    t:SetTextAlignmentX(alignX or GUIItem.Align_Min)
    t:SetTextAlignmentY(GUIItem.Align_Center)
    t:SetPosition(S(x, y))
    t:SetColor(color or kColText)
    t:SetLayer(kGUILayerPlayerHUDForeground3)
    if parent then
        parent:AddChild(t)
    else
        self.roots[#self.roots + 1] = t
    end
    return t
end

function GUIVTDroneBay:Bar(parent, x, y, w, h)
    local back = self:Item(parent, kBarTex, x, y, w, h, kColEmpty, kGUILayerPlayerHUDForeground1)
    local fill = self:Item(parent, kBarTex, x, y, w, h, kColEnergy, kGUILayerPlayerHUDForeground2)
    return { back = back, fill = fill, w = w, h = h }
end

local function SetBar(bar, frac, color)
    frac = Clamp(frac or 0, 0, 1)
    bar.fill:SetIsVisible(frac > 0.002)
    bar.fill:SetSize(S(bar.w * frac, bar.h))
    bar.fill:SetTexturePixelCoordinates(0, 0, kBarTexW * frac, kBarTexH)
    if color then bar.fill:SetColor(color) end
end

local function SetBarShown(bar, shown)
    bar.back:SetIsVisible(shown)
    if not shown then bar.fill:SetIsVisible(false) end
end

function GUIVTDroneBay:Initialize()
    self.updateInterval = 0
    self.roots = {}

    local panel = self:Item(nil, nil, 0, 0, kPanelW, kPanelH, kColBody)
    panel:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    panel:SetPosition(S(-kPanelW * 0.5, -kBottomMargin - kPanelH))
    self.panel = panel
    self:Item(panel, kPanelTex, 0, 0, kPanelW, kPanelH, kColPanel, kGUILayerPlayerHUDForeground1)

    -- header: drones | queue pips | core energy, energy bar underneath
    self.fieldCount = self:Text(panel, kPad + 2, 15, nil, kColText)
    self.queuePips = {}
    local pipW, pipGap = 18, 5
    local pipsX = kPanelW * 0.5 - (kVTArtificerQueueSize * (pipW + pipGap) - pipGap) * 0.5
    for i = 1, kVTArtificerQueueSize do
        self.queuePips[i] = self:Item(panel, nil, pipsX + (i - 1) * (pipW + pipGap), 10, pipW, 9, kColEmpty,
                kGUILayerPlayerHUDForeground2)
    end
    self.energyText = self:Text(panel, kPanelW - kPad - 2, 15, GUIItem.Align_Max, kColText)
    self.energyBar = self:Bar(panel, kPad, 28, kPanelW - kPad * 2, 4)

    -- cards
    self.cards = {}
    for t = 1, kVTDroneTypeCount do
        local x = kPad + (t - 1) * (kCardW + kCardGap)
        local y = kHeaderH
        local card = {}
        card.frame  = self:Item(panel, kChipTex, x, y, kCardW, kCardH, Color(1, 1, 1, 0.55), kGUILayerPlayerHUDForeground1)
        card.stripe = self:Item(panel, nil, x + 2, y + 6, 3, kCardH - 12, TypeColor(t, 0.9), kGUILayerPlayerHUDForeground2)
        card.name   = self:Text(panel, x + 12, y + 14, nil, TypeColor(t))
        card.count  = self:Text(panel, x + kCardW - 10, y + 14, GUIItem.Align_Max, kColText)
        card.bar    = self:Bar(panel, x + 12, y + 28, kCardW - 24, 4)
        card.directive = self:Text(panel, x + 12, y + 46, nil, kColText)
        card.cost   = self:Text(panel, x + kCardW - 10, y + 46, GUIItem.Align_Max, kColDim)
        card.name:SetText(string.format("[%d] %s", t, kVTDroneTypes[t].name))
        self.cards[t] = card
    end

    -- notice line above the panel (key help after spawning, directive / bay notices)
    self.notice = self:Text(panel, kPanelW * 0.5, -14, GUIItem.Align_Center, kColDim)

    -- world markers: the mark frame (4 corners + label) and one marker per own drone
    self.markCorners = {}
    for i = 1, 4 do
        self.markCorners[i] = self:Item(nil, nil, 0, 0, 14, 3, kColMark, kGUILayerPlayerHUDForeground2)
        self.markCorners[i + 4] = self:Item(nil, nil, 0, 0, 3, 14, kColMark, kGUILayerPlayerHUDForeground2)
    end
    self.markLabel = self:Text(nil, 0, 0, GUIItem.Align_Center, kColMark)
    self.markers = {}
    for i = 1, kMaxMarkers do
        local m = {}
        m.icon = self:Item(nil, nil, 0, 0, 8, 8, kColEnergy, kGUILayerPlayerHUDForeground1)
        m.icon:SetRotation(Vector(0, 0, math.pi * 0.25))
        m.back = self:Item(nil, nil, 0, 0, 24, 3, Color(0, 0, 0, 0.6), kGUILayerPlayerHUDForeground1)
        m.fill = self:Item(nil, nil, 0, 0, 24, 3, kColReady, kGUILayerPlayerHUDForeground2)
        self.markers[i] = m
    end

    self.visible = true
    self:SetVisible(false)
end

function GUIVTDroneBay:Uninitialize()
    for _, item in ipairs(self.roots or {}) do
        GUI.DestroyItem(item)
    end
    self.roots = {}
end

function GUIVTDroneBay:OnResolutionChanged(oldX, oldY, newX, newY)
    self:Uninitialize()
    self:Initialize()
end

function GUIVTDroneBay:SetVisible(visible)
    if self.visible == visible then return end
    self.visible = visible
    for _, item in ipairs(self.roots) do
        item:SetIsVisible(visible)
    end
end

local function GetArtificer()
    if not Client.GetIsControllingPlayer() then return nil end
    local player = Client.GetLocalPlayer()
    if not player or not player:isa("VTArtificer") or not player:GetIsAlive() then return nil end
    if MainMenu_GetIsOpened and MainMenu_GetIsOpened() then return nil end
    return player
end

-- screen position (pixels) of a world point, nil when behind the camera
local function ToScreen(camera, point)
    if camera.zAxis:DotProduct(point - camera.origin) <= 0.2 then
        return nil
    end
    return Client.WorldToScreen(point)
end

function GUIVTDroneBay:Notify(text, color, now)
    self.noticeText, self.noticeColor, self.noticeEnd = text, color, now + kNoticeTime
end

function GUIVTDroneBay:UpdatePanel(player, now)
    local energy = player.vtEnergy or 0
    local maxEnergy = player:VT_GetMaxEnergy()
    local progress = player:VT_GetBuildProgress()
    local field = player:VT_GetDroneCount()

    self.fieldCount:SetText(string.format("DRONES %d / %d", field, kVTArtificerMaxDrones))
    self.fieldCount:SetColor(field >= kVTArtificerMaxDrones and kColWarn or kColText)
    self.energyText:SetText(string.format("CORE %d", math.floor(energy)))
    SetBar(self.energyBar, energy / maxEnergy, energy / maxEnergy < 0.2 and kColWarn or kColEnergy)

    local queued = {}
    for i, pip in ipairs(self.queuePips) do
        local t = player["vtQueue" .. i] or 0
        if t > 0 then
            queued[t] = (queued[t] or 0) + 1
            local alpha = 1
            if i == 1 then
                alpha = player.vtBayFull and (0.5 + 0.5 * math.sin(now * 10)) or (0.45 + 0.55 * (progress or 0))
            end
            pip:SetColor(TypeColor(t, alpha))
        else
            pip:SetColor(kColEmpty)
        end
    end

    local head = player.vtQueue1 or 0
    for t, card in ipairs(self.cards) do
        local spec = kVTDroneTypes[t]
        local count = player["vtDrones" .. t] or 0
        local n = queued[t] or 0
        card.count:SetText(n > 0 and string.format("%d  +%d", count, n) or tostring(count))
        card.count:SetColor(count > 0 and kColText or kColDim)
        local canPay = energy >= spec.cost
        card.cost:SetText(tostring(spec.cost))
        card.cost:SetColor(canPay and kColDim or kColWarn)
        local building = head == t and progress ~= nil
        SetBarShown(card.bar, building)
        if building then
            if player.vtBayFull then
                SetBar(card.bar, 1, WithAlpha(kColWarn, 0.6 + 0.4 * math.sin(now * 10)))
            else
                SetBar(card.bar, progress, TypeColor(t))
            end
        end
        local directive = player["vtDirective" .. t] or 1
        card.directive:SetText(kVTDroneDirectiveNames[directive] or "?")
        card.directive:SetColor(kDirectiveColors[directive] or kColText)
        -- directive changed: flash the card + say what it means above the panel
        if card.lastDirective and card.lastDirective ~= directive then
            card.flashTime = now
            self:Notify(string.format("%s: %s - %s", spec.name, kVTDroneDirectiveNames[directive],
                    kVTDroneDirectiveHints[directive] or ""), kDirectiveColors[directive], now)
        end
        card.lastDirective = directive
        local flash = card.flashTime and math.max(0, 1 - (now - card.flashTime) / 0.5) or 0
        card.frame:SetColor(Color(1, 1 - 0.2 * flash, 1, 0.55 + 0.45 * flash))
        card.stripe:SetColor(TypeColor(t, canPay and 0.9 or 0.3))
    end

    if player.vtBayFull and not self.wasBayFull then
        self:Notify("BAY FULL - the next drone launches when one is lost", kColWarn, now)
    end
    self.wasBayFull = player.vtBayFull

    -- notice line: a notice, else the key help for a few seconds after spawning
    if self.noticeEnd and now < self.noticeEnd then
        self.notice:SetText(self.noticeText)
        self.notice:SetColor(WithAlpha(self.noticeColor or kColText, math.min(1, (self.noticeEnd - now) * 2)))
    elseif now - (player.vtSpawnTime or 0) < kHelpTime then
        self.notice:SetText(kHelpText)
        self.notice:SetColor(WithAlpha(kColDim, math.min(1, (kHelpTime - (now - (player.vtSpawnTime or 0))) * 0.5)))
    else
        self.notice:SetText("")
    end
end

function GUIVTDroneBay:UpdateMark(player, camera, now)
    local mark = player:VT_GetMark()
    local pos = mark and ToScreen(camera, mark:GetEngagementPoint())
    for _, item in ipairs(self.markCorners) do
        item:SetIsVisible(pos ~= nil)
    end
    self.markLabel:SetIsVisible(pos ~= nil)
    if not pos then return end

    local swarm = player:VT_GetAbilityActive()
    local dist = (mark:GetEngagementPoint() - camera.origin):GetLength()
    local size = Clamp(GUIScale(900) / math.max(dist, 1), GUIScale(18), GUIScale(70))
    size = size * (1 + (swarm and 0.12 or 0.05) * math.sin(now * (swarm and 14 or 6)))
    local col = WithAlpha(kColMark, swarm and 1 or 0.85)
    local long, thick = GUIScale(14), GUIScale(3)
    local corners = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
    for i, c in ipairs(corners) do
        local cx, cy = pos.x + c[1] * size, pos.y + c[2] * size
        local h, v = self.markCorners[i], self.markCorners[i + 4]
        h:SetSize(Vector(long, thick, 0))
        v:SetSize(Vector(thick, long, 0))
        h:SetPosition(Vector(c[1] < 0 and cx or cx - long, c[2] < 0 and cy or cy - thick, 0))
        v:SetPosition(Vector(c[1] < 0 and cx or cx - thick, c[2] < 0 and cy or cy - long, 0))
        h:SetColor(col)
        v:SetColor(col)
    end
    self.markLabel:SetText(string.format("%s  %dm", swarm and "SWARM" or "MARK", math.floor(dist + 0.5)))
    self.markLabel:SetPosition(Vector(pos.x, pos.y - size - GUIScale(12), 0))
    self.markLabel:SetColor(col)
end

function GUIVTDroneBay:UpdateMarkers(player, camera)
    local used = 0
    local myId = player:GetId()
    for _, drone in ientitylist(Shared.GetEntitiesWithClassname("VTDrone")) do
        if used >= kMaxMarkers then break end
        if drone.vtOwnerId == myId and drone:GetIsAlive() then
            local origin = drone:GetOrigin()
            local pos = (origin - camera.origin):GetLength() < 50 and ToScreen(camera, origin + Vector(0, 0.45, 0))
            if pos then
                used = used + 1
                local m = self.markers[used]
                local t = drone.vtDroneType or 1
                local frac = drone:GetHealth() / math.max(1, drone:GetMaxHealth())
                local iconSize = GUIScale(8)
                m.icon:SetSize(Vector(iconSize, iconSize, 0))
                m.icon:SetPosition(Vector(pos.x - iconSize * 0.5, pos.y - GUIScale(12), 0))
                m.icon:SetColor(TypeColor(t, drone.vtBeamTargetId ~= Entity.invalidId and 1 or 0.7))
                local w, h = GUIScale(24), GUIScale(3)
                m.back:SetSize(Vector(w, h, 0))
                m.back:SetPosition(Vector(pos.x - w * 0.5, pos.y, 0))
                m.fill:SetSize(Vector(w * Clamp(frac, 0, 1), h, 0))
                m.fill:SetPosition(Vector(pos.x - w * 0.5, pos.y, 0))
                m.fill:SetColor(frac < 0.35 and kColWarn or kColReady)
                m.icon:SetIsVisible(true)
                m.back:SetIsVisible(true)
                m.fill:SetIsVisible(true)
            end
        end
    end
    for i = used + 1, kMaxMarkers do
        local m = self.markers[i]
        m.icon:SetIsVisible(false)
        m.back:SetIsVisible(false)
        m.fill:SetIsVisible(false)
    end
end

function GUIVTDroneBay:Update(deltaTime)
    PROFILE("GUIVTDroneBay:Update")
    local player = GetArtificer()
    self:SetVisible(player ~= nil)
    if not player then return end
    local now = Shared.GetTime()
    self:UpdatePanel(player, now)
    local camera = player.GetCameraViewCoords and player:GetCameraViewCoords()
    if camera then
        self:UpdateMark(player, camera, now)
        self:UpdateMarkers(player, camera)
    end
end
