-- ============================================================================
-- GUIVTGateMenu - destination picker for Nexus Gate jumps.
-- Opened by pressing E on a pylon connected to a Nexus Gate
-- (VTSubventionPylon:OnUse -> VT_OpenGateMenu). Keys 1-9 pick a gate,
-- Escape closes. The server validates and performs the jump.
-- ============================================================================

class 'GUIVTGateMenu' (GUIScript)

local kMaxDestinations = 9
local kAutoCloseTime = 15
local kUseRangeSlack = 1      -- close once the player walks away from the pylon

local kNumberKeys =
{
    [InputKey.Num1] = 1, [InputKey.Num2] = 2, [InputKey.Num3] = 3,
    [InputKey.Num4] = 4, [InputKey.Num5] = 5, [InputKey.Num6] = 6,
    [InputKey.Num7] = 7, [InputKey.Num8] = 8, [InputKey.Num9] = 9,
}

local gGateMenu

function VT_OpenGateMenu(pylon)
    if gGateMenu then
        gGateMenu:Open(pylon)
    end
end

function GUIVTGateMenu:Initialize()

    self.updateInterval = 0.1

    self.background = GUIManager:CreateGraphicItem()
    self.background:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.background:SetColor(Color(0.05, 0.02, 0.10, 0.85))
    self.background:SetLayer(kGUILayerPlayerHUDForeground1 or (kGUILayerPlayerHUD + 1))
    self.background:SetIsVisible(false)

    self.text = GUIManager:CreateTextItem()
    self.text:SetFontName(Fonts.kAgencyFB_Small)
    self.text:SetScale(GetScaledVector())
    GUIMakeFontScale(self.text)
    self.text:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.text:SetTextAlignmentX(GUIItem.Align_Min)
    self.text:SetTextAlignmentY(GUIItem.Align_Min)
    self.text:SetColor(Color(0.35, 0.95, 1.0, 1))
    self.text:SetPosition(GUIScale(Vector(16, 12, 0)))
    self.background:AddChild(self.text)

    self.pylonId = Entity.invalidId
    self.destinationIds = {}
    gGateMenu = self

end

function GUIVTGateMenu:Uninitialize()
    if self.background then
        GUI.DestroyItem(self.background)   -- destroys the child text too
        self.background = nil
        self.text = nil
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
    return self.background:GetIsVisible()
end

function GUIVTGateMenu:Close()
    self.background:SetIsVisible(false)
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

    local lines = { "NEXUS GATE NETWORK - choose destination", "" }
    local origin = pylon:GetOrigin()
    for i = 1, math.min(#destinations, kMaxDestinations) do
        local gate = destinations[i]
        self.destinationIds[i] = gate:GetId()
        local location = gate.GetLocationName and gate:GetLocationName() or ""
        if location == "" then
            location = "Unknown sector"
        end
        lines[#lines + 1] = string.format("[%d] %s  (%.0f m)", i, location, (gate:GetOrigin() - origin):GetLength())
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[Esc] cancel"

    self.text:SetText(table.concat(lines, "\n"))

    local padding = GUIScale(Vector(32, 24, 0))
    local size = Vector(self.text:GetTextWidth(self.text:GetText()) * self.text:GetScale().x,
            self.text:GetTextHeight(self.text:GetText()) * self.text:GetScale().y, 0) + padding
    self.background:SetSize(size)
    self.background:SetPosition(-size / 2)
    self.background:SetIsVisible(true)

end

function GUIVTGateMenu:Update(deltaTime)

    if not self:GetIsOpen() then
        return
    end

    local player = Client.GetLocalPlayer()
    local pylon = Shared.GetEntity(self.pylonId)

    if not player or not player:GetIsAlive() or not pylon
            or (pylon:GetOrigin() - player:GetOrigin()):GetLength() > kVTGateUseRange + kUseRangeSlack
            or Shared.GetTime() - self.openTime > kAutoCloseTime then
        self:Close()
    end

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
        local gateId = self.destinationIds[index]
        if gateId then
            Client.SendNetworkMessage("VTNexusTeleport", { pylonId = self.pylonId, gateId = gateId }, true)
            self:Close()
        end
        return true   -- swallow number keys while the menu is open (no weapon switch)
    end

    return false

end
