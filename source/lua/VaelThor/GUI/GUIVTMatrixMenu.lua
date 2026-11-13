-- ============================================================================
-- GUIVTMatrixMenu - the Synthesis Matrix menu of a dead Vael'Thor soldier
-- (issue #1, styled after the alien evolve menu).
--
-- Opens on death with a mouse cursor over a dimmed screen:
--   * four caste cards with a portrait (ui/vaelthor/caste_portraits.dds, from
--     art/ui/make_caste_portraits.sh), quota, cost and lock state (click, or keys 1-4)
--   * three loadout rows (left click / right click cycles; keys 5, R, E)
--   * SYNTHESIZE button (click, or Space). There is no automatic respawn: the
--     server synthesizes the player only after this request. Asking while the
--     matrix timer still runs arms the request ("ARMED"); click again to cancel.
--   * B hides / shows the menu (hidden: a small status chip stays at the bottom,
--     camera control comes back). The number keys keep working while hidden.
--
-- Clicks come through a MouseTracker button listener (it runs before the GUI
-- scripts, so spectator GUIs can't swallow them). Every text is fitted to its box.
--
-- Every choice goes to the server as a VTMatrixChoice message (VTSpectator:
-- VT_ApplyChoice), which works in all spectator camera modes. The server mirrors
-- the state back with VTMatrixLoadout (VT_MatrixLoadout in Client.lua).
-- ============================================================================

class 'GUIVTMatrixMenu' (GUIScript)

local St = VTGUIStyle   -- shared look (GUI/VTGUIStyle.lua)

local kPanelTex     = St.kPanelTex
local kChipTex      = St.kChipTex
local kPortraitTex  = PrecacheAsset("ui/vaelthor/caste_portraits.dds")
local kPortraitCell = 256          -- atlas: 4 cells of 256x256, order as kCastes

local kColDim           = St.kColDim
local kColBody          = St.kColBody
local kColCardBody      = St.kColCardBody
local kColCardBodyHover = St.kColCardBodyHover
local kColCardBodySel   = St.kColCardBodySel
local kColFrame         = St.kColFrame
local kColFrameHover    = St.kColFrameHover
local kColSelected      = St.kColSelected
local kColLocked        = St.kColLocked
local kColText          = St.kColText
local kColDimText       = St.kColDimText
local kColKey           = St.kColKey
local kColCyan          = St.kColCyan
local kColReady         = St.kColReady
local kColWarn          = St.kColWarn
local kColActive        = St.kColActive

local kMargin = 28
local kPanelW, kPanelH = 1100, 760
local kCardW, kCardH, kCardGap, kCardY = 245, 330, 16, 100
local kPortraitH = 196
local kPad = 12                                             -- text inset inside cards / rows
local kDescY = kCardY + kCardH + 12
local kRowW, kRowH, kRowGap, kRowY = kPanelW - 2 * kMargin, 42, 8, 512
local kRowLabelW, kRowValueX, kRowValueW = 210, 250, 420   -- label column, value column
local kButtonW, kButtonH, kButtonY = 400, 62, 664

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

local S = St.S

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

local SetFittedText = St.SetFittedText

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
-- mouse: one MouseTracker listener for the whole session (MouseTracker has no
-- way to unregister), forwarding to the live menu instance.
-- ----------------------------------------------------------------------------
local gMatrixMenu

if not VT_MatrixMouseListener then
    VT_MatrixMouseListener =
    {
        OnMouseDown = function(_, key, doubleClick)
            if gMatrixMenu and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1) then
                return gMatrixMenu:OnMouseDown(key == InputKey.MouseButton1)
            end
            return false
        end,
        OnMouseUp = function(_, key)
            return gMatrixMenu ~= nil and gMatrixMenu:GetIsMenuShown()
                and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1)
                and gMatrixMenu:GetIsCursorOverPanel()
        end,
    }
    MouseTracker_ListenToButtons(VT_MatrixMouseListener)
end

-- ----------------------------------------------------------------------------
-- construction
-- ----------------------------------------------------------------------------
function GUIVTMatrixMenu:Graphic(parent, tex, w, h, x, y, color, layer)
    return St.Graphic(parent, tex, w, h, x, y, color, layer)
end

function GUIVTMatrixMenu:Text(parent, font, x, y, alignX, color)
    return St.Text(parent, font, x, y, alignX, color)
end

function GUIVTMatrixMenu:Box(parent, tex, w, h, x, y, bodyColor, frameColor, layer)
    return St.Box(parent, tex, w, h, x, y, bodyColor, frameColor, layer)
end

function GUIVTMatrixMenu:Initialize()

    self.updateInterval = 0   -- every frame: hover highlight and countdown

    -- ---- dim the world behind the menu
    self.dim = self:Graphic(nil, nil, 0, 0, 0, 0, kColDim, kGUILayerPlayerHUD)
    self.dim:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))

    -- ---- main panel
    self.panel = self:Graphic(nil, nil, kPanelW, kPanelH, 0, 0, kColBody, kGUILayerPlayerHUDForeground1)
    self.panel:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.panel:SetPosition(S(-kPanelW / 2, -kPanelH / 2))
    self:Graphic(self.panel, kPanelTex, kPanelW, kPanelH, 0, 0, kColFrame, kGUILayerPlayerHUDForeground1)

    self.title = self:Text(self.panel, Fonts.kAgencyFB_Large, kMargin, 42, nil, kColCyan)
    self.title:SetText("SYNTHESIS MATRIX")
    self.rank = self:Text(self.panel, Fonts.kAgencyFB_Small, kMargin, 76, nil, kColDimText)
    self.directives = self:Text(self.panel, Fonts.kAgencyFB_Small, kPanelW - kMargin, 42, GUIItem.Align_Max, kColActive)

    -- ---- caste cards
    self.cards = {}
    for i, def in ipairs(kCastes) do
        local x = kMargin + (i - 1) * (kCardW + kCardGap)
        local body, frame = self:Box(self.panel, kChipTex, kCardW, kCardH, x, kCardY, kColCardBody, kColFrame, kGUILayerPlayerHUDForeground2)
        -- above the frame texture, whose translucent body would darken it
        local portrait = self:Graphic(body, kPortraitTex, kCardW - 2 * kPad, kPortraitH, kPad, kPad, Color(1, 1, 1, 1), kGUILayerPlayerHUDForeground4)
        -- crop the square atlas cell to the portrait box's aspect (cuts the bottom = legs; heads stay)
        local cellW = kPortraitCell * (kCardW - 2 * kPad) / kPortraitH
        cellW = math.min(cellW, kPortraitCell)
        local u0 = (i - 1) * kPortraitCell + (kPortraitCell - cellW) / 2
        local visibleH = kPortraitCell * math.min(1, kPortraitH / (kCardW - 2 * kPad))
        portrait:SetTexturePixelCoordinates(u0, 0, u0 + cellW, visibleH)
        local textY = kPad + kPortraitH
        local card =
        {
            def      = def,
            body     = body,
            frame    = frame,
            portrait = portrait,
            key      = self:Text(body, Fonts.kAgencyFB_Small, kCardW - kPad, textY + 22, GUIItem.Align_Max, kColKey),
            name     = self:Text(body, Fonts.kAgencyFB_Medium, kPad, textY + 22, nil, kColText),
            info1    = self:Text(body, Fonts.kAgencyFB_Small, kPad, textY + 52, nil, kColDimText),
            info2    = self:Text(body, Fonts.kAgencyFB_Small, kPad, textY + 74, nil, kColDimText),
            lock     = self:Text(body, Fonts.kAgencyFB_Small, kPad, textY + 100, nil, kColWarn),
        }
        card.key:SetText("[" .. def.key .. "]")
        SetFittedText(card.name, def.name, kCardW - 2 * kPad - 34)   -- room for the "[n]" on the right
        self.cards[i] = card
    end

    -- description of the selected caste (word wrapped below the cards, at most 2 lines)
    self.description = self:Text(self.panel, Fonts.kAgencyFB_Small, kMargin, kDescY, nil, kColText)
    self.description:SetTextAlignmentY(GUIItem.Align_Min)
    self.descriptionClass = nil

    -- ---- loadout rows
    self.rows = {}
    for i, def in ipairs(kRows) do
        local y = kRowY + (i - 1) * (kRowH + kRowGap)
        local body, frame = self:Box(self.panel, kChipTex, kRowW, kRowH, kMargin, y, kColCardBody, kColFrame, kGUILayerPlayerHUDForeground2)
        local row =
        {
            def   = def,
            body  = body,
            frame = frame,
            key   = self:Text(body, Fonts.kAgencyFB_Small, kPad + 4, kRowH / 2, nil, kColKey),
            label = self:Text(body, Fonts.kAgencyFB_Small, kPad + 44, kRowH / 2, nil, kColDimText),
            value = self:Text(body, Fonts.kAgencyFB_Small, kRowValueX + kRowValueW / 2, kRowH / 2, GUIItem.Align_Center, kColText),
            lock  = self:Text(body, Fonts.kAgencyFB_Small, kRowW - kPad - 4, kRowH / 2, GUIItem.Align_Max, kColWarn),
        }
        row.key:SetText("[" .. def.key .. "]")
        SetFittedText(row.label, def.label, kRowLabelW - 44)
        self.rows[i] = row
    end

    -- ---- synthesize button
    self.button, self.buttonFrame = self:Box(self.panel, kChipTex, kButtonW, kButtonH, (kPanelW - kButtonW) / 2, kButtonY,
            kColCardBody, kColFrame, kGUILayerPlayerHUDForeground2)
    self.buttonText = self:Text(self.button, Fonts.kAgencyFB_Medium, kButtonW / 2, kButtonH / 2, GUIItem.Align_Center, kColText)

    self.hint = self:Text(self.panel, Fonts.kAgencyFB_Small, kPanelW / 2, kPanelH - 18, GUIItem.Align_Center, kColDimText)
    SetFittedText(self.hint, "[Space] synthesize    [B] hide menu    left / right click: cycle loadout", kPanelW - 2 * kMargin)

    -- ---- small chip while the menu is hidden
    self.mini = self:Box(nil, kChipTex, 460, 46, 0, 0, kColCardBody, kColFrame, kGUILayerPlayerHUDForeground1)
    self.mini:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    self.mini:SetPosition(S(-230, -140))
    self.miniText = self:Text(self.mini, Fonts.kAgencyFB_Small, 230, 23, GUIItem.Align_Center, kColText)

    self.dim:SetIsVisible(false)
    self.panel:SetIsVisible(false)
    self.mini:SetIsVisible(false)

    self.hidden = false
    self.wasDead = false
    self.cursorShown = false
    self.keysDown = {}
    gMatrixMenu = self

end

function GUIVTMatrixMenu:SetCursorShown(shown)
    if shown ~= self.cursorShown then
        self.cursorShown = shown
        MouseTracker_SetIsVisible(shown, St.kCursor, true)
    end
    -- Spectator camera modes may hide the OS cursor again; keep it up while the menu is open.
    if shown and not Client.GetMouseVisible() then
        Client.SetMouseVisible(true)
    end
end

function GUIVTMatrixMenu:Uninitialize()
    self:SetCursorShown(false)
    for _, key in ipairs({ "dim", "panel", "mini" }) do
        if self[key] then
            GUI.DestroyItem(self[key])   -- destroys all children
            self[key] = nil
        end
    end
    if gMatrixMenu == self then
        gMatrixMenu = nil
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

function GUIVTMatrixMenu:GetIsCursorOverPanel()
    local x, y = Client.GetCursorPosScreen()
    return GUIItemContainsPoint(self.panel, x, y)
end

-- ----------------------------------------------------------------------------
-- update
-- ----------------------------------------------------------------------------
local GetHovered = St.GetHovered

-- Button / chip text for the current synthesis state.
local function GetSynthesisStatus(state)
    local now = Shared.GetTime()
    local readyTime = state.readyTime or 0
    if readyTime <= 0 then
        return "AWAITING MATRIX", "waiting for a matrix slot", kColDimText
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
    SetFittedText(self.directives, #parts > 0 and ("Directive: " .. table.concat(parts, "  |  ")) or "", kPanelW / 2 - kMargin)
end

function GUIVTMatrixMenu:UpdateMenu(state)

    local rank, score = GetLocalRank()
    self.rank:SetText(string.format("Imperial Authorization: rank %d  (score %d)", rank, score))
    self:UpdateDirectives()

    local info = VT_GetEmpireInfo()
    local textW = kCardW - 2 * kPad

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
            SetFittedText(card.info1, info and string.format("quota %d / %d", count, quota) or "", textW)
            local cost = kVTCasteCost[def.caste] or 0
            SetFittedText(card.info2, cost > 0 and string.format("%d team res", cost) or "free", textW)
        else
            SetFittedText(card.info1, "unlimited", textW)
            SetFittedText(card.info2, "free", textW)
        end

        if lock then
            SetFittedText(card.lock, "locked: " .. lock, textW)
        elseif full then
            SetFittedText(card.lock, "quota full", textW)
        else
            card.lock:SetText("")
        end

        local hovered = GetHovered(card.body)
        local frameColor, bodyColor = kColFrame, kColCardBody
        if selected then
            frameColor, bodyColor = kColSelected, kColCardBodySel
        elseif lock then
            frameColor = kColLocked
        end
        if hovered and not selected then
            frameColor, bodyColor = kColFrameHover, kColCardBodyHover
        end
        card.frame:SetColor(frameColor)
        card.body:SetColor(bodyColor)
        card.portrait:SetColor((lock and not selected) and Color(0.45, 0.45, 0.5, 0.8) or Color(1, 1, 1, 1))
        card.name:SetColor(selected and kColCyan or (lock and kColDimText or kColText))
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
        self.description:SetText(WordWrap(self.description, text, 0, GUIScale(kPanelW - 2 * kMargin), 2))
    end

    for _, row in ipairs(self.rows) do
        local def = row.def
        local value = state[def.field] or 1
        SetFittedText(row.value, "<   " .. VT_GetString(def.prefix .. tostring(value)) .. "   >", kRowValueW)
        local lock = LockReason(_G[def.req][value], rank)
        SetFittedText(row.lock, lock and ("locked: " .. lock .. " - default used") or "",
                kRowW - (kRowValueX + kRowValueW) - kPad - 12)
        local hovered = GetHovered(row.body)
        row.frame:SetColor(hovered and kColFrameHover or kColFrame)
        row.body:SetColor(hovered and kColCardBodyHover or kColCardBody)
    end

    local label, _, color = GetSynthesisStatus(state)
    SetFittedText(self.buttonText, label, kButtonW - 2 * kPad)
    self.buttonText:SetColor(color)
    local ready = (state.readyTime or 0) > 0 and Shared.GetTime() >= state.readyTime and not state.armed
    local frameColor, bodyColor = kColFrame, kColCardBody
    if GetHovered(self.button) then
        frameColor, bodyColor = kColFrameHover, kColCardBodyHover
    elseif ready then
        local pulse = 0.75 + 0.25 * math.sin(Shared.GetTime() * 6)
        frameColor = Color(kColReady.r * pulse, kColReady.g * pulse, kColReady.b * pulse, 1)
    elseif state.armed then
        frameColor = kColActive
    end
    self.buttonFrame:SetColor(frameColor)
    self.button:SetColor(bodyColor)

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
    self.dim:SetIsVisible(showMenu)
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
        SetFittedText(self.miniText, "SYNTHESIS MATRIX [B]  -  " .. status, 460 - 2 * kPad)
        self.miniText:SetColor(color)
    end

end

-- ----------------------------------------------------------------------------
-- input
-- ----------------------------------------------------------------------------
local function SendChoice(choice)
    Client.SendNetworkMessage("VTMatrixChoice", { choice = choice }, true)
end

-- From VT_MatrixMouseListener. Returns true to swallow the click.
function GUIVTMatrixMenu:OnMouseDown(rightButton)

    if not self:GetIsMenuShown() then
        return false
    end

    local x, y = Client.GetCursorPosScreen()

    for i, card in ipairs(self.cards) do
        if GUIItemContainsPoint(card.body, x, y) then
            SendChoice(i)
            return true
        end
    end

    for _, row in ipairs(self.rows) do
        if GUIItemContainsPoint(row.body, x, y) then
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

    -- mouse buttons are handled by VT_MatrixMouseListener (they arrive there first)
    return false

end
