-- ============================================================================
-- GUIVTHud - full-screen tint while the local Infiltrator's cloaking field is
-- active. (The dead-player Synthesis Matrix menu is GUIVTMatrixMenu, the living
-- soldier HUD is GUIVTPlayerHUD.)
-- ============================================================================

class 'GUIVTHud' (GUIScript)

function GUIVTHud:Initialize()

    self.updateInterval = 0.1

    -- Full-screen tint while the local Infiltrator's cloaking field is active.
    self.cloakTint = GUIManager:CreateGraphicItem()
    self.cloakTint:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.cloakTint:SetPosition(Vector(0, 0, 0))
    self.cloakTint:SetSize(Vector(Client.GetScreenWidth(), Client.GetScreenHeight(), 0))
    self.cloakTint:SetColor(Color(0.25, 0.85, 1.0, 0))
    self.cloakTint:SetLayer(kGUILayerPlayerHUD - 1)
    self.cloakTint:SetIsVisible(false)

end

function GUIVTHud:Uninitialize()
    if self.cloakTint then
        GUI.DestroyItem(self.cloakTint)
        self.cloakTint = nil
    end
end

function GUIVTHud:UpdateCloakTint(player)
    local fraction = 0
    if player:isa("VTInfiltrator") and player.GetCloakFraction then
        fraction = player:GetCloakFraction()
    end
    if fraction > 0.01 then
        self.cloakTint:SetColor(Color(0.25, 0.85, 1.0, 0.18 * fraction))
        self.cloakTint:SetIsVisible(true)
    else
        self.cloakTint:SetIsVisible(false)
    end
end

function GUIVTHud:OnResolutionChanged(oldX, oldY, newX, newY)
    self:Uninitialize()
    self:Initialize()
end

function GUIVTHud:Update(deltaTime)

    PROFILE("GUIVTHud:Update")

    local player = Client.GetLocalPlayer()
    if not player or player:GetTeamNumber() ~= kVTTeamIndex then
        self.cloakTint:SetIsVisible(false)
        return
    end

    self:UpdateCloakTint(player)

end
