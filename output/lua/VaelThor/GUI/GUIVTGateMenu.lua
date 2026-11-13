-- ============================================================================
-- GUIVTGateMenu - destination picker for Nexus Gate jumps, in the style of the
-- Synthesis Matrix menu (GUI/VTGUIStyle.lua).
-- Opened by pressing E on a pylon connected to a Nexus Gate
-- (VTSubventionPylon:OnUse -> VT_OpenGateMenu). Shows a dimmed screen, a
-- cursor and one row per active Nexus Gate (sector, distance, integrity).
-- Pick with a click or keys 1-9; Esc, right click or a click outside the panel
-- cancels. Walking away from the pylon or waiting kAutoCloseTime closes it.
-- The server validates and performs the jump (Server.lua, VTNexusTeleport).
-- ============================================================================

class 'GUIVTGateMenu' (GUIScript)

local St = VTGUIStyle

local kMaxDestinations = 9
local kAutoCloseTime = 15
local kUseRangeSlack = 1      -- close once the player walks away from the pylon

local kPanelW = 640
local kMargin = 28
local kHeaderH = 104
local kRowW, kRowH, kRowGap = kPanelW - 2 * kMargin, 64, 8
local kFooterH = 52
local kPad = 16

local kNumberKeys =
{
    [InputKey.Num1] = 1, [InputKey.Num2] = 2, [InputKey.Num3] = 3,
    [InputKey.Num4] = 4, [InputKey.Num5] = 5, [InputKey.Num6] = 6,
    [InputKey.Num7] = 7, [InputKey.Num8] = 8, [InputKey.Num9] = 9,
}

local gGateMenu

-- Client-side estimate of the per-player jump cooldown (the server's
-- vtNextGateJump isn't networked); only used to grey out the menu.
VT_GateLastJumpTime = VT_GateLastJumpTime or 0

function VT_OpenGateMenu(pylon)
    if gGateMenu then
        gGateMenu:Open(pylon)
    end
end

-- One MouseTracker listener for the session (no way to unregister), forwarding
-- to the live menu. It runs before the GUI scripts, so nothing swallows clicks.
if not VT_GateMouseListener then
    VT_GateMouseListener =
    {
        OnMouseDown = function(_, key, doubleClick)
            if gGateMenu and gGateMenu:GetIsOpen() and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1) then
                return gGateMenu:OnMouseDown(key == InputKey.MouseButton1)
            end
            return false
        end,
        OnMouseUp = function(_, key)
            return gGateMenu ~= nil and gGateMenu:GetIsOpen()
                and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1)
        end,
    }
    MouseTracker_ListenToButtons(VT_GateMouseListener)
end

local function GetLocation(entity)
    local location = entity and entity.GetLocationName and entity:GetLocationName() or ""
    return location ~= "" and location or "Unknown sector"
end

local function GetCooldownRemaining()
    return VT_GateLastJumpTime + kVTGateTeleportCooldown - Shared.GetTime()
end

function GUIVTGateMenu:Initialize()

    self.updateInterval = 0   -- every frame: hover, distances, cooldown

    self.dim = St.Graphic(nil, nil, 0, 0, 0, 0, St.kColDim, kGUILayerPlayerHUD)
    self.dim:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))

    self.panel = St.Graphic(nil, nil, kPanelW, 200, 0, 0, St.kColBody, kGUILayerPlayerHUDForeground1)
    self.panel:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.frame = St.Graphic(self.panel, St.kPanelTex, kPanelW, 200, 0, 0, St.kColFrame, kGUILayerPlayerHUDForeground1)

    self.title = St.Text(self.panel, Fonts.kAgencyFB_Large, kMargin, 40, nil, St.kColCyan)
    self.title:SetText("NEXUS GATE NETWORK")
    self.subtitle = St.Text(self.panel, Fonts.kAgencyFB_Small, kMargin, 76, nil, St.kColDimText)

    self.rows = {}
    for i = 1, kMaxDestinations do
        local y = kHeaderH + (i - 1) * (kRowH + kRowGap)
        local body, frame = St.Box(self.panel, St.kChipTex, kRowW, kRowH, kMargin, y)
        local row =
        {
            body     = body,
            frame    = frame,
            key      = St.Text(body, Fonts.kAgencyFB_Medium, kPad, kRowH / 2, nil, St.kColKey),
            name     = St.Text(body, Fonts.kAgencyFB_Medium, kPad + 46, 22, nil, St.kColText),
            info     = St.Text(body, Fonts.kAgencyFB_Small, kPad + 46, 46, nil, St.kColDimText),
            distance = St.Text(body, Fonts.kAgencyFB_Medium, kRowW - kPad, kRowH / 2, GUIItem.Align_Max, St.kColText),
        }
        row.key:SetText(string.format("[%d]", i))
        self.rows[i] = row
    end

    self.hint = St.Text(self.panel, Fonts.kAgencyFB_Small, kPanelW / 2, 0, GUIItem.Align_Center, St.kColDimText)
    St.SetFittedText(self.hint, "[1-9] / click: jump      [Esc] / right click: cancel", kPanelW - 2 * kMargin)

    self.dim:SetIsVisible(false)
    self.panel:SetIsVisible(false)

    self.pylonId = Entity.invalidId
    self.destinationIds = {}
    self.cursorShown = false
    gGateMenu = self

end

function GUIVTGateMenu:SetCursorShown(shown)
    if shown ~= self.cursorShown then
        self.cursorShown = shown
        MouseTracker_SetIsVisible(shown, St.kCursor, true)
    end
end

function GUIVTGateMenu:Uninitialize()
    self:SetCursorShown(false)
    for _, key in ipairs({ "dim", "panel" }) do
        if self[key] then
            GUI.DestroyItem(self[key])   -- destroys all children
            self[key] = nil
        end
    end
    if gGateMenu == self then
        gGateMenu = nil
    end
end

function GUIVTGateMenu:OnResolutionChanged(oldX, oldY, newX, newY)
    self:Uninitialize()
    self:Initialize()
end

function GUIVTGateMenu:GetIsOpen()
    return self.panel ~= nil and self.panel:GetIsVisible()
end

function GUIVTGateMenu:Close()
    self.dim:SetIsVisible(false)
    self.panel:SetIsVisible(false)
    self:SetCursorShown(false)
    self.pylonId = Entity.invalidId
    self.destinationIds = {}
end

function GUIVTGateMenu:Open(pylon)

    if self:GetIsOpen() and self.pylonId == pylon:GetId() then
        return  -- E is held: OnUse fires every frame
    end

    local connected, destinations = VT_GetGateJumpOptions(pylon)
    if not connected or #destinations == 0 then
        return
    end

    self.pylonId = pylon:GetId()
    self.openTime = Shared.GetTime()
    self.destinationIds = {}

    local count = math.min(#destinations, kMaxDestinations)
    for i = 1, kMaxDestinations do
        self.destinationIds[i] = i <= count and destinations[i]:GetId() or nil
        self.rows[i].body:SetIsVisible(i <= count)
    end

    -- size the panel to the number of gates
    local height = kHeaderH + count * (kRowH + kRowGap) - kRowGap + kFooterH
    self.panel:SetSize(St.S(kPanelW, height))
    self.frame:SetSize(St.S(kPanelW, height))
    self.panel:SetPosition(St.S(-kPanelW / 2, -height / 2))
    self.hint:SetPosition(St.S(kPanelW / 2, height - kFooterH / 2))

    self.dim:SetIsVisible(true)
    self.panel:SetIsVisible(true)
    self:SetCursorShown(true)
    self:Update(0)

end

function GUIVTGateMenu:Update(deltaTime)

    if not self:GetIsOpen() then
        return
    end

    local player = Client.GetLocalPlayer()
    local pylon = Shared.GetEntity(self.pylonId)

    if not player or not player:GetIsAlive() or not pylon
            or (pylon:GetOrigin() - player:GetOrigin()):GetLength() > kVTGateUseRange + kUseRangeSlack
            or Shared.GetTime() - self.openTime > kAutoCloseTime
            or (MainMenu_GetIsOpened and MainMenu_GetIsOpened()) then
        self:Close()
        return
    end

    -- spectator / menu code may hide the OS cursor; keep it up while open
    if not Client.GetMouseVisible() then
        Client.SetMouseVisible(true)
    end

    local cooldown = GetCooldownRemaining()
    if cooldown > 0 then
        self.subtitle:SetColor(St.kColWarn)
        St.SetFittedText(self.subtitle, string.format("Gate recharging - %d s", math.ceil(cooldown)), kPanelW - 2 * kMargin)
    else
        self.subtitle:SetColor(St.kColDimText)
        St.SetFittedText(self.subtitle, "From the pylon in " .. GetLocation(pylon) .. " - choose a destination", kPanelW - 2 * kMargin)
    end

    local origin = player:GetOrigin()
    for i, row in ipairs(self.rows) do
        local gate = self.destinationIds[i] and Shared.GetEntity(self.destinationIds[i])
        if row.body:GetIsVisible() then
            if gate and gate:GetIsAlive() then
                St.SetFittedText(row.name, GetLocation(gate), kRowW - 2 * kPad - 46 - 90)
                local integrity = gate.GetHealthScalar and math.floor(gate:GetHealthScalar() * 100 + 0.5) or 100
                St.SetFittedText(row.info, string.format("Nexus Gate  -  integrity %d%%", integrity), kRowW - 2 * kPad - 46 - 90)
                row.info:SetColor(integrity < 50 and St.kColWarn or St.kColDimText)
                row.distance:SetText(string.format("%.0f m", (gate:GetOrigin() - origin):GetLength()))
                row.name:SetColor(cooldown > 0 and St.kColDimText or St.kColText)
            else
                St.SetFittedText(row.name, "gate lost", kRowW - 2 * kPad - 46 - 90)
                row.name:SetColor(St.kColWarn)
                row.info:SetText("")
                row.distance:SetText("")
            end
            St.ColorBox(row.body, row.frame, cooldown <= 0 and St.GetHovered(row.body), false)
        end
    end

end

-- Returns true when the jump was requested (the menu closes then).
function GUIVTGateMenu:Jump(index)
    local gateId = self.destinationIds[index]
    local gate = gateId and Shared.GetEntity(gateId)
    if not (gate and gate:GetIsAlive()) or GetCooldownRemaining() > 0 then
        return false
    end
    Client.SendNetworkMessage("VTNexusTeleport", { pylonId = self.pylonId, gateId = gateId }, true)
    VT_GateLastJumpTime = Shared.GetTime()
    self:Close()
    return true
end

-- From VT_GateMouseListener; the menu is open. Always swallows the click.
function GUIVTGateMenu:OnMouseDown(rightButton)
    if rightButton then
        self:Close()
        return true
    end
    local x, y = Client.GetCursorPosScreen()
    for i, row in ipairs(self.rows) do
        if row.body:GetIsVisible() and GUIItemContainsPoint(row.body, x, y) then
            self:Jump(i)
            return true
        end
    end
    if not GUIItemContainsPoint(self.panel, x, y) then
        self:Close()   -- click outside = cancel
    end
    return true
end

function GUIVTGateMenu:SendKeyEvent(key, down)

    if not self:GetIsOpen() or not down then
        return false
    end

    if key == InputKey.Escape then
        self:Close()
        return true
    end

    local index = kNumberKeys[key]
    if index then
        self:Jump(index)
        return true   -- swallow number keys while the menu is open (no weapon switch)
    end

    return false

end
