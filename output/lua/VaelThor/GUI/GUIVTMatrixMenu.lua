-- ============================================================================
-- GUIVTMatrixMenu - the Synthesis Matrix menu of a dead Vael'Thor soldier
-- (issue #1, styled after the alien evolve menu).
--
-- Opens on death with a mouse cursor:
--   * four caste cards (click, or keys 1-4) with quota, cost and lock state
--   * three loadout rows (left click / right click cycles; keys 5, R, E)
--   * SYNTHESIZE button (click, or Space). There is no automatic respawn: the
--     server synthesizes the player only after this request. Asking while the
--     matrix timer still runs arms the request ("ARMED"); click again to cancel.
--   * B hides / shows the menu (hidden: a small status chip stays at the bottom,
--     camera control comes back). The number keys keep working while hidden.
--
-- Every choice goes to the server as a VTMatrixChoice message (VTSpectator:
-- VT_ApplyChoice), which works in all spectator camera modes. The server mirrors
-- the state back with VTMatrixLoadout (VT_MatrixLoadout in Client.lua).
-- ============================================================================

class 'GUIVTMatrixMenu' (GUIScript)

local kPanelTex = PrecacheAsset("ui/vaelthor/hud_panel.dds")
local kChipTex  = PrecacheAsset("ui/vaelthor/hud_chip.dds")

local kColPanel    = Color(1, 1, 1, 0.95)
local kColCard     = Color(0.80, 0.70, 1.00, 0.85)
local kColCardHover = Color(1.00, 0.92, 1.00, 1)
local kColSelected = Color(0.45, 1.00, 1.00, 1)
local kColLocked   = Color(0.50, 0.48, 0.56, 0.75)
local kColText     = Color(0.88, 0.80, 1.00, 1)
local kColDim      = Color(0.62, 0.52, 0.78, 1)
local kColKey      = Color(0.78, 0.45, 1.00, 1)
local kColCyan     = Color(0.35, 0.95, 1.00, 1)
local kColReady    = Color(0.55, 1.00, 0.85, 1)
local kColWarn     = Color(1.00, 0.42, 0.42, 1)
local kColActive   = Color(1.00, 0.85, 1.00, 1)

local kPanelW, kPanelH = 900, 600
local kCardW, kCardH, kCardGap, kCardY = 200, 170, 12, 104
local kRowW, kRowH, kRowGap, kRowY = 836, 42, 8, 352
local kButtonW, kButtonH, kButtonY = 380, 62, 508
local kMargin = 32

local kCastes =
{
    { key = "1", class = "Vanguard",    caste = nil,           name = "VANGUARD",    tip = "VT_VANGUARD_TOOLTIP" },
    { key = "2", class = "Infiltrator", caste = "Infiltrator", name = "INFILTRATOR", tip = "VT_INFILTRATOR_TOOLTIP" },
    { key = "3", class = "Subject",     caste = "Subject",     name = "SUBJECT",     tip = "VT_SUBJECT_TOOLTIP" },
    { key = "4", class = "Praetor",     caste = "Praetor",     name = "PRAETOR",     tip = "VT_PRAETOR_TOOLTIP" },
}

-- choice ids: forward / backward (VTSpectator:VT_ApplyChoice)
local kRows =
{
    { key = "5", label = "TACTICAL MODULE", field = "vtModule",     prefix = "VT_MODULE_",    req = "kVTModuleRequirements",     fwd = 5, back = 9 },
    { key = "R", label = "PRIMARY",         field = "vtPrimaryMod", prefix = "VT_PRIMARY_",   req = "kVTPrimaryModRequirements", fwd = 6, back = 10 },
    { key = "E", label = "SECONDARY",       field = "vtSecondary",  prefix = "VT_SECONDARY_", req = "kVTSecondaryRequirements",  fwd = 7, back = 11 },
}

local kSynthesizeChoice = 8

-- Keys work whether the menu is shown or hidden (same order as the choices 1-7).
local kChoiceBindings = { "Weapon1", "Weapon2", "Weapon3", "Weapon4", "Weapon5", "Reload", "Use" }

local function S(x, y) return GUIScale(Vector(x, y, 0)) end

local function GetLocalRank()
    local ok, score = pcall(Scoreboard_GetPlayerData, Client.GetLocalClientIndex(), "Score")
    score = ok and tonumber(score) or 0
    return VT_GetRankForScore(score), score
end

local function LockReason(requirement, rank)
    if not requirement then
        return nil
    end
    if requirement.rank and rank < requirement.rank then
        return string.format("rank %d", requirement.rank)
    end
    if requirement.tech and not VT_GetTeamHasTech(requirement.tech) then
        return VT_GetString(LookupTechData(kTechId[requirement.tech], kTechDataDisplayName, requirement.tech))
    end
    return nil
end

-- The local client is a dead Vael'Thor soldier: either our own VTSpectator, or
-- we are following someone (kill cam / first person) and the local player isn't us.
local function GetIsDeadVTSoldier()
    if Client.GetLocalClientTeamNumber() ~= kVTTeamIndex then
        return false
    end
    local player = Client.GetLocalPlayer()
    if not player then
        return false
    end
    if player:isa("VTSpectator") then
        return true
    end
    return not Client.GetIsControllingPlayer()
end

-- Our matrix choices: the server's mirror, or the spectator entity itself
-- before the first VTMatrixLoadout message arrived.
local function GetMatrixState()
    if VT_MatrixLoadout then
        return VT_MatrixLoadout
    end
    local player = Client.GetLocalPlayer()
    if player and player:isa("VTSpectator") then
        return { vtDesiredClass = player.vtDesiredClass, vtModule = player.vtModule,
                 vtPrimaryMod = player.vtPrimaryMod, vtSecondary = player.vtSecondary,
                 readyTime = 0, armed = false }
    end
    return { vtDesiredClass = kVTClass.Vanguard, vtModule = kVTModule.ShieldBoost,
             vtPrimaryMod = kVTPrimaryMod.Standard, vtSecondary = kVTSecondary.Pistol,
             readyTime = 0, armed = false }
end

-- ----------------------------------------------------------------------------
-- construction
-- ----------------------------------------------------------------------------
function GUIVTMatrixMenu:Graphic(parent, tex, w, h, x, y, color, layer)
    local item = GUIManager:CreateGraphicItem()
    if tex then item:SetTexture(tex) end
    item:SetSize(S(w, h))
    item:SetPosition(S(x, y))
    item:SetColor(color or Color(1, 1, 1, 1))
    item:SetLayer(layer or kGUILayerPlayerHUDForeground1)
    if parent then
        parent:AddChild(item)
    end
    return item
end

function GUIVTMatrixMenu:Text(parent, font, x, y, alignX, color)
    local t = GUIManager:CreateTextItem()
    t:SetFontName(font)
    t:SetScale(GetScaledVector())
    GUIMakeFontScale(t)
    t:SetTextAlignmentX(alignX or GUIItem.Align_Min)
    t:SetTextAlignmentY(GUIItem.Align_Center)
    t:SetPosition(S(x, y))
    t:SetColor(color or kColText)
    t:SetLayer(kGUILayerPlayerHUDForeground3)
    parent:AddChild(t)
    return t
end

function GUIVTMatrixMenu:Initialize()

    self.updateInterval = 0   -- every frame: hover highlight and countdown

    -- ---- main panel
    self.panel = self:Graphic(nil, kPanelTex, kPanelW, kPanelH, 0, 0, kColPanel, kGUILayerPlayerHUDForeground1)
    self.panel:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.panel:SetPosition(S(-kPanelW / 2, -kPanelH / 2))

    self.title = self:Text(self.panel, Fonts.kAgencyFB_Large, kMargin, 40, nil, kColCyan)
    self.title:SetText("SYNTHESIS MATRIX")
    self.rank = self:Text(self.panel, Fonts.kAgencyFB_Small, kMargin, 76, nil, kColDim)
    self.directives = self:Text(self.panel, Fonts.kAgencyFB_Small, kPanelW - kMargin, 40, GUIItem.Align_Max, kColActive)

    -- ---- caste cards
    self.cards = {}
    for i, def in ipairs(kCastes) do
        local x = kMargin + (i - 1) * (kCardW + kCardGap)
        local frame = self:Graphic(self.panel, kChipTex, kCardW, kCardH, x, kCardY, kColCard, kGUILayerPlayerHUDForeground2)
        local card =
        {
            def   = def,
            frame = frame,
            key   = self:Text(frame, Fonts.kAgencyFB_Small, 16, 24, nil, kColKey),
            name  = self:Text(frame, Fonts.kAgencyFB_Medium, 16, 58, nil, kColText),
            info1 = self:Text(frame, Fonts.kAgencyFB_Small, 16, 94, nil, kColDim),
            info2 = self:Text(frame, Fonts.kAgencyFB_Small, 16, 118, nil, kColDim),
            lock  = self:Text(frame, Fonts.kAgencyFB_Small, 16, 146, nil, kColWarn),
        }
        card.key:SetText("[" .. def.key .. "]")
        card.name:SetText(def.name)
        self.cards[i] = card
    end

    -- description of the selected caste (word wrapped below the cards)
    self.description = self:Text(self.panel, Fonts.kAgencyFB_Small, kMargin, kCardY + kCardH + 14, nil, kColText)
    self.description:SetTextAlignmentY(GUIItem.Align_Min)
    self.descriptionClass = nil

    -- ---- loadout rows
    self.rows = {}
    for i, def in ipairs(kRows) do
        local y = kRowY + (i - 1) * (kRowH + kRowGap)
        local frame = self:Graphic(self.panel, kChipTex, kRowW, kRowH, kMargin, y, kColCard, kGUILayerPlayerHUDForeground2)
        local row =
        {
            def   = def,
            frame = frame,
            key   = self:Text(frame, Fonts.kAgencyFB_Small, 16, kRowH / 2, nil, kColKey),
            label = self:Text(frame, Fonts.kAgencyFB_Small, 60, kRowH / 2, nil, kColDim),
            value = self:Text(frame, Fonts.kAgencyFB_Small, kRowW / 2 + 40, kRowH / 2, GUIItem.Align_Center, kColText),
            lock  = self:Text(frame, Fonts.kAgencyFB_Small, kRowW - 16, kRowH / 2, GUIItem.Align_Max, kColWarn),
        }
        row.key:SetText("[" .. def.key .. "]")
        row.label:SetText(def.label)
        self.rows[i] = row
    end

    -- ---- synthesize button
    self.button = self:Graphic(self.panel, kChipTex, kButtonW, kButtonH, (kPanelW - kButtonW) / 2, kButtonY, kColCard, kGUILayerPlayerHUDForeground2)
    self.buttonText = self:Text(self.button, Fonts.kAgencyFB_Medium, kButtonW / 2, kButtonH / 2, GUIItem.Align_Center, kColText)

    self.hint = self:Text(self.panel, Fonts.kAgencyFB_Small, kPanelW / 2, kPanelH - 16, GUIItem.Align_Center, kColDim)
    self.hint:SetText("[Space] synthesize    [B] hide menu    left / right click: cycle loadout")

    -- ---- small chip while the menu is hidden
    self.mini = self:Graphic(nil, kChipTex, 420, 46, 0, 0, kColCard, kGUILayerPlayerHUDForeground1)
    self.mini:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    self.mini:SetPosition(S(-210, -140))
    self.miniText = self:Text(self.mini, Fonts.kAgencyFB_Small, 210, 23, GUIItem.Align_Center, kColText)

    self.panel:SetIsVisible(false)
    self.mini:SetIsVisible(false)

    self.hidden = false
    self.wasDead = false
    self.cursorShown = false
    self.keysDown = {}

end

function GUIVTMatrixMenu:SetCursorShown(shown)
    if shown ~= self.cursorShown then
        self.cursorShown = shown
        MouseTracker_SetIsVisible(shown, "ui/Cursor_MenuDefault.dds", true)
    end
end

function GUIVTMatrixMenu:Uninitialize()
    self:SetCursorShown(false)
    if self.panel then
        GUI.DestroyItem(self.panel)   -- destroys all children
        self.panel = nil
    end
    if self.mini then
        GUI.DestroyItem(self.mini)
        self.mini = nil
    end
end

function GUIVTMatrixMenu:OnResolutionChanged(oldX, oldY, newX, newY)
    local hidden, wasDead = self.hidden, self.wasDead
    self:Uninitialize()
    self:Initialize()
    self.hidden, self.wasDead = hidden, wasDead
end

function GUIVTMatrixMenu:GetIsMenuShown()
    return self.panel ~= nil and self.panel:GetIsVisible()
end

-- ----------------------------------------------------------------------------
-- update
-- ----------------------------------------------------------------------------
local function GetHovered(item)
    if not MouseTracker_GetIsVisible() then
        return false
    end
    local x, y = Client.GetCursorPosScreen()
    return GUIItemContainsPoint(item, x, y)
end

-- Button / chip text for the current synthesis state.
local function GetSynthesisStatus(state)
    local now = Shared.GetTime()
    local readyTime = state.readyTime or 0
    if readyTime <= 0 then
        return "AWAITING MATRIX", "waiting for a matrix slot", kColDim
    end
    local remaining = readyTime - now
    if remaining > 0 then
        if state.armed then
            return string.format("ARMED  -  %d", math.ceil(remaining)), string.format("synthesis in %d s (armed)", math.ceil(remaining)), kColActive
        end
        return string.format("SYNTHESIZE  -  %d", math.ceil(remaining)), string.format("matrix ready in %d s", math.ceil(remaining)), kColText
    end
    if state.armed then
        return "SYNTHESIZING...", "synthesizing...", kColActive
    end
    return "SYNTHESIZE", "READY - [B] open menu", kColReady
end

function GUIVTMatrixMenu:UpdateDirectives()
    local info = VT_GetEmpireInfo()
    local parts = {}
    if info then
        local now = Shared.GetTime()
        if info.requisitionEnd > now then
            parts[#parts + 1] = string.format("Requisition Mandate %.0fs", info.requisitionEnd - now)
        end
        if info.relentlessEnd > now then
            parts[#parts + 1] = string.format("Relentless Advance %.0fs", info.relentlessEnd - now)
        end
        if info.ironEnd > now then
            parts[#parts + 1] = string.format("Iron Discipline %.0fs", info.ironEnd - now)
        end
    end
    self.directives:SetText(#parts > 0 and ("Directive: " .. table.concat(parts, "  |  ")) or "")
end

function GUIVTMatrixMenu:UpdateMenu(state)

    local rank, score = GetLocalRank()
    self.rank:SetText(string.format("Imperial Authorization: rank %d  (score %d)", rank, score))
    self:UpdateDirectives()

    local info = VT_GetEmpireInfo()

    for _, card in ipairs(self.cards) do
        local def = card.def
        local class = kVTClass[def.class]
        local selected = state.vtDesiredClass == class
        -- castes are gated by tech only (not by rank), like the server's ResolveCaste
        local lock = LockReason(kVTClassRequirements[class], 3)
        local full = false

        if def.caste then
            local count = info and info:GetCount(def.caste) or 0
            local quota = info and info:GetQuota(def.caste) or 0
            full = info ~= nil and count >= quota
            card.info1:SetText(info and string.format("quota %d / %d", count, quota) or "")
            local cost = kVTCasteCost[def.caste] or 0
            card.info2:SetText(cost > 0 and string.format("%d team res", cost) or "free")
        else
            card.info1:SetText("unlimited")
            card.info2:SetText("free")
        end

        if lock then
            card.lock:SetText("locked: " .. lock)
        elseif full then
            card.lock:SetText("quota full")
        else
            card.lock:SetText("")
        end

        local color = kColCard
        if selected then
            color = kColSelected
        elseif lock then
            color = kColLocked
        elseif GetHovered(card.frame) then
            color = kColCardHover
        end
        card.frame:SetColor(color)
        card.name:SetColor(selected and kColCyan or (lock and kColDim or kColText))
    end

    -- description of the selected caste
    if self.descriptionClass ~= state.vtDesiredClass then
        self.descriptionClass = state.vtDesiredClass
        local text = ""
        for _, def in ipairs(kCastes) do
            if kVTClass[def.class] == state.vtDesiredClass then
                text = VT_GetString(def.tip)
            end
        end
        local maxWidth = GUIScale(kPanelW - 2 * kMargin)
        self.description:SetText(WordWrap(self.description, text, 0, maxWidth, 2))
    end

    for _, row in ipairs(self.rows) do
        local def = row.def
        local value = state[def.field] or 1
        row.value:SetText("<   " .. VT_GetString(def.prefix .. tostring(value)) .. "   >")
        local lock = LockReason(_G[def.req][value], rank)
        row.lock:SetText(lock and ("locked: " .. lock .. " - default used") or "")
        row.frame:SetColor(GetHovered(row.frame) and kColCardHover or kColCard)
    end

    local label, _, color = GetSynthesisStatus(state)
    self.buttonText:SetText(label)
    self.buttonText:SetColor(color)
    local ready = (state.readyTime or 0) > 0 and Shared.GetTime() >= state.readyTime and not state.armed
    local buttonColor = kColCard
    if GetHovered(self.button) then
        buttonColor = kColCardHover
    elseif ready then
        local pulse = 0.75 + 0.25 * math.sin(Shared.GetTime() * 6)
        buttonColor = Color(kColReady.r * pulse, kColReady.g * pulse, kColReady.b * pulse, 1)
    elseif state.armed then
        buttonColor = kColActive
    end
    self.button:SetColor(buttonColor)

end

function GUIVTMatrixMenu:Update(deltaTime)

    PROFILE("GUIVTMatrixMenu:Update")

    local dead = GetIsDeadVTSoldier() and not (MainMenu_GetIsOpened and MainMenu_GetIsOpened())

    if dead and not self.wasDead then
        self.hidden = false             -- every death opens the menu again
    elseif not dead and self.wasDead and Client.GetIsControllingPlayer() then
        VT_MatrixLoadout = nil          -- alive again: drop the last life's state (armed, timer)
    end
    self.wasDead = dead

    local showMenu = dead and not self.hidden
    self.panel:SetIsVisible(showMenu)
    self.mini:SetIsVisible(dead and self.hidden)
    self:SetCursorShown(showMenu)

    if not dead then
        return
    end

    local state = GetMatrixState()
    if showMenu then
        self:UpdateMenu(state)
    else
        local _, status, color = GetSynthesisStatus(state)
        self.miniText:SetText("SYNTHESIS MATRIX [B]  -  " .. status)
        self.miniText:SetColor(color)
    end

end

-- ----------------------------------------------------------------------------
-- input
-- ----------------------------------------------------------------------------
local function SendChoice(choice)
    Client.SendNetworkMessage("VTMatrixChoice", { choice = choice }, true)
end

function GUIVTMatrixMenu:OnClick(rightButton)

    local x, y = Client.GetCursorPosScreen()

    for i, card in ipairs(self.cards) do
        if GUIItemContainsPoint(card.frame, x, y) then
            SendChoice(i)
            return true
        end
    end

    for _, row in ipairs(self.rows) do
        if GUIItemContainsPoint(row.frame, x, y) then
            SendChoice(rightButton and row.def.back or row.def.fwd)
            return true
        end
    end

    if GUIItemContainsPoint(self.button, x, y) then
        SendChoice(kSynthesizeChoice)
        return true
    end

    -- swallow clicks on the panel itself; let clicks outside reach the spectator camera
    return GUIItemContainsPoint(self.panel, x, y)

end

function GUIVTMatrixMenu:SendKeyEvent(key, down)

    if not self.panel or not self.wasDead or not GetIsDeadVTSoldier() then
        return false
    end
    if GetIsTextBeingEntered and GetIsTextBeingEntered() then
        return false
    end
    if MainMenu_GetIsOpened and MainMenu_GetIsOpened() then
        return false
    end

    -- ignore OS key repeat
    local repeated = down and self.keysDown[key]
    self.keysDown[key] = down or nil

    if GetIsBinding(key, "Buy") then
        if down and not repeated then
            self.hidden = not self.hidden
        end
        return true
    end

    for choice, binding in ipairs(kChoiceBindings) do
        if GetIsBinding(key, binding) then
            if down and not repeated then
                SendChoice(choice)
            end
            return true
        end
    end

    if not self:GetIsMenuShown() then
        return false
    end

    if GetIsBinding(key, "Jump") then
        if down and not repeated then
            SendChoice(kSynthesizeChoice)
        end
        return true
    end

    if key == InputKey.MouseButton0 or key == InputKey.MouseButton1 then
        if down then
            return self:OnClick(key == InputKey.MouseButton1)
        end
        return false
    end

    return false

end
